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

-- Who a saved trainer is and where, from the record or, for older saves,
-- from its "Name @ Zone" key.
local function Where(key, trainer)
    local npc, zone = trainer.npc, trainer.zone
    if not npc then npc, zone = key:match("^(.-) @ ([^(]+)") end
    zone = zone and strtrim(zone) or nil
    return npc and zone and (npc .. ", " .. zone) or npc or key
end

-- Sorts the saved trainers for this class into class trainers, pet trainers
-- and weapon masters, by what their lists teach, and gathers each one's
-- prices. A pet trainer opens the same window as a class trainer, but what
-- it lists are pet abilities.
local function Trainers(classID, classSpells, classNames, weaponIDs, weaponNames, beastByName)
    local prices = { bySpell = {}, byName = {}, listed = {}, haveTrainer = false, weapons = {}, pet = {} }
    for key, trainer in pairs(type(ns.db.trainers) == "table" and ns.db.trainers or {}) do
        if trainer.class == classID and type(trainer.rows) == "table" then
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
                    end
                    prices.byName[(row.name or "") .. "|" .. (row.rank or "")] = row.cost
                end
            else
                for _, row in ipairs(trainer.rows) do
                    local id = (row.spell and weaponIDs[row.spell] and row.spell) or weaponNames[row.name or ""]
                    if id then
                        prices.weapons[id] = { cost = row.cost, where = Where(key, trainer) }
                    end
                    local pet = beastByName[(row.name or "") .. "|" .. (row.rank or "")]
                    if pet then
                        prices.pet[pet] = { cost = row.cost, level = row.level, learned = row.category == "used" }
                    end
                end
            end
        end
    end
    return prices
end

-- Grimoire prices by the ability and rank they teach, from every demon
-- trainer saved for this class ("Grimoire of Firebolt (Rank 2)").
local function Grimoires(classID)
    local out = {}
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
    -- A hunter's pet abilities by name and rank, as a pet trainer lists them.
    local beastByName = {}
    for _, entry in ipairs(source.beast or {}) do
        local name = Compat.SpellInfo(entry[1])
        if name then beastByName[name .. "|" .. (Rank(entry[1]) or "")] = entry[1] end
    end
    local prices = Trainers(classID, classSpells, classNames, weaponIDs, weaponNames, beastByName)

    -- Race-only spells show only for that race. Races past the first 31 have
    -- no bit to check, so they get only the spells every race learns.
    local _, _, raceID = UnitRace("player")
    local raceBit = raceID and raceID <= 31 and bit.lshift(1, raceID - 1) or 0
    local function ForMyRace(mask)
        return not mask or mask == 0 or bit.band(mask, raceBit) ~= 0
    end

    local skips = type(ns.char.trainingSkips) == "table" and ns.char.trainingSkips or {}
    local data = { classID = classID, schools = source.schools, spells = {}, weapons = {}, haveTrainer = prices.haveTrainer }
    for _, entry in ipairs(source.spells) do
        local id, level, school, race = entry[1], entry[2], entry[3], entry[4]
        local name, icon = Compat.SpellInfo(id)
        if name and ForMyRace(race) and (not prices.haveTrainer or prices.listed[id] or IsPlayerSpell(id)) then
            local rank = Rank(id)
            data.spells[#data.spells + 1] = {
                id = id, level = level, school = school, name = name, icon = icon, rank = rank,
                cost = prices.bySpell[id] or prices.byName[name .. "|" .. (rank or "")],
                known = IsPlayerSpell(id), skipped = skips[id] == true,
            }
        end
    end
    for _, id in ipairs(source.weapons) do
        local name, icon = Compat.SpellInfo(id)
        if name then
            local taught = prices.weapons[id]
            data.weapons[#data.weapons + 1] = {
                id = id, name = name, icon = icon, known = IsPlayerSpell(id),
                cost = taught and taught.cost, where = taught and taught.where,
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
    local grimoires = Grimoires(classID)
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

-- Demon abilities are the demon's, not yours, so the game only says what the
-- demon out right now knows. Each time one is summoned, what it knows is
-- noted for this character.
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PET_BAR_UPDATE")
watcher:RegisterEvent("UNIT_PET")
watcher:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_PET" and unit ~= "player" then return end
    local _, _, classID = UnitClass("player")
    local source = ns.SpellData and ns.SpellData[classID]
    if not (source and source.demons and ns.char) then return end
    ns.char.petKnown = type(ns.char.petKnown) == "table" and ns.char.petKnown or {}
    for _, demon in ipairs(source.demons) do
        for _, entry in ipairs(demon.spells) do
            if IsSpellKnown(entry[1], true) then ns.char.petKnown[entry[1]] = true end
        end
    end
end)

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
