-- The flight bar: while you fly, the route, the time left and today's games.
-- The game doesn't tell addons how long a flight takes, but its own flight
-- tables give each path's length (FlightData.lua). A flight's time is the
-- length of its legs over the flight speed, plus any stops along the way.
local _, ns = ...
local Style, Compat = ns.Style, ns.Compat

local Flight = ns.NewModule("flight", {
    title = "Flight bar",
    note = "Route, time left and today's games while you fly.",
})

-- Flights go about 29.9 yards a second on Forever, as measured over whole
-- flights. Each normal landing measures the speed again, and the last few
-- measurements are averaged, so the countdown keeps up if it ever changes.
local BASE_SPEED = 29.9
local KEEP, TRUST = 5, 0.3   -- measurements kept; how far off one may be
local WIDTH = 380

local function Speed()
    local list = ns.db.flightSpeeds
    if type(list) ~= "table" or #list == 0 then return BASE_SPEED end
    local sum = 0
    for _, s in ipairs(list) do sum = sum + s end
    return sum / #list
end

local function LearnSpeed(flight, seconds)
    local flying = seconds - (flight.stops or 0)
    if not flight.yards or flying <= 0 then return end
    local speed = flight.yards / flying / (flight.bonus or 1)
    if math.abs(speed - BASE_SPEED) / BASE_SPEED > TRUST then return end
    local list = type(ns.db.flightSpeeds) == "table" and ns.db.flightSpeeds or {}
    list[#list + 1] = speed
    while #list > KEEP do table.remove(list, 1) end
    ns.db.flightSpeeds = list
end

-- Yards and stop seconds for a flight, leg by leg, or nil when a leg isn't
-- in the game's tables.
local function Legs(nodes, hops)
    local yards, stops = 0, 0
    for _, hop in ipairs(hops) do
        local from, to = nodes[hop[1]], nodes[hop[2]]
        local path = from and to and from.id and to.id and ns.FlightPaths[from.id * 10000 + to.id]
        if not path then return nil end
        yards, stops = yards + path[1], stops + path[2]
    end
    if #hops == 0 then return nil end
    return yards, stops
end

-- Flight points are named "Town, Zone"; the bar shows just the town.
local function Short(name)
    return name and (name:match("^([^,]+)") or name) or "?"
end

local function Clock(seconds)
    seconds = math.max(0, math.floor(seconds + 0.5))
    return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

-- The bar.
local bar, route, time, track, fill, knob, note
local current

-- Today's games and chess, as the quick buttons' icons: a gold dot when
-- one is waiting (today's puzzle not played, your move), a tooltip saying
-- what. Parts that are switched off leave no gap.
local GAMES, TILE = { "word", "icons", "chess" }, 32
local tiles = {}

local function PaintGames()
    local launcher = ns.Launcher
    local x = 12
    for _, key in ipairs(GAMES) do
        local t, place = tiles[key], launcher and launcher.Place(key)
        local on = t and place and launcher.Ready(place)
        if t then t:SetShown(on and true or false) end
        if on then
            t:ClearAllPoints()
            t:SetPoint("BOTTOMLEFT", x, 12)
            x = x + TILE + 6
            t.dot:SetShown(launcher.Waiting(place) ~= nil)
        end
    end
end

local function Tile(key)
    local place = ns.Launcher and ns.Launcher.Place(key)
    if not place then return end
    local t = CreateFrame("Button", nil, bar)
    t:SetSize(TILE, TILE)
    t.icon = t:CreateTexture(nil, "ARTWORK")
    t.icon:SetAllPoints()
    t.icon:SetTexture(place.icon)
    t.dot = t:CreateTexture(nil, "OVERLAY")
    t.dot:SetTexture("Interface\\AddOns\\jsalUI\\Media\\Chess\\dot")
    t.dot:SetVertexColor(Style.Color("gold"))
    t.dot:SetSize(10, 10)
    t.dot:SetPoint("TOPRIGHT", 3, 3)
    t:SetScript("OnClick", function()
        place.open()
        PaintGames()
    end)
    t:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(place.label)
        local waiting = ns.Launcher.Waiting(place)
        if waiting then GameTooltip:AddLine(waiting, 0.89, 0.69, 0.29) end
        GameTooltip:Show()
    end)
    t:SetScript("OnLeave", function() GameTooltip:Hide() end)
    tiles[key] = t
end

local function Paint()
    if not current then return end
    local elapsed = Compat.Now() - current.start
    local trackWidth = track:GetWidth()
    if current.expected then
        local left = current.expected - elapsed
        local share = math.min(1, math.max(0, elapsed / current.expected))
        time:SetText(Clock(left))
        time:SetTextColor(Style.Color("gold"))
        fill:SetWidth(math.max(1, trackWidth * share))
        fill:Show()
        knob:ClearAllPoints()
        knob:SetPoint("CENTER", track, "LEFT", trackWidth * share, 0)
        knob:Show()
        note:SetText(left <= 0 and "Landing any moment" or (Clock(current.expected) .. " in all"))
    else
        -- A route the tables don't have: count up instead.
        time:SetText(Clock(elapsed))
        time:SetTextColor(Style.Color("text"))
        fill:Hide()
        knob:Hide()
        note:SetText("This route isn't in the game's flight tables yet")
    end
end

local function Build()
    -- One fixed spot, top centre, where flight timers usually sit; it isn't
    -- dragged, so it's always where you look for it. A spot saved by the
    -- older, draggable bar is forgotten.
    ns.db.flightPoint = nil
    bar = CreateFrame("Frame", "jsalUIFlightBar", UIParent)
    bar:SetSize(WIDTH, 112)
    bar:SetPoint("TOP", 0, -150)
    bar:SetFrameStrata("MEDIUM")
    bar:EnableMouse(true)
    bar:Hide()
    Style.Fill(bar, "window")
    Style.Border(bar, "lineStrong")

    route = Style.Text(bar, 14, "text")
    route:SetPoint("TOPLEFT", 12, -12)
    route:SetWidth(WIDTH - 110)
    route:SetWordWrap(false)
    time = Style.Text(bar, 20, "gold", nil, true)
    time:SetPoint("TOPRIGHT", -12, -8)
    time:SetJustifyH("RIGHT")

    track = CreateFrame("Frame", nil, bar)
    track:SetPoint("TOPLEFT", 12, -40)
    track:SetPoint("TOPRIGHT", -12, -40)
    track:SetHeight(6)
    Style.Fill(track, "line")
    fill = track:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT")
    fill:SetPoint("BOTTOMLEFT")
    fill:SetColorTexture(Style.Color("gold"))
    knob = track:CreateTexture(nil, "OVERLAY")
    knob:SetSize(2, 14)
    knob:SetColorTexture(Style.Color("text"))

    note = Style.Text(bar, 11, "muted")
    note:SetPoint("TOPLEFT", track, "BOTTOMLEFT", 0, -6)

    for _, key in ipairs(GAMES) do Tile(key) end
    if ns.Chess and ns.Chess.OnChange then
        ns.Chess.OnChange(function() if bar:IsShown() then PaintGames() end end)
    end

    -- A light refresh: the clock and the bar move a few times a second,
    -- the games' dots every couple of seconds.
    local wait, games = 0, 0
    bar:SetScript("OnUpdate", function(_, elapsed)
        wait, games = wait - elapsed, games - elapsed
        if wait > 0 then return end
        wait = 0.2
        if not Compat.OnTaxi() then return Flight.Land() end
        Paint()
        if games <= 0 then
            games = 2
            PaintGames()
        end
    end)
end

local function Show()
    if not bar then Build() end
    route:SetText(("|cff9a9688%s|r  ›  %s"):format(Short(current.from), Short(current.to)))
    PaintGames()
    Paint()
    bar:Show()
end

function Flight.Land()
    local flight = current
    current = nil
    ns.char.flight = nil
    if bar then bar:Hide() end
    if flight and not flight.early then
        LearnSpeed(flight, Compat.Now() - flight.start)
    end
end

local pending

local function Start(plan)
    pending = nil
    current = plan
    current.start = Compat.Now()
    if plan.yards then
        current.expected = plan.yards / (Speed() * plan.bonus) + plan.stops
    end
    -- Saved per character, so a /reload mid-flight picks the bar back up.
    ns.char.flight = current
    Show()
end

-- The flight starts a moment after the flight master's click. The game
-- says so the instant it takes the controls away (PLAYER_CONTROL_LOST,
-- below); this checks every tenth of a second too, for ten seconds, in
-- case that event comes first or not at all.
local function WaitForTakeoff(plan, tries)
    if pending ~= plan then return end
    if Compat.OnTaxi() then return Start(plan) end
    if tries < 100 then
        Compat.After(0.1, function() WaitForTakeoff(plan, tries + 1) end)
    else
        pending = nil
    end
end

local function OnTakeTaxi(slot)
    if not Flight.running then return end
    local nodes, here = Compat.TaxiNodes()
    local to = nodes[slot]
    if not to then return end
    local yards, stops = Legs(nodes, Compat.TaxiHops(slot))
    pending = {
        from = nodes[here] and nodes[here].name,
        to = to.name,
        yards = yards,
        stops = stops or 0,
        bonus = Compat.FlightSpeedBonus(),
    }
    WaitForTakeoff(pending, 1)
end

-- Games finished mid-flight show as done on the bar.
function Flight.Refresh()
    if bar and bar:IsShown() then PaintGames() end
end

local hooked = false
function Flight:OnEnable()
    if not hooked then
        hooked = true
        hooksecurefunc("TakeTaxiNode", ns.Safe(self, OnTakeTaxi))
        -- An early landing cuts the flight short, so it doesn't count
        -- toward the speed.
        hooksecurefunc("TaxiRequestEarlyLanding", ns.Safe(self, function()
            if current then current.early = true end
        end))
        -- Takeoff and landing to the moment: the game takes the controls
        -- away as the flight starts and hands them back as it lands.
        local events = CreateFrame("Frame")
        events:RegisterEvent("PLAYER_CONTROL_LOST")
        events:RegisterEvent("PLAYER_CONTROL_GAINED")
        events:SetScript("OnEvent", ns.Safe(self, function(_, event)
            if not Flight.running then return end
            if event == "PLAYER_CONTROL_LOST" and pending then
                Start(pending)
            elseif event == "PLAYER_CONTROL_GAINED" and current and not Compat.OnTaxi() then
                Flight.Land()
            end
        end))
    end
    -- Speeds measured before flights were timed to the moment are dropped.
    if ns.db.flightTiming ~= 2 then
        ns.db.flightSpeeds, ns.db.flightTiming = nil, 2
    end
    local saved = ns.char.flight
    if type(saved) == "table" and Compat.OnTaxi() and (saved.start or 0) <= Compat.Now() then
        current = saved
        Show()
    else
        ns.char.flight = nil
    end
end

function Flight:OnDisable()
    if bar then bar:Hide() end
end

ns.Flight = Flight
