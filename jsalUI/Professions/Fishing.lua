-- Fishing on the Professions page, worked out from FishingData: where you stand in Fishing, the
-- nearest water where no fish get away from you, what players catch there, what would help, and the
-- road of waters to 300. Everything here is matched by ID (the skill line 356, maps by uiMap, items by
-- item ID): names come from the game. The zones' numbers are the original game's, not yet Forever's.
local _, ns = ...
local Compat = ns.Compat

local Fishing = {}
ns.Fishing = Fishing

local Data = ns.FishingData or { zones = {}, catches = {}, gear = {} }
Fishing.LINE = 356
local COOKING = 185
-- Where the road of waters ends: Fishing's last rank's cap.
Fishing.TOP = 300
-- The slot a fishing pole is held in.
local MAIN_HAND = 16

-- Your Fishing, from the game's list of professions, wherever in it Fishing is: { line, name (the
-- game's), icon, skill, cap, bonus (from your pole, lure and what you wear) }, or nil without it.
local function Places(...) return select("#", ...), { ... } end
function Fishing.Mine()
    local pretend = ns.Pretend and ns.Pretend.Fishing and ns.Pretend.Fishing()
    if pretend then return pretend end
    if not (GetProfessions and GetProfessionInfo) then return nil end
    local count, places = Places(GetProfessions())
    for i = 1, count do
        local index = places[i]
        if index then
            local name, icon, skill, cap, _, _, line, bonus = GetProfessionInfo(index)
            if line == Fishing.LINE then
                return { line = line, name = name or "Fishing", icon = icon, skill = skill or 0, cap = cap or 0,
                         bonus = tonumber(bonus) or 0 }
            end
        end
    end
    return nil
end

