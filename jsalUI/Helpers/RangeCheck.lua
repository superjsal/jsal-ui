-- Hunter range check: one small box, filled with the colour of where you stand
-- from an enemy you're targeting. White in melee range, red in the dead zone
-- (too close to shoot, too far to strike), gold in shooting range, grey too
-- far. It shows only for hunters, only with a living enemy targeted, and drags
-- anywhere.
--
-- The game gives addons no distance to an enemy, only whether a spell
-- reaches: a melee strike in range means melee, Auto Shot in range means
-- shooting, and when neither does, the duel-distance check (about ten yards)
-- tells the dead zone from too far. Where that check isn't allowed (in a
-- fight, on some clients), the last reading decides: coming out of melee is
-- the dead zone.
local _, ns = ...
local Style, Compat = ns.Style, ns.Compat

local RangeCheck = ns.NewModule("rangecheck", {
    title = "Hunter range check",
    note = "A small box that shows, by its colour, where you stand from your target: white melee, red dead zone, gold shooting, grey too far. Hunters only; drag it anywhere.",
    options = {
        { key = "sound", title = "Sound in the dead zone", default = false,
          note = "A short sound when you step into the dead zone." },
    },
})
ns.RangeCheck = RangeCheck

local MELEE = { 2973, 2974, 1495 }   -- Raptor Strike, Wing Clip, Mongoose Bite
local RANGED = { 75, 3044 }          -- Auto Shot, Arcane Shot
local DUEL = 3                        -- the duel distance, about ten yards
local EVERY = 0.1

RangeCheck.COLORS = { melee = "text", dead = "red", shoot = "gold", far = "muted" }
RangeCheck.WORDS = {
    melee = "Melee range",
    dead = "Dead zone: step back to shoot",
    shoot = "Shooting range",
    far = "Too far",
}

local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    return GetSpellInfo and (GetSpellInfo(id)) or nil
end

-- Whether any of these spells reaches the target: true, false, or nil when
-- none of them can say (not learned, no ranged weapon).
local function Reaches(list)
    local check = (C_Spell and C_Spell.IsSpellInRange) or IsSpellInRange
    if not check then return nil end
    local answer
    for _, id in ipairs(list) do
        local name = SpellName(id)
        if name then
            local ok, r = pcall(check, name, "target")
            if ok and r ~= nil then
                if r == true or r == 1 then return true end
                answer = false
            end
        end
    end
    return answer
end

local function Near()
    if not CheckInteractDistance then return nil end
    local ok, r = pcall(CheckInteractDistance, "target", DUEL)
    if not ok then return nil end
    return r and true or false
end

-- Where you stand: "melee", "dead", "shoot" or "far".
local last
function RangeCheck.Read()
    if Reaches(MELEE) then
        last = "melee"
    elseif Reaches(RANGED) then
        last = "shoot"
    else
        local near = Near()
        if near == nil then near = (last == "melee" or last == "dead") end
        last = near and "dead" or "far"
    end
    return last
end

local function Wanted()
    return UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDead("target")
end

---------------------------------------------------------------------------
-- The box.
---------------------------------------------------------------------------
local box, state

local function Paint(new)
    if new == state then return end
    local before = state
    state = new
    box.fill:SetColorTexture(Style.Color(RangeCheck.COLORS[new]))
    if new == "dead" and before and before ~= "dead" and ns.OptionOn("rangecheck", "sound") and PlaySound then
        PlaySound(SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959, "Master")
    end
    if box:IsMouseOver() and GameTooltip:IsOwned(box) then box:GetScript("OnEnter")(box) end
end

local function Place()
    box:ClearAllPoints()
    local at = ns.db and ns.db.rangeCheckAt
    if type(at) == "table" and at[1] then
        box:SetPoint(at[1], UIParent, at[2], at[3], at[4])
    else
        box:SetPoint("CENTER", UIParent, "CENTER", 0, -250)
    end
end

local function Build()
    box = CreateFrame("Frame", "jsalUIRangeCheck", UIParent)
    box:SetSize(26, 26)
    box:SetFrameStrata("MEDIUM")
    box:SetClampedToScreen(true)
    box:SetMovable(true)
    box:EnableMouse(true)
    box:RegisterForDrag("LeftButton")
    Style.Fill(box, "window")
    Style.Border(box, "lineStrong")
    Style.Shadow(box, 8)
    box.fill = box:CreateTexture(nil, "ARTWORK")
    box.fill:SetPoint("TOPLEFT", 3, -3)
    box.fill:SetPoint("BOTTOMRIGHT", -3, 3)
    box:SetScript("OnDragStart", function(self) self:StartMoving() end)
    box:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relative, x, y = self:GetPoint(1)
        if ns.db then ns.db.rangeCheckAt = { point, relative, x, y } end
    end)
    box:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(RangeCheck.WORDS[state] or "Range check")
        GameTooltip:AddLine("Drag to move.", 0.6, 0.59, 0.53)
        GameTooltip:Show()
    end)
    box:SetScript("OnLeave", function() GameTooltip:Hide() end)
    box:Hide()
end

local wait = 0
local function Tick(_, elapsed)
    wait = wait + elapsed
    if wait < EVERY then return end
    wait = 0
    Paint(RangeCheck.Read())
end

-- Shown while a living enemy is targeted; read ten times a second meanwhile.
function RangeCheck.Update()
    if not box then return end
    if Wanted() then
        if not box:IsShown() then
            state, last = nil, nil
            Paint(RangeCheck.Read())
            box:Show()
        end
        box:SetScript("OnUpdate", ns.Safe(RangeCheck, Tick))
    else
        box:SetScript("OnUpdate", nil)
        box:Hide()
    end
end

function RangeCheck:OnEnable()
    local _, class = UnitClass("player")
    if class ~= "HUNTER" then return end
    if not box then Build() end
    Place()
    local events = self.events or CreateFrame("Frame")
    self.events = events
    events:RegisterEvent("PLAYER_TARGET_CHANGED")
    events:RegisterEvent("UNIT_HEALTH")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:SetScript("OnEvent", ns.Safe(self, function(_, event, unit)
        if event == "UNIT_HEALTH" and unit ~= "target" then return end
        RangeCheck.Update()
    end))
    RangeCheck.Update()
end

function RangeCheck:OnDisable()
    if self.events then self.events:UnregisterAllEvents() end
    if box then
        box:SetScript("OnUpdate", nil)
        box:Hide()
    end
end
