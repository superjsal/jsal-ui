-- Guild games: who in the guild runs jsal.ui, today's game scores, and the Guild Word, a word
-- the guild master or an officer sets for the whole guild to play. It hears only guildmates who have jsal.ui,
-- through addon messages, and keeps guildmates' scores for this session only. What it hears is
-- shown on the Games page; the Guild page it had was folded into that one (18 Nov 2026).
local _, ns = ...
local Style, Compat, Comms, Window = ns.Style, ns.Compat, ns.Comms, ns.Window

local Guild = ns.NewModule("guild", {
    title = "Guild games",
    note = "Your guild's scores beside yours on the Games page, and the Guild Word. /jsal games",
})

local members, answered = {}, {}

---------------------------------------------------------------------------
-- The Guild Word: saved per guild as its ID (the moment it was set), the
-- word lightly scrambled so it doesn't sit in plain text, and who set it.
---------------------------------------------------------------------------
local function Shift(word, id, sign)
    local out = {}
    for i = 1, #word do
        local code = word:byte(i) - 97
        out[i] = string.char((code + sign * ((id + i * 5) % 26)) % 26 + 97)
    end
    return table.concat(out)
end

local function Words()
    ns.db.guildWords = type(ns.db.guildWords) == "table" and ns.db.guildWords or {}
    return ns.db.guildWords
end

function Guild.Word()
    local guild = Compat.GuildName()
    local saved = guild and Words()[guild]
    if type(saved) ~= "table" or not saved.id then return nil end
    return { id = saved.id, answer = Shift(saved.code, saved.id, -1), setter = saved.setter or "the guild master" }
end

-- A word's ID is the moment it was set, and the newest wins. So one dated ahead of the realm's
-- clock isn't taken: it would stand against every real word set after it. One saved that way
-- before this gives way to the next real one.
local AHEAD = 600
local function SaveWord(id, code, setter)
    local guild = Compat.GuildName()
    if not guild then return false end
    local latest = Compat.ServerTime() + AHEAD
    if id > latest then return false end
    local saved = Words()[guild]
    if type(saved) == "table" and (saved.id or 0) >= id and (saved.id or 0) <= latest then return false end
    Words()[guild] = { id = id, code = code, setter = setter }
    return true
end

local function WordPayload()
    local guild = Compat.GuildName()
    local saved = guild and Words()[guild]
    if type(saved) ~= "table" then return nil end
    return ("%d;%s;%s"):format(saved.id, saved.code, saved.setter or "")
end

-- What a player tells the guild: "version;wordDay;wordScore;iconDay;iconScore;
-- guildWordID;guildWordScore;wordAverage;wordsSolved". Older versions send
-- the first seven, and the rest read as missing.
local function Status()
    local wordDay, wordScore = ns.DailyWord.Result()
    local iconDay, iconScore = ns.IconGuess.Result()
    local word = Guild.Word()
    local guildScore = word and ns.DailyWord.GuildResult(word.id)
    local average, solved = ns.DailyWord.Average()
    return table.concat({
        ns.version,
        wordDay or 0, wordScore or "",
        iconDay or 0, iconScore or "",
        word and guildScore and word.id or 0, guildScore or "",
        average and ("%.2f"):format(average) or "", solved or 0,
        -- "R" when this player takes problem reports for jsal.ui.
        ns.Reports and ns.Reports.Receiving() and "R" or "",
        -- A fingerprint of the recipes this player shares, for Guild crafters.
        ns.Crafters and ns.Crafters.Signature() or "",
        -- The zone and layer this player is on ("map:layer"), for changing layers.
        ns.LayerSwitch and ns.LayerSwitch.Code() or "",
        -- The last version that added files: updating past it needs a restart.
        ns.restartSince or "",
        -- How many boss kills and drops this player has heard, for guild loot.
        ns.GuildLoot and ns.GuildLoot.Signature() or "",
        -- How many guild orders this player has heard, and their revisions added up.
        ns.Orders and ns.Orders.Signature() or "",
        -- Today's Pal run: its day, this player's best time and their pal's name, "day:steps:name".
        ns.PalRun and ns.PalRun.Signature() or "",
    }, ";")
end

local Newer = ns.Newer

-- Addons can't look online, but guildmates' copies say which version they
-- run: when one is newer than yours, you hear about it once a session, and
-- whether that update needs a restart or just a /reload.
local toldNewer
local function CheckVersion(version, name, restartSince)
    if not version or name == Compat.MyName() or not Newer(version, ns.version) then return end
    -- A beta only interests players already on a beta: the rest hear only of newer stable versions.
    if ns.IsBeta(version) and not ns.IsBeta(ns.version) then return end
    if toldNewer and not Newer(version, toldNewer) then return end
    toldNewer = version
    local after = ""
    if restartSince and restartSince ~= "" then
        after = Newer(restartSince, ns.startedVersion or ns.version) and " After updating, restart the game."
            or " After updating, a /reload is enough."
    end
    ns.Print(("A newer jsal.ui is out: %s has %s, you have %s. Get it at jsal.io/jsal-ui.%s"):format(name, version, ns.version, after))
