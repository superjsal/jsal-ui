-- The shopping list: a small window of what you mean to craft and other
-- items you want, and what's left to buy for them once your bags and bank
-- are counted, with prices where they're known (vendor prices from the
-- data, auction prices remembered from your own Auction House searches).
-- Things are added here, from the game's recipe details, or from the
-- profession panel's road; at a vendor who sells something on the list, a
-- button buys it. /jsal shop opens it.
local _, ns = ...
local Style, Compat, Professions = ns.Style, ns.Compat, ns.Professions

local Shopping = ns.NewModule("shopping", {
    title = "Shopping list",
    note = "What to craft and buy, less what you have, with prices. /jsal shop",
})
ns.Shopping = Shopping

local WIDTH, PAD, ROW_H = 380, 14, 28
local MAX_CRAFTS, MAX_ITEMS, MAX_BUY = 8, 8, 12

---------------------------------------------------------------------------
-- The list, per character: crafts by recipe and other items by item.
---------------------------------------------------------------------------
local function List()
    local s = ns.char.shopping
    if type(s) ~= "table" then
        s = {}
        ns.char.shopping = s
    end
    s.crafts = type(s.crafts) == "table" and s.crafts or {}
    s.items = type(s.items) == "table" and s.items or {}
    return s
end

local Paint

function Shopping.AddCraft(spell, count)
    count = math.max(1, math.floor(tonumber(count) or 1))
    local crafts = List().crafts
    crafts[spell] = (crafts[spell] or 0) + count
    Shopping.Open()
end

function Shopping.AddItem(item, count)
    count = math.max(1, math.floor(tonumber(count) or 1))
    local items = List().items
    items[item] = (items[item] or 0) + count
    Shopping.Open()
end

local function Recipe(spell)
    return ns.ProfWindow and ns.ProfWindow.RecipeFor(spell)
end

-- What everything on the list needs, by item: each craft's reagents times
-- how many, and the other items themselves.
local function Needs()
    local need = {}
    local s = List()
    for spell, count in pairs(s.crafts) do
        local recipe = Recipe(spell)
        for _, reagent in ipairs(recipe and recipe.reagents or {}) do
            need[reagent.item] = (need[reagent.item] or 0) + reagent.count * count
        end
    end
    for item, count in pairs(s.items) do need[item] = (need[item] or 0) + count end
    return need
end

---------------------------------------------------------------------------
-- Auction prices: the cheapest price per item seen in your own searches,
-- kept per realm with when it was seen.
---------------------------------------------------------------------------
local function Prices()
    local realm = GetRealmName and GetRealmName() or "?"
    ns.db.ahPrices = type(ns.db.ahPrices) == "table" and ns.db.ahPrices or {}
    ns.db.ahPrices[realm] = type(ns.db.ahPrices[realm]) == "table" and ns.db.ahPrices[realm] or {}
    return ns.db.ahPrices[realm]
end

local function SeePrice(item, unit)
    if not (item and unit and unit > 0) then return end
    Prices()[item] = { price = math.floor(unit), seen = Compat.ServerTime() }
end

-- A unit price for an item: the vendor's if a vendor sells it, else the
-- auction price last seen, else none.
local function PriceOf(item)
    local vendor = Professions.IsVendor(item)
    if vendor then return vendor, "vendor" end
    local seen = Prices()[item]
    if type(seen) == "table" and seen.price then return seen.price, "auction" end
end

---------------------------------------------------------------------------
-- The window.
---------------------------------------------------------------------------
local frame, box, qty
local rows = {}

local function Small(parent, label, width)
    local b = Style.Button(parent, label, "plain", width or 20)
    b:SetHeight(20)
    return b
end

local function Row(i)
    local r = rows[i]
    if r then return r end
    r = CreateFrame("Frame", nil, frame)
    r:SetSize(WIDTH - PAD * 2, ROW_H)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(20, 20)
    r.icon:SetPoint("LEFT")
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.remove = Small(r, "x")
    r.remove:SetPoint("RIGHT")
    r.plus = Small(r, "+")
    r.plus:SetPoint("RIGHT", r.remove, "LEFT", -4, 0)
    r.minus = Small(r, "-")
    r.minus:SetPoint("RIGHT", r.plus, "LEFT", -4, 0)
    r.status = Style.Text(r, 11, "muted")
    r.status:SetJustifyH("RIGHT")
    r.name = Style.Text(r, 12, "text")
    r.name:SetPoint("LEFT", r.icon, "RIGHT", 8, 0)
    r.name:SetWordWrap(false)
    r:EnableMouse(true)
    r:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.item then GameTooltip:SetItemByID(self.item) elseif self.spell then GameTooltip:SetSpellByID(self.spell) end
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    rows[i] = r
    return r
