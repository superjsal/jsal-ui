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

-- The side menu, in order, in its groups; Report a problem and Settings sit
-- at the bottom. Each
-- entry has one of jsal.ui's own icons (gold on a slate tile, in
-- Media\Icons), or a game icon by name. An entry nothing has claimed yet
-- says it's on the way.
local ICONS = "Interface\\Icons\\"
local OWN = "Interface\\AddOns\\jsalUI\\Media\\Icons\\"
local PAGES = {
    { key = "home", label = "Home", icon = OWN .. "home" },
    { key = "journal", label = "Journal", icon = OWN .. "journal" },
    { key = "build", label = "Build Planner", icon = OWN .. "build", group = "PLAN" },
    { key = "training", label = "Training Planner", icon = OWN .. "training" },
    { key = "gear", label = "Gear plan", icon = OWN .. "gear" },
    { key = "professions", label = "Professions", icon = OWN .. "professions" },
    { key = "dungeons", label = "Dungeons", icon = OWN .. "dungeons" },
    { key = "games", label = "Games", icon = OWN .. "games", group = "PLAY" },
    { key = "chess", label = "Chess", icon = OWN .. "chess" },
    -- Only in the menu once its part is switched on: `when` is asked as the
    -- dashboard is built, and a switch waits for a reload anyway.
    { key = "pet", label = "Companion", icon = "Interface\\AddOns\\jsalUI\\Media\\Pet\\briarboar",
      when = function() return ns.Pet ~= nil and ns.Pet.running == true end },
    { key = "guild", label = "Guild", icon = OWN .. "guild" },
    -- Installing the look is done once, so it sits with the other rare ones.
    { key = "install", label = "Install", icon = OWN .. "install", bottom = true },
    { key = "report", label = "Report a problem", icon = OWN .. "report", bottom = true },
    { key = "settings", label = "Settings", icon = OWN .. "settings", bottom = true },
}
local byKey = {}
for _, page in ipairs(PAGES) do byKey[page.key] = page end

-- A part of jsal.ui claims its menu entry by giving it a builder. The builder
-- runs once, the first time the page opens, and may set page.Refresh to run
-- on every open.
function Window.Page(key, build, own)
    byKey[key].build = build
    -- A page big enough to want room of its own (the gear plan, the dungeon
    -- guide) opens in a window of that size beside the dashboard instead.
    byKey[key].own = own
end

-- A page's top: a title that says where things stand (set as the page
-- paints), and a quieter line under it. Returns both.
function Window.Header(page, width)
    local title = Style.Text(page, 21, "text", nil, true)
    title:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", 0, -8)
    title:SetWidth(width)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    local sub = Style.Text(page, 13, "muted")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    sub:SetWidth(width)
    sub:SetJustifyH("LEFT")
    return title, sub
end

local frame, content, current, crumb

-- Addons can't reload the game themselves on Forever, but the game's own
-- secure button can run the /reload command when the player clicks it.
-- Because it's secure, the dashboard never opens or closes during combat:
-- it closes as a fight starts and waits until it ends to open.
-- Each one needs a name of its own. A gold one is a page's main action
-- (Settings, once a change is waiting for a reload).
function Window.ReloadButton(parent, name, text, width, gold)
    local b = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
    b:SetAttribute("type", "macro")
    b:SetAttribute("macrotext", "/reload")
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetSize(width, 26)
    local rest, lit = gold and "gold" or "well", gold and "goldHover" or "wellHover"
    local fill = Style.Fill(b, rest)
    local edges = Style.Border(b, gold and "gold" or "lineStrong")
    local label = Style.Text(b, gold and 13 or 11, gold and "onGold" or "text", nil, true)
    label:SetPoint("CENTER")
    label:SetText(text)
    b:SetScript("OnEnter", function()
        fill:SetColorTexture(Style.Color(lit))
        Style.SetBorder(edges, gold and "goldHover" or "gold")
    end)
    b:SetScript("OnLeave", function()
        fill:SetColorTexture(Style.Color(rest))
        Style.SetBorder(edges, gold and "gold" or "lineStrong")
    end)
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
        b.label:SetTextColor(Style.Color(selected and "text" or "secondary"))
    end
end

