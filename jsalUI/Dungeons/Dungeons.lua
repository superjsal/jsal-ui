-- The dungeon guide's records: each boss you kill (counted per character,
-- on top of the game's own Boss Kills statistics) and what each boss has
-- dropped (kept for the whole account), learned as you play: from the loot
-- window when the boss is your target, and from the rolls just after a
-- boss dies.
local _, ns = ...

local Dungeons = ns.NewModule("dungeons", {
    title = "Dungeon guide",
    note = "A Dungeons page: every dungeon and raid by level, its bosses, the ones you've killed, and what each boss drops.",
    options = {
        { key = "share", title = "Share boss loot with your guild", default = true,
          note = "Guildmates with jsal.ui see the bosses you kill and what they drop, and you see theirs, so every boss's loot fills in. Only bosses and items are shared, not who looted what." },
    },
})
ns.Dungeons = Dungeons

local BOSS_KILLS = 14821   -- the Statistics window's Boss Kills list
-- Rolls this soon after a boss dies are its loot.
local ROLL_WINDOW = 180

local function Key(name) return type(name) == "string" and name:lower() or nil end
Dungeons.Key = Key

-- Every boss by name, for the loot window: by its encounter's name and, when
-- the boss you see is named differently, by that too, each giving the boss
-- as { encounter ID, encounter name (which kills and loot are kept under) }.
local bosses
local function Bosses()
    if bosses then return bosses end
    bosses = {}
    for _, d in ipairs(ns.DungeonData or {}) do
        for _, b in ipairs(d.bosses) do
            bosses[Key(b[2])] = b
            if b[3] then bosses[Key(b[3])] = b end
        end
    end
    return bosses
end

local function Kills()
    local d = ns.char.dungeons
    if type(d) ~= "table" then
        d = {}
        ns.char.dungeons = d
    end
    d.kills = type(d.kills) == "table" and d.kills or {}
    return d.kills
end

-- Loot by boss: { [boss] = { [item ID] = { n = name, q = quality, seen = times } } }.
function Dungeons.Loot()
    if type(ns.db.dungeonLoot) ~= "table" then ns.db.dungeonLoot = {} end
    return ns.db.dungeonLoot
end

---------------------------------------------------------------------------
-- Kills: the game's Boss Kills statistics (kept since the character was
-- made) and jsal.ui's own count, whichever is bigger.
---------------------------------------------------------------------------
function Dungeons.GameKills()
    local out = {}
    local J = ns.Journal
    if not (J and J.GameStat and GetCategoryNumAchievements and GetAchievementInfo) then return out end
    for i = 1, (GetCategoryNumAchievements(BOSS_KILLS, true) or 0) do
        local id, name = GetAchievementInfo(BOSS_KILLS, i)
        local n = id and J.GameStat(id)
        if type(name) == "string" and n then out[#out + 1] = { name:lower(), n } end
    end
    return out
end

-- A statistic the game counts for another boss than the one it's named for, by the faction: "Bazzalan kills
-- (Ragefire Chasm)" counts a kill of Bazzalan or of Hall of Thanes' Durgen Dirgehammer (its criteria take either
-- creature), and Durgen's own statistic counts nothing. Ragefire Chasm is the Horde's alone, so for the Alliance
-- that statistic is Durgen's.
local STAT_FOR = { ["bazzalan"] = { Alliance = "durgen dirgehammer" } }
local function StatOwner(name, faction)
    for named, by in pairs(STAT_FOR) do
        if by[faction] and name:find(named, 1, true) then return by[faction] end
    end
end

-- A boss's kills, by its encounter's name; the statistics may use the
-- boss's own name instead.
function Dungeons.KillCount(boss, game, ownName)
    local key, own = Key(boss), Key(ownName)
    local n = Kills()[key] or 0
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    for _, stat in ipairs(game or {}) do
        local owner = StatOwner(stat[1], faction)
        local mine
        if owner then
            mine = owner == key or owner == own
        else
            mine = stat[1]:find(key, 1, true) or (own and stat[1]:find(own, 1, true))
        end
        if mine then n = math.max(n, stat[2]) end
    end
    return n
end

---------------------------------------------------------------------------
-- Loot: uncommon and better, from an item's link.
---------------------------------------------------------------------------
local QUALITY = { ["9d9d9d"] = 0, ["ffffff"] = 1, ["1eff00"] = 2, ["0070dd"] = 3, ["a335ee"] = 4, ["ff8000"] = 5 }

