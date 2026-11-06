-- The Training Planner page: your next trainer visit and what it costs,
-- your road to 60, and the spells: ready now, coming soon, later, skipped,
-- and the weapon skills you can learn.
local _, ns = ...
local Style, Compat, Window, Training = ns.Style, ns.Compat, ns.Window, ns.Training

local TOP_CARD, ROAD = 92, 74
local ROW_H, CARD_H, GAP = 28, 54, 8
local SECTION_H = 30

local function Section(parent, width)
    local s = CreateFrame("Frame", nil, parent)
    s:SetSize(width, 20)
    s.title = Style.Text(s, 11, "gold", nil, true)
    s.title:SetPoint("LEFT")
    s.count = Style.Text(s, 11, "muted", nil, true)
    s.count:SetPoint("LEFT", s.title, "RIGHT", 8, 0)
    s.note = Style.Text(s, 11, "muted")
    s.note:SetPoint("RIGHT")
    s.note:SetJustifyH("RIGHT")
    Style.Rule(s, "BOTTOM", "line")
    return s
end

local function Price(spell)
    return spell.cost and Compat.Money(spell.cost) or "|cff9a9688at the trainer|r"
end

Window.Page("training", function(page)
    local width, height = Window.contentWidth, Window.contentHeight
    local selectedLevel
    local Paint

    ---------------------------------------------------------------------------
    -- The next visit: what's ready, what it costs, and your gold.
    ---------------------------------------------------------------------------
    local visit = Style.Card(page, "Next trainer visit")
    visit:SetPoint("TOPLEFT", 0, -34)
    visit:SetSize(width, TOP_CARD)
    local cost = Style.Text(visit, 24, "gold", nil, true)
    cost:SetPoint("TOPLEFT", 12, -28)
    local ready = Style.Text(visit, 13, "text")
    ready:SetPoint("BOTTOMLEFT", cost, "BOTTOMRIGHT", 12, 3)
    local track = CreateFrame("Frame", nil, visit)
    track:SetPoint("TOPLEFT", 12, -62)
    track:SetSize(width * 0.5, 6)
    Style.Fill(track, "line")
    local fill = track:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT")
    fill:SetPoint("BOTTOMLEFT")
    fill:SetColorTexture(Style.Color("gold"))
    local enough = Style.Text(visit, 11, "muted")
    enough:SetPoint("TOPLEFT", track, "BOTTOMLEFT", 0, -6)
    enough:SetWidth(width * 0.62)

    local goldLabel = Style.Text(visit, 11, "muted", nil, true)
    goldLabel:SetPoint("TOPRIGHT", -12, -10)
    goldLabel:SetText("YOUR GOLD")
    local gold = Style.Text(visit, 16, "text", nil, true)
    gold:SetPoint("TOPRIGHT", goldLabel, "BOTTOMRIGHT", 0, -4)
    gold:SetJustifyH("RIGHT")
    local restLabel = Style.Text(visit, 11, "muted", nil, true)
    restLabel:SetPoint("TOPRIGHT", gold, "BOTTOMRIGHT", 0, -8)
    restLabel:SetText("LEFT TO 60")
    local rest = Style.Text(visit, 13, "text", nil, true)
    rest:SetPoint("TOPRIGHT", restLabel, "BOTTOMRIGHT", 0, -3)
    rest:SetJustifyH("RIGHT")

    ---------------------------------------------------------------------------
    -- The road to 60: a dot for level 1 and each even level, filled up to
    -- yours. Clicking one shows what that level brings.
    ---------------------------------------------------------------------------
    local road = Style.Card(page, "Your road to 60")
    road:SetPoint("TOPLEFT", visit, "BOTTOMLEFT", 0, -GAP)
    road:SetSize(width, ROAD)
    local roadNote = Style.Text(road, 11, "muted")
    roadNote:SetPoint("TOPRIGHT", -12, -10)
    roadNote:SetText("Click a level to see what it brings")
    local you = Style.Text(road, 10, "gold", nil, true)
    you:SetText("YOU")
    local stops = { 1 }
    for l = 2, 60, 2 do stops[#stops + 1] = l end
    local dots = {}
    local roadLeft, roadRight = 22, width - 22
    local line = road:CreateTexture(nil, "BORDER")
    line:SetColorTexture(Style.Color("lineStrong"))
    line:SetHeight(2)
    line:SetPoint("LEFT", road, "TOPLEFT", roadLeft, -40)
    line:SetPoint("RIGHT", road, "TOPLEFT", roadRight, -40)
    for i, level in ipairs(stops) do
        local x = roadLeft + (roadRight - roadLeft) * (i - 1) / (#stops - 1)
        local dot = CreateFrame("Button", nil, road)
        dot:SetSize(16, 16)
        dot:SetPoint("CENTER", road, "TOPLEFT", x, -40)
        dot.fill = dot:CreateTexture(nil, "ARTWORK")
        dot.fill:SetPoint("CENTER")
        dot.edges = Style.Border(dot, "lineStrong")
        dot.level = level
        if level == 1 or level % 10 == 0 then
            local label = Style.Text(road, 10, "muted")
            label:SetPoint("TOP", dot, "BOTTOM", 0, -3)
            label:SetText(level)
        end
        dot:SetScript("OnClick", function(self)
            selectedLevel = selectedLevel ~= self.level and self.level or nil
            Paint()
        end)
        dot:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(("Level %d"):format(self.level))
            GameTooltip:AddLine(self.brings or "", 0.6, 0.59, 0.53)
            GameTooltip:Show()
        end)
        dot:SetScript("OnLeave", function() GameTooltip:Hide() end)
        dots[i] = dot
    end

    ---------------------------------------------------------------------------
    -- The spell lists, in a list that scrolls with the mouse wheel.
    ---------------------------------------------------------------------------
    local listTop = 34 + TOP_CARD + GAP + ROAD + GAP + 4
    local scroll = CreateFrame("ScrollFrame", nil, page)
    scroll:SetPoint("TOPLEFT", 0, -listTop)
    scroll:SetSize(width - 10, height - listTop)
    local list = CreateFrame("Frame", nil, scroll)
    list:SetSize(width - 10, 1)
    scroll:SetScrollChild(list)
    local thumb = page:CreateTexture(nil, "ARTWORK")
    thumb:SetColorTexture(Style.Color("lineStrong"))
    thumb:SetWidth(3)
    local function PlaceThumb()
        local range, h = scroll:GetVerticalScrollRange(), scroll:GetHeight()
        thumb:SetShown(range > 0)
        if range <= 0 then return end
        local size = math.max(24, h * h / (h + range))
        thumb:SetHeight(size)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 8, -(h - size) * scroll:GetVerticalScroll() / range)
    end
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local target = self:GetVerticalScroll() - delta * ROW_H * 3
        self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), target)))
        PlaceThumb()
    end)

    -- Pools, so a repaint reuses what the last one made.
    local pools = { section = {}, card = {}, row = {} }
    local used = {}
    local listW = width - 10

    local function Take(kind, make)
        used[kind] = (used[kind] or 0) + 1
        local item = pools[kind][used[kind]]
        if not item then
            item = make()
            pools[kind][used[kind]] = item
        end
        item:Show()
        return item
    end

    local function Tooltip(frame)
        frame:EnableMouse(true)
        frame:SetScript("OnEnter", function(self)
            if not self.spellID then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(self.spellID)
            GameTooltip:Show()
        end)
        frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    local function MakeCard()
        local c = CreateFrame("Frame", nil, list)
        c:SetHeight(CARD_H)
        Style.Fill(c, "well")
        Style.Border(c, "line")
        c.icon = c:CreateTexture(nil, "ARTWORK")
        c.icon:SetSize(32, 32)
        c.icon:SetPoint("LEFT", 10, 0)
        c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        c.name = Style.Text(c, 13, "text", nil, true)
        c.name:SetPoint("TOPLEFT", c.icon, "TOPRIGHT", 10, -1)
        c.name:SetWordWrap(false)
        c.rank = Style.Text(c, 11, "muted")
        c.rank:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -3)
        c.cost = Style.Text(c, 12, "text", nil, true)
        c.cost:SetPoint("TOPRIGHT", -10, -9)
        c.cost:SetJustifyH("RIGHT")
        c.button = Style.Button(c, "Skip", "plain", 54)
        c.button:SetHeight(20)
        c.button:SetPoint("BOTTOMRIGHT", -8, 7)
        Tooltip(c)
        return c
    end

    local function MakeRow()
        local r = CreateFrame("Frame", nil, list)
        r:SetSize(listW, ROW_H)
        r.bg = Style.Fill(r, "well")
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(20, 20)
        r.icon:SetPoint("LEFT", 8, 0)
        r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.name = Style.Text(r, 13, "text")
        r.name:SetPoint("LEFT", r.icon, "RIGHT", 10, 0)
        r.rank = Style.Text(r, 11, "muted")
        r.rank:SetPoint("LEFT", r.name, "RIGHT", 8, 0)
        r.cost = Style.Text(r, 12, "text", nil, true)
        r.cost:SetPoint("RIGHT", -10, 0)
        r.cost:SetJustifyH("RIGHT")
        r.level = Style.Text(r, 11, "muted")
        r.level:SetPoint("RIGHT", -120, 0)
        r.level:SetJustifyH("RIGHT")
        r.button = Style.Button(r, "Skip", "plain", 54)
        r.button:SetHeight(20)
        r.button:SetPoint("RIGHT", -180, 0)
        Tooltip(r)
        return r
    end

    local y

    local function Head(title, count, note)
        local s = Take("section", function() return Section(list, listW) end)
        s:ClearAllPoints()
        s:SetPoint("TOPLEFT", 0, -y)
        s.title:SetText(title)
        s.count:SetText(count)
        s.note:SetText(note or "")
        y = y + SECTION_H
    end

    local function SkipButton(button, spell)
        button:SetLabel(spell.skipped and "Unskip" or "Skip")
        button:SetScript("OnClick", function()
            Training.Skip(spell.id, not spell.skipped)
            Paint()
        end)
    end

    local function Cards(spells)
        local cols = 3
        local w = (listW - (cols - 1) * GAP) / cols
        for i, spell in ipairs(spells) do
            local c = Take("card", MakeCard)
            local col, rowIndex = (i - 1) % cols, math.floor((i - 1) / cols)
            c:ClearAllPoints()
            c:SetWidth(w)
            c:SetPoint("TOPLEFT", col * (w + GAP), -(y + rowIndex * (CARD_H + GAP)))
            c.spellID = spell.id
            c.icon:SetTexture(spell.icon)
            c.name:SetText(spell.name)
            c.name:SetWidth(w - 130)
            c.rank:SetText(spell.rank or "")
            c.cost:SetText(Price(spell))
            SkipButton(c.button, spell)
        end
        y = y + math.ceil(#spells / cols) * (CARD_H + GAP) + 6
    end

    -- level: show "Level N" on the right; button: "skip" for Skip/Unskip.
    local function Rows(spells, showLevel, withButton)
        for i, spell in ipairs(spells) do
            local r = Take("row", MakeRow)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 0, -y)
            r.spellID = spell.id
            r.bg:SetShown(i % 2 == 1)
            r.icon:SetTexture(spell.icon)
            r.name:SetText(spell.name)
            r.rank:SetText(spell.rank or "")
            r.level:SetText(showLevel and ("Level " .. spell.level) or "")
            if spell.known ~= nil and spell.weapon then
                r.cost:SetText(spell.known and "|cff9a9688Known|r" or "From a weapon master")
            else
                r.cost:SetText(spell.known and "|cff9a9688Known|r" or Price(spell))
            end
            r.button:SetShown(withButton and not spell.known)
            if withButton and not spell.known then SkipButton(r.button, spell) end
            y = y + ROW_H
        end
        y = y + 10
    end

    local missing = Style.Text(page, 13, "text")
    missing:SetPoint("TOPLEFT", 0, -34)
    missing:SetWidth(width)
    missing:SetText("There's no spell list for this class yet.")

    Paint = function()
        local data = Training.Read()
        missing:SetShown(data == nil)
        visit:SetShown(data ~= nil)
        road:SetShown(data ~= nil)
        scroll:SetShown(data ~= nil)
        if not data then return end
        local level = UnitLevel("player")
        local sorted = Training.Sort(data, level)
        local money = GetMoney()

        -- The next visit.
        local unknownNote = sorted.nowUnknown > 0 and ((" + %d not priced yet"):format(sorted.nowUnknown)) or ""
        cost:SetText(sorted.nowCost > 0 and Compat.Money(sorted.nowCost) or (#sorted.now > 0 and "?" or "Nothing"))
        ready:SetText(#sorted.now > 0 and (("%d spell%s ready to train%s"):format(#sorted.now, #sorted.now == 1 and "" or "s", unknownNote)) or "Nothing to train right now")
        local need = sorted.nowCost
        fill:SetWidth(math.max(1, track:GetWidth() * (need > 0 and math.min(1, money / need) or 1)))
        if not data.haveTrainer then
            enough:SetText("Prices fill in the first time you open a class trainer: jsal.ui saves its whole list.")
        elseif need == 0 then
            enough:SetText("You're all trained up for now.")
        elseif money >= need then
            enough:SetText("Enough for all of it, with " .. Compat.Money(money - need) .. " to spare.")
        else
            enough:SetText("You're " .. Compat.Money(need - money) .. " short of all of it.")
        end
        gold:SetText(Compat.Money(money))
        rest:SetText(sorted.restCost > 0 and Compat.Money(sorted.restCost) or "?")

        -- The road.
        local byLevel = {}
        for _, spell in ipairs(data.spells) do
            local stop = spell.level <= 1 and 1 or (spell.level + spell.level % 2)
            byLevel[stop] = (byLevel[stop] or 0) + 1
        end
        local youDot
        for _, dot in ipairs(dots) do
            local reached = dot.level <= level
            local brings = byLevel[dot.level] or 0
            local size = brings > 0 and 10 or 6
            dot.fill:SetSize(size, size)
            dot.fill:SetColorTexture(Style.Color(reached and "gold" or "well"))
            Style.SetBorder(dot.edges, dot.level == selectedLevel and "gold" or (reached and "gold" or "lineStrong"))
            for _, edge in ipairs(dot.edges) do edge:SetShown(dot.level == selectedLevel) end
            dot.brings = brings > 0 and (("%d spell%s to learn"):format(brings, brings == 1 and "" or "s")) or "Nothing new"
            if dot.level <= level then youDot = dot end
        end
        you:ClearAllPoints()
        if youDot then you:SetPoint("BOTTOM", youDot, "TOP", 0, 1) end

        -- The lists.
        used = {}
        y = 0
        if selectedLevel then
            local at = {}
            for _, spell in ipairs(data.spells) do
                local stop = spell.level <= 1 and 1 or (spell.level + spell.level % 2)
                if stop == selectedLevel then at[#at + 1] = spell end
            end
            Head(("LEVEL %d BRINGS"):format(selectedLevel), #at, "Click the level again to go back")
            Rows(at, true, true)
        end
        Head("AVAILABLE NOW", #sorted.now, "Skip one to leave it out of your totals")
        if #sorted.now > 0 then Cards(sorted.now) else y = y + 4 end
        local soonCost = 0
        for _, spell in ipairs(sorted.soon) do soonCost = soonCost + (spell.cost or 0) end
        Head("COMING SOON", #sorted.soon, ("Within %d levels%s"):format(Training.SOON, soonCost > 0 and (", " .. Compat.Money(soonCost)) or ""))
        Rows(sorted.soon, true, true)
        Head("LATER", #sorted.later, "The rest of the way to 60")
        Rows(sorted.later, true, true)
        if #sorted.skipped > 0 then
            Head("SKIPPED", #sorted.skipped, "Left out of your totals")
            Rows(sorted.skipped, true, true)
        end
        local weapons = {}
        for _, w in ipairs(data.weapons) do
            weapons[#weapons + 1] = { id = w.id, name = w.name, icon = w.icon, known = w.known, weapon = true }
        end
        Head("WEAPON SKILLS", #weapons, "Taught by weapon masters in the cities")
        Rows(weapons, false, false)

        for kind, pool in pairs(pools) do
            for i = (used[kind] or 0) + 1, #pool do pool[i]:Hide() end
        end
        list:SetHeight(math.max(1, y))
        scroll:UpdateScrollChildRect()
        PlaceThumb()
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
