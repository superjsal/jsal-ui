-- The game's own talent window, marked: while it's open, the next talent in
-- the build you follow gets a pulsing gold frame, and its tooltip says so.
-- The frame is jsal.ui's own, attached to the game's button so it always
-- draws just above the icon; nothing of the game's window is changed, so
-- learning talents there works as always.
local _, ns = ...
local Style, Compat, Tree = ns.Style, ns.Compat, ns.TalentTree

local Glow = {}
ns.TalentGlow = Glow

local overlay, nextID, nextRank, nextMax
local hooked = setmetatable({}, { __mode = "k" })

-- Forever's talent window is the Talents tab of the game's spells window,
-- loaded the first time it opens.
local function TalentsFrame()
    return PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
end

local function Build()
    overlay = CreateFrame("Frame", nil, UIParent)
    overlay:EnableMouse(false)
    overlay:Hide()
    -- A 3px gold square just outside the icon.
    local OUT, THICK = 4, 3
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local t = overlay:CreateTexture(nil, "OVERLAY", nil, 7)
        t:SetColorTexture(Style.Color("gold"))
        if side == "TOP" or side == "BOTTOM" then
            local y = side == "TOP" and OUT or -OUT
            t:SetPoint(side .. "LEFT", -OUT, y)
            t:SetPoint(side .. "RIGHT", OUT, y)
            t:SetHeight(THICK)
        else
            local x = side == "LEFT" and -OUT or OUT
            t:SetPoint("TOP" .. side, x, OUT)
            t:SetPoint("BOTTOM" .. side, x, -OUT)
            t:SetWidth(THICK)
        end
    end
    -- A slow pulse, so it reads as "here" without shouting.
    local pulse = overlay:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local fade = pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0.35)
    fade:SetDuration(0.8)
    overlay.pulse = pulse
end

-- Adds a line to the marked talent's tooltip, after the game's own lines.
local function HookTooltip(button)
    if hooked[button] then return end
    hooked[button] = true
    button:HookScript("OnEnter", function(self)
        local id = self.GetNodeID and self:GetNodeID()
        if id and id == nextID and GameTooltip:IsOwned(self) then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(("Next in your jsal.ui plan: rank %d of %d"):format(nextRank, nextMax), 0.89, 0.69, 0.29)
            GameTooltip:Show()
        end
    end)
end

function Glow.Update()
    local frame = TalentsFrame()
    if overlay then overlay:Hide() end
    nextID = nil
    if not (ns.TalentHelper and ns.TalentHelper.running) then return end
    if not (frame and frame:IsVisible() and frame.GetTalentButtonByNodeID) then return end
    local data = Tree.Read()
    if not (data and data.configID) then return end
    local order = Tree.Replay(data, Tree.Active().order or {})
    local id, rank = Tree.Next(data, order)
    if not id then return end
    local button = frame:GetTalentButtonByNodeID(id)
    if not (button and button:IsVisible()) then return end
    nextID, nextRank, nextMax = id, rank, data.nodes[id].max
    if not overlay then Build() end
    overlay:SetParent(button)
    overlay:ClearAllPoints()
    overlay:SetAllPoints(button)
    overlay:SetFrameLevel(button:GetFrameLevel() + 10)
    overlay:Show()
    overlay.pulse:Play()
    HookTooltip(button)
end

-- The window's buttons are laid out a moment after it shows, so the mark
-- follows a beat later.
local function Soon()
    Compat.After(0.1, function() xpcall(Glow.Update, ns.Report) end)
end

local watching = false
local function Watch()
    local frame = TalentsFrame()
    if watching or not frame then return end
    watching = true
    frame:HookScript("OnShow", Soon)
    frame:HookScript("OnHide", function() if overlay then overlay:Hide() end end)
    if EventRegistry then
        EventRegistry:RegisterCallback("PlayerSpellsFrame.TalentTab.Show", Soon, Glow)
    end
end

function Glow.Start()
    Watch()
    local events = CreateFrame("Frame")
    events:RegisterEvent("ADDON_LOADED")
    events:SetScript("OnEvent", function(_, _, name)
        if name == "Blizzard_PlayerSpells" then Watch() end
    end)
    -- Learning a talent, here or in the game's window, moves the mark on.
    Tree.OnChange(Soon)
end
