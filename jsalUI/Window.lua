-- The /jsal dashboard: a title bar, the side menu and one page at a time.
-- Each page is built the first time it opens.
local _, ns = ...
local Style, Compat = ns.Style, ns.Compat

local Window = {}
ns.Window = Window

local WIDTH, HEIGHT = 960, 680
local TITLE_HEIGHT, MENU_WIDTH, PAD, ITEM_HEIGHT = 32, 172, 20, 32
Window.contentWidth = WIDTH - MENU_WIDTH - PAD * 2
Window.contentHeight = HEIGHT - TITLE_HEIGHT - PAD * 2

-- The side menu, in order. An entry nothing has claimed yet says it's on
-- the way.
local PAGES = {
    { key = "home", label = "Home" },
    { key = "install", label = "Install" },
    { key = "build", label = "Build Planner" },
    { key = "training", label = "Training Planner" },
    { key = "games", label = "Games" },
    { key = "guild", label = "Guild" },
    { key = "settings", label = "Settings" },
}
local byKey = {}
for _, page in ipairs(PAGES) do byKey[page.key] = page end

-- A part of jsal.ui claims its menu entry by giving it a builder. The builder
-- runs once, the first time the page opens, and may set page.Refresh to run
-- on every open.
function Window.Page(key, build)
    byKey[key].build = build
end

local frame, content, current

-- Addons can't reload the game themselves on Forever, but the game's own
-- secure button can run the /reload command when the player clicks it.
-- Because it's secure, the dashboard never opens or closes during combat:
-- it closes as a fight starts and waits until it ends to open.
local function ReloadButton(parent)
    local b = CreateFrame("Button", "jsalUIReloadButton", parent, "SecureActionButtonTemplate")
    b:SetAttribute("type", "macro")
    b:SetAttribute("macrotext", "/reload")
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetSize(64, 22)
    Style.Fill(b, "well")
    local edges = Style.Border(b, "lineStrong")
    local label = Style.Text(b, 11, "text", nil, true)
    label:SetPoint("CENTER")
    label:SetText("Reload")
    b:SetScript("OnEnter", function() Style.SetBorder(edges, "gold") end)
    b:SetScript("OnLeave", function() Style.SetBorder(edges, "lineStrong") end)
    return b
end

local function SavePosition()
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    ns.db.window.point = { point, relativePoint, x, y }
end

local function PaintMenu()
    for _, page in ipairs(PAGES) do
        local b = page.button
        local selected = page.key == current
        b.bg:SetShown(selected)
        b.mark:SetShown(selected)
        b.label:SetTextColor(Style.Color(selected and "text" or "muted"))
    end
end

local function MenuButton(menu, page, index)
    local b = CreateFrame("Button", nil, menu)
    local top = -(8 + (index - 1) * ITEM_HEIGHT)
    b:SetHeight(ITEM_HEIGHT)
    b:SetPoint("TOPLEFT", 0, top)
    b:SetPoint("TOPRIGHT", 0, top)
    b.bg = Style.Fill(b, "well")
    b.mark = b:CreateTexture(nil, "ARTWORK")
    b.mark:SetColorTexture(Style.Color("gold"))
    b.mark:SetPoint("TOPLEFT")
    b.mark:SetPoint("BOTTOMLEFT")
    b.mark:SetWidth(2)
    b.label = Style.Text(b, 13, "muted")
    b.label:SetPoint("LEFT", 16, 0)
    b.label:SetText(page.label)
    b:SetScript("OnClick", function() Window.Open(page.key) end)
    b:SetScript("OnEnter", function() b.label:SetTextColor(Style.Color("text")) end)
    b:SetScript("OnLeave", PaintMenu)
    page.button = b
end

