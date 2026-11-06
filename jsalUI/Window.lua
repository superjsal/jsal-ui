-- The /jsal dashboard: a title bar, the side menu and one page at a time.
-- Each page is built the first time it opens.
local _, ns = ...
local Style, Compat = ns.Style, ns.Compat

local Window = {}
ns.Window = Window

local WIDTH, HEIGHT = 1000, 920
local TITLE_HEIGHT, MENU_WIDTH, ITEM_HEIGHT = 44, 210, 36
local PAD_X, PAD_Y, MENU_PAD = 30, 26, 12
Window.contentWidth = WIDTH - MENU_WIDTH - PAD_X * 2
Window.contentHeight = HEIGHT - TITLE_HEIGHT - PAD_Y * 2

-- The side menu, in order, in its groups; Settings sits at the bottom. Each
-- entry has a game icon. An entry nothing has claimed yet says it's on the way.
local ICONS = "Interface\\Icons\\"
local PAGES = {
    { key = "home", label = "Home", icon = "INV_Misc_Map_01" },
    { key = "install", label = "Install", icon = "Trade_Engineering" },
    { key = "build", label = "Build Planner", icon = "Ability_Marksmanship", group = "PLAN" },
    { key = "training", label = "Training Planner", icon = "INV_Misc_Book_09" },
    { key = "professions", label = "Professions", icon = "Trade_BlackSmithing" },
    { key = "games", label = "Games", icon = "INV_Misc_Dice_02", group = "PLAY" },
    { key = "guild", label = "Guild", icon = "INV_Shirt_GuildTabard_01" },
    { key = "settings", label = "Settings", icon = "INV_Misc_Gear_01", bottom = true },
}
local byKey = {}
for _, page in ipairs(PAGES) do byKey[page.key] = page end

-- A part of jsal.ui claims its menu entry by giving it a builder. The builder
-- runs once, the first time the page opens, and may set page.Refresh to run
-- on every open.
function Window.Page(key, build)
    byKey[key].build = build
end

local frame, content, current, crumb

-- Addons can't reload the game themselves on Forever, but the game's own
-- secure button can run the /reload command when the player clicks it.
-- Because it's secure, the dashboard never opens or closes during combat:
-- it closes as a fight starts and waits until it ends to open.
local function ReloadButton(parent)
    local b = CreateFrame("Button", "jsalUIReloadButton", parent, "SecureActionButtonTemplate")
    b:SetAttribute("type", "macro")
    b:SetAttribute("macrotext", "/reload")
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetSize(72, 26)
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

-- One menu entry: its icon in a thin frame, then its name. The open page's
-- entry is filled, with a gold mark down its left edge.
local function MenuButton(menu, page)
    local b = CreateFrame("Button", nil, menu)
    b:SetHeight(ITEM_HEIGHT)
    b.bg = Style.Fill(b, "well")
    b.mark = b:CreateTexture(nil, "ARTWORK")
    b.mark:SetColorTexture(Style.Color("gold"))
    b.mark:SetPoint("TOPLEFT")
    b.mark:SetPoint("BOTTOMLEFT")
    b.mark:SetWidth(2)
    local frameIcon = CreateFrame("Frame", nil, b)
    frameIcon:SetSize(22, 22)
    frameIcon:SetPoint("LEFT", 10, 0)
    Style.Border(frameIcon, "lineStrong")
    local icon = frameIcon:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", -1, 1)
    icon:SetTexture(ICONS .. page.icon)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.label = Style.Text(b, 13, "muted")
    b.label:SetPoint("LEFT", frameIcon, "RIGHT", 10, 0)
    b.label:SetText(page.label)
    b:SetScript("OnClick", function() Window.Open(page.key) end)
    b:SetScript("OnEnter", function() b.label:SetTextColor(Style.Color("text")) end)
    b:SetScript("OnLeave", PaintMenu)
    page.button = b
end

-- The hub keeps one size, 1000 by 920 at full scale, so its text stays the
-- size it was drawn at. Only when the screen is too small to hold it does it
-- shrink, evenly, to fit with a little room around it.
local function FitScale()
    local w, h = UIParent:GetWidth(), UIParent:GetHeight()
    return math.min(1, (w - 40) / WIDTH, (h - 40) / HEIGHT)
