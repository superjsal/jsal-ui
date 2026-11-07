-- Waypoints: a label over the game's own navigation marker (the blue diamond
-- that points at a map pin), naming where it leads and how far it is, for
-- pins jsal.ui sets (a trainer) and, with RestedXP Guides on, the guide's
-- next step, which the marker follows by itself as the guide moves on. At
-- the spot it says Arrived and clears itself; a click on the label clears
-- it too. A pin the player sets on the map is never replaced, and gets no
-- label.
local _, ns = ...
local Style, Compat = ns.Style, ns.Compat

local Waypoint = ns.NewModule("waypoint", {
    title = "Waypoint label",
    note = "A label over the game's navigation marker saying where it leads and how far, and your RestedXP guide's next step as the destination.",
    options = {
        { key = "guide", title = "Follow your RestedXP guide", default = true,
          note = "With RestedXP Guides on, the navigation marker points at the guide's next step and moves on with it. A pin you set yourself is kept." },
    },
})
ns.Waypoint = Waypoint

-- The pin jsal.ui set last: where, and what to call it.
local ours

local function Same(a, b)
    return a and b and a.map == b.map and math.abs(a.x - b.x) < 0.0005 and math.abs(a.y - b.y) < 0.0005
end

-- The game's pin now, as { map, x, y }, or nil.
local function Current()
    local point = C_Map and C_Map.GetUserWaypoint and C_Map.GetUserWaypoint()
    if not (point and point.position) then return nil end
    -- On Forever the position is a plain pair of numbers, not always one
    -- with a GetXY of its own.
    local pos = point.position
    local x, y
    if type(pos.GetXY) == "function" then x, y = pos:GetXY() else x, y = pos.x, pos.y end
    if not (x and y) then return nil end
    return { map = point.uiMapID, x = x, y = y }
end

-- Whether the pin on the map is one jsal.ui set (or there's none), so it may
-- be moved.
local function Ours()
    local now = Current()
    return not now or Same(now, ours)
end

-- Within this many yards you've arrived; the pin goes after a few seconds
-- there, or at once when its label is clicked.
local ARRIVED, LINGER = 10, 3
local arrivedAt, cleared

-- Sets the game's pin and its label; false when the map takes no pins.
function Waypoint.Set(map, x, y, label, source)
    if not Compat.SetWaypoint(map, x, y) then return false end
    ours = { map = map, x = x, y = y, label = label, source = source }
    arrivedAt, cleared = nil, nil
    return true
end

-- Takes jsal.ui's pin away; a guide spot cleared isn't set again until the
-- guide moves on.
function Waypoint.Clear()
    if not ours then return end
    if Ours() and C_Map and C_Map.ClearUserWaypoint then C_Map.ClearUserWaypoint() end
    cleared = { map = ours.map, x = ours.x, y = ours.y }
    ours, arrivedAt = nil, nil
end

---------------------------------------------------------------------------
-- RestedXP Guides: the first unfinished spot of its current steps.
---------------------------------------------------------------------------
function Waypoint.GuideTarget()
    local rxp = RXP
    local steps = rxp and rxp.RXPFrame and rxp.RXPFrame.activeSteps
    if type(steps) ~= "table" then return nil end
    for _, step in ipairs(steps) do
        for _, element in ipairs(type(step) == "table" and step.elements or {}) do
            if type(element) == "table" and element.zone and element.x and element.y
                and not element.completed and not element.skip then
                return tonumber(element.zone), element.x / 100, element.y / 100
            end
        end
    end
end

local function FollowGuide()
    if not (Waypoint.running and ns.OptionOn("waypoint", "guide")) then return end
    local map, x, y = Waypoint.GuideTarget()
    if not map then
        -- The guide has nowhere to go: its old pin goes too.
        if ours and ours.source == "guide" and Ours() and C_Map.ClearUserWaypoint then
            C_Map.ClearUserWaypoint()
            ours = nil
        end
        return
    end
    if not Ours() then return end
    local spot = { map = map, x = x, y = y }
    -- Already there, unless the game took the pin away itself (a loading
    -- screen can): then it's put back.
    if ours and ours.source == "guide" and Same(ours, spot) and Same(Current(), ours) then return end
    if Same(cleared, spot) then return end
    Waypoint.Set(map, x, y, "Guide destination", "guide")
end
Waypoint.FollowGuide = FollowGuide

---------------------------------------------------------------------------
-- The label, kept just above the game's marker while it shows our pin.
---------------------------------------------------------------------------
local box, title, distance, pointer

local function Build()
    box = CreateFrame("Frame", nil, UIParent)
    box:SetSize(150, 38)
    box:SetFrameStrata("LOW")
    Style.Fill(box, "window")
    Style.Border(box, "lineStrong")
    title = Style.Text(box, 12, "text", nil, true)
    title:SetPoint("TOP", 0, -5)
    distance = Style.Text(box, 13, "gold", nil, true)
    distance:SetPoint("TOP", title, "BOTTOM", 0, -2)
    -- Clicking the label clears the pin.
    box:EnableMouse(true)
    box:SetScript("OnMouseUp", function() Waypoint.Clear() end)
    box:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Click to clear this waypoint")
        GameTooltip:Show()
    end)
    box:SetScript("OnLeave", function() GameTooltip:Hide() end)
    box:Hide()
    -- jsal.ui's own pointer: a gold diamond with a dark edge, exactly where
    -- the game's marker points (at the screen's edge when the spot is
    -- behind you), since the game's own diamond may be hidden.
    pointer = CreateFrame("Frame", nil, UIParent)
    pointer:SetSize(18, 18)
    pointer:SetFrameStrata("LOW")
    local edge = pointer:CreateTexture(nil, "ARTWORK")
    edge:SetSize(14, 14)
    edge:SetPoint("CENTER")
    edge:SetColorTexture(Style.Color("onGold"))
    edge:SetRotation(math.rad(45))
    local gem = pointer:CreateTexture(nil, "OVERLAY")
    gem:SetSize(9, 9)
    gem:SetPoint("CENTER")
    gem:SetColorTexture(Style.Color("gold"))
    gem:SetRotation(math.rad(45))
    pointer:Hide()