-- A zone's numbers: where no fish get away, where it can be fished at all, and whose town it is ("a",
-- "h" or nil). Nil for a zone with no number (Forever's own, an instance).
function Fishing.Zone(map)
    local z = map and Data.zones[map]
    if not z then return nil end
    return z[1], z[2], z[3]
end

-- What players caught in a zone: { total, x, y, list = { { item, share } } }, or nil where nothing
-- was seen caught. `x` and `y` are where they fished from most.
local catchCache = {}
function Fishing.Catches(map)
    local c = map and Data.catches[map]
    if not c then return nil end
    if catchCache[map] then return catchCache[map] end
    local out = { total = c[1], x = c[2], y = c[3], list = {} }
    for i = 4, #c - 1, 2 do out.list[#out.list + 1] = { item = c[i], share = c[i + 1] } end
    catchCache[map] = out
    return out
end

-- The other side's letter: a zone with it is their town.
local function Theirs()
    local faction = Compat.Faction()
    if faction == "Alliance" then return "h" end
    if faction == "Horde" then return "a" end
    return nil
end

-- A zone's place in the world, read once: its continent and where it's fished from (the spot players
-- fished from most, else the map's middle).
local placed = {}
local function Place(map)
    if placed[map] ~= nil then return placed[map] end
    local found = false
    if C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D then
        local c = Fishing.Catches(map)
        local ok, continent, pos = pcall(C_Map.GetWorldPosFromMapPos, map, CreateVector2D(c and c.x or 0.5, c and c.y or 0.5))
        if ok and continent and pos then
            local x, y = pos:GetXY()
            found = { continent = continent, x = x, y = y }
        end
    end
    placed[map] = found
    return found
end

-- How far a zone is from you, to compare: nothing for the zone you're in, the square of the distance
-- on your continent, and a very large number for another continent or where that can't be said.
local function Far(map, here)
    if not here then return 1e9 end
    if map == here.map then return -1 end
    local at = Place(map)
    if not (at and here.continent and at.continent == here.continent) then return 1e9 end
    return (at.x - here.x) ^ 2 + (at.y - here.y) ^ 2
end

-- Where you are: your map and your place in the world, or nil.
function Fishing.Here()
    local map, x, y = Compat.PlayerPosition()
    if not map then return nil end
    local here = { map = map }
    if C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D then
        local ok, continent, pos = pcall(C_Map.GetWorldPosFromMapPos, map, CreateVector2D(x, y))
        if ok and continent and pos then here.continent, here.x, here.y = continent, pos:GetXY() end
    end
    return here
end

-- Every zone you may fish (not the other side's town), nearest first; those as far, the harder water
-- first. `here` is Fishing.Here()'s.
local function Waters(here)
    local theirs, list = Theirs(), {}
    for map, z in pairs(Data.zones) do
        if not theirs or z[3] ~= theirs then
            list[#list + 1] = { map = map, clear = z[1], base = z[2], far = Far(map, here) }
        end
    end
    table.sort(list, function(a, b)
        if a.far ~= b.far then return a.far < b.far end
        if a.clear ~= b.clear then return a.clear > b.clear end
        return a.map < b.map
    end)
    return list
end

-- The water to fish at `skill` (with your pole and lure): the nearest where no fish get away from
-- you. Returns its map, where no fish get away there, and whether none do at your skill: where no
-- water is clear yet, the nearest of the easiest, where fewest get away.
function Fishing.Best(skill, here)
    local list = Waters(here)
    for _, w in ipairs(list) do
        if w.clear <= skill then return w.map, w.clear, true end
    end
    local least
    for _, w in ipairs(list) do
        if not least or w.clear < least.clear then least = w end
    end
    if least then return least.map, least.clear, false end
end

-- The road's waters above `skill`, to the road's end: each number where fish stop getting away, with
-- the zones you may fish there, nearest first.
function Fishing.Signs(skill, here)
    local by, out = {}, {}
    for _, w in ipairs(Waters(here)) do
        if w.clear > skill and w.clear <= Fishing.TOP then
            if not by[w.clear] then
                by[w.clear] = { at = w.clear, zones = {} }
                out[#out + 1] = by[w.clear]
            end
            local zones = by[w.clear].zones
            zones[#zones + 1] = w.map
        end
    end
    table.sort(out, function(a, b) return a.at < b.at end)
    return out
end

-- The road to 300: the waters (`kind` "water") and the ranks still to learn ("rank", with the rank
-- you're learning from and the skill it's learned at), in the order you come to them; at one skill
-- the water first. A rank you can learn now is the first.
function Fishing.Road(skill, cap, here)
    local P = ns.Professions
    local items = {}
    for _, sign in ipairs(Fishing.Signs(skill, here)) do
        items[#items + 1] = { kind = "water", at = sign.at, zones = sign.zones }
    end
    local ranks = P and P.RANKS or {}
    for i, rank in ipairs(ranks) do
        local at = rank.next and P.At(Fishing.LINE, rank)
        if at and rank.cap >= cap then
            items[#items + 1] = { kind = "rank", at = at, rank = rank, index = i }
        end
    end
    table.sort(items, function(a, b)
        if a.at ~= b.at then return a.at < b.at end
        return a.kind == "water" and b.kind ~= "water"
    end)
    return items
end

---------------------------------------------------------------------------
-- What helps: the pole you hold, the lure to use, and the next real upgrades, each with where it
-- comes from. Read from what you wear and carry, at the time asked.
---------------------------------------------------------------------------
local byItem
local function Gear(item)
    if not byItem then
        byItem = {}
        for _, g in ipairs(Data.gear) do byItem[g.item] = g end
    end
    return item and byItem[item]
end
Fishing.Gear = Gear

-- Whether your side may have it: a vendor or a quest giver of one side only.
local function Ours(g)
    if not g.side then return true end
    local theirs = Theirs()
    return theirs == nil or g.side ~= theirs
end

-- The level it can be had from: what it needs to use, or the level its quest is offered from.
local function From(g)
    return math.max(g.level or 0, g.how == "quest" and g.from or 0)
end

-- The pole in your hands, if it's one jsal.ui knows, and whether a lure is on it now.
function Fishing.Held()
    local item = GetInventoryItemID and GetInventoryItemID("player", MAIN_HAND)
    local g = Gear(item)
    local lure = false
    if GetWeaponEnchantInfo then lure = GetWeaponEnchantInfo() and true or false end
    return (g and g.kind == "pole") and g or nil, lure, item
end

-- What helps you now, at `skill` (without bonus) and `level`: up to `most` rows ({ gear, held =
-- "hand" | "bags" | nil, count }), the lure among them (or nil), whether a lure is on now, and the
-- rest worth knowing (for a tooltip).
function Fishing.Helps(skill, level, most)
    most = most or 4
    local pole, lureOn = Fishing.Held()
    local rows, shown = {}, {}
    local function Add(g, held, count)
        rows[#rows + 1] = { gear = g, held = held, count = count }
        shown[g] = true
    end
    -- The pole: in your hands; else the best in your bags; else the plain one, from a vendor.
    if pole then
        Add(pole, "hand")
    else
        local best
        for _, g in ipairs(Data.gear) do
            if g.kind == "pole" and Compat.ItemCount(g.item) > 0 and (not best or g.bonus > best.bonus) then best = g end
        end
        if best then Add(best, "bags") else Add(Gear(6256)) end
    end
    local poleBonus = rows[1].gear.bonus
    -- The lure: the best you carry that your skill can use, unless a vendor sells a better one for
    -- coin, with no limit on how many.
    local held, sold
    for _, g in ipairs(Data.gear) do
        if g.kind == "lure" and (g.skill or 0) <= skill then
            local count = Compat.ItemCount(g.item)
            if count > 0 and (not held or g.bonus > held.gear.bonus) then held = { gear = g, count = count } end
            if g.how == "vendor" and not g.limited and Ours(g) and (not sold or g.bonus > sold.bonus) then sold = g end
        end
    end
    local lure
    if held and (not sold or held.gear.bonus >= sold.bonus) then
        Add(held.gear, "bags", held.count)
        lure = held.gear
    elseif sold then
        Add(sold)
        lure = sold
    end
    -- The poles better than yours that your skill can use and your side can get: the ones you could
    -- have at your level first, the biggest bonus first.
    local better = {}
    for _, g in ipairs(Data.gear) do
        if g.kind == "pole" and g.bonus > poleBonus and (g.skill or 0) <= skill and Ours(g) and not shown[g] then
            better[#better + 1] = g
        end
    end
    table.sort(better, function(a, b)
        local na, nb = From(a) <= level, From(b) <= level
        if na ~= nb then return na end
        if a.bonus ~= b.bonus then return a.bonus > b.bonus end
        return a.item < b.item
    end)
    local slots = most - #rows
    for i = 1, math.min(2, slots) do
        if better[i] then Add(better[i]) end
    end
    -- The rest: what else helps that your side can get, for the tooltip.
    local rest = {}
    for _, g in ipairs(Data.gear) do
        if not shown[g] and Ours(g) and g.bonus > 0 and (g.kind ~= "pole" or g.bonus > poleBonus)
            and (g.kind ~= "lure" or not lure or g.bonus > lure.bonus) then
            rest[#rest + 1] = g
        end
    end
    return rows, lure, lureOn, rest
end

-- What a thing's bonus comes from, as the page says it: "your pole", "your pole and lure", "your
-- lure", or "your gear" for the rest (a hat, boots).
function Fishing.BonusWords(bonus, poleBonus, lureOn)
    if lureOn and (poleBonus or 0) > 0 then return "your pole and lure" end
    if lureOn then return "your lure" end
    if (poleBonus or 0) > 0 and bonus == poleBonus then return "your pole" end
    return "your gear"
end

---------------------------------------------------------------------------
-- The cook tag: the fish Cooking's road needs, from that road as the Professions page works it out.
---------------------------------------------------------------------------
local cooked = { key = nil, needs = {} }

-- The fish (and anything else) Cooking's road to its rank's cap takes, by item: the first step that
-- takes it ({ from, to }). Empty without Cooking. Worked out again only when Cooking's skill, cap or
-- known recipes change.
function Fishing.CookNeeds()
    local P = ns.Professions
    if not (P and P.Mine and P.Plan) then return {} end
    local cook
    for _, p in ipairs(P.Mine()) do
        if p.line == COOKING then cook = p end
    end
    if not cook then return {} end
    local seen = not cook.pretend and P.Remembered(COOKING)
    local set = seen and seen.known
    if not set then
        set = {}
        for _, recipe in ipairs(P.Recipes(COOKING) or {}) do
            if recipe.how == 1 and recipe.learn <= cook.skill then set[recipe.spell] = true end
        end
    end
    local count = 0
    for _ in pairs(set) do count = count + 1 end
    local key = table.concat({ cook.skill, cook.cap, count, seen and "seen" or "trainer" }, ";")
    if cooked.key == key then return cooked.needs end
    local rank = P.Rank(cook.cap)
    local road = P.Plan(COOKING, cook.skill, cook.cap, function(spell) return set[spell] end, P.At(COOKING, rank))
    local needs = {}
    for _, step in ipairs(road or {}) do
        for _, reagent in ipairs(step.recipe and step.recipe.reagents or {}) do
            if not needs[reagent.item] then needs[reagent.item] = { from = step.from, to = step.to } end
        end
    end
    cooked.key, cooked.needs = key, needs
    return needs
end
