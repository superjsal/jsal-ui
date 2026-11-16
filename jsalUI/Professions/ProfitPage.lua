-- The Crafting profit page: every recipe your characters know, one row each,
-- with what it costs to make, what it sells for, the profit and when its
-- prices were seen. A click on a column's heading sorts by it, a second
-- click the other way (John, picking it: "A but with sorting"). Above the
-- list: a button per profession, a switch to hide what loses money, and a
-- search box. "+" on a row adds the craft to the shopping list. Profit only:
-- no levelling view ("this is purely profit").
local _, ns = ...
local Style, Compat, Window = ns.Style, ns.Compat, ns.Window

local ROW_H, LIST_TOP, FOOT_H = 30, 150, 44
local DAY = 86400

-- The columns: what each sorts by, its heading, and the x its text ends at
-- (the name starts at 32, after the icon).
local COLUMNS = { { key = "name", label = "RECIPE", x = 32, left = true },
                  { key = "cost", label = "TO MAKE", x = 400 }, { key = "sells", label = "SELLS FOR", x = 490 },
                  { key = "profit", label = "PROFIT", x = 580 }, { key = "age", label = "SEEN", x = 680 } }
-- Columns read lowest first when first clicked: names, costs, and the most
-- recently seen prices. The list opens with the highest profit first.
local LOW_FIRST = { name = true, cost = true, age = true }

-- How the page is set: sort, direction, profession, hiding what loses
-- money. Kept for the account, so it opens as you left it.
local function View()
    local v = type(ns.db.craftView) == "table" and ns.db.craftView or {}
    ns.db.craftView = v
    return v
end

local function Sort(v)
    local s = v.sort
    if type(s) ~= "table" or not s.key then
        s = { key = "profit", desc = true }
        v.sort = s
    end
    return s
end

---------------------------------------------------------------------------
-- Words and numbers.
---------------------------------------------------------------------------
local function Money(c)
    if not c then return "" end
    if c < 0 then return "-" .. Compat.Money(-c) end
    return Compat.Money(c)
end

local function Ago(seconds)
    local days = math.floor((seconds or 0) / DAY)
    if days < 1 then return "today" end
    if days == 1 then return "yesterday" end
    return days .. " days ago"
end

local function ItemInfo(item)
    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local name, _, quality = get(item)
    if not name and C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(item) end
    return name, quality
end

-- A row's name, coloured by the item's quality.
local function Name(row)
    if row.name then return row.name, row.colour end
    local name, quality
    if row.item then name, quality = ItemInfo(row.item) end
    if not name then name = Compat.SpellInfo(row.spell) end
    local colour = Style.Quality(quality)
    if name then row.name, row.colour = name, colour end
    return name or "...", colour
end

local function ItemName(item)
    return Compat.ItemName(item) or "an item"
end

-- What a row is sorted by in a column, or nil when it has none.
local function Value(row, key)
    if key == "name" then return (Name(row)):lower() end
    if key == "age" then return row.cost and row.sells and row.age or nil end
    return row[key]
end

local function SortRows(rows, s)
    table.sort(rows, function(a, b)
        local x, y = Value(a, s.key), Value(b, s.key)
        if x == nil or y == nil then
            if x ~= nil or y ~= nil then return x ~= nil end
        elseif x ~= y then
            if s.desc then return x > y end
            return x < y
        end
        return (Name(a)):lower() < (Name(b)):lower()
    end)
end

---------------------------------------------------------------------------
-- The page's parts.
---------------------------------------------------------------------------
local P = { rows = {}, chips = {}, heads = {} }

local function Tooltip(self)
    local row = self.data
    if not row then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if row.item then GameTooltip:SetItemByID(row.item) else GameTooltip:SetSpellByID(row.spell) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("To make one:", 0.89, 0.69, 0.29)
    for _, part in ipairs(row.parts or {}) do
        local how = part.how == "craft" and "you make it" or part.how
        local right = part.each and (Money(math.floor(part.each * part.count + 0.5)) .. "  " .. how) or "not seen"
        GameTooltip:AddDoubleLine(part.count .. " " .. ItemName(part.item), right, 0.93, 0.9, 0.84, 0.6, 0.59, 0.53)
    end
    if row.who and #row.who > 0 then
        GameTooltip:AddLine("Known by " .. table.concat(row.who, ", "), 0.6, 0.59, 0.53, true)
    end
    if ns.Shopping and ns.Shopping.running then
        GameTooltip:AddLine("+ adds one to your shopping list; Shift-click, five.", 0.6, 0.59, 0.53, true)
    end
    GameTooltip:Show()
