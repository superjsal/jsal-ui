-- The Crafting profit page: every recipe your characters know, one row each,
-- with what it costs to make, what it sells for, the profit and when its
-- prices were seen. A click on a column's heading sorts by it, a second
-- click the other way. Above the list: a button per profession, a switch to
-- hide what loses money, and a search box. "+" on a row adds the craft to
-- the shopping list. Profit only: no levelling view ("this is purely
-- profit"); the same prices can steer the road to the next rank instead
-- (Professions.lua). It opens in a window of its own.
local _, ns = ...
local Style, Compat, Window = ns.Style, ns.Compat, ns.Window

-- Rows and text a size up from the first build.
local ROW_H, LIST_TOP, FOOT_H = 32, 150, 34
-- A line of the professions' buttons.
local CHIP_ROW = 32
local DAY = 86400

-- The page's parts, filled in as it's built.
local P = { rows = {}, chips = {}, heads = {} }

-- The columns: what each sorts by and its heading (the name starts at 32,
-- after the icon).
local COLUMNS = { { key = "name", label = "RECIPE", left = true },
                  { key = "cost", label = "TO MAKE", right = 480 }, { key = "sells", label = "SELLS FOR", right = 335 },
                  { key = "profit", label = "PROFIT", right = 185 }, { key = "age", label = "SEEN", right = 50 } }
-- How wide a number column is. Gold, silver and copper with their coins run to
-- about 110: at 86, 90 apart, "+1g 80s 58c" ran into SELLS FOR.
local CELL_W = 135
-- Where a number column's text ends: measured from the list's right edge,
-- so a wider window gives the room to the names.
local function ColumnX(c) return P.width - COLUMNS[c].right end
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
    -- Kept only once it's the item's own (or there's no item): the spell's name stands in
    -- while the item loads, and kept, it held the item's name and colour back for good.
    local own = name ~= nil or not row.item
    if not name then name = Compat.SpellInfo(row.spell) end
    local colour = Style.Quality(quality)
    if name and own then row.name, row.colour = name, colour end
    return name or "...", colour
end

local function ItemName(item)
    return Compat.ItemName(item) or "an item"
end

-- Where a recipe you don't know is learned, in a few words: a trainer and the
-- skill, a pattern and what the cheapest vendor wants for it, a drop, a quest.
local HOW = { [3] = "drop", [4] = "quest" }
local function LearnNote(recipe)
    if recipe.how == 1 then return "trainer, " .. recipe.learn end
    if recipe.how == 2 then
        local sources = ns.RecipeSourceText
        local vendor = sources and sources.Vendors and sources.Vendors(recipe.spell, UnitFactionGroup and UnitFactionGroup("player") or nil)[1]
        return vendor and vendor.copper and vendor.copper > 0 and ("pattern, " .. Money(vendor.copper)) or "pattern"
    end
    return HOW[recipe.how] or "other"
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
local function Tooltip(self)
    local row = self.data
    if not row then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if row.item then GameTooltip:SetItemByID(row.item) else GameTooltip:SetSpellByID(row.spell) end
    GameTooltip:AddLine(" ")
    if row.known == false then
        GameTooltip:AddLine("None of your characters knows this yet.", 0.89, 0.69, 0.29)
        if ns.RecipeSourceText and ns.RecipeSourceText.Tooltip then
            ns.RecipeSourceText.Tooltip(GameTooltip, row.spell, UnitFactionGroup and UnitFactionGroup("player") or nil)
        end
        GameTooltip:AddLine(" ")
    end
    if row.missing then
        GameTooltip:AddLine("No price seen yet for " .. ItemName(row.missing) .. ": search for it at the auction house.", 0.94, 0.48, 0.4, true)
    end
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
    r = CreateFrame("Button", nil, P.list)
    r:SetSize(P.width - 8, ROW_H)
    r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(26, 26)
    r.icon:SetPoint("LEFT", 0, 0)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.cells = {}
    for c = 1, 5 do
        local t = Style.Text(r, 13, "secondary")
        t:SetWordWrap(false)
        -- A number column holds its own width, so nothing runs into the next.
        if c > 1 then t:SetWidth(CELL_W) end
        r.cells[c] = t
    end
    r.cells[1]:SetPoint("LEFT", 36, 0)
    r.cells[1]:SetWidth(P.width - 36 - COLUMNS[2].right - 110)
    r.cells[1]:SetJustifyH("LEFT")
    r.heading = Style.Text(r, 11, "gold", nil, true)
    r.heading:SetPoint("LEFT", 0, -2)
    r.note = Style.Text(r, 11, "muted")
    r.note:SetPoint("RIGHT", -8, -2)
    r.rule = Style.Rule(r, "BOTTOM", "line")
    r.add = Style.Button(r, "+", "plain", 24)
    r.add:SetHeight(24)
    r.add:SetPoint("RIGHT", -14, 0)
    r.add:SetScript("OnClick", function(self)
        local data = self:GetParent().data
        if data and ns.Shopping and ns.Shopping.running then
            ns.Shopping.AddCraft(data.spell, IsShiftKeyDown() and 5 or 1)
        end
    end)
    r:SetScript("OnEnter", Tooltip)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r:EnableMouseWheel(true)
    r:SetScript("OnMouseWheel", function(_, delta) P.Wheel(delta) end)
    Style.Hover(r, 0)
    P.rows[i] = r
    return r
end

-- Places a cell's text so it ends at its column's x.
local function Cell(r, c, text, colour)
    local t = r.cells[c]
    t:ClearAllPoints()
    t:SetPoint("RIGHT", r, "LEFT", ColumnX(c), 0)
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
    -- What has no price is named in the tooltip: a material's name here ran
    -- across the other columns.
    if row.missing then Cell(r, 5, "needs a price", "muted")
    elseif row.cost and row.sells then Cell(r, 5, Compat.DaysAgo(math.floor((row.age or 0) / DAY)), row.old and "red" or "muted")
    else Cell(r, 5, "") end
end

local function PaintRow(r, row)
    r.data = row
    r.heading:Hide()
    r.note:Hide()
    r.icon:Show()
    r.icon:SetTexture(row.item and Compat.ItemIcon(row.item) or select(2, Compat.SpellInfo(row.spell)))
    local name, colour = Name(row)
    local text = ("|cff%s%s|r"):format(colour, name)
    if row.known == false then text = text .. ("  |cff%s· %s|r"):format(Style.hex.muted, LearnNote(row.recipe)) end
    r.cells[1]:SetText(text)
    PaintProfitCells(r, row)
    r.add:SetShown(ns.Shopping ~= nil and ns.Shopping.running == true)
end

---------------------------------------------------------------------------
-- Painting.
---------------------------------------------------------------------------
-- The rows for the switch: the recipes your characters know, or every recipe
-- of their professions. Every recipe is several hundred, and working them out
-- on each open is slow enough to feel, so they're kept: while you type in
-- the search box, and otherwise until a recipe is learned, a price is seen or
-- you're at the auction house (ns.CraftProfit.Holds), or an hour has gone by,
-- as the SEEN column counts in days. Sorting and the list keep each paint.
local KEEP_FOR = 3600
local function Rows(v, keep)
    local key = v.all and "all" or "known"
    local c = P.cache
    local CP, now = ns.CraftProfit, ns.Compat.ServerTime()
    if c and c.key == key and (keep or (CP.Holds(c.stamp) and now - c.at < KEEP_FOR)) then
        return c.rows, c.names, c.count
    end
    local stamp = CP.Stamp()
    local count = ns.ItemPrices.Counting()
    local rows, names
    if v.all then rows, names = CP.AllRows() else rows, names = CP.ProfitRows() end
    P.cache = { key = key, rows = rows, names = names, count = count, stamp = stamp, at = now }
    return rows, names, count
end

-- Works the rows out ahead, for the list the page will open on, so that open only draws
-- them. Nothing is drawn, and nothing is worked out while the kept rows still hold.
function P.Warm()
    Rows(View(), false)
end

-- The rows for the profession chosen and the search.
local function Pick(v, keep)
    local all, names, count = Rows(v, keep)
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
    return shown, all, names or {}, lines, counts, losing, count
end

local function PaintChips(v, all, lines, counts)
    local list = { { line = nil, label = "All", n = #all } }
    for _, line in ipairs(lines) do list[#list + 1] = { line = line, label = ns.Professions.Name(line) or "?", n = counts[line] } end
    -- As many lines as they need: every profession's button is wider than the
    -- window, and what's under them moves down to make room.
    local x, row = 0, 0
    for i = 1, math.max(#list, #P.chips) do
        local c = P.chips[i]
        local entry = list[i]
        if entry and not c then
            c = Style.Button(P.page, "", "tab", 60)
            c:SetHeight(26)
            c:SetScript("OnClick", function(self)
                View().line = self.line
                P.Paint(true)
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
                if x > 0 and x + w > P.width then x, row = 0, row + 1 end
                c:ClearAllPoints()
                c:SetPoint("TOPLEFT", P.page.heading, "BOTTOMLEFT", x, -58 - row * CHIP_ROW)
                c:SetSelected(v.line == entry.line)
                x = x + w + 8
            end
        end
    end
    P.Layout(row * CHIP_ROW)
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
            h:SetPoint("TOPLEFT", P.page.heading, "BOTTOMLEFT", 0, -(LIST_TOP + P.extra - 26))
            h:SetWidth(300)
        else
            h:SetPoint("TOPLEFT", P.page.heading, "BOTTOMLEFT", ColumnX(i) - CELL_W + 10, -(LIST_TOP + P.extra - 26))
            h:SetWidth(CELL_W)
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

local function PaintFoot(v, all, names, losing, count)
    local nameList = #names > 0 and (#names == 1 and names[1] or (table.concat(names, ", ", 1, #names - 1) .. " and " .. names[#names])) or nil
    local who = nameList and ("Known by " .. nameList .. ". Each character's recipes count once it logs in with this on.")
        or "Open each of your professions once and its recipes show here."
    local from
    if count.auctionator then
        from = "Prices from " .. ns.ItemPrices.From(count) .. "."
    elseif ns.ItemPrices.HasAuctionator() then
        from = "Prices from your own auction house searches: Auctionator has none until it scans at an auction house."
    else
        from = "Prices from your own auction house searches. With Auctionator installed, its prices are used."
    end
    -- Read on a hover over the link at the page's foot.
    P.about.note = who .. "\n" .. from
    local cut = math.floor(ns.ItemPrices.CUT * 100 + 0.5)
    local making = 0
    for _, row in ipairs(all) do if row.profit and row.profit > 0 then making = making + 1 end end
    P.title:SetText(making == 1 and "1 recipe makes a profit" or (making .. " recipes make a profit"))
    P.sub:SetText((v.all and "Of the %d recipes in your professions, known or not, after the auction house takes %d%%."
        or "Of the %d your characters know, after the auction house takes %d%%."):format(#all, cut))
    P.tabs:Pick(v.all and "all" or "known")
    P.hide.label:SetText(("Hide what loses money (%d)"):format(losing))
    P.hide.switch:SetOn(v.hide and true or false)
end

-- `stay`: the list keeps its place, for a repaint nobody asked for (a recipe learned, a bag
-- changed). It went back to the top each time, under whoever was reading it.
function P.Paint(keep, stay)
    local v = View()
    local shown, all, names, lines, counts, losing, count = Pick(v, keep)
    local s = Sort(v)
    SortRows(shown, s)
    PaintChips(v, all, lines, counts)
    PaintHeads(v)
    PaintFoot(v, all, names, losing, count)
    -- With the list sorted by its main number, what has no price waits
    -- under a heading of its own.
    local split = s.key == "profit"
    local entries, at = {}, nil
    for i, row in ipairs(shown) do
        if split and not at and Value(row, s.key) == nil then
            at = i
            entries[#entries + 1] = { heading = #shown - i + 1 }
        end
        entries[#entries + 1] = row
    end
    if not stay then P.offset = 0 end
    P.entries = entries
    P.PaintList()
    P.empty:SetShown(#shown == 0)
    if #shown == 0 then
        P.empty:SetText(#all == 0 and "Open each of your professions once and its recipes show here." or "Nothing matches.")
    end
end

-- The rows on screen: only as many as fit are drawn, filled from where the
-- list is scrolled to (every recipe can be several hundred), with a thin bar
-- at the right showing where that is.
function P.PaintList()
    local entries = P.entries or {}
    P.offset = math.max(0, math.min(P.offset or 0, #entries - P.visible))
    for slot = 1, P.visible do
        local entry = entries[P.offset + slot]
        local r = (entry or P.rows[slot]) and Row(slot)
        if entry and entry.heading then
            PaintHeading(r, entry.heading)
            r:Show()
        elseif entry then
            PaintRow(r, entry)
            r:Show()
        elseif r then
            r.data = nil
            r:Hide()
        end
    end
    local more = #entries > P.visible
    P.bar:SetShown(more)
    P.track:SetShown(more)
    if more then
        local h = P.visible * ROW_H
        local size = math.max(24, h * P.visible / #entries)
        P.bar:SetHeight(size)
        P.bar:ClearAllPoints()
        P.bar:SetPoint("TOPRIGHT", P.list, "TOPRIGHT", 0, -(h - size) * P.offset / (#entries - P.visible))
    end
end

-- Everything under the professions' buttons, `extra` lower when they take
-- more than one line; the list is that much shorter.
function P.Layout(extra)
    if P.extra == extra then return end
    P.extra = extra
    local H = P.page.heading
    local function At(f, point, x, y)
        f:ClearAllPoints()
        f:SetPoint(point, H, "BOTTOMLEFT", x, y - extra)
    end
    At(P.tabs, "TOPLEFT", 0, -93)
    At(P.search.well, "TOPRIGHT", P.width, -95)
    At(P.rule, "TOPLEFT", 0, -(LIST_TOP - 4))
    At(P.list, "TOPLEFT", 0, -LIST_TOP)
    At(P.empty, "TOPLEFT", 0, -(LIST_TOP + 16))
    P.list:SetHeight(P.listH - extra)
    P.visible = math.max(1, math.floor((P.listH - extra) / ROW_H))
    for i = P.visible + 1, #P.rows do P.rows[i]:Hide() end
end

-- The wheel: three rows a turn.
function P.Wheel(delta)
    P.offset = (P.offset or 0) - delta * 3
    P.PaintList()
end

-- While the left button is held on the strip: the list goes to where the
-- pointer is along it, top to bottom.
function P.Drag()
    local room = #(P.entries or {}) - P.visible
    if room <= 0 then return end
    local top, height, scale = P.track:GetTop(), P.track:GetHeight(), P.track:GetEffectiveScale()
    if not (top and height and height > 0 and scale and scale > 0) then return end
    local _, y = GetCursorPosition()
    local at = math.max(0, math.min(1, (top - y / scale) / height))
    local offset = math.floor(at * room + 0.5)
    if offset ~= P.offset then
        P.offset = offset
        P.PaintList()
    end
end

---------------------------------------------------------------------------
-- Building.
---------------------------------------------------------------------------
local function Heads(page)
    for i = 1, 5 do
        local h = CreateFrame("Button", nil, page)
        h:SetHeight(20)
        h.text = Style.Text(h, 11, "muted", nil, true)
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
            P.Paint(true)
        end)
        P.heads[i] = h
    end
end

local function Controls(page, width)
    -- The recipes your characters know, or every recipe of their professions.
    P.tabs = Style.Tabs(page, { { "known", "Recipes you know" }, { "all", "All recipes" } }, function(key)
        View().all = key == "all"
        P.Paint()
    end)
    P.tabs:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", 0, -93)
    -- Hide what loses money: a switch and its words, beside them.
    P.hide = CreateFrame("Frame", nil, page)
    P.hide:SetSize(320, 20)
    P.hide:SetPoint("LEFT", P.tabs, "RIGHT", 20, 0)
    P.hide.switch = Style.Switch(P.hide, function(on) View().hide = on; P.Paint(true) end)
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
        P.Paint(true)
    end)
    P.search:SetScript("OnEditFocusGained", function(self) self.hint:Hide() end)
    P.search:SetScript("OnEditFocusLost", function(self) self.hint:SetShown(self:GetText() == "") end)
end

Window.Page("craftprofit", function(page)
    local width, height = page.contentWidth or Window.contentWidth, page.contentHeight or Window.contentHeight
    P.page, P.width = page, width
    P.title, P.sub = Window.Header(page, width)
    Controls(page, width)
    Heads(page)
    local rule = CreateFrame("Frame", nil, page)
    P.rule, P.extra = rule, 0
    rule:SetSize(width, 1)
    rule:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", 0, -(LIST_TOP - 4))
    Style.Rule(rule, "BOTTOM", "lineStrong")
    local listH = height - LIST_TOP - FOOT_H
    P.listH = listH
    P.list = CreateFrame("Frame", nil, page)
    P.list:SetSize(width, listH)
    P.list:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", 0, -LIST_TOP)
    P.visible = math.max(1, math.floor(listH / ROW_H))
    P.offset = 0
    P.list:EnableMouseWheel(true)
    P.list:SetScript("OnMouseWheel", function(_, delta) P.Wheel(delta) end)
    -- The strip at the list's right: hold the left button on it and drag, and
    -- the list follows; a click jumps there. Wider than the thin bar it holds,
    -- so it's easy to catch.
    P.track = CreateFrame("Frame", nil, P.list)
    P.track:SetPoint("TOPRIGHT")
    P.track:SetPoint("BOTTOMRIGHT")
    P.track:SetWidth(12)
    P.track:SetFrameLevel(P.list:GetFrameLevel() + 5)
    P.track:EnableMouse(true)
    P.track:EnableMouseWheel(true)
    P.track:SetScript("OnMouseWheel", function(_, delta) P.Wheel(delta) end)
    P.track:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        self.held = true
        P.Drag()
    end)
    P.track:SetScript("OnMouseUp", function(self) self.held = false end)
    P.track:SetScript("OnHide", function(self) self.held = false end)
    P.track:SetScript("OnUpdate", ns.Safe(ns.CraftProfit, function(self)
        if self.held then P.Drag() end
    end))
    P.bar = page:CreateTexture(nil, "OVERLAY")
    P.bar:SetColorTexture(Style.Color("thumb"))
    P.bar:SetWidth(3)
    P.bar:Hide()
    P.empty = Style.Text(page, 13, "muted")
    P.empty:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", 0, -(LIST_TOP + 16))
    -- The page's small print: whose recipes these are, and where the prices come from.
    P.about = Style.About(page)
    P.about:SetPoint("BOTTOMRIGHT", page, "BOTTOMLEFT", width, 0)
    page.Refresh = function() P.Paint(nil, true) end
-- A window of its own beside the dashboard, as the Gear plan and the dungeon
-- guide have, and as big as the dashboard.
end, { width = 1000, height = 920 })
ns.CraftProfitPage = P