end

local function Heading(text, note)
    local h = CreateFrame("Frame", nil, frame)
    h:SetSize(WIDTH - PAD * 2, 18)
    h.title = Style.Text(h, 11, "gold", nil, true)
    h.title:SetPoint("LEFT")
    h.title:SetText(text)
    h.note = Style.Text(h, 11, "muted")
    h.note:SetPoint("RIGHT")
    h.note:SetJustifyH("RIGHT")
    h.note:SetText(note or "")
    return h
end

-- Reads what's in the add box: an item link (shift-clicked), an item ID,
-- or a name the game knows, or one of the professions' items by name.
local function ItemFromText(text)
    text = strtrim(text or "")
    if text == "" then return nil end
    local linked = text:match("|Hitem:(%d+)")
    if linked then return tonumber(linked) end
    if text:match("^%d+$") then return tonumber(text) end
    local id = C_Item and C_Item.GetItemInfoInstant and C_Item.GetItemInfoInstant(text)
    if not id and GetItemInfoInstant then id = GetItemInfoInstant(text) end
    if id then return id end
    local lower = text:lower()
    local function Matches(item)
        local name = item and Compat.ItemName(item)
        return name and name:lower() == lower
    end
    for line, source in pairs(ns.ProfessionData) do
        if type(source) == "table" and type(source.recipes) == "table" then
            for _, recipe in ipairs(Professions.Recipes(line) or {}) do
                if Matches(recipe.item) then return recipe.item end
                for _, reagent in ipairs(recipe.reagents) do
                    if Matches(reagent.item) then return reagent.item end
                end
            end
        end
    end
end

local function Field(parent, width, numeric)
    local well = CreateFrame("Frame", nil, parent)
    well:SetSize(width, 26)
    Style.Fill(well, "well")
    Style.Border(well, "lineStrong")
    local e = CreateFrame("EditBox", nil, well)
    e:SetPoint("TOPLEFT", 8, 0)
    e:SetPoint("BOTTOMRIGHT", -8, 0)
    e:SetAutoFocus(false)
    e:SetFont(Style.font, 12, "")
    e:SetTextColor(Style.Color("text"))
    if numeric then e:SetNumeric(true); e:SetMaxLetters(3); e:SetJustifyH("CENTER") end
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    well:EnableMouse(true)
    well:SetScript("OnMouseDown", function() e:SetFocus() end)
    e.well = well
    return e
end

