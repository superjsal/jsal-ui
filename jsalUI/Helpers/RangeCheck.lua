-- Hunter range check: one small box, filled with the colour of where you stand
-- from an enemy you're targeting. White in melee range, red in the dead zone
-- (too close to shoot, too far to strike), green in shooting range, and a dim
-- grey too far. It shows only for hunters, only with a living enemy targeted.
-- It drags anywhere and resizes from its corner, from a small square to a long
-- bar, and has a 2px black edge like EllesmereUI's icons and bars.
--
-- The game gives addons no distance to an enemy, only whether a spell
-- reaches: a melee strike in range means melee, Auto Shot in range means
-- shooting, and when neither does, the game's follow and duel distances tell
-- the dead zone from too far. Where those checks aren't allowed (in a fight,
-- on some clients), the last reading decides: coming out of melee is the dead
-- zone.
local _, ns = ...
local Style, Compat = ns.Style, ns.Compat

local RangeCheck = ns.NewModule("rangecheck", {
    title = "Hunter range check",
    -- A new box on the screen, so it starts off.
    defaultOn = false,
    note = "A small box that shows, by its colour, where you stand from your target: white melee, red dead zone, green shooting, dim grey too far. Hunters only; drag it anywhere and resize it from its corner.",
    options = {
        { key = "sound", title = "Sound in the dead zone", default = false,
          note = "A short sound when you step into the dead zone." },
    },
})
ns.RangeCheck = RangeCheck

-- Raptor Strike isn't asked: on WoW Forever the game says it's in range at
-- any distance, so it can't tell melee apart.
local MELEE = { 2974, 1495 }   -- Wing Clip, Mongoose Bite
local RANGED = { 75, 3044 }          -- Auto Shot, Arcane Shot
local DUEL = 3                        -- the duel distance, about ten yards
local EVERY = 0.1

RangeCheck.COLORS = { melee = "text", dead = "red", shoot = "green", far = "lineStrong" }
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

-- Close enough that not shooting means too close, not too far. The duel
-- distance alone left a gap: on WoW Forever it's shorter than Auto Shot's
-- least range, so the box flickered grey between shooting and the dead zone.
-- The follow distance (about 28 yards) is well inside shooting range, so
-- out of shot but within it is always the dead zone.
local FOLLOW = 4
local function Near()
    if not CheckInteractDistance then return nil end
    local answered
    for _, index in ipairs({ FOLLOW, DUEL }) do
        local ok, r = pcall(CheckInteractDistance, "target", index)
        if ok then
            if r then return true end
            answered = true
        end
    end
    if answered then return false end
    return nil
end

-- Before a hunter learns Wing Clip, a five-yard item's range says whether
-- you're in melee: whether it would reach, not whether you carry it.
local MELEE_ITEM = 8149   -- Voodoo Charm
local function ItemReaches()
    local check = (C_Item and C_Item.IsItemInRange) or IsItemInRange
    if not check then return nil end
    local ok, r = pcall(check, MELEE_ITEM, "target")
    if not ok or r == nil then return nil end
    return r == true or r == 1
end

-- Where you stand: "melee", "dead", "shoot" or "far".
local last
function RangeCheck.Read()
    local melee = Reaches(MELEE)
    if melee == nil then melee = ItemReaches() end
    if melee then
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

-- Where it was dragged to and how big it was made, saved for the account; at
-- first a 26 square above the action bars.
local SIZE, MIN, MAX = 26, 8, 400
local function Place()
    box:ClearAllPoints()
    local at = ns.db and ns.db.rangeCheckAt
    if type(at) == "table" and at[1] then
        box:SetPoint(at[1], UIParent, at[2], at[3], at[4])
    else
        box:SetPoint("CENTER", UIParent, "CENTER", 0, -250)
    end
    local size = ns.db and ns.db.rangeCheckSize
    if type(size) == "table" and tonumber(size[1]) and tonumber(size[2]) then
        box:SetSize(size[1], size[2])
    else
        box:SetSize(SIZE, SIZE)
    end
end

local function Save()
    if not ns.db then return end
    local point, _, relative, x, y = box:GetPoint(1)
    ns.db.rangeCheckAt = { point, relative, x, y }
    ns.db.rangeCheckSize = { math.floor(box:GetWidth() + 0.5), math.floor(box:GetHeight() + 0.5) }
end

-- A 2px black edge, as EllesmereUI draws round its icons and bars, so the box
-- sits beside them as one of theirs.
local EDGE = 2
local function Edge()
    local px = (Compat.OnePixel and Compat.OnePixel(box) or 1) * EDGE
    for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
                            { "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false } }) do
        local t = box:CreateTexture(nil, "BORDER")
        t:SetColorTexture(0, 0, 0, 1)
        t:SetPoint(side[1])
        t:SetPoint(side[2])
        if side[3] then t:SetHeight(px) else t:SetWidth(px) end
    end
end

local function Build()
    box = CreateFrame("Frame", "jsalUIRangeCheck", UIParent)
    box:SetSize(SIZE, SIZE)
    box:SetFrameStrata("MEDIUM")
    box:SetClampedToScreen(true)
    box:SetMovable(true)
    box:SetResizable(true)
    if box.SetResizeBounds then box:SetResizeBounds(MIN, MIN, MAX, MAX)
    elseif box.SetMinResize then box:SetMinResize(MIN, MIN); box:SetMaxResize(MAX, MAX) end
    box:EnableMouse(true)
    box:RegisterForDrag("LeftButton")
    box.fill = box:CreateTexture(nil, "BACKGROUND")
    box.fill:SetAllPoints()
    Edge()
    box:SetScript("OnDragStart", function(self) self:StartMoving() end)
    box:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        Save()
    end)
    -- A corner to resize it by, shown while the pointer is on the box: a
    -- square, or a bar as long as the ones beside it.
    local grip = CreateFrame("Button", nil, box)
    grip:SetSize(10, 10)
    grip:SetPoint("BOTTOMRIGHT", 0, 0)
    grip:SetFrameLevel(box:GetFrameLevel() + 2)
    local mark = grip:CreateTexture(nil, "OVERLAY")
    mark:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    mark:SetAllPoints()
    grip:SetAlpha(0)
    grip:SetScript("OnMouseDown", function() box:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function()
        box:StopMovingOrSizing()
        Save()
    end)
    grip:SetScript("OnEnter", function() grip:SetAlpha(1) end)
    grip:SetScript("OnLeave", function() if not box:IsMouseOver() then grip:SetAlpha(0) end end)
    box.grip = grip
    box:SetScript("OnEnter", function(self)
        grip:SetAlpha(1)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(RangeCheck.WORDS[state] or "Range check")
        GameTooltip:AddLine("Drag to move; drag its corner to resize.", 0.6, 0.59, 0.53)
        GameTooltip:Show()
    end)
    box:SetScript("OnLeave", function()
        if not grip:IsMouseOver() then grip:SetAlpha(0) end
        GameTooltip:Hide()
    end)
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
    -- The game answers an item's range once it has the item loaded.
    if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, MELEE_ITEM) end
    if not box then Build() end
    Place()
    -- In EllesmereUI's Unlock Mode, with its grid and snapping, when it's on.
    if ns.Unlock then
        ns.Unlock.Add({
            key = "RangeCheck", label = "jsal.ui range check",
            frame = function() return box end,
            load = function() return ns.db and ns.db.rangeCheckAt end,
            save = function(point, relative, x, y)
                if not ns.db then return end
                ns.db.rangeCheckAt = point and { point, relative, x, y } or nil
                if not point then Place() end
            end,
        })
    end
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