-- An item's quality from its link: the game's own word for the item where it has one, else
-- the link's colour, in the newer form ("|cnIQ3:") or the older ("|cff0070dd"). Only the older
-- was read, and a link in the newer one counted as below uncommon: nothing was learned.
function Dungeons.LinkQuality(link)
    if type(link) ~= "string" then return nil end
    local id = tonumber(link:match("item:(%d+)"))
    local quality = id and C_Item and C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(id)
    if type(quality) == "number" then return quality end
    local named = link:match("|cnIQ(%d):")
    if named then return tonumber(named) end
    local color = link:match("|c%x%x(%x%x%x%x%x%x)")
    return color and QUALITY[color:lower()] or nil
end

function Dungeons.Learn(boss, link)
    local key = Key(boss)
    if not (key and type(link) == "string") then return false end
    local id = tonumber(link:match("item:(%d+)"))
    local name = link:match("%[(.-)%]")
    local quality = Dungeons.LinkQuality(link)
    if not (id and name) or (quality or 0) < 2 then return false end
    local loot = Dungeons.Loot()
    loot[key] = loot[key] or {}
    local item = loot[key][id] or { n = name, q = quality, seen = 0 }
    item.seen = (item.seen or 0) + 1
    loot[key][id] = item
    return true
end

-- The boss you're looting: your target, dead, and one of the guide's.
local function LootedBoss()
    if not (UnitExists and UnitExists("target") and UnitIsDead and UnitIsDead("target")) then return nil end
    return Bosses()[Key(ns.Compat.Name("target"))]
end

local recent, recentId, recentAt
local looted = {}
local Guild = function() return ns.GuildLoot end

local function Changed()
    if ns.Window and ns.Window.IsOpen and ns.Window.IsOpen("dungeons") then ns.Window.Refresh() end
end

local function OnEvent(_, event, a, b, _, _, e)
    a, b, e = ns.Compat.Plains(a, b, e)
    if event == "ENCOUNTER_END" then
        if e == 1 and type(b) == "string" then
            local kills = Kills()
            kills[Key(b)] = (kills[Key(b)] or 0) + 1
            recent, recentId, recentAt = b, tonumber(a), GetTime()
            if Guild() and recentId then Guild().Killed(recentId) end
            Changed()
        end
    elseif event == "LOOT_OPENED" then
        local boss = LootedBoss()
        if not boss then return end
        -- Each corpse once, however often its window is opened.
        local guid = ns.Compat.GUID("target")
        if guid and looted[guid] then return end
        if guid then looted[guid] = true end
        local any
        for slot = 1, (GetNumLootItems and GetNumLootItems() or 0) do
            local link = GetLootSlotLink(slot)
            if Dungeons.Learn(boss[2], link) then any = true end
            if Guild() then Guild().Dropped(boss[1], link) end
        end
        if any then Changed() end
    elseif event == "START_LOOT_ROLL" then
        if recent and GetTime() - recentAt <= ROLL_WINDOW and GetLootRollItemLink then
            local link = GetLootRollItemLink(a)
            if Dungeons.Learn(recent, link) then Changed() end
            if Guild() and recentId then Guild().Dropped(recentId, link) end
        end
    end
end
Dungeons.OnEvent = OnEvent

