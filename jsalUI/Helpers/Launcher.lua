-- Quick buttons: a small bar of jsal.ui's places (the dashboard, today's
-- games, chess, the shopping list, the Build Planner) that can be dragged
-- anywhere by its grip, so nobody has to type /jsal. A gold dot marks a
-- button with something waiting: today's puzzle not played, your move in
-- chess. Right-click the grip to choose the buttons, stand the bar up, or
-- lock it. The minimap button's right-click menu lists the same places.
local addonName, ns = ...
local Style, Compat = ns.Style, ns.Compat

local Launcher = ns.NewModule("launcher", {
    title = "Quick buttons",
    note = "A small bar of buttons you can move anywhere: the dashboard, games, chess and more.",
})
ns.Launcher = Launcher

local ICONS = "Interface\\Icons\\"
local SIZE, GAP, GRIP = 32, 4, 12

-- The places: what each opens, its icon, whether it's there to use, and
-- what's waiting there, if anything.
local function ChessWaiting()
    local chess = ns.Chess
    if not (chess and chess.running) then return nil end
    for _, game in ipairs(chess.Games()) do
        if game.status == "asked" then return game.opp .. " wants a game" end
        if chess.MyTurn(game) then return "Your move against " .. game.opp end
    end
end

local PLACES = {
    { key = "dashboard", label = "Dashboard", icon = "Interface\\AddOns\\" .. addonName .. "\\Media\\Logo",
      open = function() ns.Window.Toggle() end },
    { key = "word", label = "Daily Word", icon = ICONS .. "INV_Misc_Note_01",
      ready = function() return ns.DailyWord and ns.DailyWord.running end,
      open = function() ns.DailyWord.Open() end,
      waiting = function() return not ns.DailyWord.DailyDone() and ("Puzzle #%d is waiting"):format(ns.Games.Today()) or nil end },
    { key = "icons", label = "Icon Guess", icon = ICONS .. "INV_Misc_QuestionMark",
      ready = function() return ns.IconGuess and ns.IconGuess.running end,
      open = function() ns.IconGuess.Open() end,
      waiting = function() return not ns.IconGuess.DailyDone() and "Today's round is waiting" or nil end },
    { key = "chess", label = "Chess", icon = "Interface\\AddOns\\" .. addonName .. "\\Media\\Chess\\icon",
      ready = function() return ns.Chess and ns.Chess.running end,
      open = function() ns.Window.Open("chess") end,
      waiting = ChessWaiting },
    { key = "shop", label = "Shopping list", icon = ICONS .. "INV_Misc_Bag_08",
      ready = function() return ns.Shopping and ns.Shopping.running end,
      open = function() ns.Shopping.Toggle() end },
    { key = "build", label = "Build Planner", icon = ICONS .. "Ability_Marksmanship",
      open = function() ns.Window.Open("build") end },
}

local function Ready(place)
    return not place.ready or place.ready()
end

local function Waiting(place)
    if not (place.waiting and Ready(place)) then return nil end
    local ok, text = pcall(place.waiting)
    return ok and text or nil
end

-- Saved for the account: where the bar is, which buttons are hidden, its
-- direction and whether it's locked.
local function Saved()
    local s = ns.db.launcher
    if type(s) ~= "table" then
        s = { hidden = {} }
        ns.db.launcher = s
    end
    s.hidden = type(s.hidden) == "table" and s.hidden or {}
    return s
end

---------------------------------------------------------------------------
-- A small menu of rows, shared by the bar's grip and the minimap button.
-- Each row is { label, note, onClick }; a click anywhere else closes it.
---------------------------------------------------------------------------
local menu, menuRows, catcher = nil, {}, nil

local function CloseMenu()
    if menu then menu:Hide() end
    if catcher then catcher:Hide() end
end

