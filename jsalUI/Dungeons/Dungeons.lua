-- The dungeon guide's records: each boss you kill (counted per character,
-- on top of the game's own Boss Kills statistics) and what each boss has
-- dropped (kept for the whole account), learned as you play: from the loot
-- window when the boss is your target, and from the rolls just after a
-- boss dies.
local _, ns = ...

local Dungeons = ns.NewModule("dungeons", {
    title = "Dungeon guide",
    note = "A Dungeons page: every dungeon and raid by level, its bosses, the ones you've killed, and what each boss has dropped for you.",
})
ns.Dungeons = Dungeons

local BOSS_KILLS = 14821   -- the Statistics window's Boss Kills list
-- Rolls this soon after a boss dies are its loot.
local ROLL_WINDOW = 180

local function Key(name) return type(name) == "string" and name:lower() or nil end
Dungeons.Key = Key

-- Every boss by name, for the loot window and the game's statistics.
local bosses
local function Bosses()
    if bosses then return bosses end
    bosses = {}
    for _, d in ipairs(ns.DungeonData or {}) do
        for _, b in ipairs(d.bosses) do bosses[Key(b[2])] = d end
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

function Dungeons.KillCount(boss, game)
    local key = Key(boss)
    local n = Kills()[key] or 0
    for _, stat in ipairs(game or {}) do
        if stat[1]:find(key, 1, true) then n = math.max(n, stat[2]) end
    end
    return n
end

---------------------------------------------------------------------------
-- Loot: uncommon and better, from an item's link.
---------------------------------------------------------------------------
local QUALITY = { ["9d9d9d"] = 0, ["ffffff"] = 1, ["1eff00"] = 2, ["0070dd"] = 3, ["a335ee"] = 4, ["ff8000"] = 5 }

function Dungeons.Learn(boss, link)
    local key = Key(boss)
    if not (key and type(link) == "string") then return false end
    local id = tonumber(link:match("item:(%d+)"))
    local name = link:match("%[(.-)%]")
    local color = link:match("|c%x%x(%x%x%x%x%x%x)")
    local quality = color and QUALITY[color:lower()]
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
    local name = UnitName("target")
    return Bosses()[Key(name)] and name or nil
end

local recent, recentAt
local looted = {}

local function Changed()
    if ns.Window and ns.Window.IsOpen and ns.Window.IsOpen("dungeons") then ns.Window.Refresh() end
end

local function OnEvent(_, event, a, b, _, _, e)
    if event == "ENCOUNTER_END" then
        if e == 1 and type(b) == "string" then
            local kills = Kills()
            kills[Key(b)] = (kills[Key(b)] or 0) + 1
            recent, recentAt = b, GetTime()
            Changed()
        end
    elseif event == "LOOT_OPENED" then
        local boss = LootedBoss()
        if not boss then return end
        -- Each corpse once, however often its window is opened.
        local guid = UnitGUID and UnitGUID("target")
        if guid and looted[guid] then return end
        if guid then looted[guid] = true end
        local any
        for slot = 1, (GetNumLootItems and GetNumLootItems() or 0) do
            if Dungeons.Learn(boss, GetLootSlotLink(slot)) then any = true end
        end
        if any then Changed() end
    elseif event == "START_LOOT_ROLL" then
        if recent and GetTime() - recentAt <= ROLL_WINDOW and GetLootRollItemLink then
            if Dungeons.Learn(recent, GetLootRollItemLink(a)) then Changed() end
        end
    end
end
Dungeons.OnEvent = OnEvent

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
