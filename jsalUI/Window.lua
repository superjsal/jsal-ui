-- The /jsal dashboard: a title bar, the side menu and one page at a time.
-- Each page is built the first time it opens.
local _, ns = ...
local Style, Compat = ns.Style, ns.Compat

local Window = {}
ns.Window = Window

local WIDTH, HEIGHT = 1320, 880
local TITLE_HEIGHT, MENU_WIDTH, ITEM_HEIGHT = 48, 232, 38
local PAD_X, PAD_Y, MENU_PAD = 36, 28, 12
local TILE = 26
-- The room a page has. A page made for all of it (`wide`) is as wide as fullWidth; any
-- other keeps to a column of contentWidth in the middle, the width a page is laid out
-- in unless it says otherwise.
Window.fullWidth = WIDTH - MENU_WIDTH - PAD_X * 2
Window.contentWidth = 730
Window.contentHeight = HEIGHT - TITLE_HEIGHT - PAD_Y * 2

-- The side menu, in order, in its groups: what you plan (your build, training, gear and
-- dungeons), what you craft, and what you play; Report a problem and Settings sit at the
-- bottom. A group's heading is on its first entry. Each entry has one of jsal.ui's own icons
-- (gold on a slate tile, in Media\Icons), or a game icon by name. `short` is an entry's name
-- in the menu where the page's own would crowd it: the title bar and a page's own window
-- still say the whole name. An entry nothing has claimed yet says it's on the way.
local ICONS = "Interface\\Icons\\"
local OWN = "Interface\\AddOns\\jsalUI\\Media\\Icons\\"
local PAGES = {
    { key = "home", label = "Home", icon = OWN .. "home" },
    { key = "journal", label = "Journal", icon = OWN .. "journal" },
    { key = "build", label = "Build Planner", short = "Build", icon = OWN .. "build", group = "PLAN" },
    { key = "training", label = "Training Planner", short = "Training", icon = OWN .. "training" },
    { key = "gear", label = "Gear plan", short = "Gear", icon = OWN .. "gear" },
    { key = "dungeons", label = "Dungeons", icon = OWN .. "dungeons" },
    -- Level 60: your set, raid night, and every character's raids and cooldowns.
    { key = "endgame", label = "Endgame", icon = OWN .. "endgame" },
    { key = "professions", label = "Professions", icon = OWN .. "professions", group = "CRAFT" },
    { key = "craftprofit", label = "Crafting profit", icon = OWN .. "profit",
      when = function() return ns.CraftProfit ~= nil and ns.CraftProfit.running == true end },
    -- Who in the guild makes what, and the orders guildmates ask each other for: in the
    -- menu while either part is on.
    { key = "guildcrafts", label = "Guild Crafts", icon = OWN .. "crafts",
      when = function()
          return (ns.Crafters ~= nil and ns.Crafters.running == true) or (ns.Orders ~= nil and ns.Orders.running == true)
      end,
      -- In the size it was last left in: the full window, or the small one.
      -- Pressed in the menu while either is open, it closes.
      open = function() ns.GuildCrafts.Show() end,
      press = function() ns.GuildCrafts.Toggle() end,
      raise = function()
          local small = ns.GuildCrafts.small
          if small and small:IsShown() then small:Raise() end
      end },
    { key = "games", label = "Games", icon = OWN .. "games", group = "PLAY" },
    { key = "chess", label = "Chess", icon = OWN .. "chess", when = function() return ns.Chess ~= nil end },
    -- Only in the menu once its part is switched on: `when` is asked as the
    -- dashboard is built, and a switch waits for a reload anyway. It has a
    -- small window of its own rather than a page here: `open` shows that.
    { key = "pet", label = "Jsal's Pals", icon = OWN .. "pals",
      when = function() return ns.Pet ~= nil and ns.Pet.running == true end,
      open = function() ns.Pet.Open() end },
    -- Installing the look is done once, so it sits with the other rare ones;
    -- and only in a version that has a look to install.
    { key = "install", label = "Install", icon = OWN .. "install", bottom = true,
      when = function() return ns.Installer ~= nil and ns.Installer.HasProfile ~= nil and ns.Installer.HasProfile() end },
    { key = "report", label = "Report a problem", icon = OWN .. "report", bottom = true },
    { key = "settings", label = "Settings", icon = OWN .. "settings", bottom = true },
}
local byKey = {}
for _, page in ipairs(PAGES) do byKey[page.key] = page end

