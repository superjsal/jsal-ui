-- Guild games: who in the guild runs jsal.ui, today's game scores, and the Guild Word, a word
-- the guild master or an officer sets for the whole guild to play. It hears only guildmates who have jsal.ui,
-- through addon messages. Who is on is kept for this session only; a guildmate's scores for
-- today are saved, so they're still there after a reload or once that guildmate has logged off.
-- What it hears is shown on the Games page.
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

-- This account's own number: random, made once and kept account-wide, so a guildmate's Games page
-- shows one row for one player's characters. Nothing about the account, its characters or realm goes
-- into it; it rides only on what is told to the guild channel, and is never shown.
local PERSON_LEN = 10
local function Person()
    local p = ns.db.person
    if type(p) ~= "string" or #p ~= PERSON_LEN or not p:match("^%w+$") then
        local digits = "0123456789abcdefghijklmnopqrstuvwxyz"
        local made = {}
        for i = 1, PERSON_LEN do
            local k = math.random(1, #digits)
            made[i] = digits:sub(k, k)
        end
        p = table.concat(made)
        ns.db.person = p
    end
    return p
end
Guild.Person = Person

-- A number heard from a guildmate, or nil for none or one not of its shape.
local function HeardPerson(p)
    return type(p) == "string" and #p == PERSON_LEN and p:match("^%w+$") and p or nil
end

-- What a player tells the guild: "version;wordDay;wordScore;iconDay;iconScore;
-- guildWordID;guildWordScore;wordAverage;wordsSolved". Older versions send
-- the first seven, and the rest read as missing. `whisper`: it's an answer to
-- one guildmate, which carries no number.
local function Status(whisper)
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
        -- Left empty: the fields after it are read by their place in the line.
        "",
        -- The last version that added files: updating past it needs a restart.
        ns.restartSince or "",
        -- How many boss kills and drops this player has heard, for guild loot.
        ns.GuildLoot and ns.GuildLoot.Signature() or "",
        -- How many guild orders this player has heard, and their revisions added up.
        ns.Orders and ns.Orders.Signature() or "",
        -- Today's Pal run: its day, this player's best time and their pal's name, "day:steps:name".
        ns.PalRun and ns.PalRun.Signature() or "",
        -- This account's number, on the guild channel only.
        whisper and "" or Person(),
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

---------------------------------------------------------------------------
-- Today's scores, saved per guild. A reload forgets who was heard, and a
-- guildmate who has logged off can't say again what they played, so what
-- each one told the guild is kept by name: until the daily reset for the
-- daily games, and for as long as the Guild Word they played stands.
---------------------------------------------------------------------------
-- Each group is a game's day (or word ID) and what goes with it. A group is taken from a
-- message only when it's as new as the one kept: a message that came out of order, or one
-- from before that guildmate played, never wipes a score.
local KEPT = {
    { "wordDay", "wordScore" }, { "iconDay", "iconScore" }, { "runDay", "runSteps", "runPal" },
    { "marksDay", "wordMarks", "iconMarks" }, { "guildID", "guildScore" }, { "guildMarksID", "guildMarks" },
}
-- With them, the guildmate's account number when they sent one, so a reload still shows one row a player.

local function Worth(r, today, word)
    return (r.wordDay == today and r.wordScore ~= nil) or (r.iconDay == today and r.iconScore ~= nil)
        or (r.runDay == today and r.runSteps ~= nil) or (word ~= 0 and r.guildID == word and r.guildScore ~= nil)
end

-- The guild's saved day, with today's number and the Guild Word's ID. When either has changed
-- since it was last read, everyone with nothing left to show is let go, so it never holds more
-- than a day's players.
local function DayBook()
    local guild = Compat.GuildName()
    if not guild then return nil end
    ns.db.guildDay = type(ns.db.guildDay) == "table" and ns.db.guildDay or {}
    local book = ns.db.guildDay[guild]
    if type(book) ~= "table" or type(book.names) ~= "table" then
        book = { names = {} }
        ns.db.guildDay[guild] = book
    end
    local today = ns.Games and ns.Games.Today() or 0
    local saved = Words()[guild]
    local word = type(saved) == "table" and saved.id or 0
    if book.day ~= today or book.word ~= word then
        for name, r in pairs(book.names) do
            if type(r) ~= "table" or not Worth(r, today, word) then book.names[name] = nil end
        end
        book.day, book.word = today, word
    end
    return book, today, word
end

local function Keep(name, m)
    if name == Compat.MyName() then return end
    local book, today, word = DayBook()
    if not book then return end
    local r = book.names[name] or {}
    for _, group in ipairs(KEPT) do
        local key = group[1]
        if m[key] and m[key] >= (r[key] or 0) then
            for _, field in ipairs(group) do r[field] = m[field] end
        end
    end
    r.person = m.person or r.person
    book.names[name] = Worth(r, today, word) and r or nil
end

-- Everyone with something to show today, by name: guildmates heard this session, and those
-- whose scores for today were saved before a reload or before they logged off.
function Guild.Day()
    local book = DayBook()
    local list = {}
    for name, r in pairs(book and book.names or {}) do list[name] = r end
    for name, m in pairs(members) do
        if not list[name] then list[name] = m end
    end
    return list
end

local function Store(payload, name, sender)
    local version, wordDay, wordScore, iconDay, iconScore, guildID, guildScore, average, solved, reports, recipes, _, restartSince, loot, orders, run, person = strsplit(";", payload or "")
    local runDay, runSteps, runPal = (run or ""):match("^(%d+):(%d+):(.*)$")
    if ns.Crafters then ns.Crafters.HeardHello(name, recipes, sender or name) end
    if ns.GuildLoot then ns.GuildLoot.HeardHello(name, loot, sender or name) end
    if ns.Orders then ns.Orders.HeardHello(name, orders, sender or name) end
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
        person = HeardPerson(person) or before.person,
        seen = GetTime(),
    }
    Keep(name, members[name])
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
    Keep(name, m)
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

