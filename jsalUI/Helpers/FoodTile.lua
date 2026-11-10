-- Food reminder: a small glowing tile that shows while you aren't Well Fed,
-- out of a fight. Pointing at it opens a row of the food in your bags right
-- under it, centred, buff food first; point at one for the game's own
-- tooltip, click one to eat it.
--
-- Eating is an item use, which the game only allows from its own secure
-- buttons, and those can't be shown, hidden or changed in a fight. So the
-- tile and its row hide as a fight starts and come back once it ends (you
-- can't eat in a fight anyway).
local _, ns = ...
local Style, Compat = ns.Style, ns.Compat

local FoodTile = ns.NewModule("foodtile", {
    title = "Food reminder",
    -- A new box on the screen, so it starts off.
    defaultOn = false,
    note = "A glowing tile while you aren't Well Fed. Point at it for the food in your bags, buff food first, and click one to eat it. Drag it anywhere.",
})
ns.FoodTile = FoodTile

local SIZE, ITEM, GAP, MAX = 36, 32, 4, 10
-- The Well Fed buff wears this icon whatever food gave it; a few buff foods
-- name their buff differently.
local WELL_FED_ICON = 136000
local OTHER_BUFFS = { [18192] = true, [18194] = true, [22730] = true, [25661] = true, [18125] = true, [18141] = true }
local FOOD_CLASS, FOOD_SUBCLASS = 0, 5

---------------------------------------------------------------------------
-- What you're wearing and what you carry.
---------------------------------------------------------------------------

-- Your buffs: whether one is Well Fed, and whether you're eating right now
-- (the buff comes after ten seconds of it, so the tile waits).
function FoodTile.Buffs()
    local fed, eating = false, false
    local get = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
    for i = 1, 40 do
        local name, icon, spell
        if get then
            local ok, aura = pcall(get, "player", i, "HELPFUL")
            if not ok or not aura then break end
            name, icon, spell = aura.name, aura.icon, aura.spellId
        elseif UnitBuff then
            local n, ic, _, _, _, _, _, _, _, id = UnitBuff("player", i)
            if not n then break end
            name, icon, spell = n, ic, id
        else
            break
        end
        if icon == WELL_FED_ICON or name == "Well Fed" or OTHER_BUFFS[spell] then fed = true end
        if name == "Food" or name == "Refreshment" or name == "Food & Drink" then eating = true end
    end
    return fed, eating
end

-- Whether an item gives Well Fed, read once from its tooltip and kept.
local buffFood = {}
local function GivesBuff(itemID)
    if buffFood[itemID] ~= nil then return buffFood[itemID] end
    local get = C_TooltipInfo and C_TooltipInfo.GetItemByID
    if not get then return false end
    local ok, data = pcall(get, itemID)
    if not ok or not data or not data.lines or #data.lines < 2 then return false end
    local found = false
    for _, line in ipairs(data.lines) do
        local text = line.leftText
        if type(text) == "string" and text:lower():find("well fed", 1, true) then found = true break end
    end
    buffFood[itemID] = found
    return found
end
FoodTile.GivesBuff = GivesBuff

-- Food, not drink: a Food & Drink item whose use is eating. Drinks only
-- restore mana, so they aren't offered unless they also feed you.
local function IsFood(itemID)
    local info = C_Item and C_Item.GetItemInfoInstant
    if not info then return false end
    local _, _, _, _, _, class, subclass = info(itemID)
    if class ~= FOOD_CLASS or subclass ~= FOOD_SUBCLASS then return false end
    local spell = C_Item.GetItemSpell and C_Item.GetItemSpell(itemID)
    if spell == "Drink" then return GivesBuff(itemID) end
    return true
end

-- The food in your bags, once per kind: buff food first, then the most you
-- carry.
function FoodTile.Foods()
    local seen, list = {}, {}
    for bag = 0, Compat.LAST_BAG do
        for slot = 1, Compat.BagSize(bag) do
            local info = Compat.BagItem(bag, slot)
            local id = info and info.itemID
            if id and not seen[id] and IsFood(id) then
                seen[id] = true
                list[#list + 1] = { id = id, icon = info.iconFileID, count = Compat.ItemCount(id), buff = GivesBuff(id) }
            end
        end
    end
    table.sort(list, function(a, b)
        if a.buff ~= b.buff then return a.buff end
        if a.count ~= b.count then return a.count > b.count end
        return a.id < b.id
    end)
    for i = #list, MAX + 1, -1 do list[i] = nil end
    return list
end

-- Shown while you're alive, out of a fight, not Well Fed and not eating.
function FoodTile.Wanted()
    if Compat.InCombat() then return false end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return false end
    if Compat.OnTaxi and Compat.OnTaxi() then return false end
    -- Where the game keeps buffs from addons (some instances), stay hidden.
    local ok, fed, eating = pcall(FoodTile.Buffs)
    if not ok then return false end
    return not fed and not eating
end

---------------------------------------------------------------------------
-- The tile and its row.
---------------------------------------------------------------------------
local holder, tile, row, glow

local function Glow(frame)
    local overlay = CreateFrame("Frame", nil, frame)
    overlay:SetAllPoints()
    local OUT, THICK = 3, 2
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
    local pulse = overlay:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local fade = pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0.3)
    fade:SetDuration(0.9)
    overlay.pulse = pulse
    return overlay
end

-- One food button: the game's secure button, so a click eats it.
local function FoodButton(i)
    local b = row.items[i]
    if b then return b end
    b = CreateFrame("Button", "jsalUIFood" .. i, row, "SecureActionButtonTemplate")
    b:SetSize(ITEM, ITEM)
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetAttribute("type", "item")
    Style.Fill(b, "well")
    b.edges = Style.Border(b, "lineStrong")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 2, -2)
    b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.count = Style.Text(b, 12, "text", "OVERLAY", true)
    b.count:SetPoint("BOTTOMRIGHT", -3, 3)
    b.count:SetJustifyH("RIGHT")
    b:SetScript("OnEnter", function(self)
        Style.SetBorder(self.edges, "gold")
        if self.food and GameTooltip.SetItemByID then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(self.food)
            GameTooltip:AddLine("Click to eat.", 0.6, 0.59, 0.53)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function(self)
        Style.SetBorder(self.edges, "lineStrong")
        GameTooltip:Hide()
    end)
    row.items[i] = b
    return b