function Launcher.ShowMenu(anchor, items)
    if not menu then
        menu = CreateFrame("Frame", "jsalUIQuickMenu", UIParent)
        menu:SetFrameStrata("DIALOG")
        menu:SetClampedToScreen(true)
        menu:SetWidth(200)
        Style.Fill(menu, "window")
        Style.Border(menu, "lineStrong")
        -- A full-screen layer under the menu: a click outside closes it.
        catcher = CreateFrame("Button", nil, UIParent)
        catcher:SetAllPoints(UIParent)
        catcher:SetFrameStrata("DIALOG")
        catcher:SetFrameLevel(1)
        catcher:RegisterForClicks("AnyUp")
        catcher:SetScript("OnClick", CloseMenu)
        menu:SetFrameLevel(10)
    end
    for i, item in ipairs(items) do
        local r = menuRows[i]
        if not r then
            r = CreateFrame("Button", nil, menu)
            r:SetSize(200, 26)
            r.bg = Style.Fill(r, "well")
            r.bg:Hide()
            r.label = Style.Text(r, 12, "text")
            r.label:SetPoint("LEFT", 10, 0)
            r.note = Style.Text(r, 11, "muted")
            r.note:SetPoint("RIGHT", -10, 0)
            r.note:SetJustifyH("RIGHT")
            r:SetScript("OnEnter", function(self) self.bg:Show() end)
            r:SetScript("OnLeave", function(self) self.bg:Hide() end)
            menuRows[i] = r
        end
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 0, -(i - 1) * 26)
        r.label:SetText(item[1])
        r.note:SetText(item[2] or "")
        r:SetScript("OnClick", function()
            CloseMenu()
            item[3]()
        end)
        r:Show()
    end
    for i = #items + 1, #menuRows do menuRows[i]:Hide() end
    menu:SetHeight(#items * 26)
    -- It opens toward the middle of the screen, away from the nearest edges.
    local x, y = anchor:GetCenter()
    local below = (y or 0) > UIParent:GetHeight() / 2
    local leftward = (x or 0) > UIParent:GetWidth() / 2
    local side = leftward and "RIGHT" or "LEFT"
    menu:ClearAllPoints()
    menu:SetPoint((below and "TOP" or "BOTTOM") .. side, anchor, (below and "BOTTOM" or "TOP") .. side, 0, below and -4 or 4)
    catcher:Show()
    menu:Show()
end

-- The places as menu rows, with what's waiting at each.
function Launcher.PlacesMenu(anchor)
    local items = {}
    for _, place in ipairs(PLACES) do
        if Ready(place) then
            local waiting = Waiting(place)
            items[#items + 1] = { place.label, waiting and "|cffe3b04bwaiting|r" or nil, function()
                ns.Count("minimapMenu." .. place.key)
                place.open()
            end }
        end
    end
    Launcher.ShowMenu(anchor, items)
end

---------------------------------------------------------------------------
-- The bar.
---------------------------------------------------------------------------
local bar, grip
local buttons = {}
local Layout

local function SavePlace()
    local point, _, relative, x, y = bar:GetPoint(1)
    local s = Saved()
    s.point, s.relative, s.x, s.y = point, relative, x, y
end

local function Button(place)
    local b = CreateFrame("Button", nil, bar)
    b:SetSize(SIZE, SIZE)
    Style.Fill(b, "well")
    b.edges = Style.Border(b, "lineStrong")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 2, -2)
    b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    b.icon:SetTexture(place.icon)
    if place.icon:find("\\Icons\\", 1, true) then b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    b.dot = b:CreateTexture(nil, "OVERLAY")
    b.dot:SetTexture("Interface\\AddOns\\" .. addonName .. "\\Media\\Chess\\dot")
    b.dot:SetVertexColor(Style.Color("gold"))
    b.dot:SetSize(10, 10)
    b.dot:SetPoint("TOPRIGHT", 3, 3)
    b.dot:Hide()
    b:SetScript("OnClick", function()
        ns.Count("quickButtons." .. place.key)
        place.open()
    end)
    b:SetScript("OnEnter", function(self)
        Style.SetBorder(self.edges, "gold")
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(place.label)
        local waiting = Waiting(place)
        if waiting then GameTooltip:AddLine(waiting, 0.89, 0.69, 0.29) end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self)
        Style.SetBorder(self.edges, "lineStrong")
        GameTooltip:Hide()
    end)
    b.place = place
    return b
end

