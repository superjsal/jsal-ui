-- The dashboard's first page: how the look stands, and today's games.
local _, ns = ...
local Style, Window = ns.Style, ns.Window

Window.Page("home", function(page)
    local lead = Style.Text(page, 13, "muted")
    lead:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", 0, -8)
    lead:SetWidth(Window.contentWidth)
    lead:SetText("Your UI, a few games and your guild, in one place.")

    local half = (Window.contentWidth - 12) / 2

    local yourUI = Style.Card(page, "Your UI")
    yourUI:SetSize(half, 160)
    yourUI:SetPoint("TOPLEFT", lead, "BOTTOMLEFT", 0, -16)
    local status = Style.Text(yourUI, 13, "text")
    status:SetPoint("TOPLEFT", yourUI.heading, "BOTTOMLEFT", 0, -10)
    status:SetWidth(half - 24)
    local open = Style.Button(yourUI, "Open Install", "plain", 120)
    open:SetPoint("BOTTOMLEFT", 12, 12)
    open:SetScript("OnClick", function() Window.Open("install") end)

    local today = ns.Games.TodayCard(page, half, 160)
    today:SetPoint("TOPLEFT", yourUI, "TOPRIGHT", 12, 0)

    page.Refresh = function()
        status:SetText(ns.Installer.Message())
        today:Refresh()
    end
end)