-- What a dungeon's ordinary creatures drop, and not its bosses, from the gear the Gear plan knows (GearData): a drop
-- placed in the dungeon, either a creature and the dungeon (Crypt Beast, in Stratholme) or the dungeon alone, that no
-- boss of the guide lists, from a creature that isn't one of the dungeon's bosses (by either of a boss's names, or a name that begins the
-- other, as the Endgame goal finds a boss), and that your side can get. { { id, creature (nil where none is named),
-- quality } }, found the first time a dungeon is shown and kept. Wowhead names Sunken Temple by the temple's own name.
-- No drop chance is known for them. A drop in several dungeons has its other dungeons in GearData's `more`, read the
-- first time a Trash card is built and kept.
local ALSO_CALLED = { ["Sunken Temple"] = "The Temple of Atal'Hakkar" }
local SEP = " \194\183 "
local trash, bossDrop = {}, nil
local function IsBoss(d, name)
    for _, b in ipairs(d.bosses) do
        for i = 2, 3 do
            local n = b[i]
            if n and (n == name or (#n >= 5 and #name >= 5 and (name:sub(1, #n) == n or n:sub(1, #name) == name))) then return true end
        end
    end
    return false
end
local moreAt
function Dungeons.Trash(d)
    local data = ns.GearData
    if trash[d] and trash[d].data == data then return trash[d].list end
    local list = {}
    trash[d] = { data = data, list = list }
    if not (data and data.places and data.items) then return list end
    if not bossDrop then
        bossDrop = {}
        for _, drops in pairs(ns.DungeonLoot or {}) do
            for _, drop in ipairs(drops) do bossDrop[drop[1]] = true end
        end
    end
    -- The places that are this dungeon, by number: the creature named, or true for none.
    local want, any = {}, false
    for _, name in ipairs({ d.name, ALSO_CALLED[d.name] }) do
        local tail = SEP .. name
        for i, place in ipairs(data.places) do
            if place == name then
                want[i], any = true, true
            elseif #place > #tail and place:sub(-#tail) == tail then
                local creature = place:sub(1, #place - #tail)
                if not IsBoss(d, creature) then want[i], any = creature, true end
            end
        end
    end
    if not any then return list end
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    local mine = (faction == "Alliance" and "1") or (faction == "Horde" and "2") or nil
    local seen = {}
    if not (moreAt and moreAt.data == data) then
        moreAt = { data = data, at = {} }
        for id, nums in (data.more or ""):gmatch("(%d+):([%d,]+)") do
            for n in nums:gmatch("%d+") do
                n = tonumber(n)
                moreAt.at[n] = moreAt.at[n] or {}
                moreAt.at[n][tonumber(id)] = true
            end
        end
    end
    -- An item's entry ends in its source kind and place: ",1,<place>" for a drop there, then ";" or the line's end.
    for _, line in pairs(data.items) do
        for place, creature in pairs(want) do
            local key = ",1," .. place
            local from = 1
            while true do
                local at = line:find(key, from, true)
                if not at then break end
                local stop = at + #key
                local after = line:byte(stop)
                if after == nil or after == 59 then
                    local start = at
                    while start > 1 and line:byte(start - 1) ~= 59 do start = start - 1 end
                    local id, side, q = line:sub(start, at - 1):match("^(%d+),%d+,%d+,%-?%d+,%-?%d+,(%d+),%d+,(%d+)$")
                    id = tonumber(id)
                    if id and not seen[id] and not bossDrop[id] and (side == "0" or side == mine) then
                        seen[id] = true
                        list[#list + 1] = { id, creature ~= true and creature or nil, tonumber(q) }
                    end
                end
                from = stop
            end
        end
        -- A drop whose other dungeons (`more`) include this one: its entry found by its ID, at an entry's start.
        for place, creature in pairs(want) do
            for id in pairs(moreAt.at[place] or {}) do
                local key, from = id .. ",", 1
                while true do
                    local at = line:find(key, from, true)
                    if not at then break end
                    if at == 1 or line:byte(at - 1) == 59 then
                        local stop = line:find(";", at, true)
                        local side, q = line:sub(at, (stop or 0) - 1):match("^%d+,%d+,%d+,%-?%d+,%-?%d+,(%d+),%d+,(%d+),1,%d+$")
                        if side and not seen[id] and not bossDrop[id] and (side == "0" or side == mine) then
                            seen[id] = true
                            list[#list + 1] = { id, creature ~= true and creature or nil, tonumber(q) }
                        end
                    end
                    from = at + 1
                end
            end
        end
    end
    table.sort(list, function(a, b) return a[1] < b[1] end)
    return list
end

function Dungeons:OnEnable()
    local f = self.frame or CreateFrame("Frame")
    self.frame = f
    for _, event in ipairs({ "ENCOUNTER_END", "LOOT_OPENED", "START_LOOT_ROLL" }) do
        pcall(f.RegisterEvent, f, event)
    end
    f:SetScript("OnEvent", ns.Safe(self, OnEvent))
end

function Dungeons:OnDisable()
    if self.frame then self.frame:UnregisterAllEvents() end
end

ns.Command("dungeons", function() if ns.Window then ns.Window.Open("dungeons") end end)
