-- One bag button in place of the game's bag bar, in a small frame of its
-- own that drags anywhere: a gold bag and how many bag slots are free, in red
-- at five or fewer. It starts where the game's bag bar is. A click opens your
-- bags; a right-click brings the game's bag slots back where Edit Mode put
-- them, to put on or swap a bag, and a second hides them again.
-- Pointing at it opens a panel with your free space and the four cheapest
-- things in your bags, grey junk first: a click on one puts it on your
-- cursor, to drop or sell (the game asks before anything is destroyed).
local addonName, ns = ...
local Style, Compat = ns.Style, ns.Compat

local BagButton = ns.NewModule("bagbutton", {
    title = "Bag button",
    -- It takes the place of the game's bag bar, so it starts off.
    defaultOn = false,
    note = "One button with your free bag space in place of the game's bag bar; drag it anywhere. Point at it for your cheapest items; right-click it for your bag slots. Turning it off takes a /reload.",
})
ns.BagButton = BagButton

local LOW, SHOW = 5, 4
local BAG = "Interface\\AddOns\\" .. addonName .. "\\Media\\Icons\\Menu\\bag"

---------------------------------------------------------------------------
-- What's in your bags. A quiver or ammo pouch holds only its own kind, so
-- its slots aren't counted as room, and nothing in it is offered.
---------------------------------------------------------------------------
local function Ordinary(bag)
    local _, family = Compat.BagFree(bag)
    return family == nil or family == 0
end

function BagButton.Space()
    local free, total = 0, 0
    for bag = 0, Compat.LAST_BAG do
        if Ordinary(bag) then
            free = free + (Compat.BagFree(bag) or 0)
            total = total + Compat.BagSize(bag)
        end
    end
    return free, total
end

-- The cheapest stacks to drop: only things a vendor buys (so quest items,
-- keys and the hearthstone never show), grey junk first, then by what the
-- whole stack sells for.
function BagButton.Cheapest(limit)
    local list = {}
    for bag = 0, Compat.LAST_BAG do
        if Ordinary(bag) then
            for slot = 1, Compat.BagSize(bag) do
                local info = Compat.BagItem(bag, slot)
                if info and info.itemID and not info.hasNoValue then
                    local price = Compat.SellPrice(info.itemID)
                    if price and price > 0 then
                        local count = info.stackCount or 1
                        list[#list + 1] = { bag = bag, slot = slot, icon = info.iconFileID, count = count,
                                            junk = info.quality == 0, value = price * count }
                    end
                end
            end
        end
    end
    table.sort(list, function(a, b)
        if a.junk ~= b.junk then return a.junk end
        if a.value ~= b.value then return a.value < b.value end
        if a.bag ~= b.bag then return a.bag < b.bag end
        return a.slot < b.slot
    end)
    for i = #list, (limit or SHOW) + 1, -1 do list[i] = nil end
    return list
end

---------------------------------------------------------------------------
-- The game's bag bar: faded and not clickable while the bag button stands
-- in for it; a right-click on the button brings it back.
---------------------------------------------------------------------------
local slotsShown = false
local fading = false