-- A part of jsal.ui claims its menu entry by giving it a builder. The builder
-- runs once, the first time the page opens, and may set page.Refresh to run
-- on every open.
function Window.Page(key, build, own, wide)
    byKey[key].build = build
    -- A page big enough to want room of its own (the gear plan, the dungeon
    -- guide) opens in a window of that size beside the dashboard instead.
    byKey[key].own = own
    -- A page laid out for the whole width of the dashboard.
    byKey[key].wide = wide and true or false
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

local frame, content, current, crumb, pretendMark

-- A title bar's button: a small well with its word, lit under the pointer.
-- A gold one is a page's main action.
local function Dress(b, text, width, gold)
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
    return Dress(b, text, width, gold)
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
    frameIcon:SetSize(TILE, TILE)
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
    b.label:SetText(page.short or page.label)
    b.badge = CreateFrame("Frame", nil, b)
    b.badge:SetSize(18, 18)
    -- A count sits at the entry's right edge; on an entry with the arrow of a window of its
    -- own, just left of the arrow, so the two never share a spot.
    b.badge:SetPoint("RIGHT", page.own and -26 or -4, 0)
    Style.Pill(b.badge, nil, "gold")
    b.count = Style.Text(b.badge, 11, "onGold", nil, true)
    b.count:SetPoint("CENTER")
    b.count:SetJustifyH("CENTER")
    b.badge:Hide()
    -- A page that opens in a window of its own says so with a small, quiet arrow
    -- out of a corner, so the dashboard staying put is no surprise.
    if page.own then
        local out = CreateFrame("Frame", nil, b)
        out:SetSize(9, 9)
        out:SetPoint("RIGHT", -10, 0)
        local function Stroke(w, h, angle)
            local t = out:CreateTexture(nil, "ARTWORK")
            t:SetColorTexture(Style.Color("lineStrong"))
            t:SetSize(w, h)
            if angle then t:SetRotation(math.rad(angle)) end
            return t
        end
        Stroke(11, 1.5, 45):SetPoint("CENTER")
        Stroke(6, 1.5):SetPoint("TOPRIGHT")
        Stroke(1.5, 6):SetPoint("TOPRIGHT")
    end
    b:SetScript("OnClick", function() Window.Press(page.key) end)
    b:SetScript("OnMouseDown", function() Window.Hold(page.key) end)
    b:SetScript("OnEnter", function()
        b.label:SetTextColor(Style.Color("text"))
        b.bg:Show()
    end)
    b:SetScript("OnLeave", PaintMenu)
    page.button = b
end

