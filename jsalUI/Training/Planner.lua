-- The Training Planner page. On the left, what you can train now: a card for
-- each spell with its price and a Skip button, and the visit's total against
-- your gold. On the right, the road to 60 in a short box of its own: a stop
-- for each trainer visit to come, its spells and its cost. Under it, a
-- hunter's pet and the weapon skills.
local _, ns = ...
local Style, Compat, Window, Training = ns.Style, ns.Compat, ns.Window, ns.Training

local CART_W, CART_PAD, GAP = 312, 16, 26
local VISIT_H, FOLD_H = 52, 34   -- a spell in the visit's list; the line that folds the skipped ones away
local CHIP_H, CHIP_GAP = 32, 8   -- a road spell's icon, square
local LEVEL_W, NODE_W, COST_W = 34, 16, 64
local ROAD_H = 300   -- the road's own scrolling box: about six stops
local ROW_H = 34     -- a pet or weapon row: a name, and a detail under it
local STATE_W = 84   -- a row's price or state column ("Pet level 30")
local SKIP_W = 52
local SUB_H = 26     -- a heading inside the pet's list

-- A hunter's pet abilities, grouped by how each is got, in this order.
local PET_GROUPS = {
    { "ready", "Ready to teach" },
    { "trainer", "From a pet trainer" },
    { "level", "In Beast Training, waiting on your pet's level" },
    { "tame", "From taming a beast that has it" },
    { "unchecked", "Open Beast Training to check these" },
    { "known", "Known" },
}

-- Spells at an odd level are trained on the next even one, so each stop is
-- level 1 or an even level.
local function Stop(level)
    if level <= 1 then return 1 end
    return level + level % 2
end

-- Where a spell no class trainer sells comes from: its words on a card, the
-- letter on its road icon, and its tooltip line.
local VIA = {
    quest = { card = "Class quest", tag = "Quest", hint = "Learned from a class quest, not a trainer." },
    book = { card = "Book", tag = "Book", hint = "Learned from a book that drops, not a trainer." },
    portal = { card = "Portal trainer", tag = "Portal", hint = "Taught by a mage portal trainer, in a capital city." },
}

-- Quest and book spells cost no gold, so they stay out of the totals.
local function Free(spell)
    return spell.via == "quest" or spell.via == "book"
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

-- A quiet button of words (Skip, Unskip) that light up under the pointer:
-- for an action offered on every row, where a boxed button each would shout.
local function Link(parent, width)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, 20)
    b.text = Style.Text(b, 11, "muted")
    b.text:SetPoint("RIGHT")
    b.text:SetJustifyH("RIGHT")
    b:SetScript("OnEnter", function(self) self.text:SetTextColor(Style.Color("gold")) end)
    b:SetScript("OnLeave", function(self) self.text:SetTextColor(Style.Color("muted")) end)
    function b:SetLabel(text) self.text:SetText(text) end
    return b
end

