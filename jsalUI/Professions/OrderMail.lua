-- Guild orders to mail. At a mailbox, a card under the mail window lists the
-- orders you accepted whose item is in your bags. Fill in writes whoever
-- asked into the letter's To box and the order into its Subject; the item is
-- dragged in and the letter sent by hand. When the game says a letter went to
-- them with the item in it, the order is sent (Orders.Mailed) and they're
-- told. Sent marks one sent by hand, for an item handed over in a trade.
--
-- The card is a child of UIParent, placed from the mail window's edges and
-- never anchored to it. Fill in only sets the text of the To and Subject
-- boxes, and nothing of this runs inside the game's mail code: SendMail is
-- watched by a post-hook, which only notes who the letter is to and what's in it.
local _, ns = ...
local Style, Compat, Orders = ns.Style, ns.Compat, ns.Orders

local M = {}
ns.OrderMail = M

local HEAD, ROW, FOOT, GAP, MIN_W = 34, 34, 30, 30, 300
local MAX_ROWS = 6

-- The orders to mail: accepted by you, for an item, with some of it in your bags.
function M.ToMail()
    local out = {}
    if not Orders.running then return out end
    for _, o in ipairs(Orders.ForMe().todo) do
        local recipe = Orders.Recipe(o.spell)
        if recipe and recipe.item and Compat.ItemCount(recipe.item) > 0 then out[#out + 1] = o end
    end
    return out
end

local card

-- Words that act, lighting up under the pointer.
local function Quiet(parent, label, colour)
    local b = CreateFrame("Button", nil, parent)
    b.colour = colour
    b.label = Style.Text(b, 13, colour, nil, true)
    b.label:SetPoint("RIGHT")
    b.label:SetText(label)
    b:SetSize(math.max(30, (b.label:GetStringWidth() or 40) + 4), 22)
    b:SetScript("OnEnter", function(self)
        if self.why then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(self.why, 0.6, 0.59, 0.53, true)
            GameTooltip:Show()
        else
            self.label:SetTextColor(Style.Color("text"))
        end
    end)
    b:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
        self.label:SetTextColor(Style.Color(self.why and "muted" or self.colour))
    end)
    return b
end

local function MakeRow(parent)
    local r = CreateFrame("Frame", nil, parent)
    r:SetHeight(ROW)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(24, 24)
    r.icon:SetPoint("LEFT", 0, 0)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.name = Style.Text(r, 13, "text")
    r.name:SetPoint("TOPLEFT", 32, -3)
    r.name:SetWordWrap(false)
    r.who = Style.Text(r, 11, "muted")
    r.who:SetPoint("TOPLEFT", 32, -19)
    r.who:SetWordWrap(false)
    r.fill = Quiet(r, "Fill in", "gold")
    r.fill:SetPoint("RIGHT", 0, 0)
    r.sent = Quiet(r, "Sent", "muted")
    r.sent:SetPoint("RIGHT", r.fill, "LEFT", -14, 0)
    r.rule = Style.Rule(r, "BOTTOM", "line")
    return r
end

local function Build()
    card = CreateFrame("Frame", nil, UIParent)
    M.card = card
    card:SetFrameStrata("HIGH")
    card:SetSize(MIN_W, HEAD + FOOT)
    card:Hide()
    Style.Shadow(card)
    Style.Fill(card, "window")
    Style.Border(card, "lineStrong")
    local edge = card:CreateTexture(nil, "ARTWORK")
    edge:SetPoint("TOPLEFT")
    edge:SetPoint("BOTTOMLEFT")
    edge:SetWidth(3)
    edge:SetColorTexture(Style.Color("gold"))
    card.title = Style.Text(card, 11, "gold", nil, true)
    card.title:SetPoint("TOPLEFT", 14, -11)
    card.title:SetText("GUILD ORDERS TO MAIL")
    card.count = Style.Text(card, 11, "gold", nil, true)
    card.count:SetPoint("TOPRIGHT", -12, -11)
    local rule = card:CreateTexture(nil, "ARTWORK")
    rule:SetColorTexture(Style.Color("line"))
    rule:SetPoint("TOPLEFT", 12, -29)
    rule:SetPoint("TOPRIGHT", -12, -29)
    rule:SetHeight(Compat.OnePixel(card))
    card.foot = Style.Text(card, 11, "muted")
    card.foot:SetPoint("BOTTOMLEFT", 14, 10)
    card.foot:SetText("Fill in writes the name and subject. Drag the item in.")
    card.rows = {}
    -- While it shows: keep it under the mail window, and Fill in only on the Send Mail page.
    local wait = 0
    card:SetScript("OnUpdate", ns.Safe(Orders, function(_, elapsed)
        wait = wait - elapsed
        if wait > 0 then return end
        wait = 0.25
        M.Place()
        M.FillState()
    end))
end

