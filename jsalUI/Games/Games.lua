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

-- Park and Miller's generator: the same seed gives every player the same
-- numbers. random(n) returns 1 to n.
function Games.Random(seed)
    local state = seed % 2147483646 + 1
    return function(n)
        state = (state * 16807) % 2147483647
        return state % n + 1
    end
end

-- The Games page: a card for each daily game, with how today's stands, your
-- record, and a button to play it or see how it went.
local GAMES = {
    { label = "Daily Word", icon = "word", game = function() return ns.DailyWord end },
    { label = "Icon Guess", icon = "icons", game = function() return ns.IconGuess end, practice = true },
}

-- A game's record without its own name in front ("Daily Word: 1 played"
-- under a card that already says Daily Word).
local function Tidy(text)
    text = (text or ""):gsub("^[^:]+:%s*", "")
    return (text:gsub("^%l", string.upper))
end

Window.Page("games", function(page)
    local width = Window.contentWidth
    local CARD_H, PAD = 104, 14
    local title, sub = Window.Header(page, width)
    sub:SetText("Each day's puzzles are the same for everyone, so you can compare with your guild. They're offered when a flight starts, too.")

    local cards = {}
    for i, entry in ipairs(GAMES) do
        local c = CreateFrame("Frame", nil, page)
        c:SetSize(width, CARD_H)
        c:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -(18 + (i - 1) * (CARD_H + 12)))
        Style.Fill(c, "well")
        Style.Border(c, "cardLine")
        local icon = c:CreateTexture(nil, "ARTWORK")
        icon:SetSize(40, 40)
        icon:SetPoint("TOPLEFT", PAD, -PAD)
        icon:SetTexture("Interface\\AddOns\\jsalUI\\Media\\Icons\\" .. entry.icon)
        local name = Style.Text(c, 15, "text", nil, true)
        name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 14, 0)
        name:SetText(entry.label)
        c.state = Style.Text(c, 13, "text")
        c.state:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -4)
        c.record = Style.Text(c, 12, "muted")
        c.record:SetPoint("BOTTOMLEFT", PAD, PAD)
        c.record:SetWidth(width - PAD * 2)
        c.record:SetJustifyH("LEFT")
        c.record:SetWordWrap(false)
        c.play = Style.Button(c, "Play", "plain", 124)
        c.play:SetHeight(30)
        c.play:SetPoint("TOPRIGHT", -PAD, -PAD)
        c.play:SetScript("OnClick", function() entry.game().Open() end)
        if entry.practice then
            c.practice = Style.Button(c, "Practice", "plain", 100)
            c.practice:SetHeight(30)
            c.practice:SetPoint("RIGHT", c.play, "LEFT", -8, 0)
            c.practice:SetScript("OnClick", function() entry.game().Practice() end)
        end
        cards[i] = c
    end

    page.Refresh = function()
        local left = 0
        for i, entry in ipairs(GAMES) do
            local game, c = entry.game(), cards[i]
            local on = game ~= nil and game.running == true
            local done = on and game.DailyDone() and true or false
            c.state:SetText(game and game.Status() or "Turned off in Settings")
            c.state:SetTextColor(Style.Color(on and "text" or "muted"))
            c.record:SetText(game and Tidy(game.Record()) or "")
            c.play:SetLabel(done and "Result" or "Play")
            -- Gold marks the first one still to play, and only that one.
            c.play:SetKind((on and not done and left == 0) and "primary" or "plain")
            c.play:SetEnabled(on)
            if c.practice then c.practice:SetEnabled(on) end
            if on and not done then left = left + 1 end
        end
        title:SetText((left == 0 and "Today's puzzles are done" or (left == 1 and "1 puzzle left today" or (left .. " puzzles to play today")))
            .. ("   |cff9a9688#%d|r"):format(Games.Today()))
    end
end)