end

local function Row(i)
    local r = P.rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, P.child)
    r:SetSize(P.width - 8, ROW_H)
    r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(22, 22)
    r.icon:SetPoint("LEFT", 0, 0)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.cells = {}
    for c = 1, 5 do
        local t = Style.Text(r, 12, "secondary")
        t:SetWordWrap(false)
        r.cells[c] = t
    end
    r.cells[1]:SetPoint("LEFT", 32, 0)
    r.cells[1]:SetWidth(280)
    r.cells[1]:SetJustifyH("LEFT")
    r.heading = Style.Text(r, 10, "gold", nil, true)
    r.heading:SetPoint("LEFT", 0, -2)
    r.note = Style.Text(r, 10, "muted")
    r.note:SetPoint("RIGHT", -8, -2)
    r.rule = Style.Rule(r, "BOTTOM", "line")
    r.add = Style.Button(r, "+", "plain", 22)
    r.add:SetHeight(22)
    r.add:SetPoint("RIGHT", -4, 0)
    r.add:SetScript("OnClick", function(self)
        local data = self:GetParent().data
        if data and ns.Shopping and ns.Shopping.running then
            ns.Shopping.AddCraft(data.spell, IsShiftKeyDown() and 5 or 1)
        end
    end)
    r:SetScript("OnEnter", Tooltip)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    Style.Hover(r, 0)
    P.rows[i] = r
    return r
end

-- Places a cell's text so it ends at its column's x.
local function Cell(r, c, text, colour)
    local t = r.cells[c]
    t:ClearAllPoints()
    t:SetPoint("RIGHT", r, "LEFT", COLUMNS[c].x, 0)
    t:SetJustifyH("RIGHT")
    t:SetText(text or "")
    t:SetTextColor(Style.Color(colour or "secondary"))
end

-- A heading row between what has a price and what hasn't.
local function PaintHeading(r, count)
    r.data = nil
    r.icon:Hide()
    r.add:Hide()
    for _, t in ipairs(r.cells) do t:SetText("") end
    r.heading:SetText("NOT PRICED YET")
    r.note:SetText(count .. " · search these at the auction house and they count")
    r.heading:Show()
    r.note:Show()
end

local function PaintProfitCells(r, row)
    if row.cost then Cell(r, 2, Money(row.cost)) else Cell(r, 2, "–", "muted") end
    if row.sells then Cell(r, 3, Money(row.sells))
    else Cell(r, 3, row.item and "not seen" or "no item", "muted") end
    if row.profit then
        local colour = row.old and "muted" or (row.profit > 0 and "green" or (row.profit < 0 and "red" or "secondary"))
        Cell(r, 4, (row.profit > 0 and "+" or "") .. Money(row.profit), colour)
    else
        Cell(r, 4, "")
    end
    if row.missing then Cell(r, 5, ItemName(row.missing) .. " not seen", "muted")
    elseif row.cost and row.sells then Cell(r, 5, Ago(row.age), row.old and "red" or "muted")
    else Cell(r, 5, "") end
end

local function PaintRow(r, row)
    r.data = row
    r.heading:Hide()
    r.note:Hide()
    r.icon:Show()
    r.icon:SetTexture(row.item and Compat.ItemIcon(row.item) or select(2, Compat.SpellInfo(row.spell)))
    local name, colour = Name(row)
    r.cells[1]:SetText(("|cff%s%s|r"):format(colour, name))
    PaintProfitCells(r, row)
    r.add:SetShown(ns.Shopping ~= nil and ns.Shopping.running == true)
end

