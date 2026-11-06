-- Daily Word: one five-letter word a day, the same for everyone, six tries.
-- A letter in the right spot turns green; a letter that's in the word but in
-- another spot turns yellow; a letter not in the word turns grey.
local _, ns = ...
local Style, Compat, Games = ns.Style, ns.Compat, ns.Games

local DailyWord = ns.NewModule("dailyword", {
    title = "Daily Word",
    note = "One word a day, the same for everyone. /jsal word",
})
ns.DailyWord = DailyWord

local Data = ns.DailyWordData
local LENGTH, TRIES = 5, 6

-- The answers are stored scrambled: each letter shifted by its place in the
-- list, undone here one word at a time.
local function Answer(day)
    local count = #Data.answers / LENGTH
    local i = (day - 1) % count + 1
    local letters = {}
    for pos = 1, LENGTH do
        local code = Data.answers:byte((i - 1) * LENGTH + pos) - 97
        local shift = (i * 7 + pos * 3) % 26
        letters[pos] = string.char((code - shift) % 26 + 97)
    end
    return table.concat(letters)
end

local words
local function IsWord(word)
    if not words then
        words = {}
        for w in Data.guesses:gmatch("%a%a%a%a%a") do words[w] = true end
        for i = 1, #Data.answers / LENGTH do words[Answer(i)] = true end
    end
    return words[word] == true
end

-- Green first, then yellow, so a doubled letter is only marked as often as
-- the answer has it.
local function Score(guess, answer)
    local result, left = {}, {}
    for i = 1, LENGTH do
        local g, a = guess:sub(i, i), answer:sub(i, i)
        if g == a then
            result[i] = "right"
        else
            left[a] = (left[a] or 0) + 1
        end
    end
    for i = 1, LENGTH do
        if not result[i] then
            local g = guess:sub(i, i)
            if (left[g] or 0) > 0 then
                result[i] = "near"
                left[g] = left[g] - 1
            else
                result[i] = "miss"
            end
        end
    end
    return result
end

-- Today's game and the running record, saved per character.
local function Game()
    local today = Games.Today()
    local game = ns.char.word
    if type(game) ~= "table" or game.day ~= today then
        game = { day = today, guesses = {} }
        ns.char.word = game
    end
    return game
end

local function Stats()
    local stats = ns.char.wordStats
    if type(stats) ~= "table" then
        stats = { played = 0, won = 0, streak = 0, best = 0, dist = { 0, 0, 0, 0, 0, 0 } }
        ns.char.wordStats = stats
    end
    return stats
end

function DailyWord.DailyDone()
    local game = ns.char.word
    return type(game) == "table" and game.day == Games.Today() and game.finished or false
end