end

-- Lays the food out in one row under the tile, centred on it.
local function FillRow()
    if Compat.InCombat() then return end
    local list = FoodTile.Foods()
    for i, food in ipairs(list) do
        local b = FoodButton(i)
        b.food = food.id
        b:SetAttribute("item", "item:" .. food.id)
        b.icon:SetTexture(food.icon)
        b.count:SetText(food.count > 1 and food.count or "")
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", (i - 1) * (ITEM + GAP), 0)
        b:Show()
    end
    for i = #list + 1, #row.items do
        local b = row.items[i]
        b.food = nil
        b:SetAttribute("item", nil)
        b:Hide()
    end
    row:SetSize(math.max(1, #list) * (ITEM + GAP) - GAP, ITEM)
    row.count = #list
end
FoodTile.FillRow = FillRow

local function OpenRow()
    if Compat.InCombat() then return end
    FillRow()
    if row.count == 0 then
        GameTooltip:SetOwner(tile, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Not well fed")
        GameTooltip:AddLine("No food in your bags.", 0.6, 0.59, 0.53)
        GameTooltip:Show()
        return
    end
    row.away = 0
    row:Show()
end

local function CloseRow()
    if row and row:IsShown() and not Compat.InCombat() then row:Hide() end
end

local function Place()
    holder:ClearAllPoints()
    local at = ns.db and ns.db.foodTileAt
    if type(at) == "table" and at[1] then
        holder:SetPoint(at[1], UIParent, at[2], at[3], at[4])
    else
        holder:SetPoint("CENTER", UIParent, "CENTER", 0, -170)
    end
end

local function Build()
    holder = CreateFrame("Frame", "jsalUIFoodTile", UIParent)
    holder:SetSize(SIZE, SIZE)
    holder:SetFrameStrata("MEDIUM")
    holder:SetClampedToScreen(true)
    holder:SetMovable(true)
    tile = CreateFrame("Button", nil, holder)
    tile:SetAllPoints()
    tile:RegisterForDrag("LeftButton")
    tile:SetScript("OnDragStart", function() holder:StartMoving() end)
    tile:SetScript("OnDragStop", function()
        holder:StopMovingOrSizing()
        local point, _, relative, x, y = holder:GetPoint(1)
        if ns.db then ns.db.foodTileAt = { point, relative, x, y } end
    end)
    tile.fill = Style.Fill(tile, "well")
    tile.edges = Style.Border(tile, "gold")
    tile.icon = tile:CreateTexture(nil, "ARTWORK")
    tile.icon:SetTexture(WELL_FED_ICON)
    tile.icon:SetPoint("TOPLEFT", 3, -3)
    tile.icon:SetPoint("BOTTOMRIGHT", -3, 3)
    tile.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    tile:SetScript("OnEnter", function(self)
        self.fill:SetColorTexture(Style.Color("wellHover"))
        OpenRow()
    end)
    tile:SetScript("OnLeave", function(self)
        self.fill:SetColorTexture(Style.Color("well"))
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    glow = Glow(tile)

    row = CreateFrame("Frame", "jsalUIFoodRow", UIParent)
    row:SetFrameStrata("DIALOG")
    row:SetClampedToScreen(true)
    row:SetPoint("TOP", holder, "BOTTOM", 0, -6)
    row.items = {}
    row.count = 0
    row:Hide()
    -- It stays while the pointer is on the tile or the row.
    row:SetScript("OnUpdate", function(self, elapsed)
        self.away = (holder:IsMouseOver() or self:IsMouseOver()) and 0 or (self.away or 0) + elapsed
        if self.away > 0.3 then CloseRow() end
    end)
    holder:Hide()
end

-- Shows or hides the tile for how you are now. Never in a fight: secure
-- buttons can't change then.
function FoodTile.Update()
    if not holder or Compat.InCombat() then return end
    if FoodTile.Wanted() then
        if not holder:IsShown() then
            holder:Show()
            glow.pulse:Play()
        end
        if row:IsShown() then FillRow() end
    else
        CloseRow()
        glow.pulse:Stop()
        holder:Hide()
    end
end

function FoodTile:OnEnable()
    if not holder then Build() end
    Place()
    -- In EllesmereUI's Unlock Mode, with its grid and snapping, when it's on.
    if ns.Unlock then
        ns.Unlock.Add({
            key = "FoodTile", label = "jsal.ui food reminder",
            frame = function() return holder end,
            load = function() return ns.db and ns.db.foodTileAt end,
            save = function(point, relative, x, y)
                if not ns.db then return end
                ns.db.foodTileAt = point and { point, relative, x, y } or nil
                if not point then Place() end
            end,
        })
    end
    local events = self.events or CreateFrame("Frame")
    self.events = events
    for _, e in ipairs({ "UNIT_AURA", "BAG_UPDATE_DELAYED", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
                         "PLAYER_REGEN_DISABLED", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST",
                         "PLAYER_CONTROL_GAINED", "PLAYER_CONTROL_LOST" }) do
        events:RegisterEvent(e)
    end
    events:SetScript("OnEvent", ns.Safe(self, function(_, event, unit)
        unit = Compat.Plain(unit)
        if event == "UNIT_AURA" and unit ~= "player" then return end
        -- The fight's lockdown starts after this event, so hide now.
        if event == "PLAYER_REGEN_DISABLED" then
            CloseRow()
            glow.pulse:Stop()
            holder:Hide()
            return
        end
        FoodTile.Update()
    end))
    FoodTile.Update()
end

function FoodTile:OnDisable()
    if self.events then self.events:UnregisterAllEvents() end
    ns.AfterCombat(function()
        if row then row:Hide() end
        if holder then holder:Hide() end
    end)
end
