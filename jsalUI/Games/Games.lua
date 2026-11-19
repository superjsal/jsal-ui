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
-- never shown (John, 18 Nov 2026: "get rid of the tallying #14s", "a timer instead").
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

-- The Guild Word as one of the games (John, 18 Nov 2026: the Guild page folded into this one,
-- "debating if we even need this page"). It answers what a card asks of a game, from the
-- word the guild master set and what guildmates have told the guild.
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
    for name, m in pairs(ns.Guild.Members() or {}) do
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
    if not (ns.Guild and ns.Guild.running and ns.DailyWord and ns.DailyWord.running) then return "Turned off in Settings" end
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
    for name in pairs(ns.Guild.Members() or {}) do if name ~= me then heard = heard + 1 end end
    return { { ("%d of %d"):format(#GuildWord.Played(), heard), "have played" }, { tostring(#word.answer), "letters" } }
end
function GuildWord.Record()
    if not GuildWord.running then return "" end
    return "When the guild master sets a word, it shows here for everyone."
end
function GuildWord.Open()
    if GuildWord.word then ns.DailyWord.OpenGuild(GuildWord.word) end
end

-- The guild master's Set word: a small window with a box, as Report a problem's Discord
-- link opens one ("A is better", 18 Nov 2026): the card stays the shape of the others.
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

-- The Games page: a card for each daily game, side by side, with how
-- today's stands, your record as numbers, and a button to play it or see how
-- it went; under the cards, how your guild did today. Pal run can be run
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

-- How your guild did today, for the foot of the page: a row for each
-- guildmate heard this session with jsal.ui, the best Daily Word first, each
-- with today's Daily Word, Icon Guess and Pal run where they've played. Nil
-- with Guild games off.
function Games.GuildToday()
    local guild = ns.Guild
    if not (guild and guild.running and guild.Members) then return nil end
    local today, list = Games.Today(), {}
    local gw, me = guild.Word and guild.Word(), Compat.MyName()
    for name, m in pairs(guild.Members()) do
        if name ~= me then
            list[#list + 1] = {
                name = name,
                word = m.wordDay == today and m.wordScore or nil,
                icons = m.iconDay == today and m.iconScore or nil,
                run = m.runDay == today and m.runSteps or nil,
                pal = m.runDay == today and m.runPal or nil,
                guild = gw and m.guildID == gw.id and m.guildScore or nil,
                -- How their games went, from guildmates on 0.3.57 or later.
                wordMarks = m.marksDay == today and m.wordMarks or nil,
                iconMarks = m.marksDay == today and m.iconMarks or nil,
                guildMarks = gw and m.guildMarksID == gw.id and m.guildMarks or nil,
            }
        end
    end
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

-- A guildmate's day, for the tooltip of their row on the Games page: a gold heading a game, its
-- score, and for the Word games the grid as tiles (never the letters), for Icon Guess its ten.
local TILES = { r = { 98, 179, 90 }, n = { 227, 176, 75 }, x = { 61, 66, 78 }, ["1"] = { 98, 179, 90 }, ["0"] = { 61, 66, 78 } }
local function Tiles(row, size)
    local out = {}
    for c in row:gmatch(".") do
        local t = TILES[c]
        if t then
            out[#out + 1] = ("|TInterface\\Buttons\\WHITE8X8:%d:%d:0:0:8:8:0:8:0:8:%d:%d:%d|t"):format(size, size, t[1], t[2], t[3])
        end
    end
    return table.concat(out, " ")
end
function Games.ShowDay(owner, e)
    local tip = GameTooltip
    tip:SetOwner(owner, "ANCHOR_TOP")
    tip:AddLine(e.name .. " today", 1, 1, 1)
    local gold, muted = { Style.Color("gold") }, { Style.Color("muted") }
    local function Game(head, score, rows, size)
        tip:AddLine(" ")
        tip:AddLine(head, gold[1], gold[2], gold[3])
        if score then tip:AddLine(score, 1, 1, 1) else tip:AddLine("Not played yet", muted[1], muted[2], muted[3]) end
        for row in (rows or ""):gmatch("[^.]+") do tip:AddLine(Tiles(row, size)) end
    end
    local function Word(score) return score and (score == "X" and "Missed" or ("Solved in " .. score)) or nil end
    Game("DAILY WORD", Word(e.word), e.word and e.wordMarks, 14)
    Game("ICON GUESS", e.icons and (e.icons .. " of 10") or nil, e.icons and e.iconMarks, 12)
    local run = e.run and ns.PalRun and ns.PalRun.Clock and ns.PalRun.Clock(e.run) or nil
    Game("PAL RUN", run and (run .. ((e.pal and e.pal ~= "") and ("  with " .. e.pal) or "")) or nil)
    if GuildWord.running and GuildWord.word then Game("GUILD WORD", Word(e.guild), e.guild and e.guildMarks, 12) end
    tip:Show()
end

Window.Page("games", function(page)
    local Heading, Tick
    local width = Window.fullWidth
    local GAP, CARD_H, PAD, CARDS_Y = 16, 346, 18, 70
    local cardW = math.floor((width - GAP * (#GAMES - 1)) / #GAMES)
    local inner = cardW - PAD * 2
    local title = Style.Text(page, 23, "text", nil, true)
    title:SetPoint("TOPLEFT")
    local sub = Style.Text(page, 13, "muted")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    sub:SetText("Each day's games are the same for everyone, so you can compare with your guild. They're offered when a flight starts, too.")

    -- A card a game, side by side: its tile, its name and how today's
    -- stands; its record as numbers; something of its own under those; and
    -- its buttons at the foot.
    local cards = {}
    for i, entry in ipairs(GAMES) do
        local c = CreateFrame("Frame", nil, page)
        c:SetSize(cardW, CARD_H)
        c:SetPoint("TOPLEFT", (i - 1) * (cardW + GAP), -CARDS_Y)
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
    -- Four games make narrow cards: a record shows four numbers at most there.
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
    -- Under the cards: how your guild did today, a row a guildmate.
    ---------------------------------------------------------------------
    local GUILD_Y, ROWS = CARDS_Y + CARD_H + 24, 7
    local COLS = { 0, 260, 450, 640, 820 }
    local guildHead = Style.Section(page, width)
    guildHead:SetPoint("TOPLEFT", 0, -GUILD_Y)
    guildHead.title:SetText("YOUR GUILD TODAY")
    local guildCols = CreateFrame("Frame", nil, page)
    guildCols:SetSize(width, 22)
    guildCols:SetPoint("TOPLEFT", 0, -(GUILD_Y + 26))
    Style.Rule(guildCols, "BOTTOM", "lineStrong")
    for k, label in ipairs({ "GUILDMATE", "DAILY WORD", "ICON GUESS", "PAL RUN", "GUILD WORD" }) do
        local t = Style.Text(guildCols, 10, "muted", nil, true)
        t:SetPoint("LEFT", COLS[k], 0)
        t:SetText(label)
    end
    local guildRows = {}
    for i = 1, ROWS do
        local r = CreateFrame("Frame", nil, page)
        r:SetSize(width, 28)
        r:SetPoint("TOPLEFT", 0, -(GUILD_Y + 48 + (i - 1) * 28))
        Style.Rule(r, "BOTTOM", "line")
        r.dot = r:CreateTexture(nil, "ARTWORK")
        r.dot:SetSize(7, 7)
        r.dot:SetPoint("LEFT", 0, 0)
        r.dot:SetColorTexture(Style.Color("green"))
        r.cells = {}
        for k = 1, 5 do
            local t = Style.Text(r, 13, "text")
            t:SetPoint("LEFT", COLS[k] + (k == 1 and 14 or 0), 0)
            r.cells[k] = t
        end
        r:EnableMouse(true)
        r:SetScript("OnEnter", function(self) if self.entry then Games.ShowDay(self, self.entry) end end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        Style.Hover(r)
        guildRows[i] = r
    end
    local guildNote = Style.Text(page, 12, "muted")
    guildNote:SetPoint("TOPLEFT", 0, -(GUILD_Y + 56))

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
            c.state:SetText(game and game.Status() or "Turned off in Settings")
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
                -- Only the guild master can set the word; with none set yet, it's their one thing to do.
                local master = game.running and Compat.IsGuildMaster() and true or false
                c.set:SetShown(master)
                c.set:SetKind((master and not game.word) and "primary" or "plain")
                c.play:SetShown(game.word ~= nil or not master)
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
