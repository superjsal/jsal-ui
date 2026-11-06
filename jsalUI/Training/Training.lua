-- Your class's trainer spells: from the game's files (SpellData.lua) for
-- what each level brings, and from the trainer prices jsal.ui saved for
-- what it costs. Once a trainer's list is saved, only spells that trainer
-- teaches are shown, so anything in the files a trainer doesn't offer drops out.
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

-- Prices and the list of what trainers teach, from every class trainer saved
-- for this class: by spell, and by name and rank as a fallback.
local function Prices(classID)
    local bySpell, byName, listed, seen = {}, {}, {}, false
    for _, trainer in pairs(type(ns.db.trainers) == "table" and ns.db.trainers or {}) do
        if trainer.class == classID and type(trainer.rows) == "table" then
            seen = true
            for _, row in ipairs(trainer.rows) do
                if row.spell then
                    bySpell[row.spell] = row.cost
                    listed[row.spell] = true
                end
                byName[(row.name or "") .. "|" .. (row.rank or "")] = row.cost
            end
        end
    end
    return bySpell, byName, listed, seen
end

-- Everything the page needs: each spell with its level, school, name, rank,
-- icon, price (nil when no trainer has shown it yet), whether you know it,
-- and whether you've chosen to skip it.
function Training.Read()
    local _, _, classID = UnitClass("player")
    local source = ns.SpellData[classID]
    if not source then return nil end
    local bySpell, byName, listed, haveTrainer = Prices(classID)
    local skips = type(ns.char.trainingSkips) == "table" and ns.char.trainingSkips or {}
    local data = { classID = classID, schools = source.schools, spells = {}, weapons = {}, haveTrainer = haveTrainer }
    for _, entry in ipairs(source.spells) do
        local id, level, school = entry[1], entry[2], entry[3]
        local name, icon = Compat.SpellInfo(id)
        if name and (not haveTrainer or listed[id] or IsPlayerSpell(id)) then
            local rank = Rank(id)
            data.spells[#data.spells + 1] = {
                id = id, level = level, school = school, name = name, icon = icon, rank = rank,
                cost = bySpell[id] or byName[name .. "|" .. (rank or "")],
                known = IsPlayerSpell(id), skipped = skips[id] == true,
            }
        end
    end
    for _, id in ipairs(source.weapons) do
        local name, icon = Compat.SpellInfo(id)
        if name then
            data.weapons[#data.weapons + 1] = { id = id, name = name, icon = icon, known = IsPlayerSpell(id) }
        end
    end
    return data
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
