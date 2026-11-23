-- What the games share: today's puzzle number, a random sequence that comes
-- out the same on every player's game, the Today card and the Games page.
local _, ns = ...
local Style, Compat, Window = ns.Style, ns.Compat, ns.Window

local Games = {}
ns.Games = Games

-- Puzzle #1 is the daily reset of 7 November 2026. The number turns over at
-- the region's daily reset, so everyone on a region shares each puzzle.
local FIRST_DAY = 20764
local DAY = 86400

function Games.Today()
    local nextReset = Compat.ServerTime() + Compat.SecondsUntilDailyReset()
    return math.max(1, math.floor(nextReset / DAY) - FIRST_DAY + 1)
end

-- How long until the next day's games, as the heading says it: "14h 20m", minutes alone in
-- the last hour. The day still turns over at the daily reset; the number counting days is
-- never shown, as how long is left says more than which day it is.
-- `short`: the hours alone, for Home's small card ("14h").
function Games.Until(short)
    local left = math.max(0, Compat.SecondsUntilDailyReset() or 0)
    local hours, minutes = math.floor(left / 3600), math.floor(left % 3600 / 60)
    if hours == 0 then return math.max(1, minutes) .. "m" end
    if short then return hours .. "h" end
    return ("%dh %02dm"):format(hours, minutes)
end

-- Park and Miller's generator: the same seed gives every player the same
-- numbers. random(n) returns 1 to n.
function Games.Random(seed)
    local state = seed % 2147483646 + 1
    return function(n)
        state = (state * 16807) % 2147483647
        return state % n + 1
    end
end

-- The Guild Word as one of the games, on this page with the rest of the guild's day. It
-- answers what a card asks of a game, from the word the guild master or an officer set and
-- what guildmates have told the guild.
local GuildWord = { running = false }
local function GuildWordGame()
    local guild = ns.Guild
    GuildWord.running = guild ~= nil and guild.running == true and ns.DailyWord ~= nil and ns.DailyWord.running == true
        and IsInGuild() and true or false
    GuildWord.word = GuildWord.running and guild.Word and guild.Word() or nil
    return GuildWord
end
function GuildWord.DailyDone()
    return GuildWord.word ~= nil and ns.DailyWord.GuildResult(GuildWord.word.id) ~= nil