local function BagSlots()
    local list = {}
    local manager = MainMenuBarBagManager
    if manager and manager.EnumerateBagButtons then
        for _, b in manager:EnumerateBagButtons() do list[#list + 1] = b end
    end
    for _, name in ipairs({ "BagBarExpandToggle", "KeyRingButton" }) do
        if _G[name] then list[#list + 1] = _G[name] end
    end
    return list
end

function BagButton.ShowSlots(show)
    slotsShown = show and true or false
    local bar = BagsBar
    if bar then
        fading = true
        bar:SetAlpha(slotsShown and 1 or 0)
        fading = false
    end
    -- The slots stop taking clicks while unseen; out of a fight only.
    ns.AfterCombat(function()
        for _, b in ipairs(BagSlots()) do
            if b.EnableMouse then pcall(b.EnableMouse, b, slotsShown) end
        end
    end)
end

---------------------------------------------------------------------------
-- The button.
---------------------------------------------------------------------------
local holder, tile, panel
local SIZE, INSET = 32, 4

local function Lay()
    local h = tile:GetHeight()
    if not h or h < 8 then return end
    local pad = h * 0.28
    tile.icon:SetSize(h * 0.58, h * 0.58)
    tile.icon:ClearAllPoints()
    tile.icon:SetPoint("LEFT", pad, 0)
    tile.count:ClearAllPoints()
    tile.count:SetPoint("LEFT", tile.icon, "RIGHT", h * 0.22, 0)
    tile.free:ClearAllPoints()
    tile.free:SetPoint("LEFT", tile.count, "RIGHT", 3, 0)
    local width = pad + h * 0.58 + h * 0.22 + tile.count:GetStringWidth() + 3 + tile.free:GetStringWidth() + pad + 2
    tile:SetWidth(width)
    holder:SetSize(width + INSET * 2, h + INSET * 2)
end

local function PaintTile()
    if not tile then return end
    local free = BagButton.Space()
    tile.count:SetText(free)
    tile.count:SetTextColor(Style.Color(free <= LOW and "red" or "text"))
    local lit = tile.hover or slotsShown
    tile.fill:SetColorTexture(Style.Color(tile.hover and "wellHover" or "well"))
    Style.SetBorder(tile.edges, lit and "gold" or "lineStrong")
    Lay()
end
BagButton.PaintTile = PaintTile

---------------------------------------------------------------------------
-- The panel: free space, then the cheapest few, each a click from your
-- cursor.
---------------------------------------------------------------------------
local ITEM, ITEM_GAP, PAD = 36, 8, 12

local function ItemTile(i)
    local b = panel.items[i]
    if b then return b end
    b = CreateFrame("Button", nil, panel)
    b:SetSize(ITEM, ITEM)
    Style.Fill(b, "well")
    b.edges = Style.Border(b, "lineStrong")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 2, -2)
    b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.count = Style.Text(b, 12, "text", "OVERLAY", true)
    b.count:SetPoint("BOTTOMRIGHT", -3, 3)
    b.count:SetJustifyH("RIGHT")
    b.value = Style.Text(panel, 12, "muted")
    b.value:SetPoint("TOP", b, "BOTTOM", 0, -4)
    b.value:SetJustifyH("CENTER")
    b:SetScript("OnClick", function(self)
        if self.bag then Compat.PickupBagItem(self.bag, self.slot) end
    end)
    b:SetScript("OnEnter", function(self)
        Style.SetBorder(self.edges, "gold")
        if self.bag and GameTooltip.SetBagItem then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetBagItem(self.bag, self.slot)
            GameTooltip:AddLine("Click to pick it up.", 0.6, 0.59, 0.53)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function(self)
        Style.SetBorder(self.edges, "lineStrong")
        GameTooltip:Hide()
    end)
    panel.items[i] = b
    return b
end

local function PaintPanel()
    if not (panel and panel:IsShown()) then return end
    local free, total = BagButton.Space()
    panel.title:SetText(("%d free of %d"):format(free, total))
    panel.title:SetTextColor(Style.Color(free <= LOW and "red" or "text"))
    local list = BagButton.Cheapest(SHOW)
    for i, item in ipairs(list) do
        local b = ItemTile(i)
        b.bag, b.slot = item.bag, item.slot
        b.icon:SetTexture(item.icon)
        b.count:SetText(item.count > 1 and item.count or "")
        b.value:SetText(Compat.Money(item.value))
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", panel.label, "BOTTOMLEFT", (i - 1) * (ITEM + ITEM_GAP), -8)
        b:Show()
        b.value:Show()
    end
    for i = #list + 1, #panel.items do
        panel.items[i]:Hide()
        panel.items[i].value:Hide()
        panel.items[i].bag = nil
    end
    local row = math.max(1, #list) * (ITEM + ITEM_GAP) - ITEM_GAP
    panel.label:SetText(#list > 0 and "CHEAPEST TO DROP" or "NOTHING A VENDOR WOULD BUY")
    panel:SetWidth(math.max(row, panel.title:GetStringWidth() + 28, 150) + PAD * 2)
    panel:SetHeight(#list > 0 and (PAD + 20 + 6 + 14 + 8 + ITEM + 4 + 14 + PAD) or (PAD + 20 + 6 + 14 + PAD))
end
BagButton.PaintPanel = PaintPanel

local function BuildPanel()
    panel = CreateFrame("Frame", "jsalUIBagPanel", UIParent)
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:Hide()
    Style.Fill(panel, "window")
    Style.Border(panel, "lineStrong")
    Style.Shadow(panel, 12)
    panel.items = {}
    local icon = panel:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(BAG)
    icon:SetVertexColor(Style.Color("gold"))
    icon:SetSize(18, 18)
    icon:SetPoint("TOPLEFT", PAD, -PAD)
    panel.title = Style.Text(panel, 14, "text", nil, true)
    panel.title:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    panel.label = Style.Text(panel, 11, "muted", nil, true)
    panel.label:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -8)
    -- It stays while the pointer is on the button or the panel.
    panel:SetScript("OnUpdate", function(self, elapsed)
        self.away = (holder:IsMouseOver() or self:IsMouseOver()) and 0 or (self.away or 0) + elapsed
        if self.away > 0.25 then self:Hide() end
    end)
end

local function OpenPanel()
    if not panel then BuildPanel() end
    panel:ClearAllPoints()
    panel:SetPoint("BOTTOMRIGHT", holder, "TOPRIGHT", 0, 8)
    panel.away = 0
    panel:Show()
    PaintPanel()
end

-- Where the frame was dragged to, saved for the account; at first, where the
-- game's bag bar is.
local function Place()
    holder:ClearAllPoints()
    local at = ns.db and ns.db.bagButtonAt
    if type(at) == "table" and at[1] then
        holder:SetPoint(at[1], UIParent, at[2], at[3], at[4])
    elseif BagsBar and select(2, BagsBar:GetCenter()) then
        local x, y = BagsBar:GetCenter()
        local scale = BagsBar:GetEffectiveScale() / UIParent:GetEffectiveScale()
        holder:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x * scale, y * scale)
    else
        holder:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -320, 60)
    end
end

local function Build()
    holder = CreateFrame("Frame", "jsalUIBagButton", UIParent)
    holder:SetFrameStrata("MEDIUM")
    holder:SetClampedToScreen(true)
    holder:SetMovable(true)
    Style.Fill(holder, "window")
    Style.Border(holder, "lineStrong")
    Style.Shadow(holder, 10)
    tile = CreateFrame("Button", nil, holder)
    tile:SetPoint("TOPLEFT", INSET, -INSET)
    tile:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    -- Dragging the button moves the whole frame; a plain click still clicks.
    tile:RegisterForDrag("LeftButton")
    tile:SetScript("OnDragStart", function() holder:StartMoving() end)
    tile:SetScript("OnDragStop", function()
        holder:StopMovingOrSizing()
        local point, _, relative, x, y = holder:GetPoint(1)
        if ns.db then ns.db.bagButtonAt = { point, relative, x, y } end
    end)
    tile.fill = Style.Fill(tile, "well")
    tile.edges = Style.Border(tile, "lineStrong")
    tile.icon = tile:CreateTexture(nil, "ARTWORK")
    tile.icon:SetTexture(BAG)
    tile.icon:SetVertexColor(Style.Color("gold"))
    tile.count = Style.Text(tile, 13, "text", nil, true)
    tile.free = Style.Text(tile, 12, "muted")
    tile.free:SetText("free")
    tile:SetHeight(SIZE)
    tile:SetScript("OnSizeChanged", Lay)
    tile:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            BagButton.ShowSlots(not slotsShown)
            PaintTile()
        elseif ToggleAllBags then
            ToggleAllBags()
        end
    end)
    tile:SetScript("OnEnter", function(self)
        self.hover = true
        PaintTile()
        OpenPanel()
    end)
    tile:SetScript("OnLeave", function(self)
        self.hover = false
        PaintTile()
    end)
