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
-- Hunters leave out thrown weapons: one in the ranged slot stops Auto Shot.
---------------------------------------------------------------------------
-- Checked against the game's own files (which skills each class can learn,
-- and when): Forever's rogues also use one-handed axes and its druids
-- polearms. Dual wield is learned at 10 by rogues, at 20 by warriors and
-- hunters, and by shamans through a talent.
Gear.CLASS_GEAR = {
    WARRIOR = { weapons = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18 }, armor = 3, at40 = 4, shield = true, dualWield = 20 },
    PALADIN = { weapons = { 0, 1, 4, 5, 6, 7, 8 }, armor = 3, at40 = 4, shield = true },
    HUNTER = { weapons = { 0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 18 }, armor = 2, at40 = 3, dualWield = 20 },
    SHAMAN = { weapons = { 0, 1, 4, 5, 10, 13, 15 }, armor = 2, at40 = 3, shield = true },
    ROGUE = { weapons = { 0, 2, 3, 4, 7, 13, 15, 16, 18 }, armor = 2, dualWield = 10 },
    DRUID = { weapons = { 4, 5, 6, 10, 13, 15 }, armor = 2 },
    PRIEST = { weapons = { 4, 10, 15, 19 }, armor = 1 },
    MAGE = { weapons = { 7, 10, 15, 19 }, armor = 1 },
    WARLOCK = { weapons = { 7, 10, 15, 19 }, armor = 1 },
}
local WEAPON, ARMOR, SHIELD, CLOAK = 2, 4, 6, 16
local OFF_HAND_WEAPON = 22
local DUAL_WIELD = 674

-- Whether you can carry a weapon in your off hand: the game says, when it's
-- your own class (a shaman's talent included); else by the class's level.
function Gear.DualWields(classFile, level)
    local _, mine = UnitClass("player")
    if classFile == mine and IsPlayerSpell then return IsPlayerSpell(DUAL_WIELD) and true or false end
    local gear = Gear.CLASS_GEAR[classFile or ""]
    return gear ~= nil and gear.dualWield ~= nil and (level or 1) >= gear.dualWield
end

-- Whether an item is for a class at a level: a weapon it wields (in the off
-- hand only once it dual wields), armor of the type it wears, or anything
-- anyone wears (cloaks, rings, necklaces, trinkets, off-hand items). Nil
-- when not known.
function Gear.ForClass(classFile, level, itemClass, subclass, slot)
    if not itemClass then return nil end
    local gear = Gear.CLASS_GEAR[classFile or ""]
    if not gear then return true end
    if itemClass == WEAPON then
        if (slot == OFF_HAND_WEAPON or slot == "INVTYPE_WEAPONOFFHAND") and not Gear.DualWields(classFile, level) then return false end
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

-- Whether a class can wear a piece of armor at all: its own type or any
-- lighter one. The plan offers lighter armor too, when its stats are better
-- for you (a hunter's cloth with Agility, an engineer's cloth goggles).
Gear.ARMOR_NAMES = { "Cloth", "Leather", "Mail", "Plate" }
function Gear.CanWear(classFile, level, itemClass, subclass)
    local gear = Gear.CLASS_GEAR[classFile or ""]
    if not gear or itemClass ~= ARMOR or not subclass or subclass < 1 or subclass > 4 then return false end
    local wears = (gear.at40 and (level or 1) >= 40) and gear.at40 or gear.armor
    return subclass <= wears
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
Gear.BELOW, Gear.ABOVE = 12, 5

-- The level an item belongs to: its required level, or for one with none
-- (some world drops) its item level less five, so it isn't taken as level 1.
function Gear.LevelOf(req, ilvl)
    if req and req > 0 then return req end
    return math.max(1, (ilvl or 1) - 5)
end

-- The game's slot names (an item's equip location) as inventory types.
Gear.INVTYPE = {
    INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3, INVTYPE_CHEST = 5, INVTYPE_ROBE = 20,
    INVTYPE_WAIST = 6, INVTYPE_LEGS = 7, INVTYPE_FEET = 8, INVTYPE_WRIST = 9, INVTYPE_HAND = 10,
    INVTYPE_FINGER = 11, INVTYPE_TRINKET = 12, INVTYPE_WEAPON = 13, INVTYPE_SHIELD = 14,
    INVTYPE_RANGED = 15, INVTYPE_CLOAK = 16, INVTYPE_2HWEAPON = 17, INVTYPE_WEAPONMAINHAND = 21,
    INVTYPE_WEAPONOFFHAND = 22, INVTYPE_HOLDABLE = 23, INVTYPE_THROWN = 25, INVTYPE_RANGEDRIGHT = 26,
}

-- The slot an item of an inventory type goes in (a one-handed weapon: the
-- main hand).
function Gear.SlotOf(invType)
    for _, slot in ipairs(Gear.SLOTS) do
        for _, t in ipairs(slot.types) do
            if t == invType then return slot end
        end
    end
end

-- Whether an item of an inventory type fits a slot, a one-handed weapon in
-- the off hand once you dual wield included.
local function Fits(slot, invType, classFile, level)
    for _, t in ipairs(slot.types) do
        if t == invType then return true end
    end
    return slot.key == "off" and invType == 13 and Gear.DualWields(classFile, level)
end
Gear.Fits = Fits

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

-- With no talent points yet (below level 10), the tree a class usually levels in, not its first:
-- a new paladin was given Holy's healing weights, a new priest Discipline's, a druid Balance's.
-- The weights are still WoWSims' own, for that tree.
local LEVELING_TREE = { PALADIN = 3, PRIEST = 3, SHAMAN = 2, DRUID = 2, ROGUE = 2, MAGE = 3 }

function Gear.Spec()
    local saved = ns.char and tonumber(ns.char.gearSpec)
    if saved and saved >= 1 and saved <= 3 then return saved end
    local best, most = LEVELING_TREE[ClassFile() or ""] or 1, 0
    for i, tree in ipairs(Gear.Trees()) do
        if tree.points > most then best, most = i, tree.points end
    end
    return best
