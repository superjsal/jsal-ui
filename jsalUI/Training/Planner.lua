-- The Training Planner page. On the left, what you can train now: a card for
-- each spell with its price and a Skip button, and the visit's total against
-- your gold. On the right, the road to 60: a stop for each trainer visit to
-- come, its spells and its cost, then the weapon skills.
local _, ns = ...
local Style, Compat, Window, Training = ns.Style, ns.Compat, ns.Window, ns.Training

local CART_W, GAP = 300, 20
local CARD_H, CARD_GAP = 58, 8
local CHIP_H, CHIP_GAP = 28, 6
local LEVEL_W, NODE_W, COST_W = 34, 16, 64

-- Spells at an odd level are trained on the next even one, so each stop is
-- level 1 or an even level.
local function Stop(level)
    if level <= 1 then return 1 end
    return level + level % 2
end

local function Price(spell)
    return spell.cost and Compat.Money(spell.cost) or nil
end

-- The section heading used on the right: a title, a note, and a rule.
local function Section(parent, width)
    local s = CreateFrame("Frame", nil, parent)
    s:SetSize(width, 20)
    s.title = Style.Text(s, 11, "gold", nil, true)
    s.title:SetPoint("LEFT")
    s.note = Style.Text(s, 11, "muted")
    s.note:SetPoint("RIGHT")
    s.note:SetJustifyH("RIGHT")
    Style.Rule(s, "BOTTOM", "line")
    return s
end

local function Tooltip(frame)
    frame:SetScript("OnEnter", function(self)
        if not self.spellID then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetSpellByID(self.spellID)
        if self.hint then GameTooltip:AddLine(self.hint, 0.6, 0.59, 0.53) end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- A list that scrolls with the mouse wheel, with a thin bar showing where.
local function Scroller(parent, width, height)
    local scroll = CreateFrame("ScrollFrame", nil, parent)
    scroll:SetSize(width, height)
    local list = CreateFrame("Frame", nil, scroll)
    list:SetSize(width, 1)
    scroll:SetScrollChild(list)
    local thumb = parent:CreateTexture(nil, "ARTWORK")
    thumb:SetColorTexture(Style.Color("lineStrong"))
    thumb:SetWidth(3)
    function scroll:Place()
        local range, h = self:GetVerticalScrollRange(), self:GetHeight()
        thumb:SetShown(range > 0)
        if range <= 0 then return end
        local size = math.max(24, h * h / (h + range))
        thumb:SetHeight(size)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOPRIGHT", self, "TOPRIGHT", 6, -(h - size) * self:GetVerticalScroll() / range)
    end
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local target = self:GetVerticalScroll() - delta * 60
        self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), target)))
        self:Place()
    end)
    return scroll, list
end

