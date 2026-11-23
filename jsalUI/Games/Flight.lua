-- The flight bar: while you fly, the route, the time left and today's games.
-- The game doesn't tell addons how long a flight takes, but its own flight
-- tables give each path's length (FlightData.lua). A flight's time is the
-- length of its legs over the flight speed, plus any stops along the way;
-- at a flight point passed through, less the approach and climb not flown.
-- A route flown before is timed by how long it took then. The flight map's
-- tooltip says the same time for a place before you take off.
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

-- Only a flight of one leg teaches the speed: how a flight through other points
-- is joined is fitted, not measured.
local function LearnSpeed(flight, seconds)
    local flying = seconds - (flight.stops or 0)
    if not flight.yards or flight.legs ~= 1 or flying <= 0 then return end
    local speed = flight.yards / flying / (flight.bonus or 1)
    if math.abs(speed - BASE_SPEED) / BASE_SPEED > TRUST then return end
    local list = type(ns.db.flightSpeeds) == "table" and ns.db.flightSpeeds or {}
    list[#list + 1] = speed
    while #list > KEEP do table.remove(list, 1) end
    ns.db.flightSpeeds = list
end

-- How long routes took when flown, account-wide: by faction and the chain of
-- flight points flown (from, each point passed, to), the flying part's tenths
-- of a second at normal speed, stops apart. A route is kept only from a whole
-- flight that landed where it was going, close to its worked-out time: a
-- flight-speed bonus the bar doesn't see is a sixth off, which is outside it.
-- Two flights of a route within a couple of seconds are averaged; further
-- apart, the shorter stands, as a landing can be noticed late but never early.
-- Guildmates' times are kept apart, and used for a route only until it's
-- flown here.
local KEPT_MOST, KEY_MOST = 300, 40   -- routes kept; the longest key kept
local NEAR, AGREE = 0.12, 2           -- how far off the worked-out time; seconds apart that agree
local LANDED_NEAR = 40                -- yards from its flight point a landing comes down within

-- "A43.6.2.19": the faction's first letter and the flight points' node IDs.
-- Nil when a point has no ID or the hops don't follow on from each other.
local function RouteKey(nodes, hops)
    -- The game's side, never a pretended one: the key is kept and shared with the guild.
    local faction = Compat.Faction(true)
    local first = hops[1] and nodes[hops[1][1]]
    if type(faction) ~= "string" or not (first and first.id) then return nil end
    local ids = { first.id }
    for i, hop in ipairs(hops) do
        local to = nodes[hop[2]]
        if not (to and to.id) or (i > 1 and hop[1] ~= hops[i - 1][2]) then return nil end
        ids[#ids + 1] = to.id
    end
    local key = faction:sub(1, 1) .. table.concat(ids, ".")
    return #key <= KEY_MOST and key or nil
end

local function Routes(part)
    local t = ns.db.flightTimes
    return type(t) == "table" and type(t[part]) == "table" and t[part] or nil
end

local function Tenths(part, key)
    local list = Routes(part)
    local tenths = list and list[key]
    return type(tenths) == "number" and tenths > 0 and tenths or nil
end

-- A kept route's flying seconds at normal speed, this account's own or else a
-- guildmate's, while it's still close to what its legs work out at, and whose
-- it is ("own" or "heard").
local function Kept(key, yards)
    if not (key and yards) then return nil end
    local whose, tenths = "own", Tenths("own", key)
    if not tenths then whose, tenths = "heard", Tenths("heard", key) end
    if not tenths then return nil end
    local seconds, worked = tenths / 10, yards / Speed()
    if math.abs(seconds - worked) / worked > NEAR then return nil end
    return seconds, whose
end

-- Whether a flight came down by its own flight point: where the character
-- stands in the world against where the game's tables put that point. Every
-- path to a flight point ends within 15 yards of it; a summon or a teleport
-- puts the character somewhere else. A point not in the tables, or a position
-- the game can't give, doesn't stand in the way.
local function Arrived(flight)
    local spot = ns.FlightPoints and ns.FlightPoints[flight.dest]
    if type(spot) ~= "table" then return true end
    local x, y, continent = Compat.WorldPosition()
    if not (x and y) then return true end
    if continent ~= nil and continent ~= spot[3] then return false end
    -- The game's two horizontal coordinates are matched to the tables' both ways round, as nothing
    -- here can confirm their order; only a spot within reach of the point's mirror image could pass
    -- by mistake, and no summon or teleport lands there.
    local near = LANDED_NEAR ^ 2
    return (x - spot[1]) ^ 2 + (y - spot[2]) ^ 2 <= near or (y - spot[1]) ^ 2 + (x - spot[2]) ^ 2 <= near
end

-- Puts a route's flying seconds into the account's own times or the ones
-- heard, settled against what's there already. False when it's too far off
-- what the legs work out at.
local function Settle(part, key, flying, yards)
    local worked = yards / Speed()
    if flying <= 0 or math.abs(flying - worked) / worked > NEAR then return false end
    local t = type(ns.db.flightTimes) == "table" and ns.db.flightTimes or {}
    local list = type(t[part]) == "table" and t[part] or {}
    local before = type(list[key]) == "number" and list[key] / 10 or nil
    if before then
        flying = math.abs(flying - before) <= AGREE and (flying + before) / 2 or math.min(flying, before)
    else
        local count = 0
        for _ in pairs(list) do count = count + 1 end
        if count >= KEPT_MOST then list[next(list)] = nil end
    end
    list[key] = math.floor(flying * 10 + 0.5)
    t[part] = list
    ns.db.flightTimes = t
    return true
end

local function KeepTime(flight, seconds)
    if not (flight.key and flight.yards) or Compat.Dead() or not Arrived(flight) then return end
    local flying = (seconds - (flight.stops or 0)) * (flight.bonus or 1)
    if Settle("own", flight.key, flying, flight.yards) then ns.db.flightTimes.last = flight.key end
end

-- A leg's path in the game's tables, and the yards its end saves when the
-- flight goes on through it to the next leg's point instead of landing (the
-- join's third part, by that point; none when it lands there).
local function Leg(nodes, hops, i)
    local from, to = nodes[hops[i][1]], nodes[hops[i][2]]
    local path = from and to and from.id and to.id and ns.FlightPaths[from.id * 10000 + to.id]
    if not path then return nil, 0 end
    local after = hops[i + 1] and nodes[hops[i + 1][2]]
    local saves = after and after.id and type(path[3]) == "table" and path[3][after.id] or 0
    return path, saves
end

-- Yards and stop seconds for a flight, leg by leg, or nil when a leg isn't
-- in the game's tables.
local function Legs(nodes, hops)
    local yards, stops = 0, 0
    for i = 1, #hops do
        local path, saves = Leg(nodes, hops, i)
        if not path then return nil end
        yards, stops = yards + path[1] - saves, stops + path[2]
    end
    if #hops == 0 then return nil end
    return yards, stops
end

-- The flight points a flight passes before its last: each one's name, the
-- yards and stop seconds flown by the time it's reached when landing there
-- (the leg flown whole to the perch), and how many yards before that the
-- flight leaves its path when it goes on, after which it's too late to ask
-- (half what passing through saves). No yards when a leg isn't in the tables.
local function Via(nodes, hops)
    local list, yards, stops = {}, 0, 0
    for i = 1, #hops - 1 do
        local to = nodes[hops[i][2]]
        local path, saves = Leg(nodes, hops, i)
        local reached = path and yards and (yards + path[1]) or nil
        list[i] = { name = to and to.name, yards = reached, stops = stops, leaves = saves / 2 }
        yards = reached and (reached - saves) or nil
        stops = stops + (path and path[2] or 0)
    end
    return list
end

-- The next flight point a flight can still land at: true, its name and
-- the seconds into the flight it's reached. One a couple of seconds away
-- is too late to ask for. With a leg missing from the tables there's no
-- telling which point is next, so it has no name and no time.
local LAND_NOTICE = 2
local function NextStop(flight, elapsed)
    if type(flight.via) ~= "table" then return false end
    local speed = (flight.speed or Speed()) * (flight.bonus or 1)
    for _, stop in ipairs(flight.via) do
        if not stop.yards then return true end
        local at = stop.yards / speed + stop.stops
        if at - (stop.leaves or 0) / speed > elapsed + LAND_NOTICE then return true, stop.name, at end
    end
    return false
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
local bar, route, time, track, fill, knob, note, land
local current

-- Just after the game loads it can be a moment before it says the character is
-- flying. For that long a flight saved before a /reload is still looked for, and
-- once it's back on the bar a "not flying" doesn't take it down.
local SETTLE = 10
local loaded
local function Settling()
    return loaded ~= nil and current ~= nil and current.resumed == true and Compat.Now() - loaded < SETTLE
end

-- Today's games, Pal run and chess, as the quick buttons' icons: a gold dot
-- when one is waiting (today's puzzle or course not played, your move), a
-- tooltip saying what. Parts that are switched off leave no gap.
local GAMES, TILE = { "word", "icons", "run", "chess" }, 32
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

local function PaintRoute()
    route:SetText(("|cff9a9688%s|r  ›  %s"):format(Short(current.from), Short(current.to)))
end

local function Paint()
    if not current then return end
    local elapsed = Compat.Now() - current.start
    local trackWidth = track:GetWidth()
    -- Land at the next flight point: there while one is still ahead.
    local ahead, stop = false, nil
    if not current.early then ahead, stop = NextStop(current, elapsed) end
    if ahead then
        land.label:SetText(stop and ("Land at " .. Short(stop)) or "Land at the next stop")
        land:SetWidth(math.max(60, land.label:GetStringWidth() + 18))
    end
    land:SetShown(ahead)
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
        note:SetText(left <= 0 and "Landing any moment" or current.early and "Landing early"
            or (Clock(current.expected) .. " in all"))
    else
        -- A route the tables don't have: count up instead.
        time:SetText(Clock(elapsed))
        time:SetTextColor(Style.Color("text"))
        fill:Hide()
        knob:Hide()
        note:SetText(current.early and "Landing at the next stop" or "This route isn't in the game's flight tables yet")
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
    Style.Shadow(bar)

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

    note = Style.Text(bar, 12, "muted")
    note:SetPoint("TOPLEFT", track, "BOTTOMLEFT", 0, -6)

    -- Land at the next flight point, on the note's line: a flight with
    -- stops can be cut short at the next one.
    land = CreateFrame("Button", nil, bar)
    land:SetSize(120, 20)
    land:SetPoint("TOPRIGHT", track, "BOTTOMRIGHT", 0, -4)
    Style.Fill(land, "well")
    land.edges = Style.Border(land, "lineStrong")
    land.label = Style.Text(land, 12, "gold")
    land.label:SetPoint("CENTER")
    land:SetScript("OnEnter", function(self)
        Style.SetBorder(self.edges, "gold")
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Land at the next flight point")
        GameTooltip:AddLine("The rest of the flight isn't refunded.", 0.6, 0.59, 0.53)
        GameTooltip:Show()
    end)
    land:SetScript("OnLeave", function(self)
        Style.SetBorder(self.edges, "lineStrong")
        GameTooltip:Hide()
    end)
    land:SetScript("OnClick", ns.Safe(Flight, function()
        if current and not current.early then TaxiRequestEarlyLanding() end
    end))
    land:Hide()

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
        if not Compat.OnTaxi() then
            if Settling() then return end
            return Flight.Land()
        end
        Paint()
        if games <= 0 then
            games = 2
            PaintGames()
        end
    end)
end

-- The game's own button for landing early (its vehicle exit button) does what
-- the bar's does, so it's out of sight while the bar shows and back after.
-- Edit Mode can't hide it. Faded and unclickable rather than hidden, as the
-- game shows it again by itself; only put back if it was this that faded it.
local exitFaded, exitWanted = false, false
local function GameExit(hide)
    exitWanted = hide
    local button = MainMenuBarVehicleLeaveButton
    if not button or hide == exitFaded then return end
    -- It can't be touched in a fight: done once the fight is over, as things stand then. Left
    -- at that, a flight that ended in a fight kept the button unseen and unclickable until the
    -- next flight.
    if InCombatLockdown and InCombatLockdown() then
        ns.AfterCombat(function() GameExit(exitWanted) end)
        return
    end
    button:SetAlpha(hide and 0 or 1)
    button:EnableMouse(not hide)
    exitFaded = hide
end

local function Show()
    if not bar then Build() end
    PaintRoute()
    PaintGames()
    Paint()
    bar:Show()
    GameExit(true)
end

function Flight.Land()
    local flight = current
    current = nil
    ns.char.flight = nil
    if bar then bar:Hide() end
    GameExit(false)
    -- One picked back up after a /reload doesn't count either: its landing may have been
    -- noticed late.
    if flight and not flight.early and not flight.resumed then
        local seconds = Compat.Now() - flight.start
        LearnSpeed(flight, seconds)
        KeepTime(flight, seconds)
    end
end

-- A flight from here to a slot on the flight master's map: its route, its
-- legs' yards and stops, the flight-speed bonus, the route's key and where it
-- comes down. Nil for a slot that isn't on the map.
local function Plan(slot)
    local nodes, here = Compat.TaxiNodes()
    local to = nodes[slot]
    if not to then return nil end
    local hops = Compat.TaxiHops(slot)
    local yards, stops = Legs(nodes, hops)
    return {
        via = Via(nodes, hops),
        from = nodes[here] and nodes[here].name,
        to = to.name,
        yards = yards,
        stops = stops or 0,
        legs = #hops,
        bonus = Compat.FlightSpeedBonus(),
        key = RouteKey(nodes, hops),
        dest = to.id,
    }
end

-- How long a plan's flight takes in all, in seconds, and whose flight that
-- comes from ("own", "heard", or nil when it's worked out from the legs); nil
-- when a leg isn't in the game's tables. The one way a flight is timed: the
-- bar at take-off and the flight map's tooltip both ask here. A route flown
-- before goes at the speed that took the time kept for it, so the points
-- passed keep their share of it.
local function Price(plan)
    if not plan.yards then return nil end
    local kept, whose = Kept(plan.key, plan.yards)
    plan.speed = kept and plan.yards / kept or nil
    plan.expected = plan.yards / ((plan.speed or Speed()) * plan.bonus) + plan.stops
    return plan.expected, kept and whose or nil
end

local pending

local function Start(plan)
    pending = nil
    current = plan
    current.start = Compat.Now()
    Price(plan)
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
    local plan = Plan(slot)
    if not plan then return end
    pending = plan
    WaitForTakeoff(pending, 1)
end

-- Pointing at a place on the flight map you can fly to: the game's tooltip
-- (its name and the fare) gets jsal.ui's section under it, with the time the
-- bar would say the flight takes in all if you took it now. Nothing on where
-- you stand, a place you can't reach from here, or a route with a leg the
-- tables don't have. The game builds the tooltip afresh each time the pointer
-- comes onto a place, so the lines go on once a showing; a second call on a
-- tooltip that already has them leaves it be.
local FLOWN = { own = " · as you flew it", heard = " · as a guildmate flew it" }
local tipped = {}   -- the place last added to, and the tooltip's lines after
local function OnNodeEnter(button)
    if not (Flight.running and button and button.GetID and GameTooltip:IsOwned(button)) then return end
    if tipped[1] == button and tipped[2] == GameTooltip:NumLines() then return end
    local slot = button:GetID()
    if TaxiNodeGetType(slot) ~= "REACHABLE" then return end
    local plan = Plan(slot)
    if not plan then return end
    local inAll, whose = Price(plan)
    if not inAll then return end
    local mr, mg, mb = Style.Color("muted")
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(Style.MARK .. " jsal.ui", mr, mg, mb)
    GameTooltip:AddLine("Flight time " .. Clock(inAll) .. (FLOWN[whose] or ""), 1, 1, 1)
    GameTooltip:Show()
    tipped[1], tipped[2] = button, GameTooltip:NumLines()
end

-- The route this account flew last and its time, as "A43.6.2.19=6594", for
-- the guild message that tells guildmates how today's games went; "" when
-- there's none. Only this account's own flights, at normal speed.
function Flight.Shared()
    local t = ns.db.flightTimes
    local key = type(t) == "table" and t.last
    local tenths = type(key) == "string" and Tenths("own", key)
    return tenths and (key .. "=" .. tenths) or ""
end

-- A guildmate's route and time, as Shared gives it: kept for a route this
-- account hasn't flown, of its own faction, close to what its legs work out at.
function Flight.Heard(text)
    text = Compat.Plain(text)
    if not Flight.running or type(text) ~= "string" or #text > KEY_MOST + 8 then return end
    local key, tenths = text:match("^(%u[%d%.]+)=(%d+)$")
    local faction = Compat.Faction(true)
    if not key or type(faction) ~= "string" or key:sub(1, 1) ~= faction:sub(1, 1) or Tenths("own", key) then return end
    local nodes, hops = {}, {}
    for id in key:sub(2):gmatch("[^%.]+") do
        nodes[#nodes + 1] = { id = tonumber(id) }
        if #nodes > 1 then hops[#hops + 1] = { #nodes - 1, #nodes } end
    end
    if RouteKey(nodes, hops) ~= key then return end
    local yards = Legs(nodes, hops)
    if yards then Settle("heard", key, tonumber(tenths) / 10, yards) end
end

-- Games finished mid-flight show as done on the bar.
function Flight.Refresh()
    if bar and bar:IsShown() then PaintGames() end
end

-- A flight saved before a /reload: back on the bar as soon as the game says the
-- character is flying, looked for twice a second while the game settles, and
-- forgotten if it never does. A new flight started meanwhile takes its place.
local function Resume(saved, tries)
    -- The first look is as the part starts, before it's marked as running.
    if current or ns.char.flight ~= saved or (tries > 1 and not Flight.running) then return end
    if Compat.OnTaxi() then
        current = saved
        current.resumed = true
        return Show()
    end
    if tries < SETTLE * 2 then
        Compat.After(0.5, function() Resume(saved, tries + 1) end)
    else
        ns.char.flight = nil
    end
end

local hooked = false
function Flight:OnEnable()
    if not hooked then
        hooked = true
        hooksecurefunc("TakeTaxiNode", ns.Safe(self, OnTakeTaxi))
        -- The flight map's places are the game's taxi buttons, whose tooltip is
        -- filled by this function on the pointer coming onto one.
        hooksecurefunc("TaxiNodeOnButtonEnter", ns.Safe(self, OnNodeEnter))
        -- An early landing cuts the flight short, so it doesn't count
        -- toward the speed, and the bar counts down to the flight point
        -- it lands at instead. Asked for from any addon's button or the
        -- game's own, not only this bar's.
        hooksecurefunc("TaxiRequestEarlyLanding", ns.Safe(self, function()
            if not current or current.early then return end
            local ahead, stop, at = NextStop(current, Compat.Now() - current.start)
            current.early = true
            if ahead then
                current.to, current.expected = stop or current.to, at
            end
            if bar and bar:IsShown() then
                PaintRoute()
                Paint()
            end
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
            elseif event == "PLAYER_CONTROL_GAINED" and current and not Compat.OnTaxi() and not Settling() then
                Flight.Land()
            end
        end))
    end
    -- Speeds measured before flights were timed to the moment, and before a
    -- flight through other points stopped teaching the speed, are dropped once.
    if ns.db.flightTiming ~= 3 then
        ns.db.flightSpeeds, ns.db.flightTiming = nil, 3
    end
    loaded = Compat.Now()
    local saved = ns.char.flight
    if type(saved) == "table" and (saved.start or 0) <= Compat.Now() then
        Resume(saved, 1)
    else
        ns.char.flight = nil
    end
end

function Flight:OnDisable()
    if bar then bar:Hide() end
    GameExit(false)
end

ns.Flight = Flight
