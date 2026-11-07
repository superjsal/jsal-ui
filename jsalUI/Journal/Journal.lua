-- The Journal: each character's story from the day jsal.ui first saw it.
-- It counts as you play (foes, quests, damage and healing, deaths, gold
-- earned and where from, distance, spells cast, time in each zone, duels,
-- jumps) and notes the moments worth keeping: levels, rare and elite first
-- kills, dungeon bosses, blue and purple loot, deaths, profession ranks,
-- guild changes. It also keeps a line on every character of the account
-- for the Characters tab. Only your own actions are counted, so busy fights
-- stay light. Nothing is shared.
local _, ns = ...
local Compat = ns.Compat

local Journal = ns.NewModule("journal", {
    title = "Journal",
    note = "Your character's story and stats from today on, and all your characters at a glance. /jsal journal",
    options = {
        { key = "photo", title = "A screenshot at each level-up", default = true,
          note = "Saved in the game's Screenshots folder, and noted in the story." },
    },
})
ns.Journal = Journal

local MAX_EVENTS = 400
-- Repeating attacks aren't "casts" worth counting.
local NOT_CASTS = { [75] = true, [6603] = true, [5019] = true }

---------------------------------------------------------------------------
-- Saved: this character's journal, and a line per character for the
-- account.
---------------------------------------------------------------------------
local function Book()
    local j = ns.char.journal
    if type(j) ~= "table" then
        j = { since = Compat.ServerTime(), startLevel = UnitLevel("player"), events = {} }
        ns.char.journal = j
    end
    j.stats = type(j.stats) == "table" and j.stats or {}
    j.spells = type(j.spells) == "table" and j.spells or {}
    j.zones = type(j.zones) == "table" and j.zones or {}
    j.killers = type(j.killers) == "table" and j.killers or {}
    j.money = type(j.money) == "table" and j.money or {}
    j.seen = type(j.seen) == "table" and j.seen or {}
    j.events = type(j.events) == "table" and j.events or {}
    return j
end
Journal.Book = Book

local function Add(stat, amount)
    local s = Book().stats
    s[stat] = (s[stat] or 0) + (amount or 1)
end

local function Zone()
    local zone = GetRealZoneText and GetRealZoneText() or ""
    return zone ~= "" and zone or nil
end

