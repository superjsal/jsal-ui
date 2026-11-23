-- Your class's trainer spells: from the game's files (SpellData.lua) for
-- what each level brings, and from the trainers jsal.ui saved for what it
-- costs. A class trainer's list also says which spells are really taught:
-- once one is saved, anything in the files it doesn't offer drops out. A
-- weapon master's list gives each weapon skill's price and who teaches it.
-- A warlock's demons and a hunter's pet trainer add their own abilities.
local _, ns = ...
local Compat = ns.Compat

local Training = {}
ns.Training = Training

Training.SOON = 2   -- levels ahead that count as "coming soon"

-- A class spell's rank held back by a lower rank you skipped: its spell ID to the skipped one's.
local held = {}

-- A spell's rank as the game words it ("Rank 5"), nil for none. The rank
-- that ships with the spell list comes first: the game's rank text is empty
-- until it has loaded that spell, and a spell read as having no rank looked
-- known to anyone with a lower rank.
local function Rank(spellID, shipped)
    if shipped then return shipped > 0 and ("Rank " .. shipped) or nil end
    local text = C_Spell and C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(spellID)
    if not text and GetSpellSubtext then text = GetSpellSubtext(spellID) end
    return text and text ~= "" and text or nil
end

-- A spell's name and rank as one key, the rank by its digits alone: "Claw|3"
-- whether the game words the rank "Rank 3", "Rang 3" or "Уровень 3", and
-- whether it's text or the number that ships with the spell list. A rank
-- with no digits in it is kept as it reads; no rank is "Claw|". Every key
-- of a name and rank is made here: a trainer's row, the spellbook and the
-- spell list each word a rank their own way on a client in another language.
local function RankKey(name, rank)
    rank = rank ~= nil and tostring(rank) or ""
    return (name or "") .. "|" .. (rank:match("%d+") or rank)
end
Training.RankKey = RankKey

-- A saved table keyed by name and rank as the game wrote them ("Claw|Rank 3",
-- "Klaue|Rang 3"), keyed again with RankKey. What's saved is left as it is,
-- so an older jsal.ui still reads it, and keys of either kind are found.
function Training.ByRank(saved)
    local out = {}
    for key, value in pairs(type(saved) == "table" and saved or {}) do
        if type(key) == "string" then
            local name, rank = key:match("^(.*)|([^|]*)$")
            local again = name and RankKey(name, rank)
            if again and out[again] == nil then out[again] = value end
        end
    end
    return out
end