local function Build()
    frame = CreateFrame("Frame", "jsalUIShoppingList", UIParent)
    frame:SetWidth(WIDTH)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relative, x, y = self:GetPoint(1)
        ns.db.shoppingAt = { point, relative, x, y }
    end)
    frame:Hide()
    Style.Fill(frame, "window")
    Style.Border(frame, "lineStrong")
    local bar = CreateFrame("Frame", nil, frame)
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("TOPRIGHT")
    bar:SetHeight(36)
    Style.Fill(bar, "titleBar")
    Style.Rule(bar, "BOTTOM", "line")
    local mark = bar:CreateTexture(nil, "ARTWORK")
    mark:SetTexture("Interface\\AddOns\\jsalUI\\Media\\Logo")
    mark:SetSize(18, 18)
    mark:SetPoint("LEFT", 12, 0)
    local word = Style.Wordmark(bar, 15)
    word:SetPoint("LEFT", mark, "RIGHT", 8, 0)
    local divider = bar:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(Style.Color("lineStrong"))
    divider:SetSize(Compat.OnePixel(bar), 16)
    divider:SetPoint("LEFT", word, "RIGHT", 10, 0)
    local title = Style.Text(bar, 13, "text", nil, true)
    title:SetPoint("LEFT", divider, "RIGHT", 10, 0)
    title:SetText("Shopping list")
    Style.CloseButton(bar, 36, function() frame:Hide() end):SetPoint("TOPRIGHT")
    -- The bar is the handle for moving the window.
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() frame:StartMoving() end)
    bar:SetScript("OnDragStop", function() frame:GetScript("OnDragStop")(frame) end)

    box = Field(frame, WIDTH - PAD * 2 - 46 - 60 - 12)
    box.well:SetPoint("TOPLEFT", PAD, -(36 + 12))
    box.hint = Style.Text(box.well, 11, "muted")
    box.hint:SetPoint("LEFT", 8, 0)
    box.hint:SetText("Shift-click an item, or type its name")
    box:SetScript("OnTextChanged", function(self) box.hint:SetShown(self:GetText() == "" and not self:HasFocus()) end)
    box:SetScript("OnEditFocusGained", function() box.hint:Hide() end)
    box:SetScript("OnEditFocusLost", function(self) box.hint:SetShown(self:GetText() == "") end)
    qty = Field(frame, 46, true)
    qty.well:SetPoint("LEFT", box.well, "RIGHT", 6, 0)
    qty:SetText("1")
    frame.add = Style.Button(frame, "Add", "plain", 60)
    frame.add:SetHeight(26)
    frame.add:SetPoint("LEFT", qty.well, "RIGHT", 6, 0)
    local function Add()
        local item = ItemFromText(box:GetText())
        if not item then
            frame.message:SetText("That isn't an item the game knows yet: shift-click it instead.")
            return
        end
        frame.message:SetText("")
        box:SetText("")
        box:ClearFocus()
        Shopping.AddItem(item, qty:GetText())
        qty:SetText("1")
    end
    frame.add:SetScript("OnClick", Add)
    box:SetScript("OnEnterPressed", Add)
    qty:SetScript("OnEnterPressed", Add)
    frame.message = Style.Text(frame, 11, "gold")
    frame.message:SetPoint("TOPLEFT", box.well, "BOTTOMLEFT", 0, -4)
    frame.message:SetWidth(WIDTH - PAD * 2)

    frame.craftsHead = Heading("CRAFTS")
    frame.itemsHead = Heading("OTHER ITEMS")
    frame.buyHead = Heading("TO BUY", "bags and bank / need · price")
    frame.empty = Style.Text(frame, 12, "muted")
    frame.empty:SetWidth(WIDTH - PAD * 2)
    frame.empty:SetText("Nothing on the list yet. Add an item above, a craft from the profession window, or the road from jsal.ui's profession panel.")
    frame.rule = frame:CreateTexture(nil, "BORDER")
    frame.rule:SetColorTexture(Style.Color("line"))
    frame.rule:SetSize(WIDTH - PAD * 2, Compat.OnePixel(frame))
    frame.total = Style.Text(frame, 11, "muted")
    frame.total:SetWidth(WIDTH - PAD * 2 - 90)
    frame.clear = Style.Button(frame, "Clear", "plain", 80)
    frame.clear:SetHeight(26)
    -- Clearing asks once: the first click arms it for a moment.
    local armed = 0
    frame.clear:SetScript("OnClick", function()
        if GetTime() > armed then
            armed = GetTime() + 3
            frame.clear:SetLabel("Sure?")
            Compat.After(3, function() frame.clear:SetLabel("Clear") end)
            return
        end
        armed = 0
        frame.clear:SetLabel("Clear")
        ns.char.shopping = nil
        Paint()
    end)
    local at = ns.db.shoppingAt
    if type(at) == "table" and at[1] then
        frame:SetPoint(at[1], UIParent, at[2], at[3], at[4])
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 300, 60)
    end
end

local function Place(region, y)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -y)
    region:Show()
end

local function ItemName(item) return Compat.ItemName(item) or "..." end