end
-- Who has played this word, the best first: { name, score, mine }.
function GuildWord.Played()
    local word, list = GuildWord.word, {}
    if not word then return list end
    local me = Compat.MyName()
    for name, m in pairs(ns.Guild.Day() or {}) do
        if m.guildID == word.id and m.guildScore and name ~= me then
            list[#list + 1] = { name = name, score = m.guildScore }
        end
    end
    local mine = ns.DailyWord.GuildResult(word.id)
    if mine then list[#list + 1] = { name = me, score = mine, mine = true } end
    local function Rank(e) return e.score == "X" and 7 or tonumber(e.score) or 8 end
    table.sort(list, function(a, b)
        if Rank(a) ~= Rank(b) then return Rank(a) < Rank(b) end
        return a.name < b.name
    end)
    return list
end
function GuildWord.Status()
    if not (ns.Guild and ns.Guild.running and ns.DailyWord and ns.DailyWord.running) then return "Off in Settings" end
    if not IsInGuild() then return "Join a guild to play" end
    local word = GuildWord.word
    if not word then return "No word set yet" end
    local mine = ns.DailyWord.GuildResult(word.id)
    if mine then return mine == "X" and "Missed it" or ("Solved in " .. mine) end
    return word.setter == Compat.MyName() and "Set by you" or ("Set by " .. word.setter)
end
function GuildWord.Numbers()
    local word = GuildWord.word
    if not word then return {} end
    local heard, me = 1, Compat.MyName()
    for name in pairs(ns.Guild.Day() or {}) do if name ~= me then heard = heard + 1 end end
    return { { ("%d of %d"):format(#GuildWord.Played(), heard), "have played" }, { tostring(#word.answer), "letters" } }
end
function GuildWord.Record()
    if not GuildWord.running then return "" end
    return "When the guild master or an officer sets a word, it shows here for everyone."
end
function GuildWord.Open()
    if GuildWord.word then ns.DailyWord.OpenGuild(GuildWord.word) end
end

-- Set word, for the guild master and officers: a small window with a box, as Report a problem's Discord
-- link opens one, so the card stays the shape of the others.
local setter
function Games.SetWord()
    if not setter then
        local WIDTH = 400
        setter = Style.Panel("jsalUISetGuildWord", WIDTH, 170, "Set the Guild Word")
        setter:SetFrameStrata("DIALOG")
        local note = Style.Text(setter, 13, "secondary")
        note:SetPoint("TOPLEFT", 16, -44)
        note:SetWidth(WIDTH - 32)
        note:SetJustifyH("LEFT")
        note:SetText("One word for the whole guild, five to eight letters. It takes the place of today's.")
        local box = Style.Field(setter, WIDTH - 32 - 110)
        box.well:SetPoint("TOPLEFT", 16, -86)
        box:SetMaxLetters(8)
        local set = Style.Button(setter, "Set word", "primary", 100)
        set:SetHeight(26)
        set:SetPoint("TOPRIGHT", -16, -86)
        local said = Style.Text(setter, 12, "muted")
        said:SetPoint("TOPLEFT", 16, -126)
        said:SetWidth(WIDTH - 32)
        said:SetJustifyH("LEFT")
        local function Set()
            local ok, why = ns.Guild.SetWord(box:GetText())
            if ok then
                box:SetText("")
                box:ClearFocus()
                setter:Hide()
                Window.Refresh()
            else
                said:SetText(why)
                said:SetTextColor(Style.Color("red"))
            end
        end
        set:SetScript("OnClick", Set)
        box:SetScript("OnEnterPressed", Set)
        box:SetScript("OnEscapePressed", function() setter:Hide() end)
        setter.box, setter.said = box, said
    end
    setter.said:SetText("Guildmates with jsal.ui get it at once. Escape closes this.")
    setter.said:SetTextColor(Style.Color("muted"))
    setter:Show()
    setter.box:SetFocus()
    return setter
end

-- The Games page: a card for each daily game, three across and the Guild
-- Word under them, with how today's stands, your record as numbers, and a
-- button to play it or see how it went; beside the Guild Word, how your guild
-- did today. Pal run can be run
-- again for a better time, so its button plays while it has runs left.
-- `body` is what a card shows under its numbers: your tries as bars, today's
-- board, or, with neither, its `words`.
local GAMES = {
    { label = "Daily Word", icon = "word", game = function() return ns.DailyWord end, body = "tries" },
    { label = "Icon Guess", icon = "icons", game = function() return ns.IconGuess end, practice = true,
      words = "Ten spells, one at a time: name each from its icon." },
    { label = "Pal run", icon = "run", game = function() return ns.PalRun end, practice = true, again = true, body = "board" },
    { label = "Guild Word", icon = "guild", game = GuildWordGame, body = "guild", setword = true },
}

-- A game's record without its own name in front ("Daily Word: 1 played"
-- under a card that already says Daily Word).
local function Tidy(text)
    text = (text or ""):gsub("^[^:]+:%s*", "")
    return (text:gsub("^%l", string.upper))
end

-- A guildmate's Daily Word today, in words.
local function Tries(score)
    if not score then return nil end
    return score == "X" and "Missed" or (score .. " of 6")
end

-- How your guild did today, for the foot of the page: a row for you, each
-- guildmate heard this session with jsal.ui and each one who played today
-- and has since gone, the best Daily Word first, each with today's Daily
-- Word, Icon Guess and Pal run where they've played. Nil with Guild games
-- off. You're among them, so with no guildmate on it still has your day.
-- Each says whether they're on now (`on`); one who has gone and played
-- nothing today has nothing to show and is left out.
function Games.GuildToday()
    local guild = ns.Guild
    if not (guild and guild.running and guild.Day) then return nil end
    local today, list = Games.Today(), {}
    local gw, me = guild.Word and guild.Word(), Compat.MyName()
    local on = guild.OnNow()
    for name, m in pairs(guild.Day()) do
        local e = name ~= me and {
            name = name, on = on[name] == true,
            word = m.wordDay == today and m.wordScore or nil,
            icons = m.iconDay == today and m.iconScore or nil,
            run = m.runDay == today and m.runSteps or nil,
            pal = m.runDay == today and m.runPal or nil,
            guild = gw and m.guildID == gw.id and m.guildScore or nil,
            -- How their games went, from guildmates on 0.3.57 or later.
            wordMarks = m.marksDay == today and m.wordMarks or nil,
            iconMarks = m.marksDay == today and m.iconMarks or nil,
            guildMarks = gw and m.guildMarksID == gw.id and m.guildMarks or nil,
            person = m.person, seen = m.seen,
        }
        if e and (e.on or e.word or e.icons or e.run or e.guild) then list[#list + 1] = e end
    end
    -- Your own row, from your own games.
    local function Today(game)
        if not (game and game.running and game.Result) then return nil end
        local day, score = game.Result()
        return day == today and score or nil
    end
    local dw, ig, pr = ns.DailyWord, ns.IconGuess, ns.PalRun
    local function Marks(text) return (text and text ~= "") and text or nil end
    list[#list + 1] = {
        name = me, mine = true, on = true,
        word = Today(dw), icons = Today(ig), run = Today(pr),
        pal = pr and pr.PalName and pr.PalName() or nil,
        guild = gw and dw and dw.GuildResult and dw.GuildResult(gw.id) or nil,
        wordMarks = dw and dw.Marks and Marks(dw.Marks()) or nil,
        iconMarks = ig and ig.Marks and Marks(ig.Marks()) or nil,
        guildMarks = gw and dw and dw.GuildMarks and Marks(dw.GuildMarks(gw)) or nil,
        person = guild.Person and guild.Person() or nil,
    }
    list = Games.OneRowAPerson(list)
    local function Rank(e)
        if not e.word then return 99 end
        return e.word == "X" and 7 or tonumber(e.word) or 98
    end
    table.sort(list, function(a, b)
        if Rank(a) ~= Rank(b) then return Rank(a) < Rank(b) end
        return a.name < b.name
    end)
    return list
end

-- One row a person: characters carrying one account's number are one row, named for yours, else the one
-- on now, else the one heard from last. A game's result is the row's own where it has one, else the first
-- of the others' (every game keeps a day's result for the account, so they agree). Characters with no
-- number (a guildmate on an older version) stay a row each.
local RESULTS = { { "word", "wordMarks" }, { "icons", "iconMarks" }, { "run", "pal" }, { "guild", "guildMarks" } }
function Games.OneRowAPerson(list)
    local groups, order = {}, {}
    for _, e in ipairs(list) do
        local key = e.person or e
        if not groups[key] then
            groups[key] = {}
            order[#order + 1] = key
        end
        local g = groups[key]
        g[#g + 1] = e
    end
    local out = {}
    for _, key in ipairs(order) do
        local g = groups[key]
        if #g > 1 then
            table.sort(g, function(a, b)
                if (a.mine or false) ~= (b.mine or false) then return a.mine == true end
                if (a.on or false) ~= (b.on or false) then return a.on == true end
                if (a.seen or 0) ~= (b.seen or 0) then return (a.seen or 0) > (b.seen or 0) end
                return a.name < b.name
            end)
            local lead = g[1]
            for i = 2, #g do
                for _, fields in ipairs(RESULTS) do
                    if lead[fields[1]] == nil and g[i][fields[1]] ~= nil then
                        for _, f in ipairs(fields) do lead[f] = g[i][f] end
                    end
                end
            end
        end
        out[#out + 1] = g[1]
    end
    return out
end

-- A guildmate's day, shown beside their row on the Games page while it's pointed at: their name,
-- then a gold heading a game, its score under it, and for the Word games the grid as tiles (never
-- the letters), for Icon Guess its ten, all of it centred. A card of its own, not the game's
-- tooltip, so its gaps can be set: a tooltip spaces a game from the next by a whole blank line.
-- Made the first time it's wanted.
local TILES = { r = "green", n = "gold", x = "lineStrong", ["1"] = "green", ["0"] = "lineStrong" }
local DAY_PAD, DAY_GAP, DAY_HEAD, DAY_SCORE = 12, 12, 3, 6   -- the card's edge; between games; under a heading; under a score
-- A touch bigger than first drawn: the words a size up, the tiles 16.
local day
local function DayCard()
    if day then return day end
    day = CreateFrame("Frame", "jsalUIGuildDay", UIParent)
    day:SetFrameStrata("TOOLTIP")
    day:SetClampedToScreen(true)
    day:Hide()
    Style.Box(day, 5, "titleBar", "lineStrong")
    day.title = Style.Text(day, 15, "text", nil, true)
    day.heads, day.scores, day.tiles = {}, {}, {}
    return day
end
local function Pooled(list, i, make)
    if not list[i] then list[i] = make() end
    return list[i]
end
function Games.HideDay()
    if day then day:Hide() end
end
function Games.ShowDay(owner, e)
    local c = DayCard()
    local y, widest = DAY_PAD, 0
    c.title:ClearAllPoints()
    c.title:SetPoint("TOP", 0, -y)
    c.title:SetText(e.name)   -- the name alone ("dont need the today part, name is fine")
    widest = math.max(widest, c.title:GetStringWidth() or 0)
    y = y + 19
    local games, used = 0, 0
    local function Game(head, score, rows, size)
        games = games + 1
        y = y + (games == 1 and 2 or DAY_GAP)
        local h = Pooled(c.heads, games, function() return Style.Text(c, 12, "gold", nil, true) end)
        h:ClearAllPoints()
        h:SetPoint("TOP", 0, -y)
        h:SetText(head)
        h:Show()
        y = y + 14 + DAY_HEAD
        local sc = Pooled(c.scores, games, function() return Style.Text(c, 14, "text") end)
        sc:ClearAllPoints()
        sc:SetPoint("TOP", 0, -y)
        sc:SetText(score or "Not played yet")
        sc:SetTextColor(Style.Color(score and "text" or "muted"))
        sc:Show()
        widest = math.max(widest, h:GetStringWidth() or 0, sc:GetStringWidth() or 0)
        y = y + 16
        local first = true
        for row in (rows or ""):gmatch("[^.]+") do
            y = y + (first and DAY_SCORE or 3)
            first = false
            -- A row is centred on the card: its left end half its width left of the middle.
            local count = 0
            for ch in row:gmatch(".") do if TILES[ch] then count = count + 1 end end
            local rowW = count * size + math.max(0, count - 1) * 3
            local x = -rowW / 2
            for ch in row:gmatch(".") do
                if TILES[ch] then
                    used = used + 1
                    local t = Pooled(c.tiles, used, function() return c:CreateTexture(nil, "ARTWORK") end)
                    t:ClearAllPoints()
                    t:SetSize(size, size)
                    t:SetPoint("TOPLEFT", c, "TOP", x, -y)
                    t:SetColorTexture(Style.Color(TILES[ch]))
                    t:Show()
                    x = x + size + 3
                end
            end
            widest = math.max(widest, rowW)
            y = y + size
        end
    end
    local function Word(score) return score and (score == "X" and "Missed" or ("Solved in " .. score)) or nil end
    Game("DAILY WORD", Word(e.word), e.word and e.wordMarks, 16)
    -- Its ten in two rows of five, a block the width of the word's grid ("do 2 columns for icon").
    local ten = e.icons and e.iconMarks and (e.iconMarks:sub(1, 5) .. "." .. e.iconMarks:sub(6)) or nil
    Game("ICON GUESS", e.icons and (e.icons .. " of 10") or nil, ten, 16)
    local run = e.run and ns.PalRun and ns.PalRun.Clock and ns.PalRun.Clock(e.run) or nil
    Game("PAL RUN", run and (run .. ((e.pal and e.pal ~= "") and ("  with " .. e.pal) or "")) or nil)
    if GuildWord.running and GuildWord.word then Game("GUILD WORD", Word(e.guild), e.guild and e.guildMarks, 14) end
    for i = games + 1, #c.heads do c.heads[i]:Hide(); c.scores[i]:Hide() end
    for i = used + 1, #c.tiles do c.tiles[i]:Hide() end
    c:SetSize(math.ceil(widest) + DAY_PAD * 2, y + DAY_PAD)
    c:ClearAllPoints()
    c:SetPoint("BOTTOM", owner, "TOP", 0, 4)
    c:Show()
    return c
end

Window.Page("games", function(page)
    local Heading, Tick
    local width = Window.fullWidth
    local GAP, CARD_H, PAD, CARDS_Y = 16, 346, 18, 70
    -- Three cards across; the fourth starts the row under them, a card wide,
    -- down to the page's foot, with how your guild did today beside it.
    local ACROSS = 3
    local cardW = math.floor((width - GAP * (ACROSS - 1)) / ACROSS)
    local inner = cardW - PAD * 2
    local GUILD_Y = CARDS_Y + CARD_H + 24
    local title = Style.Text(page, 23, "text", nil, true)
    title:SetPoint("TOPLEFT")
    local sub = Style.Text(page, 13, "muted")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    sub:SetText("Each day's games are the same for everyone, so you can compare with your guild. They're offered when a flight starts, too.")

    -- A card a game: its tile, its name and how today's stands; its record
    -- as numbers; something of its own under those; and its buttons at the foot.
    local cards = {}
    for i, entry in ipairs(GAMES) do
        local c = CreateFrame("Frame", nil, page)
        if i <= ACROSS then
            c:SetSize(cardW, CARD_H)
            c:SetPoint("TOPLEFT", (i - 1) * (cardW + GAP), -CARDS_Y)
        else
            c:SetSize(cardW, Window.contentHeight - GUILD_Y)
            c:SetPoint("TOPLEFT", (i - ACROSS - 1) * (cardW + GAP), -GUILD_Y)
        end
        Style.Box(c, 6, "well", "cardLine")
        local icon = c:CreateTexture(nil, "ARTWORK")
        icon:SetSize(48, 48)
        icon:SetPoint("TOPLEFT", PAD, -16)
        icon:SetTexture("Interface\\AddOns\\jsalUI\\Media\\Icons\\" .. entry.icon)
        local name = Style.Text(c, 17, "text", nil, true)
        name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 14, -1)
        name:SetText(entry.label)
        c.state = Style.Text(c, 13, "text", nil, true)
        c.state:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3)
        c.state:SetWidth(inner - 62)
        c.state:SetJustifyH("LEFT")
        c.state:SetWordWrap(false)
        -- Its record: up to five numbers, each with what it counts under it;
        -- or, before there's one, a line that says so.
        c.numbers = {}
        for k = 1, 5 do
            local n = { value = Style.Text(c, 16, "text", nil, true), label = Style.Text(c, 11, "muted") }
            n.label:SetPoint("TOPLEFT", n.value, "BOTTOMLEFT", 0, -2)
            c.numbers[k] = n
        end
        c.record = Style.Text(c, 12, "muted")
        c.record:SetPoint("TOPLEFT", PAD, -88)
        c.record:SetWidth(inner)
        c.record:SetJustifyH("LEFT")
        -- Under the numbers, by the game: your tries as bars, a line of what
        -- the game is, or today's board.
        c.head = Style.Text(c, 10, "muted", nil, true)
        c.head:SetPoint("TOPLEFT", PAD, -140)
        c.words = Style.Text(c, 12, "muted")
        c.words:SetPoint("TOPLEFT", PAD, -140)
        c.words:SetWidth(inner)
        c.words:SetJustifyH("LEFT")
        c.lines = {}
        for k = 1, 6 do
            local l = { key = Style.Text(c, 11, "muted"), value = Style.Text(c, 11, "muted"), bar = c:CreateTexture(nil, "ARTWORK"),
                        name = Style.Text(c, 13, "text"), time = Style.Text(c, 13, "text", nil, true) }
            local y = -(162 + (k - 1) * 20)
            l.key:SetPoint("TOPLEFT", PAD, y)
            l.bar:SetPoint("TOPLEFT", PAD + 16, y - 4)
            l.bar:SetHeight(8)
            l.value:SetPoint("LEFT", l.bar, "RIGHT", 8, 0)
            l.name:SetPoint("TOPLEFT", PAD + 18, y + 1)
            l.name:SetWidth(inner - 18 - 70)
            l.name:SetJustifyH("LEFT")
            l.name:SetWordWrap(false)
            l.time:SetPoint("TOPRIGHT", -PAD, y + 1)
            l.time:SetJustifyH("RIGHT")
            c.lines[k] = l
        end
        c.play = Style.Button(c, "Play", "plain", 100)
        c.play:SetHeight(30)
        c.play:SetPoint("BOTTOMRIGHT", -PAD, 16)
        c.play:SetScript("OnClick", function() entry.game().Open() end)
        if entry.practice then
            c.practice = Style.Button(c, "Practice", "plain", 100)
            c.practice:SetHeight(30)
            c.practice:SetPoint("RIGHT", c.play, "LEFT", -8, 0)
            c.practice:SetScript("OnClick", function() entry.game().Practice() end)
        end
        if entry.setword then
            c.set = Style.Button(c, "Set word", "plain", 100)
            c.set:SetHeight(30)
            c.set:SetPoint("RIGHT", c.play, "LEFT", -8, 0)
            c.set:SetScript("OnClick", function() Games.SetWord() end)
        end
        cards[i] = c
    end
    -- A narrow card shows four numbers of a record at most.
    local MOST = inner < 260 and 4 or 5

    -- A card's lines, all put away, before the ones it uses are shown.
    local function Clear(c)
        c.head:SetText("")
        c.words:SetText("")
        for _, l in ipairs(c.lines) do
            for _, region in ipairs({ l.key, l.value, l.bar, l.name, l.time }) do region:Hide() end
        end
    end

    -- Daily Word: how many games took each number of tries, as bars, the
    -- row for today's in green.
    local function PaintTries(c, game)
        local dist, mine = game.Tries()
        local most = 0
        for _, n in ipairs(dist or {}) do most = math.max(most, n) end
        if most == 0 then return end
        c.head:SetText("YOUR TRIES")
        for k, l in ipairs(c.lines) do
            local n = dist[k] or 0
            l.key:SetText(tostring(k))
            l.bar:SetWidth(math.max(2, (inner - 60) * n / most))
            l.bar:SetColorTexture(Style.Color(k == mine and "green" or "lineStrong"))
            l.value:SetText(n > 0 and tostring(n) or "")
            for _, region in ipairs({ l.key, l.bar, l.value }) do region:Show() end
        end
    end

    -- The Guild Word: who has played it, the best first, and in how many tries.
    local function PaintGuildWord(c, game)
        if not game.word then return end
        local list = game.Played()
        c.head:SetText("THE GUILD'S TRIES")
        if #list == 0 then
            c.lines[1].name:SetText("No one yet.")
            c.lines[1].name:SetTextColor(Style.Color("muted"))
            c.lines[1].name:Show()
            return
        end
        for k, l in ipairs(c.lines) do
            local e = list[k]
            if e and k <= 5 then
                l.key:SetText(tostring(k))
                l.name:SetText(e.name)
                l.name:SetTextColor(Style.Color(e.mine and "gold" or "text"))
                l.time:SetText(e.score == "X" and "missed" or ("in " .. e.score))
                for _, region in ipairs({ l.key, l.name, l.time }) do region:Show() end
            end
        end
    end

    -- Pal run: today's times, fastest first, each by its pal's name.
    local function PaintBoard(c, game)
        local board = game.Board()
        c.head:SetText("TODAY'S BOARD")
        if #board == 0 then
            c.lines[1].name:SetText("No times yet today.")
            c.lines[1].name:SetTextColor(Style.Color("muted"))
            c.lines[1].name:Show()
            return
        end
        for k, l in ipairs(c.lines) do
            local e = board[k]
            if e and k <= 5 then
                l.key:SetText(tostring(k))
                l.name:SetText((e.pal and e.pal ~= "" and e.pal) or e.name)
                l.name:SetTextColor(Style.Color(e.mine and "gold" or "text"))
                l.time:SetText(game.Clock(e.steps))
                for _, region in ipairs({ l.key, l.name, l.time }) do region:Show() end
            end
        end
    end

    ---------------------------------------------------------------------
    -- Beside the Guild Word, under the cards: how your guild did today, a
    -- row a guildmate.
    ---------------------------------------------------------------------
    local GUILD_X, ROWS = cardW + GAP, 7
    local guildW = width - GUILD_X
    local COLS = { 0, 190, 320, 450, 560 }
    local guildHead = Style.Section(page, guildW)
    guildHead:SetPoint("TOPLEFT", GUILD_X, -GUILD_Y)
    guildHead.title:SetText("YOUR GUILD TODAY")
    local guildCols = CreateFrame("Frame", nil, page)
    guildCols:SetSize(guildW, 22)
    guildCols:SetPoint("TOPLEFT", GUILD_X, -(GUILD_Y + 26))
    Style.Rule(guildCols, "BOTTOM", "lineStrong")
    for k, label in ipairs({ "GUILDMATE", "DAILY WORD", "ICON GUESS", "PAL RUN", "GUILD WORD" }) do
        local t = Style.Text(guildCols, 10, "muted", nil, true)
        t:SetPoint("LEFT", COLS[k], 0)
        t:SetText(label)
    end
    local guildRows = {}
    for i = 1, ROWS do
        local r = CreateFrame("Frame", nil, page)
        r:SetSize(guildW, 28)
        r:SetPoint("TOPLEFT", GUILD_X, -(GUILD_Y + 48 + (i - 1) * 28))
        Style.Rule(r, "BOTTOM", "line")
        r.dot = Style.Dot(r, 9)
        r.dot:SetPoint("LEFT", 0, 0)
        r.dot:Paint("green")
        -- A guildmate who has gone has the dot's outline instead, a ring, made when first wanted.
        r.Gone = function(self, gone)
            self.dot:SetShown(not gone)
            if gone and not self.gone then
                self.gone = CreateFrame("Frame", nil, self)
                self.gone:SetSize(9, 9)
                self.gone:SetPoint("LEFT", 0, 0)
                Style.Circle(self.gone, "well", "muted")
            end
            if self.gone then self.gone:SetShown(gone) end
        end
        r.cells = {}
        for k = 1, 5 do
            local t = Style.Text(r, 13, "text")
            t:SetPoint("LEFT", COLS[k] + (k == 1 and 14 or 0), 0)
            r.cells[k] = t
        end
        r:EnableMouse(true)
        r:SetScript("OnEnter", function(self) if self.entry then Games.ShowDay(self, self.entry) end end)
        r:SetScript("OnLeave", function() Games.HideDay() end)
        Style.Hover(r)
        guildRows[i] = r
    end
    local guildNote = Style.Text(page, 12, "muted")
    guildNote:SetPoint("TOPLEFT", GUILD_X, -(GUILD_Y + 56))

    local function PaintGuild()
        local list = Games.GuildToday()
        local shown = list ~= nil
        guildHead:SetShown(shown)
        guildCols:SetShown(shown and #list > 0)
        guildNote:SetShown(shown and #list == 0)
        guildNote:SetText("No one yet. Guildmates show up as they log in with jsal.ui.")
        local played = 0
        for i, r in ipairs(guildRows) do
            local e = shown and list[i] or nil
            r:SetShown(e ~= nil)
            r.entry = e
            if e then
                local run = e.run and ns.PalRun and ns.PalRun.Clock and ns.PalRun.Clock(e.run) or nil
                local gw = e.guild and (e.guild == "X" and "missed" or ("in " .. e.guild)) or false
                r.cells[1]:SetText(e.name)
                -- A green dot for one who's on now, its outline in grey for one who has gone.
                r:Gone(not e.on)
                -- Your own row's name in gold, as yours is on a board.
                r.cells[1]:SetTextColor(Style.Color(e.mine and "gold" or "text"))
                for k, value in ipairs({ Tries(e.word) or false, e.icons and (e.icons .. " of 10") or false, run or false, gw }) do
                    -- With no Guild Word set, its column says nothing.
                    r.cells[k + 1]:SetText(value or ((k == 4 and not GuildWord.word) and "" or "Not yet"))
                    r.cells[k + 1]:SetTextColor(Style.Color(value and "text" or "muted"))
                end
            end
        end
        for _, e in ipairs(list or {}) do
            if e.word or e.icons or e.run or e.guild then played = played + 1 end
        end
        guildHead.note:SetText(shown and #list > 0 and ("%d of %d have played%s"):format(played, #list,
            #list > ROWS and (", and %d more"):format(#list - ROWS) or "") or "")
    end

    -- The heading, with the countdown to the next day's games; redrawn each half minute while
    -- the page is on screen, and not at all while it isn't.
    function Heading()
        local left = page.left or 0
        title:SetText((left == 0 and "Today's games are done" or (left == 1 and "1 game left today" or (left .. " games to play today")))
            .. "  |cff9a9688· new in " .. Games.Until() .. "|r")
    end
    local ticking = false
    function Tick()
        if ticking then return end
        ticking = true
        local function Again()
            if not page:IsVisible() then ticking = false return end
            Heading()
            Compat.After(30, Again)
        end
        Compat.After(30, Again)
    end

    page.Refresh = function()
        local left = 0
        for i, entry in ipairs(GAMES) do
            local game, c = entry.game(), cards[i]
            local on = game ~= nil and game.running == true and (not entry.setword or game.word ~= nil)
            local done = on and game.DailyDone() and true or false
            c.state:SetText(game and game.Status() or "Off in Settings")
            c.state:SetTextColor(Style.Color(not on and "muted" or (done and "green" or "gold")))
            -- The record: numbers where the game gives them, else its line.
            local numbers = game and game.Numbers and game.Numbers() or {}
            local each = math.floor(inner / math.max(2, math.min(#numbers, MOST)))
            for k, n in ipairs(c.numbers) do
                local one = k <= MOST and numbers[k] or nil
                n.value:SetShown(one ~= nil)
                n.label:SetShown(one ~= nil)
                if one then
                    n.value:ClearAllPoints()
                    n.value:SetPoint("TOPLEFT", PAD + (k - 1) * each, -84)
                    n.value:SetText(tostring(one[1]))
                    n.label:SetText(one[2])
                end
            end
            c.record:SetText(#numbers == 0 and game and Tidy(game.Record()) or "")
            Clear(c)
            if on and entry.body == "tries" and game.Tries then
                PaintTries(c, game)
            elseif on and entry.body == "board" and game.Board and game.Clock then
                PaintBoard(c, game)
            elseif on and entry.body == "guild" then
                PaintGuildWord(c, game)
            elseif entry.words then
                c.words:SetText(entry.words)
            end
            local again = done and entry.again and game.Left() > 0
            c.play:SetLabel(again and "Play again" or (done and "Result" or "Play"))
            -- Gold marks the first one still to play, and only that one.
            c.play:SetKind((on and not done and left == 0) and "primary" or "plain")
            c.play:SetEnabled(on)
            if c.practice then c.practice:SetEnabled(on) end
            if c.set then
                -- Only the guild master and officers can set the word; with none set yet, it's their one thing to do.
                local master = game.running and Compat.IsGuildOfficer() and true or false
                c.set:SetShown(master)
                c.set:SetKind((master and not game.word) and "primary" or "plain")
                local playing = game.word ~= nil or not master
                c.play:SetShown(playing)
                -- Beside Play when it shows, else in its place at the card's right edge.
                c.set:ClearAllPoints()
                if playing then
                    c.set:SetPoint("RIGHT", c.play, "LEFT", -8, 0)
                else
                    c.set:SetPoint("BOTTOMRIGHT", -PAD, 16)
                end
            end
            if on and not done then left = left + 1 end
        end
        page.left = left
        Heading()
        if ns.Guild and ns.Guild.Hello then ns.Guild.Hello() end
        xpcall(PaintGuild, ns.Report)
        Tick()
    end
end, nil, true)