end

local function Paint()
    local frame = C_Navigation and C_Navigation.GetFrame and C_Navigation.GetFrame()
    local tracking = C_SuperTrack and C_SuperTrack.IsSuperTrackingUserWaypoint and C_SuperTrack.IsSuperTrackingUserWaypoint()
    local show = frame and frame:IsVisible() and tracking and ours and Same(Current(), ours)
    if not show then
        box:Hide()
        pointer:Hide()
        return
    end
    title:SetText(ours.label or "Waypoint")
    local yards = C_Navigation.GetDistance and C_Navigation.GetDistance()
    if yards and yards <= ARRIVED then
        distance:SetText("Arrived")
        arrivedAt = arrivedAt or GetTime()
        if GetTime() - arrivedAt >= LINGER then
            Waypoint.Clear()
            box:Hide()
            pointer:Hide()
            return
        end
    else
        arrivedAt = nil
        distance:SetText(yards and ("%d yd"):format(math.floor(yards)) or "")
    end
    box:SetWidth(math.max(110, title:GetStringWidth() + 24))
    pointer:ClearAllPoints()
    pointer:SetPoint("CENTER", frame, "CENTER", 0, 0)
    pointer:Show()
    box:ClearAllPoints()
    box:SetPoint("BOTTOM", pointer, "TOP", 0, 4)
    box:Show()
end

function Waypoint:OnEnable()
    if not box then Build() end
    local paint, follow = 0, 0
    box:SetScript("OnUpdate", nil)
    local driver = self.driver or CreateFrame("Frame")
    self.driver = driver
    -- The label every tenth of a second; the guide every two.
    driver:SetScript("OnUpdate", ns.Safe(self, function(_, elapsed)
        paint, follow = paint + elapsed, follow + elapsed
        if paint >= 0.1 then
            paint = 0
            Paint()
        end
        if follow >= 2 then
            follow = 0
            FollowGuide()
        end
    end))
end

---------------------------------------------------------------------------
-- /jsal waypoint: why the label is or isn't showing, for a bug report.
---------------------------------------------------------------------------
local function Spot(s)
    return s and ("%s %.1f, %.1f"):format(tostring(s.map), s.x * 100, s.y * 100) or "none"
end

function Waypoint.Status()
    local lines = {}
    local function Add(text) lines[#lines + 1] = text end
    Add(("Waypoint label: %s; follow the guide: %s"):format(Waypoint.running and "on" or "off",
        ns.OptionOn("waypoint", "guide") and "on" or "off"))
    local map, x, y = Waypoint.GuideTarget()
    local guide = map and { map = map, x = x, y = y }
    Add("RestedXP's next spot: " .. (RXP and Spot(guide) or "RestedXP isn't running"))
    if guide and C_Map and C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(map) then
        Add("That map takes no pins, so there's nothing to point at.")
    end
    if guide and Same(cleared, guide) then Add("You cleared or reached that spot; the next step brings a new one.") end
    local now = Current()
    Add("The map's pin: " .. Spot(now) .. (now and (Same(now, ours) and " (jsal.ui's)" or " (set by you or another addon, so it's left alone)") or ""))
    local tracking = C_SuperTrack and C_SuperTrack.IsSuperTrackingUserWaypoint and C_SuperTrack.IsSuperTrackingUserWaypoint()
    Add("The game is tracking it: " .. (tracking and "yes" or "no"))
    local frame = C_Navigation and C_Navigation.GetFrame and C_Navigation.GetFrame()
    local yards = C_Navigation and C_Navigation.GetDistance and C_Navigation.GetDistance()
    Add(("The game's marker: %s%s"):format(frame and (frame:IsVisible() and "showing" or "hidden") or "none",
        yards and ("; %d yd away"):format(math.floor(yards)) or ""))
    return lines
end

ns.Command("waypoint", function()
    for _, line in ipairs(Waypoint.Status()) do ns.Print(line) end
end)

function Waypoint:OnDisable()
    if self.driver then self.driver:SetScript("OnUpdate", nil) end
    if box then box:Hide() end
end
