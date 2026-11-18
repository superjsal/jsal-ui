-- The Guild tab: who in the guild runs jsal.ui, today's game scores, and the
-- Guild Word, a word the guild master sets for the whole guild to play. It hears
-- only guildmates who have jsal.ui, through addon messages, and keeps
-- guildmates' scores for this session only.
local _, ns = ...
local Style, Compat, Comms, Window = ns.Style, ns.Compat, ns.Comms, ns.Window

local Guild = ns.NewModule("guild", {
    title = "Guild tab",
    note = "Guildmates with jsal.ui, today's scores and the Guild Word. /jsal guild",
})

local members, answered = {}, {}
local MAX_ROWS = 14

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
    members[name] = {
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

-- Tells the guild a game was finished, so the scores update for everyone.
function Guild.Announce()
    if Guild.running and IsInGuild() then
        Comms.Send("ME", Status())
    end
end

-- A Guild Word game finished: tell the guild.
function Guild.WordResult()
    Guild.Announce()
end

-- The guild master sets a new Guild Word. Returns false and why, or true.
function Guild.SetWord(word)
    word = strtrim(word or ""):lower()
    if not Compat.IsGuildMaster() then return false, "Only the guild master can set the Guild Word." end
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
    -- Only the guild master's word counts. A word passed on by a guildmate
    -- names who set it, so the check is on the setter, by the roster.
    local setBy = setter ~= "" and setter or name
    if Compat.IsGuildMasterName(setBy) == false then return end
    if SaveWord(id, code, setter ~= "" and setter or name) then
        if setter ~= Compat.MyName() then
            ns.Print(("New Guild Word from %s. /jsal guild to play it."):format(setter ~= "" and setter or name))
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
            local word = WordPayload()
            if word then Comms.Send("GW", word, "WHISPER", sender) end
        end
    end)
    Comms.On("ME", Answer)
    Comms.On("GW", HeardWord)
    Compat.After(8, Guild.Hello)
end

function Guild:OnDisable()
    Comms.On("HI", nil)
    Comms.On("ME", nil)
    Comms.On("GW", nil)
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