end

local function Build()
    frame = CreateFrame("Frame", "jsalUIWindow", UIParent)
    -- Scaled before anything is drawn on it, so its 1px lines start crisp.
    frame:SetScale(FitScale())
    frame:SetSize(WIDTH, HEIGHT)
    -- A size saved by the old corner handle no longer applies.
    ns.db.window.scale = nil
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

    -- jsal.io's mark, then the wordmark, as in the site's top bar, then the
    -- open page's name after a thin divider.
    local mark = bar:CreateTexture(nil, "ARTWORK")
    mark:SetTexture("Interface\\AddOns\\jsalUI\\Media\\Logo")
    mark:SetSize(24, 24)
    mark:SetPoint("LEFT", 16, 0)
    local name = Style.Wordmark(bar, 20)
    name:SetPoint("LEFT", mark, "RIGHT", 10, 0)
    name:SetJustifyV("MIDDLE")
    local divider = bar:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(Style.Color("lineStrong"))
    divider:SetSize(Compat.OnePixel(bar), 20)
    divider:SetPoint("LEFT", name, "RIGHT", 16, 0)
    Compat.Crisp(divider)
    crumb = Style.Text(bar, 13, "text", nil, true)
    crumb:SetPoint("LEFT", divider, "RIGHT", 16, 0)
    crumb:SetJustifyV("MIDDLE")
    local close = Style.CloseButton(bar, TITLE_HEIGHT, function() frame:Hide() end)
    close:SetPoint("TOPRIGHT")
    ReloadButton(bar):SetPoint("RIGHT", close, "LEFT", -6, 0)

    -- The menu: entries in their groups from the top, Settings and the
    -- version at the bottom.
    local menu = CreateFrame("Frame", nil, frame)
    menu:SetPoint("TOPLEFT", 0, -TITLE_HEIGHT)
    menu:SetPoint("BOTTOMLEFT")
    menu:SetWidth(MENU_WIDTH)
    Style.Fill(menu, "titleBar")
    Style.Rule(menu, "RIGHT", "line")
    local y = 18
    for _, page in ipairs(PAGES) do
        MenuButton(menu, page)
        local b = page.button
        if page.bottom then
            b:SetPoint("BOTTOMLEFT", MENU_PAD, 40)
            b:SetPoint("BOTTOMRIGHT", -MENU_PAD, 40)
        else
            if page.group then
                local group = Style.Text(menu, 10, "muted", nil, true)
                group:SetPoint("TOPLEFT", MENU_PAD + 10, -(y + 18))
                group:SetText(page.group)
                group:SetAlpha(0.8)
                y = y + 18 + 18
            end
            b:SetPoint("TOPLEFT", MENU_PAD, -y)
            b:SetPoint("TOPRIGHT", -MENU_PAD, -y)
            y = y + ITEM_HEIGHT + 2
        end
    end
    local version = Style.Text(menu, 11, "muted")
    version:SetPoint("BOTTOMLEFT", MENU_PAD + 10, 16)
    version:SetText("jsal.ui " .. (ns.version or ""))

    content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", MENU_WIDTH + PAD_X, -(TITLE_HEIGHT + PAD_Y))
    content:SetPoint("BOTTOMRIGHT", -PAD_X, PAD_Y)
end

local function Refresh(page)
    if page.frame and page.frame.Refresh then
        xpcall(function() page.frame.Refresh(page.frame) end, ns.Report)
    end
end

local function BuildPage(page)
    local f = CreateFrame("Frame", nil, content)
    f:SetAllPoints()
    -- The page's name is in the title bar. Pages place their first line
    -- 8px under this anchor, which sits just above the top, so that line
    -- starts at the very top.
    f.heading = CreateFrame("Frame", nil, f)
    f.heading:SetSize(1, 1)
    f.heading:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, 8)
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
        text:SetPoint("TOPLEFT", f.heading, "BOTTOMLEFT", 0, -8)
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
    crumb:SetText(page.label)
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
