-- The Journal's nights and bosses: a NIGHT is one stay in a dungeon or raid, from going in to leaving
-- (back in the same one within half an hour, after a reload, a disconnect or a corpse run, is the same
-- night), with its place, when it began, how long, the bosses killed, wipes, deaths, gold looted, the
-- better items won and who it was with. A BOSS keeps its first kill (when, how long that fight took, who
-- with), its kills, its wipes and its last kill. The Story shows a night as one row with its moments under
-- it; the By boss tab shows the bosses; the Summary at 60 shows the nights since.
--
-- From the game's own boss-fight events (ENCOUNTER_START, ENCOUNTER_END) and where you are (the
-- instance you're in, as you enter a zone). In a dungeon what an event hands over can come hidden: a
-- boss is named from its encounter ID by the dungeon data; with the ID hidden too, nothing is kept for
-- that fight. A groupmate's name that comes hidden is left out and counted.
--
-- Kept for this character only: the last 60 nights, the bosses the dungeon data lists, at most four
-- groupmates' names for a dungeon and two counts for a raid ("24 others, 18 of the guild"). Nothing here
-- is ever sent.
local _, ns = ...
local Compat = ns.Compat
local Journal = ns.Journal

local Nights = {}
Journal.Nights = Nights

Nights.KEPT, Nights.NAMES, Nights.ITEMS, Nights.REJOIN = 60, 4, 8, 30 * 60

---------------------------------------------------------------------------
-- Saved.
---------------------------------------------------------------------------
function Nights.List()
    local j = Journal.Book()
    j.nights = type(j.nights) == "table" and j.nights or {}
    return j.nights
end

function Nights.Bosses()
    local j = Journal.Book()
    j.bosses = type(j.bosses) == "table" and j.bosses or {}
    return j.bosses
end

-- What the pages show: the nights and the bosses, as saved.
function Nights.Data()
    return { nights = Nights.List(), bosses = Nights.Bosses(), since60 = Nights.Since60() }
end

---------------------------------------------------------------------------
-- The dungeon data, by encounter ID and by the instance's map ID (Lower and Upper Blackrock Spire
-- share one map: then the game's own name for it, or the night's first boss, says which).
---------------------------------------------------------------------------
local byBoss, byMap
local function Index()
    if byBoss then return end
    byBoss, byMap = {}, {}
    for _, d in ipairs(ns.DungeonData or {}) do
        if d.map then
            byMap[d.map] = byMap[d.map] or {}
            table.insert(byMap[d.map], d)
        end
        for _, b in ipairs(d.bosses or {}) do byBoss[b[1]] = { dungeon = d, name = b[2], own = b[3] } end
    end
end

-- A boss by its encounter ID: { dungeon, name, own } or nil.
function Nights.Boss(id)
    Index()
    return id and byBoss[id]
end

-- A dungeon or raid by the instance's map ID, and the game's name for it when two share the map.
function Nights.Place(map, name)
    Index()
    local list = map and byMap[map]
    if not list then return nil end
    for _, d in ipairs(list) do if d.name == name then return d end end
    return list[1], #list > 1
end

---------------------------------------------------------------------------
-- Who you're with: up to four names in a dungeon, two counts in a raid. A name the game keeps back
-- is left out and counted.
---------------------------------------------------------------------------
function Nights.Group()
    local n = GetNumGroupMembers and GetNumGroupMembers() or 0
    if n <= 1 then return nil end
    local raid = IsInRaid and IsInRaid()
    local mine = Compat.GuildName()
    local out = { others = 0, guild = 0, hidden = 0 }
    for i = 1, raid and n or n - 1 do
        local unit = (raid and "raid" or "party") .. i
        if not (UnitIsUnit and UnitIsUnit(unit, "player")) then
            out.others = out.others + 1
            if mine and GetGuildInfo and Compat.Plain((GetGuildInfo(unit))) == mine then out.guild = out.guild + 1 end
            if not raid then
                local name = Compat.Name(unit)
                if name then
                    if #out < Nights.NAMES then out[#out + 1] = name end
                else
                    out.hidden = out.hidden + 1
                end
            end
        end
    end
    out.raid = raid and true or nil
    return out
end