end

function Gear.SetSpec(i)
    if ns.char then ns.char.gearSpec = i end
    Gear.PlansChanged()
end

-- WoWSims' weights for a spec. Gear.Weights is these with your own changes
-- on top (Weights.lua); until that loads, it's these.
function Gear.BaseWeights(spec)
    local specs = ns.GearData and ns.GearData.specs[ClassFile() or ""]
    return specs and specs[spec or Gear.Spec()] or nil
end
Gear.Weights = Gear.BaseWeights

---------------------------------------------------------------------------
-- Item stats, from the game. An item it hasn't loaded yet comes back nil and
-- is asked for; GET_ITEM_INFO_RECEIVED says when it's in.
---------------------------------------------------------------------------
--
-- Forever gives crit, hit, haste, expertise, dodge, parry and block as rating: an item of "1%
-- crit" says ITEM_MOD_CRIT_RATING_SHORT = 14. The weights are per 1%, so those
-- are turned into 1% here, by Forever's own rating for 1% at 60.
local PER_PERCENT = {
    ITEM_MOD_CRIT_RATING_SHORT = 14, ITEM_MOD_CRIT_MELEE_RATING_SHORT = 14, ITEM_MOD_CRIT_SPELL_RATING_SHORT = 14,
    ITEM_MOD_CRIT_RANGED_RATING_SHORT = 14,
    ITEM_MOD_HIT_RATING_SHORT = 10, ITEM_MOD_HIT_MELEE_RATING_SHORT = 10, ITEM_MOD_HIT_SPELL_RATING_SHORT = 10,
    ITEM_MOD_HIT_RANGED_RATING_SHORT = 10,
    ITEM_MOD_DODGE_RATING_SHORT = 12, ITEM_MOD_PARRY_RATING_SHORT = 15, ITEM_MOD_BLOCK_RATING_SHORT = 5,
    ITEM_MOD_HASTE_RATING_SHORT = 10, ITEM_MOD_EXPERTISE_RATING_SHORT = 10,
}
Gear.PER_PERCENT = PER_PERCENT
-- An item's stats by its ID, kept once the game has given them: they never
-- change, and a redraw asked the game for about 2,000 items' stats every time.
-- Nothing changes a stats table once it's made. Stats by link (what you wear,
-- which can carry a random suffix) are asked for each time.
local statsOf, statsLevel = {}, nil
-- Items asked of the game that haven't arrived: not asked again until
-- GET_ITEM_INFO_RECEIVED says they're in. Each pass asked again for every
-- one still loading, and each arrival brings another pass (the page repaints
-- for them): "working out upgrades" ran 21 times, up to 61 ms. A mark lasts
-- two seconds at most: an item that had already loaded can send no
-- GET_ITEM_INFO_RECEIVED, and one marked for good never showed.
local loading = {}
local RETRY = 2
-- After five asks (about ten seconds) an item that still hasn't come is given
-- up on until the next /reload: some of Wowhead's items the game never sends,
-- and the plan said "checking..." for good.
local TRIES = 5
local tries = {}
function Gear.Arrived(id)
    if id then loading[id], tries[id] = nil, nil end
end
function Gear.GivenUp(id)
    return (tries[id] or 0) >= TRIES
end
-- Whether an item asked for is still waited on: marked, and not past its two seconds.
local function Waiting(id)
    local until_ = loading[id]
    if not until_ then return false end
    local now = GetTime and GetTime()
    if until_ == true or not now or now < until_ then return true end
    loading[id] = nil
    return false
end
local function Mark(id)
    -- Only while the module runs: its event is what clears the mark early.
    if Gear.running then
        loading[id] = GetTime and (GetTime() + RETRY) or true
        tries[id] = (tries[id] or 0) + 1
    end