---------------------------------------------------------------------------
-- Painting.
---------------------------------------------------------------------------
-- The rows for the profession chosen and the search.
local function Pick(v)
    local all, names = ns.CraftProfit.ProfitRows()
    local counts, lines = {}, {}
    for _, row in ipairs(all) do
        if not counts[row.line] then counts[row.line] = 0; lines[#lines + 1] = row.line end
        counts[row.line] = counts[row.line] + 1
    end
    table.sort(lines, function(a, b) return (ns.Professions.Name(a) or "") < (ns.Professions.Name(b) or "") end)
    if v.line and not counts[v.line] then v.line = nil end
    local find = P.search and strtrim(P.search:GetText() or ""):lower() or ""
    local shown, losing = {}, 0
    for _, row in ipairs(all) do
        local loses = row.profit ~= nil and row.profit <= 0
        if loses then losing = losing + 1 end
        if (not v.line or row.line == v.line) and not (loses and v.hide)
            and (find == "" or (Name(row)):lower():find(find, 1, true)) then
            shown[#shown + 1] = row
        end
    end
    return shown, all, names or {}, lines, counts, losing
end

local function PaintChips(v, all, lines, counts)
    local list = { { line = nil, label = "All", n = #all } }
    for _, line in ipairs(lines) do list[#list + 1] = { line = line, label = ns.Professions.Name(line) or "?", n = counts[line] } end
    local x = 0
    for i = 1, math.max(#list, #P.chips) do
        local c = P.chips[i]
        local entry = list[i]
        if entry and not c then
            c = Style.Button(P.page, "", "tab", 60)
            c:SetHeight(26)
            c:SetScript("OnClick", function(self)
                View().line = self.line
                P.Paint()
            end)
            P.chips[i] = c
        end
        if c then
            c:SetShown(entry ~= nil)
            if entry then
                c.line = entry.line
                c:SetLabel(("%s  |cff%s%d|r"):format(entry.label, Style.hex.muted, entry.n))
                local w = math.max(60, math.floor((c.label:GetStringWidth() or 0) + 24))
                c:SetWidth(w)
                c:ClearAllPoints()
                c:SetPoint("TOPLEFT", P.page.heading, "BOTTOMLEFT", x, -58)
                c:SetSelected(v.line == entry.line)
                x = x + w + 8
            end
        end
    end
end

local function PaintHeads(v)
    local s = Sort(v)
    for i, col in ipairs(COLUMNS) do
        local h = P.heads[i]
        h.key = col.key
        h.text:ClearAllPoints()
        if col.left then
            h.text:SetPoint("LEFT", h, "LEFT", 0, 0)
            h.text:SetJustifyH("LEFT")
        else
            h.text:SetPoint("RIGHT", h, "RIGHT", -10, 0)
            h.text:SetJustifyH("RIGHT")
        end
        h:ClearAllPoints()
        if col.left then
            h:SetPoint("TOPLEFT", P.page.heading, "BOTTOMLEFT", 0, -(LIST_TOP - 26))
            h:SetWidth(300)
        else
            h:SetPoint("TOPLEFT", P.page.heading, "BOTTOMLEFT", col.x - 80, -(LIST_TOP - 26))
            h:SetWidth(90)
        end
        local on = s.key == col.key
        h.text:SetText(col.label)
        h.text:SetTextColor(Style.Color(on and "gold" or "muted"))
        -- A small arrow beside the chosen heading: down for high first.
        h.arrow:SetShown(on)
        if on then
            h.arrow:ClearAllPoints()
            if col.left then h.arrow:SetPoint("LEFT", h.text, "RIGHT", 6, 0) else h.arrow:SetPoint("RIGHT", h, "RIGHT", 0, 0) end
            local turn = math.rad(45) * (s.desc and 1 or -1)
            h.arrow.a:SetRotation(-turn)
            h.arrow.b:SetRotation(turn)
        end
    end
end

local function PaintFoot(v, all, names, losing)
    local nameList = #names > 0 and (#names == 1 and names[1] or (table.concat(names, ", ", 1, #names - 1) .. " and " .. names[#names])) or nil
    local who = nameList and ("Known by " .. nameList .. ". Each character's recipes count once it logs in with this on.")
        or "Open each of your professions once and its recipes show here."
    local from = ns.ItemPrices.HasAuctionator() and "Prices from Auctionator, and your own auction house searches where it has none."
        or "Prices from your own auction house searches. With Auctionator installed, its prices are used."
    P.foot:SetText(who .. "\n" .. from)
    local cut = math.floor(ns.ItemPrices.CUT * 100 + 0.5)
    local making = 0
    for _, row in ipairs(all) do if row.profit and row.profit > 0 then making = making + 1 end end
    P.title:SetText(making == 1 and "1 recipe makes a profit" or (making .. " recipes make a profit"))
    P.sub:SetText(("Of the %d your characters know, after the auction house takes %d%%."):format(#all, cut))
    P.hide.label:SetText(("Hide what loses money (%d)"):format(losing))
    P.hide.switch:SetOn(v.hide and true or false)
end

function P.Paint()
    local v = View()
    local shown, all, names, lines, counts, losing = Pick(v)
    local s = Sort(v)
    SortRows(shown, s)
    PaintChips(v, all, lines, counts)
    PaintHeads(v)
    PaintFoot(v, all, names, losing)
    -- With the list sorted by its main number, what has no price waits
    -- under a heading of its own.
    local split = s.key == "profit"
    local n, at = 0, nil
    for i, row in ipairs(shown) do
        if split and not at and Value(row, s.key) == nil then
            at = i
            n = n + 1
            PaintHeading(Row(n), #shown - i + 1)
            Row(n):Show()
        end
        n = n + 1
        local r = Row(n)
        PaintRow(r, row)
        r:Show()
    end
    for i = n + 1, #P.rows do P.rows[i]:Hide() end
    P.child:SetHeight(math.max(1, n * ROW_H))
    P.empty:SetShown(#shown == 0)
    if #shown == 0 then
        P.empty:SetText(#all == 0 and "Open each of your professions once and its recipes show here." or "Nothing matches.")
    end
end

---------------------------------------------------------------------------
-- Building.
---------------------------------------------------------------------------
local function Heads(page)
    for i = 1, 5 do
        local h = CreateFrame("Button", nil, page)
        h:SetHeight(20)
        h.text = Style.Text(h, 10, "muted", nil, true)
        -- The arrow: a small chevron of two strokes, pointing down for high first.
        h.arrow = CreateFrame("Frame", nil, h)
        h.arrow:SetSize(10, 6)
        h.arrow.a = h.arrow:CreateTexture(nil, "ARTWORK")
        h.arrow.b = h.arrow:CreateTexture(nil, "ARTWORK")
        for _, t in ipairs({ h.arrow.a, h.arrow.b }) do
            t:SetColorTexture(Style.Color("gold"))
            t:SetSize(6, 1.5)
        end
        h.arrow.a:SetPoint("CENTER", -2, 0)
        h.arrow.b:SetPoint("CENTER", 2, 0)
        h:SetScript("OnClick", function(self)
            local s = Sort(View())
            if s.key == self.key then s.desc = not s.desc
            else s.key, s.desc = self.key, not LOW_FIRST[self.key] end
            P.Paint()
        end)
        P.heads[i] = h
    end
end

local function Controls(page, width)
    -- Hide what loses money: a switch and its words, under the professions' buttons.
    P.hide = CreateFrame("Frame", nil, page)
    P.hide:SetSize(320, 20)
    P.hide:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", 0, -98)
    P.hide.switch = Style.Switch(P.hide, function(on) View().hide = on; P.Paint() end)
    P.hide.switch:SetPoint("LEFT")
    P.hide.label = Style.Text(P.hide, 12, "secondary")
    P.hide.label:SetPoint("LEFT", P.hide.switch, "RIGHT", 10, 0)
    -- The search box, with its hint while it's empty.
    P.search = Style.Field(page, 200)
    P.search.well:SetPoint("TOPRIGHT", page.heading, "BOTTOMLEFT", width, -95)
    P.search.hint = Style.Text(P.search.well, 12, "muted")
    P.search.hint:SetPoint("LEFT", 8, 0)
    P.search.hint:SetText("Search recipes")
    P.search:SetScript("OnTextChanged", function(self)
        self.hint:SetShown(self:GetText() == "" and not self:HasFocus())
        P.Paint()
    end)
    P.search:SetScript("OnEditFocusGained", function(self) self.hint:Hide() end)
    P.search:SetScript("OnEditFocusLost", function(self) self.hint:SetShown(self:GetText() == "") end)
end

Window.Page("craftprofit", function(page)
    local width, height = Window.contentWidth, Window.contentHeight
    P.page, P.width = page, width
    P.title, P.sub = Window.Header(page, width)
    Controls(page, width)
    Heads(page)
    local rule = CreateFrame("Frame", nil, page)
    rule:SetSize(width, 1)
    rule:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", 0, -(LIST_TOP - 4))
    Style.Rule(rule, "BOTTOM", "lineStrong")
    local listH = height - LIST_TOP - FOOT_H
    P.scroll, P.child = Style.Scroller(page, width, listH, width - 8, 0, ROW_H * 3)
    P.scroll:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", 0, -LIST_TOP)
    P.empty = Style.Text(page, 13, "muted")
    P.empty:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", 0, -(LIST_TOP + 16))
    P.foot = Style.Text(page, 11, "muted")
    P.foot:SetPoint("BOTTOMLEFT", 0, 0)
    P.foot:SetWidth(width)
    P.foot:SetJustifyH("LEFT")
    page.Refresh = function() P.Paint() end
end)
ns.CraftProfitPage = P