local function Build()
    frame = CreateFrame("Frame", "jsalUIWindow", UIParent)
    frame:SetSize(WIDTH, HEIGHT)
    local saved = ns.db.window.point
    if saved then
        frame:SetPoint(saved[1], UIParent, saved[2], saved[3], saved[4])
    else
        frame:SetPoint("CENTER")
    end
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:Hide()
    Style.Fill(frame, "window")
    Style.Border(frame, "lineStrong")
    -- Escape closes it, like the game's own windows.
    tinsert(UISpecialFrames, "jsalUIWindow")

    local bar = CreateFrame("Frame", nil, frame)
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("TOPRIGHT")
    bar:SetHeight(TITLE_HEIGHT)
    Style.Fill(bar, "titleBar")
    Style.Rule(bar, "BOTTOM", "line")
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() frame:StartMoving() end)
    bar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        SavePosition()
    end)

    -- jsal.io's mark, then the wordmark, as in the site's top bar.
    local mark = bar:CreateTexture(nil, "ARTWORK")
    mark:SetTexture("Interface\\AddOns\\jsalUI\\Media\\Logo")
    mark:SetSize(20, 20)
    mark:SetPoint("LEFT", 12, 0)
    local name = Style.Wordmark(bar, 18)
    name:SetPoint("LEFT", mark, "RIGHT", 8, 0)
    name:SetJustifyV("MIDDLE")
    local version = Style.Text(bar, 11, "muted")
    version:SetPoint("LEFT", name, "RIGHT", 8, -1)
    version:SetText(ns.version)
    local close = Style.CloseButton(bar, TITLE_HEIGHT, function() frame:Hide() end)
    close:SetPoint("TOPRIGHT")
    ReloadButton(bar):SetPoint("RIGHT", close, "LEFT", -4, 0)

    local menu = CreateFrame("Frame", nil, frame)
    menu:SetPoint("TOPLEFT", 0, -TITLE_HEIGHT)
    menu:SetPoint("BOTTOMLEFT")
    menu:SetWidth(MENU_WIDTH)
    Style.Fill(menu, "titleBar")
    Style.Rule(menu, "RIGHT", "line")
    for index, page in ipairs(PAGES) do
        MenuButton(menu, page, index)
    end

    content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", MENU_WIDTH + PAD, -(TITLE_HEIGHT + PAD))
    content:SetPoint("BOTTOMRIGHT", -PAD, PAD)
end

local function Refresh(page)
    if page.frame and page.frame.Refresh then
        xpcall(function() page.frame.Refresh(page.frame) end, ns.Report)
    end
end

local function BuildPage(page)
    local f = CreateFrame("Frame", nil, content)
    f:SetAllPoints()
    f.heading = Style.Text(f, 18, "text", nil, true)
    f.heading:SetPoint("TOPLEFT")
    f.heading:SetText(page.label)
    page.frame = f
    local note
    if page.build then
        local ok = xpcall(function() page.build(f) end, ns.Report)
        if not ok then note = "This page hit an error. BugSack has the details." end
    else
        note = page.label .. " arrives in a later version of jsal.ui."
    end
    if note then
        local text = Style.Text(f, 13, "muted")
        text:SetPoint("TOPLEFT", f.heading, "BOTTOMLEFT", 0, -10)
        text:SetWidth(Window.contentWidth)
        text:SetText(note)
    end
end

function Window.Open(key)
    if Compat.InCombat() then
        return ns.Print("The dashboard opens once combat ends.")
    end
    if not frame then Build() end
    local page = byKey[key] or byKey.home
    if not page.frame then BuildPage(page) end
    for _, other in ipairs(PAGES) do
        if other.frame then other.frame:SetShown(other == page) end
    end
    current = page.key
    PaintMenu()
    Refresh(page)
    frame:Show()
end

function Window.Toggle()
    if frame and frame:IsShown() then
        frame:Hide()
    else
        Window.Open(current or "home")
    end
end

-- The fight's first moment is the last chance to close a window holding a
-- secure button, so the dashboard closes here.
local combat = CreateFrame("Frame")
combat:RegisterEvent("PLAYER_REGEN_DISABLED")
combat:SetScript("OnEvent", function()
    if frame and frame:IsShown() then frame:Hide() end
end)

-- Repaints the page on screen after something it shows has changed.
function Window.Refresh()
    if frame and frame:IsShown() and current then
        Refresh(byKey[current])
    end
end
