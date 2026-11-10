-- The dashboard's first page: what's new in this version, how the look
-- stands, and today's games.
local _, ns = ...
local Style, Window = ns.Style, ns.Window

-- What's new in this version, in two or three short lines, written with
-- each release. The card shows once per version, until it's put away.
local NEWS = {
    "Fixed: the Journal stopping for the session after an error in a dungeon",
    "A quick button that goes missing comes back within a second",
    "Flight bar: a button to land at the next flight point (0.3.24)",
}

local function NewsWanted()
    return #NEWS > 0 and ns.db.newsSeen ~= ns.version
end

Window.Page("home", function(page)
    local lead = Style.Text(page, 13, "muted")
    lead:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", 0, -8)
    lead:SetWidth(Window.contentWidth)
    lead:SetText("Your UI, a few games and your guild, in one place.")

    local half = (Window.contentWidth - 12) / 2

    local news = Style.Card(page, "New in " .. ns.version)
    news.heading:SetTextColor(Style.Color("gold"))
    local y = -32
    for _, text in ipairs(NEWS) do
        local line = Style.Text(news, 13, "text")
        line:SetPoint("TOPLEFT", 12, y)
        line:SetWidth(Window.contentWidth - 60)
        line:SetText("|cffe3b04b·|r  " .. text)
        y = y - 20
    end
    news:SetSize(Window.contentWidth, -y + 8)
    news:SetPoint("TOPLEFT", lead, "BOTTOMLEFT", 0, -16)

    local yourUI = Style.Card(page, "Your UI")
    yourUI:SetSize(half, 160)

    -- The cards below sit under the news while it shows, under the lead
    -- line once it's put away.
    local function Place()
        local shown = NewsWanted()
        news:SetShown(shown)
        yourUI:ClearAllPoints()
        if shown then
            yourUI:SetPoint("TOPLEFT", news, "BOTTOMLEFT", 0, -12)
        else
            yourUI:SetPoint("TOPLEFT", lead, "BOTTOMLEFT", 0, -16)
        end
    end
    Style.CloseButton(news, 28, function()
        ns.db.newsSeen = ns.version
        Place()
    end):SetPoint("TOPRIGHT", -2, -2)
    local status = Style.Text(yourUI, 13, "text")
    status:SetPoint("TOPLEFT", yourUI.heading, "BOTTOMLEFT", 0, -10)
    status:SetWidth(half - 24)
    local open = Style.Button(yourUI, "Open Install", "plain", 120)
    open:SetPoint("BOTTOMLEFT", 12, 12)
    open:SetScript("OnClick", function() Window.Open("install") end)

    local today = ns.Games.TodayCard(page, half, 160)
    today:SetPoint("TOPLEFT", yourUI, "TOPRIGHT", 12, 0)

    page.Refresh = function()
        Place()
        status:SetText(ns.Installer.Message())
        today:Refresh()
    end
end)
