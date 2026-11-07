-- The gear plan's thinking: for each of your gear slots, what you wear and
-- the items near your level that would be better for your spec. Items come
-- from GearData (Wowhead Forever's gear lists, with where each comes from);
-- their stats come from the game; "better" is each stat times what WoWSims
-- says a point of it is worth for your spec.
local _, ns = ...

local Gear = ns.NewModule("gear", {
    title = "Gear plan",
    note = "A Gear plan page: your gear slots around your character, with the upgrades near your level for your spec, and where each one comes from.",
})
ns.Gear = Gear

---------------------------------------------------------------------------
-- What each class wears and wields, shared with the dungeon guide. Weapons
-- by the game's weapon types (0 one-handed axe, 1 two-handed axe, 2 bow,
-- 3 gun, 4 one-handed mace, 5 two-handed mace, 6 polearm, 7 one-handed
-- sword, 8 two-handed sword, 10 staff, 13 fist weapon, 15 dagger, 16 thrown,
-- 18 crossbow, 19 wand); armor as the type worn (1 cloth, 2 leather, 3 mail,
-- 4 plate), and from level 40 the next one up for the classes that get it.
---------------------------------------------------------------------------
Gear.CLASS_GEAR = {
    WARRIOR = { weapons = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18 }, armor = 3, at40 = 4, shield = true },
    PALADIN = { weapons = { 0, 1, 4, 5, 6, 7, 8 }, armor = 3, at40 = 4, shield = true },
    HUNTER = { weapons = { 0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 16, 18 }, armor = 2, at40 = 3 },
    SHAMAN = { weapons = { 0, 1, 4, 5, 10, 13, 15 }, armor = 2, at40 = 3, shield = true },
    ROGUE = { weapons = { 2, 3, 4, 7, 13, 15, 16, 18 }, armor = 2 },
    DRUID = { weapons = { 4, 5, 10, 13, 15 }, armor = 2 },
    PRIEST = { weapons = { 4, 10, 15, 19 }, armor = 1 },
    MAGE = { weapons = { 7, 10, 15, 19 }, armor = 1 },
    WARLOCK = { weapons = { 7, 10, 15, 19 }, armor = 1 },
}
local WEAPON, ARMOR, SHIELD, CLOAK = 2, 4, 6, 16

-- Whether an item is for a class at a level: a weapon it wields, armor of
-- the type it wears, or anything anyone wears (cloaks, rings, necklaces,
-- trinkets, off-hand items). Nil when not known.
function Gear.ForClass(classFile, level, itemClass, subclass, slot)
    if not itemClass then return nil end
    local gear = Gear.CLASS_GEAR[classFile or ""]
    if not gear then return true end
    if itemClass == WEAPON then
        for _, kind in ipairs(gear.weapons) do if kind == subclass then return true end end
        return false
    end
    if itemClass == ARMOR then
        if subclass == SHIELD then return gear.shield == true end
        if slot == CLOAK or slot == "INVTYPE_CLOAK" or not subclass or subclass < 1 or subclass > 4 then return true end
        local wears = (gear.at40 and (level or 1) >= 40) and gear.at40 or gear.armor
        return subclass == wears
    end
    return true
end

---------------------------------------------------------------------------
-- The slots, as the character pane lays them out: the game's equipment
-- slots for what you wear, and the item slots (inventory types) that fit.
---------------------------------------------------------------------------
Gear.SLOTS = {
    { key = "head", label = "Head", equip = { 1 }, types = { 1 }, empty = "HeadSlot" },
    { key = "neck", label = "Neck", equip = { 2 }, types = { 2 }, empty = "NeckSlot" },
    { key = "shoulder", label = "Shoulder", equip = { 3 }, types = { 3 }, empty = "ShoulderSlot" },
    { key = "back", label = "Back", equip = { 15 }, types = { 16 }, empty = "BackSlot" },
    { key = "chest", label = "Chest", equip = { 5 }, types = { 5, 20 }, empty = "ChestSlot" },
    { key = "wrist", label = "Wrist", equip = { 9 }, types = { 9 }, empty = "WristSlot" },
    { key = "hands", label = "Hands", equip = { 10 }, types = { 10 }, empty = "HandsSlot" },
    { key = "waist", label = "Waist", equip = { 6 }, types = { 6 }, empty = "WaistSlot" },
    { key = "legs", label = "Legs", equip = { 7 }, types = { 7 }, empty = "LegsSlot" },
    { key = "feet", label = "Feet", equip = { 8 }, types = { 8 }, empty = "FeetSlot" },
    { key = "finger", label = "Finger", equip = { 11, 12 }, types = { 11 }, empty = "Finger0Slot" },
    { key = "trinket", label = "Trinket", equip = { 13, 14 }, types = { 12 }, empty = "Trinket0Slot" },
    { key = "main", label = "Main hand", equip = { 16 }, types = { 13, 17, 21 }, empty = "MainHandSlot", dps = "mh" },
    { key = "off", label = "Off hand", equip = { 17 }, types = { 14, 22, 23 }, empty = "SecondaryHandSlot", dps = "oh" },
    { key = "ranged", label = "Ranged", equip = { 18 }, types = { 15, 25, 26 }, empty = "RangedSlot", dps = "ranged" },
}

