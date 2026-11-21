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
    options = {
        { key = "craftMats", title = "Add what you can craft, with its mats", default = false,
          note = "When one of your professions makes an item you add (a Camp Tent, say), the list adds the craft and what it takes. Buy it instead puts the item back." },
    },
})
ns.Shopping = Shopping

local WIDTH, PAD, ROW_H = 380, 14, 30
local MAX_CRAFTS, MAX_ITEMS, MAX_BUY, MAX_ENOUGH = 8, 8, 12, 9
-- A count's pill; a group's card: its heading's height, and how far in its
-- rows start; the bar beside how many more.
local STEP_W, HEAD_H, CARD_PAD, BAR_W = 84, 30, 13, 48

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
    -- Materials you'd rather buy than make, by item: absent on a list that has none.
    s.bought = type(s.bought) == "table" and next(s.bought) and s.bought or nil
    return s
end

local Paint, PaintVendor

function Shopping.AddCraft(spell, count)
    count = math.max(1, math.floor(tonumber(count) or 1))
    local crafts = List().crafts
    crafts[spell] = (crafts[spell] or 0) + count
    Shopping.Open(true)
end

-- Steps of a profession's road onto the list: each recipe is raised to what
-- the steps given need of it, summed where one recipe makes two steps, and
-- left as it is where the list already has that many or more. So the step
-- in hand and then the whole road, or either one twice, list each craft
-- once, and a count raised by hand is kept. The list opens once.
local function Want(steps)
    local want = {}
    for _, step in ipairs(steps) do
        local spell = step.recipe.spell
        want[spell] = (want[spell] or 0) + math.max(1, math.floor(tonumber(step.crafts) or 1))
    end
    return want
end

function Shopping.TopUp(steps)
    local crafts = List().crafts
    for spell, count in pairs(Want(steps)) do
        crafts[spell] = math.max(crafts[spell] or 0, count)
    end
    Shopping.Open(true)
end

-- Whether the list already has every craft of these steps at what they
-- need or more, so TopUp would change nothing.
function Shopping.Listed(steps)
    local crafts, any = List().crafts, false
    for spell, count in pairs(Want(steps)) do
        if (crafts[spell] or 0) < count then return false end
        any = true
    end
    return any
end

-- The buttons that put a road's steps on the list, each with its steps:
-- each says whether the list has them all, and says it again whenever the
-- list changes. A button has SetListed(on).
local tracked = {}
function Shopping.Track(button, steps)
    tracked[button] = steps
    button:SetListed(Shopping.Listed(steps))
end

function Shopping.AddItem(item, count)
    count = math.max(1, math.floor(tonumber(count) or 1))
    local items = List().items
    items[item] = (items[item] or 0) + count
    Shopping.Open()
end

-- The recipe of one of your professions that makes an item, and that
-- profession's name, when the option to add such items as crafts is on.
function Shopping.CraftFor(item)
    if not ns.OptionOn("shopping", "craftMats") then return nil end
    for _, p in ipairs(Professions.Mine()) do
        local recipe = Professions.MadeBy(p.line, item)
        if recipe then return recipe, p.name end
    end
    return nil
end

local function Recipe(spell)
    return ns.ProfWindow and ns.ProfWindow.RecipeFor(spell)
end

-- A recipe you know in one of your own professions that makes an item, where
-- making it is how you'd come by it (not a leather that's skinned as it is);
-- `gathered`: any that makes it, a leather from the one below it too.
local function KnownMaker(mine, item, gathered)
    for _, p in ipairs(mine) do
        local recipe = (gathered and Professions.MadeBy or Professions.Makes)(p.line, item)
        if recipe then
            local seen = Professions.Remembered(p.line)
            if (type(seen) == "table" and type(seen.known) == "table" and seen.known[recipe.spell])
                or (Compat.KnowsRecipe and Compat.KnowsRecipe(recipe.spell)) then
                return recipe
            end
        end
    end
end