-- Today's day and score ("1" to "6", or "X"), once today's game is over.
function DailyWord.Result()
    if not DailyWord.DailyDone() then return nil end
    local game = ns.char.word
    return game.day, game.won and tostring(#game.guesses) or "X"
end

function DailyWord.Status()
    if not DailyWord.running then return "Turned off in Settings" end
    local game = Game()
    if game.finished then
        return game.won and ("Solved in " .. #game.guesses) or "Missed it. New word after the daily reset."
    end
    if #game.guesses > 0 then
        return ("In progress: %d of %d tries used"):format(#game.guesses, TRIES)
    end
    return ("#%d is ready"):format(game.day)
end

function DailyWord.Record()
    local s = Stats()
    if s.played == 0 then return "Daily Word: no games yet." end
    return ("Daily Word: %d played, %d%% won, streak %d, best %d."):format(
        s.played, math.floor(s.won / s.played * 100 + 0.5), s.streak, s.best)
end

local function Finish(game, won)
    game.finished, game.won = true, won
    local s = Stats()
    s.played = s.played + 1
    if won then
        s.won = s.won + 1
        s.dist[#game.guesses] = (s.dist[#game.guesses] or 0) + 1
        s.streak = (s.lastWon == game.day - 1) and s.streak + 1 or 1
        s.lastWon = game.day
        s.best = math.max(s.best, s.streak)
    else
        s.streak = 0
    end
    if ns.Guild then ns.Guild.Announce() end
    if ns.Flight then ns.Flight.Refresh() end
    ns.Window.Refresh()
end

-- The share line uses raid markers in the tiles' colours: the green triangle,
-- the yellow star, and a cross for a miss.
local MARKS = { right = "{rt4}", near = "{rt1}", miss = "{rt7}" }

local function ShareLine(game)
    local answer = Answer(game.day)
    local rows = {}
    for i, guess in ipairs(game.guesses) do
        local scored, row = Score(guess, answer), {}
        for c = 1, LENGTH do row[c] = MARKS[scored[c]] end
        rows[i] = table.concat(row)
    end
    return ("Daily Word #%d %s/6 %s"):format(game.day, game.won and #game.guesses or "X", table.concat(rows, " "))
end

-- The window.
local TILE, GAP, KEY_W, KEY_H, WIDE_KEY = 48, 6, 30, 38, 48
local WIDTH, HEIGHT = 360, 556
local KEY_ROWS = { "qwertyuiop", "asdfghjkl", "zxcvbnm" }
local TONES = {
    right = { "wordGreen", "white", "wordGreen" },
    near = { "wordYellow", "white", "wordYellow" },
    miss = { "wordGrey", "white", "wordGrey" },
}
-- On the keyboard, a letter that's out goes dark, so the letters still in
-- play stand out.
local KEY_TONES = {
    right = TONES.right,
    near = TONES.near,
    miss = { "titleBar", "muted", "line" },
}
local RANK = { miss = 1, near = 2, right = 3 }

local frame, input, message, keyboard, result, recordText, shareButton
local tiles, keys = {}, {}
local current, notice = "", nil

local function PaintCell(cell, letter, tone, typed, tones)
    cell.letter:SetText(letter and letter:upper() or "")
    local colors = tone and (tones or TONES)[tone]
    if colors then
        cell.bg:SetColorTexture(Style.Color(colors[1]))
        cell.letter:SetTextColor(Style.Color(colors[2]))
        Style.SetBorder(cell.edges, colors[3])
    else
        cell.bg:SetColorTexture(Style.Color("well"))
        cell.letter:SetTextColor(Style.Color("text"))
        Style.SetBorder(cell.edges, typed and "muted" or "lineStrong")
    end
end

local function Paint()
    local game = Game()
    frame.title:SetText("Daily Word #" .. game.day)
    local answer = Answer(game.day)
    local keyTone = {}
    for row = 1, TRIES do
        local guess = game.guesses[row]
        local scored = guess and Score(guess, answer)
        local typing = not guess and not game.finished and row == #game.guesses + 1
        for col = 1, LENGTH do
            local letter = guess and guess:sub(col, col) or (typing and current:sub(col, col)) or ""
            if letter == "" then letter = nil end
            local tone = scored and scored[col]
            PaintCell(tiles[row][col], letter, tone, letter ~= nil)
            if tone and (not keyTone[letter] or RANK[tone] > RANK[keyTone[letter]]) then
                keyTone[letter] = tone
            end
        end
    end
    for letter, key in pairs(keys) do
        PaintCell(key, letter, keyTone[letter], false, KEY_TONES)
    end

    keyboard:SetShown(not game.finished)
    result:SetShown(game.finished)
    if game.finished then
        recordText:SetText(DailyWord.Record())
        if game.won then
            message:SetText(("Solved in %d. A new word comes with the daily reset."):format(#game.guesses))
        else
            message:SetText(("The word was %s. A new one comes with the daily reset."):format(answer:upper()))
        end
    else
        message:SetText(notice or "Type a word and press Enter.")
    end
end

local function Say(text)
    notice = text
    Paint()
end

local function Submit()
    local game = Game()
    if game.finished then return end
    if #current < LENGTH then return Say("Five letters, please.") end
    if not IsWord(current) then return Say("That one isn't in the word list.") end
    local guess = current
    game.guesses[#game.guesses + 1] = guess
    current, notice = "", nil
    input:SetText("")
    if guess == Answer(game.day) then
        Finish(game, true)
    elseif #game.guesses >= TRIES then
        Finish(game, false)
    end
    Paint()
end

local function Cell(parent, width, height, size)
    local cell = CreateFrame("Button", nil, parent)
    cell:SetSize(width, height)
    cell.bg = Style.Fill(cell, "well")
    cell.edges = Style.Border(cell, "lineStrong")
    cell.letter = Style.Text(cell, size, "text", nil, true)
    cell.letter:SetPoint("CENTER")
    cell.letter:SetJustifyH("CENTER")
    cell.letter:SetJustifyV("MIDDLE")
    return cell
end

local function TypeKey(letter)
    if Game().finished then return end
    input:SetText(input:GetText() .. letter)
    input:SetFocus()
end

local function Build()
    frame = Style.Panel("jsalUIDailyWord", WIDTH, HEIGHT, "Daily Word")

    local gridWidth = LENGTH * TILE + (LENGTH - 1) * GAP
    local left = (WIDTH - gridWidth) / 2
    for row = 1, TRIES do
        tiles[row] = {}
        for col = 1, LENGTH do
            local tile = Cell(frame, TILE, TILE, 22)
            tile:EnableMouse(false)
            tile:SetPoint("TOPLEFT", left + (col - 1) * (TILE + GAP), -(32 + 16 + (row - 1) * (TILE + GAP)))
            tiles[row][col] = tile
        end
    end

    local gridBottom = 32 + 16 + TRIES * TILE + (TRIES - 1) * GAP
    message = Style.Text(frame, 13, "text")
    message:SetPoint("TOP", 0, -(gridBottom + 12))
    message:SetWidth(WIDTH - 32)
    message:SetJustifyH("CENTER")

    keyboard = CreateFrame("Frame", nil, frame)
    keyboard:SetPoint("TOPLEFT", 0, -(gridBottom + 44))
    keyboard:SetPoint("BOTTOMRIGHT")
    for r, letters in ipairs(KEY_ROWS) do
        local count = #letters
        local rowWidth = count * KEY_W + (count - 1) * 4
        if r == 3 then rowWidth = rowWidth + 2 * (WIDE_KEY + 4) end
        local x = (WIDTH - rowWidth) / 2
        local y = -((r - 1) * (KEY_H + 6))
        if r == 3 then
            local enter = Cell(keyboard, WIDE_KEY, KEY_H, 11)
            enter.letter:SetText("ENTER")
            enter:SetPoint("TOPLEFT", x, y)
            enter:SetScript("OnClick", function() Submit(); input:SetFocus() end)
            x = x + WIDE_KEY + 4
        end
        for i = 1, count do
            local letter = letters:sub(i, i)
            local key = Cell(keyboard, KEY_W, KEY_H, 14)
            key:SetPoint("TOPLEFT", x, y)
            key:SetScript("OnClick", function() TypeKey(letter) end)
            keys[letter] = key
            x = x + KEY_W + 4
        end
        if r == 3 then
            local back = Cell(keyboard, WIDE_KEY, KEY_H, 11)
            back.letter:SetText("BACK")
            back:SetPoint("TOPLEFT", x, y)
            back:SetScript("OnClick", function()
                input:SetText(input:GetText():sub(1, -2))
                input:SetFocus()
            end)
        end
    end

    result = CreateFrame("Frame", nil, frame)
    result:SetPoint("TOPLEFT", 0, -(gridBottom + 44))
    result:SetPoint("BOTTOMRIGHT")
    recordText = Style.Text(result, 13, "muted")
    recordText:SetPoint("TOP")
    recordText:SetWidth(WIDTH - 32)
    recordText:SetJustifyH("CENTER")
    shareButton = Style.Button(result, "Share to guild", "primary", 150)
    shareButton:SetPoint("TOPRIGHT", result, "TOP", -4, -32)
    shareButton:SetScript("OnClick", function()
        if not IsInGuild() then return Say("Join a guild to share.") end
        Compat.SendChat(ShareLine(Game()), "GUILD")
        shareButton:SetEnabled(false)
    end)
    local icons = Style.Button(result, "Play Icon Guess", "plain", 150)
    icons:SetPoint("TOPLEFT", result, "TOP", 4, -32)
    icons:SetScript("OnClick", function()
        frame:Hide()
        ns.IconGuess.Open()
    end)

    -- Typing goes to an invisible edit box, so the game keeps the keyboard
    -- only while this window is open and focused.
    input = CreateFrame("EditBox", nil, frame)
    input:SetFontObject(ChatFontNormal)
    input:SetAutoFocus(false)
    input:SetMaxLetters(LENGTH)
    input:SetSize(1, 1)
    input:SetPoint("TOPLEFT")
    input:SetAlpha(0)
    input:SetScript("OnTextChanged", function(self)
        local text = self:GetText()
        local clean = (text:lower():gsub("[^a-z]", "")):sub(1, LENGTH)
        if clean ~= text then
            self:SetText(clean)
            return
        end
        if Game().finished then return end
        current, notice = clean, nil
        Paint()
    end)
    input:SetScript("OnEnterPressed", Submit)
    input:SetScript("OnEscapePressed", function() frame:Hide() end)

    frame:SetScript("OnShow", function() input:SetFocus() end)
    frame:SetScript("OnHide", function() input:ClearFocus() end)
    frame:SetScript("OnMouseDown", function() input:SetFocus() end)
end

function DailyWord.Open()
    if not DailyWord.running then
        return ns.Print("Daily Word is turned off. /jsal settings turns it on.")
    end
    if Compat.InCombat() then
        return ns.Print("Daily Word opens once combat ends.")
    end
    if not frame then Build() end
    current, notice = "", nil
    input:SetText("")
    shareButton:SetEnabled(true)
    Paint()
    frame:Show()
end

function DailyWord:OnEnable()
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:SetScript("OnEvent", ns.Safe(self, function()
        if frame then frame:Hide() end
    end))
end

ns.Command("word", function() DailyWord.Open() end)