-- How far below and above your level an item may be: below, it's likely
-- outgrown; just above, it's coming soon (its level shows in red).
Gear.BELOW, Gear.ABOVE = 12, 3

---------------------------------------------------------------------------
-- Your spec: chosen on the page, else the talent tree with the most points.
---------------------------------------------------------------------------
local function ClassFile()
    local _, classFile = UnitClass("player")
    return classFile
end

-- Your class's three talent trees, with the points you've spent in each,
-- from the Build Planner's reading of your talents.
function Gear.Trees()
    local trees = {}
    local data
    if ns.TalentTree and ns.TalentTree.Read then
        local ok, read = pcall(ns.TalentTree.Read)
        data = ok and read or nil
    end
    for i = 1, 3 do
        local tree = data and data.trees[i]
        local points = 0
        for _, id in ipairs(tree and tree.nodes or {}) do points = points + (data.nodes[id].learned or 0) end
        trees[i] = { name = tree and tree.name or ("Tree " .. i), points = points }
    end
    return trees
end

function Gear.Spec()
    local saved = ns.char and tonumber(ns.char.gearSpec)
    if saved and saved >= 1 and saved <= 3 then return saved end
    local best, most = 1, 0
    for i, tree in ipairs(Gear.Trees()) do
        if tree.points > most then best, most = i, tree.points end
    end
    return best
end

function Gear.SetSpec(i)
    if ns.char then ns.char.gearSpec = i end
end

function Gear.Weights(spec)
    local specs = ns.GearData and ns.GearData.specs[ClassFile() or ""]
    return specs and specs[spec or Gear.Spec()] or nil
end

---------------------------------------------------------------------------
-- Item stats, from the game. An item it hasn't loaded yet comes back nil
-- and is asked for; GET_ITEM_INFO_RECEIVED says when it's in.
---------------------------------------------------------------------------
local function Stats(item)
    local get = (C_Item and C_Item.GetItemStats) or GetItemStats
    if not get then return nil end
    local link = type(item) == "string" and item or ("item:" .. item)
    local ok, stats = pcall(get, link)
    if ok and stats and next(stats) then return stats end
    if type(item) == "number" and C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(item) end
    return nil
end
Gear.Stats = Stats

-- An item's worth for a spec: each stat times its weight, and its weapon
-- damage per second for where it goes.
function Gear.Score(stats, weights, dpsKey)
    if not (stats and weights) then return nil end
    local score = 0
    for key, value in pairs(stats) do
        if key == "ITEM_MOD_DAMAGE_PER_SECOND_SHORT" then
            score = score + value * ((dpsKey and weights.dps[dpsKey]) or 0)
        else
            score = score + value * (weights.stats[key] or 0)
        end
    end
    return score
end

