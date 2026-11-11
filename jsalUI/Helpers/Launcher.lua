-- Quick buttons: a small bar of jsal.ui's places (the dashboard, the games,
-- the shopping list, the planners, the gear plan, the dungeon guide) and the
-- layer you're in, that can be dragged anywhere by its grip, so nobody has
-- to type /jsal. The three games share one button that opens a menu of them.
-- A gold dot marks a button with something waiting: today's puzzle not
-- played, your move in chess. Laid side by side, the time sits between its
-- two halves. Right-clicking the j locks or unlocks it; locked, the grip goes.
-- Choose the buttons in Settings or by right-clicking the grip, which also
-- stands the bar up. The minimap button's right-click menu lists the same
-- places.
local addonName, ns = ...
local Style, Compat = ns.Style, ns.Compat

local Launcher = ns.NewModule("launcher", {
    title = "Quick buttons",
    note = "A small bar of buttons you can move anywhere: the dashboard, the games, the gear plan and more.",
})
ns.Launcher = Launcher

local OWN = "Interface\\AddOns\\" .. addonName .. "\\Media\\Icons\\"
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

-- The Layer button opens a menu: guildmates in your zone on another layer
-- to join, asking in General, telling your guild, leaving a group. Telling
-- puts "I'm on layer 12 in Darkshore." in the guild chat box, ready to
-- send with Enter; it never sends by itself.
local function TellLayer()
    local c = ns.Layers.Current()
    if not c then return ns.Print(ns.Layers.NONE) end
    local line = ns.Layers.ShareLine(c)
    local open = (ChatFrameUtil and ChatFrameUtil.OpenChat) or ChatFrame_OpenChat
    if not open then return ns.Print(line) end
    open((IsInGuild() and "/g " or "") .. line)
end

local function LayerTooltip(tip)
    local c = ns.Layers.Current()
    if not c then
        tip:SetText("Layer")
        tip:AddLine("Not read on this map yet: mouse over any creature.", 1, 1, 1, true)
        return
    end
    local mapName = ns.Layers.MapName(c)
    tip:SetText("Layer " .. c.layer)
    tip:AddLine((mapName and (mapName .. ", read ") or "Read ") .. ns.Layers.Ago(c), 1, 1, 1)
    local others = ns.LayerSwitch and #ns.LayerSwitch.Choices() or 0
    if others > 0 then
        tip:AddLine(("%d guildmate%s here on another layer"):format(others, others == 1 and "" or "s"), 1, 1, 1)
    end
    tip:AddLine("Click to change layer or tell your guild", 0.89, 0.69, 0.29)
end

local function LayerMenu(button)
    -- From the minimap button's list there's no button to open beside, so
    -- the menu opens mid-screen.
    if ns.LayerSwitch then return ns.LayerSwitch.Menu(button or UIParent, TellLayer) end
    TellLayer()
end

-- Every button opens its place, and closes it when it's already open: the
-- dashboard page, or the page's own window (the gear plan, the dungeons).
local function Page(key)
    return function()
        if ns.Window.IsOpen(key) then ns.Window.Close(key) else ns.Window.Open(key) end
    end
end

local function Game(window, open)
    return function()
        local f = window()
        if f and f:IsShown() then f:Hide() else open() end
    end
end

local function Ready(place)
    return not place.ready or place.ready()
end

local function Waiting(place)
    if not (place.waiting and Ready(place)) then return nil end
    local ok, text = pcall(place.waiting)
    return ok and text or nil
end