-- What everything on the list needs, by item: each craft's reagents times
-- how many, and the other items themselves. A craft's material you can make
-- yourself is made rather than bought, all the way down: what the crafts
-- need of it, less what you have and what a craft of it you listed makes,
-- in crafts of its recipe, whose own materials are needed instead. Returns
-- what to get by item; what's made, { item, recipe, crafts } by item; and
-- the materials you could make but chose to buy.
local BUSY = {}
local function Needs()
    local s = List()
    local bought = s.bought or {}
    local base = {}
    for spell, count in pairs(s.crafts) do
        local recipe = Recipe(spell)
        for _, reagent in ipairs(recipe and recipe.reagents or {}) do
            base[reagent.item] = (base[reagent.item] or 0) + reagent.count * count
        end
    end
    -- Each material looked at once a call. One made from something made from
    -- it isn't made: a loop has nowhere to start.
    local mine, opens, buying = nil, {}, {}
    local function Opens(item)
        local known = opens[item]
        if known == BUSY then return nil, true end
        if known ~= nil then return known or nil end
        opens[item] = BUSY
        mine = mine or Professions.Mine()
        local recipe = KnownMaker(mine, item)
        if recipe and bought[item] then recipe, buying[item] = nil, true end
        for _, reagent in ipairs(recipe and recipe.reagents or {}) do
            local _, loop = Opens(reagent.item)
            if loop then recipe = nil break end
        end
        opens[item] = recipe or false
        return recipe
    end
    local function Have(item, recipe)
        return Compat.ItemCount(item, true) + (s.crafts[recipe.spell] or 0) * math.max(1, recipe.makes or 1)
    end
    -- Over again until the counts hold: a material can be wanted both by a
    -- craft and by another made material, one level further down.
    local made, need = {}, base
    for _ = 1, 8 do
        need = {}
        for item, count in pairs(base) do need[item] = count end
        for item, crafts in pairs(made) do
            for _, reagent in ipairs(opens[item].reagents) do
                need[reagent.item] = (need[reagent.item] or 0) + reagent.count * crafts
            end
        end
        local changed = false
        for item in pairs(made) do
            if not need[item] then made[item], changed = nil, true end
        end
        for item, count in pairs(need) do
            local recipe = Opens(item)
            if recipe then
                local crafts = math.ceil(math.max(0, count - Have(item, recipe)) / math.max(1, recipe.makes or 1))
                if crafts ~= (made[item] or 0) then
                    made[item], changed = crafts > 0 and crafts or nil, true
                end
            end
        end
        if not changed then break end
    end
    -- A leather that's skinned as it is is bought, unless what you hold of the
    -- leather it's made from covers all that's short of it, once everything
    -- else has taken what it needs of that: then it's made, and never from
    -- leather bought for it. All of it or none, so it's on one line; one
    -- level, as the leather below is only ever what you hold.
    local held = {}
    local gathered = ns.ProfessionData.gathered or {}
    local short = {}
    for item in pairs(need) do
        if gathered[item] and not made[item] then short[#short + 1] = item end
    end
    table.sort(short)
    for _, item in ipairs(short) do
        mine = mine or Professions.Mine()
        local recipe = KnownMaker(mine, item, true)
        local crafts = recipe and math.ceil(math.max(0, need[item] - Have(item, recipe)) / math.max(1, recipe.makes or 1)) or 0
        local covered = crafts > 0
        for _, reagent in ipairs(covered and recipe.reagents or {}) do
            if Compat.ItemCount(reagent.item, true) - (need[reagent.item] or 0) < reagent.count * crafts then covered = false break end
        end
        if covered and bought[item] then
            buying[item] = true
        elseif covered then
            made[item], opens[item], held[item] = crafts, recipe, true
            for _, reagent in ipairs(recipe.reagents) do
                need[reagent.item] = (need[reagent.item] or 0) + reagent.count * crafts
            end
        end
    end
    -- What's made comes off what's to get; what you have of it is still used.
    local making = {}
    for item, crafts in pairs(made) do
        making[item] = { item = item, recipe = opens[item], crafts = crafts, held = held[item] }
        local have = Compat.ItemCount(item, true)
        need[item] = have > 0 and math.min(have, need[item] or 0) or nil
    end
    for item, count in pairs(s.items) do need[item] = (need[item] or 0) + count end
    return need, making, buying
end

-- A unit price for an item: the vendor's if a vendor sells it, else its
-- auction price, else none. ItemPrices is the one way jsal.ui prices items.
local function PriceOf(item)
    return ns.ItemPrices.Of(item)
end

-- What vendors charged this character, by vendor and item, where it wasn't
-- the data's price: a reputation's discount, which the game takes off at
-- the vendor and says nowhere else. Read off the vendor's own window at
-- each visit, so a standing that changes is seen there next time.
local function Charged()
    local c = ns.char.vendorPrices
    if type(c) ~= "table" then
        c = {}
        ns.char.vendorPrices = c
    end
    return c
end

-- A merchant row's price for one, and its item.
local function MerchantUnit(i)
    local item = GetMerchantItemID and GetMerchantItemID(i)
    local price, stack
    local info = C_MerchantFrame and C_MerchantFrame.GetItemInfo and C_MerchantFrame.GetItemInfo(i)
    if info then
        price, stack = info.price, info.stackCount
    elseif GetMerchantItemInfo then
        local _, _, p, q = GetMerchantItemInfo(i)
        price, stack = p, q
    end
    if not (item and price and price > 0) then return nil end
    return item, price / math.max(1, stack or 1)
end

-- The vendor whose window is open: what it asks for the items the data
-- prices, kept where that differs. Nothing is kept for a vendor at full price.
local function LearnVendor()
    local guid = Compat.GUID and Compat.GUID("npc")
    local npc = type(guid) == "string" and tonumber(guid:match("^Creature%-.-%-.-%-.-%-.-%-(%d+)%-"))
    if not npc then return end
    local all = Charged()
    local kept = type(all[npc]) == "table" and all[npc] or {}
    for i = 1, (GetMerchantNumItems and GetMerchantNumItems() or 0) do
        local item, unit = MerchantUnit(i)
        local full = item and Professions.IsVendor(item)
        if full then kept[item] = math.abs(unit - full) >= 0.01 and unit or nil end
    end
    all[npc] = next(kept) and kept or nil
end

-- What a vendor will ask this character for one: what that vendor last
-- charged, else the data's price.
function Shopping.VendorPrice(item, npc)
    local seen = npc and Charged()[npc]
    local unit = type(seen) == "table" and tonumber(seen[item])
    return unit or Professions.IsVendor(item)
end

---------------------------------------------------------------------------
-- The window.
---------------------------------------------------------------------------
local frame, box, qty
local rows = {}

-- A quiet link: words that light up under the pointer. `under` draws a
-- thin line beneath them, for one that's read on a hover.
local function Link(parent, words, under)
    local b = CreateFrame("Button", nil, parent)
    b.text = Style.Text(b, 12, "muted")
    b.text:SetPoint("CENTER")
    if under then
        b.line = b:CreateTexture(nil, "ARTWORK")
        b.line:SetColorTexture(Style.Color("lineStrong"))
        b.line:SetPoint("BOTTOMLEFT")
        b.line:SetPoint("BOTTOMRIGHT")
        b.line:SetHeight(1)
    end
    function b:SetLabel(text)
        self.label = text
        self.text:SetText(text)
        self:SetSize(Style.Wide(self.text, #text * 7) + 2, 18)
    end
    b:SetScript("OnEnter", function(self) self.text:SetTextColor(Style.Color("text")) end)
    b:SetScript("OnLeave", function(self) self.text:SetTextColor(Style.Color("muted")) end)
    b:SetLabel(words)
    return b
end

-- Less or more, at one end of a count's pill.
local function Sign(pill, glyph, side)
    local b = CreateFrame("Button", nil, pill)
    b:SetSize(26, 22)
    b:SetPoint(side)
    b.text = Style.Text(b, 14, "secondary", nil, true)
    b.text:SetPoint("CENTER")
    b.text:SetText(glyph)
    b:SetScript("OnEnter", function(self) self.text:SetTextColor(Style.Color("gold")) end)
    b:SetScript("OnLeave", function(self) self.text:SetTextColor(Style.Color("secondary")) end)
    return b
end

-- What a row adds to the game's tooltip: its note, and what a right-click
-- does.
local function RowTip(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if self.item then GameTooltip:SetItemByID(self.item) elseif self.spell then GameTooltip:SetSpellByID(self.spell) end
    if self.note then GameTooltip:AddLine(self.note, Style.Color("text")) end
    if self.drop then GameTooltip:AddLine(self.dropTip or "Right-click to take it off the list", Style.Color("muted")) end
    GameTooltip:Show()
end

-- A row is one of three things. Something you put on the list, a craft or an
-- item: its count in a pill, with less and more either side (less than one
-- takes it off, and so does a right-click). A material you'll make for the
-- crafts, muted: its count follows the list, so there's no pill, and "Buy it
-- instead" puts it back with what's to get. Or something still to get, in a
-- group's card: how many more, with a bar for how much of it you have.
local function Row(i)
    local r = rows[i]
    if r then return r end
    r = CreateFrame("Frame", nil, frame)
    r:SetSize(WIDTH - PAD * 2, ROW_H)
    -- Over a group's card, which is the window's child as it is.
    r:SetFrameLevel((frame:GetFrameLevel() or 0) + 3)
    r.rule = r:CreateTexture(nil, "BORDER")
    r.rule:SetColorTexture(Style.Color("line"))
    r.rule:SetPoint("TOPLEFT", 1, 0)
    r.rule:SetPoint("TOPRIGHT", -1, 0)
    r.rule:SetHeight(Compat.OnePixel(r))
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(20, 20)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.step = CreateFrame("Frame", nil, r)
    r.step:SetSize(STEP_W, 22)
    r.step:SetPoint("RIGHT")
    Style.PillBox(r.step, "titleBar", "lineStrong")
    r.count = Style.Text(r.step, 13, "text", nil, true)
    r.count:SetPoint("CENTER")
    r.minus = Sign(r.step, "-", "LEFT")
    r.plus = Sign(r.step, "+", "RIGHT")
    r.status = Style.Text(r, 12, "muted")
    r.status:SetPoint("RIGHT", r.step, "LEFT", -10, 0)
    r.status:SetJustifyH("RIGHT")
    r.made = Style.Text(r, 13, "muted", nil, true)
    r.made:SetPoint("CENTER", r.step, "CENTER")
    r.buy = Link(r, "Buy it instead")
    r.buy:SetPoint("RIGHT", r.step, "LEFT", -10, 0)
    r.more = Style.Text(r, 14, "text", nil, true)
    r.more:SetPoint("RIGHT", -CARD_PAD, 0)
    r.more:SetJustifyH("RIGHT")
    r.bar = CreateFrame("Frame", nil, r)
    r.bar:SetSize(BAR_W, 4)
    r.bar:SetPoint("RIGHT", -(CARD_PAD + 44), 0)
    Style.Fill(r.bar, "line")
    r.fill = r.bar:CreateTexture(nil, "ARTWORK")
    r.fill:SetColorTexture(Style.Color("gold"))
    r.fill:SetPoint("TOPLEFT")
    r.fill:SetPoint("BOTTOMLEFT")
    r.name = Style.Text(r, 13, "text")
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    r:EnableMouse(true)
    r:SetScript("OnEnter", RowTip)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" and self.drop then self.drop() end
    end)
    r.glow = Style.Hover(r, 6)
    rows[i] = r
    return r
end

local function Heading(text, note)
    local h = CreateFrame("Frame", nil, frame)
    h:SetSize(WIDTH - PAD * 2, 18)
    h.title = Style.Text(h, 12, "gold", nil, true)
    h.title:SetPoint("LEFT")
    h.title:SetText(text)
    h.note = Style.Text(h, 12, "muted")
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

local function Field(parent, width, numeric) return Style.Field(parent, width, numeric) end

-- Dragging is done here, not by the game's StartMoving, which has twice
-- thrown this window across the screen as it was picked up. The window
-- follows the pointer by the spot it's held at, and is pinned by its top
-- left corner, so a list that grows or shrinks does so downward and its
-- title bar stays where it was put.
local function DragStop()
    local held = frame.held
    if not held then return end
    frame.held = nil
    frame:SetScript("OnUpdate", nil)
    if held.left then
        ns.db.shoppingAt = { "TOPLEFT", "BOTTOMLEFT", held.left, held.top }
        frame.beside = nil
    end
end

local function DragTo()
    local held = frame.held
    local x, y = GetCursorPosition()
    local scale = frame:GetEffectiveScale()
    if not (held and x and y and scale and scale > 0) then return end
    local left, top = x / scale - held.x, y / scale + held.y
    -- Kept whole on the screen, where its size is known.
    local wide = (UIParent:GetWidth() or 0) * (UIParent:GetEffectiveScale() or 0) / scale
    local tall = (UIParent:GetHeight() or 0) * (UIParent:GetEffectiveScale() or 0) / scale
    if wide > 0 and tall > 0 then
        left = math.max(0, math.min(left, wide - (frame:GetWidth() or 0)))
        top = math.min(tall, math.max(top, frame:GetHeight() or 0))
    end
    held.left, held.top = left, top
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
end

local function DragStart()
    local x, y = GetCursorPosition()
    local scale, left, top = frame:GetEffectiveScale(), frame:GetLeft(), frame:GetTop()
    if not (x and y and left and top and scale and scale > 0) then return end
    -- Where on the window the pointer has hold of it: across from its left
    -- edge and down from its top.
    frame.held = { x = x / scale - left, y = top - y / scale }
    frame:SetScript("OnUpdate", function()
        if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then return DragStop() end
        DragTo()
    end)
end

local function Build()
    frame = CreateFrame("Frame", "jsalUIShoppingList", UIParent)
    frame:SetWidth(WIDTH)
    -- On the layer of jsal.ui's main window, above other addons' unit
    -- frames and bars, which would draw over it on the one below.
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", DragStart)
    frame:SetScript("OnDragStop", DragStop)
    frame:SetScript("OnHide", DragStop)
    frame:Hide()
    Style.Box(frame, 6, "window", "lineStrong")
    Style.Shadow(frame)
    local bar = CreateFrame("Frame", nil, frame)
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("TOPRIGHT")
    bar:SetHeight(36)
    Style.Cap(bar, 6, "titleBar")
    Style.Rule(bar, "BOTTOM", "line")
    local mark = bar:CreateTexture(nil, "ARTWORK")
    mark:SetTexture("Interface\\AddOns\\jsalUI\\Media\\Logo")
    mark:SetSize(18, 18)
    mark:SetPoint("LEFT", 12, 0)
    local divider = bar:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(Style.Color("lineStrong"))
    divider:SetSize(Compat.OnePixel(bar), 16)
    divider:SetPoint("LEFT", mark, "RIGHT", 10, 0)
    local title = Style.Text(bar, 13, "text", nil, true)
    title:SetPoint("LEFT", divider, "RIGHT", 10, 0)
    title:SetText("Shopping list")
    Style.CloseButton(bar, 36, function() frame:Hide() end):SetPoint("TOPRIGHT")
    -- The bar is the handle for moving the window.
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", DragStart)
    bar:SetScript("OnDragStop", DragStop)

    box = Field(frame, WIDTH - PAD * 2 - 46 - 60 - 12)
    box.well:SetPoint("TOPLEFT", PAD, -(36 + 12))
    box.hint = Style.Text(box.well, 12, "muted")
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
    -- Something you can craft goes on as its craft, with a way back to
    -- buying the item itself.
    local undone
    frame.undo = CreateFrame("Button", nil, frame)
    frame.undo:SetSize(96, 16)
    frame.undo:SetPoint("TOPRIGHT", box.well, "BOTTOMRIGHT", 46 + 60 + 12, -3)
    local undoText = Style.Text(frame.undo, 12, "text")
    undoText:SetPoint("RIGHT")
    undoText:SetText("Buy it instead")
    Style.Hover(frame.undo)
    frame.undo:Hide()
    frame.undo:SetScript("OnClick", function()
        local u = undone
        frame.undo:Hide()
        frame.message:SetText("")
        if not u then return end
        local crafts = List().crafts
        crafts[u.spell] = (crafts[u.spell] or 0) > u.crafts and crafts[u.spell] - u.crafts or nil
        undone = nil
        Shopping.AddItem(u.item, u.count)
    end)
    local function Add()
        local item = ItemFromText(box:GetText())
        frame.undo:Hide()
        undone = nil
        if not item then
            frame.message:SetText("That isn't an item the game knows yet: shift-click it instead.")
            return
        end
        frame.message:SetText("")
        box:SetText("")
        box:ClearFocus()
        local count = math.max(1, math.floor(tonumber(qty:GetText()) or 1))
        qty:SetText("1")
        local recipe, profession = Shopping.CraftFor(item)
        if recipe then
            local crafts = math.ceil(count / math.max(1, recipe.makes or 1))
            undone = { spell = recipe.spell, crafts = crafts, item = item, count = count }
            Shopping.AddCraft(recipe.spell, crafts)
            frame.message:SetText(("A %s craft: its mats are below."):format(profession))
            frame.undo:Show()
            return
        end
        Shopping.AddItem(item, count)
    end
    frame.add:SetScript("OnClick", Add)
    box:SetScript("OnEnterPressed", Add)
    qty:SetScript("OnEnterPressed", Add)
    frame.message = Style.Text(frame, 12, "gold")
    frame.message:SetPoint("TOPLEFT", box.well, "BOTTOMLEFT", 0, -4)
    frame.message:SetWidth(WIDTH - PAD * 2)

    frame.craftsHead = Heading("CRAFTS")
    frame.itemsHead = Heading("OTHER ITEMS")
    frame.buyHead = Heading("STILL TO GET", "more to get")
    -- What's still to get is a card a group, each with its heading and its
    -- total: what a vendor sells, and what comes from the auction house or
    -- the world. Along the foot of the vendor's: where to go for them.
    frame.groups = {}
    for i = 1, 2 do
        local g = CreateFrame("Frame", nil, frame)
        g:SetWidth(WIDTH - PAD * 2)
        Style.Box(g, 6, "well", "cardLine")
        g.title = Style.Text(g, 11, "muted", nil, true)
        g.title:SetPoint("TOPLEFT", CARD_PAD, -9)
        g.note = Style.Text(g, 12, "secondary")
        g.note:SetPoint("TOPRIGHT", -CARD_PAD, -9)
        g.note:SetJustifyH("RIGHT")
        g.strip = CreateFrame("Frame", nil, g)
        g.strip:SetPoint("BOTTOMLEFT", 1, 1)
        g.strip:SetPoint("BOTTOMRIGHT", -1, 1)
        Style.Cap(g.strip, 5, "titleBar", "BOTTOM")
        Style.Rule(g.strip, "TOP", "cardLine")
        frame.groups[i] = g
    end
    -- Where to buy what a vendor sells: a line or two along that card's
    -- foot. A click anywhere on one pins its vendor on the map.
    frame.shopLines = {}
    for i = 1, 2 do
        local b = CreateFrame("Button", nil, frame)
        b:SetSize(WIDTH - PAD * 2 - CARD_PAD * 2, 18)
        b:SetFrameLevel((frame:GetFrameLevel() or 0) + 3)
        b.link = Style.Text(b, 12, "gold", nil, true)
        b.link:SetPoint("RIGHT")
        b.link:SetText("show on map")
        b.text = Style.Text(b, 12, "muted")
        b.text:SetPoint("LEFT")
        b.text:SetPoint("RIGHT", b.link, "LEFT", -8, 0)
        b.text:SetJustifyH("LEFT")
        b.text:SetWordWrap(false)
        b:SetScript("OnClick", function(self)
            if self.shop and ns.Trainers then ns.Trainers.Pin(self.shop) end
        end)
        b:SetScript("OnEnter", function(self) self.link:SetTextColor(Style.Color("goldHover")) end)
        b:SetScript("OnLeave", function(self) self.link:SetTextColor(Style.Color("gold")) end)
        frame.shopLines[i] = b
    end
    -- What you already have enough of: small pictures on one line, dimmed.
    -- Point at one for what it is and how many you have.
    frame.enough = CreateFrame("Frame", nil, frame)
    frame.enough:SetSize(WIDTH - PAD * 2, 22)
    frame.enough.label = Style.Text(frame.enough, 12, "muted")
    frame.enough.label:SetPoint("LEFT")
    frame.enough.label:SetText("You have enough of")
    frame.enough.icons = {}
    for i = 1, MAX_ENOUGH do
        local e = CreateFrame("Frame", nil, frame.enough)
        e:SetSize(18, 18)
        e:SetPoint("LEFT", frame.enough.label, "RIGHT", 10 + (i - 1) * 22, 0)
        e:SetAlpha(0.55)
        e.icon = e:CreateTexture(nil, "ARTWORK")
        e.icon:SetAllPoints()
        e.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        e:EnableMouse(true)
        e:SetScript("OnEnter", RowTip)
        e:SetScript("OnLeave", function() GameTooltip:Hide() end)
        frame.enough.icons[i] = e
    end
    frame.enough.more = Style.Text(frame.enough, 12, "muted")
    -- "and 3 more crafts": what a list is too long to show still counts, and says so.
    frame.more = {}
    for i = 1, 3 do frame.more[i] = Style.Text(frame, 11, "muted") end
    frame.empty = Style.Text(frame, 12, "muted")
    frame.empty:SetWidth(WIDTH - PAD * 2)
    frame.empty:SetText("Nothing on the list yet. Add an item above, a craft from the profession window, or the road from jsal.ui's profession panel.")
    frame.rule = frame:CreateTexture(nil, "BORDER")
    frame.rule:SetColorTexture(Style.Color("line"))
    frame.rule:SetSize(WIDTH - PAD * 2, Compat.OnePixel(frame))
    frame.total = Style.Text(frame, 12, "muted")
    -- Where the prices come from, read on a hover.
    frame.about = Link(frame, "about these prices", true)
    frame.about:SetPoint("LEFT", frame.total, "RIGHT", 10, 0)
    frame.about:HookScript("OnEnter", function(self)
        if not self.tip then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(self.tip, Style.Color("text"))
        GameTooltip:Show()
    end)
    frame.about:HookScript("OnLeave", function() GameTooltip:Hide() end)
    frame.clear = Link(frame, "Clear")
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
end

-- Where the list was last dragged to, or a little right of centre.
local function PlaceSaved()
    frame:ClearAllPoints()
    frame:SetFrameStrata("HIGH")
    local at = ns.db.shoppingAt
    if type(at) == "table" and at[1] then
        frame:SetPoint(at[1], UIParent, at[2], at[3], at[4])
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 300, 60)
    end
    frame.beside = nil
end

-- Something added from a profession window opens the list right beside it
-- (beside jsal.ui's profession panel when that's showing), on the same
-- layer, so it never opens hidden behind them.
local function PlaceBeside()
    local panel, game = jsalUIProfessionPanel, ProfessionsFrame
    local next = (panel and panel:IsShown() and panel) or (game and game:IsShown() and game)
    if not next then return false end
    local right, top = next:GetRight(), next:GetTop()
    if not (right and top) then return false end
    -- Beside the game's window, after the profession tabs on its right edge.
    local reach = (next == game and ns.TabsReach) and ns.TabsReach(game, frame) or 0
    -- Placed on the screen there, not hung off the window: once the window
    -- closes the game can take its place away, and the list would be left
    -- with none to be dragged from.
    local scale = next:GetEffectiveScale() / frame:GetEffectiveScale()
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", right * scale + 6 + reach, top * scale)
    frame:SetFrameStrata(next:GetFrameStrata())
    frame:Raise()
    frame.beside = true
    return true
end

---------------------------------------------------------------------------
-- Who sells it. Under FROM A VENDOR, one line says where to go: the vendor of your side that
-- sells the most of what's still to get, the nearest of those; and a second line for the rest,
-- when one vendor doesn't have it all. A click pins them on the map. The vendors are the ones
-- players opened on Forever, shipped in ProfessionData.
---------------------------------------------------------------------------
local WORDS = { [3] = "three", [4] = "four", [5] = "five", [6] = "six", [7] = "seven", [8] = "eight", [9] = "nine" }

-- The best vendor for a list of item IDs: its shop ({ name, map, x, y }), how many of the items
-- it sells, and those it doesn't. Nil when no vendor of your side is known to sell any.
function Shopping.Vendor(items)
    local data = ns.ProfessionData
    if not (data and type(data.sellers) == "table" and type(data.shops) == "table") or #items == 0 then return nil end
    local faction = UnitFactionGroup("player")
    local mine = faction == "Alliance" and 1 or faction == "Horde" and 2 or nil
    local has = {}
    for _, item in ipairs(items) do
        for npc in (data.sellers[item] or ""):gmatch("%d+") do
            npc = tonumber(npc)
            local shop = data.shops[npc]
            if shop and (shop[5] == 0 or not mine or shop[5] == mine) then
                has[npc] = has[npc] or {}
                has[npc][item] = true
            end
        end
    end
    local best, bestCount, bestFar
    for npc, sells in pairs(has) do
        local count = 0
        for _ in pairs(sells) do count = count + 1 end
        local shop = data.shops[npc]
        local far = ns.Trainers and ns.Trainers.Distance({ map = shop[2], x = shop[3], y = shop[4] }) or 1e9
        if not best or count > bestCount or (count == bestCount and (far < bestFar or (far == bestFar and npc < best))) then
            best, bestCount, bestFar = npc, count, far
        end
    end
    if not best then return nil end
    local shop, rest = data.shops[best], {}
    for _, item in ipairs(items) do
        if not has[best][item] then rest[#rest + 1] = item end
    end
    return { name = shop[1], map = shop[2], x = shop[3], y = shop[4], npc = best, sells = has[best] }, bestCount, rest
end

-- The lines for a list of items still to buy from a vendor: each { text, shop }, two at most.
function Shopping.WhereToBuy(items)
    local lines = {}
    local function At(shop)
        local zone = ns.Trainers and ns.Trainers.Zone(shop)
        return shop.name .. (zone and (", " .. zone) or "")
    end
    local shop, count, rest = Shopping.Vendor(items)
    if not shop then return lines end
    local of = #items
    local text
    if count < of then
        text = ("%d of %d at %s"):format(count, of, At(shop))
    elseif of == 1 then
        text = "At " .. At(shop)
    elseif of == 2 then
        text = "Both at " .. At(shop)
    else
        text = ("All %s at %s"):format(WORDS[of] or tostring(of), At(shop))
    end
    lines[1] = { text = text, shop = shop }
    if #rest > 0 then
        local second, n = Shopping.Vendor(rest)
        if second then
            lines[2] = { text = (n < #rest and ("%d more at %s"):format(n, At(second))
                or (#rest == 1 and "The other at " or "The rest at ") .. At(second)), shop = second }
        end
    end
    return lines
end

local function Place(region, y)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -y)
    region:Show()
end

local function ItemName(item) return Compat.ItemName(item) or "..." end

local function PaintList()
    if not frame then return end
    local s = List()
    local used = 0
    local y = 36 + 12 + 26 + 18
    -- The next row: `counted`, one you put on the list, with its pill; else
    -- one still to get, in a group's card.
    -- `worked`: a material to make, worked out from the crafts.
    local function Next(counted, worked)
        used = used + 1
        local r = Row(used)
        r.step:SetShown(counted and not worked)
        r.status:SetShown(counted and not worked)
        r.made:SetShown(worked and true or false)
        r.buy:SetShown(worked and true or false)
        r.rule:SetShown(not counted)
        r.bar:SetShown(not counted)
        r.more:SetShown(not counted)
        r.icon:ClearAllPoints()
        r.icon:SetPoint("LEFT", counted and 0 or CARD_PAD, 0)
        r.name:ClearAllPoints()
        r.name:SetPoint("LEFT", r.icon, "RIGHT", 8, 0)
        r.name:SetPoint("RIGHT", worked and r.buy or (counted and r.status or r.bar), "LEFT", -8, 0)
        r.name:SetTextColor(Style.Color(worked and "muted" or "text"))
        r.drop, r.note, r.dropTip = nil, nil, nil
        -- The light under the pointer: past the row's ends, or within its card.
        if r.glow then
            r.glow:ClearAllPoints()
            r.glow:SetPoint("TOPLEFT", counted and -6 or 1, 0)
            r.glow:SetPoint("BOTTOMRIGHT", counted and 6 or -1, 0)
        end
        r:SetAlpha(1)
        return r
    end
    -- Its count, and what less, more and a right-click do.
    local function Count(r, list, key)
        r.count:SetText(list[key])
        r.minus:SetScript("OnClick", function()
            list[key] = (list[key] or 1) > 1 and list[key] - 1 or nil
            Paint()
        end)
        r.plus:SetScript("OnClick", function()
            list[key] = (list[key] or 0) + 1
            Paint()
        end)
        r.drop = function()
            list[key] = nil
            Paint()
        end
    end

    -- A list longer than its rows says how many more there are: they were left out without
    -- a word, and still counted in what's left to get.
    local mores = 0
    local function More(n, words)
        if n <= 0 then return end
        mores = mores + 1
        local t = frame.more[mores]
        t:SetText(words:format(n))
        Place(t, y + 2)
        y = y + 20
    end

    -- Making or buying a material the crafts need, and painting it so.
    local function Buy(item, on)
        local list = List()
        list.bought = list.bought or {}
        list.bought[item] = on or nil
        Paint()
    end
    local needs, making, buying = Needs()

    -- Crafts, by name; then what's made for them, by item.
    local crafts = {}
    for spell, count in pairs(s.crafts) do crafts[#crafts + 1] = { spell = spell, count = count, recipe = Recipe(spell) } end
    table.sort(crafts, function(a, b) return a.spell < b.spell end)
    local made = {}
    for _, m in pairs(making) do made[#made + 1] = m end
    table.sort(made, function(a, b) return a.item < b.item end)
    for _, m in ipairs(made) do crafts[#crafts + 1] = { spell = m.recipe.spell, count = m.crafts, recipe = m.recipe, made = m } end
    if #crafts > 0 then
        frame.craftsHead.note:SetText(#crafts)
        Place(frame.craftsHead, y)
        y = y + 22
        for i, c in ipairs(crafts) do
            if i > MAX_CRAFTS then break end
            local r = Next(true, c.made ~= nil)
            Place(r, y)
            r.item, r.spell = c.recipe and c.recipe.item, c.spell
            r.icon:SetTexture((r.item and Compat.ItemIcon(r.item)) or select(2, Compat.SpellInfo(c.spell)))
            r.name:SetText((r.item and Compat.ItemName(r.item)) or (Compat.SpellInfo(c.spell)) or "...")
            r.status:SetText("")
            if c.made then
                local item = c.made.item
                r.made:SetText(c.count)
                r.note = c.made.held and "Made for the crafts above, from what you have."
                    or "Made for the crafts above: what it takes is under Still to get."
                r.drop, r.dropTip = function() Buy(item, true) end, "Right-click to buy it instead"
                r.buy:SetScript("OnClick", r.drop)
            else
                Count(r, s.crafts, c.spell)
            end
            y = y + ROW_H
        end
        More(#crafts - MAX_CRAFTS, "and %d more not shown, counted below")
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
            local r = Next(true)
            Place(r, y)
            r.item, r.spell = e.item, nil
            r.icon:SetTexture(Compat.ItemIcon(e.item))
            r.name:SetText(ItemName(e.item))
            local have = Compat.ItemCount(e.item, true)
            local enough = have >= e.count
            r.status:SetText(enough and (Style.Tint("green") .. "have %d|r"):format(have) or (Style.Tint("red") .. "have %d|r"):format(have))
            r:SetAlpha(enough and 0.5 or 1)
            Count(r, s.items, e.item)
            y = y + ROW_H
        end
        More(#items - MAX_ITEMS, "and %d more not shown, counted below")
        y = y + 6
    else
        frame.itemsHead:Hide()
    end

    -- Still to get: everything needed, less what you have. What a vendor
    -- sells, with its cost, and what comes from the auction house or the
    -- world are a card each; a row says how many more to get, as that's
    -- what you shop by, and its bar how much of it you have. What you
    -- already have enough of is small pictures under them.
    local vendor, other, enough = {}, {}, {}
    local count = ns.ItemPrices.Counting()
    local total, unpriced, vendorCost, auctionCost = 0, 0, 0, 0
    for item, need in pairs(needs) do
        local have = Compat.ItemCount(item, true)
        local e = { item = item, need = need, have = have, short = math.max(0, need - have), buying = buying[item] }
        if e.short == 0 then
            enough[#enough + 1] = e
        else
            local price, where = PriceOf(item)
            if not price then
                unpriced = unpriced + 1
            elseif where ~= "vendor" then
                auctionCost = auctionCost + price * e.short
            end
            local group = (price and where == "vendor") and vendor or other
            group[#group + 1] = e
        end
    end
    -- What's bought from a vendor costs what the vendor named for it asks.
    local toBuy = {}
    for _, e in ipairs(vendor) do toBuy[#toBuy + 1] = e.item end
    local whereToBuy = Shopping.WhereToBuy(toBuy)
    for _, e in ipairs(vendor) do
        local npc
        for _, line in ipairs(whereToBuy) do
            if line.shop.sells and line.shop.sells[e.item] then npc = line.shop.npc break end
        end
        vendorCost = vendorCost + math.floor(Shopping.VendorPrice(e.item, npc) * e.short + 0.5)
    end
    total = vendorCost + auctionCost
    local function Biggest(a, b)
        if a.short ~= b.short then return a.short > b.short end
        return a.item < b.item
    end
    table.sort(vendor, Biggest)
    table.sort(other, Biggest)
    table.sort(enough, function(a, b) return a.item < b.item end)
    local listed, groups, shopLines = 0, 0, 0
    local function Group(title, note, list, where)
        if #list == 0 or listed >= MAX_BUY then return end
        groups = groups + 1
        local g = frame.groups[groups]
        g.title:SetText(title)
        g.note:SetText(note or "")
        Place(g, y)
        local tall = HEAD_H
        for _, e in ipairs(list) do
            if listed >= MAX_BUY then break end
            listed = listed + 1
            local r = Next(false)
            Place(r, y + tall)
            r.item, r.spell = e.item, nil
            r.icon:SetTexture(Compat.ItemIcon(e.item))
            r.name:SetText(ItemName(e.item))
            r.more:SetText(e.short)
            r.fill:SetShown(e.have > 0)
            r.fill:SetWidth(math.max(1, BAR_W * math.min(1, e.have / e.need)))
            r.note = ("You have %d of %d."):format(e.have, e.need)
            if e.buying then
                local item = e.item
                r.drop, r.dropTip = function() Buy(item, false) end, "Right-click to make it instead"
            end
            tall = tall + ROW_H
        end
        -- Where to go for these, along the card's foot.
        local lines = 0
        for _, line in ipairs(where or {}) do
            local b = frame.shopLines[shopLines + 1]
            if not b then break end
            shopLines, lines = shopLines + 1, lines + 1
            b.shop = line.shop
            b.text:SetText(line.text)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + CARD_PAD, -(y + tall + 7 + (lines - 1) * 20))
            b:Show()
        end
        g.strip:SetShown(lines > 0)
        if lines > 0 then
            g.strip:SetHeight(lines * 20 + 12)
            tall = tall + lines * 20 + 12
        end
        g:SetHeight(tall)
        y = y + tall + 8
    end
    if #vendor + #other > 0 then
        Place(frame.buyHead, y)
        y = y + 24
        Group("FROM A VENDOR", vendorCost > 0 and Compat.Money(vendorCost) or nil, vendor, whereToBuy)
        Group("AUCTION HOUSE OR THE WORLD", auctionCost > 0 and ("about " .. Compat.Money(auctionCost)) or nil, other)
        More(#vendor + #other - listed, "and %d more not shown, counted in the total")
    else
        frame.buyHead:Hide()
    end
    if #enough > 0 then
        local shown = math.min(#enough, MAX_ENOUGH)
        for i, icon in ipairs(frame.enough.icons) do
            local e = enough[i]
            icon:SetShown(i <= shown)
            if i <= shown then
                icon.item = e.item
                icon.icon:SetTexture(Compat.ItemIcon(e.item))
                icon.note = ("You have %d of %d."):format(e.have, e.need)
            end
        end
        frame.enough.more:SetText(#enough > shown and ("+%d"):format(#enough - shown) or "")
        frame.enough.more:ClearAllPoints()
        frame.enough.more:SetPoint("LEFT", frame.enough.icons[shown], "RIGHT", 6, 0)
        Place(frame.enough, y + 2)
        y = y + 26
    else
        frame.enough:Hide()
    end
    for i = groups + 1, #frame.groups do frame.groups[i]:Hide() end
    for i = shopLines + 1, #frame.shopLines do frame.shopLines[i]:Hide() end
    for i = mores + 1, #frame.more do frame.more[i]:Hide() end
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
    local text
    if total > 0 then
        text = ("About |cffece6d6%s|r in all"):format(Compat.Money(total))
        if unpriced > 0 then text = text .. (" · %d not priced"):format(unpriced) end
    elseif unpriced > 0 then
        text = ("%d still to get, no price known yet"):format(unpriced)
    else
        text = "Nothing left to get"
    end
    frame.total:SetText(text)
    Place(frame.total, y + 4)
    -- Where an auction price comes from is read on a hover.
    frame.about.tip = auctionCost > 0 and ("Auction prices are from %s."):format(ns.ItemPrices.From(count)) or nil
    frame.about:SetShown(auctionCost > 0)
    frame.clear:ClearAllPoints()
    frame.clear:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -(y + 2))
    frame.clear:SetShown(not empty)
    frame:SetHeight(y + 26 + PAD)
end

-- Every change to the list (a row's less or more, Clear, an add) paints it,
-- and the vendor's pop-up follows. It kept offering what had been on the
-- list after Clear.
Paint = function()
    PaintList()
    if PaintVendor then PaintVendor() end
    for button, steps in pairs(tracked) do
        if button:IsShown() then button:SetListed(Shopping.Listed(steps)) end
    end
end

-- beside: opened by adding from a profession window. A list that's
-- already open stays where the player has it and just comes to the front.
function Shopping.Open(beside)
    if not Shopping.running then return end
    if not frame then
        Build()
        PlaceSaved()
        frame:Hide()
    end
    if frame:IsShown() then
        frame:Raise()
    elseif not (beside and PlaceBeside()) and frame.beside then
        PlaceSaved()
    end
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
    -- Along the form's bottom edge, across from Track Recipe: the top right
    -- holds the recipe's name and the game's favourite star.
    count.well:SetPoint("BOTTOMLEFT", form, "BOTTOMLEFT", 12, 8)
    detailButton:SetPoint("LEFT", count.well, "RIGHT", 6, 0)
    detailButton:SetScript("OnClick", function()
        if detailRecipe then Shopping.AddCraft(detailRecipe, count:GetText()) end
    end)
    hooksecurefunc(form, "Init", ns.Safe(Shopping, function(_, recipeInfo)
        detailRecipe = type(recipeInfo) == "table" and recipeInfo.recipeID or nil
        local show = Shopping.running and detailRecipe ~= nil and Recipe(detailRecipe) ~= nil
        detailButton:SetShown(show)
        count.well:SetShown(show)
    end))
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

function PaintVendor()
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
        Style.Box(vendorFrame, 6, "window", "lineStrong")
        Style.Shadow(vendorFrame, 12)
        vendorFrame.title = Style.Text(vendorFrame, 12, "gold", nil, true)
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
-- Starting.
---------------------------------------------------------------------------
function Shopping:OnEnable()
    local events = CreateFrame("Frame")
    for _, event in ipairs({ "ADDON_LOADED", "TRADE_SKILL_SHOW", "BAG_UPDATE_DELAYED", "MERCHANT_SHOW", "MERCHANT_UPDATE",
                             "MERCHANT_CLOSED", "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", "COMMODITY_SEARCH_RESULTS_UPDATED",
                             "AUCTION_ITEM_LIST_UPDATE", "ITEM_DATA_LOAD_RESULT", "GET_ITEM_INFO_RECEIVED" }) do
        pcall(events.RegisterEvent, events, event)
    end
    local naming = false
    events:SetScript("OnEvent", function(_, event, arg1)
        local ok, err = pcall(function()
            if event == "ADDON_LOADED" or event == "TRADE_SKILL_SHOW" then
                HookDetails()
            elseif event == "ITEM_DATA_LOAD_RESULT" or event == "GET_ITEM_INFO_RECEIVED" then
                -- An item's name comes a moment after it's first asked for.
                -- A row that read "..." stayed that way, as nothing painted
                -- the list again. Once for a burst of them.
                if frame and frame:IsShown() and not naming then
                    naming = true
                    Compat.After(0.3, function()
                        naming = false
                        if frame:IsShown() then xpcall(Paint, ns.Report) end
                    end)
                end
            elseif event == "BAG_UPDATE_DELAYED" then
                if frame and frame:IsShown() then Paint() end
                PaintVendor()
            elseif event == "MERCHANT_SHOW" or event == "MERCHANT_UPDATE" then
                Compat.After(0.2, function()
                    xpcall(LearnVendor, ns.Report)
                    xpcall(frame and frame:IsShown() and Paint or PaintVendor, ns.Report)
                end)
            elseif event == "MERCHANT_CLOSED" then
                if vendorFrame then vendorFrame:Hide() end
            else
                -- An auction house search: ItemPrices remembers its prices.
                ns.ItemPrices.OnAuctionEvent(event, arg1)
            end
        end)
        if not ok then ns.Report(err) end
    end)
    self.events = events
    -- Shift-clicking an item while the add box has the cursor puts it there.
    -- The game's shift-click calls ChatFrameUtil.InsertLink by that name.
    hooksecurefunc(ChatFrameUtil, "InsertLink", ns.Safe(Shopping, function(link)
        if box and box:HasFocus() and type(link) == "string" and link:find("|Hitem:") then box:SetText(link) end
    end))
    pcall(HookDetails)
end

function Shopping:OnDisable()
    if self.events then self.events:UnregisterAllEvents() end
    if frame then frame:Hide() end
    if vendorFrame then vendorFrame:Hide() end
end