-- The hub keeps one size, 1320 by 880 at full scale, so its text stays the
-- size it was drawn at. Only when the screen is too small to hold it does it
-- shrink, evenly, to fit with a little room around it. It's wider than it is
-- tall because a screen is: a short screen shrinks it less.
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
    Style.Box(frame, 6, "window", "lineStrong")
    Style.Shadow(frame)
    Style.Opening(frame, -8)
    -- Escape closes it, like the game's own windows.
    tinsert(UISpecialFrames, "jsalUIWindow")

    local bar = CreateFrame("Frame", nil, frame)
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("TOPRIGHT")
    bar:SetHeight(TITLE_HEIGHT)
    Style.Cap(bar, 6, "titleBar")
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
    mark:SetSize(TILE, TILE)
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
    -- While a beta pretends to be level 60 (/jsal pretend 60), a muted word after the name says so.
    pretendMark = Style.Text(bar, 12, "muted")
    pretendMark:SetPoint("LEFT", crumb, "RIGHT", 12, 0)
    local close = Style.CloseButton(bar, TITLE_HEIGHT, function() frame:Hide() end)
    close:SetPoint("TOPRIGHT")
    local reload = Window.ReloadButton(bar, "jsalUIReloadButton", "Reload", 72)
    reload:SetPoint("RIGHT", close, "LEFT", -6, 0)
    -- Unlock, left of it: the dashboard steps aside and Unlock Mode opens, to move jsal.ui's
    -- pieces about the screen (/jsal unlock).
    if ns.Unlock and ns.Unlock.Open then
        local unlock = Dress(CreateFrame("Button", nil, bar), "Unlock", 72)
        unlock:SetPoint("RIGHT", reload, "LEFT", -6, 0)
        unlock:SetScript("OnClick", function()
            frame:Hide()
            ns.Unlock.Open()
        end)
    end

    -- The menu: entries in their groups from the top; the bottom entries
    -- stack up from the version line, the last one lowest.
    local menu = CreateFrame("Frame", nil, frame)
    menu:SetPoint("TOPLEFT", 0, -TITLE_HEIGHT)
    menu:SetPoint("BOTTOMLEFT")
    menu:SetWidth(MENU_WIDTH)
    Style.Cap(menu, 6, "titleBar", "BOTTOMLEFT")
    Style.Rule(menu, "RIGHT", "line")
    local y, below = 18, 0
    -- The entries at the menu's foot that show, so the last sits at the foot
    -- with no room left for one that doesn't.
    for _, page in ipairs(PAGES) do
        if page.bottom and not (page.when and not page.when()) then below = below + 1 end
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
        local started = debugprofilestop()
        xpcall(function() page.frame.Refresh(page.frame) end, ns.Report)
        ns.Timed("Page: " .. page.label .. ", redraw", started)
    end
end

local function BuildPage(page)
    local f = CreateFrame("Frame", nil, content)
    if page.wide then
        f:SetAllPoints()
    else
        f:SetPoint("TOP")
        f:SetPoint("BOTTOM")
        f:SetWidth(Window.contentWidth)
    end
    -- The page's name is in the title bar. Pages place their first line
    -- 8px under this anchor, which sits just above the top, so that line
    -- starts at the very top.
    f.heading = CreateFrame("Frame", nil, f)
    f.heading:SetSize(1, 1)
    f.heading:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, 8)
    page.frame = f
    local note
    if page.build then
        local started = debugprofilestop()
        local ok = xpcall(function() page.build(f) end, ns.Report)
        ns.Timed("Page: " .. page.label .. ", first open", started)
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
local function OpenOwn(page, spent)
    local own = page.own
    if not own.frame then
        local name = "jsalUI" .. page.key:gsub("^%l", string.upper) .. "Window"
        local f = Style.Panel(name, own.width, own.height, page.label)
        f.jsalRoomy = true
        -- As the hub does: its own size, shrunk evenly only on a screen too small to hold it.
        -- Scaled before anything is drawn on it, so its 1px lines start crisp.
        local scale = math.min(1, (UIParent:GetWidth() - 40) / own.width, (UIParent:GetHeight() - 40) / own.height)
        f:SetScale(scale)
        -- A window shrunk to fit has only a little room round it, so it opens in the middle, the
        -- same room above as below: a little above the middle would press its title bar against
        -- the top. One at its own size keeps the panel's place. A place the player
        -- dragged it to is theirs.
        if scale < 1 and not (f.IsUserPlaced and f:IsUserPlaced()) then
            f:ClearAllPoints()
            f:SetPoint("CENTER")
        end
        local inner = CreateFrame("Frame", nil, f)
        inner:SetPoint("TOPLEFT", PANEL_PAD, -(BAR_H + 16))
        inner:SetPoint("BOTTOMRIGHT", -PANEL_PAD, 18)
        inner.heading = CreateFrame("Frame", nil, inner)
        inner.heading:SetSize(1, 1)
        inner.heading:SetPoint("BOTTOMLEFT", inner, "TOPLEFT", 0, 8)
        inner.contentWidth = own.width - PANEL_PAD * 2
        inner.contentHeight = own.height - BAR_H - 16 - 18
        own.frame, page.frame = f, inner
        local started = debugprofilestop()
        local built = xpcall(function() page.build(inner) end, ns.Report)
        ns.Timed("Page: " .. page.label .. ", first open", started)
        if not built then
            local text = Style.Text(inner, 13, "muted")
            text:SetPoint("TOPLEFT")
            text:SetText("This window hit an error. BugSack has the details.")
        end
    end
    Refresh(page)
    local t = debugprofilestop()
    own.frame:Show()
    own.frame:Raise()
    spent.show = debugprofilestop() - t