-- "with Odrin, Maelis and Fenwick", "with Odrin, Maelis +2", "with 24 others, 18 of Lanternlight".
function Nights.With(w, short)
    if type(w) ~= "table" then return nil end
    if w.raid or #w == 0 then
        if (w.others or 0) == 0 then return nil end
        local guild = (w.guild or 0) > 0 and Compat.GuildName() and (", %d of %s"):format(w.guild, Compat.GuildName()) or ""
        return ("%d other%s%s"):format(w.others, w.others == 1 and "" or "s", guild)
    end
    local names = {}
    for i = 1, #w do names[i] = w[i] end
    local more = (w.others or #names) - #names
    if short then
        local shown = { names[1], names[2] }
        local rest = (w.others or #names) - #shown
        return table.concat(shown, ", ") .. (rest > 0 and (" +" .. rest) or "")
    end
    if more > 0 then return table.concat(names, ", ") .. (" and %d other%s"):format(more, more == 1 and "" or "s") end
    if #names == 1 then return names[1] end
    return table.concat(names, ", ", 1, #names - 1) .. " and " .. names[#names]
end

---------------------------------------------------------------------------
-- Where you are: a night begins as you go into a dungeon or raid, and ends as you leave.
---------------------------------------------------------------------------
local current, fight
function Nights.Current() return current end

-- The Story's row for a night, found once and kept.
local function Event(night)
    if night.ev == nil then return nil end
    local events = Journal.Book().events
    for i = #events, 1, -1 do
        local e = events[i]
        if e.k == "night" and e.night == night.at then return e end
    end
    return nil
end

-- Its row's figures, as the night goes on: the bosses killed, the minutes, when it last was.
local function Mark(night)
    local e = Event(night)
    if not e then return end
    e.b, e.m, e.till = night.kills, math.floor((night.secs or 0) / 60), night.left
end

-- Something happened in the night: it lasts till now, so its row stands over that moment.
local function Touch()
    if current then current.left = Compat.ServerTime() end
end

-- The first fight of a night gives it its row in the Story.
local function Begun(night)
    if night.ev then return Mark(night) end
    night.ev = true
    Journal.Note("night", night.place or "A dungeon", { night = night.at, b = 0, m = 0, till = night.left, raid = night.raid })
    Mark(night)
end

-- A night with no fight in it isn't kept: walking in and out leaves nothing.
local function Forget(night)
    if not night or night.ev then return end
    local list = Nights.List()
    for i = #list, 1, -1 do
        if list[i] == night then table.remove(list, i) end
    end
end

function Nights.Where()
    local inside, kind = false, nil
    if IsInInstance then inside, kind = IsInInstance() end
    inside, kind = Compat.Plain(inside), Compat.Plain(kind)
    if not (inside and (kind == "party" or kind == "raid")) then
        if current then Forget(current) end
        current, fight = nil, nil
        return
    end
    local name, map
    if GetInstanceInfo then
        local n, _, _, _, _, _, _, id = GetInstanceInfo()
        name, map = Compat.Plain(n), Compat.Plain(id)
    end
    local data, shared = Nights.Place(map, name)
    if not shared then name = (data and data.name) or name end
    if current and current.map == map then return end
    if current then Forget(current) end
    local now, list = Compat.ServerTime(), Nights.List()
    local last = list[#list]
    if last and last.map == map and now - (last.left or last.at or 0) <= Nights.REJOIN then
        current = last
        current.left = now
        return
    end
    current = { at = now, place = name, map = map, raid = (kind == "raid" or (data and data.raid)) or nil, secs = 0, kills = 0,
                bosses = {}, wipes = 0, deaths = 0, gold = 0, items = {}, left = now, lv = UnitLevel("player") }
    list[#list + 1] = current
    while #list > Nights.KEPT do table.remove(list, 1) end
end

-- Once a second, from the Journal's own tick: the time inside.
function Nights.Tick(seconds)
    if not current then return end
    current.secs = (current.secs or 0) + (seconds or 0)
    current.left = Compat.ServerTime()
    if current.ev and math.floor(current.secs / 60) ~= math.floor((current.secs - (seconds or 0)) / 60) then Mark(current) end
end

---------------------------------------------------------------------------
-- Boss fights.
---------------------------------------------------------------------------
local function Plainly(v) return v ~= nil end

-- What the game handed over at a fight's end, on a beta build, so a tester can say whether a boss's ID
-- and name come through in a dungeon at 60 (or hidden: then nothing can be kept for it).
local function Said(id, name, won, took)
    if not (ns.IsBeta and ns.IsBeta(ns.version)) then return end
    ns.Print(("Boss fight %s (%s): %s%s."):format(Plainly(id) and tostring(id) or "hidden", Plainly(name) and tostring(name) or "hidden",
        won and "won" or (won == false and "not won" or "result hidden"), took and (", %d:%02d"):format(math.floor(took / 60), math.floor(took % 60)) or ""))
end
Nights.Said = Said

function Nights.Start(id, name)
    id, name = Compat.Plain(id), Compat.Plain(name)
    id = tonumber(id)
    if not id then
        fight = nil
        return
    end
    fight = { id = id, name = name, at = GetTime(), with = Nights.Group() }
    if current and not current.with and fight.with then
        local w = fight.with
        current.with = { others = w.others, guild = w.guild, hidden = w.hidden, raid = w.raid }
        for i = 1, #w do current.with[i] = w[i] end
    end
end

-- A boss's fight over: `success` 1 is a kill, 0 a wipe. Returns the boss's record, or nil when the ID
-- was hidden.
function Nights.End(id, name, success)
    id, name, success = Compat.Plain(id), Compat.Plain(name), Compat.Plain(success)
    id = tonumber(id)
    -- A kill, a wipe, or (the result kept back) neither.
    local won = nil
    if success == 1 then won = true elseif success == 0 then won = false end
    local same = fight and fight.id == id and fight or nil
    local took = same and (GetTime() - same.at) or nil
    fight = nil
    Said(id, name, won, took)
    if won then Journal.Add("bosses") end
    if not id then return nil end
    local known = Nights.Boss(id)
    local label = (known and known.name) or name
    local now = Compat.ServerTime()
    Touch()
    if current then
        -- A night in a place two dungeons share is the one its first boss belongs to.
        if known and known.dungeon.map == current.map and current.place ~= known.dungeon.name and (current.kills or 0) == 0 then
            current.place = known.dungeon.name
            local ev = Event(current)
            if ev then ev.s = current.place end
        end
        if won then
            current.kills = (current.kills or 0) + 1
            local seen = false
            for _, b in ipairs(current.bosses) do if b == id then seen = true end end
            if not seen then current.bosses[#current.bosses + 1] = id end
        elseif won == false then
            current.wipes = (current.wipes or 0) + 1
        end
        if won ~= nil then Begun(current) end
    end
    -- Only the bosses the data lists are kept, so the list can't grow past them.
    local b
    if known then
        local bosses = Nights.Bosses()
        b = bosses[id] or { kills = 0, wipes = 0 }
        bosses[id] = b
        if won then
            b.kills, b.last = (b.kills or 0) + 1, now
            if not b.first then
                b.first, b.fight, b.lv = now, took and math.floor(took + 0.5) or nil, UnitLevel("player")
                local w = same and same.with
                if w then
                    b.with = { others = w.others, guild = w.guild, hidden = w.hidden, raid = w.raid }
                    for i = 1, #w do b.with[i] = w[i] end
                end
            end
        elseif won == false then
            b.wipes = (b.wipes or 0) + 1
        end
    end
    -- The first kill of a boss, ever, is a moment for the Story (kept under the key it always was).
    if won and label and Journal.First("boss:" .. tostring(id)) then
        local place = (known and known.dungeon.name) or (current and current.place)
            or (GetInstanceInfo and Compat.Plain((GetInstanceInfo())))
        Journal.Note("boss", ("Defeated %s%s"):format(label, place and (" in " .. place) or ""),
            { boss = label, id = id, wipes = b and b.wipes or nil })
    end
    return b
end

-- The boss you're fighting now, by name, or nil.
function Nights.Fighting()
    if not fight then return nil end
    local known = Nights.Boss(fight.id)
    return (known and known.name) or fight.name
end

---------------------------------------------------------------------------
-- The rest of a night: deaths, gold looted, the better items won.
---------------------------------------------------------------------------
function Nights.Died()
    Touch()
    if current then current.deaths = (current.deaths or 0) + 1 end
    if current then Mark(current) end
end

function Nights.Gold(copper)
    if current and copper and copper > 0 then
        Touch()
        current.gold = (current.gold or 0) + copper
        Mark(current)
    end
end

function Nights.Won(item)
    if not (current and item) then return end
    Touch()
    Mark(current)
    for _, have in ipairs(current.items) do if have == item then return end end
    if #current.items < Nights.ITEMS then current.items[#current.items + 1] = item end
end

-- Whether an item is a piece of the set you're working towards at 60.
function Nights.InSet(item)
    local Goal = ns.GearGoal
    if not (item and Goal and Goal.ChosenSet) then return false end
    local ok, ids = pcall(Goal.ChosenSet)
    if not ok or type(ids) ~= "table" then return false end
    for _, id in ipairs(ids) do if id == item then return true end end
    return false
end

---------------------------------------------------------------------------
-- Level 60: when it was reached, from the Story's "Reached level 60".
---------------------------------------------------------------------------
function Nights.Since60()
    local events = Journal.Book().events
    for _, e in ipairs(events) do
        if e.k == "level" and e.s == "Reached level 60" then return e.t end
    end
    return nil
end
