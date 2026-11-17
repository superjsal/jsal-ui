-- Guild Crafts: a window of its own for what the guild makes for each other.
-- Three tabs. For you: what guildmates asked for that you know how to make.
-- Your orders: ask the guild for a craft or an enchant, and where each of
-- yours stands. Crafters: who makes what (Guild crafters' own list). An
-- order is waiting for a crafter, being made, sent, or done, and each state
-- has a colour and a sign that are the same everywhere: in the counts at the
-- top of a tab, in its headings, down a row's left edge and on its track.
--
-- The window comes in two sizes, swapped by a switch in the title bar: the
-- full one, and a small one to leave open while you play, with a line an
-- order and one button on it.
local _, ns = ...
local Style, Compat, Window = ns.Style, ns.Compat, ns.Window

local C = { tabs = {}, views = {}, ask = { have = true } }
ns.GuildCrafts = C

local ROW, DONE_ROW, HEAD_ROW, FOUND_ROW, CARD_H = 82, 40, 26, 52, 76
-- A row's track, and the room kept after its materials for "+2 more".
local TRACK_GAP = 86
local TRACK_W, MORE_W = 3 * TRACK_GAP + 24, 64
-- The least room who makes it has in the asking card's foot.
local MAKERS_W = 250
local TOP, FOOT = 116, 30
-- Where the asking card starts under the counts (which are 52 high): the gap holds a line
-- saying why something couldn't be done. And the card's height.
local CARD_Y, ASK_H = 80, 160
local ENCHANTING = 333
-- A state's colour. "todo" is an order you accepted and "got" one of yours
-- that was sent to you: the two things that wait on you. "sent" is one you
-- sent, waiting for whoever asked to mark it received; "unconfirmed" one
-- sent over a week ago that never was.
local STATE = { todo = "gold", got = "gold", waiting = "amber", making = "sky", sent = "sky", done = "green", unconfirmed = "muted" }
local STEP = { waiting = 1, todo = 2, making = 2, sent = 3, got = 3, done = 4 }
local WAITS_ON_YOU = { todo = true, got = true }
local UNDER_WAY = { making = true, sent = true }
local DAY = 86400
local DOT = "   ·   "

local function View()
    local v = type(ns.db.craftsView) == "table" and ns.db.craftsView or {}
    ns.db.craftsView = v
    return v
end

local function OrdersOn() return ns.Orders ~= nil and ns.Orders.running == true end
local function CraftersOn() return ns.Crafters ~= nil and ns.Crafters.running == true end

-- The tab showing: the one last picked; before any pick, For you with orders
-- on, else Crafters (the one that works for everyone who has Guild crafters).
local KNOWN_TABS = { foryou = true, yours = true, crafters = true }
local function CurrentTab()
    local tab = View().tab
    if KNOWN_TABS[tab] then return tab end
    return OrdersOn() and "foryou" or "crafters"
end

---------------------------------------------------------------------------
-- Words.
---------------------------------------------------------------------------
local function Plural(n, one, many)
    return n == 1 and one or many
end

local function Ago(t)
    local s = math.max(0, Compat.ServerTime() - (t or 0))
    if s < 3600 then return math.max(1, math.floor(s / 60)) .. " min ago" end
    if s < DAY then return math.floor(s / 3600) .. " h ago" end
    local days = math.floor(s / DAY)
    return days == 1 and "yesterday" or (days .. " days ago")
end

-- The guild by name: who's online, where, their class, and the whole name a
-- whisper needs.
local function Roster()
    local who = {}
    for i = 1, (GetNumGuildMembers and GetNumGuildMembers() or 0) do
        local full, _, _, _, _, zone, _, _, isOnline, _, class = GetGuildRosterInfo(i)
        if full then
            who[Ambiguate(full, "none")] = {
                full = full, online = isOnline and true or false, class = class,
                zone = type(zone) == "string" and zone ~= "" and zone or nil,
            }
        end
    end
    return who
end

-- A guildmate's name in their class's colour.
local function Who(name, roster)
    local entry = roster and roster[name]
    local colour = entry and entry.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[entry.class]
    if not colour then return Style.Tint("text") .. name .. "|r" end
    local function Part(v) return math.floor((v or 1) * 255 + 0.5) end
    return ("|cff%02x%02x%02x%s|r"):format(Part(colour.r), Part(colour.g), Part(colour.b), name)
end

-- A guildmate's name in their class's colour, for the card at the mailbox.
function C.Who(name)
    return Who(name, Roster())
end

local function Whisper(name, roster)
    local entry = roster and roster[name]
    local tell = (ChatFrameUtil and ChatFrameUtil.SendTell) or ChatFrame_SendTell
    if tell then tell(entry and entry.full or name) end
end

local function ItemTint(item)
    local quality = item and C_Item and C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(item)
    if not quality or quality == 1 then return Style.Tint("text") end
    return "|cff" .. Style.Quality(quality)
end

-- What an order is for, as its row's first line.
local function Title(order)
    local recipe = ns.Orders.Recipe(order.spell)
    local text = ItemTint(recipe and recipe.item) .. (ns.Orders.Name(order) or "...") .. "|r"
    if recipe and recipe.item then
        text = text .. "   " .. Style.Tint("secondary") .. "×" .. (order.n or 1) .. "|r"
    end
    if order.on then
        text = text .. "   " .. Style.Tint("muted") .. "on|r " .. ItemTint(order.on) .. (Compat.ItemName(order.on) or "an item") .. "|r"
    end
    return text
end
C.Title = Title

-- What an order's materials would cost, to go on the line under its name; nothing when the
-- asker has them, or when one has no price.
local function CostNote(order)
    local cost = not order.have and ns.Orders.Cost(order)
    return cost and (DOT .. "materials about " .. Compat.Money(cost)) or ""
end

local function Icon(order)
    local recipe = ns.Orders.Recipe(order.spell)
    if recipe and recipe.item then return Compat.ItemIcon(recipe.item) end
    return (select(2, Compat.SpellInfo(order.spell)))
end

local function TextWidth(text, fallback)
    local w = text.GetStringWidth and text:GetStringWidth()
    return (type(w) == "number" and w > 0) and w or fallback
end

---------------------------------------------------------------------------
-- Small parts.
---------------------------------------------------------------------------
-- A state's sign: a full square for what waits on you, an outline for
-- waiting, a half for being made or sent, a tick for done, a dash in an
-- outline for not confirmed.
local function Mark(parent, size)
    local m = CreateFrame("Frame", nil, parent)
    m:SetSize(size, size)
    m.full = m:CreateTexture(nil, "ARTWORK")
    m.full:SetAllPoints()
    m.half = m:CreateTexture(nil, "ARTWORK")
    m.half:SetPoint("BOTTOMLEFT")
    m.half:SetPoint("BOTTOMRIGHT")
    m.half:SetHeight(size / 2)
    m.edges = {}
    for i, edge in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
                            { "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false } }) do
        local t = m:CreateTexture(nil, "ARTWORK")
        t:SetPoint(edge[1])
        t:SetPoint(edge[2])
        if edge[3] then t:SetHeight(2) else t:SetWidth(2) end
        m.edges[i] = t
    end
    m.short = m:CreateTexture(nil, "ARTWORK")
    m.short:SetSize(size * 0.5, 2)
    m.short:SetPoint("CENTER", -size * 0.27, -size * 0.18)
    m.short:SetRotation(math.rad(-45))
    m.long = m:CreateTexture(nil, "ARTWORK")
    m.long:SetSize(size * 0.9, 2)
    m.long:SetPoint("CENTER", size * 0.16, 0)
    m.long:SetRotation(math.rad(50))
    m.dash = m:CreateTexture(nil, "ARTWORK")
    m.dash:SetSize(size * 0.5, 2)
    m.dash:SetPoint("CENTER")
    function m:Set(state)
        local r, g, b = Style.Color(STATE[state])
        self.full:SetShown(WAITS_ON_YOU[state] == true)
        self.half:SetShown(UNDER_WAY[state] == true)
        for _, t in ipairs(self.edges) do t:SetShown(state == "waiting" or state == "unconfirmed" or UNDER_WAY[state] == true) end
        self.short:SetShown(state == "done")
        self.long:SetShown(state == "done")
        self.dash:SetShown(state == "unconfirmed")
        for _, t in ipairs({ self.full, self.half, self.short, self.long, self.dash }) do t:SetColorTexture(r, g, b) end
        for _, t in ipairs(self.edges) do t:SetColorTexture(r, g, b) end
    end
    return m
end

-- A lesser action: words only, with a line under them.
local function Quiet(parent, label)
    local b = CreateFrame("Button", nil, parent)
    b.label = Style.Text(b, 11, "muted", nil, true)
    b.label:SetPoint("CENTER")
    b.line = b:CreateTexture(nil, "ARTWORK")
    b.line:SetColorTexture(Style.Color("lineStrong"))
    b.line:SetPoint("BOTTOMLEFT")
    b.line:SetPoint("BOTTOMRIGHT")
    b.line:SetHeight(1)
    function b:SetLabel(text)
        self.label:SetText(text)
        self:SetSize(TextWidth(self.label, #text * 6) + 2, 18)
    end
    b:SetScript("OnEnter", function(self) self.label:SetTextColor(Style.Color("text")) end)
    b:SetScript("OnLeave", function(self) self.label:SetTextColor(Style.Color("muted")) end)
    b:SetLabel(label or "")
    return b
end

-- "HAS THE MATERIALS" in green, "NEEDS THE MATERIALS" in gold.
local function Pill(parent)
    local p = CreateFrame("Frame", nil, parent)
    p:SetHeight(20)
    p.fill = Style.Fill(p, "goodFill")
    p.text = Style.Text(p, 10, "green", nil, true)
    p.text:SetPoint("CENTER")
    function p:Set(label, kind)
        self.fill:SetColorTexture(Style.Color(kind == "good" and "goodFill" or (kind == "need" and "needFill" or "line")))
        self.text:SetTextColor(Style.Color(kind == "good" and "green" or (kind == "need" and "gold" or "secondary")))
        self.text:SetText(label)
        self:SetWidth(TextWidth(self.text, #label * 7) + 16)
    end
    return p
end

-- A material: a thin box with "16 Medium Leather" in it. Pointed at, it shows the game's own
-- tooltip for the item, with whatever the game and other addons add to one: its vendor and
-- auction prices among them.
local function Chip(parent)
    local c = CreateFrame("Frame", nil, parent)
    c:SetHeight(20)
    c.edges = Style.Border(c, "cardLine")
    c.text = Style.Text(c, 11, "secondary")
    c.text:SetPoint("CENTER")
    function c:Set(label, item)
        self.item = item
        self.text:SetText(label)
        self:SetWidth(TextWidth(self.text, #label * 6) + 14)
    end
    c:EnableMouse(true)
    c:SetScript("OnEnter", function(self)
        if not self.item then return end
        Style.SetBorder(self.edges, "lineStrong")
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetItemByID(self.item)
        GameTooltip:Show()
    end)
    c:SetScript("OnLeave", function(self)
        Style.SetBorder(self.edges, "cardLine")
        GameTooltip:Hide()
    end)
    return c
end

-- Where an order stands: asked, being made, sent, received. The same on every row.
local function Track(parent)
    local t = CreateFrame("Frame", nil, parent)
    t:SetSize(TRACK_W, 32)
    t.nodes, t.holes, t.lines, t.labels = {}, {}, {}, {}
    for i, label in ipairs({ "Asked", "Being made", "Sent", "Received" }) do
        local x = (i - 1) * TRACK_GAP
        local node = t:CreateTexture(nil, "ARTWORK")
        node:SetSize(10, 10)
        node:SetPoint("TOPLEFT", x, 0)
        local hole = t:CreateTexture(nil, "OVERLAY")
        hole:SetSize(8, 8)
        hole:SetPoint("CENTER", node, "CENTER")
        hole:SetColorTexture(Style.Color("window"))
        local text = Style.Text(t, 10, "muted")
        text:SetPoint("TOP", node, "BOTTOM", 0, -5)
        text:SetJustifyH("CENTER")
        text:SetText(label)
        t.nodes[i], t.holes[i], t.labels[i] = node, hole, text
        if i < 4 then
            local line = t:CreateTexture(nil, "ARTWORK")
            line:SetSize(TRACK_GAP - 10, 1)
            line:SetPoint("LEFT", node, "RIGHT", 0, 0)
            t.lines[i] = line
        end
    end
    function t:Set(state)
        local at = STEP[state]
        local r, g, b = Style.Color(STATE[state])
        for i = 1, 4 do
            local reached = i <= at
            if reached then self.nodes[i]:SetColorTexture(r, g, b) else self.nodes[i]:SetColorTexture(Style.Color("lineStrong")) end
            self.holes[i]:SetShown(not reached)
            if i == at then self.labels[i]:SetTextColor(r, g, b) else self.labels[i]:SetTextColor(Style.Color("muted")) end
            if self.lines[i] then
                if i < at then self.lines[i]:SetColorTexture(r, g, b) else self.lines[i]:SetColorTexture(Style.Color("lineStrong")) end
            end
        end
    end
    return t
end

-- How things stand, at a glance: a number for a state.
local function CountBox(parent, width)
    local box = CreateFrame("Frame", nil, parent)
    box:SetSize(width, 52)
    Style.Fill(box, "well")
    Style.Border(box, "cardLine")
    box.edge = box:CreateTexture(nil, "ARTWORK")
    box.edge:SetPoint("TOPLEFT")
    box.edge:SetPoint("BOTTOMLEFT")
    box.edge:SetWidth(3)
    box.number = Style.Text(box, 26, "text", nil, true)
    box.number:SetPoint("LEFT", 20, 0)
    box.number:SetJustifyV("MIDDLE")
    box.mark = Mark(box, 10)
    box.mark:SetPoint("TOPLEFT", 62, -12)
    box.label = Style.Text(box, 11, "text", nil, true)
    box.label:SetPoint("LEFT", box.mark, "RIGHT", 8, 0)
    box.say = Style.Text(box, 11, "muted")
    box.say:SetPoint("TOPLEFT", 62, -30)
    function box:Set(state, n, label, say)
        local r, g, b = Style.Color(STATE[state])
        self.edge:SetColorTexture(r, g, b)
        self.number:SetText(n)
        if n > 0 then self.number:SetTextColor(r, g, b) else self.number:SetTextColor(Style.Color("muted")) end
        self.mark:Set(state)
        self.label:SetText(label)
        self.label:SetTextColor(r, g, b)
        self.say:SetText(say)
    end
    return box
end

---------------------------------------------------------------------------
-- A scrolling list of rows of several kinds, each kind kept and reused.
---------------------------------------------------------------------------
local function List(parent, width, height)
    local list = { width = width, pools = {}, y = 0 }
    list.scroll, list.child = Style.Scroller(parent, width, height, width - 10, 0, ROW)
    return list
end

local function Reset(list)
    for _, pool in pairs(list.pools) do
        for i = 1, #pool do pool[i]:Hide() end
        pool.used = 0
    end
    list.y = 0
end

local function Take(list, kind, make, height)
    local pool = list.pools[kind]
    if not pool then
        pool = { used = 0 }
        list.pools[kind] = pool
    end
    pool.used = pool.used + 1
    local f = pool[pool.used]
    if not f then
        f = make(list.child, list.width - 10)
        pool[pool.used] = f
    end
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", 0, -list.y)
    f:Show()
    list.y = list.y + height
    return f
end

local function Close(list)
    list.child:SetHeight(math.max(1, list.y))
    if list.scroll.Place then list.scroll:Place() end
end

---------------------------------------------------------------------------
-- Rows.
---------------------------------------------------------------------------
local function MakeHead(parent, width)
    local h = CreateFrame("Frame", nil, parent)
    h:SetSize(width, HEAD_ROW)
    h.mark = Mark(h, 10)
    h.mark:SetPoint("LEFT", 0, 0)
    h.text = Style.Text(h, 11, "text", nil, true)
    h.text:SetPoint("LEFT", 18, 0)
    h.text:SetJustifyV("MIDDLE")
    return h
end

local function Head(list, state, title, n, say)
    list.y = list.y + (list.y > 0 and 12 or 0)
    local h = Take(list, "head", MakeHead, HEAD_ROW)
    h.mark:SetShown(state ~= nil)
    if state then h.mark:Set(state) end
    h.text:ClearAllPoints()
    h.text:SetPoint("LEFT", state and 18 or 0, 0)
    h.text:SetText(Style.Tint(state and STATE[state] or "gold") .. title .. "|r   " .. Style.Tint("text") .. n .. "|r"
        .. (say and ("     " .. Style.Tint("muted") .. say .. "|r") or ""))
    return h
end

local function ShowTip(self)
    local order = self.order
    local recipe = order and ns.Orders.Recipe(order.spell)
    if not recipe then return end
    GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
    if recipe.item then GameTooltip:SetItemByID(recipe.item) else GameTooltip:SetSpellByID(order.spell) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(order.have and (order.by .. " has the materials:") or (order.by .. " needs the materials too:"), 0.89, 0.69, 0.29)
    -- Each material with what that many cost, where a price is known, and the lot under them.
    local prices = ns.ItemPrices and ns.ItemPrices.Of
    local total, priced, materials = 0, 0, ns.Orders.Materials(order)
    for _, m in ipairs(materials) do
        local each = prices and prices(m.item)
        if each then total, priced = total + each * m.count, priced + 1 end
        GameTooltip:AddDoubleLine(m.count .. " " .. (Compat.ItemName(m.item) or "..."), each and Compat.Money(each * m.count) or "no price yet",
            0.93, 0.9, 0.84, each and 0.93 or 0.6, each and 0.9 or 0.59, each and 0.84 or 0.53)
    end
    if priced > 0 then
        GameTooltip:AddDoubleLine(priced == #materials and "All of it, about" or ("The %d with a price, about"):format(priced), Compat.Money(total),
            0.89, 0.69, 0.29, 0.89, 0.69, 0.29)
    end
    if order.note then GameTooltip:AddLine("“" .. order.note .. "”", 0.77, 0.75, 0.69, true) end
    GameTooltip:Show()
end

local function MakeOrder(parent, width)
    local r = CreateFrame("Frame", nil, parent)
    r:SetSize(width, ROW)
    r.edge = r:CreateTexture(nil, "ARTWORK")
    r.edge:SetPoint("TOPLEFT", 0, -8)
    r.edge:SetPoint("BOTTOMLEFT", 0, 10)
    r.edge:SetWidth(2)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(40, 40)
    r.icon:SetPoint("TOPLEFT", 14, -10)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.l1 = Style.Text(r, 14, "text", nil, true)
    r.l1:SetPoint("TOPLEFT", 68, -8)
    r.l1:SetWidth(width - 68 - 300)
    r.l1:SetWordWrap(false)
    r.l2 = Style.Text(r, 12, "muted")
    r.l2:SetPoint("TOPLEFT", 68, -30)
    r.l2:SetWidth(width - 68 - 300)
    r.l2:SetWordWrap(false)
    r.pill = Pill(r)
    r.pill:SetPoint("TOPLEFT", 68, -52)
    r.chips = {}
    r.more = Style.Text(r, 11, "muted")
    r.main = Style.Button(r, "", "primary", 90)
    r.plain = Style.Button(r, "Whisper", "plain", 84)
    r.lesser = Quiet(r)
    r.track = Track(r)
    r.track:SetPoint("BOTTOMRIGHT", 0, 6)
    Style.Rule(r, "BOTTOM", "line")
    r:EnableMouse(true)
    r:SetScript("OnEnter", ShowTip)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return r
end

-- Runs one of the orders' actions, says why if it couldn't, and repaints.
local function Do(action, id)
    local ok, why = action(id)
    if not ok and why then ns.Print(why) end
    C.Repaint()
end

-- The crafter's button on an order they accepted: Mark sent for an item
-- (done once whoever asked marks it received), Mark done for an enchant
-- (given in a trade).
local function Finish(order)
    local id, O = order.id, ns.Orders
    if O.MakesItem(order) then return { "Mark sent", function() Do(O.Sent, id) end } end
    return { "Mark done", function() Do(O.Done, id) end }
end

-- Whether what an order makes is in your bags (some of it, at least).
local function InBags(order)
    local recipe = ns.Orders.Recipe(order.spell)
    return recipe and recipe.item and Compat.ItemCount(recipe.item) > 0 or false
end
C.InBags = InBags

-- "mailed 2 min ago", or "sent 2 min ago" for one handed over.
local function SentWhen(order)
    return (order.s == "m" and "mailed " or "sent ") .. Ago(order.e)
end

-- Fills a row: `state` is its colour, `second` its line under the name,
-- `buttons` = { main = { label, fn }, plain = { label, fn }, lesser = { label, fn } }.
local function FillOrder(r, order, state, second, mine, buttons)
    r.order = order
    r.edge:SetColorTexture(Style.Color(STATE[state]))
    r.icon:SetTexture(Icon(order))
    r.l1:SetText(Title(order))
    r.l2:SetText(second)
    if order.have then
        r.pill:Set(mine and "YOU HAVE THE MATERIALS" or "HAS THE MATERIALS", "good")
    else
        r.pill:Set(mine and "YOU NEED THE MATERIALS" or "NEEDS THE MATERIALS", "need")
    end
    -- The materials, as many as fit before the track; the rest are counted ("+2 more") and
    -- named in the row's tooltip.
    local after, waiting, shown = r.pill, false, 0
    local materials = ns.Orders.Materials(order)
    local room = r:GetWidth() - 68 - TRACK_W - 24 - r.pill:GetWidth()
    for i, m in ipairs(materials) do
        local chip = r.chips[i]
        if not chip then
            chip = Chip(r)
            r.chips[i] = chip
        end
        local name = Compat.ItemName(m.item)
        if not name then waiting = true end
        chip:Set(m.count .. " " .. (name or "..."), m.item)
        -- The last one needs only its own room; any other, room for the count after it too.
        local need = chip:GetWidth() + (after == r.pill and 8 or 5) + (i < #materials and MORE_W or 0)
        if shown == i - 1 and need <= room then
            chip:ClearAllPoints()
            chip:SetPoint("LEFT", after, "RIGHT", after == r.pill and 8 or 5, 0)
            chip:Show()
            room = room - chip:GetWidth() - (after == r.pill and 8 or 5)
            after, shown = chip, i
        else
            chip:Hide()
        end
    end
    for i = #materials + 1, #r.chips do r.chips[i]:Hide() end
    r.more:SetText(shown < #materials and ("+%d more"):format(#materials - shown) or "")
    r.more:ClearAllPoints()
    r.more:SetPoint("LEFT", after, "RIGHT", 8, 0)
    r.track:Set(state)
    -- The buttons, from the right: the main one, the plain one, the lesser.
    local right = 0
    for _, key in ipairs({ "main", "plain", "lesser" }) do
        local b, spec = r[key], buttons[key]
        b:SetShown(spec ~= nil)
        if spec then
            b:SetLabel(spec[1])
            if key ~= "lesser" then
                b:SetSize(TextWidth(b.label, #spec[1] * 7) + (key == "main" and 36 or 28), 28)
            end
            b:ClearAllPoints()
            b:SetPoint("TOPRIGHT", -right, key == "lesser" and -14 or -9)
            b:SetScript("OnClick", spec[2])
            right = right + b:GetWidth() + (key == "lesser" and 0 or 8) + (key == "plain" and 6 or 0)
        end
    end
    -- The two lines of words have the row up to its buttons, however many there are.
    local words = r:GetWidth() - 68 - right - 16
    r.l1:SetWidth(words)
    r.l2:SetWidth(words)
    return waiting
end

local function MakeDone(parent, width)
    local r = CreateFrame("Frame", nil, parent)
    r:SetSize(width, DONE_ROW)
    r.mark = Mark(r, 10)
    r.mark:SetPoint("LEFT", 4, 0)
    r.mark:Set("done")
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(24, 24)
    r.icon:SetPoint("LEFT", 28, 0)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.icon:SetDesaturated(true)
    r.icon:SetAlpha(0.7)
    r.text = Style.Text(r, 13, "muted")
    r.text:SetPoint("LEFT", 64, 0)
    r.text:SetJustifyV("MIDDLE")
    r.text:SetWidth(width - 64 - 110)
    r.text:SetWordWrap(false)
    r.when = Style.Text(r, 11, "muted")
    r.when:SetPoint("RIGHT", 0, 0)
    r.when:SetJustifyH("RIGHT")
    r.action = Quiet(r)
    r.action:SetPoint("RIGHT", -84, 0)
    Style.Rule(r, "BOTTOM", "line")
    r:EnableMouse(true)
    r:SetScript("OnEnter", ShowTip)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return r
end

-- A finished order: one grey line with a tick. Or, with `state`
-- "unconfirmed", one never marked received, with a dash and maybe `action`
-- = { label, fn }.
local function Done(list, order, words, name, state, action)
    local r = Take(list, "done", MakeDone, DONE_ROW)
    r.order = order
    r.mark:Set(state or "done")
    r.action:SetShown(action ~= nil)
    if action then
        r.action:SetLabel(action[1])
        r.action:SetScript("OnClick", action[2])
    end
    r.icon:SetTexture(Icon(order))
    local recipe = ns.Orders.Recipe(order.spell)
    r.text:SetText((ns.Orders.Name(order) or "...") .. ((recipe and recipe.item) and ("   ×" .. (order.n or 1)) or "")
        .. (name and ("     " .. words .. " " .. name) or ""))
    r.when:SetText(Ago(order.e))
end

local function MakeNote(parent, width)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width, 44)
    f.text = Style.Text(f, 13, "muted")
    f.text:SetPoint("TOPLEFT", 0, -10)
    f.text:SetWidth(width)
    return f
end

local function Note(list, text)
    Take(list, "note", MakeNote, 44).text:SetText(text)
end

-- A row of three count boxes across a view.
local function Boxes(view, width)
    view.boxes = {}
    local w = math.floor((width - 20) / 3)
    for i = 1, 3 do
        local box = CountBox(view, w)
        box:SetPoint("TOPLEFT", (i - 1) * (w + 10), 0)
        view.boxes[i] = box
    end
end

-- With orders off, an order tab says where to turn them on.
local function Off(view, width)
    view.off = CreateFrame("Frame", nil, view)
    view.off:SetAllPoints()
    local text = Style.Text(view.off, 13, "muted")
    text:SetPoint("TOPLEFT", 0, -4)
    text:SetWidth(width)
    text:SetText("Guild orders are off. With them on, you can ask the guild for a craft or an enchant here, and accept what guildmates ask for. They reach guildmates who have jsal.ui with Guild orders on too.")
    local open = Style.Button(view.off, "Turn them on in Settings", "primary", 220)
    open:SetPoint("TOPLEFT", 0, -62)
    open:SetScript("OnClick", function() Window.Open("settings") end)
    view.off.text, view.off.open = text, open
end

---------------------------------------------------------------------------
-- For you.
---------------------------------------------------------------------------
local function PaintForYou()
    local view = C.views.foryou
    local on = OrdersOn()
    view.off:SetShown(not on)
    view.body:SetShown(on)
    if not on then
        C.title:SetText("Guild orders are off")
        C.sub:SetText("What guildmates ask for that you know how to make shows here.")
        C.right:SetText("")
        C.foot:SetText("")
        return
    end
    local O = ns.Orders
    local me, roster, list = O.ForMe(), Roster(), view.list
    O.Looked()
    if #me.todo > 0 then
        C.title:SetText(("%d %s waiting on you"):format(#me.todo, Plural(#me.todo, "order is", "orders are")))
    elseif #me.waiting > 0 then
        C.title:SetText(("%d %s you can make"):format(#me.waiting, Plural(#me.waiting, "order", "orders")))
    else
        C.title:SetText("Nothing is waiting on you")
    end
    C.sub:SetText("What guildmates asked for that you know how to make.")
    C.right:SetText(("%d open in the guild"):format(me.open))
    view.boxes[1]:Set("todo", #me.todo, "TO DO", #me.todo > 0 and ("you accepted " .. Plural(#me.todo, "it", "these")) or "nothing accepted")
    view.boxes[2]:Set("waiting", #me.waiting, "WAITING", #me.waiting > 0 and "you can accept " .. Plural(#me.waiting, "it", "these") or "nothing to accept")
    view.boxes[3]:Set("done", #me.done, "DONE", #me.done > 0 and "made by you, lately" or "nothing lately")
    Reset(list)
    local waiting = false
    if #me.todo > 0 then
        Head(list, "todo", "TO DO", #me.todo)
        for _, o in ipairs(me.todo) do
            local where = roster[o.by] and roster[o.by].online and (roster[o.by].zone or "online") or "offline"
            local second = "for " .. Who(o.by, roster) .. DOT .. where .. DOT .. "you accepted it " .. Ago(o.e) .. CostNote(o)
                .. (InBags(o) and (DOT .. Style.Tint("green") .. "made, in your bags|r") or "")
                .. (o.note and ("   “" .. o.note .. "”") or "")
            local id, by = o.id, o.by
            waiting = FillOrder(Take(list, "order", MakeOrder, ROW), o, "todo", second, false, {
                main = Finish(o),
                plain = { "Whisper", function() Whisper(by, Roster()) end },
                lesser = { "Give it up", function() Do(O.Release, id) end },
            }) or waiting
        end
    end
    if #me.waiting > 0 then
        Head(list, "waiting", "WAITING FOR A CRAFTER", #me.waiting)
        for _, o in ipairs(me.waiting) do
            local where = roster[o.by] and roster[o.by].online and (roster[o.by].zone or "online") or "offline"
            local second = "ordered by " .. Who(o.by, roster) .. DOT .. where .. DOT .. Ago(o.t) .. CostNote(o)
                .. (o.note and ("   “" .. o.note .. "”") or "")
            local id, by = o.id, o.by
            waiting = FillOrder(Take(list, "order", MakeOrder, ROW), o, "waiting", second, false, {
                main = { "Accept", function() Do(O.Accept, id) end },
                plain = { "Whisper", function() Whisper(by, Roster()) end },
            }) or waiting
        end
    end
    if #me.sent > 0 then
        Head(list, "sent", "SENT", #me.sent, "waiting for them to mark it received")
        for _, o in ipairs(me.sent) do
            local by = o.by
            waiting = FillOrder(Take(list, "order", MakeOrder, ROW), o, "sent", "to " .. Who(o.by, roster) .. DOT .. SentWhen(o), false, {
                plain = { "Whisper", function() Whisper(by, Roster()) end },
            }) or waiting
        end
    end
    if #me.unconfirmed > 0 then
        Head(list, "unconfirmed", "NOT CONFIRMED", #me.unconfirmed, "sent over a week ago, never marked received")
        for _, o in ipairs(me.unconfirmed) do Done(list, o, "sent to", o.by .. ", not confirmed", "unconfirmed") end
    end
    if #me.done > 0 then
        Head(list, "done", "DONE", #me.done, "shown for 3 days")
        for _, o in ipairs(me.done) do Done(list, o, "made for", o.by) end
    end
    if #me.todo + #me.waiting + #me.sent + #me.unconfirmed + #me.done == 0 then
        Note(list, "No orders for you right now. When a guildmate orders something you know how to make, it shows here and you're told in chat.")
    end
    Close(list)
    C.foot:SetText((me.other > 0 and ("%d more open %s for a profession you don't have. "):format(me.other, Plural(me.other, "order is", "orders are")) or "")
        .. "Mail an order from any mailbox and it's marked sent for you. Enchants are done in a trade: whisper to arrange where to meet.")
    C.Later(waiting)
end

---------------------------------------------------------------------------
-- Your orders: the asking card.
---------------------------------------------------------------------------
-- Every recipe by its name, for the card's search. A recipe's spell is named
-- for what it makes, and the game always has a spell's name, where an item's
-- may need asking for.
local SKIP = { [129] = true }   -- First Aid is everyone's
local function Names()
    if C.names then return C.names end
    local list = {}
    for line, source in pairs(ns.ProfessionData) do
        if type(line) == "number" and type(source) == "table" and type(source.recipes) == "table" and not SKIP[line] then
            for _, recipe in ipairs(ns.Professions.Recipes(line) or {}) do
                local name = Compat.SpellInfo(recipe.spell)
                if name then list[#list + 1] = { spell = recipe.spell, name = name, lower = name:lower(), line = line } end
            end
        end
    end
    table.sort(list, function(a, b)
        if a.lower ~= b.lower then return a.lower < b.lower end
        return a.spell < b.spell
    end)
    if #list > 0 then C.names = list end
    return list
end

-- Recipes whose name has the text in it: those starting with it first. Also how many there
-- were before the list was cut to `limit`.
function C.Find(text, limit)
    text = strtrim(text or ""):lower()
    local first, rest = {}, {}
    -- Under two letters nothing is looked for: none found, of none.
    if #text < 2 then return first, 0 end
    for _, entry in ipairs(Names()) do
        local at = entry.lower:find(text, 1, true)
        if at == 1 then first[#first + 1] = entry elseif at then rest[#rest + 1] = entry end
    end
    for _, entry in ipairs(rest) do first[#first + 1] = entry end
    local total = #first
    for i = (limit or 8) + 1, #first do first[i] = nil end
    return first, total
end

-- What an enchant goes on, from its name: the slot, and a word for it.
-- Each: the words in the enchant's name, the slot it's worn in, a word for what you wear
-- there, the kinds of item it can go on (as the game names where an item is worn), and how
-- to ask for one.
local SLOTS = {
    { "2H Weapon", 16, "weapon", { INVTYPE_2HWEAPON = true }, "a two-handed weapon" },
    { "Weapon", 16, "weapon", { INVTYPE_WEAPON = true, INVTYPE_WEAPONMAINHAND = true, INVTYPE_WEAPONOFFHAND = true, INVTYPE_2HWEAPON = true },
      "a weapon" },
    { "Shield", 17, "shield", { INVTYPE_SHIELD = true }, "a shield" },
    { "Bracer", 9, "bracers", { INVTYPE_WRIST = true }, "bracers" },
    { "Chest", 5, "chest", { INVTYPE_CHEST = true, INVTYPE_ROBE = true }, "a chest piece" },
    { "Cloak", 15, "cloak", { INVTYPE_CLOAK = true }, "a cloak" },
    { "Boots", 8, "boots", { INVTYPE_FEET = true }, "boots" },
    { "Gloves", 10, "gloves", { INVTYPE_HAND = true }, "gloves" },
}
local function SlotFor(spell)
    local name = Compat.SpellInfo(spell) or ""
    for _, slot in ipairs(SLOTS) do
        if name:find("Enchant " .. slot[1], 1, true) then return slot[2], slot[3], slot[4], slot[5] end
    end
end

-- Whether an enchant can go on an item: the item is worn where the enchant's name says.
-- An enchant whose name names no slot takes anything that can be worn. Without the game's
-- word for where an item is worn, anything is taken. Also gives what to ask for instead.
local function Fits(spell, item)
    local _, _, fits, say = SlotFor(spell)
    local info = C_Item and C_Item.GetItemInfoInstant
    if not info then return true, say end
    local _, _, _, worn = info(item)
    if fits then return worn ~= nil and fits[worn] == true, say end
    return worn ~= nil and worn ~= "" and worn ~= "INVTYPE_NON_EQUIP_IGNORE", "something you can wear"
end

local function IsEnchant(spell)
    local recipe, line = ns.Orders.Recipe(spell)
    return recipe ~= nil and recipe.item == nil and line == ENCHANTING
end

-- Picks what to ask for. An enchant starts on what you wear in its slot.
function C.Pick(spell)
    local a = C.ask
    a.spell, a.on, a.worn = spell, nil, nil
    if spell and IsEnchant(spell) then
        local slot, word = SlotFor(spell)
        local worn = slot and GetInventoryItemID and GetInventoryItemID("player", slot)
        -- Only what the enchant can go on: a one-handed weapon isn't offered for a two-hander's enchant.
        if worn and not Fits(spell, worn) then worn = nil end
        a.on, a.worn = worn or nil, worn and word or nil
    end
    if C.card then
        C.card.what:SetText(spell and (Compat.SpellInfo(spell) or "") or "")
        C.card.what:ClearFocus()
        C.card.drop:Hide()
        C.card.message:SetText("")
    end
end

local function PaintAsk()
    local card, a = C.card, C.ask
    local enchant = a.spell ~= nil and IsEnchant(a.spell)
    card.countLabel:SetText(enchant and "ON" or "HOW MANY")
    card.count.well:SetShown(not enchant)
    card.on:SetShown(enchant)
    if enchant then
        if a.on then
            card.on.text:SetText(ItemTint(a.on) .. (Compat.ItemName(a.on) or "an item") .. "|r")
            card.on.hint:SetText(a.worn and ("your " .. a.worn) or "")
        else
            card.on.text:SetText(Style.Tint("muted") .. "Drop an item here|r")
            card.on.hint:SetText("")
        end
    end
    card.have:SetSelected(a.have)
    card.need:SetSelected(not a.have)
    card.hint:SetShown(card.what:GetText() == "" and not card.what:HasFocus())
    card.noteHint:SetShown(card.note:GetText() == "" and not card.note:HasFocus())
    card.post:SetEnabled(a.spell ~= nil)
    card.post:SetKind(a.spell and "primary" or "plain")
    -- The card's foot: who makes it, and what it takes.
    local makers, materials = "", {}
    if a.spell then
        local recipe = ns.Orders.Recipe(a.spell)
        local people = ns.Crafters and ns.Crafters.ForItem and ns.Crafters.ForItem(recipe.item or -a.spell) or {}
        local roster, on, names = Roster(), 0, {}
        for _, p in ipairs(people) do
            if #names < 3 then names[#names + 1] = Who(p.name, roster) end
            if p.online then on = on + 1 end
        end
        if #names > 0 then
            makers = table.concat(names, ", ") .. (#people > 3 and (" and %d more"):format(#people - 3) or "")
                .. Plural(#people, " makes this", " make this") .. DOT .. (on > 0 and (on == #people and "online" or (on .. " online")) or "none online now")
        else
            makers = "Nobody sharing recipes makes this yet"
        end
        materials = ns.Orders.Materials({ spell = a.spell, n = enchant and 1 or math.max(1, tonumber(card.count:GetText()) or 1) })
    end
    card.makers:SetText(a.spell and makers or "Pick what you need above: who makes it and what it takes show here.")
    card.list:SetShown(a.spell ~= nil and ns.Shopping ~= nil and ns.Shopping.running == true)
    -- From the right: the shopping list's words, then the materials after "Takes". Who makes
    -- it keeps MAKERS_W at the left; the materials have the rest, as many as fit, and the
    -- others are counted ("+2 more").
    for i, m in ipairs(materials) do
        local chip = card.chips[i]
        if not chip then
            chip = Chip(card.strip)
            card.chips[i] = chip
        end
        chip:Set(m.count .. " " .. (Compat.ItemName(m.item) or "..."), m.item)
    end
    local strip = C.width - 2
    local room = strip - 16 - MAKERS_W - 16 - (TextWidth(card.takes, 30) + 8) - (card.list:GetWidth() + 14) - 16
    local shown, used = 0, 0
    for i = 1, #materials do
        local w = card.chips[i]:GetWidth() + 5
        -- Any but the last also needs room for the count of the rest after it.
        if used + w + (i < #materials and MORE_W or 0) > room then break end
        shown, used = i, used + w
    end
    card.more:SetText(shown < #materials and ("+%d more"):format(#materials - shown) or "")
    local before = card.list
    if shown < #materials and #materials > 0 then
        card.more:ClearAllPoints()
        card.more:SetPoint("RIGHT", card.list, "LEFT", -14, 0)
        before = card.more
    end
    for i = #materials, 1, -1 do
        local chip = card.chips[i]
        chip:SetShown(i <= shown)
        if i <= shown then
            chip:ClearAllPoints()
            chip:SetPoint("RIGHT", before, "LEFT", (before == card.list and -14) or (before == card.more and -8) or -5, 0)
            before = chip
        end
    end
    for i = #materials + 1, #card.chips do card.chips[i]:Hide() end
    card.takes:SetShown(#materials > 0)
    card.takes:ClearAllPoints()
    card.takes:SetPoint("RIGHT", before, "LEFT", -8, 0)
    -- Who makes it has the strip up to "Takes", and is cut short there, not drawn over it.
    local taken = #materials > 0 and (used + (shown < #materials and MORE_W or 0) + TextWidth(card.takes, 30) + 8) or 0
    card.makers:SetWidth(math.max(MAKERS_W, strip - 16 - 16 - taken - (card.list:GetWidth() + 14) - 16))
end

-- The names under the search box as you type.
local function PaintDrop()
    local card = C.card
    local found, total = {}, 0
    if card.what:HasFocus() then found, total = C.Find(card.what:GetText(), 8) end
    -- More than fit: the last line says how many, and how to get to them.
    local more = total - #found
    card.drop:SetShown(#found > 0)
    card.drop:SetHeight(#found * 26 + 2 + (more > 0 and 24 or 0))
    card.drop.more:SetText(more > 0 and ("and %d more: type more of its name"):format(more) or "")
    for i, row in ipairs(card.drop.rows) do
        local entry = found[i]
        row:SetShown(entry ~= nil)
        if entry then
            row.spell = entry.spell
            row.text:SetText(entry.name .. "   " .. Style.Tint("muted") .. (ns.Professions.Name(entry.line) or "") .. "|r")
        end
    end
end

local function Post()
    local card, a = C.card, C.ask
    if not a.spell then return end
    local ok, why = ns.Orders.Post(a.spell, IsEnchant(a.spell) and 1 or tonumber(card.count:GetText()), a.have, a.on, card.note:GetText())
    if not ok then
        card.message:SetText(why or "")
        return
    end
    card.note:SetText("")
    card.count:SetText("1")
    C.Pick(nil)
    C.Paint()
end

local function Label(parent, text, x, y)
    local t = Style.Text(parent, 10, "muted", nil, true)
    t:SetPoint("TOPLEFT", x, y)
    t:SetText(text)
    return t
end

local function BuildCard(view, width)
    local card = CreateFrame("Frame", nil, view.body)
    card:SetSize(width, ASK_H)
    card:SetPoint("TOPLEFT", 0, -CARD_Y)
    Style.Fill(card, "well")
    Style.Border(card, "cardLine")
    C.card = card
    card.strip = CreateFrame("Frame", nil, card)
    card.strip:SetPoint("BOTTOMLEFT", 1, 1)
    card.strip:SetPoint("BOTTOMRIGHT", -1, 1)
    card.strip:SetHeight(38)
    Style.Fill(card.strip, "titleBar")
    Style.Rule(card.strip, "TOP", "cardLine")

    Label(card, "ASK THE GUILD FOR", 16, -12)
    card.what = Style.Field(card, 340)
    card.what.well:SetHeight(30)
    card.what.well:SetPoint("TOPLEFT", 16, -28)
    card.what:SetFont(Style.font, 13, "")
    card.what:SetMaxLetters(60)
    card.hint = Style.Text(card.what.well, 12, "muted")
    card.hint:SetPoint("LEFT", 10, 0)
    card.hint:SetText("Type its name: a bag, a potion, an enchant")

    card.countLabel = Label(card, "HOW MANY", 370, -12)
    card.count = Style.Field(card, 70, true)
    card.count.well:SetHeight(30)
    card.count.well:SetPoint("TOPLEFT", 370, -28)
    card.count:SetText("1")
    -- An enchant has no count: it has something it goes on.
    card.on = CreateFrame("Button", nil, card)
    card.on:SetSize(230, 30)
    card.on:SetPoint("TOPLEFT", 370, -28)
    Style.Fill(card.on, "well")
    Style.Border(card.on, "lineStrong")
    card.on.text = Style.Text(card.on, 13, "text", nil, true)
    card.on.text:SetPoint("LEFT", 10, 0)
    card.on.hint = Style.Text(card.on, 11, "muted")
    card.on.hint:SetPoint("RIGHT", -10, 0)
    local function Dropped()
        local kind, item = GetCursorInfo()
        if kind ~= "item" or not item then return end
        ClearCursor()
        local fits, say = Fits(C.ask.spell, item)
        if not fits then
            C.card.message:SetText(("%s can't take this enchant. Drop %s on the box."):format(Compat.ItemName(item) or "That", say or "an item it goes on"))
            return
        end
        C.card.message:SetText("")
        C.ask.on, C.ask.worn = item, nil
        PaintAsk()
    end
    card.on:SetScript("OnReceiveDrag", Dropped)
    card.on:SetScript("OnClick", Dropped)
    card.on:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("What the enchant goes on")
        GameTooltip:AddLine("It starts as what you're wearing there. Drop another item the enchant can go on to change it.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    card.on:SetScript("OnLeave", function() GameTooltip:Hide() end)

    Label(card, "MATERIALS", 614, -12)
    local half = math.floor((width - 16 - 614) / 2)
    card.have = Style.Button(card, "I have them", "tab", half)
    card.have:SetHeight(30)
    card.have:SetPoint("TOPLEFT", 614, -28)
    card.need = Style.Button(card, "I need them too", "tab", half)
    card.need:SetHeight(30)
    card.need:SetPoint("LEFT", card.have, "RIGHT", 0, 0)
    card.have:SetScript("OnClick", function() C.ask.have = true; PaintAsk() end)
    card.need:SetScript("OnClick", function() C.ask.have = false; PaintAsk() end)

    card.post = Style.Button(card, "Post to the guild", "primary", 170)
    card.post:SetHeight(30)
    card.post:SetPoint("TOPRIGHT", -16, -72)
    card.post:SetScript("OnClick", Post)
    card.note = Style.Field(card, width - 32 - 170 - 14)
    card.note.well:SetHeight(30)
    card.note.well:SetPoint("TOPLEFT", 16, -72)
    card.note:SetFont(Style.font, 13, "")
    card.note:SetMaxLetters(ns.Orders and ns.Orders.NOTE or 60)
    card.noteHint = Style.Text(card.note.well, 12, "muted")
    card.noteHint:SetPoint("LEFT", 10, 0)
    card.noteHint:SetText("A note, if you like: where to meet, how soon")
    card.note:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    card.note:SetScript("OnTextChanged", function() PaintAsk() end)
    card.note:SetScript("OnEditFocusGained", function() PaintAsk() end)
    card.note:SetScript("OnEditFocusLost", function() PaintAsk() end)
    card.count:SetScript("OnTextChanged", function() PaintAsk() end)

    card.makers = Style.Text(card.strip, 12, "muted")
    card.makers:SetPoint("LEFT", 16, 0)
    card.makers:SetJustifyV("MIDDLE")
    card.makers:SetWordWrap(false)
    card.list = Quiet(card.strip, "+ Shopping list")
    card.list:SetPoint("RIGHT", -16, 0)
    card.list:SetScript("OnClick", function()
        local a = C.ask
        if a.spell and ns.Shopping and ns.Shopping.running then
            ns.Shopping.AddCraft(a.spell, IsEnchant(a.spell) and 1 or math.max(1, tonumber(card.count:GetText()) or 1))
        end
    end)
    card.takes = Style.Text(card.strip, 11, "muted")
    card.takes:SetText("Takes")
    card.more = Style.Text(card.strip, 11, "muted")
    card.chips = {}
    card.message = Style.Text(card, 12, "red")
    card.message:SetPoint("BOTTOMLEFT", card, "TOPLEFT", 0, 7)

    -- The names under the search box.
    card.drop = CreateFrame("Frame", nil, card)
    card.drop:SetWidth(340)
    card.drop:SetPoint("TOPLEFT", card.what.well, "BOTTOMLEFT", 0, -2)
    card.drop:SetFrameLevel((card:GetFrameLevel() or 1) + 20)
    Style.Fill(card.drop, "titleBar")
    Style.Border(card.drop, "lineStrong")
    card.drop.rows = {}
    for i = 1, 8 do
        local row = CreateFrame("Button", nil, card.drop)
        row:SetSize(338, 26)
        row:SetPoint("TOPLEFT", 1, -1 - (i - 1) * 26)
        row.text = Style.Text(row, 12, "text")
        row.text:SetPoint("LEFT", 9, 0)
        row.text:SetWidth(320)
        row.text:SetWordWrap(false)
        row:SetScript("OnClick", function(self)
            C.Pick(self.spell)
            PaintAsk()
        end)
        Style.Hover(row)
        card.drop.rows[i] = row
    end
    card.drop.more = Style.Text(card.drop, 11, "muted")
    card.drop.more:SetPoint("BOTTOMLEFT", 10, 7)
    card.drop:Hide()
    card.what:SetScript("OnTextChanged", function(self, userInput)
        -- Typing over a picked name lets go of the pick.
        if userInput then
            C.ask.spell, C.ask.on, C.ask.worn = nil, nil, nil
            C.card.message:SetText("")
        end
        PaintDrop()
        PaintAsk()
    end)
    card.what:SetScript("OnEditFocusGained", function() PaintDrop(); PaintAsk() end)
    card.what:SetScript("OnEditFocusLost", function()
        PaintAsk()
        -- A moment later, so a click on one of the names lands first.
        Compat.After(0.3, function()
            if not card.what:HasFocus() then card.drop:Hide() end
        end)
    end)
    card.what:SetScript("OnEnterPressed", function(self)
        local first = C.Find(self:GetText(), 1)[1]
        if first and not C.ask.spell then C.Pick(first.spell) end
        self:ClearFocus()
        PaintAsk()
    end)
end

local function PaintYours()
    local view = C.views.yours
    local on = OrdersOn()
    view.off:SetShown(not on)
    view.body:SetShown(on)
    if not on then
        C.title:SetText("Guild orders are off")
        C.sub:SetText("Ask the guild for a craft or an enchant here.")
        C.right:SetText("")
        C.foot:SetText("")
        return
    end
    local O = ns.Orders
    local mine, roster, list = O.Mine(), Roster(), view.list
    local open = #mine.waiting + #mine.making + #mine.sent
    C.title:SetText(open > 0 and ("%d %s of yours %s open"):format(open, Plural(open, "order", "orders"), Plural(open, "is", "are")) or "Ask the guild for something")
    C.sub:SetText("Ask the guild for a craft or an enchant.")
    C.right:SetText("")
    view.boxes[1]:Set("waiting", #mine.waiting, "WAITING",
        #mine.waiting > 0 and ("nobody has accepted " .. Plural(#mine.waiting, "it", "them") .. " yet") or "nothing waiting")
    view.boxes[2]:Set("making", #mine.making, "BEING MADE",
        #mine.making > 0 and ("a guildmate accepted " .. Plural(#mine.making, "it", "them")) or "nothing being made")
    view.boxes[3]:Set("done", #mine.done, "DONE", #mine.done > 0 and "received lately" or "nothing lately")
    PaintAsk()
    Reset(list)
    local waiting = false
    if #mine.waiting > 0 then
        Head(list, "waiting", "WAITING FOR A CRAFTER", #mine.waiting)
        for _, o in ipairs(mine.waiting) do
            local recipe = O.Recipe(o.spell)
            local people = ns.Crafters and ns.Crafters.ForItem and ns.Crafters.ForItem(recipe.item or -o.spell) or {}
            local maker = people[1] and people[1].online and people[1].name or nil
            -- Who could make it: someone online to whisper, else who makes it and when they
            -- were last seen, else that nobody sharing their recipes does.
            local who
            if maker then
                who = Who(maker, roster) .. " makes this and is online"
            elseif people[1] then
                who = Who(people[1].name, roster) .. " makes this, " .. ns.Crafters.Ago(people[1].seen)
            else
                who = "nobody sharing recipes makes this yet"
            end
            -- The cost before who makes it: if the line runs out of room, the number isn't what's cut.
            local second = "Ordered " .. Ago(o.t) .. CostNote(o) .. DOT .. who .. (o.note and ("   “" .. o.note .. "”") or "")
            local id = o.id
            waiting = FillOrder(Take(list, "order", MakeOrder, ROW), o, "waiting", second, true, {
                plain = maker and { "Whisper " .. (maker:match("^%S+") or maker), function() Whisper(maker, Roster()) end } or nil,
                lesser = { "Cancel", function() Do(O.Cancel, id) end },
            }) or waiting
        end
    end
    if #mine.making > 0 then
        Head(list, "making", "BEING MADE", #mine.making)
        for _, o in ipairs(mine.making) do
            local second = Who(o.c, roster) .. " is making it" .. DOT .. "accepted " .. Ago(o.e) .. (o.note and ("   “" .. o.note .. "”") or "")
            local id, crafter = o.id, o.c
            waiting = FillOrder(Take(list, "order", MakeOrder, ROW), o, "making", second, true, {
                main = { "Mark received", function() Do(O.GotIt, id) end },
                plain = { "Whisper", function() Whisper(crafter, Roster()) end },
                lesser = { "Cancel", function() Do(O.Cancel, id) end },
            }) or waiting
        end
    end
    if #mine.sent > 0 then
        Head(list, "got", "SENT TO YOU", #mine.sent, "mark it received once you have it")
        for _, o in ipairs(mine.sent) do
            local second = "made by " .. Who(o.c, roster) .. DOT .. SentWhen(o) .. (o.s == "m" and ": check your mailbox" or "")
            local id, crafter = o.id, o.c
            waiting = FillOrder(Take(list, "order", MakeOrder, ROW), o, "got", second, true, {
                main = { "Mark received", function() Do(O.GotIt, id) end },
                plain = { "Whisper", function() Whisper(crafter, Roster()) end },
            }) or waiting
        end
    end
    if #mine.unconfirmed > 0 then
        Head(list, "unconfirmed", "NOT CONFIRMED", #mine.unconfirmed, "sent over a week ago, never marked received")
        for _, o in ipairs(mine.unconfirmed) do
            local id = o.id
            Done(list, o, "sent by", (o.c or "a guildmate") .. ", not confirmed", "unconfirmed", { "Mark received", function() Do(O.GotIt, id) end })
        end
    end
    if #mine.done > 0 then
        Head(list, "done", "DONE", #mine.done, "shown for 3 days")
        for _, o in ipairs(mine.done) do Done(list, o, "made by", o.c) end
    end
    if open + #mine.unconfirmed + #mine.done == 0 then
        Note(list, "You haven't ordered anything yet. Type what you need above, say whether you have the materials, and post it: guildmates who can make it are told.")
    end
    Close(list)
    C.foot:SetText("Mark an order received once you have it. An order nobody accepts closes by itself after 7 days.")
    C.Later(waiting)
end

---------------------------------------------------------------------------
-- Crafters: who makes what.
---------------------------------------------------------------------------
-- Starts an order for a recipe: over to Your orders, with it picked.
function C.Ask(spell)
    C.Show("yours", true)
    if not OrdersOn() or not C.card then return end
    C.Pick(spell)
    PaintAsk()
end

local function MakeFound(parent, width)
    local r = CreateFrame("Frame", nil, parent)
    r:SetSize(width, FOUND_ROW)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(32, 32)
    r.icon:SetPoint("LEFT", 0, 0)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.name = Style.Text(r, 14, "text", nil, true)
    r.name:SetPoint("TOPLEFT", 46, -8)
    r.name:SetWidth(width - 46 - 280)
    r.name:SetWordWrap(false)
    r.who = Style.Text(r, 12, "muted")
    r.who:SetPoint("TOPLEFT", 46, -28)
    r.who:SetWidth(width - 46 - 280)
    r.who:SetWordWrap(false)
    r.order = Style.Button(r, "Order", "primary", 80)
    r.order:SetPoint("RIGHT", 0, 0)
    r.whisper = Style.Button(r, "Whisper", "plain", 140)
    r.whisper:SetPoint("RIGHT", r.order, "LEFT", -8, 0)
    Style.Rule(r, "BOTTOM", "line")
    r:EnableMouse(true)
    r:SetScript("OnEnter", function(self)
        if not (self.item or self.spell) then return end
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        if self.item then GameTooltip:SetItemByID(self.item) else GameTooltip:SetSpellByID(self.spell) end
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return r
end

local function Found(list, entry, roster)
    local r = Take(list, "found", MakeFound, FOUND_ROW)
    local Crafters = ns.Crafters
    r.item, r.spell = entry.row.item, entry.row.spell
    r.icon:SetTexture((entry.row.item and Compat.ItemIcon(entry.row.item)) or select(2, Compat.SpellInfo(entry.row.spell)))
    r.name:SetText(ItemTint(entry.row.item) .. entry.name .. "|r")
    local on, off = {}, {}
    for _, p in ipairs(entry.people) do
        if p.online then
            on[#on + 1] = Who(p.name, roster) .. ((roster[p.name] and roster[p.name].zone) and (Style.Tint("muted") .. " in " .. roster[p.name].zone .. "|r") or "")
        elseif #off < 3 then
            off[#off + 1] = #off == 0 and (p.name .. " (" .. Crafters.Ago(p.seen) .. ")") or p.name
        end
    end
    local who = table.concat(on, ", ")
    if #off > 0 then who = who .. (who ~= "" and DOT or "") .. table.concat(off, ", ") end
    r.who:SetText(who)
    local first, spell, name = entry.people[1], entry.row.spell, entry.name
    r.whisper:SetShown(first ~= nil and first.online == true)
    if first and first.online then
        r.whisper:SetLabel("Whisper " .. (first.name:match("^%S+") or first.name))
        r.whisper:SetScript("OnClick", function() Crafters.Whisper(first, name) end)
    end
    r.order:SetScript("OnClick", function() C.Ask(spell) end)
end

local function MakePerson(parent, width)
    local card = CreateFrame("Frame", nil, parent)
    card:SetSize(math.floor((width - 14) / 2), CARD_H)
    Style.Fill(card, "well")
    Style.Border(card, "cardLine")
    card.dot = card:CreateTexture(nil, "ARTWORK")
    card.dot:SetSize(7, 7)
    card.dot:SetPoint("TOPLEFT", 14, -17)
    card.name = Style.Text(card, 14, "text", nil, true)
    card.name:SetPoint("TOPLEFT", 28, -11)
    card.name:SetWordWrap(false)
    card.where = Style.Text(card, 12, "muted")
    card.where:SetPoint("BOTTOMLEFT", card.name, "BOTTOMRIGHT", 0, 1)
    card.where:SetWordWrap(false)
    card.chips = {}
    card.more = Style.Text(card, 11, "muted")
    card.whisper = Style.Button(card, "Whisper", "plain", 84)
    card.whisper:SetHeight(24)
    card.whisper:SetPoint("TOPRIGHT", -12, -10)
    return card
end

-- A profession on a guildmate's card: its name and skill, to click.
local function ProfChip(card, k)
    local c = card.chips[k]
    if c then return c end
    c = CreateFrame("Button", nil, card)
    c:SetHeight(22)
    Style.Fill(c, "line")
    c.text = Style.Text(c, 11, "text")
    c.text:SetPoint("CENTER")
    Style.Hover(c)
    c:SetScript("OnClick", function(self)
        if not self.prof or self.prof.recipes == 0 then return end
        C.pick = { name = self.person.name, line = self.prof.line, label = self.prof.name }
        C.views.crafters.search:SetText("")
        C.views.crafters.search:ClearFocus()
        C.Paint()
    end)
    card.chips[k] = c
    return c
end

local function Person(list, p, roster, column)
    local card
    if column == 0 then
        card = Take(list, "person", MakePerson, CARD_H + 12)
    else
        -- The second of a pair sits beside the first, on its line.
        local y = list.y
        card = Take(list, "person", MakePerson, 0)
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", card:GetWidth() + 14, -(y - CARD_H - 12))
    end
    card.dot:SetColorTexture(Style.Color(p.online and "green" or "lineStrong"))
    card.name:SetText(Who(p.name, roster))
    card.where:SetText(DOT .. (p.online and (p.zone or "online") or ns.Crafters.Ago(p.seen)))
    local x, limit, left = 14, card:GetWidth() - 14, 0
    for k, prof in ipairs(p.profs) do
        local c = ProfChip(card, k)
        -- A gathering skill is shared in steps of 25: "125+".
        local words = ("%s  %d%s"):format(prof.name, prof.skill, prof.steps and "+" or "")
        c.text:SetText(words)
        -- One with recipes to list is brighter: it opens them.
        c.text:SetTextColor(Style.Color(prof.recipes > 0 and "text" or "muted"))
        local w = TextWidth(c.text, #words * 6) + 16
        c.person, c.prof = p, prof
        if x + w > limit then
            c:Hide()
            left = left + 1
        else
            c:SetWidth(w)
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", x, -42)
            c:Show()
            x = x + w + 6
        end
    end
    for k = #p.profs + 1, #card.chips do card.chips[k]:Hide() end
    card.more:SetText(left > 0 and ("+" .. left) or "")
    card.more:ClearAllPoints()
    card.more:SetPoint("TOPLEFT", x, -46)
    card.whisper:SetShown(p.online)
    card.whisper:SetScript("OnClick", function() ns.Crafters.Whisper(p) end)
end

local function PaintCrafters()
    local view = C.views.crafters
    local list = view.list
    local Crafters = ns.Crafters
    local on = CraftersOn()
    view.searchWell:SetShown(on)
    view.back:Hide()
    Reset(list)
    C.right:SetText("")
    if not on then
        C.title:SetText("Guild crafters is off")
        C.sub:SetText("Who in the guild makes what shows here.")
        Note(list, "Guild crafters is off. Turn it on in Settings, under Professions: it shares your recipes with guildmates who have jsal.ui, and shows theirs here.")
        Close(list)
        C.foot:SetText("")
        return
    end
    local text = view.search:GetText()
    local typed = strtrim(text) ~= ""
    view.hint:SetShown(text == "" and not view.search:HasFocus())
    -- Typing goes back to the search of everyone's crafts.
    if typed then C.pick = nil end
    local sharing = Crafters.Count()
    local roster = Roster()
    C.title:SetText(("%d %s"):format(sharing, Plural(sharing, "guildmate shares their recipes", "guildmates share their recipes")))
    C.sub:SetText("Search what you need, then order it or whisper its maker.")
    C.foot:SetText("Click a profession to see what they make with it. Order puts it on Your orders, ready to post.")
    if not IsInGuild() then
        Note(list, "Guild crafters shows what your guildmates can make. Join a guild to use it.")
    elseif sharing == 0 then
        Note(list, "No recipes heard yet. Guildmates with jsal.ui share theirs once they've opened their profession windows, and their crafts show here as they come in.")
    elseif typed or C.pick then
        local found
        if C.pick then
            found = Crafters.Makes(C.pick.name, C.pick.line)
            Head(list, nil, ("%s'S %s"):format(C.pick.name:upper(), C.pick.label:upper()), #found)
            view.back:Show()
            if #found == 0 then Note(list, "Nothing to list yet: the game is still loading their names.") end
        else
            found = Crafters.Search(text, 60)
            if #found == 0 then Note(list, "No guildmate makes anything by that name yet.") end
        end
        for _, entry in ipairs(found) do Found(list, entry, roster) end
    else
        local people = Crafters.Sharing()
        local online = 0
        for _, p in ipairs(people) do if p.online then online = online + 1 end end
        C.right:SetText(online .. " online")
        Head(list, nil, "EVERYONE WHO SHARES", #people)
        for i, p in ipairs(people) do Person(list, p, roster, (i - 1) % 2) end
    end
    Close(list)
end

---------------------------------------------------------------------------
-- The window.
---------------------------------------------------------------------------
local TABS = { { key = "foryou", label = "For you" }, { key = "yours", label = "Your orders" }, { key = "crafters", label = "Crafters" } }
local PAINT = { foryou = PaintForYou, yours = PaintYours, crafters = PaintCrafters }

local function Tab(parent, spec)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(34)
    b.label = Style.Text(b, 14, "secondary", nil, true)
    b.label:SetPoint("LEFT", 14, 0)
    b.label:SetJustifyV("MIDDLE")
    b.label:SetText(spec.label)
    b.badge = CreateFrame("Frame", nil, b)
    b.badge:SetHeight(18)
    b.badge:SetPoint("LEFT", b.label, "RIGHT", 8, 0)
    b.fill = Style.Fill(b.badge, "well")
    b.edges = Style.Border(b.badge, "cardLine")
    b.count = Style.Text(b.badge, 11, "muted", nil, true)
    b.count:SetPoint("CENTER")
    b.under = b:CreateTexture(nil, "ARTWORK")
    b.under:SetColorTexture(Style.Color("gold"))
    b.under:SetPoint("BOTTOMLEFT")
    b.under:SetPoint("BOTTOMRIGHT")
    b.under:SetHeight(2)
    -- `hot`: a gold badge, for a number that waits on you.
    function b:Set(selected, n, hot)
        self.label:SetTextColor(Style.Color(selected and "text" or "secondary"))
        self.under:SetShown(selected)
        self.badge:SetShown(n ~= nil)
        local w = TextWidth(self.label, #spec.label * 8) + 28
        if n then
            self.count:SetText(n)
            self.count:SetTextColor(Style.Color(hot and "onGold" or "muted"))
            self.fill:SetColorTexture(Style.Color(hot and "gold" or "well"))
            Style.SetBorder(self.edges, hot and "gold" or "cardLine")
            local bw = math.max(18, TextWidth(self.count, 8) + 10)
            self.badge:SetWidth(bw)
            w = w + 8 + bw
        end
        self:SetWidth(w)
    end
    b:SetScript("OnClick", function() C.Show(spec.key) end)
    b:SetScript("OnEnter", function(self) self.label:SetTextColor(Style.Color("text")) end)
    b:SetScript("OnLeave", function() C.PaintTabs() end)
    return b
end

function C.PaintTabs()
    local tab = CurrentTab()
    local O = OrdersOn() and ns.Orders or nil
    local todo = O and O.Badge() or 0
    local mine = O and O.Mine() or nil
    -- A number only when there's something to count.
    local function Some(n) return n and n > 0 and n or nil end
    local counts = {
        foryou = Some(O and todo),
        yours = Some(mine and (#mine.waiting + #mine.making)),
        crafters = Some(CraftersOn() and ns.Crafters.Count()),
    }
    local x = 0
    for _, spec in ipairs(TABS) do
        local b = C.tabs[spec.key]
        b:Set(spec.key == tab, counts[spec.key], spec.key == "foryou" and todo > 0)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", x, -66)
        x = x + b:GetWidth() + 6
    end
end

-- A name the game hadn't loaded leaves "..." on a row: look again in a
-- moment, a few times at most.
function C.Later(waiting)
    if not waiting then
        C.tries = 0
        return
    end
    C.tries = (C.tries or 0) + 1
    if C.tries > 5 or C.queued then return end
    C.queued = true
    Compat.After(1, function()
        C.queued = false
        xpcall(C.Repaint, ns.Report)
    end)
end

function C.Paint()
    if not C.page then return end
    local tab = CurrentTab()
    for key, view in pairs(C.views) do view:SetShown(key == tab) end
    PAINT[tab]()
    C.PaintTabs()
end

-- Repaints whichever size is on screen.
function C.Repaint()
    if Window.IsOpen("guildcrafts") then C.Paint() end
    if C.small and C.small:IsShown() then C.PaintSmall() end
end

-- Opens the window on a tab, in the size it was last left in. `full` asks
-- for the full one whatever it was (asking for something needs its card).
function C.Show(tab, full)
    if tab and PAINT[tab] then View().tab = tab end
    if full then View().compact = nil end
    if View().compact then
        Window.Close("guildcrafts")
        C.OpenSmall()
    else
        if C.small then C.small:Hide() end
        if C.page and Window.IsOpen("guildcrafts") then
            C.Paint()
        else
            Window.Open("guildcrafts", true)
        end
    end
end

-- The switch in a title bar: a small box and a word, left of the close cross.
local function ModeSwitch(bar, label, compact)
    local b = CreateFrame("Button", nil, bar)
    b:SetHeight(20)
    b.box = CreateFrame("Frame", nil, b)
    b.box:SetSize(12, 12)
    b.box:SetPoint("LEFT", 0, 0)
    Style.Border(b.box, "secondary")
    b.inner = b.box:CreateTexture(nil, "ARTWORK")
    b.inner:SetColorTexture(Style.Color("secondary"))
    -- The full window's switch shows a small window in a big one's corner; the
    -- small window's, a box filled out.
    if compact then
        b.inner:SetSize(6, 6)
        b.inner:SetPoint("TOPRIGHT", -1, -1)
    else
        b.inner:SetSize(8, 8)
        b.inner:SetPoint("CENTER")
    end
    b.label = Style.Text(b, 11, "secondary", nil, true)
    b.label:SetPoint("LEFT", b.box, "RIGHT", 6, 0)
    b.label:SetText(label)
    b:SetWidth(18 + TextWidth(b.label, #label * 6))
    b:SetPoint("RIGHT", bar, "RIGHT", -44, 0)
    b:SetScript("OnEnter", function(self) self.label:SetTextColor(Style.Color("text")) end)
    b:SetScript("OnLeave", function(self) self.label:SetTextColor(Style.Color("secondary")) end)
    b:SetScript("OnClick", function()
        View().compact = compact and true or nil
        C.Show()
    end)
    return b
end

local function BuildView(page, key, width, height)
    local view = CreateFrame("Frame", nil, page)
    view:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", 0, -TOP)
    view:SetSize(width, height)
    C.views[key] = view
    return view
end

Window.Page("guildcrafts", function(page)
    local width, height = page.contentWidth or Window.contentWidth, page.contentHeight or Window.contentHeight
    C.page, C.width = page, width
    C.title, C.sub = Window.Header(page, width - 200)
    C.right = Style.Text(page, 12, "muted")
    C.right:SetPoint("TOPRIGHT", page, "TOPLEFT", width, -6)
    C.right:SetJustifyH("RIGHT")
    for _, spec in ipairs(TABS) do C.tabs[spec.key] = Tab(page, spec) end
    local rule = CreateFrame("Frame", nil, page)
    rule:SetSize(width, 1)
    rule:SetPoint("TOPLEFT", 0, -99)
    Style.Rule(rule, "BOTTOM", "lineStrong")
    C.foot = Style.Text(page, 12, "muted")
    C.foot:SetPoint("BOTTOMLEFT", 0, 0)
    C.foot:SetWidth(width)
    C.foot:SetWordWrap(false)
    local bodyH = height - TOP - FOOT

    -- For you: the counts, then the list.
    local foryou = BuildView(page, "foryou", width, bodyH)
    Off(foryou, width)
    foryou.body = CreateFrame("Frame", nil, foryou)
    foryou.body:SetAllPoints()
    Boxes(foryou.body, width)
    foryou.boxes = foryou.body.boxes
    foryou.list = List(foryou.body, width, bodyH - 70)
    foryou.list.scroll:SetPoint("TOPLEFT", 0, -70)

    -- Your orders: the counts, the asking card, then the list.
    local yours = BuildView(page, "yours", width, bodyH)
    Off(yours, width)
    yours.body = CreateFrame("Frame", nil, yours)
    yours.body:SetAllPoints()
    Boxes(yours.body, width)
    yours.boxes = yours.body.boxes
    yours.list = List(yours.body, width, bodyH - CARD_Y - ASK_H - 20)
    yours.list.scroll:SetPoint("TOPLEFT", 0, -(CARD_Y + ASK_H + 20))
    BuildCard(yours, width)

    -- Crafters: the search, then what it finds or everyone who shares.
    local crafters = BuildView(page, "crafters", width, bodyH)
    crafters.searchWell = CreateFrame("Frame", nil, crafters)
    crafters.searchWell:SetPoint("TOPLEFT")
    crafters.searchWell:SetSize(width, 36)
    Style.Fill(crafters.searchWell, "well")
    Style.Border(crafters.searchWell, "lineStrong")
    local search = CreateFrame("EditBox", nil, crafters.searchWell)
    search:SetAllPoints()
    search:SetTextInsets(12, 12, 0, 0)
    search:SetAutoFocus(false)
    search:SetMaxLetters(40)
    search:SetFont(Style.font, 14, "")
    search:SetTextColor(Style.Color("text"))
    search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    crafters.searchWell:EnableMouse(true)
    crafters.searchWell:SetScript("OnMouseDown", function() search:SetFocus() end)
    crafters.search = search
    crafters.hint = Style.Text(crafters.searchWell, 13, "muted")
    crafters.hint:SetPoint("LEFT", 12, 0)
    crafters.hint:SetText("Search what you need: a bag, a potion, bracers")
    crafters.back = Style.Button(crafters, "Everyone who shares", "plain", 170)
    crafters.back:SetHeight(24)
    crafters.back:SetPoint("TOPRIGHT", crafters, "TOPLEFT", width - 10, -48)
    crafters.back:SetFrameLevel((crafters:GetFrameLevel() or 1) + 10)
    crafters.back:SetScript("OnClick", function()
        C.pick = nil
        C.Paint()
    end)
    crafters.list = List(crafters, width, bodyH - 46)
    crafters.list.scroll:SetPoint("TOPLEFT", 0, -46)
    search:SetScript("OnTextChanged", function() if C.views.crafters:IsShown() then xpcall(C.Paint, ns.Report) end end)
    search:SetScript("OnEditFocusGained", function() crafters.hint:Hide() end)
    search:SetScript("OnEditFocusLost", function() crafters.hint:SetShown(search:GetText() == "") end)

    local panel = page:GetParent()
    if panel and panel.bar then C.toCompact = ModeSwitch(panel.bar, "Compact", true) end
    page.Refresh = function() C.Paint() end
end, { width = 1000, height = 920 })

---------------------------------------------------------------------------
-- The small window: the same three tabs, a line an order, one button on it.
-- It leaves out the counts, the tracks, the materials and the asking card
-- (a row's tooltip has the materials and the note; asking opens the full
-- window).
---------------------------------------------------------------------------
local SMALL_W, LINE, PERSON_LINE = 430, 46, 31

local function MakeLine(parent, width)
    local r = CreateFrame("Frame", nil, parent)
    r:SetSize(width, LINE)
    r.edge = r:CreateTexture(nil, "ARTWORK")
    r.edge:SetPoint("TOPLEFT", 0, -5)
    r.edge:SetPoint("BOTTOMLEFT", 0, 7)
    r.edge:SetWidth(2)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(28, 28)
    r.icon:SetPoint("TOPLEFT", 10, -8)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.l1 = Style.Text(r, 13, "text", nil, true)
    r.l1:SetPoint("TOPLEFT", 48, -6)
    r.l1:SetWidth(width - 48 - 96)
    r.l1:SetWordWrap(false)
    r.l2 = Style.Text(r, 11, "muted")
    r.l2:SetPoint("TOPLEFT", 48, -25)
    r.l2:SetWidth(width - 48 - 96)
    r.l2:SetWordWrap(false)
    r.main = Style.Button(r, "", "primary", 80)
    r.main:SetHeight(26)
    r.main:SetPoint("RIGHT", 0, 1)
    r.lesser = Quiet(r)
    r.lesser:SetPoint("RIGHT", -4, 1)
    Style.Rule(r, "BOTTOM", "line")
    r:EnableMouse(true)
    r:SetScript("OnEnter", ShowTip)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return r
end

-- One order in the small window. `button` = { label, fn, main }.
local function Line(list, order, state, second, button)
    local r = Take(list, "line", MakeLine, LINE)
    r.order = order
    r.edge:SetColorTexture(Style.Color(STATE[state]))
    r.icon:SetTexture(Icon(order))
    local recipe = ns.Orders.Recipe(order.spell)
    r.l1:SetText(ItemTint(recipe and recipe.item) .. (ns.Orders.Name(order) or "...") .. "|r"
        .. ((recipe and recipe.item) and ("  " .. Style.Tint("secondary") .. "×" .. (order.n or 1) .. "|r") or ""))
    r.l2:SetText(second)
    r.main:SetShown(button ~= nil and button[3] == true)
    r.lesser:SetShown(button ~= nil and button[3] ~= true)
    if button then
        local b = button[3] and r.main or r.lesser
        b:SetLabel(button[1])
        if button[3] then b:SetWidth(TextWidth(b.label, #button[1] * 7) + 28) end
        b:SetScript("OnClick", button[2])
    end
    return r
end

local function MakeSmallNote(parent, width)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width, 54)
    f.text = Style.Text(f, 12, "muted")
    f.text:SetPoint("TOPLEFT", 0, -8)
    f.text:SetWidth(width)
    return f
end

local function MakeTail(parent, width)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width, 68)
    f.mark = Mark(f, 9)
    f.mark:SetPoint("TOPLEFT", 0, -11)
    f.mark:Set("done")
    f.text = Style.Text(f, 10, "muted", nil, true)
    f.text:SetPoint("TOPLEFT", 16, -9)
    f.ask = CreateFrame("Button", nil, f)
    f.ask:SetPoint("TOPLEFT", 0, -34)
    f.ask:SetSize(width, 30)
    f.ask.edges = Style.Border(f.ask, "cardLine")
    f.ask.label = Style.Text(f.ask, 12, "gold", nil, true)
    f.ask.label:SetPoint("CENTER")
    f.ask.label:SetText("+  Ask the guild for something")
    f.ask:SetScript("OnEnter", function(self) Style.SetBorder(self.edges, "gold") end)
    f.ask:SetScript("OnLeave", function(self) Style.SetBorder(self.edges, "cardLine") end)
    f.ask:SetScript("OnClick", function() C.Show("yours", true) end)
    return f
end

-- Under a list of orders: how many are done, and the way to ask for one.
local function Tail(list, done, say)
    list.y = list.y + 2
    local f = Take(list, "tail", MakeTail, done > 0 and 68 or 44)
    f.mark:SetShown(done > 0)
    f.text:SetText(done > 0 and (Style.Tint("green") .. "DONE|r   " .. Style.Tint("text") .. done .. "|r     " .. say) or "")
    f.ask:ClearAllPoints()
    f.ask:SetPoint("TOPLEFT", 0, done > 0 and -34 or -10)
end

local function SmallHead(list, state, title, n)
    list.y = list.y + (list.y > 0 and 8 or 0)
    local h = Take(list, "head", MakeHead, 22)
    h.mark:SetShown(state ~= nil)
    if state then h.mark:Set(state) end
    h.text:ClearAllPoints()
    h.text:SetPoint("LEFT", state and 16 or 0, 0)
    h.text:SetText(Style.Tint(state and STATE[state] or "gold") .. title .. "|r   " .. Style.Tint("text") .. n .. "|r")
end

local function Mats(order, mine)
    if order.have then return Style.Tint("green") .. (mine and "you have the materials" or "has the materials") .. "|r" end
    return Style.Tint("gold") .. (mine and "you need the materials" or "needs the materials") .. "|r"
end

local SMALL_DOT = "  ·  "

local function SmallForYou(list)
    local O = ns.Orders
    local me, roster = O.ForMe(), Roster()
    O.Looked()
    local function Second(o)
        return "for " .. Who(o.by, roster) .. (o.on and (SMALL_DOT .. "on " .. ItemTint(o.on) .. (Compat.ItemName(o.on) or "an item") .. "|r") or "")
            .. SMALL_DOT .. Mats(o)
    end
    if #me.todo > 0 then
        SmallHead(list, "todo", "TO DO", #me.todo)
        for _, o in ipairs(me.todo) do
            local id = o.id
            local finish = Finish(o)
            Line(list, o, "todo", Second(o), { finish[1], finish[2], true })
        end
    end
    if #me.waiting > 0 then
        SmallHead(list, "waiting", "WAITING FOR A CRAFTER", #me.waiting)
        for _, o in ipairs(me.waiting) do
            local id = o.id
            Line(list, o, "waiting", Second(o), { "Accept", function() Do(O.Accept, id) end, true })
        end
    end
    if #me.sent > 0 then
        SmallHead(list, "sent", "SENT", #me.sent)
        for _, o in ipairs(me.sent) do Line(list, o, "sent", "to " .. Who(o.by, roster) .. SMALL_DOT .. SentWhen(o)) end
    end
    if #me.todo + #me.waiting + #me.sent == 0 then
        Take(list, "note", MakeSmallNote, 54).text:SetText("No orders for you right now. When a guildmate orders something you can make, it shows here.")
    end
    Tail(list, #me.done, "made by you, lately")
end

local function SmallYours(list)
    local O = ns.Orders
    local mine, roster = O.Mine(), Roster()
    if #mine.waiting > 0 then
        SmallHead(list, "waiting", "WAITING FOR A CRAFTER", #mine.waiting)
        for _, o in ipairs(mine.waiting) do
            local recipe = O.Recipe(o.spell)
            local people = ns.Crafters and ns.Crafters.ForItem and ns.Crafters.ForItem(recipe.item or -o.spell) or {}
            local maker = people[1] and people[1].online and people[1].name or nil
            local id = o.id
            Line(list, o, "waiting", maker and (Who(maker, roster) .. " makes this, online") or "nobody has accepted it yet",
                { "Cancel", function() Do(O.Cancel, id) end })
        end
    end
    if #mine.making > 0 then
        SmallHead(list, "making", "BEING MADE", #mine.making)
        for _, o in ipairs(mine.making) do
            local id = o.id
            Line(list, o, "making", Who(o.c, roster) .. " is making it", { "Mark received", function() Do(O.GotIt, id) end, true })
        end
    end
    if #mine.sent > 0 then
        SmallHead(list, "got", "SENT TO YOU", #mine.sent)
        for _, o in ipairs(mine.sent) do
            local id = o.id
            Line(list, o, "got", "from " .. Who(o.c, roster) .. SMALL_DOT .. SentWhen(o), { "Mark received", function() Do(O.GotIt, id) end, true })
        end
    end
    if #mine.unconfirmed > 0 then
        SmallHead(list, "unconfirmed", "NOT CONFIRMED", #mine.unconfirmed)
        for _, o in ipairs(mine.unconfirmed) do
            local id = o.id
            Line(list, o, "unconfirmed", "from " .. Who(o.c, roster) .. SMALL_DOT .. SentWhen(o), { "Mark received", function() Do(O.GotIt, id) end })
        end
    end
    if #mine.waiting + #mine.making + #mine.sent + #mine.unconfirmed == 0 then
        Take(list, "note", MakeSmallNote, 54).text:SetText("You have no open orders.")
    end
    Tail(list, #mine.done, "received lately")
end

local function MakeSmallFound(parent, width)
    local r = CreateFrame("Frame", nil, parent)
    r:SetSize(width, LINE)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(28, 28)
    r.icon:SetPoint("TOPLEFT", 0, -8)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.name = Style.Text(r, 13, "text", nil, true)
    r.name:SetPoint("TOPLEFT", 38, -6)
    r.name:SetWidth(width - 38 - 80)
    r.name:SetWordWrap(false)
    r.who = Style.Text(r, 11, "muted")
    r.who:SetPoint("TOPLEFT", 38, -25)
    r.who:SetWidth(width - 38 - 80)
    r.who:SetWordWrap(false)
    r.order = Style.Button(r, "Order", "primary", 68)
    r.order:SetHeight(26)
    r.order:SetPoint("RIGHT", 0, 1)
    Style.Rule(r, "BOTTOM", "line")
    return r
end

local function MakePersonLine(parent, width)
    local r = CreateFrame("Frame", nil, parent)
    r:SetSize(width, PERSON_LINE)
    r.dot = r:CreateTexture(nil, "ARTWORK")
    r.dot:SetSize(6, 6)
    r.dot:SetPoint("LEFT", 2, 0)
    r.name = Style.Text(r, 12, "text", nil, true)
    r.name:SetPoint("LEFT", 16, 0)
    r.name:SetJustifyV("MIDDLE")
    r.profs = Style.Text(r, 11, "muted")
    r.profs:SetPoint("RIGHT", 0, 0)
    r.profs:SetJustifyH("RIGHT")
    r.profs:SetWidth(width - 140)
    r.profs:SetWordWrap(false)
    Style.Rule(r, "BOTTOM", "line")
    return r
end

local function SmallCrafters(list)
    local Crafters, small = ns.Crafters, C.small
    local text = small.search:GetText()
    local typed = strtrim(text) ~= ""
    small.hint:SetShown(text == "" and not small.search:HasFocus())
    local roster = Roster()
    if Crafters.Count() == 0 then
        Take(list, "note", MakeSmallNote, 54).text:SetText("No recipes heard yet. Guildmates with jsal.ui share theirs once they've opened their profession windows.")
    elseif typed then
        local found = Crafters.Search(text, 30)
        if #found == 0 then Take(list, "note", MakeSmallNote, 54).text:SetText("No guildmate makes anything by that name yet.") end
        for _, entry in ipairs(found) do
            local r = Take(list, "found", MakeSmallFound, LINE)
            r.icon:SetTexture((entry.row.item and Compat.ItemIcon(entry.row.item)) or select(2, Compat.SpellInfo(entry.row.spell)))
            r.name:SetText(ItemTint(entry.row.item) .. entry.name .. "|r")
            local first = entry.people[1]
            r.who:SetText(Who(first.name, roster) .. (#entry.people > 1 and (" and %d more"):format(#entry.people - 1) or "")
                .. SMALL_DOT .. (first.online and "online" or Crafters.Ago(first.seen)))
            local spell = entry.row.spell
            r.order:SetScript("OnClick", function()
                C.Show("yours", true)
                C.Ask(spell)
            end)
        end
    else
        local people = Crafters.Sharing()
        SmallHead(list, nil, "EVERYONE WHO SHARES", #people)
        for _, p in ipairs(people) do
            local r = Take(list, "person", MakePersonLine, PERSON_LINE)
            r.dot:SetColorTexture(Style.Color(p.online and "green" or "lineStrong"))
            r.name:SetText(p.online and Who(p.name, roster) or (Style.Tint("muted") .. p.name .. "|r"))
            local words = {}
            for _, prof in ipairs(p.profs) do words[#words + 1] = ("%s %d%s"):format(prof.name, prof.skill, prof.steps and "+" or "") end
            r.profs:SetText(table.concat(words, SMALL_DOT))
        end
    end
end

local SMALL = { foryou = SmallForYou, yours = SmallYours, crafters = SmallCrafters }
local SHORT = { foryou = "For you", yours = "Your orders", crafters = "Crafters" }

function C.PaintSmall()
    local small = C.small
    if not small then return end
    local tab = CurrentTab()
    -- The tabs, with their numbers.
    local O = OrdersOn() and ns.Orders or nil
    local todo = O and O.Badge() or 0
    local mine = O and O.Mine() or nil
    local function Some(n) return n and n > 0 and n or nil end
    local counts = { foryou = Some(O and todo), yours = Some(mine and (#mine.waiting + #mine.making)),
                     crafters = Some(CraftersOn() and ns.Crafters.Count()) }
    local x = 0
    for _, spec in ipairs(TABS) do
        local b = small.tabs[spec.key]
        b:Set(spec.key == tab, counts[spec.key], spec.key == "foryou" and todo > 0)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", x, 0)
        x = x + b:GetWidth() + 2
    end
    local list = small.list
    Reset(list)
    local searching = tab == "crafters" and CraftersOn()
    small.searchWell:SetShown(searching)
    list.scroll:ClearAllPoints()
    list.scroll:SetPoint("TOPLEFT", 0, searching and -74 or -40)
    if tab == "crafters" then
        if CraftersOn() then
            SmallCrafters(list)
        else
            Take(list, "note", MakeSmallNote, 54).text:SetText("Guild crafters is off. Turn it on in Settings, under Professions.")
        end
    elseif O then
        SMALL[tab](list)
    else
        Take(list, "note", MakeSmallNote, 54).text:SetText("Guild orders are off. Turn them on in Settings, under Professions, to ask the guild for a craft here.")
    end
    Close(list)
    -- As tall as what's in it, within reason.
    local body = math.max(60, math.min(520, list.y + 6))
    list.scroll:SetHeight(body)
    small:SetHeight(32 + 10 + (searching and 74 or 40) + body + 10)
end

local function BuildSmall()
    local f = Style.Panel("jsalUIGuildCraftsSmall", SMALL_W, 400, "Guild Crafts")
    C.small = f
    -- Hung by its top left corner, so it grows and shrinks downwards as its list does, and
    -- the title bar stays where it was put. (A dragged window is left hung by whichever
    -- point the game picks: it's hung again by its corner once the drag ends.)
    local saved = View().at
    local left = type(saved) == "table" and tonumber(saved.left) or (UIParent:GetWidth() / 2 - SMALL_W / 2)
    local top = type(saved) == "table" and tonumber(saved.top) or (UIParent:GetHeight() / 2 + 220)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    f.bar:HookScript("OnDragStop", function()
        local x, y = f:GetLeft(), f:GetTop()
        if not (x and y) then return end
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
        View().at = { left = x, top = y }
    end)
    f.toFull = ModeSwitch(f.bar, "Full size", false)
    local inner = CreateFrame("Frame", nil, f)
    inner:SetPoint("TOPLEFT", 14, -42)
    inner:SetPoint("BOTTOMRIGHT", -14, 10)
    local width = SMALL_W - 28
    f.tabs = {}
    for _, spec in ipairs(TABS) do
        local b = CreateFrame("Button", nil, inner)
        b:SetHeight(28)
        b.label = Style.Text(b, 12, "secondary", nil, true)
        b.label:SetPoint("LEFT", 8, 0)
        b.label:SetJustifyV("MIDDLE")
        b.label:SetText(SHORT[spec.key])
        b.badge = CreateFrame("Frame", nil, b)
        b.badge:SetHeight(16)
        b.badge:SetPoint("LEFT", b.label, "RIGHT", 6, 0)
        b.fill = Style.Fill(b.badge, "well")
        b.edges = Style.Border(b.badge, "cardLine")
        b.count = Style.Text(b.badge, 10, "muted", nil, true)
        b.count:SetPoint("CENTER")
        b.under = b:CreateTexture(nil, "ARTWORK")
        b.under:SetColorTexture(Style.Color("gold"))
        b.under:SetPoint("BOTTOMLEFT")
        b.under:SetPoint("BOTTOMRIGHT")
        b.under:SetHeight(2)
        local key = spec.key
        function b:Set(selected, n, hot)
            self.label:SetTextColor(Style.Color(selected and "text" or "secondary"))
            self.under:SetShown(selected)
            self.badge:SetShown(n ~= nil)
            local w = TextWidth(self.label, #SHORT[key] * 7) + 16
            if n then
                self.count:SetText(n)
                self.count:SetTextColor(Style.Color(hot and "onGold" or "muted"))
                self.fill:SetColorTexture(Style.Color(hot and "gold" or "well"))
                Style.SetBorder(self.edges, hot and "gold" or "cardLine")
                local bw = math.max(16, TextWidth(self.count, 7) + 10)
                self.badge:SetWidth(bw)
                w = w + 6 + bw
            end
            self:SetWidth(w)
        end
        b:SetScript("OnClick", function()
            View().tab = key
            C.PaintSmall()
        end)
        f.tabs[key] = b
    end
    local rule = CreateFrame("Frame", nil, inner)
    rule:SetSize(width, 1)
    rule:SetPoint("TOPLEFT", 0, -27)
    Style.Rule(rule, "BOTTOM", "lineStrong")
    -- The Crafters tab's search.
    f.searchWell = CreateFrame("Frame", nil, inner)
    f.searchWell:SetPoint("TOPLEFT", 0, -38)
    f.searchWell:SetSize(width, 30)
    Style.Fill(f.searchWell, "well")
    Style.Border(f.searchWell, "lineStrong")
    local search = CreateFrame("EditBox", nil, f.searchWell)
    search:SetAllPoints()
    search:SetTextInsets(10, 10, 0, 0)
    search:SetAutoFocus(false)
    search:SetMaxLetters(40)
    search:SetFont(Style.font, 13, "")
    search:SetTextColor(Style.Color("text"))
    search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    f.searchWell:EnableMouse(true)
    f.searchWell:SetScript("OnMouseDown", function() search:SetFocus() end)
    f.search = search
    f.hint = Style.Text(f.searchWell, 12, "muted")
    f.hint:SetPoint("LEFT", 10, 0)
    f.hint:SetText("Search what you need")
    search:SetScript("OnTextChanged", function() xpcall(C.PaintSmall, ns.Report) end)
    search:SetScript("OnEditFocusGained", function() f.hint:Hide() end)
    search:SetScript("OnEditFocusLost", function() f.hint:SetShown(search:GetText() == "") end)
    f.list = List(inner, width, 300)
    f.list.scroll:SetPoint("TOPLEFT", 0, -40)
end

function C.OpenSmall()
    if not C.small then BuildSmall() end
    C.PaintSmall()
    C.small:Show()
    C.small:Raise()
end

-- An order changed: the small window isn't one of the dashboard's pages, so
-- it's told here.
if ns.Orders then
    ns.Orders.OnChange = function()
        if C.small and C.small:IsShown() then xpcall(C.PaintSmall, ns.Report) end
    end
end

local function Slash()
    local on = OrdersOn() or CraftersOn()
    if not on then
        return ns.Print("Guild Crafts is off. Turn on Guild crafters or Guild orders in Settings, under Professions, then reload.")
    end
    C.Toggle()
end

-- Opens it, in the size it was left in; open already, closes it.
function C.Toggle()
    if C.small and C.small:IsShown() then return C.small:Hide() end
    if Window.IsOpen("guildcrafts") then return Window.Close("guildcrafts") end
    C.Show()
end
ns.Command("crafts", Slash)
ns.Command("orders", Slash)