end

-- The second after a page opens, watched: its longest frame, against the game's usual frame
-- at the time. /jsal perf's own timers see only jsal.ui's code, and a page can hitch on opening
-- with every part of its code under 10 ms. This sees the whole
-- frame: the game drawing the page, and anything that comes in just after (the guild's
-- answers to a hello). Noted when the longest is 10 ms or more over the usual, with what of it
-- was jsal.ui's own code in opening it (`spent`, filled by the opening: `code`, and of that
-- `counts`, the menu's numbers, and `show`), so the rest is the game laying out and drawing.
local WATCH_FOR = 1
local watcher = CreateFrame("Frame")
local PARTS = { { "code", "of which jsal.ui's code" }, { "counts", "of which the menu's counts" },
    { "show", "of which showing it" } }
function Window.Watch(label)
    local fps = GetFramerate and GetFramerate() or 0
    if not (fps > 0) then return nil end
    local usual, longest, gone, spent = 1000 / fps, 0, 0, {}
    watcher:SetScript("OnUpdate", function(self, elapsed)
        elapsed = elapsed or 0
        longest, gone = math.max(longest, elapsed * 1000), gone + elapsed
        if gone < WATCH_FOR then return end
        self:SetScript("OnUpdate", nil)
        if longest - usual >= 10 then
            ns.NoteTime("Opening " .. label .. ": its longest frame, over the usual", longest - usual)
            for _, part in ipairs(PARTS) do
                if spent[part[1]] then ns.NoteTime("Opening " .. label .. ": " .. part[2], spent[part[1]]) end
            end
        end
    end)
    return spent
end

-- `direct` opens a page's own window even when the entry has an `open` of its own (Guild
-- Crafts' picks between its two sizes, and comes back here for the full one).
function Window.Open(key, direct)
    local page = byKey[key] or byKey.home
    if page.open and not direct then return page.open() end
    -- A page that isn't in the menu just now (/jsal install with no look to
    -- install) opens the dashboard's home instead.
    if page.when and not page.when() then page = byKey.home end
    local spent = Window.Watch(page.label) or {}
    local started = debugprofilestop()
    if page.own and page.build then
        OpenOwn(page, spent)
        spent.code = debugprofilestop() - started
        return
    end
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
    pretendMark:SetText(ns.Pretend and ns.Pretend.Words() or "")
    PaintMenu()
    local t = debugprofilestop()
    PaintBadges()
    spent.counts = debugprofilestop() - t
    Refresh(page)
    t = debugprofilestop()
    frame:Show()
    spent.show = debugprofilestop() - t
    spent.code = debugprofilestop() - started
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
    -- At once, not faded: once the fight has begun it can't be hidden.
    if frame and frame:IsShown() then (frame.HideNow or frame.Hide)(frame) end
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

-- The mouse going down on a menu entry. A click on the dashboard brings it
-- to the front, over the window the entry is about to close, which was
-- seen to drop behind the dashboard before it went. That window is put
-- back on top, so it closes from where it stood.
function Window.Hold(key)
    local page = byKey[key]
    if page.own and page.own.frame and page.own.frame:IsShown() then page.own.frame:Raise() end
    if page.raise then page.raise() end
end

-- A press on a menu entry. A page in a window of its own closes when its
-- entry is pressed while that window is open, so the entry opens and shuts
-- it; any other entry opens its page.
function Window.Press(key)
    local page = byKey[key]
    if page.press then return page.press() end
    if page.own and Window.IsOpen(key) then return Window.Close(key) end
    Window.Open(key)
end