-- A minute after login, a second hello if a guildmate the roster has on, and known to have
-- jsal.ui, hasn't answered the first: each answers a hello at most every 30 seconds, so two
-- reloads close together leave the second unanswered. One look at the roster, once a login.
function Guild.HelloAgain()
    if not (Guild.running and IsInGuild()) then return end
    local seen, me = SeenList(), Compat.MyName()
    if not seen then return end
    for name in pairs(Compat.GuildOnline()) do
        if name ~= me and seen.names[name] and not members[name] then
            Guild.Hello()
            return
        end
    end
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
            Comms.Send("ME", Status(true), "WHISPER", sender)
            Comms.Send("GD", Details(), "WHISPER", sender)
            local word = WordPayload()
            if word then Comms.Send("GW", word, "WHISPER", sender) end
        end
    end)
    Comms.On("ME", Answer)
    Comms.On("GW", HeardWord)
    Comms.On("GD", HeardDetails)
    Compat.After(8, Guild.Hello)
    Compat.After(75, Guild.HelloAgain)
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

-- Who of those heard this session is on now, by name: on by the guild's roster, or heard in
-- the last few minutes. With no roster in yet, everyone heard counts.
function Guild.OnNow()
    local online = Compat.GuildOnline()
    local known = next(online) ~= nil
    local now, on = GetTime(), {}
    for name, m in pairs(members) do
        if not known or online[name] or now - (m.seen or 0) <= HEARD then on[name] = true end
    end
    return on
end

-- Which jsal.ui each guildmate has, for /jsal versions: those on now first, the newest version
-- first, then those seen before, the most recently seen first. The Guild page's VERSION column
-- went when it was folded into Games (John, 19 Nov 2026: "what is the command to show all the
-- guildies versions now?").
function Guild.Versions()
    if not Compat.GuildName() then
        ns.Print("You're not in a guild.")
        return
    end
    Prune()
    local me, on, away = Compat.MyName(), {}, {}
    for name, m in pairs(members) do
        if name ~= me and m.version then on[#on + 1] = { name = name, version = m.version } end
    end
    local function Newer(a, b) return ns.Newer(a.version or "0", b.version or "0") end
    table.sort(on, function(a, b)
        if Newer(a, b) ~= Newer(b, a) then return Newer(a, b) end
        return a.name < b.name
    end)
    local seen, now = SeenList(), Compat.ServerTime()
    for name, entry in pairs(seen and seen.names or {}) do
        if name ~= me and not (members[name] and members[name].version) and type(entry) == "table" then
            away[#away + 1] = { name = name, version = entry.version, last = entry.last or 0 }
        end
    end
    table.sort(away, function(a, b)
        if a.last ~= b.last then return a.last > b.last end
        return a.name < b.name
    end)
    local function Version(v) return (v and v ~= "") and v or "an older version" end
    ns.Print(("jsal.ui in your guild. You have %s."):format(ns.version))
    if #on + #away == 0 then print("  No guildmate heard with jsal.ui yet.") end
    for _, e in ipairs(on) do print(("  %s: %s, on now"):format(e.name, Version(e.version))) end
    for _, e in ipairs(away) do
        print(("  %s: %s, seen %s"):format(e.name, Version(e.version), Compat.DaysAgo(math.floor((now - e.last) / 86400))))
    end
end
if ns.Command then ns.Command("versions", Guild.Versions) end

ns.Guild = Guild