-- A moment for the story: kind is level, kill, boss, loot, death, prof,
-- guild, duel or start.
function Journal.Note(kind, text, extra)
    local events = Book().events
    local e = { t = Compat.ServerTime(), k = kind, s = text, z = Zone() }
    for k, v in pairs(extra or {}) do e[k] = v end
    events[#events + 1] = e
    while #events > MAX_EVENTS do table.remove(events, 1) end
    if ns.Window then ns.Window.Refresh() end
    return e
end

-- Once per key, ever, for this character.
local function First(key)
    local seen = Book().seen
    if seen[key] then return false end
    seen[key] = true
    return true
end

---------------------------------------------------------------------------
-- The account's characters.
---------------------------------------------------------------------------
local function Characters()
    ns.db.characters = type(ns.db.characters) == "table" and ns.db.characters or {}
    return ns.db.characters
end
Journal.Characters = Characters

function Journal.SaveCharacter()
    local name = Compat.MyName()
    if not name then return end
    local className, classFile = UnitClass("player")
    local profs = {}
    if ns.Professions then
        for _, p in ipairs(ns.Professions.Mine()) do profs[#profs + 1] = { name = p.name, skill = p.skill, cap = p.cap } end
    end
    local c = Characters()[name] or {}
    c.name, c.class, c.classFile = name, className, classFile
    c.level = UnitLevel("player")
    c.zone = Zone() or c.zone
    c.money = GetMoney and GetMoney() or c.money
    c.xpMax = UnitXPMax and UnitXPMax("player") or c.xpMax
    c.rested = GetXPExhaustion and (GetXPExhaustion() or 0) or c.rested
    c.resting = IsResting and IsResting() or false
    c.professions = profs
    c.guild = Compat.GuildName()
    c.updated = Compat.ServerTime()
    Characters()[name] = c
end

-- Rested XP now, as a share of the level bar: what was saved at logout,
-- plus what resting has added since (5% of a level every 8 hours in an inn
-- or city, a quarter of that elsewhere), up to a level and a half.
function Journal.RestedNow(c, now)
    if not c or not c.xpMax or c.xpMax <= 0 or (c.level or 0) >= 60 then return nil end
    local hours = math.max(0, ((now or Compat.ServerTime()) - (c.updated or 0)) / 3600)
    local gained = hours / 8 * 0.05 * c.xpMax * (c.resting and 1 or 0.25)
    return math.min(1.5, ((c.rested or 0) + gained) / c.xpMax)
end

---------------------------------------------------------------------------
-- Counting.
---------------------------------------------------------------------------
local playerGUID
local units = {}        -- creature GUID = its kind, from units seen
local unitCount = 0
local lastHit           -- what last hurt you, for a death
local moneyWas
local window            -- which money window is open: vendor, mail...
local questAt = -10

local function NoteUnit(unit)
    if not UnitExists(unit) or UnitIsPlayer(unit) then return end
    local guid = UnitGUID(unit)
    if not guid or units[guid] then return end
    -- Only rares and world bosses make the story; dungeon bosses come from
    -- the encounter's end instead.
    local kind = UnitClassification and UnitClassification(unit) or "normal"
    if kind ~= "rare" and kind ~= "rareelite" and kind ~= "worldboss" then return end
    if unitCount > 300 then units, unitCount = {}, 0 end
    units[guid] = { kind = kind, name = UnitName(unit), level = UnitLevel(unit) }
    unitCount = unitCount + 1
end

local KINDS = { rare = "rare", rareelite = "rare elite", elite = "elite", worldboss = "boss" }

local function Killed(guid, name)
    Add("foes")
    local seen = units[guid]
    if not seen then return end
    local npc = select(6, strsplit("-", guid))
    if npc and First("kill:" .. npc) then
        Journal.Note("kill", ("First kill: %s (%s)"):format(seen.name or name or "?", KINDS[seen.kind] or seen.kind))
    end
end

local DAMAGE = { SWING_DAMAGE = 12, RANGE_DAMAGE = 15, SPELL_DAMAGE = 15, SPELL_PERIODIC_DAMAGE = 15, DAMAGE_SHIELD = 15 }
local HEAL = { SPELL_HEAL = 15, SPELL_PERIODIC_HEAL = 15 }

local function CombatLog()
    local info = { CombatLogGetCurrentEventInfo() }
    local event, sourceGUID, sourceName, destGUID, destName = info[2], info[4], info[5], info[8], info[9]
    local mine = sourceGUID == playerGUID or (sourceGUID and sourceGUID == UnitGUID("pet"))
    if mine then
        local at = DAMAGE[event] or HEAL[event]
        if at then
            local amount = tonumber(info[at]) or 0
            if HEAL[event] then
                local over = tonumber(info[at + 1]) or 0
                Add("healing", math.max(0, amount - over))
            else
                Add("damage", amount)
            end
        end
    end
    if event == "PARTY_KILL" and destGUID and destGUID:find("^Creature") then
        -- Your kills and your group's: the killer is you, your pet, or in
        -- your party or raid.
        local flags = tonumber(info[6]) or 0
        if mine or (bit and bit.band(flags, 0x7) ~= 0) then
            Killed(destGUID, destName)
        end
    elseif destGUID == playerGUID then
        if DAMAGE[event] then
            lastHit = { name = sourceName, at = GetTime() }
        elseif event == "ENVIRONMENTAL_DAMAGE" then
            local kind = tostring(info[12] or ""):lower()
            lastHit = { name = kind == "falling" and "a fall" or kind == "drowning" and "drowning" or kind == "lava" and "lava" or kind, at = GetTime() }
        end
    end
end

-- Distance and time: once a second, how far you've moved in the world and
-- where you are. The game hides your position inside instances, so those
-- yards aren't counted; a jump of more than 60 yards is a teleport.
local lastX, lastY, lastMap, tick = nil, nil, nil, 0
local function Tick(_, elapsed)
    tick = tick + elapsed
    if tick < 1 then return end
    local seconds = tick
    tick = 0
    local j = Book()
    Add("seconds", seconds)
    local zone = Zone()
    if zone then j.zones[zone] = (j.zones[zone] or 0) + seconds end
    local y, x, map
    if UnitPosition then
        local _
        y, x, _, map = UnitPosition("player")
    end
    if x and y then
        if lastX and map == lastMap then
            local d = math.sqrt((x - lastX) ^ 2 + (y - lastY) ^ 2)
            if d < 60 then Add("yards", d) end
        end
        lastX, lastY, lastMap = x, y, map
    else
        lastX, lastY = nil, nil
    end
end

-- Money earned, and where from, by what was open when it came in.
local function MoneyChanged()
    local now = GetMoney()
    local gained = now - (moneyWas or now)
    moneyWas = now
    if gained <= 0 then return end
    Add("earned", gained)
    local source = window or ((GetTime() - questAt < 2) and "quests") or "loot"
    local m = Book().money
    m[source] = (m[source] or 0) + gained
end

-- Loot of blue quality or better: the first of each item makes the story.
local SELF_LOOT = {}
local function LootPrefixes()
    for _, key in ipairs({ "LOOT_ITEM_SELF", "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF",
                           "LOOT_ITEM_PUSHED_SELF_MULTIPLE", "LOOT_ITEM_CREATED_SELF" }) do
        local s = _G[key]
        local prefix = type(s) == "string" and s:match("^(.-)%%")
        if prefix and prefix ~= "" then SELF_LOOT[#SELF_LOOT + 1] = prefix end
    end
end

local function Looted(text)
    local mine = false
    for _, prefix in ipairs(SELF_LOOT) do
        if text:sub(1, #prefix) == prefix then mine = true break end
    end
    if not mine then return end
    local item = tonumber(text:match("|Hitem:(%d+)"))
    local name = text:match("|h%[(.-)%]|h")
    if not item then return end
    local quality = C_Item and C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(item)
    if quality and quality >= 3 and First("item:" .. item) then
        local label = quality >= 5 and "First legendary" or quality == 4 and "First epic" or "New blue"
        Journal.Note("loot", ("%s: %s"):format(label, name or "an item"), { item = item, q = quality })
    end
end

-- Duels, from the game's own line in chat.
local DUELS = {}
local function DuelPatterns()
    for _, key in ipairs({ "DUEL_WINNER_KNOCKOUT", "DUEL_WINNER_RETREAT" }) do
        local s = _G[key]
        if type(s) == "string" then
            local winnerFirst = (s:find("%1$s", 1, true) or 0) < (s:find("%2$s", 1, true) or 0)
            local p = s:gsub("%%1%$s", "\001"):gsub("%%2%$s", "\002")
            p = p:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%0")
            p = p:gsub("[\001\002]", "(.+)")
            local pattern = "^" .. p .. "$"
            DUELS[#DUELS + 1] = { pattern = pattern, winnerFirst = winnerFirst, retreat = key == "DUEL_WINNER_RETREAT" }
        end
    end
end

local function IsMe(name)
    return name == Compat.MyName() or name == UnitName("player")
end

local function SystemLine(text)
    for _, d in ipairs(DUELS) do
        local a, b = text:match(d.pattern)
        if a then
            local winner, loser = a, b
            if not d.winnerFirst then winner, loser = b, a end
            if IsMe(winner) then
                Add("duelsWon")
                Journal.Note("duel", ("Won a duel against %s"):format(loser))
            elseif IsMe(loser) then
                Add("duelsLost")
                Journal.Note("duel", ("Lost a duel to %s"):format(winner))
            end
            return
        end
    end
end

-- Profession ranks: a new cap is a new rank.
local function CheckRanks()
    if not ns.Professions then return end
    local j = Book()
    j.caps = type(j.caps) == "table" and j.caps or {}
    for _, p in ipairs(ns.Professions.Mine()) do
        local was = j.caps[p.name]
        if was and p.cap > was then
            Journal.Note("prof", ("%s %s"):format(ns.Professions.Rank(p.cap).name, p.name))
        end
        j.caps[p.name] = p.cap
    end
end

local function Dead()
    Add("deaths")
    local killer = lastHit and GetTime() - lastHit.at < 10 and lastHit.name or nil
    local j = Book()
    if killer then j.killers[killer] = (j.killers[killer] or 0) + 1 end
    Journal.Note("death", killer and ("Died to %s"):format(killer) or "Died")
end

local function LevelUp(level)
    local photo = ns.OptionOn("journal", "photo")
    Journal.Note("level", ("Reached level %d"):format(level), { photo = photo or nil })
    if photo and Screenshot then
        -- A moment later, so the level-up glow is in the picture.
        Compat.After(1.5, function() pcall(Screenshot) end)
    end
end

---------------------------------------------------------------------------
-- What the page shows.
---------------------------------------------------------------------------
local function Top(map, count)
    local list = {}
    for key, n in pairs(map or {}) do list[#list + 1] = { key = key, n = n } end
    table.sort(list, function(a, b) if a.n ~= b.n then return a.n > b.n end return tostring(a.key) < tostring(b.key) end)
    for i = count + 1, #list do list[i] = nil end
    return list
end
Journal.Top = Top

function Journal.Stat(name)
    return Book().stats[name] or 0
end

-- The story, newest first, of one kind group or all: rows of events.
local GROUPS = { levels = { level = true }, kills = { kill = true, boss = true }, loot = { loot = true },
                 deaths = { death = true }, more = { prof = true, guild = true, duel = true, start = true } }
function Journal.Story(group)
    local out, events, only = {}, Book().events, GROUPS[group]
    for i = #events, 1, -1 do
        if not only or only[events[i].k] then out[#out + 1] = events[i] end
    end
    return out
end

function Journal:OnEnable()
    playerGUID = UnitGUID("player")
    local j = Book()
    if #j.events == 0 then
        Journal.Note("start", ("This journal begins, at level %d"):format(UnitLevel("player")))
    end
    LootPrefixes()
    DuelPatterns()
    moneyWas = GetMoney and GetMoney() or 0
    local f = CreateFrame("Frame")
    self.frame = f
    for _, event in ipairs({ "COMBAT_LOG_EVENT_UNFILTERED", "PLAYER_LEVEL_UP", "PLAYER_DEAD", "QUEST_TURNED_IN",
                             "PLAYER_MONEY", "CHAT_MSG_LOOT", "CHAT_MSG_SYSTEM", "ENCOUNTER_END",
                             "UNIT_SPELLCAST_SUCCEEDED", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT",
                             "NAME_PLATE_UNIT_ADDED", "SKILL_LINES_CHANGED", "PLAYER_GUILD_UPDATE",
                             "MERCHANT_SHOW", "MERCHANT_CLOSED", "MAIL_SHOW", "MAIL_CLOSED",
                             "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "TRADE_SHOW", "TRADE_CLOSED",
                             "PLAYER_LOGOUT", "ZONE_CHANGED_NEW_AREA", "PLAYER_UPDATE_RESTING" }) do
        pcall(f.RegisterEvent, f, event)
    end
    local windows = { MERCHANT_SHOW = "vendor", MAIL_SHOW = "mail", AUCTION_HOUSE_SHOW = "auction", TRADE_SHOW = "trade" }
    local closes = { MERCHANT_CLOSED = true, MAIL_CLOSED = true, AUCTION_HOUSE_CLOSED = true, TRADE_CLOSED = true }
    f:SetScript("OnEvent", ns.Safe(self, function(_, event, a, b, c, d, e)
        if event == "COMBAT_LOG_EVENT_UNFILTERED" then
            CombatLog()
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            if a == "player" and c and not NOT_CASTS[c] then
                local name = Compat.SpellInfo(c)
                if name then
                    local spells = Book().spells
                    spells[name] = (spells[name] or 0) + 1
                end
            end
        elseif event == "PLAYER_TARGET_CHANGED" then
            NoteUnit("target")
        elseif event == "UPDATE_MOUSEOVER_UNIT" then
            NoteUnit("mouseover")
        elseif event == "NAME_PLATE_UNIT_ADDED" then
            NoteUnit(a)
        elseif event == "PLAYER_LEVEL_UP" then
            LevelUp(a)
            Journal.SaveCharacter()
        elseif event == "PLAYER_DEAD" then
            Dead()
        elseif event == "QUEST_TURNED_IN" then
            Add("quests")
            questAt = GetTime()
        elseif event == "PLAYER_MONEY" then
            MoneyChanged()
        elseif event == "CHAT_MSG_LOOT" then
            if type(a) == "string" then Looted(a) end
        elseif event == "CHAT_MSG_SYSTEM" then
            if type(a) == "string" then SystemLine(a) end
        elseif event == "ENCOUNTER_END" then
            if e == 1 and b then
                Add("bosses")
                if First("boss:" .. tostring(a)) then
                    local instance = GetInstanceInfo and GetInstanceInfo()
                    Journal.Note("boss", ("Defeated %s%s"):format(b, instance and (" in " .. instance) or ""))
                end
            end
        elseif event == "SKILL_LINES_CHANGED" then
            CheckRanks()
        elseif event == "PLAYER_GUILD_UPDATE" then
            local guild = Compat.GuildName()
            local j = Book()
            if guild ~= j.guild then
                if guild then Journal.Note("guild", ("Joined %s"):format(guild)) elseif j.guild then Journal.Note("guild", ("Left %s"):format(j.guild)) end
                j.guild = guild
            end
        elseif windows[event] then
            window = windows[event]
        elseif closes[event] then
            window = nil
        else
            -- Logging out, a new zone or resting changed: the Characters line.
            Journal.SaveCharacter()
        end
    end))
    f:SetScript("OnUpdate", ns.Safe(self, Tick))
    if hooksecurefunc and JumpOrAscendStart then
        hooksecurefunc("JumpOrAscendStart", function() if Journal.running then Add("jumps") end end)
    end
    Book().guild = Book().guild or Compat.GuildName()
    Compat.After(5, function()
        xpcall(Journal.SaveCharacter, ns.Report)
        xpcall(CheckRanks, ns.Report)
    end)
end

function Journal:OnDisable()
    if self.frame then
        self.frame:UnregisterAllEvents()
        self.frame:SetScript("OnUpdate", nil)
    end
end

ns.Command("journal", function() if ns.Window then ns.Window.Open("journal") end end)
