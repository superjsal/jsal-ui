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

-- WoWSims' weights for a spec. Gear.Weights is these with your own changes
-- on top (Weights.lua); until that loads, it's these.
function Gear.BaseWeights(spec)
    local specs = ns.GearData and ns.GearData.specs[ClassFile() or ""]
    return specs and specs[spec or Gear.Spec()] or nil
end
Gear.Weights = Gear.BaseWeights

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
    if not (tip and get and get(id)) then
        if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
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
function Gear.Lookup(id)
    local data = ns.GearData
    if not (data and id) then return nil end
    local pattern = "^" .. id .. ",(%d+),(%d+),(%d+),(-?%d+),(%d+),(%d+),(%d+),(%d+),(%d+)$"
    for invType, line in pairs(data.items) do
        if line:find(id .. ",", 1, true) then
            for entry in line:gmatch("[^;]+") do
                local req, ilvl, _, _, _, _, q, kind, place = entry:match(pattern)
                if req then return Gear.Entry(data, id, req, ilvl, invType, q, kind, place) end
            end
        end
    end
end

-- Where else an item comes from, from jsal.ui's own data: the profession
-- that makes it, and the dungeon boss that drops it. Built once, when first
-- asked.
local madeBy, droppedBy
local function OtherSources()
    if madeBy then return end
    madeBy, droppedBy = {}, {}
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

function Gear.Candidates(slot, level, classFile, classID, side)
    local data = ns.GearData
    local out = {}
    if not data then return out end
    local bit = classID and 2 ^ (classID - 1) or 0
    local types = slot.types
    -- Once you dual wield, a one-handed weapon fits your off hand too.
    if slot.key == "off" and Gear.DualWields(classFile, level) then
        types = { 14, 22, 23, 13 }
    end
    for _, invType in ipairs(types) do
        local line = data.items[invType]
        for entry in (line or ""):gmatch("[^;]+") do
            local id, req, ilvl, cls, sub, s, reqclass, q, kind, place = entry:match("^(%d+),(%d+),(%d+),(%d+),(-?%d+),(%d+),(%d+),(%d+),(%d+),(%d+)$")
            req, reqclass, s = tonumber(req), tonumber(reqclass), tonumber(s)
            local at = id and Gear.LevelOf(req, tonumber(ilvl))
            local need
            if id and kind == "4" and tonumber(ilvl) - math.max(req, 1) >= 12 then
                need = Gear.SkillNeed(tonumber(id))
                if need then at = math.max(req, Gear.SkillLevel(need.skill)) end
            end
            if id and at >= level - Gear.BELOW and at <= level + Gear.ABOVE
                and (s == 0 or s == side)
                and (reqclass == 0 or math.floor(reqclass / bit) % 2 == 1)
                and (Gear.ForClass(classFile, level, tonumber(cls), tonumber(sub), invType)
                     or Gear.CanWear(classFile, level, tonumber(cls), tonumber(sub)))
                and (kind ~= "2" or not Gear.RewardTaken(tonumber(id))) then
                local e = Gear.Entry(data, id, req, ilvl, invType, q, kind, place)
                e.needs = need or nil
                -- Lighter than you wear: named, so it's a choice you see.
                if not Gear.ForClass(classFile, level, tonumber(cls), tonumber(sub), invType) then
                    e.lighter = Gear.ARMOR_NAMES[tonumber(sub)]
                end
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
    local stars, added = Gear.Starred(), Gear.Added()
    local options, waiting, seen = {}, 0, {}
    local candidates = Gear.Candidates(slot, level, classFile, classID, SideNumber())
    -- Items you added by hand come in wherever they fit, at any level, even
    -- when they aren't better for this spec.
    for id, a in pairs(added) do
        if Fits(slot, a.t, classFile, level) then
            local c = Gear.Lookup(id) or { id = id, req = a.req or 0, kind = "", place = "" }
            c.added = true
            candidates[#candidates + 1] = c
        end
    end
    for _, c in ipairs(candidates) do
        if c.id ~= wornID and not seen[c.id] then
            seen[c.id] = true
            local stats = Stats(c.id)
            if not stats then
                waiting = waiting + 1
            else
                local score = Gear.Score(stats, weights, slot.dps) or 0
                if c.added or score > worn.score + 0.01 then
                    c.score, c.stats = score, stats
                    c.gains = Gear.Gains(stats, worn.stats, weights, slot.dps)
                    c.soon = (c.req or 0) > level
                    c.starred = stars[c.id] == true
                    if c.added and c.kind == "" then c.kind = "Added by you" end
                    options[#options + 1] = c
                end
            end
        end
    end
    -- Items worth less than a quarter of the best one aren't worth listing,
    -- and nor, once anything adds what your spec wants most, are items that
    -- only win on Stamina (a caster's hood for a hunter); starred ones stay.
    -- A main stat is one your spec weighs at least as much as Stamina and
    -- more than a twentieth of its top stat (a hunter's Spell Power and
    -- Intellect barely count), or weapon damage.
    local staWeight = weights and weights.stats.ITEM_MOD_STAMINA_SHORT or 0
    local top = 0
    for _, v in pairs(weights and weights.stats or {}) do top = math.max(top, v) end
    local floor = math.max(staWeight, top * 0.05)
    local function Main(o)
        if not weights then return true end
        for key, value in pairs(o.stats) do
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
    local best, anyMain = 0, false
    for _, o in ipairs(options) do
        best = math.max(best, o.score - worn.score)
        anyMain = anyMain or Main(o)
    end
    local kept = {}
    for _, o in ipairs(options) do
        if o.starred or ((o.score - worn.score) >= best * 0.25 and (Main(o) or not anyMain)) then kept[#kept + 1] = o end
    end
    options = kept
    table.sort(options, function(a, b)
        if a.starred ~= b.starred then return a.starred end
        if a.soon ~= b.soon then return not a.soon end
        if a.score ~= b.score then return a.score > b.score end
        return a.id < b.id
    end)
    return { worn = worn, options = options, waiting = waiting }
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

function Gear:OnEnable()
    local b = Button()
    if b then b:Show() end
    if Gear.StartStars then Gear.StartStars(self) end
end

function Gear:OnDisable()
    if button then button:Hide() end
    if Gear.StopStars then Gear.StopStars(self) end
end