-- Under the mail window, as wide as it; at its right when there's no room under it.
function M.Place()
    local mf = MailFrame
    if not (card and mf) then return end
    local left, bottom, top, width = Compat.Plain(mf:GetLeft()), Compat.Plain(mf:GetBottom()), Compat.Plain(mf:GetTop()), Compat.Plain(mf:GetWidth())
    if not (left and bottom and top and width) then return end
    local s = mf:GetEffectiveScale() / card:GetEffectiveScale()
    card:SetWidth(math.max(MIN_W, width * s))
    card:ClearAllPoints()
    local under = bottom * s - GAP
    if under - card:GetHeight() >= 0 then
        card:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left * s, under)
    else
        card:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", (left + width) * s + 6, top * s)
    end
end

-- Fill in can only write into the Send Mail page's boxes while it's open.
function M.FillState()
    if not card then return end
    local open = SendMailFrame and SendMailFrame:IsShown() and true or false
    for _, r in ipairs(card.rows) do
        r.fill.why = not open and "Open the Send Mail page to fill in a letter." or nil
        r.fill.label:SetTextColor(Style.Color(open and "gold" or "muted"))
    end
end

local function Label(order)
    local name = Orders.Name(order) or "your order"
    return (order.n or 1) > 1 and ("%d %s"):format(order.n, name) or name
end

-- Writes whoever asked and the order into the letter.
function M.Fill(order)
    if not (SendMailFrame and SendMailFrame:IsShown() and SendMailNameEditBox and SendMailSubjectEditBox) then return false end
    SendMailNameEditBox:SetText(order.by)
    SendMailSubjectEditBox:SetText("Guild order: " .. Label(order))
    return true
end

function M.Paint()
    if not M.open then return end
    local list = M.ToMail()
    if #list == 0 then
        if card then card:Hide() end
        return
    end
    if not card then Build() end
    local shown = math.min(#list, MAX_ROWS)
    card.count:SetText(#list)
    card:SetHeight(HEAD + shown * ROW + FOOT)
    local C = ns.GuildCrafts
    for i = 1, shown do
        local r = card.rows[i]
        if not r then
            r = MakeRow(card)
            card.rows[i] = r
        end
        local o = list[i]
        local recipe = Orders.Recipe(o.spell)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 14, -(HEAD + (i - 1) * ROW))
        r:SetPoint("TOPRIGHT", -14, -(HEAD + (i - 1) * ROW))
        r.icon:SetTexture(Compat.ItemIcon(recipe.item))
        r.name:SetText(C and C.Title and C.Title(o) or Label(o))
        r.who:SetText("for " .. (C and C.Who and C.Who(o.by) or o.by))
        local room = (card:GetWidth() or MIN_W) - 28 - 32 - r.fill:GetWidth() - r.sent:GetWidth() - 24
        r.name:SetWidth(room)
        r.who:SetWidth(room)
        r.fill:SetScript("OnClick", function() M.Fill(o) end)
        r.sent:SetScript("OnClick", function()
            local ok, why = Orders.Sent(o.id)
            if not ok and why then ns.Print(why) end
            M.Paint()
        end)
        r.rule:SetShown(i < shown)
        r:Show()
    end
    for i = shown + 1, #card.rows do card.rows[i]:Hide() end
    card.foot:SetText(#list > shown and ("And %d more in Guild Crafts. "):format(#list - shown) .. "Fill in writes the name and subject."
        or "Fill in writes the name and subject. Drag the item in.")
    M.Place()
    M.FillState()
    card:Show()
end

-- What's in the letter being sent: how many of each item.
local function Attached()
    local items = {}
    for i = 1, ATTACHMENTS_MAX_SEND or 12 do
        local _, item, _, count = GetSendMailItem(i)
        item = Compat.Plain(item)
        if item then items[item] = (items[item] or 0) + (Compat.Plain(count) or 1) end
    end
    return items
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", ns.Safe(Orders, function(_, event)
    if event == "MAIL_SHOW" then
        M.open = true
        M.Paint()
    elseif event == "MAIL_CLOSED" then
        M.open = false
        Orders.Mailing(nil)
        if card then card:Hide() end
    elseif event == "MAIL_SEND_SUCCESS" then
        Orders.Mailed()
        M.Paint()
    elseif event == "MAIL_FAILED" then
        Orders.Mailing(nil)
    elseif event == "BAG_UPDATE_DELAYED" then
        M.Paint()
    end
end))

local hooked = false
function M.Start()
    for _, event in ipairs({ "MAIL_SHOW", "MAIL_CLOSED", "MAIL_SEND_SUCCESS", "MAIL_FAILED", "BAG_UPDATE_DELAYED" }) do
        events:RegisterEvent(event)
    end
    if not hooked then
        hooked = true
        hooksecurefunc("SendMail", ns.Safe(Orders, function(to)
            if Orders.running then Orders.Mailing(Compat.Plain(to), Attached()) end
        end))
    end
end

function M.Stop()
    events:UnregisterAllEvents()
    Orders.Mailing(nil)
    M.open = false
    if card then card:Hide() end
end

-- An order changed (accepted, sent, cancelled): the card is told, after the
-- Guild Crafts window.
local was = Orders.OnChange
Orders.OnChange = function()
    if was then was() end
    if M.open then xpcall(M.Paint, ns.Report) end
end