end

-- Every guildmate ever heard with jsal.ui, kept per guild: when first and
-- last, and their version. Someone heard for the first time gets a line in
-- chat; for the list's first two minutes everyone already using it is
-- noted quietly, so starting the list doesn't announce the whole guild.
local QUIET = 120
local function SeenList()
    local guild = Compat.GuildName()
    if not guild then return nil end
    ns.db.guildSeen = type(ns.db.guildSeen) == "table" and ns.db.guildSeen or {}
    local list = ns.db.guildSeen[guild]
    if type(list) ~= "table" then
        list = { started = Compat.ServerTime(), names = {} }
        ns.db.guildSeen[guild] = list
    end
    return list
end

local function NoteSeen(name, version)
    local list = name ~= Compat.MyName() and SeenList()
    if not list then return end
    local now = Compat.ServerTime()
    local entry = list.names[name]
    if not entry then
        entry = { first = now }
        list.names[name] = entry
        if now > (list.started or 0) + QUIET then
            ns.Print(("%s started using jsal.ui%s."):format(name, version and version ~= "" and (" (" .. version .. ")") or ""))
        end
    end
    entry.last, entry.version = now, version
end

local function Store(payload, name, sender)
    local version, wordDay, wordScore, iconDay, iconScore, guildID, guildScore, average, solved, reports, recipes, layer, restartSince, loot, orders, run = strsplit(";", payload or "")
    local runDay, runSteps, runPal = (run or ""):match("^(%d+):(%d+):(.*)$")
    if ns.Crafters then ns.Crafters.HeardHello(name, recipes, sender or name) end
    if ns.GuildLoot then ns.GuildLoot.HeardHello(name, loot, sender or name) end
    if ns.Orders then ns.Orders.HeardHello(name, orders, sender or name) end
    if ns.LayerSwitch and ns.Layers and ns.Layers.running then ns.LayerSwitch.Heard(name, layer, sender or name) end
    CheckVersion(version, name, restartSince)
    NoteSeen(name, version)
    local before = members[name] or {}
    members[name] = {
        marksDay = before.marksDay, wordMarks = before.wordMarks, iconMarks = before.iconMarks,
        guildMarksID = before.guildMarksID, guildMarks = before.guildMarks,
        target = sender or name,   -- the name to whisper them by
        average = tonumber(average),
        solved = tonumber(solved),
        version = version,
        wordDay = tonumber(wordDay),
        wordScore = wordScore ~= "" and wordScore or nil,
        iconDay = tonumber(iconDay),
        iconScore = iconScore ~= "" and iconScore or nil,
        guildID = tonumber(guildID),
        guildScore = guildScore ~= "" and guildScore or nil,
        takesReports = reports == "R",
        runDay = tonumber(runDay),
        runSteps = tonumber(runSteps),
        runPal = ns.PalRun and ns.PalRun.Clean and ns.PalRun.Clean(runPal) or nil,
        seen = GetTime(),
    }
end

local function Record(payload, name, _, sender)
    Store(payload, name, sender)
    Window.Refresh()
end

-- An answer to a hello is also how chess learns an opponent is back.
local function Answer(payload, name, channel, sender)
    Record(payload, name, channel, sender)
    if ns.Chess then ns.Chess.Heard(name) end
    if ns.Reports then ns.Reports.Heard(name) end
end

-- Guildmates heard from with jsal.ui this session, by name: their version,
-- the name to whisper them by, and when. Chess finds its players here.
function Guild.Members()
    return members
end

-- How today's games went, without a letter of any word, for the tooltip of a guildmate's row
-- on the Games page: "day;daily word grid;icon guess marks;guild word ID;guild word grid".
-- A grid is a row a guess of r, n and x (right, near, miss), the rows joined by dots; the
-- marks are a 1 or 0 an icon. Its own message, so the scores' message keeps its room.
local function Details()
    local word = Guild.Word()
    return table.concat({
        ns.Games and ns.Games.Today() or 0,
        ns.DailyWord and ns.DailyWord.Marks and ns.DailyWord.Marks() or "",
        ns.IconGuess and ns.IconGuess.Marks and ns.IconGuess.Marks() or "",
        word and word.id or 0,
        word and ns.DailyWord and ns.DailyWord.GuildMarks and ns.DailyWord.GuildMarks(word) or "",
    }, ";")
end