-- The gold number beside an entry: how many things are waiting there now
-- (spells to train, today's games), as Home's Ready now list counts them.
local function PaintBadges()
    for _, page in ipairs(PAGES) do
        local b = page.button
        local ok, n = pcall(function() return ns.Today and ns.Today.Badge(page.key) end)
        n = ok and n or nil
        b.badge:SetShown(n ~= nil)
        if n then
            b.count:SetText(n)
            b.badge:SetWidth(math.max(18, b.count:GetStringWidth() + 10))
        end
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
    local icon = frameIcon:CreateTexture(nil, "ARTWORK")
    -- jsal.ui's own icons bring their tile and edge; a game icon gets a line
    -- around it, with its baked-in border trimmed.
    local own = page.icon:find("\\", 1, true) ~= nil
    if own then
        icon:SetAllPoints()
    else
        Style.Border(frameIcon, "lineStrong")
        icon:SetPoint("TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", -1, 1)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    icon:SetTexture(own and page.icon or (ICONS .. page.icon))
    b.label = Style.Text(b, 13, "secondary")
    b.label:SetPoint("LEFT", frameIcon, "RIGHT", 10, 0)
    b.label:SetText(page.label)
    b.badge = CreateFrame("Frame", nil, b)
    b.badge:SetSize(18, 18)
    b.badge:SetPoint("RIGHT", -4, 0)
    Style.Fill(b.badge, "gold")
    b.count = Style.Text(b.badge, 11, "onGold", nil, true)
    b.count:SetPoint("CENTER")
    b.count:SetJustifyH("CENTER")
    b.badge:Hide()
    -- A page that opens in a window of its own says so with a small arrow
    -- out of a corner, so the dashboard staying put is no surprise.
    if page.own then
        local out = CreateFrame("Frame", nil, b)
        out:SetSize(9, 9)
        out:SetPoint("RIGHT", -10, 0)
        local function Stroke(w, h, angle)
            local t = out:CreateTexture(nil, "ARTWORK")
            t:SetColorTexture(Style.Color("muted"))
            t:SetSize(w, h)
            if angle then t:SetRotation(math.rad(angle)) end
            return t
        end
        Stroke(11, 1.5, 45):SetPoint("CENTER")
        Stroke(6, 1.5):SetPoint("TOPRIGHT")
        Stroke(1.5, 6):SetPoint("TOPRIGHT")
    end
    b:SetScript("OnClick", function() Window.Open(page.key) end)
    b:SetScript("OnEnter", function()
        b.label:SetTextColor(Style.Color("text"))
        b.bg:Show()
    end)
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
    frame.jsalRoomy = true
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
    Style.Shadow(frame)
    Style.Opening(frame, -8)
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
    Window.ReloadButton(bar, "jsalUIReloadButton", "Reload", 72):SetPoint("RIGHT", close, "LEFT", -6, 0)

    -- The menu: entries in their groups from the top; the bottom entries
    -- stack up from the version line, the last one lowest.
    local menu = CreateFrame("Frame", nil, frame)
    menu:SetPoint("TOPLEFT", 0, -TITLE_HEIGHT)
    menu:SetPoint("BOTTOMLEFT")
    menu:SetWidth(MENU_WIDTH)
    Style.Fill(menu, "titleBar")
    Style.Rule(menu, "RIGHT", "line")
    local y, below = 18, 0
    for _, page in ipairs(PAGES) do
        if page.bottom then below = below + 1 end
    end
    for _, page in ipairs(PAGES) do
        MenuButton(menu, page)
        local b = page.button
        if page.when and not page.when() then
            -- A part that's off has no entry, and takes no room.
            b:Hide()
        elseif page.bottom then
            below = below - 1
            local up = 40 + below * (ITEM_HEIGHT + 2)
            b:SetPoint("BOTTOMLEFT", MENU_PAD, up)
            b:SetPoint("BOTTOMRIGHT", -MENU_PAD, up)
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

-- A page's own window: the panel every jsal.ui window shares, with the page
-- built inside it the first time it opens. It holds no secure button, so
-- unlike the dashboard it may stay open in a fight.
local PANEL_PAD, BAR_H = 22, 32
local function OpenOwn(page)
    local own = page.own
    if not own.frame then
        local name = "jsalUI" .. page.key:gsub("^%l", string.upper) .. "Window"
        local f = Style.Panel(name, own.width, own.height, page.label)
        f.jsalRoomy = true
        local inner = CreateFrame("Frame", nil, f)
        inner:SetPoint("TOPLEFT", PANEL_PAD, -(BAR_H + 16))
        inner:SetPoint("BOTTOMRIGHT", -PANEL_PAD, 18)
        inner.heading = CreateFrame("Frame", nil, inner)
        inner.heading:SetSize(1, 1)
        inner.heading:SetPoint("BOTTOMLEFT", inner, "TOPLEFT", 0, 8)
        inner.contentWidth = own.width - PANEL_PAD * 2
        inner.contentHeight = own.height - BAR_H - 16 - 18
        own.frame, page.frame = f, inner
        if not xpcall(function() page.build(inner) end, ns.Report) then
            local text = Style.Text(inner, 13, "muted")
            text:SetPoint("TOPLEFT")
            text:SetText("This window hit an error. BugSack has the details.")
        end
    end
    Refresh(page)
    own.frame:Show()
    own.frame:Raise()
end

function Window.Open(key)
    local page = byKey[key] or byKey.home
    if page.own and page.build then return OpenOwn(page) end
    if Compat.InCombat() then
        return ns.Print("The dashboard opens once combat ends.")
    end
    if not frame then Build() end
    if not page.frame then BuildPage(page) end
    for _, other in ipairs(PAGES) do
        if other.frame and not other.own then other.frame:SetShown(other == page) end
    end
    current = page.key
    crumb:SetText(page.label)
    PaintMenu()
    PaintBadges()
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

-- Whether a page is on screen: the dashboard's current page, or a page's
-- own window.
function Window.IsOpen(key)
    local page = byKey[key]
    if page and page.own then return page.own.frame ~= nil and page.own.frame:IsShown() end
    return frame ~= nil and frame:IsShown() and current == key
end

-- Closes a page: its own window, or the dashboard it's showing in.
function Window.Close(key)
    local page = byKey[key]
    if page and page.own then
        if page.own.frame then page.own.frame:Hide() end
    elseif frame and frame:IsShown() and current == key then
        frame:Hide()
    end
end

-- Repaints the pages on screen after something they show has changed.
function Window.Refresh()
    if frame and frame:IsShown() and current then
        PaintBadges()
        Refresh(byKey[current])
    end
    for _, page in ipairs(PAGES) do
        if page.own and page.own.frame and page.own.frame:IsShown() then Refresh(page) end
    end
end

-- Whether a frame sits in one of the big windows, the dashboard or a page's
-- own window, where Style.Text draws nothing under its smallest size.
function Window.Roomy(region)
    local f = region
    while f do
        if f.jsalRoomy then return true end
        f = f.GetParent and f:GetParent() or nil
    end
    return false
end

-- Whether a frame sits inside the dashboard (its text is drawn a size up).
function Window.Contains(region)
    local f = region
    while f and frame do
        if f == frame then return true end
        f = f.GetParent and f:GetParent() or nil
    end
    return false
end