-- The games inside the Games button that are there to use, in order.
local PLACES
local function Games()
    local list = {}
    for _, place in ipairs(PLACES) do
        if place.inGames and Ready(place) then list[#list + 1] = place end
    end
    return list
end

-- One button for the three games: its menu lists them, with what's waiting.
local function GamesMenu(button)
    local items = {}
    for _, place in ipairs(Games()) do
        items[#items + 1] = { place.label, Waiting(place) and "|cffe3b04bwaiting|r" or nil, place.open }
    end
    ns.Launcher.ShowMenu(button or UIParent, items)
end

local function GamesTooltip(tip)
    tip:SetText("Games")
    tip:AddLine("Daily Word, Icon Guess and chess", 1, 1, 1)
    for _, place in ipairs(Games()) do
        local waiting = Waiting(place)
        if waiting then tip:AddLine(waiting, 0.89, 0.69, 0.29) end
    end
end

-- inGames: inside the Games button, not a button of its own. barOnly: on
-- the bar but not in the minimap button's list, which names each game.
PLACES = {
    { key = "dashboard", label = "Dashboard", icon = "Interface\\AddOns\\" .. addonName .. "\\Media\\Logo",
      open = function() ns.Window.Toggle() end },
    { key = "games", label = "Games", icon = OWN .. "games", barOnly = true,
      ready = function() return #Games() > 0 end,
      open = GamesMenu,
      waiting = function()
          for _, place in ipairs(Games()) do
              local waiting = Waiting(place)
              if waiting then return waiting end
          end
      end,
      tooltip = GamesTooltip,
      note = "One button for Daily Word, Icon Guess and chess: it opens a menu of them, with a gold dot when one is waiting." },
    { key = "word", inGames = true, label = "Daily Word", icon = OWN .. "word",
      ready = function() return ns.DailyWord and ns.DailyWord.running end,
      open = Game(function() return jsalUIDailyWord end, function() ns.DailyWord.Open() end),
      waiting = function() return not ns.DailyWord.DailyDone() and ("Puzzle #%d is waiting"):format(ns.Games.Today()) or nil end },
    { key = "icons", inGames = true, label = "Icon Guess", icon = OWN .. "icons",
      ready = function() return ns.IconGuess and ns.IconGuess.running end,
      open = Game(function() return jsalUIIconGuess end, function() ns.IconGuess.Open() end),
      waiting = function() return not ns.IconGuess.DailyDone() and "Today's round is waiting" or nil end },
    { key = "chess", inGames = true, label = "Chess", icon = OWN .. "chess",
      ready = function() return ns.Chess and ns.Chess.running end,
      open = Page("chess"),
      waiting = ChessWaiting },
    { key = "shop", label = "Shopping list", icon = OWN .. "shop",
      ready = function() return ns.Shopping and ns.Shopping.running end,
      open = function() ns.Shopping.Toggle() end },
    { key = "build", label = "Build Planner", icon = OWN .. "build",
      open = Page("build") },
    { key = "training", label = "Training Planner", icon = OWN .. "training",
      open = Page("training") },
    { key = "gear", label = "Gear plan", icon = OWN .. "gear",
      ready = function() return ns.Gear and ns.Gear.running end,
      open = Page("gear") },
    { key = "dungeons", label = "Dungeon guide", icon = OWN .. "dungeons",
      ready = function() return ns.Dungeons and ns.Dungeons.running end,
      open = Page("dungeons") },
    -- Shows a number, not an icon: the layer last read on this map.
    { key = "layer", label = "Layer",
      ready = function() return ns.Layers and ns.Layers.running end,
      number = function() local c = ns.Layers.Current(); return c and c.layer end,
      tooltip = LayerTooltip,
      open = LayerMenu,
      note = "The layer jsal.ui last read on this map. Click it to join a guildmate on another layer, or to tell your guild. Needs Layers on." },
}

-- Settings has a switch for each button, the same choice as the grip's
-- right-click menu; they apply at once.
Launcher.options = {}
for _, place in ipairs(PLACES) do
    if not place.inGames then
        Launcher.options[#Launcher.options + 1] = { key = place.key, title = place.label, default = true,
            note = place.note or "Show its button on the bar. Right-clicking the bar's grip gives the same choice." }
    end
end
Launcher.options[#Launcher.options + 1] = { key = "time", title = "The time", default = false,
    note = "The time in the middle of the bar, when it's laid out side by side. Hover it for local and realm time; click it for the game's clock." }

local function Hidden(key) return not ns.OptionOn("launcher", key) end

-- The same places for other parts (the flight bar's games): one by key, and
-- whether it's there to use and what's waiting.
function Launcher.Place(key)
    for _, place in ipairs(PLACES) do
        if place.key == key then return place end
    end
end
Launcher.Ready, Launcher.Waiting = Ready, Waiting

-- Saved for the account: where the bar is, its direction and whether it's
-- locked. Which buttons show are Settings options; buttons hidden before
-- those existed move across to them once.
local function Saved()
    local s = ns.db.launcher
    if type(s) ~= "table" then
        s = {}
        ns.db.launcher = s
    end
    if type(s.hidden) == "table" then
        for key, hide in pairs(s.hidden) do
            if hide then ns.SetOption("launcher", key, false) end
        end
    end
    s.hidden = nil
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
        Style.Shadow(menu, 12)
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
            r.note = Style.Text(r, 12, "muted")
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
        if Ready(place) and not place.barOnly then
            local waiting = Waiting(place)
            items[#items + 1] = { place.label, waiting and "|cffe3b04bwaiting|r" or nil, place.open }
        end
    end
    Launcher.ShowMenu(anchor, items)
end

---------------------------------------------------------------------------
-- The bar.
---------------------------------------------------------------------------
local bar, grip, clock
local buttons = {}
local Layout

-- Locked, the grip goes and the bar can't be dragged; the j's right-click
-- (or the grip's menu, while unlocked) switches it.
-- The bar is held by its centre, so it stays centred where it was put when
-- it grows or shrinks: the grip coming and going with the lock, a button
-- switched on or off.
local function HoldByCentre()
    local cx, cy = bar:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if not (cx and cy and ux and uy) then return end
    local x, y = math.floor(cx - ux + 0.5), math.floor(cy - uy + 0.5)
    bar:ClearAllPoints()
    bar:SetPoint("CENTER", UIParent, "CENTER", x, y)
    local s = Saved()
    s.point, s.relative, s.x, s.y = "CENTER", "CENTER", x, y
end

local function ToggleLock()
    local s = Saved()
    s.locked = not s.locked or nil
    HoldByCentre()
    Layout()
    if GameTooltip:IsShown() and buttons.dashboard and GameTooltip:IsOwned(buttons.dashboard) then
        buttons.dashboard:GetScript("OnEnter")(buttons.dashboard)
    end
end
Launcher.ToggleLock = ToggleLock

---------------------------------------------------------------------------
-- The time, in the middle of the bar: local or realm time and 12 or 24
-- hours as the game's own clock is set.
---------------------------------------------------------------------------
local function Hours(h, m, military)
    if military then return ("%d:%02d"):format(h, m), "" end
    return ("%d:%02d"):format(h % 12 == 0 and 12 or h % 12, m), h < 12 and "AM" or "PM"
end

function Launcher.Time(which)
    local military = GetCVarBool and GetCVarBool("timeMgrUseMilitaryTime")
    local localTime = which == "local" or (which == nil and GetCVarBool and GetCVarBool("timeMgrUseLocalTime"))
    local h, m
    if localTime or not GetGameTime then
        local now = date("*t")
        h, m = now.hour, now.min
    else
        h, m = GetGameTime()
    end
    return Hours(h, m, military)
end

local function PaintClock()
    if not (clock and clock:IsShown()) then return end
    local text, half = Launcher.Time()
    if clock.time:GetText() == text and clock.half:GetText() == half then return end
    -- Room for the widest time with this many digits, so the bar keeps its
    -- width from one minute to the next (digits differ in width, and a bar
    -- that resizes every minute is laid out again every minute). The time
    -- sits in the middle of its room.
    local digit, most = "0", 0
    for d = 0, 9 do
        clock.time:SetText(tostring(d))
        local w = clock.time:GetStringWidth()
        if w > most then digit, most = tostring(d), w end
    end
    clock.time:SetText((text:gsub("%d", digit)))
    local room = clock.time:GetStringWidth()
    clock.time:SetText(text)
    clock.half:SetText(half)
    clock.time:SetPoint("LEFT", 10 + math.max(0, room - clock.time:GetStringWidth()) / 2, 0)
    local width = room + (half ~= "" and clock.half:GetStringWidth() + 3 or 0) + 20
    if math.abs(clock:GetWidth() - width) > 0.5 then
        clock:SetWidth(width)
        Layout()
    end
end

local function OpenClock()
    if not TimeManager_Toggle then
        local load = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
        if load then pcall(load, "Blizzard_TimeManager") end
    end
    if TimeManager_Toggle then TimeManager_Toggle() end
end

local function BuildClock()
    clock = CreateFrame("Button", nil, bar)
    clock:SetSize(70, SIZE)
    clock.time = Style.Text(clock, 15, "text", nil, true)
    clock.half = Style.Text(clock, 12, "muted")
    clock.time:SetPoint("LEFT", 10, 0)
    clock.half:SetPoint("LEFT", clock.time, "RIGHT", 3, 0)
    clock:SetScript("OnClick", OpenClock)
    clock:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Time")
        local lt, lh = Launcher.Time("local")
        local rt, rh = Launcher.Time("realm")
        GameTooltip:AddDoubleLine("Local time", lt .. (lh ~= "" and " " .. lh or ""), 0.6, 0.59, 0.53, 1, 1, 1)
        GameTooltip:AddDoubleLine("Realm time", rt .. (rh ~= "" and " " .. rh or ""), 0.6, 0.59, 0.53, 1, 1, 1)
        GameTooltip:AddLine("Click for the game's clock: stopwatch and alarm.", 0.6, 0.59, 0.53)
        GameTooltip:Show()
    end)
    clock:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function SavePlace()
    HoldByCentre()
end

local function Button(place)
    local b = CreateFrame("Button", nil, bar)
    b:SetSize(SIZE, SIZE)
    Style.Fill(b, "well")
    b.edges = Style.Border(b, "lineStrong")
    if place.number then
        b.number = Style.Text(b, 15, "gold", nil, true)
        b.number:SetPoint("CENTER", 0, 0)
        b.number:SetText("?")
    else
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetPoint("TOPLEFT", 2, -2)
        b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
        b.icon:SetTexture(place.icon)
    end
    b.dot = b:CreateTexture(nil, "OVERLAY")
    b.dot:SetTexture("Interface\\AddOns\\" .. addonName .. "\\Media\\Chess\\dot")
    b.dot:SetVertexColor(Style.Color("gold"))
    b.dot:SetSize(10, 10)
    b.dot:SetPoint("TOPRIGHT", 3, 3)
    b.dot:Hide()
    -- The j also takes a right-click: it locks or unlocks the bar.
    local isJ = place.key == "dashboard"
    if isJ then b:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
    b:SetScript("OnClick", function(self, mouse)
        if isJ and mouse == "RightButton" then return ToggleLock() end
        place.open(self)
    end)
    b:SetScript("OnEnter", function(self)
        Style.SetBorder(self.edges, "gold")
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        if place.tooltip then
            place.tooltip(GameTooltip)
        else
            GameTooltip:SetText(place.label)
            local waiting = Waiting(place)
            if waiting then GameTooltip:AddLine(waiting, 0.89, 0.69, 0.29) end
        end
        if isJ then
            GameTooltip:AddLine(Saved().locked and "Right-click to unlock the bar." or "Right-click to lock the bar.", 0.6, 0.59, 0.53)
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self)
        Style.SetBorder(self.edges, "lineStrong")
        GameTooltip:Hide()
    end)
    b.place = place
    return b
end

-- The buttons due on the bar, as one line, to notice a change: parts that
-- start after the bar (the gear plan, the dungeon guide) or are switched
-- on or off elsewhere show up at the next look, without a reload.
local laidOut
local function Due()
    local due = {}
    for _, place in ipairs(PLACES) do
        if buttons[place.key] and Ready(place) and not Hidden(place.key) then due[#due + 1] = place.key end
    end
    return table.concat(due, ",")
end

-- Which buttons show, in order, and where: side by side, or up and down.
-- Side by side, the time sits between the two halves. The grip takes room
-- only while the bar is unlocked.
Layout = function()
    laidOut = Due()
    local s = Saved()
    local vertical = s.vertical
    local list = {}
    for _, place in ipairs(PLACES) do
        local b = buttons[place.key]
        local on = b ~= nil and Ready(place) and not Hidden(place.key)
        if b then b:SetShown(on) end
        if on then list[#list + 1] = b end
    end
    local withClock = clock ~= nil and not vertical and not Hidden("time")
    if clock then clock:SetShown(withClock) end
    local half = math.ceil(#list / 2)
    grip:SetShown(not s.locked)
    local at = 4 + (s.locked and 0 or GRIP)
    for i, b in ipairs(list) do
        b:ClearAllPoints()
        if vertical then b:SetPoint("TOPLEFT", 4, -at) else b:SetPoint("TOPLEFT", at, -4) end
        at = at + SIZE + GAP
        if withClock and i == half then
            clock:ClearAllPoints()
            clock:SetPoint("TOPLEFT", at, -4)
            at = at + clock:GetWidth() + GAP
        end
    end
    if #list == 0 then at = at + SIZE + GAP end
    local length = at - GAP + 4
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

-- A number button's number: gold once read, a grey "?" before, smaller
-- when it has more digits so it stays inside the button.
local function PaintNumber(b)
    local ok, n = pcall(b.place.number)
    n = ok and n or nil
    local text = n and tostring(n) or "?"
    local font, _, flags = b.number:GetFont()
    if font then b.number:SetFont(font, #text <= 2 and 15 or #text == 3 and 13 or 11, flags) end
    b.number:SetText(text)
    b.number:SetTextColor(Style.Color(n and "gold" or "muted"))
end

-- The dots: something waiting at a place; and the numbers.
local function PaintDots()
    if not bar then return end
    for _, b in pairs(buttons) do
        b.dot:SetShown(b:IsShown() and Waiting(b.place) ~= nil)
        if b.number and b:IsShown() then PaintNumber(b) end
    end
end

-- Whether a shown button (or the time) has lost its place on screen: the
-- game can drop a button's position while it's still pinned to the bar, and
-- an unplaced button isn't drawn. Laying the bar out again pins it afresh.
function Launcher.Lost()
    if not (bar and bar:IsShown()) then return false end
    for _, b in pairs(buttons) do
        if b:IsShown() and not b:GetLeft() then return true end
    end
    return clock ~= nil and clock:IsShown() and not clock:GetLeft()
end

-- How the game sees the bar and a button, as one line, for finding out why
-- a button stops being drawn. Every value goes through tostring under
-- pcall, so one the game won't hand over reads "?" instead of erroring.
local function Say(fn, ...)
    local ok, a, b, c, d, e = pcall(fn, ...)
    if not ok then return "?" end
    local out = {}
    for i, v in ipairs({ a == nil and "nil" or a, b, c, d, e }) do
        local fine, text = pcall(tostring, type(v) == "table" and (v.GetName and v:GetName() or "frame") or v)
        out[i] = fine and text or "?"
    end
    return table.concat(out, ",")
end

local function Describe(name, f)
    if not f then return name .. ": none" end
    return ("%s shown=%s visible=%s alpha=%s left=%s top=%s size=%s,%s points=%s at=%s level=%s strata=%s"):format(
        name, Say(f.IsShown, f), Say(f.IsVisible, f), Say(f.GetEffectiveAlpha, f), Say(f.GetLeft, f), Say(f.GetTop, f),
        Say(f.GetWidth, f), Say(f.GetHeight, f), Say(f.GetNumPoints, f), Say(f.GetPoint, f, 1),
        Say(f.GetFrameLevel, f), Say(f.GetFrameStrata, f))
end

-- A look at the bar, kept in the settings file (the last few): when it
-- was, where, and how the game sees the bar, the j and any button with no
-- place. `why` says what asked: the bar's own check, or /jsal bar.
local KEEP_CHECKS = 8
function Launcher.Check(why)
    if not bar then return {} end
    local lines = { Describe("bar", bar), Describe("dashboard", buttons.dashboard) }
    for key, b in pairs(buttons) do
        if key ~= "dashboard" and b:IsShown() and not b:GetLeft() then lines[#lines + 1] = Describe(key, b) end
    end
    local list = type(ns.db.barChecks) == "table" and ns.db.barChecks or {}
    list[#list + 1] = {
        why = why, at = Compat.ServerTime and Compat.ServerTime() or 0, version = ns.version,
        zone = Say(GetRealZoneText), combat = Say(InCombatLockdown), locked = Saved().locked and true or false, lines = lines,
    }
    while #list > KEEP_CHECKS do table.remove(list, 1) end
    ns.db.barChecks = list
    return lines
end

-- A button made afresh in the old one's place, for one the game still
-- won't place after the bar is laid out again.
local MakeButton = Button
local function Remake(key)
    local old = buttons[key]
    if not (old and old.place) then return end
    old:Hide()
    old:ClearAllPoints()
    buttons[key] = MakeButton(old.place)
end

-- The repair: lay the bar out again; any button still without a place is
-- made afresh. Returns what it took: "layout", "remade", or "failed".
function Launcher.Mend()
    Layout()
    if not Launcher.Lost() then return "layout" end
    for key, b in pairs(buttons) do
        if b:IsShown() and not b:GetLeft() then Remake(key) end
    end
    Layout()
    return Launcher.Lost() and "failed" or "remade"
end

-- A switch flipped in Settings shows or hides its button at once.
function Launcher:OnOption()
    if not bar then return end
    Layout()
    PaintDots()
end

local function GripMenu()
    local s = Saved()
    local items = {}
    for _, place in ipairs(PLACES) do
        if Ready(place) and not place.inGames then
            items[#items + 1] = { place.label, Hidden(place.key) and "hidden" or "shown", function()
                ns.SetOption("launcher", place.key, Hidden(place.key))
                Layout()
                PaintDots()
            end }
        end
    end
    items[#items + 1] = { s.vertical and "Lay it out side by side" or "Lay it out up and down", nil, function()
        s.vertical = not s.vertical or nil
        Layout()
    end }
    items[#items + 1] = { s.locked and "Unlock it" or "Lock it in place", "or right-click the j", ToggleLock }
    Launcher.ShowMenu(grip, items)
end

local function Build()
    bar = CreateFrame("Frame", "jsalUIQuickButtons", UIParent)
    bar:SetFrameStrata("MEDIUM")
    bar:SetClampedToScreen(true)
    bar:SetMovable(true)
    Style.Fill(bar, "window")
    Style.Border(bar, "lineStrong")
    Style.Shadow(bar, 10)
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
    for _, place in ipairs(PLACES) do
        if not place.inGames then buttons[place.key] = Button(place) end
    end
    BuildClock()
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
    -- In EllesmereUI's Unlock Mode, with its grid and snapping, when it's on.
    if ns.Unlock then
        ns.Unlock.Add({
            key = "QuickButtons", label = "jsal.ui quick buttons",
            frame = function() return bar end,
            hidden = function() return not bar:IsShown() end,
            load = function()
                local s = Saved()
                return s.point and { s.point, s.relative, s.x, s.y } or nil
            end,
            save = function(point, relative, x, y)
                local s = Saved()
                s.point, s.relative, s.x, s.y = point, relative, x, y
                if not point then
                    bar:ClearAllPoints()
                    bar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 160)
                end
            end,
        })
    end
    -- The buttons and dots are looked at every few seconds, once everything
    -- has started, and when chess changes.
    -- A button counts as lost when it has no place on two looks a second
    -- apart: the game can take a moment to place one after the bar is laid
    -- out, and that isn't a button gone missing.
    local lostFor = 0
    local function Look()
        if lostFor >= 2 and Launcher.Lost() then
            lostFor = 0
            -- Noted before and after the repair, so a recurrence leaves
            -- what the game said about it in the settings file.
            Launcher.Check("lost")
            local how = Launcher.Mend()
            local checks = ns.db.barChecks
            if checks and checks[#checks] then checks[#checks].mended = how end
        elseif Due() ~= laidOut then
            Layout()
        end
        PaintDots()
    end
    -- The time is looked at each second; it changes only on the minute.
    local elapsed, ticked = 0, 0
    bar:SetScript("OnUpdate", function(_, dt)
        elapsed, ticked = elapsed + dt, ticked + dt
        if ticked >= 1 then
            ticked = 0
            xpcall(PaintClock, ns.Report)
        end
        -- A button with no place is looked for each second, so one that
        -- goes is back almost at once; the rest waits its three seconds.
        if ticked == 0 then
            lostFor = Launcher.Lost() and lostFor + 1 or 0
            if lostFor >= 2 then elapsed = 3 end
        end
        if elapsed < 3 then return end
        elapsed = 0
        xpcall(Look, ns.Report)
    end)
    xpcall(PaintClock, ns.Report)
    Compat.After(0, function() xpcall(Look, ns.Report) end)
    if ns.Chess and ns.Chess.OnChange then ns.Chess.OnChange(function() xpcall(PaintDots, ns.Report) end) end
    if ns.Layers and ns.Layers.OnChange then ns.Layers.OnChange(function() xpcall(PaintDots, ns.Report) end) end
    Compat.After(2, function() xpcall(PaintDots, ns.Report) end)
end

-- /jsal bar: what the game says about the bar and the j, into chat and the
-- settings file, then the repair. For when a button has gone missing.
ns.Command("bar", function()
    if not bar then return ns.Print("The quick buttons are switched off.") end
    for _, line in ipairs(Launcher.Check("asked")) do ns.Print(line) end
    local how = Launcher.Mend()
    local checks = ns.db.barChecks
    if checks and checks[#checks] then checks[#checks].mended = how end
    PaintDots()
    ns.Print(how == "failed" and "Laid the bar out again; a button still has no place. A /reload brings it back."
        or "Laid the bar out again. This look is saved for a bug report.")
end)

function Launcher:OnDisable()
    if bar then
        bar:SetScript("OnUpdate", nil)
        bar:Hide()
    end
    CloseMenu()
end