-- Repaints the pages on screen after something they show has changed.
function Window.Refresh()
    if frame and frame:IsShown() and current then
        PaintBadges()
        pretendMark:SetText(ns.Pretend and ns.Pretend.Words() or "")
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

-- /jsal pieces: how many pieces each page puts on screen, for working out which is heaviest.
-- Opening the dashboard costs a frame of 11 to 26 ms past jsal.ui's own code, the game laying
-- out the window; that grows with its pieces. Counted when asked, not as you play: each page
-- built since the last reload, as it was last drawn, and the dashboard's own frame (the title
-- bar and menu). A piece counts when it's shown in its page: frames, pictures and lines of text.
local function Count(f, into, skip)
    into.frames = into.frames + 1
    for _, r in ipairs({ f:GetRegions() }) do
        if r:IsShown() then
            if r:GetObjectType() == "FontString" then into.texts = into.texts + 1 else into.pictures = into.pictures + 1 end
        end
    end
    for _, child in ipairs({ f:GetChildren() }) do
        if child ~= skip and child:IsShown() then Count(child, into) end
    end
    return into
end

local function Counted(label, f, skip)
    local c = Count(f, { label = label, frames = 0, pictures = 0, texts = 0 }, skip)
    c.all = c.frames + c.pictures + c.texts
    return c
end