-- Which buttons show, in order, and where: side by side, or up and down.
Layout = function()
    local s = Saved()
    local vertical = s.vertical
    local shown = 0
    for _, place in ipairs(PLACES) do
        local b = buttons[place.key]
        local on = Ready(place) and not s.hidden[place.key]
        b:SetShown(on)
        if on then
            b:ClearAllPoints()
            local offset = GRIP + 4 + shown * (SIZE + GAP)
            if vertical then
                b:SetPoint("TOPLEFT", 4, -offset)
            else
                b:SetPoint("TOPLEFT", offset, -4)
            end
            shown = shown + 1
        end
    end
    local length = GRIP + 4 + math.max(1, shown) * (SIZE + GAP)
    if vertical then bar:SetSize(SIZE + 8, length) else bar:SetSize(length, SIZE + 8) end
    grip:ClearAllPoints()
    if vertical then
        grip:SetPoint("TOPLEFT", 4, -4)
        grip:SetPoint("TOPRIGHT", -4, -4)
        grip:SetHeight(GRIP)
    else
        grip:SetPoint("TOPLEFT", 4, -4)
        grip:SetPoint("BOTTOMLEFT", 4, 4)
        grip:SetWidth(GRIP)
    end
end

-- The dots: something waiting at a place.
local function PaintDots()
    if not bar then return end
    for _, b in pairs(buttons) do b.dot:SetShown(b:IsShown() and Waiting(b.place) ~= nil) end
end

local function GripMenu()
    local s = Saved()
    local items = {}
    for _, place in ipairs(PLACES) do
        if Ready(place) then
            items[#items + 1] = { place.label, s.hidden[place.key] and "hidden" or "shown", function()
                s.hidden[place.key] = not s.hidden[place.key] or nil
                Layout()
                PaintDots()
            end }
        end
    end
    items[#items + 1] = { s.vertical and "Lay it out side by side" or "Lay it out up and down", nil, function()
        s.vertical = not s.vertical or nil
        Layout()
    end }
    items[#items + 1] = { s.locked and "Unlock it" or "Lock it in place", nil, function()
        s.locked = not s.locked or nil
    end }
    Launcher.ShowMenu(grip, items)
end

local function Build()
    bar = CreateFrame("Frame", "jsalUIQuickButtons", UIParent)
    bar:SetFrameStrata("MEDIUM")
    bar:SetClampedToScreen(true)
    bar:SetMovable(true)
    Style.Fill(bar, "window")
    Style.Border(bar, "lineStrong")
    grip = CreateFrame("Button", nil, bar)
    grip:RegisterForClicks("RightButtonUp")
    grip:RegisterForDrag("LeftButton")
    -- Three short lines: the grip's look.
    for i = 1, 3 do
        local line = grip:CreateTexture(nil, "ARTWORK")
        line:SetColorTexture(Style.Color("lineStrong"))
        line:SetSize(8, 2)
        line:SetPoint("CENTER", 0, (i - 2) * 5)
    end
    grip:SetScript("OnDragStart", function()
        if not Saved().locked then bar:StartMoving() end
    end)
    grip:SetScript("OnDragStop", function()
        bar:StopMovingOrSizing()
        SavePlace()
    end)
    grip:SetScript("OnClick", GripMenu)
    grip:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("jsal.ui")
        GameTooltip:AddLine(Saved().locked and "Locked. Right-click for options." or "Drag to move. Right-click for options.", 1, 1, 1)
        GameTooltip:Show()
    end)
    grip:SetScript("OnLeave", function() GameTooltip:Hide() end)
    for _, place in ipairs(PLACES) do buttons[place.key] = Button(place) end
    local s = Saved()
    if s.point then
        bar:SetPoint(s.point, UIParent, s.relative or s.point, s.x or 0, s.y or 0)
    else
        bar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 160)
    end
    Layout()
end

function Launcher:OnEnable()
    if not bar then Build() end
    Layout()
    bar:Show()
    -- The dots are looked at every few seconds and when chess changes.
    local elapsed = 0
    bar:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed < 3 then return end
        elapsed = 0
        xpcall(PaintDots, ns.Report)
    end)
    if ns.Chess and ns.Chess.OnChange then ns.Chess.OnChange(function() xpcall(PaintDots, ns.Report) end) end
    Compat.After(2, function() xpcall(PaintDots, ns.Report) end)
end

function Launcher:OnDisable()
    if bar then
        bar:SetScript("OnUpdate", nil)
        bar:Hide()
    end
    CloseMenu()
end