Paint = function()
    if not frame then return end
    local s = List()
    local used = 0
    local y = 36 + 12 + 26 + 18
    local function Next()
        used = used + 1
        local r = Row(used)
        r.minus:Show(); r.plus:Show(); r.remove:Show()
        r.status:ClearAllPoints()
        r.status:SetPoint("RIGHT", r.minus, "LEFT", -8, 0)
        r.name:SetPoint("RIGHT", r.status, "LEFT", -8, 0)
        r:SetAlpha(1)
        return r
    end
    local function Buttons(r, list, key)
        r.minus:SetScript("OnClick", function()
            list[key] = (list[key] or 1) > 1 and list[key] - 1 or nil
            Paint()
        end)
        r.plus:SetScript("OnClick", function()
            list[key] = (list[key] or 0) + 1
            Paint()
        end)
        r.remove:SetScript("OnClick", function()
            list[key] = nil
            Paint()
        end)
    end

    -- Crafts, by name.
    local crafts = {}
    for spell, count in pairs(s.crafts) do crafts[#crafts + 1] = { spell = spell, count = count, recipe = Recipe(spell) } end
    table.sort(crafts, function(a, b) return a.spell < b.spell end)
    if #crafts > 0 then
        frame.craftsHead.note:SetText(#crafts)
        Place(frame.craftsHead, y)
        y = y + 22
        for i, c in ipairs(crafts) do
            if i > MAX_CRAFTS then break end
            local r = Next()
            Place(r, y)
            r.item, r.spell = c.recipe and c.recipe.item, c.spell
            r.icon:SetTexture((r.item and Compat.ItemIcon(r.item)) or select(2, Compat.SpellInfo(c.spell)))
            r.name:SetText(((r.item and Compat.ItemName(r.item)) or (Compat.SpellInfo(c.spell)) or "...") .. "  |cff9a9688×" .. c.count .. "|r")
            r.status:SetText("")
            Buttons(r, s.crafts, c.spell)
            y = y + ROW_H
        end
        y = y + 6
    else
        frame.craftsHead:Hide()
    end

    -- Other items, with what you have.
    local items = {}
    for item, count in pairs(s.items) do items[#items + 1] = { item = item, count = count } end
    table.sort(items, function(a, b) return a.item < b.item end)
    if #items > 0 then
        frame.itemsHead.note:SetText(#items)
        Place(frame.itemsHead, y)
        y = y + 22
        for i, e in ipairs(items) do
            if i > MAX_ITEMS then break end
            local r = Next()
            Place(r, y)
            r.item, r.spell = e.item, nil
            r.icon:SetTexture(Compat.ItemIcon(e.item))
            r.name:SetText(ItemName(e.item) .. "  |cff9a9688×" .. e.count .. "|r")
            local have = Compat.ItemCount(e.item, true)
            local enough = have >= e.count
            r.status:SetText(enough and ("|cff56944fhave %d|r"):format(have) or ("|cffff6b6bhave %d|r"):format(have))
            r:SetAlpha(enough and 0.5 or 1)
            Buttons(r, s.items, e.item)
            y = y + ROW_H
        end
        y = y + 6
    else
        frame.itemsHead:Hide()
    end

    -- To buy: everything needed, the biggest shortfall first, with prices.
    local buy, total, unpriced = {}, 0, 0
    for item, need in pairs(Needs()) do
        local have = Compat.ItemCount(item, true)
        buy[#buy + 1] = { item = item, need = need, have = have, short = math.max(0, need - have) }
    end
    table.sort(buy, function(a, b)
        if a.short ~= b.short then return a.short > b.short end
        return a.item < b.item
    end)
    if #buy > 0 then
        Place(frame.buyHead, y)
        y = y + 22
        for i, e in ipairs(buy) do
            if i > MAX_BUY then break end
            local r = Next()
            Place(r, y)
            r.minus:Hide(); r.plus:Hide(); r.remove:Hide()
            r.status:ClearAllPoints()
            r.status:SetPoint("RIGHT")
            r.item, r.spell = e.item, nil
            r.icon:SetTexture(Compat.ItemIcon(e.item))
            r.name:SetText(ItemName(e.item))
            local price, where = PriceOf(e.item)
            local priceText = ""
            if e.short > 0 then
                if price then
                    total = total + price * e.short
                    priceText = ("  %s · %s"):format(where, Compat.Money(price * e.short))
                else
                    unpriced = unpriced + 1
                    priceText = "  no price"
                end
            end
            local color = e.short > 0 and "ff6b6b" or "56944f"
            r.status:SetText(("|cff%s%d|r / %d%s"):format(color, e.have, e.need, priceText))
            r:SetAlpha(e.short > 0 and 1 or 0.5)
            y = y + ROW_H
        end
    else
        frame.buyHead:Hide()
    end
    for i = used + 1, #rows do rows[i]:Hide() end

    local empty = #crafts == 0 and #items == 0
    frame.empty:SetShown(empty)
    if empty then
        Place(frame.empty, y)
        y = y + 48
    end
    y = y + 6
    Place(frame.rule, y)
    y = y + 10
    local text = total > 0 and ("About |cffece6d6%s|r to buy"):format(Compat.Money(total)) or "Nothing to buy"
    if unpriced > 0 then text = text .. (" · %d unpriced"):format(unpriced) end
    if total > 0 then text = text .. " · auction prices from your own searches" end
    frame.total:SetText(text)
    Place(frame.total, y + 4)
    frame.clear:ClearAllPoints()
    frame.clear:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -y)
    frame.clear:SetShown(not empty)
    frame:SetHeight(y + 26 + PAD)
end

function Shopping.Open()
    if not Shopping.running then return end
    if not frame then Build() end
    frame:Show()
    xpcall(Paint, ns.Report)
end

function Shopping.Toggle()
    if frame and frame:IsShown() then frame:Hide() else Shopping.Open() end
end

ns.Command("shop", function() Shopping.Toggle() end)

---------------------------------------------------------------------------
-- Adding from the game's recipe details: a count and a button.
---------------------------------------------------------------------------
local detailRecipe, detailButton
local function HookDetails()
    local form = ProfessionsFrame and ProfessionsFrame.CraftingPage and ProfessionsFrame.CraftingPage.SchematicForm
    if detailButton or not form or not form.Init then return end
    local count = Field(form, 40, true)
    count:SetText("1")
    detailButton = Style.Button(form, "Add to shopping list", "plain", 150)
    detailButton:SetHeight(24)
    detailButton:SetPoint("TOPRIGHT", form, "TOPRIGHT", -10, -10)
    count.well:SetPoint("RIGHT", detailButton, "LEFT", -6, 0)
    detailButton:SetScript("OnClick", function()
        if detailRecipe then Shopping.AddCraft(detailRecipe, count:GetText()) end
    end)
    hooksecurefunc(form, "Init", function(_, recipeInfo)
        detailRecipe = type(recipeInfo) == "table" and recipeInfo.recipeID or nil
        local show = Shopping.running and detailRecipe ~= nil and Recipe(detailRecipe) ~= nil
        detailButton:SetShown(show)
        count.well:SetShown(show)
    end)
end

---------------------------------------------------------------------------
-- At a vendor: what on the list this vendor sells, and one button to buy
-- what's still needed of it.
---------------------------------------------------------------------------
local vendorFrame
local function VendorOffer()
    local need = Needs()
    local offer, total = {}, 0
    for i = 1, (GetMerchantNumItems and GetMerchantNumItems() or 0) do
        local item = GetMerchantItemID and GetMerchantItemID(i)
        local wanted = item and need[item]
        if wanted then
            local short = wanted - Compat.ItemCount(item, true)
            if short > 0 then
                local name, price, stack
                local info = C_MerchantFrame and C_MerchantFrame.GetItemInfo and C_MerchantFrame.GetItemInfo(i)
                if info then
                    name, price, stack = info.name, info.price, info.stackCount
                else
                    local n, _, p, q = GetMerchantItemInfo(i)
                    name, price, stack = n, p, q
                end
                stack = math.max(1, stack or 1)
                local buys = math.ceil(short / stack)
                offer[#offer + 1] = { index = i, item = item, name = name, count = buys * stack, stack = stack, cost = (price or 0) * buys }
                total = total + (price or 0) * buys
            end
        end
    end
    return offer, total
end

local function BuyOffer()
    local offer = VendorOffer()
    for _, o in ipairs(offer) do
        if o.stack > 1 then
            for _ = 1, o.count / o.stack do BuyMerchantItem(o.index) end
        else
            local most = math.max(1, GetMerchantItemMaxStack and GetMerchantItemMaxStack(o.index) or 1)
            local left = o.count
            while left > 0 do
                local n = math.min(left, most)
                BuyMerchantItem(o.index, n)
                left = left - n
            end
        end
    end
end

local function PaintVendor()
    if not (Shopping.running and MerchantFrame and MerchantFrame:IsShown()) then
        if vendorFrame then vendorFrame:Hide() end
        return
    end
    local offer, total = VendorOffer()
    if #offer == 0 then
        if vendorFrame then vendorFrame:Hide() end
        return
    end
    if not vendorFrame then
        vendorFrame = CreateFrame("Frame", "jsalUIShoppingVendor", UIParent)
        vendorFrame:SetWidth(300)
        Style.Fill(vendorFrame, "window")
        Style.Border(vendorFrame, "lineStrong")
        vendorFrame.title = Style.Text(vendorFrame, 11, "gold", nil, true)
        vendorFrame.title:SetPoint("TOPLEFT", PAD, -12)
        vendorFrame.title:SetText("ON YOUR SHOPPING LIST")
        vendorFrame.lines = Style.Text(vendorFrame, 12, "text")
        vendorFrame.lines:SetPoint("TOPLEFT", PAD, -32)
        vendorFrame.lines:SetWidth(300 - PAD * 2)
        vendorFrame.buy = Style.Button(vendorFrame, "Buy", "primary", 300 - PAD * 2)
        vendorFrame.buy:SetHeight(28)
        vendorFrame.buy:SetScript("OnClick", function() BuyOffer() end)
    end
    local lines = {}
    for _, o in ipairs(offer) do
        lines[#lines + 1] = ("%s  |cff9a9688×%d · %s|r"):format(o.name or "?", o.count, Compat.Money(o.cost))
    end
    vendorFrame.lines:SetText(table.concat(lines, "\n"))
    local h = vendorFrame.lines:GetStringHeight()
    vendorFrame.buy:ClearAllPoints()
    vendorFrame.buy:SetPoint("TOPLEFT", PAD, -(32 + h + 10))
    vendorFrame.buy:SetLabel("Buy what's on my list · " .. Compat.Money(total))
    vendorFrame:SetHeight(32 + h + 10 + 28 + PAD)
    vendorFrame:ClearAllPoints()
    vendorFrame:SetPoint("TOPLEFT", MerchantFrame, "TOPRIGHT", 6, 0)
    vendorFrame:SetFrameStrata(MerchantFrame:GetFrameStrata())
    vendorFrame:SetFrameLevel(MerchantFrame:GetFrameLevel() + 10)
    vendorFrame:Show()
end

---------------------------------------------------------------------------
-- Auction House searches: whichever kind of auction house this client has,
-- the lowest prices it shows are remembered.
---------------------------------------------------------------------------
local function SeeBrowse()
    local ah = C_AuctionHouse
    if ah and ah.GetBrowseResults then
        for _, r in ipairs(ah.GetBrowseResults() or {}) do
            SeePrice(r.itemKey and r.itemKey.itemID, r.minPrice)
        end
    end
end

local function SeeCommodity(item)
    local ah = C_AuctionHouse
    local first = ah and ah.GetCommoditySearchResultInfo and ah.GetCommoditySearchResultInfo(item, 1)
    if first then SeePrice(item, first.unitPrice) end
end

-- The older auction house's list: each row's buyout per item.
local function SeeOldList()
    if not (GetNumAuctionItems and GetAuctionItemInfo) then return end
    local lowest = {}
    for i = 1, (GetNumAuctionItems("list")) do
        local _, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, item = GetAuctionItemInfo("list", i)
        if item and buyout and buyout > 0 and count and count > 0 then
            local unit = buyout / count
            if not lowest[item] or unit < lowest[item] then lowest[item] = unit end
        end
    end
    for item, unit in pairs(lowest) do SeePrice(item, unit) end
end

---------------------------------------------------------------------------
-- Starting.
---------------------------------------------------------------------------
function Shopping:OnEnable()
    local events = CreateFrame("Frame")
    for _, event in ipairs({ "ADDON_LOADED", "TRADE_SKILL_SHOW", "BAG_UPDATE_DELAYED", "MERCHANT_SHOW", "MERCHANT_UPDATE",
                             "MERCHANT_CLOSED", "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", "COMMODITY_SEARCH_RESULTS_UPDATED",
                             "AUCTION_ITEM_LIST_UPDATE" }) do
        pcall(events.RegisterEvent, events, event)
    end
    events:SetScript("OnEvent", function(_, event, arg1)
        local ok, err = pcall(function()
            if event == "ADDON_LOADED" or event == "TRADE_SKILL_SHOW" then
                HookDetails()
            elseif event == "BAG_UPDATE_DELAYED" then
                if frame and frame:IsShown() then Paint() end
                PaintVendor()
            elseif event == "MERCHANT_SHOW" or event == "MERCHANT_UPDATE" then
                Compat.After(0.2, function() xpcall(PaintVendor, ns.Report) end)
            elseif event == "MERCHANT_CLOSED" then
                if vendorFrame then vendorFrame:Hide() end
            elseif event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" then
                SeeBrowse()
            elseif event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
                SeeCommodity(arg1)
            elseif event == "AUCTION_ITEM_LIST_UPDATE" then
                SeeOldList()
            end
        end)
        if not ok then ns.Report(err) end
    end)
    self.events = events
    -- Shift-clicking an item while the add box has the cursor puts it there.
    if ChatEdit_InsertLink then
        hooksecurefunc("ChatEdit_InsertLink", function(link)
            if box and box:HasFocus() and type(link) == "string" and link:find("|Hitem:") then box:SetText(link) end
        end)
    end
    pcall(HookDetails)
end

function Shopping:OnDisable()
    if self.events then self.events:UnregisterAllEvents() end
    if frame then frame:Hide() end
    if vendorFrame then vendorFrame:Hide() end
end
