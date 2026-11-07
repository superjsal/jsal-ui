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

local function Rank(spellID)
    local text = C_Spell and C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(spellID)
    if not text and GetSpellSubtext then text = GetSpellSubtext(spellID) end
    return text and text ~= "" and text or nil
end

-- Sorts the saved trainers for this class into class trainers, pet trainers
-- and weapon masters, by what their lists teach, and gathers each one's
-- prices. A pet trainer opens the same window as a class trainer, but what
-- it lists are pet abilities.
local KINDS = { available = true, unavailable = true, used = true }

local function Trainers(classID, classSpells, classNames, weaponIDs, weaponNames, petToBeast, beastByName)
    local prices = { bySpell = {}, byName = {}, listed = {}, extra = {}, haveTrainer = false, weapons = {}, pet = {} }
    local trainers = type(ns.db.trainers) == "table" and ns.db.trainers or {}
    -- Weapon skills cost the same at every weapon master, for every class,
    -- so any character's visit prices them.
    -- "?" is Beast Training, saved as a trainer before that was caught.
    for key, trainer in pairs(trainers) do
        if key:find("^%? @ ") then trainers[key] = nil end
    end
    for _, trainer in pairs(trainers) do
        for _, row in ipairs(type(trainer.rows) == "table" and trainer.rows or {}) do
            local id = (row.spell and weaponIDs[row.spell] and row.spell) or weaponNames[row.name or ""]
            if id then prices.weapons[id] = row.cost end
        end
    end
    for _, trainer in pairs(trainers) do
        if trainer.class == classID and type(trainer.rows) == "table" then
            -- Visits saved before Forever's order was known hold the row's
            -- kind where its rank should be.
            for _, row in ipairs(trainer.rows) do
                if KINDS[row.rank] then row.category, row.rank = row.rank, Rank(row.spell or 0) end
            end
            local teachesClass = false
            for _, row in ipairs(trainer.rows) do
                if (row.spell and classSpells[row.spell]) or classNames[row.name or ""] then
                    teachesClass = true
                    break
                end
            end
            if teachesClass then
                prices.haveTrainer = true
                for _, row in ipairs(trainer.rows) do
                    if row.spell then
                        prices.bySpell[row.spell] = row.cost
                        prices.listed[row.spell] = true
                        -- Taught here but not in the class's spell list
                        -- (Parry, Plate Mail, poisons...).
                        if not classSpells[row.spell] then prices.extra[row.spell] = row.level end
                    end
                    prices.byName[(row.name or "") .. "|" .. (row.rank or "")] = row.cost
                end
            else
                for _, row in ipairs(trainer.rows) do
                    -- A pet trainer lists the pet's spell; the price is kept
                    -- under the Beast Training spell that teaches it.
                    local pet = (row.spell and petToBeast[row.spell]) or beastByName[(row.name or "") .. "|" .. (row.rank or "")]
                    if pet then
                        prices.pet[pet] = { cost = row.cost, level = row.level, learned = row.category == "used" }
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

-- Grimoire prices by the ability and rank they teach, from every demon
-- trainer saved for this class ("Grimoire of Firebolt (Rank 2)"), then the
-- ones that ship with jsal.ui.
local function Grimoires(classID, source)
    local out = {}
    for key, cost in pairs(source.grimoires or {}) do out[key] = cost end
    for _, shop in pairs(type(ns.db.grimoires) == "table" and ns.db.grimoires or {}) do
        if shop.class == classID and type(shop.rows) == "table" then
            for _, row in ipairs(shop.rows) do
                local spell, rank = (row.name or ""):match("^Grimoire of (.-) %(Rank (%d+)%)$")
                spell = spell or (row.name or ""):match("^Grimoire of (.+)$")
                if spell then out[spell .. "|" .. (rank or "")] = row.cost end
            end
        end
    end
    return out
end