-- The stats an upgrade adds that your spec values, biggest first: "+6 Agi, +4 Sta".
local SHORT = {
    ITEM_MOD_STRENGTH_SHORT = "Str", ITEM_MOD_AGILITY_SHORT = "Agi", ITEM_MOD_STAMINA_SHORT = "Sta",
    ITEM_MOD_INTELLECT_SHORT = "Int", ITEM_MOD_SPIRIT_SHORT = "Spi", ITEM_MOD_ATTACK_POWER_SHORT = "AP",
    ITEM_MOD_RANGED_ATTACK_POWER_SHORT = "RAP", ITEM_MOD_SPELL_POWER_SHORT = "Spell Power",
    ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = "Spell Damage", ITEM_MOD_SPELL_HEALING_DONE_SHORT = "Healing",
    ITEM_MOD_HIT_RATING_SHORT = "Hit", ITEM_MOD_CRIT_RATING_SHORT = "Crit", ITEM_MOD_POWER_REGEN0_SHORT = "MP5",
    ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "Defense", RESISTANCE0_NAME = "Armor",
    ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "DPS",
}
function Gear.Gains(stats, worn, weights, dpsKey)
    if not (stats and weights) then return "" end
    worn = worn or {}
    local list = {}
    for key, value in pairs(stats) do
        local diff = value - (worn[key] or 0)
        local w = key == "ITEM_MOD_DAMAGE_PER_SECOND_SHORT" and ((dpsKey and weights.dps[dpsKey]) or 0) or (weights.stats[key] or 0)
        if diff > 0 and w > 0 and SHORT[key] then list[#list + 1] = { key = key, diff = diff, worth = diff * w } end
    end
    table.sort(list, function(a, b) return a.worth > b.worth end)
    local parts = {}
    for i = 1, math.min(2, #list) do
        local e = list[i]
        local amount = e.key == "ITEM_MOD_DAMAGE_PER_SECOND_SHORT" and ("%.1f"):format(e.diff) or tostring(math.floor(e.diff + 0.5))
        parts[#parts + 1] = "+" .. amount .. " " .. SHORT[e.key]
    end
    return table.concat(parts, ", ")
end

---------------------------------------------------------------------------
-- The items that fit a slot for you, from GearData's text: your class and
-- side, near your level.
---------------------------------------------------------------------------
function Gear.Candidates(slot, level, classFile, classID, side)
    local data = ns.GearData
    local out = {}
    if not data then return out end
    local bit = classID and 2 ^ (classID - 1) or 0
    for _, invType in ipairs(slot.types) do
        local line = data.items[invType]
        for entry in (line or ""):gmatch("[^;]+") do
            local id, req, ilvl, cls, sub, s, reqclass, q, kind, place = entry:match("^(%d+),(%d+),(%d+),(%d+),(-?%d+),(%d+),(%d+),(%d+),(%d+),(%d+)$")
            req, reqclass, s = tonumber(req), tonumber(reqclass), tonumber(s)
            if id and req >= level - Gear.BELOW and req <= level + Gear.ABOVE
                and (s == 0 or s == side)
                and (reqclass == 0 or math.floor(reqclass / bit) % 2 == 1)
                and Gear.ForClass(classFile, level, tonumber(cls), tonumber(sub), invType) then
                out[#out + 1] = { id = tonumber(id), req = req, ilvl = tonumber(ilvl), slotType = invType,
                                  quality = tonumber(q), kind = data.kinds[tonumber(kind)] or "",
                                  place = data.places[tonumber(place)] or "" }
            end
        end
    end
    return out
end

---------------------------------------------------------------------------
-- A slot's plan: what you wear there and the items that would be better,
-- best first. Items whose stats haven't loaded yet are left out until they
-- have (the page repaints when they arrive).
---------------------------------------------------------------------------
local function SideNumber()
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    return faction == "Alliance" and 1 or faction == "Horde" and 2 or 0
end

function Gear.Plan(slot, spec)
    local weights = Gear.Weights(spec)
    local level = UnitLevel("player") or 1
    local _, classFile, classID = UnitClass("player")
    -- What you wear: for rings and trinkets, the weaker of the two, as an
    -- upgrade replaces that one.
    local worn
    for _, equip in ipairs(slot.equip) do
        local link = GetInventoryItemLink and GetInventoryItemLink("player", equip)
        local stats = link and Stats(link) or {}
        local score = link and Gear.Score(stats, weights, slot.dps) or 0
        if not worn or score < worn.score then worn = { link = link, equip = equip, stats = stats, score = score or 0 } end
    end
    local wornID = worn.link and tonumber(worn.link:match("item:(%d+)"))
    local stars = ns.char and type(ns.char.gearStars) == "table" and ns.char.gearStars or {}
    local options, waiting = {}, 0
    for _, c in ipairs(Gear.Candidates(slot, level, classFile, classID, SideNumber())) do
        if c.id ~= wornID then
            local stats = Stats(c.id)
            if not stats then
                waiting = waiting + 1
            else
                local score = Gear.Score(stats, weights, slot.dps) or 0
                if score > worn.score + 0.01 then
                    c.score, c.stats = score, stats
                    c.gains = Gear.Gains(stats, worn.stats, weights, slot.dps)
                    c.soon = c.req > level
                    c.starred = stars[c.id] == true
                    options[#options + 1] = c
                end
            end
        end
    end
    table.sort(options, function(a, b)
        if a.starred ~= b.starred then return a.starred end
        if a.soon ~= b.soon then return not a.soon end
        if a.score ~= b.score then return a.score > b.score end
        return a.id < b.id
    end)
    return { worn = worn, options = options, waiting = waiting }
end

function Gear.ToggleStar(id)
    if not ns.char then return end
    ns.char.gearStars = type(ns.char.gearStars) == "table" and ns.char.gearStars or {}
    ns.char.gearStars[id] = (not ns.char.gearStars[id]) or nil
end

ns.Command("gear", function() if ns.Window then ns.Window.Open("gear") end end)
