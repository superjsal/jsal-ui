-- Where a recipe comes from, by name: the vendor who sells it and for how
-- much, the quest that gives it, or the mob that drops it. The profession
-- panel's "Not learned yet" list uses it for the line under each recipe, the
-- tooltip and the map pin. The data is in RecipeSources.lua.
local _, ns = ...
local Compat = ns.Compat

local Sources = {}
ns.RecipeSourceText = Sources

local SIDE = { Alliance = 1, Horde = 2 }
local OTHER = { [1] = "Horde", [2] = "Alliance" }

local function Data() return ns.RecipeSources end

-- A zone's name from its area ID, as the game names it.
function Sources.Area(area)
    if not area or area <= 0 then return nil end
    local name = C_Map and C_Map.GetAreaInfo and Compat.Plain(C_Map.GetAreaInfo(area))
    return name ~= "" and name or nil
end

local function With(name, area)
    local zone = Sources.Area(area)
    return zone and (name .. ", " .. zone) or name
end

-- A recipe's quest as a line, and whether your side can take it.
local function Quest(entry, faction)
    if not entry.q then return nil, false end
    local side, theirs = SIDE[faction], entry.q[3] or 0
    return "Quest: " .. With(entry.q[1], entry.q[2]), theirs == 0 or not side or theirs == side
end

local function OtherSide(faction) return OTHER[SIDE[faction]] or "other side" end

-- The vendors that sell a recipe to your side, the ones that never run out
-- first and then the cheapest, and how many sell it only to the other side.
function Sources.Vendors(spell, faction)
    local data = Data()
    local entry = data and data.recipes[spell]
    local mine, others = {}, 0
    if not (entry and entry.v) then return mine, others end
    local side = SIDE[faction]
    for i = 1, #entry.v, 3 do
        local npc = data.npcs[entry.v[i]]
        if npc then
            if npc[3] == 0 or not side or npc[3] == side then
                mine[#mine + 1] = { id = entry.v[i], name = npc[1], area = npc[2], map = npc[4], x = npc[5], y = npc[6],
                                    copper = entry.v[i + 1], stock = entry.v[i + 2] }
            else
                others = others + 1
            end
        end
    end
    table.sort(mine, function(a, b)
        local la, lb = a.stock > 0, b.stock > 0
        if la ~= lb then return lb end
        if a.copper ~= b.copper then return a.copper < b.copper end
        return a.id < b.id
    end)
    return mine, others
end

-- How a recipe is come by, for sorting the ones not learned yet: "vendor"
-- (someone sells it to your side for coin alone; that vendor comes back
-- too), "other" (only the other side can get it), or "hard" (a drop, a
-- quest, a vendor who wants a standing or another currency, or nothing
-- known).
function Sources.Kind(spell, faction)
    local data = Data()
    local entry = data and data.recipes[spell]
    if not entry then return "hard" end
    local mine, others = Sources.Vendors(spell, faction)
    if entry.n == nil then
        for _, v in ipairs(mine) do
            if v.copper > 0 then return "vendor", v end
        end
    end
    if mine[1] then return "hard" end
    local quest, open = Quest(entry, faction)
    if (quest and open) or entry.d or entry.w then return "hard" end
    if others > 0 or quest then return "other" end
    return "hard"
end

-- The one line under a recipe: the first thing you can act on. Nil when
-- the data has nothing more exact than the kind of source.
function Sources.Line(spell, faction)
    local data = Data()
    local entry = data and data.recipes[spell]
    if not entry then return nil end
    local mine, others = Sources.Vendors(spell, faction)
    if mine[1] then
        local v = mine[1]
        local line = "Sold by " .. With(v.name, v.area)
        if v.copper > 0 then line = line .. " · " .. Compat.Money(v.copper) end
        if v.stock > 0 then line = line .. " · limited" end
        if #mine > 1 then line = line .. (" · +%d more"):format(#mine - 1) end
        return line
    end
    local quest, open = Quest(entry, faction)
    if quest and open then return quest end
    if entry.d then return "Drops from " .. With(entry.d[1], entry.d[2]) end
    if entry.w then return "World drop" end
    if others > 0 then return ("Sold to the %s only"):format(OtherSide(faction)) end
    if quest then return ("From a %s quest only"):format(OtherSide(faction)) end
    return nil
end

-- The note under a step of the road whose pattern has to be bought: who
-- sells it to you, where and for how much; or, when no vendor sells it to
-- your side, the quest or drop it comes from. Nil with the switch off or
-- nothing known, so the road keeps its plain note.
function Sources.BuyNote(spell)
    if not (ns.ProfWindow and ns.ProfWindow.On("sources")) then return nil end
    local faction = UnitFactionGroup and UnitFactionGroup("player") or nil
    local v = Sources.Vendors(spell, faction)[1]
    if not v then return Sources.Line(spell, faction) end
    local note = "Buy the pattern from " .. With(v.name, v.area)
    if v.copper > 0 then note = note .. " · " .. Compat.Money(v.copper) end
    if v.stock > 0 then note = note .. " · limited" end
    return note
end

-- Everything known about a recipe's sources, for its tooltip.
function Sources.Tooltip(tooltip, spell, faction)
    local data = Data()
    local entry = data and data.recipes[spell]
    if not entry then return false end
    local mine, others = Sources.Vendors(spell, faction)
    local added = false
    local function Add(text, r, g, b)
        tooltip:AddLine(text, r or 0.85, g or 0.84, b or 0.81, true)
        added = true
    end
    for i, v in ipairs(mine) do
        if i > 6 then Add(("and %d more vendors"):format(#mine - 6), 0.6, 0.59, 0.53); break end
        local line = "Sold by " .. With(v.name, v.area)
        if v.copper > 0 then line = line .. " · " .. Compat.Money(v.copper) end
        if v.stock > 0 then line = line .. (" · only %d in stock"):format(v.stock) end
        Add(line)
    end
    if not mine[1] and others > 0 then
        Add(("Sold to the %s only"):format(OtherSide(faction)), 0.6, 0.59, 0.53)
    end
    local quest, open = Quest(entry, faction)
    if quest and open then
        Add(quest)
    elseif quest then
        Add(("From a %s quest only"):format(OtherSide(faction)), 0.6, 0.59, 0.53)
    end
    if entry.d then Add("Drops from " .. With(entry.d[1], entry.d[2])) end
    if entry.w then Add("World drop") end
    return added
end

-- Puts the map pin on the first vendor who sells it to you. False when
-- there's no vendor, or no spot is known for them.
function Sources.Pin(spell, faction)
    local v = Sources.Vendors(spell, faction)[1]
    if not (v and v.map and v.map > 0 and v.x) then return false end
    local set = ns.Waypoint and ns.Waypoint.Set or function(map, x, y) return Compat.SetWaypoint(map, x, y) end
    local zone = Sources.Area(v.area) or "?"
    if set(v.map, v.x / 100, v.y / 100, v.name, "vendor") then
        ns.Print(("Map pin set on %s, %s."):format(v.name, zone))
    else
        ns.Print(("%s is at %.0f, %.0f in %s."):format(v.name, v.x, v.y, zone))
    end
    return true
end