if ns.Command then ns.Command("pieces", function()
    local rows = {}
    if frame then rows[#rows + 1] = Counted("The dashboard's title bar and menu", frame, content) end
    for _, page in ipairs(PAGES) do
        local f = page.own and page.own.frame or page.frame
        if f then rows[#rows + 1] = Counted(page.label, f) end
    end
    if #rows == 0 then return ns.Print("Open the dashboard and its pages first, then /jsal pieces again.") end
    table.sort(rows, function(a, b) return a.all > b.all end)
    ns.Print("Pieces each page shows, as last drawn, the most first (frames, pictures, texts):")
    for _, c in ipairs(rows) do
        print(("  %s: %d   (%d, %d, %d)"):format(c.label, c.all, c.frames, c.pictures, c.texts))
    end
end) end

-- /jsal snap [a few words]: a snapshot of what jsal.ui shows, kept in the saved file, for checking
-- what's on screen without a picture. It holds each of jsal.ui's windows and pieces that is shown
-- (where, how big, its scale and fade), and every line of text shown on the dashboard's open page and
-- in any page's own window: what it says, where it sits in its page, and whether the game cut it
-- short. Taken only when typed, nothing watches for it; the newest few are kept for the account.
-- /jsal snap clear empties them. jsal.ui's own errors are kept beside them already (Errors.lua).
local SNAPS_KEPT, SNAP_LINES, SNAP_TEXT = 10, 400, 120

local function Tenth(n) return type(n) == "number" and math.floor(n * 10 + 0.5) / 10 or nil end

-- Left, bottom, width and height, from `from`'s bottom left corner when given; nil where the game
-- hasn't placed it.
local function Rect(r, from)
    local left, bottom = r:GetLeft(), r:GetBottom()
    if not (left and bottom) then return nil end
    local x, y = 0, 0
    if from then x, y = from:GetLeft() or 0, from:GetBottom() or 0 end
    return { Tenth(left - x), Tenth(bottom - y), Tenth(r:GetWidth()), Tenth(r:GetHeight()) }
end

-- A line as it reads: colours, pictures and links taken out, on one line, cut at SNAP_TEXT
-- characters (never inside a letter).
local function Words(text)
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[^:|]*:", ""):gsub("|r", "")
        :gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|H.-|h(.-)|h", "%1"):gsub("|n", " "):gsub("%s*\n%s*", " ")
    if #text <= SNAP_TEXT then return text end
    local cut = SNAP_TEXT
    while cut > 0 and (text:byte(cut + 1) or 0) >= 128 and (text:byte(cut + 1) or 0) < 192 do cut = cut - 1 end
    return text:sub(1, cut) .. "..."
end

-- Every text shown in f, its shown children's too, in the order /jsal pieces counts them.
local function Lines(f, page, into)
    for _, r in ipairs({ f:GetRegions() }) do
        if r:IsShown() and r:GetObjectType() == "FontString" then
            local raw = r:GetText()
            local text = Compat.Plain(raw)
            if raw ~= nil and text ~= "" then
                into.count = into.count + 1
                if into.count <= SNAP_LINES then
                    local line = { t = text and Words(tostring(text)) or "(hidden by the game)", at = Rect(r, page) }
                    if r.IsTruncated and r:IsTruncated() then line.cut = true end
                    into.lines[#into.lines + 1] = line
                end
            end
        end
    end
    for _, child in ipairs({ f:GetChildren() }) do
        if child:IsShown() then Lines(child, page, into) end
    end
end

local function NameOf(f) return f:GetName() end

-- jsal.ui's shown windows and pieces: the dashboard, the pages in windows of their own, the pieces
-- Unlock Mode moves (by their keys there), and then any other of its frames on the screen, by name.
local function Shown()
    local out, seen = {}, {}
    local function Add(name, f)
        if not f or seen[f] or not f:IsShown() then return end
        seen[f] = true
        out[#out + 1] = { name = name, at = Rect(f), scale = math.floor(f:GetScale() * 1000 + 0.5) / 1000,
                          alpha = math.floor(f:GetAlpha() * 100 + 0.5) / 100 }
    end
    Add("dashboard", frame)
    for _, page in ipairs(PAGES) do
        if page.own then Add(page.key, page.own.frame) end
    end
    local movable = ns.Unlock and ns.Unlock.Pieces and ns.Unlock.Pieces() or {}
    local keys = {}
    for key in pairs(movable) do keys[#keys + 1] = key end
    table.sort(keys)
    for _, key in ipairs(keys) do
        local get = movable[key].frame
        if get then
            local ok, f = pcall(get)
            if ok then Add(key, f) end
        end
    end
    for _, f in ipairs({ UIParent:GetChildren() }) do
        local ok, name = pcall(NameOf, f)
        if ok and type(name) == "string" and name:find("^jsalUI") then Add(name:sub(7), f) end
    end
    return out
end

local function Snapshot(label)
    local _, class = UnitClass("player")
    local snap = {
        at = date("%Y-%m-%d %H:%M:%S"), server = Compat.ServerTime(), version = ns.version,
        class = class, level = UnitLevel("player"), zone = Compat.Plain(GetRealZoneText()),
        label = label ~= "" and label or nil,
        screen = { Tenth(UIParent:GetWidth()), Tenth(UIParent:GetHeight()) },
        pieces = Shown(), pages = {}, timings = {},
    }
    local into = { count = 0, lines = nil }
    local function Page(key, where, f)
        into.lines = {}
        local before = into.count
        Lines(f, f, into)
        local kept = #into.lines
        local more = (into.count - before) - kept
        snap.pages[#snap.pages + 1] = { key = key, where = where, at = Rect(f), lines = into.lines, more = more > 0 and more or nil }
    end
    if frame and frame:IsShown() and current and byKey[current].frame then
        snap.open = current
        Page(current, "dashboard", byKey[current].frame)
    end
    for _, page in ipairs(PAGES) do
        if page.own and page.own.frame and page.own.frame:IsShown() and page.frame then Page(page.key, "own window", page.frame) end
    end
    for k, v in pairs(ns.timings or {}) do
        if type(v) == "number" then snap.timings[k] = Tenth(v) end
    end
    return snap
end

if ns.CommandWithWords then ns.CommandWithWords("snap", function(words)
    if words == "clear" then
        ns.db.snaps = {}
        return ns.Print("Cleared the saved snapshots.")
    end
    local ok, snap = xpcall(function() return Snapshot(words) end, ns.Report)
    if not ok then return ns.Print("That snapshot hit an error. BugSack has the details.") end
    ns.db.snaps = type(ns.db.snaps) == "table" and ns.db.snaps or {}
    local kept = ns.db.snaps
    kept[#kept + 1] = snap
    while #kept > SNAPS_KEPT do table.remove(kept, 1) end
    ns.Print(("Saved what jsal.ui shows now (%d kept). It's written to your saved files at your next /reload."):format(#kept))
end) end
