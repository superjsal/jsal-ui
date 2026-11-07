-- Where trainers stand, and the nearest one of a kind for you: your
-- faction's, on your continent, by straight-line distance in the game's
-- world positions. The spots ship in TrainerData.lua.
local _, ns = ...
local Compat = ns.Compat

local Trainers = {}
ns.Trainers = Trainers

-- The highest profession rank a trainer teaches, from the title over its
-- head: "Journeyman Tailor" teaches up to Journeyman.
local RANK_WORDS = { Apprentice = 1, Journeyman = 2, Expert = 3, Artisan = 4, Master = 4 }
local function TeachesRank(tag)
    for word, rank in pairs(RANK_WORDS) do
        if tag and tag:find(word, 1, true) then return rank end
    end
    return 4
end

local function Friendly(trainer)
    local faction = UnitFactionGroup("player")
    if faction == "Alliance" then return trainer.a end
    if faction == "Horde" then return trainer.h end
    return trainer.a or trainer.h
end

-- A spot on a map as a world position: its continent, x and y.
local function World(map, x, y)
    if not (C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
    local continent, pos = C_Map.GetWorldPosFromMapPos(map, CreateVector2D(x, y))
    if not (continent and pos) then return nil end
    local wx, wy = pos:GetXY()
    return continent, wx, wy
end

-- The nearest trainer for key ("class3" for hunters, "skill197" for
-- tailoring), teaching at least rank (1 to 4) for a profession. Returns the
-- trainer ({ npc, name, tag, map, x, y }) or nil.
function Trainers.Nearest(key, rank)
    local list = ns.TrainerData and ns.TrainerData[key]
    if not list then return nil end
    local map, px, py = Compat.PlayerPosition()
    local here, hx, hy
    if map then here, hx, hy = World(map, px, py) end
    local best, bestDistance
    for _, t in ipairs(list) do
        if Friendly(t) and (not rank or TeachesRank(t.tag) >= rank) then
            local continent, wx, wy = World(t.map, t.x, t.y)
            -- Another continent, or no position (an instance), counts as far.
            local d = 1e9
            if continent and here and continent == here then
                d = (wx - hx) ^ 2 + (wy - hy) ^ 2
            end
            if not best or d < bestDistance then best, bestDistance = t, d end
        end
    end
    return best
end

-- The map's name for a trainer's spot.
function Trainers.Zone(trainer)
    local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(trainer.map)
    return info and info.name or nil
end

-- Puts the game's map pin on a trainer, labelled with their name over the
-- navigation marker, or says where they are.
function Trainers.Pin(trainer)
    local set = ns.Waypoint and ns.Waypoint.Set or function(map, x, y) return Compat.SetWaypoint(map, x, y) end
    if not set(trainer.map, trainer.x, trainer.y, trainer.name, "trainer") then
        ns.Print(("%s is at %.0f, %.0f in %s."):format(trainer.name, trainer.x * 100, trainer.y * 100,
            Trainers.Zone(trainer) or "?"))
    else
        ns.Print(("Map pin set on %s, %s."):format(trainer.name, Trainers.Zone(trainer) or "?"))
    end
end