-- Today's scores first: fewest Daily Word tries, then most icons right.
local function Sorted(wordID)
    Prune()
    local today = ns.Games.Today()
    local list = {}
    for name, m in pairs(members) do
        list[#list + 1] = {
            name = name, version = m.version, average = m.average, solved = m.solved,
            word = m.wordDay == today and m.wordScore or nil,
            icons = m.iconDay == today and m.iconScore or nil,
            guild = wordID and m.guildID == wordID and m.guildScore or nil,
        }
    end
    local function WordRank(e)
        if not e.word then return 99 end
        return e.word == "X" and 7 or tonumber(e.word) or 98
    end
    table.sort(list, function(a, b)
        local wa, wb = WordRank(a), WordRank(b)
        if wa ~= wb then return wa < wb end
        local ia, ib = tonumber(a.icons) or -1, tonumber(b.icons) or -1
        if ia ~= ib then return ia > ib end
        return a.name < b.name
    end)
    -- Then those not heard this session, the most recently seen first.
    local away = {}
    local seen = SeenList()
    for name, entry in pairs(seen and seen.names or {}) do
        if not members[name] and type(entry) == "table" then
            away[#away + 1] = { name = name, version = entry.version, last = entry.last or 0, away = true }
        end
    end
    table.sort(away, function(a, b) return a.last > b.last end)
    for _, e in ipairs(away) do list[#list + 1] = e end
    return list
end

-- "today", "yesterday", or how many days ago.
local function Ago(t)
    return Compat.DaysAgo(math.floor((Compat.ServerTime() - (t or 0)) / 86400))
end

local function Tries(score)
    if not score then return "Not yet" end
    return score == "X" and "Missed" or (score .. " of 6")
end

Window.Page("guild", function(page)
    -- Across the dashboard's whole width: the guildmates at the left, and at
    -- the right a column for the Guild Word and today's best.
    local width = Window.fullWidth
    local SIDE_W, GAP = 300, 24
    local tableW, sideX = width - SIDE_W - GAP, width - SIDE_W
    local title, lead = Window.Header(page, width)
    lead:SetText("How guildmates with jsal.ui did today. Those not online now are dimmed, with when they were last seen.")

    -- The Guild Word card: what's set and a Play button; the guild master gets a
    -- box to set a new one.
    local card = Style.Card(page, "Guild Word")
    card:SetSize(SIDE_W, 136)
    card:SetPoint("TOPLEFT", lead, "BOTTOMLEFT", sideX, -14)
    local wordText = Style.Text(card, 13, "text")
    wordText:SetPoint("TOPLEFT", card.heading, "BOTTOMLEFT", 0, -8)
    wordText:SetWidth(SIDE_W - 24)
    wordText:SetJustifyH("LEFT")
    local play = Style.Button(card, "Play", "primary", 110)
    play:SetPoint("TOPLEFT", 12, -92)
    play:SetScript("OnClick", function()
        local word = Guild.Word()
        if word then ns.DailyWord.OpenGuild(word) end
    end)
    local box = CreateFrame("EditBox", nil, card)
    box:SetSize(120, 24)
    box:SetPoint("TOPLEFT", 12, -134)
    box:SetAutoFocus(false)
    box:SetMaxLetters(8)
    box:SetFont(Style.font, 12, "")
    box:SetTextColor(Style.Color("text"))
    box:SetTextInsets(8, 8, 0, 0)
    Style.Box(box, 5, "window", "lineStrong")
    local set = Style.Button(card, "Set word", "plain", 90)
    set:SetHeight(24)
    set:SetPoint("LEFT", box, "RIGHT", 6, 0)
    local setNote = Style.Text(card, 11, "muted")
    setNote:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -8)
    setNote:SetWidth(SIDE_W - 24)
    setNote:SetJustifyH("LEFT")
    setNote:SetText("Guild master: a word of 5 to 8 letters for the whole guild.")

    -- Under it, today's best: who solved the Daily Word in the fewest tries,
    -- who named the most icons, and whose average is lowest.
    local bestHead = Style.Section(page, SIDE_W)
    bestHead:SetPoint("TOPLEFT", card, "BOTTOMLEFT", 0, -22)
    bestHead.title:SetText("TODAY'S BEST")
    local bests = {}
    for i, label in ipairs({ "Daily Word", "Icon Guess", "Word average" }) do
        local b = Style.Card(page, label)
        b:SetSize(SIDE_W, 58)
        b:SetPoint("TOPLEFT", bestHead, "BOTTOMLEFT", 0, -(10 + (i - 1) * 68))
        b.name = Style.Text(b, 14, "text", nil, true)
        b.name:SetPoint("BOTTOMLEFT", 12, 10)
        b.value = Style.Text(b, 14, "gold", nil, true)
        b.value:SetPoint("BOTTOMRIGHT", -12, 10)
        b.value:SetJustifyH("RIGHT")
        bests[i] = b
    end
    local function SetWord()
        local ok, why = Guild.SetWord(box:GetText())
        if ok then
            box:SetText("")
            box:ClearFocus()
            setNote:SetText("Sent to the guild.")
        else
            setNote:SetText(why)
        end
        page.Refresh()
    end
    set:SetScript("OnClick", SetWord)
    box:SetScript("OnEnterPressed", SetWord)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    local COLUMNS = { { "Name", 0 }, { "Daily Word", 210 }, { "Word average", 320 }, { "Icon Guess", 446 },
        { "Guild Word", 552 }, { "Version", 642 } }
    local header = CreateFrame("Frame", nil, page)
    header:SetSize(tableW, 24)
    header:SetPoint("TOPLEFT", lead, "BOTTOMLEFT", 0, -14)
    Style.Rule(header, "BOTTOM", "lineStrong")
    for _, column in ipairs(COLUMNS) do
        local t = Style.Text(header, 11, "muted", nil, true)
        t:SetPoint("TOPLEFT", column[2], -4)
        t:SetText(column[1]:upper())
    end

    local rows = {}
    for i = 1, MAX_ROWS do
        local row = CreateFrame("Frame", nil, page)
        row:SetSize(tableW, 28)
        row:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -(i - 1) * 28)
        Style.Rule(row, "BOTTOM", "line")
        -- A small square before the name: green while they're on.
        row.dot = row:CreateTexture(nil, "ARTWORK")
        row.dot:SetSize(7, 7)
        row.dot:SetPoint("LEFT", 0, 0)
        row.cells = {}
        for c, column in ipairs(COLUMNS) do
            local t = Style.Text(row, 13, c == 1 and "text" or "muted")
            t:SetPoint("LEFT", column[2] + (c == 1 and 14 or 0), 0)
            row.cells[c] = t
        end
        rows[i] = row
    end

    local empty = Style.Text(page, 13, "text")
    empty:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -12)
    empty:SetWidth(tableW)
    local more = Style.Text(page, 11, "muted")
    more:SetPoint("TOPLEFT", rows[MAX_ROWS], "BOTTOMLEFT", 0, -8)

    -- Each part of a paint, timed, so /jsal perf can say which is slow. A part is noted only when
    -- the paint was slow.
    local spent = {}
    local function Spent(part, since)
        local now = debugprofilestop()
        spent[part] = (spent[part] or 0) + now - since
        return now
    end
    page.Refresh = function()
        local started = debugprofilestop()
        spent = {}
        Guild.Hello()
        local t = Spent("hello to the guild", started)
        local inGuild = IsInGuild()
        if Guild.running and inGuild then
            local status = Status()
            t = Spent("your own scores, put together", t)
            Store(status, Compat.MyName())
            t = Spent("your own scores, kept", t)
        end
        local word = Guild.Word()
        local list = Sorted(word and word.id)
        t = Spent("who's on, from the roster", t)
        -- The title: how many of the guild run jsal.ui, and how many are on.
        local online = 0
        for _, e in ipairs(list) do if not e.away then online = online + 1 end end
        if not Guild.running then
            title:SetText("The Guild tab is turned off")
        elseif not inGuild then
            title:SetText("You're not in a guild yet")
        else
            title:SetText(("%d in your guild run%s jsal.ui   |cff9a9688%d online|r"):format(#list, #list == 1 and "s" or "", online))
        end

        -- The Guild Word card.
        local officer = Compat.IsGuildMaster()
        box:SetShown(Guild.running and officer)
        set:SetShown(Guild.running and officer)
        setNote:SetShown(Guild.running and officer)
        card:SetHeight((Guild.running and officer) and 204 or 136)
        if not (Guild.running and inGuild) then
            wordText:SetText("Join a guild, and turn on the Guild tab, to play the Guild Word.")
            play:Hide()
        elseif not word then
            wordText:SetText("No Guild Word yet. When the guild master sets one, it shows up here for everyone.")
            play:Hide()
        else
            local played = 0
            for _, e in ipairs(list) do if e.guild then played = played + 1 end end
            local mine = ns.DailyWord.GuildResult(word.id)
            wordText:SetText(("%d letters, set by %s. %d of you have played it%s."):format(#word.answer, word.setter, played,
                mine and (", you " .. (mine == "X" and "missed it" or ("got it in " .. mine))) or ""))
            play:Show()
            play:SetLabel(mine and "See result" or "Play")
        end

        if not Guild.running then
            empty:SetText("The Guild tab is turned off. /jsal settings turns it on.")
        elseif not inGuild then
            empty:SetText("You're not in a guild yet.")
        elseif #list == 0 then
            empty:SetText("No one yet. Guildmates show up as they log in with jsal.ui.")
        end
        empty:SetShown(#list == 0 or not Guild.running or not inGuild)
        for i, row in ipairs(rows) do
            local e = Guild.running and list[i]
            row:SetShown(e and true or false)
            if e then row.dot:SetColorTexture(Style.Color(e.away and "lineStrong" or "green")) end
            if e and e.away then
                -- Not online now: greyed, with when they were last seen
                -- beside the name, where it sat under the Daily Word heading
                -- as if it were a score.
                row:SetAlpha(0.65)
                row.cells[1]:SetText(e.name .. "  |cff9a9688·  last seen " .. Ago(e.last) .. "|r")
                for c = 2, 5 do row.cells[c]:SetText("") end
                row.cells[6]:SetText(e.version or "")
            elseif e then
                row:SetAlpha(1)
                row.cells[1]:SetText(e.name)
                row.cells[2]:SetText(Tries(e.word))
                -- Average tries over every word solved, and how many.
                row.cells[3]:SetText(e.average and ("%.1f |cff9a9688(%d)|r"):format(e.average, e.solved or 0) or "-")
                row.cells[4]:SetText(e.icons and (e.icons .. " of 10") or "Not yet")
                row.cells[5]:SetText(word and Tries(e.guild) or "")
                row.cells[6]:SetText(e.version or "")
            end
        end
        more:SetText(#list > MAX_ROWS and ("and %d more"):format(#list - MAX_ROWS) or "")

        -- Today's best, of those who've played: the first in the list where
        -- two are level.
        local live = Guild.running and inGuild
        bestHead:SetShown(live)
        local word1, icons1, average1
        for _, e in ipairs(live and list or {}) do
            local tries = tonumber(e.word)
            if tries and (not word1 or tries < tonumber(word1.word)) then word1 = e end
            local named = tonumber(e.icons)
            if named and (not icons1 or named > tonumber(icons1.icons)) then icons1 = e end
            if e.average and (e.solved or 0) > 0 and (not average1 or e.average < average1.average) then average1 = e end
        end
        for i, found in ipairs({ { word1, word1 and ("in " .. word1.word) }, { icons1, icons1 and (icons1.icons .. " of 10") },
                                 { average1, average1 and ("%.1f tries"):format(average1.average) } }) do
            local b = bests[i]
            b:SetShown(live)
            b.name:SetText(found[1] and found[1].name or "No one yet")
            b.name:SetTextColor(Style.Color(found[1] and "text" or "muted"))
            b.value:SetText(found[2] or "")
        end
        Spent("drawing", t)
        if debugprofilestop() - started >= 10 then
            for part, ms in pairs(spent) do ns.NoteTime("Guild, " .. part, ms) end
        end
    end
end, nil, true)

ns.Guild = Guild
