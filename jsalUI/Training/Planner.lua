-- The Training Planner page. At the top, one line of what's ready and what
-- it costs, and one of whether your gold covers it. On the left, what you
-- can train now: a line for each spell with its price and Skip, the sums
-- right under it, and under those a hunter's pet. On the right, the road to
-- 60, down the whole page: the next trainer visit spelled out, then a line
-- down the page with a mark a level and each visit's spells as their
-- symbols, and after the last the weapon skills.
local _, ns = ...
local Style, Compat, Window, Training = ns.Style, ns.Compat, ns.Window, ns.Training

local CART_W, GAP = 330, 28
local VISIT_H, FOLD_H = 46, 34   -- a spell in the visit's list; the line that folds the skipped ones away
local NAME_X, COST_W = 52, 76    -- on the road: where names start, and the cost column
local STEP_H = 24                -- a spell of the next visit
local GLYPH, GLYPH_GAP = 28, 4   -- a spell of a later visit, as its symbol
local LINE_X = 8                 -- the road's line, down the left of the later visits
local LIST_TOP = 44  -- where the list to train now starts, under its headings
local ROW_H = 28     -- a weapon skill's row
local PET_H = 24     -- a pet ability's row
local SKIP_W = 40
local SUB_H = 26     -- a heading inside the pet's list
local TOTALS_H = 112 -- the sums: four lines in a box