end
local function Stats(item)
    if type(item) == "number" and (statsOf[item] or Waiting(item) or Gear.GivenUp(item)) then return statsOf[item] end
    local get = (C_Item and C_Item.GetItemStats) or GetItemStats
    if not get then return nil end
    local link = type(item) == "string" and item or ("item:" .. item)
    local ok, stats = pcall(get, link)
    if ok and stats and next(stats) then
        local out = {}
        for key, value in pairs(stats) do
            out[key] = PER_PERCENT[key] and value / PER_PERCENT[key] or value
        end
        if type(item) == "number" then statsOf[item] = out end
        return out
    end
    if type(item) == "number" and C_Item and C_Item.RequestLoadItemDataByID then
        Mark(item)
        C_Item.RequestLoadItemDataByID(item)
    end
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
    -- One school's spell damage ("of Frozen Wrath"), as the game names it.
    ITEM_MOD_ARCANE_DAMAGE_DONE_SHORT = "Arcane Damage", ITEM_MOD_FIRE_DAMAGE_DONE_SHORT = "Fire Damage",
    ITEM_MOD_FROST_DAMAGE_DONE_SHORT = "Frost Damage", ITEM_MOD_HOLY_DAMAGE_DONE_SHORT = "Holy Damage",
    ITEM_MOD_NATURE_DAMAGE_DONE_SHORT = "Nature Damage", ITEM_MOD_SHADOW_DAMAGE_DONE_SHORT = "Shadow Damage",
    ITEM_MOD_SPELL_PENETRATION_SHORT = "Spell Pen", ITEM_MOD_HASTE_RATING_SHORT = "Haste",
    ITEM_MOD_EXPERTISE_RATING_SHORT = "Expertise", ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = "Armor Pen",
    ITEM_MOD_MANA_SHORT = "Mana", ITEM_MOD_HEALTH_SHORT = "Health", ITEM_MOD_FERAL_ATTACK_POWER_SHORT = "Feral AP",
    ITEM_MOD_DODGE_RATING_SHORT = "Dodge", ITEM_MOD_PARRY_RATING_SHORT = "Parry", ITEM_MOD_BLOCK_RATING_SHORT = "Block",
    ITEM_MOD_BLOCK_VALUE_SHORT = "Block Value", ITEM_MOD_EXTRA_ARMOR_SHORT = "Bonus Armor",
}
-- The two changes that count most for your spec, gains (sign 1: "+14 AP,
-- +6 Sta") or losses (sign -1: "-5 Agi, -5 Int").
local function Changes(stats, worn, weights, dpsKey, sign)
    if not (stats and weights) then return "" end
    worn = worn or {}
    local list, keys = {}, {}
    for key in pairs(stats) do keys[key] = true end
    for key in pairs(worn) do keys[key] = true end
    for key in pairs(keys) do
        local diff = ((stats[key] or 0) - (worn[key] or 0)) * sign
        local w = key == "ITEM_MOD_DAMAGE_PER_SECOND_SHORT" and ((dpsKey and weights.dps[dpsKey]) or 0) or (weights.stats[key] or 0)
        if diff > 0 and w > 0 and SHORT[key] then list[#list + 1] = { key = key, diff = diff, worth = diff * w } end
    end
    table.sort(list, function(a, b)
        if a.worth ~= b.worth then return a.worth > b.worth end
        return a.key < b.key
    end)
    local parts = {}
    for i = 1, math.min(2, #list) do
        local e = list[i]
        local amount
        if e.key == "ITEM_MOD_DAMAGE_PER_SECOND_SHORT" then
            amount = ("%.1f"):format(e.diff)
        elseif PER_PERCENT[e.key] then
            amount = (("%.1f"):format(e.diff):gsub("%.0$", "")) .. "%"
        else
            amount = tostring(math.floor(e.diff + 0.5))
        end
        parts[#parts + 1] = (sign > 0 and "+" or "-") .. amount .. " " .. SHORT[e.key]
    end
    return table.concat(parts, ", ")
end

function Gear.Gains(stats, worn, weights, dpsKey)
    return Changes(stats, worn, weights, dpsKey, 1)
end

-- What you'd lose that your spec values: said for a piece that isn't better
-- (one you added, or carry), as the game's own compare does.
function Gear.Losses(stats, worn, weights, dpsKey)
    return Changes(stats, worn, weights, dpsKey, -1)
end

-- A plan's best upgrade: its first option that's better than what you wear. A
-- piece you starred, added or carry comes first whatever it scores, and was
-- tagged "best for you" for it.
function Gear.Best(plan)
    for _, o in ipairs(plan and plan.options or {}) do
        if o.better then return o end
    end
end

---------------------------------------------------------------------------
-- The items that fit a slot for you, from GearData's text: your class and
-- side, near your level.
---------------------------------------------------------------------------
---------------------------------------------------------------------------
-- Profession gear (an engineer's goggles): the skill it needs, from the
-- game's own tooltip ("Requires Engineering (210)"), read once per item and
-- only for crafted pieces whose required level is far below their item level.
-- It belongs to the level you can first train that skill at, not its
-- required level, and shows to everyone, marked for that profession only.
---------------------------------------------------------------------------
local needs = {}
local skillPattern
local function SkillPattern()
    if skillPattern then return skillPattern end
    local text = type(ITEM_MIN_SKILL) == "string" and ITEM_MIN_SKILL or "Requires %s (%d)"
    text = text:gsub("([%(%)%.%[%]%+%-%*%?%^%$])", "%%%1")
    text = text:gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)")
    skillPattern = "^" .. text .. "$"
    return skillPattern
end

-- { name = "Engineering", skill = 210 }, false when it needs none, nil
-- while the game hasn't loaded the item.
function Gear.SkillNeed(id)
    if needs[id] ~= nil then return needs[id] end
    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local tip = C_TooltipInfo and C_TooltipInfo.GetItemByID
    -- Asked once while it loads, as an item's stats are: each pass asked
    -- again for every crafted piece still loading.
    if Waiting(id) then return nil end
    if not (tip and get and get(id)) then
        if C_Item and C_Item.RequestLoadItemDataByID then
            Mark(id)
            C_Item.RequestLoadItemDataByID(id)
        end
        return nil
    end
    local data = tip(id)
    if not (data and data.lines) then return nil end
    local found = false
    for _, line in ipairs(data.lines) do
        local name, skill = (line.leftText or ""):match(SkillPattern())
        if name then
            found = { name = name, skill = tonumber(skill) }
            break
        end
    end
    needs[id] = found
    return found
end

-- The level a profession's skill can first be trained to: Journeyman (to
-- 150) at 10, Expert (to 225) at 20, Artisan at 35.
function Gear.SkillLevel(skill)
    if skill <= 75 then return 1 end
    if skill <= 150 then return 10 end
    if skill <= 225 then return 20 end
    return 35
end

-- Whether you have a profession at a skill.
function Gear.HasSkill(need)
    local P = ns.Professions
    if not (need and P and P.Mine) then return false end
    local ok, mine = pcall(P.Mine)
    for _, p in ipairs(ok and mine or {}) do
        if p.name and p.name:lower() == need.name:lower() and (p.skill or 0) >= need.skill then return true end
    end
    return false
end

-- One of GearData's items as the plan uses it. A drop with no one place
-- to get it is a world drop.
function Gear.Entry(data, id, req, ilvl, invType, q, kind, place)
    local e = { id = tonumber(id), req = tonumber(req), ilvl = tonumber(ilvl), slotType = invType,
                quality = tonumber(q), kind = data.kinds[tonumber(kind)] or "",
                place = data.places[tonumber(place)] or "" }
    if e.kind == "Drop" and e.place == "" then e.kind = "World drop" end
    return e
end

-- One item from GearData by its ID, wherever it fits; nil when it isn't there.
-- What was found for an ID is kept (false for none: most bag items aren't
-- gear), and each call gets an entry of its own, as the plan marks its entries.
local looked = {}
function Gear.Lookup(id)
    local data = ns.GearData
    if not (data and id) then return nil end
    if looked.data ~= data then looked = { data = data } end
    local found = looked[id]
    if found == nil then
        found = Gear.Find(data, id) or false
        looked[id] = found
    end
    if found then return Gear.Entry(data, id, found[1], found[2], found[3], found[4], found[5], found[6]) end
end

-- Where GearData's text has an ID: its required level, item level, slot
-- type, quality, source kind and place, as text; nil when it isn't there.
function Gear.Find(data, id)
    -- Found where it starts, by plain search: going through a slot's items
    -- one by one took about a third of a millisecond an item, and a redraw
    -- looks up every bag item that fits, slot by slot.
    local key = id .. ","
    local pattern = "^" .. key .. "(%d+),(%d+),(%d+),(-?%d+),(%d+),(%d+),(%d+),(%d+),(%d+)$"
    for invType, line in pairs(data.items) do
        local from = 1
        while true do
            local at = line:find(key, from, true)
            if not at then break end
            -- A whole ID: at the line's start or after a ";", not the end of a longer one.
            if at == 1 or line:byte(at - 1) == 59 then
                local stop = line:find(";", at, true)
                local req, ilvl, _, _, _, _, q, kind, place = line:sub(at, (stop or 0) - 1):match(pattern)
                if req then return { req, ilvl, invType, q, kind, place } end
            end
            from = at + 1
        end
    end
end

-- Where else an item comes from, from jsal.ui's own data: the profession
-- that makes it, and the dungeon boss that drops it. Built once, when first
-- asked.
local madeBy, droppedBy, instance
local function OtherSources()
    -- Read once, and again only if the data it was read from is replaced.
    if madeBy and madeBy.from == ns.ProfessionData and droppedBy.from == ns.DungeonLoot then return end
    madeBy, droppedBy = { from = ns.ProfessionData }, { from = ns.DungeonLoot }
    -- The places that are a dungeon or a raid: the dungeon guide's, and the ones Wowhead names that
    -- the guide lists under another name or not at all.
    instance = { ["Ahn'Qiraj"] = true, ["Ruins of Ahn'Qiraj"] = true, ["Naxxramas"] = true, ["Blackrock Spire"] = true,
                 ["The Temple of Atal'Hakkar"] = true }
    for _, d in ipairs(ns.DungeonData or {}) do instance[d.name] = true end
    for _, source in pairs(ns.ProfessionData or {}) do
        if type(source) == "table" and type(source.recipes) == "table" then
            for _, r in ipairs(source.recipes) do
                if r[6] and not madeBy[r[6]] then madeBy[r[6]] = source.name end
            end
        end
    end
    for _, d in ipairs(ns.DungeonData or {}) do
        for _, b in ipairs(d.bosses or {}) do
            for _, drop in ipairs(ns.DungeonLoot and ns.DungeonLoot[b[1]] or {}) do
                if not droppedBy[drop[1]] then droppedBy[drop[1]] = (b[3] or b[2]) .. " · " .. d.name end
            end
        end
    end
end

-- How an item's source reads: "Leatherworking · Crafted, or Gelihast ·
-- Blackfathom Deeps"; a drop says only where; "" when nothing is known.
function Gear.Source(o)
    if o.held then return "In your bags" end
    OtherSources()
    local parts = {}
    local crafted = o.kind == "Crafted" or madeBy[o.id] ~= nil
    if crafted then parts[#parts + 1] = (madeBy[o.id] and (madeBy[o.id] .. " · ") or "") .. "Crafted" end
    local boss = droppedBy[o.id]
    if boss then
        parts[#parts + 1] = boss
    elseif not crafted then
        local kind, place = o.kind or "", o.place or ""
        if kind == "Drop" and place ~= "" then kind = "" end
        local bits = {}
        if kind ~= "" then bits[#bits + 1] = kind end
        if place ~= "" then bits[#bits + 1] = place end
        if #bits > 0 then parts[#parts + 1] = table.concat(bits, " · ") end
    end
    return table.concat(parts, ", or ")
end

-- The kinds of source the Gear plan's filter offers, in the order its chips stand. A world drop
-- comes from anything, anywhere; a zone drop from one creature or one zone out in the world.
Gear.SOURCE_KINDS = {
    { key = "dungeon", label = "Dungeon" }, { key = "quest", label = "Quest" }, { key = "vendor", label = "Vendor" },
    { key = "crafted", label = "Crafted" }, { key = "world", label = "World drop" }, { key = "zone", label = "Zone drop" },
    { key = "unknown", label = "Unknown" },
}

-- Which of those an item is, as a list of keys: it follows Gear.Source, so an item that's crafted
-- and also on a boss's list is both, and "unknown" is exactly the item whose source reads "". Two
-- more that have no chip: "bags" for a piece you hold, "added" for one you added that nothing lists.
function Gear.SourceKinds(o)
    if o.held then return { "bags" } end
    OtherSources()
    local kinds = {}
    local crafted = o.kind == "Crafted" or madeBy[o.id] ~= nil
    if crafted then kinds[#kinds + 1] = "crafted" end
    if droppedBy[o.id] then
        kinds[#kinds + 1] = "dungeon"
    elseif not crafted then
        local kind, place = o.kind or "", o.place or ""
        if kind == "Quest" then
            kinds[1] = "quest"
        elseif kind == "Vendor" then
            kinds[1] = "vendor"
        elseif kind == "World drop" then
            kinds[1] = "world"
        elseif kind == "Added by you" then
            kinds[1] = "added"
        elseif place ~= "" then
            -- A drop with a place: "Gilnid · The Deadmines", or the place alone.
            kinds[1] = instance[place:match(" · (.*)$") or place] and "dungeon" or "zone"
        else
            kinds[1] = kind == "" and "unknown" or "zone"
        end
    end
    return kinds
end

-- A slot's upgrades with only the kinds chosen (`on`: a set of keys; an empty one is all of them),
-- and how many of each kind the slot has. A piece in your bags and one you added always show:
-- they're yours already, whatever is chosen.
function Gear.BySource(options, on)
    local shown, counts = {}, {}
    local any = on and next(on) ~= nil
    for _, o in ipairs(options) do
        local pass = not any or o.held or o.added
        for _, kind in ipairs(Gear.SourceKinds(o)) do
            counts[kind] = (counts[kind] or 0) + 1
            if any and on[kind] then pass = true end
        end
        if pass then shown[#shown + 1] = o end
    end
    return shown, counts
end

-- An upgrade's share of all you wear, as the Gear plan's cards say it: "+3%", "under 1%" for a
-- hair-thin one, nil when there's no share to say. (The dungeon guide adds "for you".)
function Gear.ShareText(share)
    if not share or share <= 0 then return nil end
    local pct = math.floor(share * 100 + 0.5)
    return pct < 1 and "under 1%" or ("+" .. pct .. "%")
end

-- Rewards of quests you've done can't be had again: an item whose one
-- source is a quest carries that quest's ID, read once from GearData.
local questOf
function Gear.QuestOf(id)
    if not questOf then
        questOf = {}
        for item, quest in ((ns.GearData and ns.GearData.quests) or ""):gmatch("(%d+):(%d+)") do
            questOf[tonumber(item)] = tonumber(quest)
        end
    end
    return questOf[id]
end

function Gear.RewardTaken(id)
    local quest = Gear.QuestOf(id)
    if not quest then return false end
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then return C_QuestLog.IsQuestFlaggedCompleted(quest) and true or false end
    return IsQuestFlaggedCompleted and IsQuestFlaggedCompleted(quest) and true or false
end

-- A slot type's items that could be near a level and that you could wear,
-- read out of GearData's text once and kept until the level (or anything else
-- they're checked against) changes. Each redraw read all 11,000 items as text
-- for every slot, then checked each for your class, armor and side, about 23
-- ms of a 61 ms pass in game. A crafted piece's level can rise to its
-- skill's, so one is kept unless its required level is past the window, and
-- its level is worked out where it's used. A row: { id, req, ilvl, q, kind,
-- place (as text), at, crafted, lighter }.
local ROW = "^(%d+),(%d+),(%d+),(%d+),(-?%d+),(%d+),(%d+),(%d+),(%d+),(%d+)$"
local near = {}
local function Near(data, invType, level, classFile, classID, side)
    local line = data.items[invType] or ""
    local key = table.concat({ level, classFile or "", classID or 0, side or 0, Gear.DualWields(classFile, level) and 1 or 0 }, ":")
    local kept = near[invType]
    if kept and kept.key == key and kept.line == line then return kept end
    -- A new level brings other items: the stats kept for the last ones go, once.
    if level ~= statsLevel then statsOf, statsLevel = {}, level end
    kept = { key = key, line = line }
    near[invType] = kept
    local bit = classID and 2 ^ (classID - 1) or 0
    for entry in line:gmatch("[^;]+") do
        local id, req, ilvl, cls, sub, s, reqclass, q, kind, place = entry:match(ROW)
        if id then
            local r, il, rc, c, sb = tonumber(req), tonumber(ilvl), tonumber(reqclass), tonumber(cls), tonumber(sub)
            local at = Gear.LevelOf(r, il)
            local crafted = kind == "4" and il - math.max(r, 1) >= 12
            local mine = Gear.ForClass(classFile, level, c, sb, invType)
            if ((crafted and r <= level + Gear.ABOVE) or (at >= level - Gear.BELOW and at <= level + Gear.ABOVE))
                and (s == "0" or tonumber(s) == side)
                and (rc == 0 or math.floor(rc / bit) % 2 == 1)
                and (mine or Gear.CanWear(classFile, level, c, sb)) then
                -- Lighter than you wear: named, so it's a choice you see.
                kept[#kept + 1] = { id, req, ilvl, q, kind, place, at, crafted, not mine and Gear.ARMOR_NAMES[sb] or nil }
            end
        end
    end
    return kept
end

function Gear.Candidates(slot, level, classFile, classID, side)
    local data = ns.GearData
    local out = {}
    if not data then return out end
    local types = slot.types
    -- Once you dual wield, a one-handed weapon fits your off hand too.
    if slot.key == "off" and Gear.DualWields(classFile, level) then
        types = { 14, 22, 23, 13 }
    end
    for _, invType in ipairs(types) do
        for _, row in ipairs(Near(data, invType, level, classFile, classID, side)) do
            local id, req, ilvl, q, kind, place, at = row[1], row[2], row[3], row[4], row[5], row[6], row[7]
            local need
            if row[8] then
                need = Gear.SkillNeed(tonumber(id))
                if need then at = math.max(tonumber(req), Gear.SkillLevel(need.skill)) end
            end
            if at >= level - Gear.BELOW and at <= level + Gear.ABOVE
                and (kind ~= "2" or not Gear.RewardTaken(tonumber(id))) then
                local e = Gear.Entry(data, id, req, ilvl, invType, q, kind, place)
                e.needs = need or nil
                e.lighter = row[9]
                out[#out + 1] = e
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

-- The two-hander in your main hand, when that's what is there: its link.
function Gear.TwoHander()
    local link = GetInventoryItemLink and GetInventoryItemLink("player", 16)
    if not link then return nil end
    -- The game's quick lookup first: it answers at once for any item,
    -- where the full one can come back empty until the item has loaded.
    local quick = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    local equipLoc = quick and select(4, quick(link))
    if not equipLoc then
        local info = (C_Item and C_Item.GetItemInfo) or GetItemInfo
        equipLoc = info and select(9, info(link))
    end
    return equipLoc == "INVTYPE_2HWEAPON" and link or nil
end

-- Whether a piece is better for you than what you wear where it goes: true (then its gain) or
-- false, or nil when that can't be told (it isn't worn, the game hasn't loaded it, or your spec has
-- no weights). For a dungeon's loot, which has the item's slot, class and subclass from the game. A
-- ring or trinket is measured against the weaker of your two.
--
-- It's the Gear plan's answer: better when it scores more than what you wear, however little, and
-- then how much, as a share of all you wear's score (Gear.WornTotal), so the dungeon guide can say
-- "+16% for you" and a hair-thin upgrade reads as one. It was a share of the one piece it replaces,
-- and a hunter's two-hander, which counts only for its stats, made a polearm "+474%". Before, it
-- had to be a quarter of the best upgrade you could get, which hid a feral druid's Swine Fists, 22%
-- over his gloves; before that, any gain, which called a hunter's Strength legs "better" with
-- nothing to say by how little.
--
-- A dungeon's list asks this of every piece, so a slot's plan is kept. It was kept for the one
-- paint, and working the plans out again was 11 of each boss list's 14 ms in his /jsal perf.
-- Now it's kept until something it's worked out from changes (Gear.PlansChanged: your gear,
-- bags, level, talents, skills, quests, spec, weights or stars), for ten minutes at most. A
-- plan still waiting on items the game hasn't sent is worked out again on the next paint.
Gear.planStamp = 0
function Gear.PlansChanged() Gear.planStamp = Gear.planStamp + 1 end
local PLAN_KEEP = 600
function Gear.SlotPlan(slot)
    local now = GetTime and GetTime()
    local kept = Gear.slotPlans
    if not (kept and now and kept.at and kept.stamp == Gear.planStamp and now - kept.at < PLAN_KEEP) then
        kept = { at = now, stamp = Gear.planStamp }
        Gear.slotPlans = kept
    end
    local plan = kept[slot.key]
    if plan and (plan.waiting or 0) > 0 and plan.madeAt ~= now then plan = nil end
    if not plan then
        plan = Gear.Plan(slot)
        plan.madeAt = now
        kept[slot.key] = plan
    end
    return plan
end

-- What all you wear scores for a spec's weights: each slot's piece, each ring and trinket, its
-- weapon damage for where it goes. Kept for the one paint, as a slot's plan is.
function Gear.WornTotal(weights)
    if not weights then return 0 end
    local now = GetTime and GetTime()
    local kept = Gear.wornTotal
    if kept and now and kept.at == now and kept.weights == weights then return kept.total end
    local total = 0
    for _, slot in ipairs(Gear.SLOTS) do
        for _, equip in ipairs(slot.equip) do
            local link = GetInventoryItemLink and GetInventoryItemLink("player", equip)
            local stats = link and Stats(link)
            if stats then total = total + (Gear.Score(stats, weights, slot.dps) or 0) end
        end
    end
    Gear.wornTotal = { at = now, weights = weights, total = total }
    return total
end

function Gear.Better(id, equipLoc, classID, subclassID)
    local invType = Gear.INVTYPE[equipLoc or ""]
    local slot = invType and Gear.SlotOf(invType)
    if not slot then return nil end
    local classFile, level = ClassFile(), UnitLevel("player") or 1
    if Gear.ForClass(classFile, level, classID, subclassID, invType) == false
        and not Gear.CanWear(classFile, level, classID, subclassID) then return false end
    -- Nothing goes in the off hand under a two-hander.
    if slot.key == "off" and Gear.TwoHander() then return false end
    local weights = Gear.Weights()
    local stats = weights and Stats(id)
    if not stats then return nil end
    for _, equip in ipairs(slot.equip) do
        local link = GetInventoryItemLink and GetInventoryItemLink("player", equip)
        if link and tonumber(link:match("item:(%d+)")) == id then return false end
    end
    local plan = Gear.SlotPlan(slot)
    if not plan.Would then return false end
    return plan.Would(stats)
end

-- The pieces in your bags that go in a slot and that you can wear: their
-- item IDs. A piece you took off, or a quest's reward you've had, is in no
-- list of upgrades to go and get, but it's the easiest one to put on. The
-- bags' wearable pieces, read once for a pass (the same moment) rather
-- than for every slot: 17 reads of every bag item a pass, about 15 ms in
-- game.
local bagsAt, bagItems
local function BagItems()
    local now, C = GetTime and GetTime(), ns.Compat
    if bagItems and now and bagsAt == now then return bagItems end
    bagsAt, bagItems = now, {}
    for bag = 0, 4 do
        for i = 1, C.BagSize(bag) do
            local item = C.BagItem(bag, i)
            local id = item and (item.itemID or (item.hyperlink and tonumber(item.hyperlink:match("item:(%d+)"))))
            local info = id and Gear.Info(id)
            local invType = info and Gear.INVTYPE[info.equipLoc or ""]
            if invType then bagItems[#bagItems + 1] = { id = id, info = info, invType = invType } end
        end
    end
    return bagItems
end

function Gear.Held(slot, classFile, level)
    local out, C = {}, ns.Compat
    if not (C and C.BagSize and C.BagItem and Gear.Info) then return out end
    for _, b in ipairs(BagItems()) do
        local info, invType = b.info, b.invType
        if Fits(slot, invType, classFile, level)
            and (Gear.ForClass(classFile, level, info.classID, info.subclassID, invType) ~= false
                 or Gear.CanWear(classFile, level, info.classID, info.subclassID)) then
            out[#out + 1] = b.id
        end
    end
    return out
end

-- How long each part of the plans took in one pass, added up over the slots,
-- for /jsal perf (the page clears it before a pass and reads it after). In
-- game a pass took up to 63 ms where the same work takes 9 ms on a stand-in,
-- so the parts are timed where they run.
Gear.spent = {}
local function Spent(part, started)
    local now = debugprofilestop()
    Gear.spent[part] = (Gear.spent[part] or 0) + now - started
    return now
end

function Gear.Plan(slot, spec, only)
    -- With a two-hander in the main hand, nothing can go in the off hand,
    -- so nothing is better for it: the plan read the hand as empty and
    -- offered every off-hand piece as an upgrade. `twoHand` is the
    -- two-hander's link.
    if slot.key == "off" then
        local both = Gear.TwoHander()
        if both then return { worn = { stats = {}, score = 0 }, options = {}, waiting = 0, twoHand = both } end
    end
    local t = debugprofilestop()
    local weights = Gear.Weights(spec)
    local level = UnitLevel("player") or 1
    local _, classFile, classID = UnitClass("player")
    -- What you wear: for rings and trinkets, the weaker of the two, as an
    -- upgrade replaces that one; or the one place asked for (`only`), when
    -- the page gives each ring and trinket its own row.
    local worn
    for _, equip in ipairs(only and { only } or slot.equip) do
        local link = GetInventoryItemLink and GetInventoryItemLink("player", equip)
        local stats = link and Stats(link) or {}
        local score = link and Gear.Score(stats, weights, slot.dps) or 0
        if not worn or score < worn.score then worn = { link = link, equip = equip, stats = stats, score = score or 0 } end
    end
    local wornID = worn.link and tonumber(worn.link:match("item:(%d+)"))
    t = Spent("weights and what you wear", t)
    local stars, added = Gear.Starred(), Gear.Added()
    local options, waiting, seen = {}, 0, {}
    local candidates = Gear.Candidates(slot, level, classFile, classID, SideNumber())
    t = Spent("the items near your level", t)
    -- Items you added by hand come in wherever they fit, at any level, even
    -- when they aren't better for this spec.
    for id, a in pairs(added) do
        if Fits(slot, a.t, classFile, level) then
            local c = Gear.Lookup(id) or { id = id, req = a.req or 0, kind = "", place = "" }
            c.added = true
            candidates[#candidates + 1] = c
        end
    end
    -- What's in your bags that goes here, whatever its level or where it
    -- came from: you can put it on now.
    local held = {}
    for _, id in ipairs(Gear.Held(slot, classFile, level)) do
        if not held[id] then
            held[id] = true
            candidates[#candidates + 1] = Gear.Lookup(id) or { id = id, req = 0, kind = "", place = "" }
        end
    end
    t = Spent("your bags and added items", t)
    local asking = 0
    for _, c in ipairs(candidates) do
        if c.id ~= wornID and not seen[c.id] then
            seen[c.id] = true
            c.held = held[c.id] or nil
            -- One you added counts as added wherever it comes first: the plan's own copy, no
            -- better than yours, was dropped, and the added one skipped as already seen.
            if added[c.id] then c.added = true end
            local s0 = debugprofilestop()
            local stats = Stats(c.id)
            asking = asking + debugprofilestop() - s0
            if not stats then
                -- One the game never sent, given up on, isn't waited for.
                if not Gear.GivenUp(c.id) then waiting = waiting + 1 end
            else
                local score = Gear.Score(stats, weights, slot.dps) or 0
                if c.added or score > worn.score + 0.01 then
                    c.score, c.stats = score, stats
                    c.better = score > worn.score + 0.01
                    c.gains = Gear.Gains(stats, worn.stats, weights, slot.dps)
                    c.losses = not c.better and Gear.Losses(stats, worn.stats, weights, slot.dps) or nil
                    c.soon = (c.req or 0) > level
                    c.starred = stars[c.id] == true
                    if c.added and c.kind == "" then c.kind = "Added by you" end
                    options[#options + 1] = c
                end
            end
        end
    end
    Gear.spent["item stats"] = (Gear.spent["item stats"] or 0) + asking
    t = Spent("scoring", t + asking)
    -- Any piece that scores more than what you wear is an upgrade, however little; its gain says
    -- how much ("+24% for you"), so a hair-thin one reads as one. Still left out, once anything
    -- adds what your spec wants most: a piece that only wins on Stamina or on what your spec barely
    -- values (Spell Power for a hunter). A main stat is one your spec weighs at least as much as
    -- Stamina and more than a twentieth of its top stat, or weapon damage. The top stat is a
    -- point's: crit, hit and the like are weighed per 1%, a dozen times a point's, and set the bar
    -- so high that a hunter's Attack Power wasn't a main stat.
    local staWeight = weights and weights.stats.ITEM_MOD_STAMINA_SHORT or 0
    local top = 0
    for key, v in pairs(weights and weights.stats or {}) do
        if not PER_PERCENT[key] then top = math.max(top, v) end
    end
    local floor = math.max(staWeight, top * 0.05)
    local function Main(stats)
        if not weights then return true end
        for key, value in pairs(stats) do
            if value > 0 and key ~= "ITEM_MOD_STAMINA_SHORT" then
                if key == "ITEM_MOD_DAMAGE_PER_SECOND_SHORT" then
                    if slot.dps and (weights.dps[slot.dps] or 0) > 0 then return true end
                elseif (weights.stats[key] or 0) >= floor and (weights.stats[key] or 0) > 0 then
                    return true
                end
            end
        end
        return false
    end
    local anyMain = false
    -- How much better each is, as a share of all you wear's score: what the dungeon guide calls
    -- "+16% for you". None for a piece that isn't better (one you added), or when nothing you wear
    -- counts.
    local total = Gear.WornTotal(weights)
    for _, o in ipairs(options) do
        o.unknown = Gear.Source(o) == ""
        anyMain = anyMain or Main(o.stats)
        o.share = (total > 0 and o.score > worn.score + 0.01) and (o.score - worn.score) / total or nil
    end
    -- Whether a piece with these stats is an upgrade, then its gain as a share of all you wear's
    -- score (nil when you wear nothing that counts): for a dungeon's loot, which may not be in the
    -- plan's own lists of items. (See Gear.Better.)
    -- When it scores under what you wear, how much worse comes back with the
    -- no, as a share below nothing: for a piece you starred that what you
    -- wear has since passed.
    local function Would(stats)
        local gain = (Gear.Score(stats, weights, slot.dps) or 0) - worn.score
        if gain <= 0.01 or not (Main(stats) or not anyMain) then
            if gain < -0.01 then
                local total = Gear.WornTotal(weights)
                return false, total > 0 and gain / total or nil
            end
            return false
        end
        local total = Gear.WornTotal(weights)
        return true, total > 0 and gain / total or nil
    end
    local kept = {}
    for _, o in ipairs(options) do
        if o.starred or o.held or o.added or Main(o.stats) or not anyMain then kept[#kept + 1] = o end
    end
    options = kept
    -- One you can go and get now comes before one you can't yet: above your
    -- level, or with no source known (about one item in seven on Wowhead's
    -- lists has none, Forever's new ones among them). Such a piece headed a
    -- slot as its best upgrade with nowhere to send you.
    local function Later(o) return (o.soon or o.unknown) and true or false end
    table.sort(options, function(a, b)
        if a.starred ~= b.starred then return a.starred end
        -- A piece in your bags comes next: nothing is nearer.
        if (a.held or false) ~= (b.held or false) then return a.held == true end
        if Later(a) ~= Later(b) then return not Later(a) end
        if a.score ~= b.score then return a.score > b.score end
        return a.id < b.id
    end)
    Spent("sources and sorting", t)
    return { worn = worn, options = options, waiting = waiting, Would = Would }
end

---------------------------------------------------------------------------
-- Stars: the items you want, kept per character. Items you add by hand are
-- starred too, and kept with their slot: { [item ID] = { t = inventory
-- type, req = required level } }. Unstarring one you added removes it.
---------------------------------------------------------------------------
function Gear.Starred()
    if not ns.char then return {} end
    ns.char.gearStars = type(ns.char.gearStars) == "table" and ns.char.gearStars or {}
    return ns.char.gearStars
end

function Gear.Added()
    if not ns.char then return {} end
    ns.char.gearAdded = type(ns.char.gearAdded) == "table" and ns.char.gearAdded or {}
    return ns.char.gearAdded
end

-- Repaints whatever shows stars (the gear plan, the dungeon guide).
local function StarsChanged()
    Gear.PlansChanged()
    if ns.Window and ns.Window.Refresh then ns.Window.Refresh() end
end

function Gear.ToggleStar(id)
    if not ns.char then return end
    local stars = Gear.Starred()
    stars[id] = (not stars[id]) or nil
    if not stars[id] then Gear.Added()[id] = nil end
    StarsChanged()
end

function Gear.Unstar(id)
    Gear.Starred()[id] = nil
    Gear.Added()[id] = nil
    StarsChanged()
end

ns.Command("gear", function() if ns.Window then ns.Window.Open("gear") end end)

---------------------------------------------------------------------------
-- A button beside the game's character pane (C) that opens the gear plan:
-- jsal.ui's shield in a square, just outside the pane's right edge, on its
-- Character tab only.
---------------------------------------------------------------------------
local button
local function Button()
    local pane = PaperDollFrame or CharacterFrame
    if button or not (pane and CharacterFrame) then return button end
    local Style = ns.Style
    button = CreateFrame("Button", "jsalUIGearPlanButton", pane)
    button:SetSize(34, 34)
    button:SetPoint("TOPLEFT", CharacterFrame, "TOPRIGHT", 4, -36)
    Style.Fill(button, "window")
    local edges = Style.Border(button, "lineStrong")
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", -1, 1)
    icon:SetTexture("Interface\\AddOns\\jsalUI\\Media\\Icons\\gear")
    button:SetScript("OnClick", function() if ns.Window then ns.Window.Open("gear") end end)
    button:SetScript("OnEnter", function(self)
        Style.SetBorder(edges, "gold")
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Gear plan")
        GameTooltip:AddLine("Your best upgrades near your level, and where to get them.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        Style.SetBorder(edges, "lineStrong")
        GameTooltip:Hide()
    end)
    return button
end
Gear.CharacterButton = Button

-- The Gear plan's first open after logging in or a level up filled the lists it keeps (the
-- items near your level, and their stats) all in that one frame: 62 ms in his /jsal perf, the
-- items 25 and their stats 27. They're filled ahead now, a slot every few frames, starting a
-- while after you log in or level, and waiting out a fight. Each slot's plan is kept as its
-- Gear.SlotPlan, which the dungeon guide asks for. The page fills anything still missing.
local WARM_AFTER, WARM_STEP = 8, 0.25
local warmRun = 0
function Gear.Warm(after)
    warmRun = warmRun + 1
    local run, i, Compat = warmRun, 0, ns.Compat
    local function Step()
        if run ~= warmRun or not Gear.running then return end
        if Compat.InCombat() then return Compat.After(5, Step) end
        i = i + 1
        local slot = Gear.SLOTS[i]
        if not slot then return end
        local started = debugprofilestop()
        -- Kept as the dungeon guide's slot plans too, so its first open finds them made.
        xpcall(Gear.SlotPlan, ns.Report, slot)
        ns.Timed("Gear plan, filled ahead: " .. slot.label, started)
        Compat.After(WARM_STEP, Step)
    end
    Compat.After(after or WARM_AFTER, Step)
end

local levels
function Gear:OnEnable()
    local b = Button()
    if b then b:Show() end
    if Gear.StartStars then Gear.StartStars(self) end
    Gear.running = true
    Gear.Warm()
end

function Gear:OnDisable()
    if button then button:Hide() end
    if Gear.StopStars then Gear.StopStars(self) end
    Gear.running = false
end

-- What a slot's plan is worked out from changing: the plans kept between paints go (see
-- Gear.SlotPlan). Heard whether or not the Gear plan is on, as the dungeon guide and the
-- quest reward star ask for plans either way. A new level also fills the lists ahead again,
-- a moment after the event, once the level is the game's.
levels = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "BAG_UPDATE_DELAYED", "PLAYER_LEVEL_UP", "SKILL_LINES_CHANGED",
    "QUEST_TURNED_IN", "CHARACTER_POINTS_CHANGED", "TRAIT_CONFIG_UPDATED", "PLAYER_ENTERING_WORLD" }) do
    levels:RegisterEvent(event)
end
levels:SetScript("OnEvent", function(_, event)
    Gear.PlansChanged()
    if event == "PLAYER_LEVEL_UP" and Gear.running then Gear.Warm(3) end
end)
