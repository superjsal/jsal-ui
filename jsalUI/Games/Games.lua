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

-- The Today card on Home and Games: one row per daily game, with its state
-- and a button to play or see the result.
function Games.TodayCard(parent, width, height)
    local card = Style.Card(parent, "Today")
    card:SetSize(width, height)
    local rows = {}
    local GAMES = {
        { label = "Daily Word", game = function() return ns.DailyWord end },
        { label = "Icon Guess", game = function() return ns.IconGuess end },
    }
    for i, entry in ipairs(GAMES) do
        local top = -34 - (i - 1) * 44
        local name = Style.Text(card, 13, "text")
        name:SetPoint("TOPLEFT", 12, top)
        name:SetText(entry.label)
        local state = Style.Text(card, 11, "muted")
        state:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -4)
        state:SetWidth(width - 140)
        local play = Style.Button(card, "Play", "plain", 96)
        play:SetPoint("TOPRIGHT", -12, top + 4)
        play:SetScript("OnClick", function() entry.game().Open() end)
        rows[i] = { entry = entry, state = state, play = play }
    end
    function card:Refresh()
        self.heading:SetText(("TODAY · #%d"):format(Games.Today()))
        for _, row in ipairs(rows) do
            local game = row.entry.game()
            row.state:SetText(game.Status())
            row.play:SetLabel(game.DailyDone() and "Result" or "Play")
        end
    end
    return card
end

Window.Page("games", function(page)
    local lead = Style.Text(page, 13, "muted")
    lead:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", 0, -8)
    lead:SetWidth(Window.contentWidth)
    lead:SetText("Play any time, or when a flight starts. Each day's puzzles are the same for everyone, so you can compare with your guild.")

    local half = (Window.contentWidth - 12) / 2
    local today = Games.TodayCard(page, half, 128)
    today:SetPoint("TOPLEFT", lead, "BOTTOMLEFT", 0, -16)

    local stats = Style.Card(page, "Your record")
    stats:SetSize(half, 128)
    stats:SetPoint("TOPLEFT", today, "TOPRIGHT", 12, 0)
    local record = Style.Text(stats, 13, "text")
    record:SetPoint("TOPLEFT", stats.heading, "BOTTOMLEFT", 0, -10)
    record:SetWidth(half - 24)
    record:SetSpacing(4)

    local practice = Style.Button(page, "Icon Guess practice", "plain", 180)
    practice:SetPoint("TOPLEFT", today, "BOTTOMLEFT", 0, -16)
    practice:SetScript("OnClick", function() ns.IconGuess.Practice() end)

    page.Refresh = function()
        today:Refresh()
        record:SetText(ns.DailyWord.Record() .. "\n" .. ns.IconGuess.Record())
    end
end)