-- The weapon masters seen to teach a weapon skill, as words: "Woo Ping in
-- Stormwind City or Ilyenia Moonfire in Darnassus". Nil when none has been.
function Training.WeaponMasters(seen)
    local list = {}
    for npc, zone in pairs(seen or {}) do
        list[#list + 1] = zone ~= "" and (npc .. " in " .. zone) or npc
    end
    if #list == 0 then return nil end
    table.sort(list)
    return table.concat(list, " or ")
end

-- The portal trainer of your side seen to teach a mage's teleport or portal, or nil where none
-- has been. Each teaches its own city's pair, so a spell has one: it's that one, not the nearest.
function Training.PortalTrainer(spellID)
    local T = ns.Trainers
    if not (T and T.Friendly and T.Teaches) then return nil end
    for _, trainer in ipairs(ns.TrainerData and ns.TrainerData.portal or {}) do
        if T.Friendly(trainer) and T.Teaches(trainer, spellID) then return trainer end
    end
    return nil
end

-- Sorts the saved trainers for this class into class trainers, pet trainers
-- and weapon masters, by what their lists teach, and gathers each one's
-- prices. A pet trainer opens the same window as a class trainer, but what
-- it lists are pet abilities.
local KINDS = { available = true, unavailable = true, used = true }

-- A trainer charges less the better your standing with its faction, so two
-- visits can price one spell differently: the higher is the full price, as
-- in the prices that ship.
local function Highest(was, cost)
    if was == nil then return cost end
    if cost == nil then return was end
    return math.max(was, cost)
end

local function Trainers(classID, classSpells, classNames, weaponIDs, weaponNames, petToBeast, beastByName)
    local prices = { bySpell = {}, byName = {}, listed = {}, extra = {}, haveTrainer = false, weapons = {}, weaponAt = {}, pet = {} }
    local trainers = type(ns.db.trainers) == "table" and ns.db.trainers or {}
    -- Weapon skills cost the same at every weapon master, for every class,
    -- so any character's visit prices them. Each weapon master teaches only
    -- some of them, though, so the visit also says who teaches which: the
    -- planner said "Any weapon master teaches it", and the saved visits show
    -- Woo Ping with swords, crossbows and polearms, Buliwyf Stonehand with
    -- axes, guns and maces, Ilyenia Moonfire with bows, thrown and staves.
    --
    -- "?" is Beast Training, saved as a trainer before that was caught.
    for key, trainer in pairs(trainers) do
        if key:find("^%? @ ") then trainers[key] = nil end
    end
    for _, trainer in pairs(trainers) do
        for _, row in ipairs(ns.TrainerPrices.RowsOf(trainer)) do
            local id = (row.spell and weaponIDs[row.spell] and row.spell) or weaponNames[row.name or ""]
            if id then
                -- The highest seen, as for a class spell: a weapon master visited at a better
                -- standing charges less, and that isn't the price for every character.
                prices.weapons[id] = Highest(prices.weapons[id], row.cost)
                if trainer.npc and trainer.npc ~= "?" then
                    prices.weaponAt[id] = prices.weaponAt[id] or {}
                    prices.weaponAt[id][trainer.npc] = trainer.zone or ""
                end
            end
        end
    end
    -- And the weapon masters that ship with the addon, each with what it's been seen to teach:
    -- your own side's, so a character who has opened none still learns who to see. Until these
    -- shipped, only a weapon master you had opened yourself was named.
    local T = ns.Trainers
    for _, master in ipairs(ns.TrainerData and ns.TrainerData.weapons or {}) do
        if not T or T.Friendly(master) then
            local zone = T and T.Zone(master) or ""
            for _, id in ipairs(master.teaches or {}) do
                if weaponIDs[id] then
                    prices.weaponAt[id] = prices.weaponAt[id] or {}
                    prices.weaponAt[id][master.name] = prices.weaponAt[id][master.name] or zone
                end
            end
        end
    end
    for _, trainer in pairs(trainers) do
        if trainer.class == classID and type(trainer.rows) == "table" then
            local rows = ns.TrainerPrices.RowsOf(trainer)
            -- Visits saved before Forever's order was known hold the row's
            -- kind where its rank should be, and are kept with no rank.
            for _, row in ipairs(rows) do
                if KINDS[row.rank] then row.category, row.rank = row.rank, nil end
                if row.rank == nil and row.spell then row.rank = Rank(row.spell) end
            end
            local teachesClass = false
            for _, row in ipairs(rows) do
                if (row.spell and classSpells[row.spell]) or classNames[row.name or ""] then
                    teachesClass = true
                    break
                end
            end
            if teachesClass then
                prices.haveTrainer = true
                for _, row in ipairs(rows) do
                    if row.spell then
                        prices.bySpell[row.spell] = Highest(prices.bySpell[row.spell], row.cost)
                        prices.listed[row.spell] = true
                        -- Taught here but not in the class's spell list
                        -- (Parry, Plate Mail, poisons...).
                        if not classSpells[row.spell] then prices.extra[row.spell] = row.level end
                    end
                    local key = RankKey(row.name, row.rank)
                    prices.byName[key] = Highest(prices.byName[key], row.cost)
                end
            else
                for _, row in ipairs(rows) do
                    -- A pet trainer lists the pet's spell; the price is kept
                    -- under the Beast Training spell that teaches it.
                    local pet = (row.spell and petToBeast[row.spell]) or beastByName[RankKey(row.name, row.rank)]
                    -- Visits are kept for the whole account, so whether it's
                    -- learned is read from this character's own record later.
                    if pet then
                        local was = prices.pet[pet]
                        prices.pet[pet] = { cost = Highest(was and was.cost, row.cost), level = row.level,
                                            spell = row.spell, key = RankKey(row.name, row.rank) }
                    end
                end
            end
        end
    end
    return prices
end

-- The prices that ship with jsal.ui, seen at trainers in game, fill in
-- wherever this player hasn't been to a trainer yet.
local function Shipped(prices, source)
    for id, cost in pairs(source.prices or {}) do
        if prices.bySpell[id] == nil then prices.bySpell[id] = cost end
        prices.listed[id] = true
        prices.haveTrainer = true
    end
    for _, entry in ipairs(source.extra or {}) do
        if prices.extra[entry[1]] == nil then prices.extra[entry[1]] = entry[2] end
    end
    for id, cost in pairs(source.weaponPrices or {}) do
        if not prices.weapons[id] then prices.weapons[id] = cost end
    end
    for id, entry in pairs(source.petTrainer or {}) do
        if not prices.pet[id] then prices.pet[id] = { cost = entry[1], level = entry[2] } end
    end
end

-- Grimoire prices by the demon spell they teach: the ones that ship with
-- jsal.ui, then every demon trainer saved for this class. A saved book has
-- its spell, or (saved without one, on an English client) a name that says
-- the ability and rank it teaches ("Grimoire of Firebolt (Rank 2)"), read
-- against each demon spell's name in the game. A spell no book names takes
-- the price of another with its name and rank.
local function Grimoires(classID, source)
    local out, byKey = {}, {}
    for _, demon in ipairs(source.demons or {}) do
        for _, entry in ipairs(demon.spells) do
            local name = Compat.SpellInfo(entry[1])
            if name then
                local key = RankKey(name, entry[3] > 0 and entry[3] or nil)
                byKey[key] = byKey[key] or {}
                table.insert(byKey[key], entry[1])
            end
        end
    end
    for spell, cost in pairs(source.grimoires or {}) do out[spell] = cost end
    for _, shop in pairs(type(ns.db.grimoires) == "table" and ns.db.grimoires or {}) do
        if shop.class == classID and type(shop.rows) == "table" then
            for _, row in ipairs(shop.rows) do
                if row.spell then
                    out[row.spell] = row.cost
                else
                    local name, rank = (row.name or ""):match("^Grimoire of (.-) %(Rank (%d+)%)$")
                    name = name or (row.name or ""):match("^Grimoire of (.+)$")
                    for _, spell in ipairs(name and byKey[RankKey(name, rank)] or {}) do out[spell] = row.cost end
                end
            end
        end
    end
    for _, spells in pairs(byKey) do
        local cost
        for _, spell in ipairs(spells) do cost = cost or out[spell] end
        for _, spell in ipairs(spells) do out[spell] = out[spell] or cost end
    end
    return out
end

-- Everything the page needs: each spell with its level, school, name, rank,
-- icon, price (nil when no trainer has shown it yet), whether you know it,
-- and whether you've chosen to skip it; and each weapon skill with its price
-- and who teaches it, once a weapon master has been opened.
local function ReadNow()
    local _, _, classID = UnitClass("player")
    local source = ns.SpellData[classID]
    if not source then return nil end

    local classSpells, classNames, weaponIDs, weaponNames = {}, {}, {}, {}
    for _, entry in ipairs(source.spells) do
        classSpells[entry[1]] = true
        local name = Compat.SpellInfo(entry[1])
        if name then classNames[name] = true end
    end
    for _, id in ipairs(source.weapons) do
        weaponIDs[id] = true
        local name = Compat.SpellInfo(id)
        if name then weaponNames[name] = id end
    end
    -- A hunter's pet abilities, as a pet trainer lists them: the pet's spell
    -- to the Beast Training spell, and by name and rank.
    local petToBeast, beastByName = {}, {}
    -- And each Beast Training spell's level and rank, from the spell list. A trainer's row can't
    -- be trusted for the level: it lists a rank you've learned at level 0, and visits are kept
    -- for the whole account, so one hunter's learned rank read as ready at any level on another.
    local beastLevel, beastRank = {}, {}
    for _, list in pairs(source.families or {}) do
        for _, entry in ipairs(list) do
            petToBeast[entry[1]] = entry[2]
            beastLevel[entry[2]], beastRank[entry[2]] = entry[3], entry[4]
        end
    end
    for _, entry in ipairs(source.beast or {}) do
        local name = Compat.SpellInfo(entry[1])
        if name then beastByName[RankKey(name, Rank(entry[1]))] = entry[1] end
    end
    local prices = Trainers(classID, classSpells, classNames, weaponIDs, weaponNames, petToBeast, beastByName)
    Shipped(prices, source)

    -- Race-only spells show only for that race. Races past the first 31 have
    -- no bit to check, so they get only the spells every race learns.
    local _, _, raceID = UnitRace("player")
    local raceBit = raceID and raceID <= 31 and bit.lshift(1, raceID - 1) or 0
    local function ForMyRace(mask)
        return not mask or mask == 0 or bit.band(mask, raceBit) ~= 0
    end

    local skips = type(ns.char.trainingSkips) == "table" and ns.char.trainingSkips or {}
    local data = { classID = classID, schools = source.schools, spells = {}, weapons = {}, haveTrainer = prices.haveTrainer }
    -- Known: by the spell's ID, by its name at this rank or higher in your
    -- spellbook, or a trainer having marked it learned. Forever can give a
    -- spell you know a different ID from the one the trainer sells.
    local book = Compat.PlayerSpellbook()
    local trained = type(ns.char.trainedSpells) == "table" and ns.char.trainedSpells or {}
    -- And by name and rank, the rank by its digits: the trainer words a rank in the client's
    -- language, the spell list in English.
    local trainedBy = Training.ByRank(trained)
    local function Known(id, name, rank)
        if IsPlayerSpell(id) or book.ids[id] or trained[id] then return true end
        if not name then return false end
        if trainedBy[RankKey(name, rank)] then return true end
        local have = book.ranks[name]
        return have ~= nil and have >= (tonumber(rank and rank:match("(%d+)")) or 0)
    end
    -- A later rank of a talent's ability (Counterattack Rank 2) is sold only
    -- to someone who has the talent, so for everyone else it isn't a spell
    -- to train at all. Having the talent shows as its own spell, or as any
    -- rank of that name in the spellbook.
    local talent = source.talent or {}
    local function Untaken(id, name)
        local firsts = talent[id]
        if not firsts or book.ranks[name] ~= nil or IsPlayerSpell(id) or trained[id] then return false end
        for _, first in ipairs(firsts) do
            if IsPlayerSpell(first) then return false end
        end
        return true
    end
    -- Spells no class trainer sells come from a class quest, a book or (for
    -- a mage's teleports) a portal trainer, and say so. A priest's racial
    -- ranks are sold by trainers to that race only, so they show as usual.
    local elsewhere = source.elsewhere or {}
    for _, entry in ipairs(source.spells) do
        local id, level, school, race = entry[1], entry[2], entry[3], entry[4]
        local name, icon = Compat.SpellInfo(id)
        local via = elsewhere[id]
        local shown = via ~= nil
        if via == "trainer" then via = nil end
        if name and ForMyRace(race) and not Untaken(id, name)
            and (not prices.haveTrainer or prices.listed[id] or shown or IsPlayerSpell(id)) then
            local rank = Rank(id, entry[5])
            data.spells[#data.spells + 1] = {
                id = id, level = level, school = school, name = name, icon = icon, rank = rank,
                cost = prices.bySpell[id] or prices.byName[RankKey(name, rank)],
                known = Known(id, name, rank), skipped = skips[id] == true, via = via,
                pin = via == "portal" and Training.PortalTrainer(id) or nil,
            }
        end
    end
    -- What else a class trainer teaches. Its level is the trainer's; a
    -- learned row can show 0 there.
    for id, level in pairs(prices.extra) do
        local name, icon = Compat.SpellInfo(id)
        if name and not classSpells[id] then
            data.spells[#data.spells + 1] = {
                id = id, level = math.max(1, level or 1), name = name, icon = icon, rank = Rank(id),
                cost = prices.bySpell[id], known = Known(id, name, Rank(id)), skipped = skips[id] == true,
            }
        end
    end
    -- A trainer sells a rank only to someone who knows the rank before it (Distracting Shot Rank 2
    -- stays unavailable at level 20 without Rank 1), so a skipped rank holds back the ranks after
    -- it: they're skipped with it, held by it, and back when it is.
    held = {}
    local byName = {}
    for _, spell in ipairs(data.spells) do
        if spell.rank then
            byName[spell.name] = byName[spell.name] or {}
            table.insert(byName[spell.name], spell)
        end
    end
    for _, ranks in pairs(byName) do
        table.sort(ranks, function(a, b)
            if a.level ~= b.level then return a.level < b.level end
            return (tonumber(a.rank:match("%d+")) or 0) < (tonumber(b.rank:match("%d+")) or 0)
        end)
        local holder
        for _, spell in ipairs(ranks) do
            if not spell.known then
                if holder then
                    spell.skipped, spell.heldBy, held[spell.id] = true, holder.id, holder.id
                elseif spell.skipped then
                    holder = spell
                end
            end
        end
    end
    for _, id in ipairs(source.weapons) do
        local name, icon = Compat.SpellInfo(id)
        if name then
            data.weapons[#data.weapons + 1] = {
                id = id, name = name, icon = icon, known = IsPlayerSpell(id), cost = prices.weapons[id],
                skipped = skips[id] == true, at = Training.WeaponMasters(prices.weaponAt[id]),
            }
        end
    end

    -- A hunter's pet trainer: only what a pet trainer has listed, as most
    -- pet abilities come from taming instead.
    for id, taught in pairs(prices.pet) do
        local name, icon = Compat.SpellInfo(id)
        if name then
            local rank = Rank(id, beastRank[id])
            local level = beastLevel[id] or (tonumber(taught.level) or 0) > 0 and taught.level or 1
            data.spells[#data.spells + 1] = {
                id = id, level = level, name = name, icon = icon, rank = rank,
                cost = taught.cost,
                known = IsPlayerSpell(id) or (taught.spell and trained[taught.spell]) or (taught.key and trainedBy[taught.key])
                    or trainedBy[RankKey(name, rank)] or false,
                skipped = skips[id] == true, source = "pet", group = "Pet trainer",
            }
        end
    end

    -- A warlock's demons: every Grimoire ability, priced from the demon
    -- trainers saved. One counts as known once that demon has been seen to
    -- know it.
    local grimoires = Grimoires(classID, source)
    local petKnown = type(ns.char.petKnown) == "table" and ns.char.petKnown or {}
    for _, demon in ipairs(source.demons or {}) do
        for _, entry in ipairs(demon.spells) do
            local id, level = entry[1], entry[2]
            local name, icon = Compat.SpellInfo(id)
            if name then
                local rank = Rank(id, entry[3])
                data.spells[#data.spells + 1] = {
                    id = id, level = level, name = name, icon = icon, rank = rank,
                    cost = grimoires[id],
                    known = petKnown[id] or IsSpellKnown(id, true), skipped = skips[id] == true,
                    source = "demon", group = demon.name,
                }
            end
        end
    end
    table.sort(data.spells, function(a, b)
        if a.level ~= b.level then return a.level < b.level end
        return a.name < b.name
    end)
    return data
end

-- Reading every spell is the costly part of opening the dashboard, and
-- Home's cards, the menu's counts and the Training Planner each ask for it:
-- unkept, one click on the dashboard reads the whole spellbook two or three
-- times. So the reading is kept until something it reads changes: a spell
-- learned, a level, a pet, a trainer or Grimoire vendor saved, a spell
-- skipped. Whoever uses it only reads it.
local kept, keptPet
function Training.Read()
    if not kept then kept = ReadNow() end
    return kept
end

function Training.Forget() kept, keptPet = nil, nil end

local forget = CreateFrame("Frame")
for _, event in ipairs({ "SPELLS_CHANGED", "SKILL_LINES_CHANGED", "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD",
    "TRAINER_UPDATE", "TRAINER_CLOSED", "UNIT_PET", "PET_BAR_UPDATE",
    -- And for the pet's abilities (Training.Pet): its level, its training points, a pet stabled or renamed.
    "UNIT_LEVEL", "UNIT_PET_TRAINING_POINTS", "PET_STABLE_UPDATE", "LOCALPLAYER_PET_RENAMED" }) do
    forget:RegisterEvent(event)
end
forget:SetScript("OnEvent", Training.Forget)

-- The pet out now's family, as the spell list keys it: by the family's ID,
-- which is the same in every language, else by the name the game gives it,
-- which matches only on an English client ("Katze" is a Cat). Nil with no
-- pet out, or where the game hides it.
local function PetFamily(source)
    if not UnitExists("pet") then return nil end
    local name, id = Compat.Family("pet")
    local key = id and source.familyIDs and source.familyIDs[id]
    return key or name
end

-- A hunter's pet as last seen: its family, level and the abilities it knows.
local function NotePet(source)
    local family = PetFamily(source)
    if not family then return end
    -- The pet's spellbook shows each ability once, at the rank it knows.
    local book = Compat.PetSpellbook()
    local bookBy = Training.ByRank(book)
    local known = {}
    for _, list in ipairs({ source.families[family] or {}, source.families["*"] or {} }) do
        for _, entry in ipairs(list) do
            local name = Compat.SpellInfo(entry[1])
            if IsSpellKnown(entry[1], true) or book[entry[1]] or (name and bookBy[RankKey(name, entry[4] > 0 and entry[4] or nil)]) then
                known[entry[1]] = true
            end
        end
    end
    ns.char.pet = { family = family, name = Compat.Name("pet"), level = UnitLevel("pet"), known = known }
end

-- Pet abilities are the pet's, not yours, so the game only says what the pet
-- out right now knows. Each time one is out, what it knows is noted for this
-- character: every demon's abilities for a warlock, the pet itself for a hunter.
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PET_BAR_UPDATE")
watcher:RegisterEvent("UNIT_PET")
watcher:RegisterEvent("UNIT_LEVEL")
-- The pet bar updates many times while the game loads and in a fight, so a
-- burst of updates is noted once, a second after the last.
local noting = false
local function NoteAll()
    noting = false
    local _, _, classID = UnitClass("player")
    local source = ns.SpellData and ns.SpellData[classID]
    if not (source and ns.char) then return end
    if source.families then NotePet(source) end
    if not source.demons then return end
    ns.char.petKnown = type(ns.char.petKnown) == "table" and ns.char.petKnown or {}
    for _, demon in ipairs(source.demons) do
        for _, entry in ipairs(demon.spells) do
            if IsSpellKnown(entry[1], true) then ns.char.petKnown[entry[1]] = true end
        end
    end
    kept, keptPet = nil, nil
end

watcher:SetScript("OnEvent", function(_, event, unit)
    unit = ns.Compat.Plain(unit)
    if event == "UNIT_PET" and unit ~= "player" then return end
    if event == "UNIT_LEVEL" and unit ~= "pet" then return end
    local _, classFile = UnitClass("player")
    if classFile ~= "HUNTER" and classFile ~= "WARLOCK" then return end
    if noting then return end
    noting = true
    Compat.After(1, function() xpcall(NoteAll, ns.Report) end)
end)

-- What a hunter's pet can learn, one row per ability: the next rank to teach
-- and where it stands. Ready (in Beast Training, the pet is high enough),
-- short of training points, waiting on the pet's level, still to be tamed,
-- or all ranks known. Nil for other classes, or before a pet has been seen.
--
-- A rank takes training points, and a row the pet hasn't the points for is
-- "points", not "ready": without that, the planner says "Teach now" for
-- ranks the pet can't afford. Forever has no GetPetTrainingPoints global
-- (calling it is an error); the game's
-- own window asks C_PetInfo.GetPetTrainingPoints for the total and the used,
-- and lets you train a rank only when the free ones cover the cost it lists,
-- so that's the rule here: the listed cost against what's free. (The points
-- of the rank the pet knows do come back, but after.) Where the game doesn't
-- say how many are free, a row stays "ready" and the planner gives its cost,
-- not a promise.
-- The menu's count, Home's card and the Training Planner each ask for this on every open, and
-- working it out reads the pet's spellbook and every ability of its family. So it's kept as
-- Training.Read is, until the pet, its level, its training points or what the game says it
-- knows change.
local PetNow
function Training.Pet()
    if keptPet == nil then keptPet = PetNow() or false end
    return keptPet or nil
end

function PetNow()
    local _, _, classID = UnitClass("player")
    local source = ns.SpellData[classID]
    if not (source and source.families) then return nil end
    NotePet(source)
    local pet = type(ns.char.pet) == "table" and ns.char.pet or nil
    if not pet then return { none = true } end
    local here = PetFamily(source) == pet.family
    local beast = type(ns.char.beastTraining) == "table" and ns.char.beastTraining or nil
    -- Beast Training's rows by name and rank, the rank by its digits: the window words it in the
    -- client's language, the spell list ships it as a number.
    local listed = Training.ByRank(beast and beast.rows)
    local skips = type(ns.char.trainingSkips) == "table" and ns.char.trainingSkips or {}
    local free
    if here and C_PetInfo and C_PetInfo.GetPetTrainingPoints then
        local total, used = Compat.Plains(C_PetInfo.GetPetTrainingPoints())
        free = tonumber(total) and math.max(0, total - (tonumber(used) or 0)) or nil
    end
    -- The game says how many are free only while the pet is out. With it away, the last count
    -- seen with it out stands, for the same pet: with nothing to go on, abilities it couldn't
    -- afford were ready and joined the visit, while on a flight say. It can only gain points while
    -- out.
    if here and free then
        ns.char.petFree = { family = pet.family, name = pet.name, free = free }
    elseif not here then
        local seen = type(ns.char.petFree) == "table" and ns.char.petFree or nil
        if seen and seen.family == pet.family and seen.name == pet.name then free = tonumber(seen.free) end
    end

    -- Each ability's ranks, lowest first.
    local abilities, order = {}, {}
    for _, list in ipairs({ source.families[pet.family] or {}, source.families["*"] or {} }) do
        for _, entry in ipairs(list) do
            local name, icon = Compat.SpellInfo(entry[1])
            if name then
                if not abilities[name] then
                    abilities[name] = { name = name, icon = icon, ranks = {} }
                    order[#order + 1] = name
                end
                local ranks = abilities[name].ranks
                ranks[#ranks + 1] = { pet = entry[1], beast = entry[2], level = entry[3], rank = entry[4] }
            end
        end
    end

    local rows = {}
    for _, name in ipairs(order) do
        local a = abilities[name]
        table.sort(a.ranks, function(x, y) return x.level < y.level end)
        local knownAt = 0
        for i, r in ipairs(a.ranks) do
            if pet.known[r.pet] then knownAt = i end
        end
        -- The best rank to teach now, else the next one up.
        local row = { name = name, icon = a.icon }
        for i = #a.ranks, knownAt + 1, -1 do
            local r = a.ranks[i]
            local entry = listed[RankKey(name, r.rank > 0 and r.rank or nil)]
            local have = entry or IsPlayerSpell(r.beast)
            if have and (pet.level or 0) >= r.level then
                row.state, row.spell, row.points = "ready", r, entry and entry.points
                local points = tonumber(row.points)
                if free and points and points > free then row.state, row.short = "points", points - free end
                break
            end
        end
        if not row.state then
            local r = a.ranks[knownAt + 1]
            if not r then
                row.state, row.spell = "known", a.ranks[#a.ranks]
            else
                local entry = listed[RankKey(name, r.rank > 0 and r.rank or nil)]
                row.spell, row.points = r, entry and entry.points
                if entry or IsPlayerSpell(r.beast) then
                    row.state = "level"
                elseif (source.petTrainer or {})[r.beast] then
                    -- Sold by a pet trainer (Great Stamina, Growl...), not tamed.
                    row.state = "trainer"
                else
                    row.state = beast and "tame" or "unchecked"
                end
            end
        end
        row.skipped = skips[row.spell.pet] == true
        rows[#rows + 1] = row
    end
    -- Ready first, then by the level each needs, the known ones last.
    local rank = { ready = 1, points = 1.5, level = 2, trainer = 2, tame = 2, unchecked = 2, known = 3 }
    table.sort(rows, function(x, y)
        if rank[x.state] ~= rank[y.state] then return rank[x.state] < rank[y.state] end
        if x.spell.level ~= y.spell.level then return x.spell.level < y.spell.level end
        return x.name < y.name
    end)
    return { family = pet.family, name = pet.name, level = pet.level, here = here, free = free,
             seenBeast = beast ~= nil, rows = rows }
end

function Training.Skip(spellID, on)
    ns.char.trainingSkips = type(ns.char.trainingSkips) == "table" and ns.char.trainingSkips or {}
    ns.char.trainingSkips[spellID] = on or nil
    -- A rank held back by a lower one comes back only with it.
    local holder = not on and held[spellID]
    while holder do
        ns.char.trainingSkips[holder] = nil
        holder = held[holder]
    end
    kept, keptPet = nil, nil
end

-- Sorts the spells into what's ready now, coming soon, later and skipped,
-- with the totals for the next visit and the rest of the way to 60.
function Training.Sort(data, level)
    local out = { now = {}, soon = {}, later = {}, skipped = {}, nowCost = 0, nowUnknown = 0, restCost = 0, restUnknown = 0 }
    for _, spell in ipairs(data.spells) do
        if not spell.known then
            if spell.skipped then
                out.skipped[#out.skipped + 1] = spell
            else
                if spell.level <= level then
                    out.now[#out.now + 1] = spell
                    if spell.cost then out.nowCost = out.nowCost + spell.cost else out.nowUnknown = out.nowUnknown + 1 end
                elseif spell.level <= level + Training.SOON then
                    out.soon[#out.soon + 1] = spell
                else
                    out.later[#out.later + 1] = spell
                end
                if spell.cost then out.restCost = out.restCost + spell.cost else out.restUnknown = out.restUnknown + 1 end
            end
        end
    end
    return out
end