-- A hunter's pet abilities, grouped by how each is got, in this order.
local PET_GROUPS = {
    { "ready", "Ready to teach" },
    { "trainer", "From a pet trainer" },
    { "level" },   -- headed by the level each waits on: "Waiting on pet level 30"
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

-- Where a spell no class trainer sells comes from: its words on a line, and
-- its tooltip line.
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

-- The rank number of a spell ("Rank 3" -> 3); none for one-rank spells.
local function RankNumber(rank)
    return rank and tonumber(rank:match("(%d+)")) or nil
end

-- A spell you don't have in any rank yet: an ability new to you, where a
-- higher rank is more of one you know. It's what a visit is worth making for.
local function New(spell)
    return (RankNumber(spell.rank) or 1) == 1
end

-- How wide a line of text is drawn, or a guess where that isn't known.
local function Wide(text, guess)
    local w = text.GetStringWidth and text:GetStringWidth()
    return (type(w) == "number" and w > 0) and w or guess
end

-- A section's heading: a title in gold and a note at the right. `ruled`: a
-- line under it, for one with no column headings of its own.
local function Section(parent, width, ruled)
    local s = CreateFrame("Frame", nil, parent)
    s:SetSize(width, 20)
    s.title = Style.Text(s, 12, "gold", nil, true)
    s.title:SetPoint("LEFT")
    s.note = Style.Text(s, 11, "muted")
    s.note:SetPoint("RIGHT")
    s.note:SetJustifyH("RIGHT")
    if ruled then Style.Rule(s, "BOTTOM", "lineStrong") end
    return s
end

-- Column headings over a list: each { words, x }, a negative x from the right.
local function Columns(parent, width, labels)
    local c = CreateFrame("Frame", nil, parent)
    c:SetSize(width, 18)
    for _, label in ipairs(labels) do
        local t = Style.Text(c, 10, "muted", nil, true)
        if label[2] < 0 then
            t:SetPoint("TOPRIGHT", label[2], 0)
            t:SetJustifyH("RIGHT")
        else
            t:SetPoint("TOPLEFT", label[2], 0)
        end
        t:SetText(label[1])
    end
    Style.Rule(c, "BOTTOM", "lineStrong")
    return c
end

-- A small label after a name: gold for "new", plain for what a thing is.
local function Tag(parent, words, gold)
    local t = CreateFrame("Frame", nil, parent)
    Style.Fill(t, gold and "gold" or "line")
    t.text = Style.Text(t, 10, gold and "onGold" or "text", nil, gold)
    t.text:SetPoint("CENTER")
    t.text:SetText(words)
    t.wide = Wide(t.text, #words * 5.2) + 12
    t:SetSize(t.wide, 15)
    return t
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

-- What a road spell's tooltip adds: whose it is, where it comes from, and
-- that a right-click skips it.
local function Hint(spell)
    return (spell.group and (spell.source == "demon" and spell.group .. "'s Grimoire. " or spell.group .. ". ") or "")
        .. (spell.via and (VIA[spell.via].hint .. " ") or "")
        .. (spell.skipped and "Skipped: right-click to put it back" or "Right-click to skip it")
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
    local top = 88
    local Paint
    -- What the page is made of, in one table: Paint uses so much from outside
    -- itself that it was at the edge of what the game's Lua allows one
    -- function (limits_test.lua).
    local ui = {}

    -- The top: how many spells are ready and what they cost, whether your
    -- gold covers it, your nearest class trainer, and a pin on the map.
    ui.title = Style.Text(page, 21, "text", nil, true)
    ui.title:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", 0, -8)
    ui.gold = Style.Text(page, 13, "muted")
    ui.gold:SetPoint("TOPLEFT", ui.title, "BOTTOMLEFT", 0, -5)
    ui.gold:SetWidth(width - 200)
    ui.gold:SetWordWrap(false)
    local where = Style.Text(page, 13, "muted")
    where:SetPoint("TOPLEFT", ui.gold, "BOTTOMLEFT", 0, -4)
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
    -- Left: what to train now.
    ---------------------------------------------------------------------------
    local cart = CreateFrame("Frame", nil, page)
    cart:SetPoint("TOPLEFT", 0, -top)
    cart:SetSize(CART_W, height - top)
    ui.cartHead = Section(cart, CART_W)
    ui.cartHead:SetPoint("TOPLEFT")
    ui.cartHead.title:SetText("TRAIN NOW")
    Columns(cart, CART_W, { { "SPELL", 2 }, { "COST", -(SKIP_W + 6) } }):SetPoint("TOPLEFT", 0, -24)
    -- The list is as tall as what's in it (Paint sizes it), so the sums sit
    -- right under it: they were at the foot of the page, most of a screen
    -- below a list of one. (John's screenshot, 14 Nov 2026.)
    ui.cardScroll, ui.cardList = Style.Scroller(cart, CART_W, VISIT_H, nil, 6)
    ui.cardScroll:SetPoint("TOPLEFT", 0, -LIST_TOP)
    ui.empty = Style.Text(ui.cardList, 13, "muted")
    ui.empty:SetPoint("TOPLEFT", 2, -10)
    ui.empty:SetWidth(CART_W - 4)

    -- The sums, each a label and an amount: this visit, your gold, what's
    -- left after, and everything still to buy on the way to 60.
    local totals = CreateFrame("Frame", nil, cart)
    totals:SetSize(CART_W, TOTALS_H)
    Style.Fill(totals, "well")
    ui.totals = totals
    local function Sum(i, label, size, colorKey, bold)
        local l = Style.Text(totals, 12, "muted")
        l:SetPoint("TOPLEFT", 14, -(12 + (i - 1) * 24))
        l:SetText(label)
        local amount = Style.Text(totals, size, colorKey, nil, bold)
        amount:SetPoint("TOPRIGHT", -14, -(12 + (i - 1) * 24 - (size > 12 and 2 or 0)))
        amount:SetJustifyH("RIGHT")
        return amount, l
    end
    ui.visitCost = Sum(1, "This visit", 15, "gold", true)
    ui.haveText = Sum(2, "You have", 12, "text")
    ui.spareText, ui.spareLabel = Sum(3, "Left after", 12, "text")
    ui.restText = Sum(4, "All training to 60", 12, "text")
    local sumRule = totals:CreateTexture(nil, "ARTWORK")
    sumRule:SetColorTexture(Style.Color("line"))
    sumRule:SetPoint("TOPLEFT", 14, -80)
    sumRule:SetPoint("TOPRIGHT", -14, -80)
    sumRule:SetHeight(1)
    ui.priceNote = Style.Text(cart, 11, "muted")
    ui.priceNote:SetPoint("TOPLEFT", totals, "BOTTOMLEFT", 2, -6)
    ui.priceNote:SetWidth(CART_W - 4)
    ui.priceNote:SetWordWrap(false)

    -- Under the sums, a hunter's pet: what it can learn, by how each is
    -- got, a line an ability. (It was under the road, each ability two
    -- lines tall with "Pet level 30" beside every one of eight.)
    ui.petHead = Section(cart, CART_W, true)
    ui.petHead.title:SetText("YOUR PET")
    ui.petScroll, ui.petList = Style.Scroller(cart, CART_W, PET_H, nil, 6)
    ui.petHead:Hide()
    ui.petScroll:Hide()

    -- The rows this page has made and reuses, by kind.
    local made = { cards = {}, stops = {}, steps = {}, glyphs = {}, heads = {}, weapons = {}, subs = {}, pets = {} }
    -- A spell to train now: its icon, name and rank, its price, and Skip.
    local function Card()
        local c = CreateFrame("Frame", nil, ui.cardList)
        c:SetSize(CART_W, VISIT_H)
        Style.Rule(c, "BOTTOM", "line")
        c.icon = c:CreateTexture(nil, "ARTWORK")
        c.icon:SetSize(28, 28)
        c.icon:SetPoint("LEFT", 2, 0)
        c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        c.name = Style.Text(c, 13, "text", nil, true)
        c.name:SetWordWrap(false)
        c.new = Tag(c, "new", true)
        c.new:SetPoint("LEFT", c.name, "RIGHT", 8, 0)
        c.sub = Style.Text(c, 11, "muted")
        c.sub:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -3)
        c.sub:SetWidth(CART_W - 40 - SKIP_W - 70)
        c.sub:SetWordWrap(false)
        c.skip = Link(c, SKIP_W)
        c.skip:SetPoint("RIGHT", -2, 0)
        c.cost = Style.Text(c, 13, "text", nil, true)
        c.cost:SetPoint("RIGHT", -(SKIP_W + 6), 0)
        c.cost:SetJustifyH("RIGHT")
        -- With no line under it, the name sits in the middle of the row.
        function c:SetDetail(text)
            self.sub:SetText(text or "")
            self.name:ClearAllPoints()
            if text and text ~= "" then
                self.name:SetPoint("BOTTOMLEFT", self.icon, "RIGHT", 10, 1)
            else
                self.name:SetPoint("LEFT", self.icon, "RIGHT", 10, 0)
            end
        end
        c:EnableMouse(true)
        Tooltip(c)
        return c
    end

    -- Spells you've skipped fold into one line under the list; a click
    -- opens it to show them, each with Unskip.
    local showSkipped = false
    local fold = CreateFrame("Button", nil, ui.cardList)
    fold:SetSize(CART_W, FOLD_H)
    fold.sign = Style.Text(fold, 14, "gold", nil, true)
    fold.sign:SetPoint("LEFT", 4, 0)
    fold.text = Style.Text(fold, 12, "muted")
    fold.text:SetPoint("LEFT", 20, 0)
    fold.text:SetWidth(CART_W - 20)
    fold.text:SetWordWrap(false)
    fold:SetScript("OnClick", function()
        showSkipped = not showSkipped
        Paint()
    end)
    Style.Hover(fold)
    ui.fold = fold

    ---------------------------------------------------------------------------
    -- Right: the road to 60, in words.
    ---------------------------------------------------------------------------
    local roadHead = Section(page, roadW)
    roadHead:SetPoint("TOPLEFT", CART_W + GAP, -top)
    roadHead.title:SetText("YOUR ROAD TO 60")
    roadHead.note:SetText("gold frame: new to you  ·  right-click skips")
    Columns(page, roadW, { { "LEVEL", 2 }, { "WHAT YOU LEARN", NAME_X }, { "COST", -10 } }):SetPoint("TOPLEFT", CART_W + GAP, -(top + 24))
    -- The road has the height of the page, and the weapon skills come after
    -- its last stop in the same list. (It was a box of four visits to
    -- scroll, over a pet's list that needed scrolling too.)
    local road
    ui.roadScroll, road = Style.Scroller(page, roadW - 8, height - top - 50, nil, 6)
    ui.roadScroll:SetPoint("TOPLEFT", CART_W + GAP, -(top + 50))
    ui.road = road
    ui.roadEmpty = Style.Text(road, 13, "muted")
    ui.roadEmpty:SetPoint("TOPLEFT", 2, -10)
    ui.roadEmpty:SetText("Nothing left to learn on the way to 60.")
    ui.roadLine = road:CreateTexture(nil, "BACKGROUND")
    ui.roadLine:SetColorTexture(Style.Color("lineStrong"))
    ui.roadLine:SetWidth(2)
    ui.roadLine:Hide()

    local used

    local function Take(pool, make)
        used[pool] = (used[pool] or 0) + 1
        local list = made[pool]
        local item = list[used[pool]]
        if not item then
            item = make()
            list[used[pool]] = item
        end
        item:Show()
        return item
    end

    -- A right-click on a road spell skips it, or puts it back.
    local function SkipClick(self)
        if self.spell then
            Training.Skip(self.spell.id, not self.spell.skipped)
            Paint()
        end
    end

    -- The next visit: a card with its level and cost, a line for each spell.
    ui.nextCard = CreateFrame("Frame", nil, road)
    ui.nextCard:SetWidth(roadW - 8)
    Style.Fill(ui.nextCard, "well"):SetAlpha(0.5)
    do
        local edge = ui.nextCard:CreateTexture(nil, "ARTWORK")
        edge:SetColorTexture(Style.Color("gold"))
        edge:SetPoint("TOPLEFT")
        edge:SetPoint("BOTTOMLEFT")
        edge:SetWidth(3)
        ui.nextLevel = Style.Text(ui.nextCard, 15, "text", nil, true)
        ui.nextLevel:SetPoint("TOPLEFT", 14, -8)
        Tag(ui.nextCard, "next visit"):SetPoint("TOPLEFT", NAME_X, -10)
        ui.nextCost = Style.Text(ui.nextCard, 13, "text", nil, true)
        ui.nextCost:SetPoint("TOPRIGHT", -10, -9)
        ui.nextCost:SetJustifyH("RIGHT")
        -- What a hunter's pet can learn by then, under the visit's spells.
        ui.nextPet = Tag(ui.nextCard, "your pet")
        ui.nextPetText = Style.Text(ui.nextCard, 12, "muted")
        ui.nextPetText:SetPoint("LEFT", ui.nextPet, "RIGHT", 8, 0)
        ui.nextPetText:SetWidth(roadW - 8 - NAME_X - 70)
        ui.nextPetText:SetWordWrap(false)
    end

    -- A spell of the next visit: its icon, its name, that it's new or its
    -- rank, and its price.
    local function MakeStep()
        local r = CreateFrame("Button", nil, road)
        r:SetSize(roadW - 8, STEP_H)
        -- Above the card: both are the road's children, and at one level the
        -- game may draw the card's fill over the line.
        r:SetFrameLevel(road:GetFrameLevel() + 3)
        r:RegisterForClicks("RightButtonUp")
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(18, 18)
        r.icon:SetPoint("LEFT", 14, 0)
        r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.name = Style.Text(r, 13, "text")
        r.name:SetPoint("LEFT", NAME_X, 0)
        r.name:SetWordWrap(false)
        r.new = Tag(r, "new", true)
        r.new:SetPoint("LEFT", r.name, "RIGHT", 8, 0)
        r.rank = Style.Text(r, 12, "muted")
        r.rank:SetPoint("LEFT", r.name, "RIGHT", 8, 0)
        r.cost = Style.Text(r, 12, "muted")
        r.cost:SetPoint("RIGHT", -10, 0)
        r.cost:SetJustifyH("RIGHT")
        Tooltip(r)
        Style.Hover(r)
        r:SetScript("OnClick", SkipClick)
        return r
    end

    -- A later visit: a mark on the road's line, its level, the symbols of
    -- what it teaches (laid out by Glyphs), and its cost.
    local function MakeStop()
        local s = CreateFrame("Frame", nil, road)
        s.node = s:CreateTexture(nil, "ARTWORK")
        s.node:SetSize(8, 8)
        s.node:SetPoint("TOPLEFT", LINE_X - 3, -(8 + (GLYPH - 8) / 2))
        s.level = Style.Text(s, 13, "secondary", nil, true)
        s.level:SetPoint("LEFT", s, "TOPLEFT", 20, -(8 + GLYPH / 2))
        s.cost = Style.Text(s, 12, "text")
        s.cost:SetPoint("RIGHT", s, "TOPRIGHT", -10, -(8 + GLYPH / 2))
        s.cost:SetJustifyH("RIGHT")
        s.pet = Tag(s, "your pet")
        return s
    end

    -- A spell of a later visit is its symbol, to take in at a glance: a
    -- gold frame round an ability new to you, a higher rank's number in its
    -- corner. Pointing at it names it; a right-click skips it. (They were
    -- words, a paragraph a visit. John, 14 Nov 2026: "i would like to have
    -- this read as more of like a road itself though, can we just have the
    -- symbols instead?", "a lot of text, this should be easy to look at.
    -- icons provide a quick at a glance".)
    local function MakeGlyph()
        local g = CreateFrame("Button", nil, road)
        g:SetSize(GLYPH, GLYPH)
        g:RegisterForClicks("RightButtonUp")
        g.frame = g:CreateTexture(nil, "BACKGROUND")
        g.frame:SetAllPoints()
        g.icon = g:CreateTexture(nil, "ARTWORK")
        g.icon:SetPoint("TOPLEFT", 2, -2)
        g.icon:SetPoint("BOTTOMRIGHT", -2, 2)
        g.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        g.back = g:CreateTexture(nil, "OVERLAY")
        g.back:SetColorTexture(0, 0, 0, 0.8)
        g.back:SetPoint("BOTTOMRIGHT", -2, 2)
        g.rank = Style.Text(g, 11, "text", "OVERLAY", true, true)
        g.rank:SetPoint("CENTER", g.back, "CENTER", 0, 0)
        Tooltip(g)
        g:SetScript("OnClick", SkipClick)
        return g
    end

    -- Lays a visit's spells out as symbols from (x0, y0), wrapping at maxW,
    -- the abilities new to you first; returns how tall they came to, and
    -- whether any is new. A spell's rank is its `number`, or read from its
    -- rank's words.
    local function Glyphs(spells, x0, y0, maxW)
        local list, any = {}, false
        for k, spell in ipairs(spells) do
            local rank = spell.number or RankNumber(spell.rank) or 1
            list[k] = { spell = spell, rank = rank, fresh = rank <= 1, at = k }
        end
        table.sort(list, function(a, b)
            if a.fresh ~= b.fresh then return a.fresh end
            return a.at < b.at
        end)
        local x, y = 0, 0
        for _, e in ipairs(list) do
            local g, spell = Take("glyphs", MakeGlyph), e.spell
            g.spell, g.spellID, g.hint = spell, spell.id, Hint(spell)
            g.icon:SetTexture(spell.icon)
            g.icon:SetDesaturated(spell.skipped and true or false)
            g.frame:SetColorTexture(Style.Color(e.fresh and "gold" or "lineStrong"))
            g.back:SetShown(not e.fresh)
            g.rank:SetText(e.fresh and "" or e.rank)
            if not e.fresh then g.back:SetSize(e.rank > 9 and 16 or 11, 12) end
            any = any or (e.fresh and not spell.skipped)
            if x > 0 and x + GLYPH > maxW then
                x, y = 0, y + GLYPH + GLYPH_GAP
            end
            g:ClearAllPoints()
            g:SetPoint("TOPLEFT", x0 + x, -(y0 + y))
            g:SetAlpha(spell.skipped and 0.4 or 1)
            x = x + GLYPH + GLYPH_GAP
        end
        return y + GLYPH, any
    end

    local function MakeHead()
        return Section(road, roadW - 8, true)
    end

    -- A heading inside the pet's list: how the abilities under it are got,
    -- and how many there are.
    local function MakeSub()
        local s = CreateFrame("Frame", nil, ui.petList)
        s:SetSize(CART_W, SUB_H)
        s.text = Style.Text(s, 12, "secondary", nil, true)
        s.text:SetPoint("BOTTOMLEFT", 2, 4)
        s.count = Style.Text(s, 11, "muted")
        s.count:SetPoint("BOTTOMRIGHT", -2, 4)
        s.count:SetJustifyH("RIGHT")
        return s
    end

    -- A pet ability: its icon, name and rank on one line, what it's waiting
    -- on where its heading doesn't say, and Skip.
    local function MakePet()
        local r = CreateFrame("Frame", nil, ui.petList)
        r:SetSize(CART_W, PET_H)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(18, 18)
        r.icon:SetPoint("LEFT", 2, 0)
        r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.name = Style.Text(r, 12, "text")
        r.name:SetPoint("LEFT", 28, 0)
        r.rank = Style.Text(r, 11, "muted")
        r.rank:SetPoint("LEFT", r.name, "RIGHT", 8, 0)
        r.skip = Link(r, SKIP_W)
        r.skip:SetPoint("RIGHT", -2, 0)
        r.state = Style.Text(r, 11, "muted")
        r.state:SetPoint("RIGHT", -(SKIP_W + 8), 0)
        r.state:SetJustifyH("RIGHT")
        r:EnableMouse(true)
        Tooltip(r)
        Style.Hover(r, 4)
        return r
    end

    -- A weapon skill: its icon and name, its price or state, and a Skip
    -- button for one not learned yet.
    local function MakeWeapon()
        local r = CreateFrame("Frame", nil, road)
        r:SetSize(roadW - 8, ROW_H)
        Style.Rule(r, "BOTTOM", "line")
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(18, 18)
        r.icon:SetPoint("LEFT", 4, 0)
        r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.name = Style.Text(r, 12, "text")
        r.name:SetPoint("LEFT", 32, 0)
        r.skip = Link(r, SKIP_W)
        r.skip:SetPoint("RIGHT", -4, 0)
        r.state = Style.Text(r, 12, "text", nil, true)
        r.state:SetPoint("RIGHT", -(SKIP_W + 12), 0)
        r.state:SetJustifyH("RIGHT")
        r:EnableMouse(true)
        Tooltip(r)
        Style.Hover(r, 4)
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

    -- A visit's cost in words: the sum of what isn't skipped or free, "?"
    -- where a price hasn't been seen, nothing where there's nothing to pay.
    -- `round`: to the silver, for a visit far enough off that copper is
    -- only three more things to read.
    local function StopCost(spells, round)
        local sum, missing = 0, false
        for _, spell in ipairs(spells) do
            if not spell.skipped and not Free(spell) then
                if spell.cost then sum = sum + spell.cost else missing = true end
            end
        end
        if round and sum >= 100 then sum = sum - sum % 100 end
        return sum > 0 and Compat.Money(sum) or (missing and "|cff9a9688?|r" or "")
    end

    -- The weapon skills, from y down the road's list: ones to learn first,
    -- then skipped ones, then the ones you know. Returns where they end.
    function ui.PaintWeapons(data, y)
        local head = Take("heads", MakeHead)
        head:ClearAllPoints()
        head:SetPoint("TOPLEFT", 0, -y)
        head.title:SetText("WEAPON SKILLS")
        head.note:SetText("any weapon master, same price")
        y = y + 22
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
        return y
    end

    -- A hunter's pet, under the sums: each ability's next rank under a
    -- heading for how it's got. The ones waiting on your pet's level are
    -- headed by that level, so it's said once and not on every row.
    function ui.PaintPet(pet)
        ui.petHead:SetShown(pet ~= nil)
        ui.petScroll:SetShown(pet ~= nil)
        if not pet then return end
        ui.petHead:ClearAllPoints()
        ui.petHead:SetPoint("TOPLEFT", 0, -ui.petTop)
        ui.petScroll:ClearAllPoints()
        ui.petScroll:SetPoint("TOPLEFT", 0, -(ui.petTop + 22))
        ui.petScroll:SetHeight(math.max(PET_H, height - top - ui.petTop - 22))
        local y = 0
        if pet.none then
            ui.petHead.note:SetText("")
            local r = Take("pets", MakePet)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 0, -(y + 4))
            r.spellID, r.hint = nil, nil
            r.icon:SetTexture(select(2, Compat.SpellInfo(883)))
            r.name:SetText("Call your pet to see what it can learn")
            r.rank:SetText("")
            r.state:SetText("")
            SkipButton(r, nil)
            r:SetAlpha(1)
            y = y + 4 + PET_H
        else
            local note = ("%s, a level %d %s"):format(pet.name or "Your pet", pet.level or 0, (pet.family or "pet"):lower())
            if pet.free then note = note .. ("  ·  %d TP free"):format(pet.free) end
            ui.petHead.note:SetText(note)
            local groups = {}
            for _, group in ipairs(PET_GROUPS) do
                if group[1] == "level" then
                    local by, order = {}, {}
                    for _, row in ipairs(pet.rows) do
                        if row.state == "level" then
                            local need = row.spell.level
                            if not by[need] then
                                by[need] = {}
                                order[#order + 1] = need
                            end
                            table.insert(by[need], row)
                        end
                    end
                    table.sort(order)
                    for _, need in ipairs(order) do groups[#groups + 1] = { "Waiting on pet level " .. need, by[need] } end
                else
                    local rows = {}
                    for _, row in ipairs(pet.rows) do
                        if row.state == group[1] then rows[#rows + 1] = row end
                    end
                    if #rows > 0 then groups[#groups + 1] = { group[2], rows } end
                end
            end
            for _, group in ipairs(groups) do
                local s = Take("subs", MakeSub)
                s:ClearAllPoints()
                s:SetPoint("TOPLEFT", 0, -y)
                s.text:SetText(group[1])
                s.count:SetText(#group[2] == 1 and "1 ability" or (#group[2] .. " abilities"))
                y = y + SUB_H
                for _, row in ipairs(group[2]) do
                    local r = Take("pets", MakePet)
                    r:ClearAllPoints()
                    r:SetPoint("TOPLEFT", 0, -y)
                    r.spellID = row.spell.pet
                    r.icon:SetTexture(row.icon)
                    r.name:SetText(row.name)
                    local rank = row.spell.rank > 0 and ("Rank " .. row.spell.rank) or ""
                    -- The heading says how it's got; the row adds only what
                    -- that doesn't: to teach it now, or the level your pet
                    -- still needs.
                    local state, color = "", "muted"
                    if row.state == "known" then
                        r.hint = nil
                    elseif row.state == "ready" then
                        if row.points then rank = rank .. (rank ~= "" and "  ·  " or "") .. row.points .. " TP" end
                        state, color = "Teach now", "green"
                        r.hint = "Teach it from your Beast Training."
                    elseif row.state == "level" then
                        r.hint = "In your Beast Training. Your pet needs level " .. row.spell.level .. "."
                    else
                        if (pet.level or 0) < row.spell.level then state = "Pet level " .. row.spell.level end
                        if row.state == "trainer" then
                            r.hint = "Buy it from a pet trainer, then teach it from your Beast Training."
                        elseif row.state == "tame" then
                            r.hint = "Not in your Beast Training yet: tame a beast that has it, and you learn it."
                        else
                            r.hint = "Open Beast Training once so jsal.ui can see what's in it."
                        end
                    end
                    if row.skipped then state, color = "Skipped", "muted" end
                    r.rank:SetText(rank)
                    r.state:SetText(state)
                    r.state:SetTextColor(Style.Color(color))
                    SkipButton(r, row.state ~= "known" and row.spell.pet or nil, row.skipped)
                    r:SetAlpha((row.state == "known" or row.skipped) and 0.6 or 1)
                    y = y + PET_H
                end
            end
        end
        ui.petList:SetHeight(math.max(1, y))
        ui.petScroll:UpdateScrollChildRect()
        ui.petScroll:Place()
    end

    Paint = function()
        local data = Training.Read()
        if not data then
            ui.cartHead.note:SetText("")
            ui.title:SetText("No spell list for this class yet")
            ui.gold:SetText("")
            ui.fold:Hide()
            ui.empty:SetText("There's no spell list for this class yet.")
            ui.empty:Show()
            return
        end
        local level = UnitLevel("player")
        local money = GetMoney()

        -- Sort: ready now (not known, level reached), and the stops ahead.
        local now, ahead, cost, unknown, rest, restUnknown = {}, {}, 0, 0, 0, 0
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
                if not spell.skipped and not Free(spell) then
                    if spell.cost then rest = rest + spell.cost else restUnknown = restUnknown + 1 end
                end
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

        -- What's ready, then the skipped ones folded away.
        local active, skipped = {}, {}
        for _, spell in ipairs(now) do
            local to = spell.skipped and skipped or active
            to[#to + 1] = spell
        end
        ui.cartHead.note:SetText("level " .. level)
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
            ui.title:SetText(table.concat(ready, " and ") .. " ready"
                .. (cost > 0 and (" for |cffe3b04b" .. Compat.Money(cost) .. "|r") or ""))
        else
            ui.title:SetText("Nothing to train right now")
        end
        -- Whether your gold covers it, said once and in a colour, where it
        -- was a bar to read against two numbers.
        local short = money < cost
        if cost > 0 then
            ui.gold:SetText(("You have %s:  %s"):format(Compat.Money(money), short
                and (Style.Tint("red") .. "short by " .. Compat.Money(cost - money) .. "|r")
                or (Style.Tint("green") .. "enough, with " .. Compat.Money(money - cost) .. " left|r")))
        else
            ui.gold:SetText("You have " .. Compat.Money(money))
        end
        local at, shown = 0, 0
        local function Put(spell)
            shown = shown + 1
            local c = made.cards[shown] or Card()
            made.cards[shown] = c
            c.spellID = spell.id
            c.icon:SetTexture(spell.icon)
            c.name:SetWidth(0)
            c.name:SetText(spell.name)
            local fresh = New(spell)
            if Wide(c.name, 0) > CART_W - 40 - SKIP_W - 70 - (fresh and 40 or 0) then c.name:SetWidth(CART_W - 40 - SKIP_W - 70 - (fresh and 40 or 0)) end
            c.new:SetShown(fresh)
            -- A new ability says so in its tag; a higher rank says which.
            local detail = not fresh and spell.rank or nil
            if spell.source == "demon" then detail = spell.group .. " · Grimoire" .. (detail and (" · " .. detail) or "")
            elseif spell.group then detail = spell.group .. (detail and (" · " .. detail) or "")
            elseif spell.via then detail = VIA[spell.via].card .. (detail and (" · " .. detail) or "") end
            c:SetDetail(detail)
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
        ui.fold:SetShown(#skipped > 0)
        if #skipped > 0 then
            local names = {}
            for _, spell in ipairs(skipped) do names[#names + 1] = spell.name end
            ui.fold.sign:SetText(showSkipped and "-" or "+")
            ui.fold.text:SetText(("|cffc4bfb0%d skipped|r  %s"):format(#skipped, table.concat(names, ", ")))
            ui.fold:ClearAllPoints()
            ui.fold:SetPoint("TOPLEFT", 0, -at)
            at = at + FOLD_H
            if showSkipped then
                for _, spell in ipairs(skipped) do Put(spell) end
            end
        end
        for i = shown + 1, #made.cards do made.cards[i]:Hide() end
        ui.empty:SetShown(#now == 0)
        ui.empty:SetText("Nothing to train right now. The road on the right shows what's next.")
        ui.cardList:SetHeight(math.max(1, at))
        -- The list is as tall as what's in it, and the sums sit right under
        -- it. With a pet's list to fit under those, it has half the room at
        -- most, and scrolls past that.
        local room = height - top - LIST_TOP - 10 - TOTALS_H - 26
        local listH = math.max(1, math.min(math.max(at, #now == 0 and 44 or 0), pet and math.floor(room / 2) or room))
        ui.cardScroll:SetHeight(listH)
        ui.totals:ClearAllPoints()
        ui.totals:SetPoint("TOPLEFT", 0, -(LIST_TOP + listH + 10))
        ui.petTop = LIST_TOP + listH + 10 + TOTALS_H + 26 + 14
        ui.cardScroll:UpdateScrollChildRect()
        ui.cardScroll:Place()

        -- The sums.
        ui.visitCost:SetText(cost > 0 and Compat.Money(cost) or (unknown > 0 and "?" or "Nothing"))
        ui.haveText:SetText(Compat.Money(money))
        ui.spareLabel:SetText(short and "Short by" or "Left after")
        ui.spareText:SetText(Compat.Money(math.abs(money - cost)))
        ui.spareText:SetTextColor(Style.Color(short and "red" or "green"))
        ui.spareLabel:SetShown(cost > 0)
        ui.spareText:SetShown(cost > 0)
        -- "from": some prices on the way haven't been seen at a trainer.
        ui.restText:SetText(rest > 0 and ((restUnknown > 0 and "from " or "") .. Compat.Money(rest)) or "?")
        ui.priceNote:SetText(data.haveTrainer
            and (unknown > 0 and ("%d price%s not seen at a trainer yet."):format(unknown, unknown == 1 and "" or "s") or "")
            or "Prices fill in the first time you open a class trainer.")

        -- The road: the next visit spelled out, a line for each one after.
        used = {}
        local y = 0
        -- What a hunter's pet can learn by each stop: the next rank of each
        -- ability, at the stop your pet's level reaches what it needs.
        local petAt = {}
        for _, row in ipairs(pet and pet.rows or {}) do
            local stop = Stop(row.spell.level)
            if row.state ~= "known" and row.state ~= "ready" and not row.skipped
                and row.spell.level > (pet.level or 0) and stop > level then
                petAt[stop] = petAt[stop] or {}
                table.insert(petAt[stop], { id = row.spell.pet, name = row.name, icon = row.icon, level = row.spell.level,
                                            number = row.spell.rank, group = "Your pet", source = "beast" })
                ahead[stop] = ahead[stop] or {}
            end
        end
        local levels = {}
        for stop in pairs(ahead) do levels[#levels + 1] = stop end
        table.sort(levels)
        ui.nextCard:SetShown(#levels > 0)
        -- The road's line, from under the next visit's card to the last mark.
        local lineFrom, lineTo
        for i, stop in ipairs(levels) do
            local list, mine = ahead[stop], petAt[stop]
            if i == 1 then
                ui.nextCard:ClearAllPoints()
                ui.nextCard:SetPoint("TOPLEFT", 0, -y)
                ui.nextCard:SetHeight(34 + #list * STEP_H + 6 + (mine and 22 or 0))
                ui.nextPet:SetShown(mine ~= nil)
                ui.nextPetText:SetShown(mine ~= nil)
                if mine then
                    ui.nextPet:ClearAllPoints()
                    ui.nextPet:SetPoint("TOPLEFT", NAME_X, -(34 + #list * STEP_H + 4))
                    local names = {}
                    for k, a in ipairs(mine) do names[k] = a.name .. (a.number > 1 and (" " .. a.number) or "") end
                    ui.nextPetText:SetText(table.concat(names, ", "))
                end
                ui.nextLevel:SetText(stop)
                ui.nextCost:SetText(StopCost(list))
                y = y + 34
                for _, spell in ipairs(list) do
                    local r = Take("steps", MakeStep)
                    r.spell, r.spellID, r.hint = spell, spell.id, Hint(spell)
                    r.icon:SetTexture(spell.icon)
                    r.icon:SetDesaturated(spell.skipped)
                    r.name:SetText(spell.name)
                    local fresh = New(spell)
                    r.name:SetTextColor(Style.Color(fresh and "text" or "secondary"))
                    r.new:SetShown(fresh)
                    r.rank:SetText(not fresh and spell.rank or "")
                    r.cost:SetText(spell.skipped and "skipped" or (Free(spell) and VIA[spell.via].tag or (Price(spell) or "?")))
                    r:SetAlpha(spell.skipped and 0.4 or 1)
                    r:ClearAllPoints()
                    r:SetPoint("TOPLEFT", 0, -y)
                    y = y + STEP_H
                end
                y = y + 6 + 6 + (mine and 22 or 0)
            else
                local s = Take("stops", MakeStop)
                local roomW = roadW - 8 - NAME_X - COST_W - 8
                -- A stop your pet alone has something at has no row of spells.
                local h, fresh = 8, false
                if #list > 0 then
                    local tall
                    tall, fresh = Glyphs(list, NAME_X, y + h, roomW)
                    h = h + tall + GLYPH_GAP
                end
                s.pet:SetShown(mine ~= nil)
                if mine then
                    -- Your pet's, after a tag that says whose they are.
                    s.pet:ClearAllPoints()
                    s.pet:SetPoint("LEFT", s, "TOPLEFT", NAME_X, -(h + GLYPH / 2))
                    h = h + Glyphs(mine, NAME_X + s.pet.wide + 8, y + h, roomW - s.pet.wide - 8) + GLYPH_GAP
                end
                h = h + 6
                s:ClearAllPoints()
                s:SetPoint("TOPLEFT", 0, -y)
                s:SetSize(roadW - 8, h)
                -- Gold where the visit teaches something new to you.
                s.node:SetColorTexture(Style.Color(fresh and "gold" or "lineStrong"))
                s.level:SetText(stop)
                s.level:SetTextColor(Style.Color(fresh and "text" or "secondary"))
                s.cost:SetText(StopCost(list, true))
                lineFrom = lineFrom or y
                lineTo = y + 8 + GLYPH / 2
                y = y + h
            end
        end
        ui.roadLine:SetShown(lineFrom ~= nil)
        if lineFrom then
            ui.roadLine:ClearAllPoints()
            ui.roadLine:SetPoint("TOPLEFT", LINE_X, -(lineFrom - 6))
            ui.roadLine:SetHeight(lineTo - lineFrom + 6)
        end
        ui.roadEmpty:SetShown(#levels == 0)
        if #levels == 0 then y = 34 end
        y = ui.PaintWeapons(data, y + 18)
        ui.road:SetHeight(math.max(1, y))
        ui.roadScroll:UpdateScrollChildRect()
        ui.roadScroll:Place()
        ui.PaintPet(pet)
        for _, pool in ipairs({ "stops", "steps", "glyphs", "heads", "weapons", "subs", "pets" }) do
            local list = made[pool]
            for i = (used[pool] or 0) + 1, #list do list[i]:Hide() end
        end
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
