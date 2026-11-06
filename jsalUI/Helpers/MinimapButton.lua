-- The minimap button: a click opens or closes the dashboard, and dragging
-- moves it around the minimap's edge. It's a plain named button on the
-- minimap with the game's round border, the kind minimap button drawers
-- (EllesmereUI's Addon Buttons) gather up and show with just its icon;
-- without one, it sits on the minimap's rim where it was left.
local addonName, ns = ...

local MinimapButton = ns.NewModule("minimap", {
    title = "Minimap button",
    note = "A button that opens the dashboard, on the minimap or in EllesmereUI's Addon Buttons.",
})

local ANGLE = 200    -- where it starts: the lower left of the rim, in degrees
local OUTSIDE = 10   -- how far past the rim its centre sits
local button

local function Place()
    local angle = math.rad(ns.db.minimapAngle or ANGLE)
    local r = Minimap:GetWidth() / 2 + OUTSIDE
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

-- While dragged, the button follows the cursor's angle from the minimap's
-- centre, staying on the rim.
local function Follow()
    local mx, my = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    ns.db.minimapAngle = math.deg(math.atan2(cy / scale - my, cx / scale - mx)) % 360
    Place()
end

local function Build()
    button = CreateFrame("Button", "jsalUIMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("AnyUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetSize(20, 20)
    background:SetPoint("TOPLEFT", 7, -5)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetTexture("Interface\\AddOns\\" .. addonName .. "\\Media\\Logo")
    button.icon:SetSize(18, 18)
    button.icon:SetPoint("TOPLEFT", 7, -6)
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")

    -- A right-click lists jsal.ui's places: the games, chess and the rest.
    button:SetScript("OnClick", function(self, mouse)
        if mouse == "RightButton" and ns.Launcher then
            ns.Launcher.PlacesMenu(self)
        else
            ns.Window.Toggle()
        end
    end)
    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", Follow)
        GameTooltip:Hide()
    end)
    button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(ns.title)
        GameTooltip:AddLine("Click to open the dashboard.", 1, 1, 1)
        GameTooltip:AddLine("Right-click for the games, chess and more.", 1, 1, 1)
        GameTooltip:AddLine("Drag to move it around the minimap.", 0.6, 0.59, 0.53)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    Place()
end

-- Made as soon as jsal.ui has loaded, not at login: drawers look for new
-- buttons each time an addon finishes loading, and this way the next look
-- finds it.
ns.OnLoad(function()
    if Minimap and ns.ModuleWanted(MinimapButton) then Build() end
end)

function MinimapButton:OnEnable()
    if not Minimap then return end
    if not button then Build() end
    button:Show()
end

function MinimapButton:OnDisable()
    if button then button:Hide() end
end