Window.Page("training", function(page)
    local width, height = Window.contentWidth, Window.contentHeight
    local roadW = width - CART_W - GAP
    local top = 34
    local Paint

    ---------------------------------------------------------------------------
    -- Left: ready now.
    ---------------------------------------------------------------------------
    local cart = CreateFrame("Frame", nil, page)
    cart:SetPoint("TOPLEFT", 0, -top)
    cart:SetSize(CART_W, height - top)
    Style.Fill(cart, "titleBar")
    Style.Border(cart, "line")
    local cartTitle = Style.Text(cart, 15, "text", nil, true)
    cartTitle:SetPoint("TOPLEFT", 12, -12)
    cartTitle:SetText("Ready now")
    local cartSub = Style.Text(cart, 11, "muted")
    cartSub:SetPoint("TOPRIGHT", -12, -15)
    cartSub:SetJustifyH("RIGHT")

    local TOTALS_H = 118
    local cardScroll, cardList = Scroller(cart, CART_W - 24, height - top - 44 - TOTALS_H - 12)
    cardScroll:SetPoint("TOPLEFT", 12, -40)
    local empty = Style.Text(cardList, 13, "muted")
    empty:SetPoint("TOPLEFT", 0, -4)
    empty:SetWidth(CART_W - 24)

    local totals = CreateFrame("Frame", nil, cart)
    totals:SetPoint("BOTTOMLEFT", 12, 12)
    totals:SetPoint("BOTTOMRIGHT", -12, 12)
    totals:SetHeight(TOTALS_H)
    Style.Rule(totals, "TOP", "line")
    local visitLabel = Style.Text(totals, 12, "muted")
    visitLabel:SetPoint("TOPLEFT", 0, -12)
    visitLabel:SetText("This visit")
    local visitCost = Style.Text(totals, 15, "gold", nil, true)
    visitCost:SetPoint("TOPRIGHT", 0, -10)
    visitCost:SetJustifyH("RIGHT")
    local track = CreateFrame("Frame", nil, totals)
    track:SetPoint("TOPLEFT", 0, -36)
    track:SetPoint("TOPRIGHT", 0, -36)
    track:SetHeight(6)
    Style.Fill(track, "line")
    local fill = track:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT")
    fill:SetPoint("BOTTOMLEFT")
    fill:SetColorTexture(Style.Color("gold"))
    local haveText = Style.Text(totals, 12, "muted")
    haveText:SetPoint("TOPLEFT", 0, -52)
    local spareText = Style.Text(totals, 12, "text")
    spareText:SetPoint("TOPRIGHT", 0, -52)
    spareText:SetJustifyH("RIGHT")
    local restLabel = Style.Text(totals, 12, "muted")
    restLabel:SetPoint("TOPLEFT", 0, -74)
    restLabel:SetText("Left to 60")
    local restText = Style.Text(totals, 12, "text")
    restText:SetPoint("TOPRIGHT", 0, -74)
    restText:SetJustifyH("RIGHT")
    local priceNote = Style.Text(totals, 11, "muted")
    priceNote:SetPoint("TOPLEFT", 0, -96)
    priceNote:SetWidth(CART_W - 24)

    local cards = {}
    local function Card(i)
        local c = CreateFrame("Frame", nil, cardList)
        c:SetSize(CART_W - 24, CARD_H)
        c:SetPoint("TOPLEFT", 0, -(i - 1) * (CARD_H + CARD_GAP))
        Style.Fill(c, "well")
        Style.Border(c, "line")
        c.icon = c:CreateTexture(nil, "ARTWORK")
        c.icon:SetSize(34, 34)
        c.icon:SetPoint("LEFT", 10, 0)
        c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        c.name = Style.Text(c, 13, "text", nil, true)
        c.name:SetPoint("TOPLEFT", c.icon, "TOPRIGHT", 10, -1)
        c.name:SetWidth(CART_W - 24 - 54 - 70)
        c.name:SetWordWrap(false)
        c.sub = Style.Text(c, 11, "muted")
        c.sub:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -4)
        c.cost = Style.Text(c, 13, "text", nil, true)
        c.cost:SetPoint("TOPRIGHT", -10, -10)
        c.cost:SetJustifyH("RIGHT")
        c.skip = Style.Button(c, "Skip", "plain", 52)
        c.skip:SetHeight(20)
        c.skip:SetPoint("BOTTOMRIGHT", -8, 8)
        c:EnableMouse(true)
        Tooltip(c)
        return c
    end

    ---------------------------------------------------------------------------
    -- Right: the road to 60.
    ---------------------------------------------------------------------------
    local roadHead = Section(page, roadW)
    roadHead:SetPoint("TOPLEFT", CART_W + GAP, -top)
    roadHead.title:SetText("YOUR ROAD TO 60")
    roadHead.note:SetText("Each stop is a trainer visit · right-click a spell to skip it")
    local roadScroll, road = Scroller(page, roadW - 8, height - top - 30)
    roadScroll:SetPoint("TOPLEFT", CART_W + GAP, -(top + 30))

    local stops, chips, heads, weaponRows = {}, {}, {}, {}
    local used

    local function Take(pool, make)
        used[pool] = (used[pool] or 0) + 1
        local list = ({ stops = stops, chips = chips, heads = heads, weapons = weaponRows })[pool]
        local item = list[used[pool]]
        if not item then
            item = make()
            list[used[pool]] = item
        end
        item:Show()
        return item
    end

    local function MakeStop()
        local s = CreateFrame("Frame", nil, road)
        s.level = Style.Text(s, 13, "muted", nil, true)
        s.level:SetPoint("TOPRIGHT", s, "TOPLEFT", LEVEL_W, -6)
        s.level:SetJustifyH("RIGHT")
        s.line = s:CreateTexture(nil, "BORDER")
        s.line:SetColorTexture(Style.Color("line"))
        s.line:SetWidth(2)
        s.line:SetPoint("TOP", s, "TOPLEFT", LEVEL_W + NODE_W / 2, 0)
        s.line:SetPoint("BOTTOM", s, "BOTTOMLEFT", LEVEL_W + NODE_W / 2, 0)
        s.node = CreateFrame("Frame", nil, s)
        s.node:SetSize(10, 10)
        s.node:SetPoint("CENTER", s, "TOPLEFT", LEVEL_W + NODE_W / 2, -14)
        s.node.fill = Style.Fill(s.node, "window")
        s.node.edges = Style.Border(s.node, "lineStrong")
        s.cost = Style.Text(s, 13, "text", nil, true)
        s.cost:SetPoint("TOPRIGHT", 0, -6)
        s.cost:SetJustifyH("RIGHT")
        return s
    end

    local function MakeChip()
        local c = CreateFrame("Button", nil, road)
        c:SetHeight(CHIP_H)
        c:RegisterForClicks("RightButtonUp")
        c.bg = Style.Fill(c, "well")
        c.edges = Style.Border(c, "line")
        c.icon = c:CreateTexture(nil, "ARTWORK")
        c.icon:SetSize(22, 22)
        c.icon:SetPoint("LEFT", 3, 0)
        c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        c.name = Style.Text(c, 12, "text")
        c.name:SetPoint("LEFT", c.icon, "RIGHT", 6, 0)
        c.rank = Style.Text(c, 11, "muted")
        c.rank:SetPoint("LEFT", c.name, "RIGHT", 4, 0)
        Tooltip(c)
        c:SetScript("OnClick", function(self)
            if self.spell then
                Training.Skip(self.spell.id, not self.spell.skipped)
                Paint()
            end
        end)
        return c
    end

    local function MakeHead()
        return Section(road, roadW - 8)
    end

    local function MakeWeapon()
        local r = CreateFrame("Frame", nil, road)
        r:SetSize(roadW - 8, 26)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(20, 20)
        r.icon:SetPoint("LEFT", 2, 0)
        r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.name = Style.Text(r, 12, "text")
        r.name:SetPoint("LEFT", r.icon, "RIGHT", 8, 0)
        r.state = Style.Text(r, 12, "text", nil, true)
        r.state:SetPoint("RIGHT", -4, 0)
        r.state:SetJustifyH("RIGHT")
        r.where = Style.Text(r, 11, "muted")
        r.where:SetPoint("RIGHT", -COST_W - 12, 0)
        r.where:SetJustifyH("RIGHT")
        r:EnableMouse(true)
        Tooltip(r)
        return r
    end

    -- The short rank number on a chip ("Serpent Sting 3").
    local function RankNumber(rank)
        return rank and rank:match("(%d+)") or ""
    end

    local function Chips(spells, x0, y0, maxW)
        local x, y = 0, 0
        for _, spell in ipairs(spells) do
            local c = Take("chips", MakeChip)
            c.spell, c.spellID = spell, spell.id
            c.hint = spell.skipped and "Skipped: right-click to put it back" or "Right-click to skip it"
            c.icon:SetTexture(spell.icon)
            c.name:SetText(spell.name)
            c.rank:SetText(RankNumber(spell.rank))
            local w = 3 + 22 + 6 + c.name:GetStringWidth() + 4 + c.rank:GetStringWidth() + 8
            if x > 0 and x + w > maxW then
                x, y = 0, y + CHIP_H + CHIP_GAP
            end
            c:SetWidth(w)
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", x0 + x, -(y0 + y))
            c:SetAlpha(spell.skipped and 0.4 or 1)
            x = x + w + CHIP_GAP
        end
        return y + CHIP_H
    end

    Paint = function()
        local data = Training.Read()
        if not data then
            cartSub:SetText("")
            empty:SetText("There's no spell list for this class yet.")
            empty:Show()
            return
        end
        local level = UnitLevel("player")
        local money = GetMoney()

        -- Sort: ready now (not known, level reached), and the stops ahead.
        local now, ahead, cost, unknown, rest = {}, {}, 0, 0, 0
        for _, spell in ipairs(data.spells) do
            if not spell.known then
                if spell.level <= level then
                    now[#now + 1] = spell
                    if not spell.skipped then
                        if spell.cost then cost = cost + spell.cost else unknown = unknown + 1 end
                    end
                else
                    local stop = Stop(spell.level)
                    ahead[stop] = ahead[stop] or {}
                    table.insert(ahead[stop], spell)
                end
                if not spell.skipped and spell.cost then rest = rest + spell.cost end
            end
        end

        -- Ready now.
        local count = 0
        for _, spell in ipairs(now) do if not spell.skipped then count = count + 1 end end
        cartSub:SetText(("Level %d · %d spell%s"):format(level, count, count == 1 and "" or "s"))
        for i, spell in ipairs(now) do
            local c = cards[i] or Card(i)
            cards[i] = c
            c.spellID = spell.id
            c.icon:SetTexture(spell.icon)
            c.name:SetText(spell.name)
            c.sub:SetText(spell.skipped and "Skipped" or (spell.rank or ("Level " .. spell.level)))
            c.cost:SetText(Price(spell) or "|cff9a9688?|r")
            c.skip:SetLabel(spell.skipped and "Unskip" or "Skip")
            c.skip:SetScript("OnClick", function()
                Training.Skip(spell.id, not spell.skipped)
                Paint()
            end)
            c:SetAlpha(spell.skipped and 0.5 or 1)
            c:Show()
        end
        for i = #now + 1, #cards do cards[i]:Hide() end
        empty:SetShown(#now == 0)
        empty:SetText("Nothing to train right now. The road on the right shows what's next.")
        cardList:SetHeight(math.max(1, #now * (CARD_H + CARD_GAP)))
        cardScroll:UpdateScrollChildRect()
        cardScroll:Place()

        -- The visit's total against your gold.
        visitCost:SetText(cost > 0 and Compat.Money(cost) or (unknown > 0 and "?" or "Nothing"))
        fill:SetWidth(math.max(1, track:GetWidth() * (cost > 0 and math.min(1, money / cost) or 1)))
        haveText:SetText("You have " .. Compat.Money(money))
        if cost == 0 then
            spareText:SetText("")
        elseif money >= cost then
            spareText:SetText(Compat.Money(money - cost) .. " to spare")
        else
            spareText:SetText("|cffe3b04b" .. Compat.Money(cost - money) .. " short|r")
        end
        restText:SetText(rest > 0 and Compat.Money(rest) or "?")
        priceNote:SetText(data.haveTrainer
            and (unknown > 0 and ("%d price%s not seen at a trainer yet."):format(unknown, unknown == 1 and "" or "s") or "")
            or "Prices fill in the first time you open a class trainer.")

        -- The road: a stop for each visit ahead, then the weapon skills.
        used = {}
        local y = 0
        local levels = {}
        for stop in pairs(ahead) do levels[#levels + 1] = stop end
        table.sort(levels)
        local chipX = LEVEL_W + NODE_W + 8
        local chipW = roadW - 8 - chipX - COST_W - 8
        for i, stop in ipairs(levels) do
            local spells = ahead[stop]
            local s = Take("stops", MakeStop)
            local h = Chips(spells, chipX, y + 2, chipW) + 14
            s:ClearAllPoints()
            s:SetPoint("TOPLEFT", 0, -y)
            s:SetSize(roadW - 8, h)
            s.level:SetText(stop)
            local stopCost, missing = 0, false
            for _, spell in ipairs(spells) do
                if not spell.skipped then
                    if spell.cost then stopCost = stopCost + spell.cost else missing = true end
                end
            end
            s.cost:SetText(stopCost > 0 and Compat.Money(stopCost) or (missing and "|cff9a9688?|r" or ""))
            local first = i == 1
            Style.SetBorder(s.node.edges, first and "gold" or "lineStrong")
            s.level:SetTextColor(Style.Color(first and "text" or "muted"))
            y = y + h
        end
        if #levels == 0 then
            local head = Take("heads", MakeHead)
            head:ClearAllPoints()
            head:SetPoint("TOPLEFT", 0, -y)
            head.title:SetText("ALL TRAINED")
            head.note:SetText("Nothing left to learn on the way to 60")
            y = y + 34
        end

        y = y + 12
        local head = Take("heads", MakeHead)
        head:ClearAllPoints()
        head:SetPoint("TOPLEFT", 0, -y)
        head.title:SetText("WEAPON SKILLS")
        head.note:SetText("Prices fill in when you open a weapon master")
        y = y + 28
        -- Ones to learn first, then the ones you know.
        local weapons = {}
        for _, w in ipairs(data.weapons) do weapons[#weapons + 1] = w end
        table.sort(weapons, function(a, b)
            if a.known ~= b.known then return not a.known end
            return a.name < b.name
        end)
        for _, w in ipairs(weapons) do
            local r = Take("weapons", MakeWeapon)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 0, -y)
            r.spellID, r.hint = w.id, w.where and ("Taught by " .. w.where) or nil
            r.icon:SetTexture(w.icon)
            r.name:SetText(w.name)
            r.where:SetText(not w.known and (w.where or "At a weapon master") or "")
            if w.known then
                r.state:SetText("Known")
                r.state:SetTextColor(Style.Color("muted"))
            else
                r.state:SetText(w.cost and Compat.Money(w.cost) or "?")
                r.state:SetTextColor(Style.Color(w.cost and "text" or "muted"))
            end
            r:SetAlpha(w.known and 0.6 or 1)
            y = y + 26
        end

        for pool, list in pairs({ stops = stops, chips = chips, heads = heads, weapons = weaponRows }) do
            for i = (used[pool] or 0) + 1, #list do list[i]:Hide() end
        end
        road:SetHeight(math.max(1, y))
        roadScroll:UpdateScrollChildRect()
        roadScroll:Place()
    end

    page.Refresh = Paint
    local events = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_MONEY", "PLAYER_LEVEL_UP", "SPELLS_CHANGED", "TRAINER_CLOSED" }) do
        events:RegisterEvent(event)
    end
    events:SetScript("OnEvent", function()
        if page:IsVisible() then Compat.After(0.3, function() xpcall(Paint, ns.Report) end) end
    end)
end)