-- Everything the page needs: each spell with its level, school, name, rank,
-- icon, price (nil when no trainer has shown it yet), whether you know it,
-- and whether you've chosen to skip it; and each weapon skill with its price
-- and who teaches it, once a weapon master has been opened.
function Training.Read()
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
    for _, list in pairs(source.families or {}) do
        for _, entry in ipairs(list) do petToBeast[entry[1]] = entry[2] end
    end
    for _, entry in ipairs(source.beast or {}) do
        local name = Compat.SpellInfo(entry[1])
        if name then beastByName[name .. "|" .. (Rank(entry[1]) or "")] = entry[1] end
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
    local function Known(id, name, rank)
        if IsPlayerSpell(id) or book.ids[id] or trained[id] then return true end
        if not name then return false end
        if trained[name .. "|" .. (rank or "")] then return true end
        local have = book.ranks[name]
        return have ~= nil and have >= (tonumber(rank and rank:match("(%d+)")) or 0)
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
        if name and ForMyRace(race) and (not prices.haveTrainer or prices.listed[id] or shown or IsPlayerSpell(id)) then
            local rank = Rank(id)
            data.spells[#data.spells + 1] = {
                id = id, level = level, school = school, name = name, icon = icon, rank = rank,
                cost = prices.bySpell[id] or prices.byName[name .. "|" .. (rank or "")],
                known = Known(id, name, rank), skipped = skips[id] == true, via = via,
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
    for _, id in ipairs(source.weapons) do
        local name, icon = Compat.SpellInfo(id)
        if name then
            data.weapons[#data.weapons + 1] = {
                id = id, name = name, icon = icon, known = IsPlayerSpell(id), cost = prices.weapons[id],
                skipped = skips[id] == true,
            }
        end
    end

    -- A hunter's pet trainer: only what a pet trainer has listed, as most
    -- pet abilities come from taming instead.
    for id, taught in pairs(prices.pet) do
        local name, icon = Compat.SpellInfo(id)
        if name then
            data.spells[#data.spells + 1] = {
                id = id, level = taught.level or 1, name = name, icon = icon, rank = Rank(id),
                cost = taught.cost, known = IsPlayerSpell(id) or taught.learned,
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
                local rank = Rank(id)
                data.spells[#data.spells + 1] = {
                    id = id, level = level, name = name, icon = icon, rank = rank,
                    cost = grimoires[name .. "|" .. (rank and rank:match("%d+") or "")],
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

-- A hunter's pet as last seen: its family, level and the abilities it knows.
local function NotePet(source)
    local family = UnitExists("pet") and UnitCreatureFamily("pet")
    if not family then return end
    -- The pet's spellbook shows each ability once, at the rank it knows.
    local book = Compat.PetSpellbook()
    local known = {}
    for _, list in ipairs({ source.families[family] or {}, source.families["*"] or {} }) do
        for _, entry in ipairs(list) do
            local name = Compat.SpellInfo(entry[1])
            local rank = entry[4] > 0 and ("Rank " .. entry[4]) or ""
            if IsSpellKnown(entry[1], true) or book[entry[1]] or (name and book[name .. "|" .. rank]) then
                known[entry[1]] = true
            end
        end
    end
    ns.char.pet = { family = family, name = UnitName("pet"), level = UnitLevel("pet"), known = known }
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
end

watcher:SetScript("OnEvent", function(_, event, unit)
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
-- waiting on the pet's level, still to be tamed, or all ranks known. Nil for
-- other classes, or before a pet has been seen.
function Training.Pet()
    local _, _, classID = UnitClass("player")
    local source = ns.SpellData[classID]
    if not (source and source.families) then return nil end
    NotePet(source)
    local pet = type(ns.char.pet) == "table" and ns.char.pet or nil
    if not pet then return { none = true } end
    local here = UnitExists("pet") and UnitCreatureFamily("pet") == pet.family
    local beast = type(ns.char.beastTraining) == "table" and ns.char.beastTraining or nil
    local listed = beast and beast.rows or {}
    local skips = type(ns.char.trainingSkips) == "table" and ns.char.trainingSkips or {}
    local free
    if here and GetPetTrainingPoints then
        local total, spent = GetPetTrainingPoints()
        free = total and (total - (spent or 0)) or nil
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
            local entry = listed[name .. "|" .. (r.rank > 0 and ("Rank " .. r.rank) or "")]
            local have = entry or IsPlayerSpell(r.beast)
            if have and (pet.level or 0) >= r.level then
                row.state, row.spell, row.points = "ready", r, entry and entry.points
                break
            end
        end
        if not row.state then
            local r = a.ranks[knownAt + 1]
            if not r then
                row.state, row.spell = "known", a.ranks[#a.ranks]
            else
                local entry = listed[name .. "|" .. (r.rank > 0 and ("Rank " .. r.rank) or "")]
                row.spell, row.points = r, entry and entry.points
                if entry or IsPlayerSpell(r.beast) then
                    row.state = "level"
                else
                    row.state = beast and "tame" or "unchecked"
                end
            end
        end
        row.skipped = skips[row.spell.pet] == true
        rows[#rows + 1] = row
    end
    -- Ready first, then by the level each needs, the known ones last.
    local rank = { ready = 1, level = 2, tame = 2, unchecked = 2, known = 3 }
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
