-- Where trainers stand, and the nearest one of a kind for you: your
-- faction's, on your continent, by straight-line distance in the game's
-- world positions. The spots ship in TrainerData.lua.
local _, ns = ...
local Compat = ns.Compat

local Trainers = {}
ns.Trainers = Trainers

-- The highest profession rank a trainer teaches (1 Apprentice to 4
-- Artisan), from the title over its head, which is one step above it: an
-- "Expert Leatherworker" teaches up to Journeyman, an "Artisan" one Expert,
-- a "Master" one Artisan. Nil when the title has no such word. The title
-- was read as the rank itself, so at Leatherworking 126 the panel named
-- Fimble Finespindle, Expert Leatherworker, for Expert, and his list has
-- Journeyman and no Expert. (John, 14 Nov 2026, at that trainer: "i also
-- dont see expert leatherworking here".)
--
-- Two kinds of title aren't on that ladder. A specialisation's trainer
-- teaches its own recipes and no rank at all, "Master" in the title or not:
-- a Master Goblin Engineer was named for Artisan Engineering as readily as
-- the Master Engineer. And a "Junior Mining Trainer" teaches Apprentice
-- alone, where a plain "Miner" teaches all four. (Wowhead Forever's Teaches
-- lists, 14 Nov 2026: Nixx Sprocketspring, Oglethorpe Obnoticus, Thorkaf
-- Dragoneye, Jalane Ayrole and Shayis Steelfury teach no rank; Buzzek
-- Bracketswing, Master Engineer, all four; Kelsey Fargo, Junior Mining
-- Trainer, Apprentice; Krunn and Pikkle, Miner, all four.) The second
-- answer is true for a title on the ladder.
local RANK_WORDS = { Journeyman = 1, Expert = 2, Artisan = 3, Master = 4 }
local SPECIALISTS = { "Goblin", "Gnome", "Gnomish", "Dragonscale", "Elemental", "Tribal", "Shadoweave",
                      "Armor Crafter", "Weapon Crafter", "Armorsmith", "Weaponsmith" }
local function TeachesRank(tag)
    if not tag then return nil end
    for _, word in ipairs(SPECIALISTS) do
        if tag:find(word, 1, true) then return 0, false end
    end
    if tag:find("Junior", 1, true) then return 1, false end
    for word, rank in pairs(RANK_WORDS) do
        if tag:find(word, 1, true) then return rank, true end
    end
    return nil
end
Trainers.TeachesRank = TeachesRank

-- What a trainer with no such word in its title teaches, where it isn't
-- everything: Cooking's teach Apprentice and Journeyman and no more (Cook
-- Ghilm, Cooking Trainer; Tomas, Cook; Mudduk, Superior Cook: Wowhead
-- Forever, 14 Nov 2026), so nobody is named for Expert or Artisan Cooking.
local PLAIN = { skill185 = 2 }

local function Friendly(trainer)
    local faction = UnitFactionGroup("player")
    if faction == "Alliance" then return trainer.a end
    if faction == "Horde" then return trainer.h end
    return trainer.a or trainer.h
end
Trainers.Friendly = Friendly

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
    -- A trainer with no rank in its title: where none of a profession's do
    -- (first aid, mining), any of them teaches it, unless PLAIN says less;
    -- where the rest do (a neutral town's plain "Leatherworker"), what it
    -- teaches isn't known, so it's named for nothing past Journeyman.
    local titled = false
    for _, t in ipairs(list) do
        local _, ladder = TeachesRank(t.tag)
        if ladder then titled = true break end
    end
    local plain = titled and 2 or PLAIN[key] or 4
    local best, bestDistance
    for _, t in ipairs(list) do
        if Friendly(t) and (not rank or (TeachesRank(t.tag) or plain) >= rank) then
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