Window.Page("training", function(page)
    local width, height = Window.contentWidth, Window.contentHeight
    local roadW = width - CART_W - GAP
    local top = 62
    local Paint

    -- The top: how many spells are ready and what they cost, your nearest
    -- class trainer, and a pin on the map to them.
    local title = Style.Text(page, 21, "text", nil, true)
    title:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", 0, -8)
    local where = Style.Text(page, 13, "muted")
    where:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    where:SetWidth(width - 200)
    where:SetWordWrap(false)
    local pin = Style.Button(page, "Show trainer on map", "primary", 180)
    pin:SetHeight(30)
    pin:SetPoint("TOPRIGHT", page.heading, "BOTTOMLEFT", width, -12)
    local function PaintTrainer()
        local _, _, classID = UnitClass("player")
        local nearest = classID and ns.Trainers and ns.Trainers.Nearest("class" .. classID)
        if nearest then
            local place = ns.Trainers.Zone(nearest)
            where:SetText(("Nearest trainer: |cffece6d6%s|r%s"):format(nearest.name, place and (", " .. place) or ""))
            pin:SetScript("OnClick", function() ns.Trainers.Pin(nearest) end)
            pin:Enable()
        else
            where:SetText("No class trainer found nearby")
            pin:Disable()
        end
    end

    ---------------------------------------------------------------------------
    -- Left: this visit.
    ---------------------------------------------------------------------------
    local cart = CreateFrame("Frame", nil, page)
    cart:SetPoint("TOPLEFT", 0, -top)
    cart:SetSize(CART_W, height - top)
    Style.Fill(cart, "titleBar")
    Style.Border(cart, "cardLine")
    local cartTitle = Style.Text(cart, 15, "text", nil, true)
    cartTitle:SetPoint("TOPLEFT", CART_PAD, -CART_PAD)
    cartTitle:SetText("This visit")
    local cartSub = Style.Text(cart, 11, "muted")
    cartSub:SetPoint("TOPRIGHT", -CART_PAD, -(CART_PAD + 3))
    cartSub:SetJustifyH("RIGHT")

    local TOTALS_H = 150
    local cardScroll, cardList = Style.Scroller(cart, CART_W - CART_PAD * 2, height - top - 48 - TOTALS_H - CART_PAD, nil, 6)
    cardScroll:SetPoint("TOPLEFT", CART_PAD, -48)
    local empty = Style.Text(cardList, 13, "muted")
    empty:SetPoint("TOPLEFT", 0, -4)
    empty:SetWidth(CART_W - CART_PAD * 2)

    local totals = CreateFrame("Frame", nil, cart)
    totals:SetPoint("BOTTOMLEFT", CART_PAD, CART_PAD)
    totals:SetPoint("BOTTOMRIGHT", -CART_PAD, CART_PAD)
    totals:SetHeight(TOTALS_H)
    Style.Rule(totals, "TOP", "line")
    local visitLabel = Style.Text(totals, 12, "muted")
    visitLabel:SetPoint("TOPLEFT", 0, -12)
    visitLabel:SetText("This visit")
    local visitCost = Style.Text(totals, 15, "gold", nil, true)
    visitCost:SetPoint("TOPRIGHT", 0, -10)
    visitCost:SetJustifyH("RIGHT")
    local track = CreateFrame("Frame", nil, totals)
    track:SetPoint("TOPLEFT", 0, -40)
    track:SetPoint("TOPRIGHT", 0, -40)
    track:SetHeight(6)
    Style.Fill(track, "line")
    local fill = track:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT")
    fill:SetPoint("BOTTOMLEFT")
    fill:SetColorTexture(Style.Color("gold"))
    -- Your gold, what's left after the visit, and the cost to 60: each a
    -- label and an amount.
    local haveLabel = Style.Text(totals, 12, "muted")
    haveLabel:SetPoint("TOPLEFT", 0, -56)
    haveLabel:SetText("You have")
    local haveText = Style.Text(totals, 12, "text")
    haveText:SetPoint("TOPRIGHT", 0, -56)
    haveText:SetJustifyH("RIGHT")
    local spareLabel = Style.Text(totals, 12, "muted")
    spareLabel:SetPoint("TOPLEFT", 0, -76)
    local spareText = Style.Text(totals, 12, "text")
    spareText:SetPoint("TOPRIGHT", 0, -76)
    spareText:SetJustifyH("RIGHT")
    local restLabel = Style.Text(totals, 12, "muted")
    restLabel:SetPoint("TOPLEFT", 0, -96)
    restLabel:SetText("Left to 60")
    local restText = Style.Text(totals, 12, "text")
    restText:SetPoint("TOPRIGHT", 0, -96)
    restText:SetJustifyH("RIGHT")
    local priceNote = Style.Text(totals, 11, "muted")
    priceNote:SetPoint("TOPLEFT", 0, -118)
    priceNote:SetWidth(CART_W - CART_PAD * 2)
    -- A spell in the visit: its icon, name and rank, its price, and Skip.
    local cards = {}
    local function Card(i)
        local c = CreateFrame("Frame", nil, cardList)
        c:SetSize(CART_W - CART_PAD * 2, VISIT_H)
        Style.Rule(c, "BOTTOM", "line")
        c.icon = c:CreateTexture(nil, "ARTWORK")
        c.icon:SetSize(30, 30)
        c.icon:SetPoint("LEFT", 0, 0)
        c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        c.name = Style.Text(c, 13, "text", nil, true)
        c.name:SetPoint("TOPLEFT", c.icon, "TOPRIGHT", 10, 1)
        c.name:SetWidth(CART_W - CART_PAD * 2 - 40 - 70)
        c.name:SetWordWrap(false)
        c.sub = Style.Text(c, 11, "muted")
        c.sub:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -3)
        c.sub:SetWidth(CART_W - CART_PAD * 2 - 40 - 56)
        c.sub:SetWordWrap(false)
        c.cost = Style.Text(c, 13, "text", nil, true)
        c.cost:SetPoint("TOPRIGHT", 0, -9)
        c.cost:SetJustifyH("RIGHT")
        c.skip = Link(c, SKIP_W)
        c.skip:SetPoint("BOTTOMRIGHT", 0, 5)
        c:EnableMouse(true)
        Tooltip(c)
        return c
    end

    -- Spells you've skipped fold into one line under the visit; a click
    -- opens it to show them, each with Unskip.
    local showSkipped = false
    local fold = CreateFrame("Button", nil, cardList)
    fold:SetSize(CART_W - CART_PAD * 2, FOLD_H)
    fold.sign = Style.Text(fold, 14, "gold", nil, true)
    fold.sign:SetPoint("LEFT", 0, 0)
    fold.text = Style.Text(fold, 12, "muted")
    fold.text:SetPoint("LEFT", 16, 0)
    fold.text:SetWidth(CART_W - CART_PAD * 2 - 16)
    fold.text:SetWordWrap(false)
    fold:SetScript("OnClick", function()
        showSkipped = not showSkipped
        Paint()
    end)
    Style.Hover(fold)

    ---------------------------------------------------------------------------
    -- Right: the road to 60.
    ---------------------------------------------------------------------------
    local roadHead = Section(page, roadW)
    roadHead:SetPoint("TOPLEFT", CART_W + GAP, -top)
    roadHead.title:SetText("YOUR ROAD TO 60")
    roadHead.note:SetText("Right-click an icon to skip it")
    -- The road scrolls in a short box of its own; a hunter's pet and the
    -- weapon skills share the space under it.
    local roadScroll, road = Style.Scroller(page, roadW - 8, ROAD_H, nil, 6)
    roadScroll:SetPoint("TOPLEFT", CART_W + GAP, -(top + 34))
    local roadEmpty = Style.Text(road, 13, "muted")
    roadEmpty:SetPoint("TOPLEFT", 0, -4)
    roadEmpty:SetText("Nothing left to learn on the way to 60.")
    local lowerTop = top + 34 + ROAD_H + 24
    local lowerScroll, lower = Style.Scroller(page, roadW - 8, height - lowerTop, nil, 6)
    lowerScroll:SetPoint("TOPLEFT", CART_W + GAP, -lowerTop)

    local stops, chips, heads, weaponRows, subs = {}, {}, {}, {}, {}
    local used

    local function Take(pool, make)
        used[pool] = (used[pool] or 0) + 1
        local list = ({ stops = stops, chips = chips, heads = heads, weapons = weaponRows, subs = subs })[pool]
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

    -- A spell on the road is just its icon, with its rank in the corner; the
    -- name and the rest are in its tooltip, so a busy level stays one row.
    local function MakeChip()
        local c = CreateFrame("Button", nil, road)
        c:SetSize(CHIP_H, CHIP_H)
        c:RegisterForClicks("RightButtonUp")
        c.edges = Style.Border(c, "lineStrong")
        c.icon = c:CreateTexture(nil, "ARTWORK")
        c.icon:SetPoint("TOPLEFT", 1, -1)
        c.icon:SetPoint("BOTTOMRIGHT", -1, 1)
        c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        c.badge = CreateFrame("Frame", nil, c)
        c.badge:SetSize(14, 12)
        c.badge:SetPoint("BOTTOMRIGHT", 2, -2)
        c.badge:SetFrameLevel(c:GetFrameLevel() + 2)
        Style.Fill(c.badge, "window")
        c.rank = Style.Text(c.badge, 10, "text", nil, true, true)
        c.rank:SetPoint("CENTER", 0, 0)
        c.rank:SetJustifyH("CENTER")
        c.tag = CreateFrame("Frame", nil, c)
        c.tag:SetSize(12, 12)
        c.tag:SetPoint("TOPLEFT", -2, 2)
        c.tag:SetFrameLevel(c:GetFrameLevel() + 2)
        Style.Fill(c.tag, "gold")
        c.tagText = Style.Text(c.tag, 9, "onGold", nil, true, true)
        c.tagText:SetPoint("CENTER", 0, 0)
        c.tagText:SetJustifyH("CENTER")
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
        return Section(lower, roadW - 16)
    end

    -- A heading inside the pet's list: how the abilities under it are got.
    local function MakeSub()
        local s = CreateFrame("Frame", nil, lower)
        s:SetSize(roadW - 16, SUB_H)
        s.text = Style.Text(s, 12, "secondary", nil, true)
        s.text:SetPoint("BOTTOMLEFT", 2, 4)
        return s
    end

    -- A pet or weapon row: icon and name, a detail, its price or state, and
    -- a Skip button for anything not learned yet.
    local function MakeWeapon()
        local r = CreateFrame("Frame", nil, lower)
        r:SetSize(roadW - 16, ROW_H)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(22, 22)
        r.icon:SetPoint("LEFT", 2, 0)
        r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.name = Style.Text(r, 12, "text")
        r.skip = Link(r, SKIP_W)
        r.skip:SetPoint("RIGHT", 0, 0)
        r.state = Style.Text(r, 12, "text", nil, true)
        r.state:SetPoint("RIGHT", -(SKIP_W + 12), 0)
        r.state:SetJustifyH("RIGHT")
        -- A detail (its rank, what it's waiting on) goes on a second line
        -- under the name, up to the state column.
        r.where = Style.Text(r, 11, "muted")
        r.where:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -2)
        r.where:SetWidth(roadW - 16 - 34 - SKIP_W - 12 - STATE_W - 12)
        r.where:SetWordWrap(false)
        function r:SetDetail(text)
            self.where:SetText(text or "")
            self.name:ClearAllPoints()
            if text and text ~= "" then
                self.name:SetPoint("BOTTOMLEFT", self.icon, "RIGHT", 10, 1)
            else
                self.name:SetPoint("LEFT", self.icon, "RIGHT", 10, 0)
            end
        end
        r:SetDetail(nil)
        r:EnableMouse(true)
        Tooltip(r)
        Style.Hover(r, 6)
        return r
    end

    -- Shows a row's Skip button for the spell it would skip, or hides it.
    local function SkipButton(r, spellID, skipped)
        r.skip:SetShown(spellID ~= nil)
        if not spellID then return end
        r.skip:SetLabel(skipped and "Unskip" or "Skip")
        r.skip:SetScript("OnClick", function()
            Training.Skip(spellID, not skipped)
            Paint()
        end)
    end

    -- The rank number in a spell's corner ("Rank 3" -> 3); none for one-rank spells.
    local function RankNumber(rank)
        return rank and rank:match("(%d+)") or nil
    end

    local function Chips(spells, x0, y0, maxW)
        local x, y = 0, 0
        for _, spell in ipairs(spells) do
            local c = Take("chips", MakeChip)
            c.spell, c.spellID = spell, spell.id
            c.hint = (spell.group and (spell.source == "demon" and spell.group .. "'s Grimoire. " or spell.group .. ". ") or "")
                .. (spell.via and (VIA[spell.via].hint .. " ") or "")
                .. (spell.skipped and "Skipped: right-click to put it back" or "Right-click to skip it")
            c.icon:SetTexture(spell.icon)
            local rank = RankNumber(spell.rank)
            c.rank:SetText(rank or "")
            c.badge:SetShown(rank ~= nil)
            -- A quest or book spell has its letter in the top corner, and a
            -- quest's frame is gold.
            local via = spell.via and VIA[spell.via]
            c.tagText:SetText(via and via.tag:sub(1, 1) or "")
            c.tag:SetShown(via ~= nil)
            Style.SetBorder(c.edges, spell.via == "quest" and "gold" or "lineStrong")
            if x > 0 and x + CHIP_H > maxW then
                x, y = 0, y + CHIP_H + CHIP_GAP
            end
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", x0 + x, -(y0 + y))
            c.icon:SetDesaturated(spell.skipped)
            c:SetAlpha(spell.skipped and 0.4 or 1)
            x = x + CHIP_H + CHIP_GAP
        end
        return y + CHIP_H
    end

    Paint = function()
        local data = Training.Read()
        if not data then
            cartSub:SetText("")
            title:SetText("No spell list for this class yet")
            fold:Hide()
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
                    if not spell.skipped and not Free(spell) then
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

        -- A hunter's pet abilities ready to teach join the list; they cost
        -- training points, not gold, so they stay out of the visit's total.
        local pet = Training.Pet()
        for _, row in ipairs(pet and pet.rows or {}) do
            if row.state == "ready" then
                now[#now + 1] = {
                    id = row.spell.pet, name = row.name, icon = row.icon, level = row.spell.level,
                    rank = row.spell.rank > 0 and ("Rank " .. row.spell.rank) or nil,
                    skipped = row.skipped, source = "beast", group = "Your pet", points = row.points,
                }
            end
        end

        -- This visit: what's ready, then the skipped ones folded away.
        local active, skipped = {}, {}
        for _, spell in ipairs(now) do
            local to = spell.skipped and skipped or active
            to[#to + 1] = spell
        end
        cartSub:SetText("Level " .. level)
        -- The title counts a pet's abilities apart from your own spells: the
        -- gold beside it is only for the spells.
        local spells, abilities = 0, 0
        for _, spell in ipairs(active) do
            if spell.source == "beast" then abilities = abilities + 1 else spells = spells + 1 end
        end
        local ready = {}
        if spells > 0 then ready[#ready + 1] = ("%d spell%s"):format(spells, spells == 1 and "" or "s") end
        if abilities > 0 then ready[#ready + 1] = ("%d pet abilit%s"):format(abilities, abilities == 1 and "y" or "ies") end
        if #ready > 0 then
            title:SetText(table.concat(ready, " and ") .. " ready"
                .. (cost > 0 and ("   |cffe3b04b" .. Compat.Money(cost) .. "|r") or ""))
        else
            title:SetText("Nothing to train right now")
        end
        local at, shown = 0, 0
        local function Put(spell)
            shown = shown + 1
            local c = cards[shown] or Card(shown)
            cards[shown] = c
            c.spellID = spell.id
            c.icon:SetTexture(spell.icon)
            c.name:SetText(spell.name)
            local detail = spell.rank or ("Level " .. spell.level)
            if spell.source == "demon" then detail = spell.group .. " · Grimoire · " .. detail
            elseif spell.group then detail = spell.group .. " · " .. detail
            elseif spell.via then detail = VIA[spell.via].card .. " · " .. detail end
            c.sub:SetText(detail)
            c.hint = spell.via and VIA[spell.via].hint or nil
            if spell.source == "beast" then
                c.cost:SetText(spell.points and (spell.points .. " TP") or "|cff9a9688? TP|r")
            elseif Free(spell) then
                c.cost:SetText("|cff9a9688" .. VIA[spell.via].tag .. "|r")
            else
                c.cost:SetText(Price(spell) or "|cff9a9688?|r")
            end
            c.skip:SetLabel(spell.skipped and "Unskip" or "Skip")
            c.skip:SetScript("OnClick", function()
                Training.Skip(spell.id, not spell.skipped)
                Paint()
            end)
            c:SetAlpha(spell.skipped and 0.6 or 1)
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", 0, -at)
            c:Show()
            at = at + VISIT_H
        end
        for _, spell in ipairs(active) do Put(spell) end
        fold:SetShown(#skipped > 0)
        if #skipped > 0 then
            local names = {}
            for _, spell in ipairs(skipped) do names[#names + 1] = spell.name end
            fold.sign:SetText(showSkipped and "-" or "+")
            fold.text:SetText(("|cffc4bfb0%d skipped|r  %s"):format(#skipped, table.concat(names, ", ")))
            fold:ClearAllPoints()
            fold:SetPoint("TOPLEFT", 0, -at)
            at = at + FOLD_H
            if showSkipped then
                for _, spell in ipairs(skipped) do Put(spell) end
            end
        end
        for i = shown + 1, #cards do cards[i]:Hide() end
        empty:SetShown(#now == 0)
        empty:SetText("Nothing to train right now. The road on the right shows what's next.")
        cardList:SetHeight(math.max(1, at))
        cardScroll:UpdateScrollChildRect()
        cardScroll:Place()

        -- The visit's total against your gold.
        visitCost:SetText(cost > 0 and Compat.Money(cost) or (unknown > 0 and "?" or "Nothing"))
        fill:SetWidth(math.max(1, track:GetWidth() * (cost > 0 and math.min(1, money / cost) or 1)))
        haveText:SetText(Compat.Money(money))
        local short = money < cost
        spareLabel:SetText(short and "Short by" or "Left after")
        spareLabel:SetTextColor(Style.Color(short and "gold" or "muted"))
        spareText:SetText(Compat.Money(math.abs(money - cost)))
        spareText:SetTextColor(Style.Color(short and "gold" or "text"))
        spareLabel:SetShown(cost > 0)
        spareText:SetShown(cost > 0)
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
                if not spell.skipped and not Free(spell) then
                    if spell.cost then stopCost = stopCost + spell.cost else missing = true end
                end
            end
            s.cost:SetText(stopCost > 0 and Compat.Money(stopCost) or (missing and "|cff9a9688?|r" or ""))
            local first = i == 1
            Style.SetBorder(s.node.edges, first and "gold" or "lineStrong")
            s.level:SetTextColor(Style.Color(first and "text" or "muted"))
            y = y + h
        end
        roadEmpty:SetShown(#levels == 0)
        road:SetHeight(math.max(1, y))
        roadScroll:UpdateScrollChildRect()
        roadScroll:Place()

        -- Under the road: a hunter's pet, each ability's next rank and what
        -- it's waiting on; then the weapon skills.
        y = 0
        if pet then
            local petHead = Take("heads", MakeHead)
            petHead:ClearAllPoints()
            petHead:SetPoint("TOPLEFT", 0, -y)
            petHead.title:SetText("YOUR PET")
            y = y + 28
            if pet.none then
                petHead.note:SetText("")
                local r = Take("weapons", MakeWeapon)
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", 0, -y)
                r.spellID, r.hint = nil, nil
                r.icon:SetTexture(select(2, Compat.SpellInfo(883)))
                r.name:SetText("Call your pet to see what it can learn")
                r:SetDetail(nil)
                r.state:SetText("")
                SkipButton(r, nil)
                r:SetAlpha(1)
                y = y + ROW_H
            else
                local note = ("%s · %s · level %d"):format(pet.name or "Pet", pet.family, pet.level or 0)
                if pet.free then note = note .. (" · %d training points free"):format(pet.free) end
                petHead.note:SetText(note)
                for _, group in ipairs(PET_GROUPS) do
                    local headed = false
                    for _, row in ipairs(pet.rows) do
                        if row.state == group[1] then
                            if not headed then
                                headed = true
                                local s = Take("subs", MakeSub)
                                s:ClearAllPoints()
                                s:SetPoint("TOPLEFT", 0, -y)
                                s.text:SetText(group[2])
                                y = y + SUB_H
                            end
                            local r = Take("weapons", MakeWeapon)
                            r:ClearAllPoints()
                            r:SetPoint("TOPLEFT", 0, -y)
                            local rank = row.spell.rank > 0 and ("Rank " .. row.spell.rank) or nil
                            r.spellID = row.spell.pet
                            r.icon:SetTexture(row.icon)
                            r.name:SetText(row.name)
                            -- The heading says how it's got; the row says its
                            -- rank, and when: now, or the level your pet needs.
                            local when = (pet.level or 0) >= row.spell.level and "Any time" or ("Pet level " .. row.spell.level)
                            local detail, state, color = rank or "", when, "muted"
                            if row.state == "known" then
                                state = ""
                                r.hint = nil
                            elseif row.state == "ready" then
                                detail = (rank and (rank .. " · ") or "") .. (row.points and (row.points .. " training points") or "in Beast Training")
                                state, color = "Ready", "gold"
                                r.hint = "Teach it from your Beast Training."
                            elseif row.state == "level" then
                                r.hint = "In your Beast Training. Your pet needs level " .. row.spell.level .. "."
                            elseif row.state == "trainer" then
                                r.hint = "Buy it from a pet trainer, then teach it from your Beast Training."
                            elseif row.state == "tame" then
                                r.hint = "Not in your Beast Training yet: tame a beast that has it, and you learn it."
                            else
                                r.hint = "Open Beast Training once so jsal.ui can see what's in it."
                            end
                            if row.skipped then state, color = "Skipped", "muted" end
                            r:SetDetail(detail)
                            r.state:SetText(state)
                            r.state:SetTextColor(Style.Color(color))
                            SkipButton(r, row.state ~= "known" and row.spell.pet or nil, row.skipped)
                            r:SetAlpha((row.state == "known" or row.skipped) and 0.6 or 1)
                            y = y + ROW_H
                        end
                    end
                end
            end
            y = y + 22
        end

        local head = Take("heads", MakeHead)
        head:ClearAllPoints()
        head:SetPoint("TOPLEFT", 0, -y)
        head.title:SetText("WEAPON SKILLS")
        head.note:SetText("Any weapon master, same price")
        y = y + 34
        -- Ones to learn first, then skipped ones, then the ones you know.
        local weapons = {}
        for _, w in ipairs(data.weapons) do weapons[#weapons + 1] = w end
        local function Order(w) return w.known and 3 or (w.skipped and 2 or 1) end
        table.sort(weapons, function(a, b)
            if Order(a) ~= Order(b) then return Order(a) < Order(b) end
            return a.name < b.name
        end)
        for _, w in ipairs(weapons) do
            local r = Take("weapons", MakeWeapon)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 0, -y)
            r.spellID, r.hint = w.id, not w.known and "Any weapon master teaches it, at the same price." or nil
            r.icon:SetTexture(w.icon)
            r.name:SetText(w.name)
            r:SetDetail(nil)
            if w.known then
                r.state:SetText("Known")
                r.state:SetTextColor(Style.Color("muted"))
            elseif w.skipped then
                r.state:SetText("Skipped")
                r.state:SetTextColor(Style.Color("muted"))
            else
                r.state:SetText(w.cost and Compat.Money(w.cost) or "?")
                r.state:SetTextColor(Style.Color(w.cost and "text" or "muted"))
            end
            SkipButton(r, not w.known and w.id or nil, w.skipped)
            r:SetAlpha((w.known or w.skipped) and 0.6 or 1)
            y = y + ROW_H
        end

        for pool, list in pairs({ stops = stops, chips = chips, heads = heads, weapons = weaponRows, subs = subs }) do
            for i = (used[pool] or 0) + 1, #list do list[i]:Hide() end
        end
        lower:SetHeight(math.max(1, y))
        lowerScroll:UpdateScrollChildRect()
        lowerScroll:Place()
    end

    page.Refresh = function()
        Paint()
        PaintTrainer()
    end
    local events = CreateFrame("Frame")
    for _, event in ipairs({ "PLAYER_MONEY", "PLAYER_LEVEL_UP", "SPELLS_CHANGED", "TRAINER_CLOSED", "MERCHANT_CLOSED",
                             "UNIT_PET", "UNIT_LEVEL", "CRAFT_CLOSE" }) do
        -- pcall: not every client has the Beast Training window's events.
        pcall(events.RegisterEvent, events, event)
    end
    events:SetScript("OnEvent", function(_, event, unit)
        unit = Compat.Plain(unit)
        if event == "UNIT_LEVEL" and unit ~= "pet" then return end
        if page:IsVisible() then Compat.After(0.3, function() xpcall(Paint, ns.Report) end) end
    end)
end)
