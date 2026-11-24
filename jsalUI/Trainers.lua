-- Where trainers stand, and the nearest one of a kind for you: your
-- faction's, on your continent, by straight-line distance in the game's
-- world positions, whatever map each stands on; one on another continent
-- is named only when yours has none. The spots ship in TrainerData.lua.
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
-- Journeyman and no Expert.
--
-- Two kinds of title aren't on that ladder. A specialisation's trainer
-- teaches its own recipes and no rank at all, "Master" in the title or not:
-- a Master Goblin Engineer was named for Artisan Engineering as readily as
-- the Master Engineer. And a "Junior Mining Trainer" teaches Apprentice
-- alone, where a plain "Miner" teaches all four. The second answer is true
-- for a title on the ladder.
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
-- everything: Cooking's and Fishing's teach Apprentice and Journeyman and no
-- more (Expert is a book, Artisan a quest), so nobody is named for Expert or
-- Artisan in either.
local PLAIN = { skill185 = 2, skill356 = 2 }

local function Friendly(trainer)
    local faction = Compat.Faction()
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

-- How far a spot ({ map, x, y }) is from you, as a number to compare: the square of the
-- straight-line distance on your continent, and a very large one for another continent or a
-- spot with no place in the world (inside an instance).
function Trainers.Distance(spot)
    local map, px, py = Compat.PlayerPosition()
    if not map then return 1e9 end
    local here, hx, hy = World(map, px, py)
    local continent, wx, wy = World(spot.map, spot.x, spot.y)
    if continent and here and continent == here then return (wx - hx) ^ 2 + (wy - hy) ^ 2 end
    return 1e9
end

-- Whether a profession's trainer takes a student at a skill. One whose title
-- puts it at the top of the ladder (a "Master", who teaches Artisan) turns
-- away anyone below the skill Artisan is trained at, with no trainer window,
-- whatever else it would teach; the ranks below teach from the first recipe.
local function Takes(trainer, skill)
    if not skill then return true end
    local rank, ladder = TeachesRank(trainer.tag)
    if not (ladder and rank == 4) then return true end
    local ranks = ns.Professions and ns.Professions.RANKS
    return skill >= (ranks and ranks[3] and ranks[3].at or 200)
end
Trainers.Takes = Takes

-- A list of spell IDs as a set, made once and kept on the table that holds the list.
local function Set(holder, field)
    local set = holder[field .. "Set"]
    if not set then
        set = {}
        for _, id in ipairs(holder[field] or {}) do set[id] = true end
        holder[field .. "Set"] = set
    end
    return set
end

-- Whether a trainer teaches a spell: by what players were seen to be taught by
-- it, where it was opened (`teaches`, from EG Link); nil when that isn't known.
-- A class trainer seen selling its class's spells carries what of its class's
-- list (`sells`, kept on the class's list of trainers) it wasn't seen to sell,
-- up to its `top`: `lacks`.
local function Teaches(trainer, spell, sells)
    if type(trainer.teaches) == "table" then return Set(trainer, "teaches")[spell] == true end
    if type(trainer.lacks) ~= "table" then return nil end
    if Set(trainer, "lacks")[spell] then return false end
    if sells and Set(sells, "sells")[spell] then return true end
    return nil
end
Trainers.Teaches = Teaches

-- How many of the spells you need (a set of IDs) a class trainer seen selling
-- its class's spells wasn't seen to sell: none for one never seen.
local function Lacking(trainer, wanted)
    local n = 0
    for _, id in ipairs(trainer.lacks or {}) do
        if wanted[id] then n = n + 1 end
    end
    return n
end

-- What a class trainer is wanted for now: the spells ready for you that a
-- class trainer sells, else the next of them your levels bring; their highest
-- level (your level when there are none), and the spells as a set of IDs (nil
-- when there are none). One read of the Training Planner's list, which is kept
-- until a spell or a level changes.
local function ClassNeed()
    local level = UnitLevel("player") or 1
    local data = ns.Training and ns.Training.Read and ns.Training.Read()
    local ready, soon, now, later = nil, nil, {}, {}
    for _, spell in ipairs(data and data.spells or {}) do
        if not spell.known and not spell.skipped and not spell.via and not spell.source then
            if spell.level <= level then
                ready = math.max(ready or 0, spell.level)
                if spell.id then now[spell.id] = true end
            elseif not soon or spell.level < soon then
                soon, later = spell.level, {}
                if spell.id then later[spell.id] = true end
            elseif spell.level == soon and spell.id then
                later[spell.id] = true
            end
        end
    end
    if ready then return ready, now end
    return soon or level, soon and later or nil
end
Trainers.ClassNeed = ClassNeed

-- The nearest trainer for key ("class3" for hunters, "skill197" for
-- tailoring), teaching at least rank (1 to 4) for a profession, and, given a
-- skill, one who takes a student at it. Given a spell, a trainer players have
-- opened must have been seen to teach it, whatever its title says; one never
-- opened goes by its title. A class trainer with a `top` (a starting area's
-- teaches only the first few levels' spells) is passed over when its top is
-- below the level of what you need from it: rank, for a class, is that
-- level, and is worked out from your spells when not given. And when it is
-- worked out, so are the spells themselves: a class trainer seen not selling
-- one of them (`lacks`) gives way to one who sells them all, however far,
-- and where nobody does, to the one lacking fewest; one never seen selling
-- anything goes by its `top` alone, as before. Returns the trainer
-- ({ npc, name, tag, map, x, y }) or nil.
function Trainers.Nearest(key, rank, skill, spell)
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
    local class = key:find("^class") ~= nil
    local need, wanted = class and rank or nil, nil
    local best, bestDistance, bestLacking
    for _, t in ipairs(list) do
        local seen = spell and Teaches(t, spell, list)
        local fits
        local lacking = 0
        if class then
            if (t.top or t.lacks) and not need then need, wanted = ClassNeed() end
            fits = seen ~= false and (not t.top or t.top >= need)
            if fits and wanted and t.lacks then lacking = Lacking(t, wanted) end
        else
            fits = seen or (seen == nil and (not rank or (TeachesRank(t.tag) or plain) >= rank))
        end
        if Friendly(t) and fits and Takes(t, skill) then
            local continent, wx, wy = World(t.map, t.x, t.y)
            -- Another continent, or no position (an instance), counts as far.
            local d = 1e9
            if continent and here and continent == here then
                d = (wx - hx) ^ 2 + (wy - hy) ^ 2
            end
            if not best or lacking < bestLacking or (lacking == bestLacking and d < bestDistance) then
                best, bestDistance, bestLacking = t, d, lacking
            end
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