local function HeardDetails(payload, name)
    local day, word, icons, guildID, guild = strsplit(";", payload or "")
    local m = members[name]
    if not m then
        m = { seen = GetTime() }
        members[name] = m
    end
    local function Grid(text) return type(text) == "string" and #text <= 60 and text:match("^[rnx.]+$") and text or nil end
    m.marksDay = tonumber(day)
    m.wordMarks = Grid(word)
    m.iconMarks = type(icons) == "string" and #icons <= 10 and icons:match("^[01]+$") and icons or nil
    m.guildMarksID = tonumber(guildID)
    m.guildMarks = Grid(guild)
    Window.Refresh()
end

-- Tells the guild a game was finished, so the scores update for everyone.
function Guild.Announce()
    if Guild.running and IsInGuild() then
        Comms.Send("ME", Status())
        Comms.Send("GD", Details())
    end
end

-- A Guild Word game finished: tell the guild.
function Guild.WordResult()
    Guild.Announce()
end

-- The guild master or an officer sets a new Guild Word. Returns false and why, or true.
function Guild.SetWord(word)
    word = strtrim(word or ""):lower()
    if not Compat.IsGuildOfficer() then return false, "Only the guild master and officers can set it." end
    if not (word:match("^%a+$") and #word >= 5 and #word <= 8) then return false, "Five to eight letters, please." end
    if not ns.DailyWord.IsWord(word) then return false, "That one isn't in the word list." end
    local id = Compat.ServerTime()
    SaveWord(id, Shift(word, id, 1), Compat.MyName())
    Comms.Send("GW", WordPayload())
    return true
end

local function HeardWord(payload, name)
    local id, code, setter = strsplit(";", payload or "")
    id = tonumber(id)
    if not (id and code and code:match("^%l+$") and #code >= 5 and #code <= 8) then return end
    -- Only a word from the guild master or an officer counts. A word passed
    -- on by a guildmate names who set it, so the check is on the setter, by
    -- the roster.
    local setBy = setter ~= "" and setter or name
    if Compat.IsGuildOfficerName(setBy) == false then return end
    if SaveWord(id, code, setter ~= "" and setter or name) then
        if setter ~= Compat.MyName() then
            ns.Print(("New Guild Word from %s. /jsal games to play it."):format(setter ~= "" and setter or name))
        end
        Window.Refresh()
    end
end

-- Says hello to the guild: everyone with jsal.ui answers, so the list fills
-- in. Sent at login and again, at most once a minute, when the Guild tab or
-- Chess page opens, so a guildmate missed along the way turns up.
local lastHello = -60
function Guild.Hello()
    if not (Guild.running and IsInGuild()) or GetTime() < lastHello + 60 then return end
    lastHello = GetTime()
    Comms.Send("HI", Status())
    Comms.Send("GD", Details())
end

function Guild:OnEnable()
    -- "HI" comes from someone logging in or reloading: note them and
    -- answer by whisper with your scores and the Guild Word you have. Every
    -- hello is answered (at most every 30 seconds each), since their reload
    -- forgets who they'd heard. "ME" is an answer or a score update; "GW"
    -- is a Guild Word.
    Comms.On("HI", function(payload, name, channel, sender)
        Record(payload, name, channel, sender)
        if ns.Chess then ns.Chess.Heard(name) end
        if ns.Reports then ns.Reports.Heard(name) end
        if name ~= Compat.MyName() and (answered[name] or -30) + 30 < GetTime() then
            answered[name] = GetTime()
            Comms.Send("ME", Status(), "WHISPER", sender)
            Comms.Send("GD", Details(), "WHISPER", sender)
            local word = WordPayload()
            if word then Comms.Send("GW", word, "WHISPER", sender) end
        end
    end)
    Comms.On("ME", Answer)
    Comms.On("GW", HeardWord)
    Comms.On("GD", HeardDetails)
    Compat.After(8, Guild.Hello)
end

function Guild:OnDisable()
    Comms.On("HI", nil)
    Comms.On("ME", nil)
    Comms.On("GW", nil)
    Comms.On("GD", nil)
end

-- A guildmate heard this session who has since gone is let go: the guild's roster says who's
-- on, and a hello in the last few minutes counts too (the roster can run behind someone just
-- in). Nobody was ever let go, so everyone heard since you logged in read as online.
local HEARD = 300
local function Prune()
    local count = GetNumGuildMembers and GetNumGuildMembers() or 0
    if count == 0 then return end
    local online = {}
    for i = 1, count do
        local full, _, _, _, _, _, _, _, isOnline = GetGuildRosterInfo(i)
        if full and isOnline then online[Ambiguate(full, "none")] = true end
    end
    local me, now = Compat.MyName(), GetTime()
    for name, m in pairs(members) do
        if name ~= me and not online[name] and now - (m.seen or 0) > HEARD then members[name] = nil end
    end
end

Guild.Prune = Prune

ns.Guild = Guild