end

function BagButton:OnEnable()
    if not holder then Build() end
    Place()
    holder:Show()
    -- In EllesmereUI's Unlock Mode, with its grid and snapping, when it's on.
    if ns.Unlock then
        ns.Unlock.Add({
            key = "BagButton", label = "jsal.ui bag button",
            frame = function() return holder end,
            load = function() return ns.db and ns.db.bagButtonAt end,
            save = function(point, relative, x, y)
                if not ns.db then return end
                ns.db.bagButtonAt = point and { point, relative, x, y } or nil
                if not point then Place() end
            end,
        })
    end
    BagButton.ShowSlots(false)
    -- Another addon setting the bag bar's alpha (a fade on hover) doesn't
    -- bring it back while the button stands in for it.
    if BagsBar and not self.hooked then
        self.hooked = true
        hooksecurefunc(BagsBar, "SetAlpha", function(bar, alpha)
            if fading or slotsShown or (alpha or 0) == 0 then return end
            fading = true
            bar:SetAlpha(0)
            fading = false
        end)
    end
    local events = self.events or CreateFrame("Frame")
    self.events = events
    events:RegisterEvent("BAG_UPDATE_DELAYED")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    events:SetScript("OnEvent", ns.Safe(self, function(_, event)
        if event ~= "GET_ITEM_INFO_RECEIVED" then PaintTile() end
        PaintPanel()
    end))
    PaintTile()
end

function BagButton:OnDisable()
    if self.events then self.events:UnregisterAllEvents() end
    if holder then holder:Hide() end
    if panel then panel:Hide() end
    BagButton.ShowSlots(true)
end
