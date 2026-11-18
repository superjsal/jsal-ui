-- The Training Planner page. At the top, one line of what's ready and what
-- it costs, and one of whether your gold covers it. Under that, two cards
-- side by side: what you can train now, a line for each spell with its price
-- and Skip, the visit's sum along the card's foot; and a hunter's pet, its
-- abilities as pictures under a heading for how each is got, with the
-- weapon skills under it. Across the bottom, the road to 60, drawn as a
-- road: you at its start, a round sign for each trainer visit, and under
-- each sign what the visit costs and teaches, a picture a spell. Words are
-- for what you act on now; what's ahead is pictures, named when pointed at.
local _, ns = ...
local Style, Compat, Window, Training = ns.Style, ns.Compat, ns.Window, ns.Training

local LEFT_W, GAP = 496, 24      -- the card of what to train now; the pet and weapon skills have the rest
local UP_MIN = 330                -- the two cards' room, over the road: more when a visit of many spells needs it
local HEAD_H = 26                 -- a section's heading, down to what's under it
local ROW_W = LEFT_W - 2          -- a row inside the card's line
local VISIT_H, DENSE_H, FOLD_H, STRIP_H = 60, 44, 34, 38   -- a spell to train now, roomy and compact; the line that folds the skipped ones away; the sums
-- How the spells to train now are laid out, the roomiest that fits first:
-- a row each, a compact row each, then compact and two across.
local LAYOUTS = { { key = "roomy", high = VISIT_H, across = 1 }, { key = "dense", high = DENSE_H, across = 1 }, { key = "pair", high = DENSE_H, across = 2 } }
local SKIP_W = 40
local GLYPH, GLYPH_GAP = 28, 3    -- a spell as its picture, and the room between two
local ACROSS = 4                  -- pictures across under a sign on the road
local GLYPHS_W = GLYPH * ACROSS + GLYPH_GAP * (ACROSS - 1)
local SUB_H = 20                  -- a heading inside the pet's card
-- The road: six visits across the page, the rest a turn of the wheel away.
-- A sign every PITCH, the first FIRST_X along; each has STOP_W for
-- what's under it. The band is the road itself; you stand YOU_X along it.
local PITCH, STOP_W, FIRST_X, YOU_X = 160, 152, 56, 30
local SIGN, BAND_H = 40, 26

-- A hunter's pet abilities, grouped by how each is got, in this order. One
-- that's ready to teach isn't here: it's among what to train now.
local PET_GROUPS = {
    { "points", "Not enough training points" },
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

-- A section's heading: a title in gold and a note at the right. `ruled`: a
-- line under it, for one with no column headings of its own.
local function Section(parent, width, ruled)
    local s = CreateFrame("Frame", nil, parent)
    s:SetSize(width, 20)
    s.title = Style.Text(s, 12, "gold", nil, true)
    s.title:SetPoint("LEFT")
    -- The note has the room right of the title and no more: one too long
    -- for it is cut short, never drawn over the title.
    s.note = Style.Text(s, 11, "muted")
    s.note:SetPoint("RIGHT")
    s.note:SetPoint("LEFT", s.title, "RIGHT", 10, 0)
    s.note:SetJustifyH("RIGHT")
    s.note:SetWordWrap(false)
    if ruled then Style.Rule(s, "BOTTOM", "lineStrong") end
    return s
end

local function Tooltip(frame)
    frame:SetScript("OnEnter", function(self)
        if not self.spellID then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetSpellByID(self.spellID)
        if self.hint then GameTooltip:AddLine(self.hint, 0.6, 0.59, 0.53, true) end
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
    local width, height = Window.fullWidth, Window.contentHeight
    local sideX, sideW = LEFT_W + GAP, width - LEFT_W - GAP - 8
    local top = 88
    -- The page's height under its top lines, less the gap over the road, the
    -- road's heading and the line that explains its marks: what the cards
    -- and the road share. The road has what its tallest stop needs, at most
    -- what leaves the cards their least.
    local shared = height - top - 24 - 30 - 22
    local Paint
    -- What the page is made of, in one table: Paint uses so much from outside
    -- itself that it was at the edge of what the game's Lua allows one
    -- function (limits_test.lua).
    local ui = {}

    -- The top: how many spells are ready and what they cost, whether your
    -- gold covers it, your nearest class trainer, and a pin on the map.
    ui.title = Style.Text(page, 23, "text", nil, true)
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
    -- At the left: what to train now, a card.
    ---------------------------------------------------------------------------
    local cart = CreateFrame("Frame", nil, page)
    cart:SetPoint("TOPLEFT", 0, -top)
    cart:SetSize(LEFT_W, UP_MIN)
    ui.cartHead = Section(cart, LEFT_W)
    ui.cartHead:SetPoint("TOPLEFT")
    ui.cartHead.title:SetText("TRAIN NOW")
    -- The card is as tall as what's in it (Paint sizes it): the spells, then a
    -- strip along its bottom with the visit's sum and what's left after.
    local box = CreateFrame("Frame", nil, cart)
    box:SetPoint("TOPLEFT", 0, -HEAD_H)
    box:SetWidth(LEFT_W)
    Style.Box(box, 6, "well", "cardLine")
    ui.cartBox = box
    ui.cardScroll, ui.cardList = Style.Scroller(box, ROW_W, VISIT_H, ROW_W, -4)
    ui.cardScroll:SetPoint("TOPLEFT", 1, -1)
    ui.empty = Style.Text(ui.cardList, 13, "muted")
    ui.empty:SetPoint("TOPLEFT", 16, -22)
    ui.empty:SetWidth(ROW_W - 32)
    local strip = CreateFrame("Frame", nil, box)
    strip:SetPoint("BOTTOMLEFT", 1, 1)
    strip:SetPoint("BOTTOMRIGHT", -1, 1)
    strip:SetHeight(STRIP_H)
    Style.Cap(strip, 5, "titleBar", "BOTTOM")
    Style.Rule(strip, "TOP", "cardLine")
    local visitLabel = Style.Text(strip, 12, "muted")
    visitLabel:SetPoint("LEFT", 16, 0)
    visitLabel:SetText("This visit")
    ui.visitCost = Style.Text(strip, 14, "gold", nil, true)
    ui.visitCost:SetPoint("LEFT", visitLabel, "RIGHT", 10, 0)
    ui.spareText = Style.Text(strip, 13, "green", nil, true)
    ui.spareText:SetPoint("RIGHT", -16, 0)
    ui.spareText:SetJustifyH("RIGHT")
    ui.spareLabel = Style.Text(strip, 12, "muted")
    ui.spareLabel:SetPoint("RIGHT", ui.spareText, "LEFT", -10, 0)
    ui.spareLabel:SetJustifyH("RIGHT")
    ui.priceNote = Style.Text(cart, 11, "muted")
    ui.priceNote:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 2, -6)
    ui.priceNote:SetWidth(LEFT_W - 4)
    ui.priceNote:SetWordWrap(false)

    -- The rows and marks this page has made and reuses, by kind.
    local made = { cards = {}, stops = {}, glyphs = {}, tiles = {}, subs = {} }
    -- A spell to train now: its icon, name and rank, its price, and Skip. A
    -- right-click skips it too, which is the only way where the rows are two
    -- across and have no room for the word.
    local function Card()
        local c = CreateFrame("Button", nil, ui.cardList)
        c:RegisterForClicks("RightButtonUp")
        Style.Rule(c, "BOTTOM", "line")
        c.icon = c:CreateTexture(nil, "ARTWORK")
        c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        c.name = Style.Text(c, 14, "text", nil, true)
        c.name:SetWordWrap(false)
        c.new = Style.Tag(c, "new", true, true)
        c.new:SetPoint("LEFT", c.name, "RIGHT", 8, 0)
        c.sub = Style.Text(c, 12, "muted")
        c.sub:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -3)
        c.sub:SetWordWrap(false)
        c.skip = Link(c, SKIP_W)
        c.skip:SetPoint("RIGHT", -16, 0)
        c.cost = Style.Text(c, 14, "text", nil, true)
        c.cost:SetJustifyH("RIGHT")
        -- Sized for its layout; returns the room its name has.
        function c:Lay(layout)
            local pair = layout.across == 2
            local icon, pad = layout.high == VISIT_H and 36 or 28, pair and 12 or 16
            self.pad = pad + icon + (pair and 10 or 14)
            self:SetSize(ROW_W / layout.across, layout.high)
            self.icon:SetSize(icon, icon)
            self.icon:ClearAllPoints()
            self.icon:SetPoint("LEFT", pad, 0)
            self.skip:SetShown(not pair)
            self.cost:ClearAllPoints()
            self.cost:SetPoint("RIGHT", pair and -12 or -(16 + SKIP_W + 14), 0)
            local room = ROW_W / layout.across - self.pad - (pair and 12 + 66 or 16 + SKIP_W + 14 + 90)
            self.sub:SetWidth(room)
            return room
        end
        -- With no line under it, the name sits in the middle of the row.
        function c:SetDetail(text)
            self.sub:SetText(text or "")
            self.name:ClearAllPoints()
            if text and text ~= "" then
                self.name:SetPoint("BOTTOMLEFT", self, "LEFT", self.pad, 1)
            else
                self.name:SetPoint("LEFT", self.pad, 0)
            end
        end
        Tooltip(c)
        return c
    end

    -- Spells you've skipped fold into one line under the list; a click
    -- opens it to show them, each with Unskip.
    local showSkipped = false
    local fold = CreateFrame("Button", nil, ui.cardList)
    fold:SetSize(ROW_W, FOLD_H)
    fold.sign = Style.Text(fold, 14, "gold", nil, true)
    fold.sign:SetPoint("LEFT", 18, 0)
    fold.text = Style.Text(fold, 12, "muted")
    fold.text:SetPoint("LEFT", 36, 0)
    fold.text:SetWidth(ROW_W - 52)
    fold.text:SetWordWrap(false)
    fold:SetScript("OnClick", function()
        showSkipped = not showSkipped
        Paint()
    end)
    Style.Hover(fold)
    ui.fold = fold

    ---------------------------------------------------------------------------
    -- At the right: a hunter's pet, what it can learn as a picture each under
    -- a heading for how it's got; and under it the weapon skills. One list,
    -- that scrolls when the two run past the room they have.
    ---------------------------------------------------------------------------
    ui.sideScroll, ui.petList = Style.Scroller(page, sideW, UP_MIN, nil, 6)
    ui.sideScroll:SetPoint("TOPLEFT", sideX, -top)
    ui.petHead = Section(ui.petList, sideW)
    ui.petHead.title:SetText("YOUR PET")
    ui.petHead:Hide()
    ui.petBox = CreateFrame("Frame", nil, ui.petList)
    ui.petBox:SetWidth(sideW)
    Style.Box(ui.petBox, 6, "well", "cardLine")
    ui.petBox:Hide()
    ui.petNone = Style.Text(ui.petBox, 13, "muted")
    ui.petNone:SetPoint("TOPLEFT", 16, -14)
    ui.petNone:SetText("Call your pet to see what it can learn.")
    ui.weaponHead = Section(ui.petList, sideW)
    ui.weaponHead.title:SetText("WEAPON SKILLS")
    ui.weaponBox = CreateFrame("Frame", nil, ui.petList)
    ui.weaponBox:SetWidth(sideW)
    Style.Box(ui.weaponBox, 6, "well", "cardLine")
    ui.weaponSum = Style.Text(ui.weaponBox, 12, "muted")

    ---------------------------------------------------------------------------
    -- Across the bottom: the road to 60. A road, you at
    -- its start, and a round sign for each trainer visit with what it
    -- teaches under it. With more visits than fit across, the mouse wheel
    -- moves along it.
    ---------------------------------------------------------------------------
    ui.roadHead = Section(page, width)
    ui.roadHead.title:SetText("YOUR ROAD TO 60")
    ui.roadScroll = CreateFrame("ScrollFrame", nil, page)
    ui.roadScroll:SetSize(width, shared - UP_MIN)
    local road = CreateFrame("Frame", nil, ui.roadScroll)
    road:SetSize(width, shared - UP_MIN)
    ui.roadScroll:SetScrollChild(road)
    ui.road, ui.roadMost = road, 0
    ui.roadEmpty = Style.Text(road, 13, "muted")
    ui.roadEmpty:SetPoint("TOPLEFT", 2, -10)
    ui.roadEmpty:SetText("Nothing left to learn on the way to 60.")
    local band = CreateFrame("Frame", nil, road)
    band:SetPoint("TOPLEFT", 0, -(SIGN - BAND_H) / 2)
    band:SetSize(width, BAND_H)
    Style.Box(band, 13, "titleBar", "lineStrong")
    ui.band = band
    -- Where you are: the road's start in dim gold, filling toward your next visit's sign as you
    -- level, with a gold mark riding at its end. It stood still, the same length at any XP
    -- (John, 17 Nov 2026: "does this gold not grow? it looks like it should"; he picked the
    -- mark riding at its end from two mockups). "YOU" stays under the road's start.
    local done = CreateFrame("Frame", nil, band)
    done:SetPoint("TOPLEFT", 1, -1)
    done:SetSize(FIRST_X - 6, BAND_H - 2)
    Style.Cap(done, 12, "needFill", "LEFT")
    -- The mark has a layer of its own over the gold, so it shows when there's no gold yet.
    local markLayer = CreateFrame("Frame", nil, band)
    markLayer:SetAllPoints()
    markLayer:SetFrameLevel((done:GetFrameLevel() or 0) + 1)
    local you = markLayer:CreateTexture(nil, "ARTWORK")
    you:SetColorTexture(Style.Color("gold"))
    you:SetSize(12, 12)
    you:SetPoint("CENTER", band, "LEFT", YOU_X, 0)
    you:SetRotation(math.rad(45))
    -- The road is one you travel along, as the Professions page's (John, 17 Nov 2026, of that one:
    -- "A1, a stop apart", then the Training road "the same"): the visit behind you is its first
    -- sign, dimmed, and you move along toward the next as your XP fills, the gold behind you and
    -- your level under you. Between the two: your level and XP between their levels, clear of
    -- both signs. With no visit behind you yet, the road starts at your level.
    -- Earlier it started at you and counted from your level alone; before that from the visit
    -- before, with the road's start meaning you, and 39 at 23% looked most of the way to 40.
    local MIN_FILL = 12
    local function Middle(i) return FIRST_X + (i - 1) * PITCH + STOP_W / 2 end
    function ui.Along(level, xp, most, back, nextStop)
        if not nextStop then return 0 end
        local from = back or level
        local at = level + ((most or 0) > 0 and math.min(1, (xp or 0) / most) or 0)
        return math.max(0, math.min(1, (at - from) / math.max(1, nextStop - from)))
    end
    function ui.PaintYou()
        local level = UnitLevel("player") or 1
        local behind, nextStop = ui.roadBehind, ui.roadNext
        local along = ui.Along(level, UnitXP and UnitXP("player") or 0, UnitXPMax and UnitXPMax("player") or 0, behind, nextStop)
        local backX = behind and (Middle(1) + SIGN / 2 + 10) or 10
        local aheadX = Middle(behind and 2 or 1) - SIGN / 2 - 10
        local reach = backX + along * math.max(0, aheadX - backX)
        done:SetShown(reach >= MIN_FILL)
        done:SetWidth(math.max(MIN_FILL, reach - 1))
        you:ClearAllPoints()
        you:SetPoint("CENTER", band, "LEFT", math.max(10, reach), 0)
        ui.youText:ClearAllPoints()
        ui.youText:SetPoint("TOP", band, "BOTTOMLEFT", math.max(YOU_X, reach), -8)
    end
    ui.youText = Style.Text(road, 10, "gold", nil, true)
    ui.youText:SetPoint("TOP", band, "BOTTOMLEFT", YOU_X, -8)
    ui.youText:SetJustifyH("CENTER")
    -- A thin bar under the road shows where along it you're looking.
    local thumb = page:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(Style.Color("thumb"))
    thumb:SetHeight(3)
    thumb:Hide()
    function ui.PlaceRoad()
        local most = ui.roadMost
        local at = math.max(0, math.min(most, ui.roadScroll:GetHorizontalScroll() or 0))
        ui.roadScroll:SetHorizontalScroll(at)
        thumb:SetShown(most > 0)
        if most > 0 then
            local size = math.max(40, width * width / (width + most))
            thumb:SetWidth(size)
            thumb:ClearAllPoints()
            thumb:SetPoint("TOPLEFT", ui.roadScroll, "BOTTOMLEFT", (width - size) * at / most, -2)
        end
    end
    ui.roadScroll:EnableMouseWheel(true)
    ui.roadScroll:SetScript("OnMouseWheel", function(self, delta)
        self:SetHorizontalScroll((self:GetHorizontalScroll() or 0) - delta * PITCH)
        ui.PlaceRoad()
        ui.PaintRoad()
    end)
    ui.legend = Style.Text(page, 11, "muted")
    ui.legend:SetPoint("BOTTOMLEFT", 0, 0)
    ui.legend:SetWidth(width)
    ui.legend:SetJustifyH("LEFT")
    ui.legend:SetWordWrap(false)

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

    -- A right-click on a picture skips its spell, or puts it back. A click
    -- on one with a trainer to show (a weapon skill) pins that trainer on
    -- the map.
    local function SkipClick(self, button)
        if button == "LeftButton" then
            if self.pin and ns.Trainers then ns.Trainers.Pin(self.pin) end
        elseif self.spell then
            Training.Skip(self.spell.id, not self.spell.skipped)
            Paint()
        end
    end

    -- The nearest weapon master of your side who teaches a weapon skill.
    local function Master(id)
        local T, best, near = ns.Trainers, nil, nil
        if not (T and T.Friendly and T.Distance) then return nil end
        for _, master in ipairs(ns.TrainerData and ns.TrainerData.weapons or {}) do
            if T.Friendly(master) then
                for _, taught in ipairs(master.teaches or {}) do
                    if taught == id then
                        local far = T.Distance(master)
                        if not best or far < near then best, near = master, far end
                    end
                end
            end
        end
        return best
    end


    -- A visit: a round sign on the road with its level, and its cost under
    -- it. What it teaches is laid out under that by Glyphs. Pointing at the
    -- sign says how many spells it is and what they cost to the copper.
    local function MakeStop()
        local s = CreateFrame("Frame", nil, road)
        s:SetSize(STOP_W, SIGN + 30)
        -- Above the road's band: both are the road's children, and at one
        -- level the game may draw the band over the sign.
        s:SetFrameLevel(road:GetFrameLevel() + 3)
        s.sign = CreateFrame("Frame", nil, s)
        s.sign:SetSize(SIGN, SIGN)
        s.sign:SetPoint("TOP")
        s.disc = Style.Circle(s.sign, "well", "lineStrong")
        s.level = Style.Text(s.sign, 15, "text", nil, true)
        s.level:SetPoint("CENTER")
        s.level:SetJustifyH("CENTER")
        s.cost = Style.Text(s, 11, "text", nil, true)
        s.cost:SetPoint("TOP", 0, -(SIGN + 8))
        s.cost:SetJustifyH("CENTER")
        s.sign:EnableMouse(true)
        s.sign:SetScript("OnEnter", function(self)
            if not self.title then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(self.title)
            if self.line then GameTooltip:AddLine(self.line, 1, 1, 1) end
            GameTooltip:Show()
        end)
        s.sign:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return s
    end

    -- A spell as its picture, to take in at a glance: a gold frame round an
    -- ability new to you, a higher rank's number in its corner. Pointing at
    -- it names it; a right-click skips it.
    local function MakeGlyph(parent, size)
        local g = CreateFrame("Button", nil, parent)
        g:SetSize(size, size)
        g:SetFrameLevel(parent:GetFrameLevel() + 5)
        g:RegisterForClicks("LeftButtonUp", "RightButtonUp")
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
    -- The two kinds: one on the road, and one in the cards for a pet's
    -- abilities and the weapon skills.
    local KINDS = {
        glyphs = { size = GLYPH, gap = GLYPH_GAP, make = function() return MakeGlyph(road, GLYPH) end },
        tiles = { size = GLYPH, gap = GLYPH_GAP, make = function() return MakeGlyph(ui.petList, GLYPH) end },
    }

    -- Lays spells out as pictures of one kind from (x0, y0), wrapping at
    -- maxW, the abilities new to you first; returns how tall they came to.
    -- A spell's rank is its `number`, or read from its rank's words; it's
    -- new to you at rank 1, unless its `fresh` says otherwise. One with a
    -- `hint` of its own shows that in its tooltip; a `fixed` one can't be
    -- skipped; a `dim` one is something you can't get yet; one with a `pin`
    -- shows that trainer on the map when clicked.
    local function Glyphs(spells, x0, y0, maxW, pool)
        local kind, list = KINDS[pool], {}
        for k, spell in ipairs(spells) do
            local rank = spell.number or RankNumber(spell.rank) or 1
            local fresh = rank <= 1
            if spell.fresh ~= nil then fresh = spell.fresh end
            list[k] = { spell = spell, rank = rank, fresh = fresh, at = k }
        end
        table.sort(list, function(a, b)
            if a.fresh ~= b.fresh then return a.fresh end
            return a.at < b.at
        end)
        local x, y = 0, 0
        for _, e in ipairs(list) do
            local g, spell = Take(pool, kind.make), e.spell
            g.spell, g.spellID, g.hint = not spell.fixed and spell or nil, spell.id, spell.hint or Hint(spell)
            g.pin = spell.pin
            g.icon:SetTexture(spell.icon)
            g.icon:SetDesaturated(spell.skipped and true or false)
            g.frame:SetColorTexture(Style.Color(e.fresh and "gold" or "lineStrong"))
            local numbered = not e.fresh and e.rank > 1
            g.back:SetShown(numbered)
            -- Shown only with a number in it: an empty label was still a piece to lay out.
            g.rank:SetShown(numbered)
            g.rank:SetText(numbered and e.rank or "")
            if numbered then g.back:SetSize(e.rank > 9 and 16 or 11, 12) end
            if x > 0 and x + kind.size > maxW then
                x, y = 0, y + kind.size + kind.gap
            end
            g:ClearAllPoints()
            g:SetPoint("TOPLEFT", x0 + x, -(y0 + y))
            g:SetAlpha(spell.skipped and 0.4 or (spell.dim and 0.45 or 1))
            x = x + kind.size + kind.gap
        end
        return #list > 0 and (y + kind.size) or 0
    end

    -- A heading inside the pet's card: how the abilities under it are got,
    -- and how many there are.
    local function MakeSub()
        local s = CreateFrame("Frame", nil, ui.petBox)
        s:SetSize(sideW - 32, SUB_H)
        s.text = Style.Text(s, 10, "muted", nil, true)
        s.text:SetPoint("LEFT")
        s.count = Style.Text(s, 10, "secondary", nil, true)
        s.count:SetPoint("LEFT", s.text, "RIGHT", 6, 0)
        return s
    end

    -- A visit's cost in words: the sum of what isn't skipped or free, "?"
    -- where a price hasn't been seen, nothing where there's nothing to pay.
    -- `round`: to the silver, for under a sign on the road, where copper is
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

    -- What a pet ability's picture says when pointed at: how it's got, what
    -- it's waiting on, and that a right-click skips it.
    local function PetEntry(row, pet)
        local need, hint = row.spell.level, nil
        local low = (pet.level or 0) < need
        if row.state == "known" then
            hint = "Your pet knows it."
        elseif row.state == "ready" then
            hint = (row.points and (row.points .. " training points. ") or "") .. "Teach it from your Beast Training."
        elseif row.state == "points" then
            hint = ("Your pet has %d training points free and this takes %d: %d short."):format(pet.free or 0, row.points, row.short)
        elseif row.state == "level" then
            hint = "In your Beast Training. Your pet needs level " .. need .. "."
        elseif row.state == "trainer" then
            hint = "Buy it from a pet trainer, then teach it from your Beast Training." .. (low and (" Your pet needs level " .. need .. ".") or "")
        elseif row.state == "tame" then
            hint = "Not in your Beast Training yet: tame a beast that has it, and you learn it." .. (low and (" Your pet needs level " .. need .. ".") or "")
        else
            hint = "Open Beast Training once so jsal.ui can see what's in it."
        end
        local known = row.state == "known"
        if not known then hint = hint .. (row.skipped and " Skipped: right-click to put it back." or " Right-click to skip it.") end
        return { id = row.spell.pet, icon = row.icon, number = math.max(1, row.spell.rank or 1), fresh = not known and (row.spell.rank or 0) <= 1,
                 skipped = row.skipped, hint = hint, fixed = known, dim = known or (row.state ~= "ready" and low) }
    end

    -- The weapon skills, from y down the right column's list: a picture for
    -- each still to learn (a skipped one dimmed), and how many there are and
    -- what they cost. Pointing at one names the masters who teach it; a
    -- click pins the nearest. The ones you know are counted in the heading.
    -- Returns where they end.
    -- The road's visits in view, with one more either side. Every visit to 60 was drawn, about
    -- eleven at level 39 where six show: most of the page's 659 pieces (John, 17 Nov 2026,
    -- /jsal pieces).
    -- The wheel draws the next ones as they come into view; nothing is drawn again while the
    -- same visits are in view, unless `fresh` (the page painted).
    local roadDrawn
    function ui.PaintRoad(fresh)
        local levels, ahead = ui.roadLevels or {}, ui.roadAhead or {}
        local at = ui.roadScroll:GetHorizontalScroll() or 0
        local lo = math.max(1, math.floor((at - FIRST_X - STOP_W) / PITCH) + 1)
        local hi = math.min(#levels, math.floor((at + width - FIRST_X) / PITCH) + 2)
        local key = lo .. ":" .. hi
        if not fresh and key == roadDrawn then return end
        roadDrawn = key
        used.stops, used.glyphs = 0, 0
        for i = lo, hi do
            local stop = levels[i]
            local list = ahead[stop]
            local s = Take("stops", MakeStop)
            local x = FIRST_X + (i - 1) * PITCH
            s:ClearAllPoints()
            s:SetPoint("TOPLEFT", x, 0)
            local behind = ui.roadBehind ~= nil and i == 1
            local first, last = i == (ui.roadBehind and 2 or 1), stop >= 60
            -- Behind you, the sign stays solid over the gold (faded, the gold showed through it);
            -- its line, number and cost are quieter, and its spells dimmed.
            s.disc:Paint(first and "gold" or "well", (first or last) and "gold" or (behind and "line" or "lineStrong"))
            s.level:SetText(stop)
            s.level:SetTextColor(Style.Color(first and "onGold" or (last and "gold" or (behind and "muted" or "text"))))
            s.cost:SetTextColor(Style.Color(behind and "muted" or "text"))
            s.cost:SetText(behind and "trained" or StopCost(list, true))
            local count = 0
            for _, spell in ipairs(list) do
                if not spell.skipped then count = count + 1 end
            end
            local exact = StopCost(list)
            s.sign.title = (first and "Your next visit: level " or (behind and "Your last visit: level " or "Level ")) .. stop
            s.sign.line = ("%d spell%s"):format(count, count == 1 and "" or "s") .. (exact ~= "" and (" for " .. exact) or "")
            Glyphs(list, x + (STOP_W - GLYPHS_W) / 2, SIGN + 8 + 16 + 8, GLYPHS_W, "glyphs")
        end
        for _, pool in ipairs({ "stops", "glyphs" }) do
            local list = made[pool]
            for i = (used[pool] or 0) + 1, #list do list[i]:Hide() end
        end
    end

    function ui.PaintWeapons(data, y)
        local list, known, n, sum, same, missing = {}, 0, 0, 0, nil, false
        local weapons = {}
        for _, w in ipairs(data.weapons) do
            if w.known then known = known + 1 else weapons[#weapons + 1] = w end
        end
        table.sort(weapons, function(a, b)
            if (a.skipped and true or false) ~= (b.skipped and true or false) then return not a.skipped end
            return a.name < b.name
        end)
        for k, w in ipairs(weapons) do
            local master = Master(w.id)
            list[k] = { id = w.id, icon = w.icon, skipped = w.skipped, fresh = false, pin = master,
                hint = (w.at and ("Taught by " .. w.at .. ".")
                    or "Each weapon master teaches only some weapons, and jsal.ui hasn't seen who teaches this one. Visit one and it remembers.")
                    .. (w.cost and (" " .. Compat.Money(w.cost) .. ".") or "")
                    .. (master and (" Click to show " .. master.name .. " on the map.") or "")
                    .. (w.skipped and " Skipped: right-click to put it back." or " Right-click to skip it.") }
            if not w.skipped then
                n = n + 1
                if w.cost then
                    sum = sum + w.cost
                    if same == nil then same = w.cost elseif same ~= w.cost then same = false end
                else
                    missing = true
                end
            end
        end
        ui.weaponHead:ClearAllPoints()
        ui.weaponHead:SetPoint("TOPLEFT", 0, -y)
        ui.weaponHead.note:SetText(known > 0 and (known .. " known") or "")
        y = y + HEAD_H
        ui.weaponBox:ClearAllPoints()
        ui.weaponBox:SetPoint("TOPLEFT", 0, -y)
        local tall = Glyphs(list, 16, y + 12, sideW - 32, "tiles")
        local words
        if #list == 0 then
            words = "Nothing left to learn from a weapon master."
        elseif n == 0 then
            words = "All skipped."
        else
            words = n .. " to learn"
            if same and not missing then
                words = words .. ",  |cffece6d6" .. Compat.Money(same) .. "|r each"
            elseif sum > 0 then
                words = words .. " for " .. (missing and "at least " or "") .. "|cffece6d6" .. Compat.Money(sum) .. "|r"
            end
        end
        ui.weaponSum:SetText(words)
        -- The words stand right of the pictures where one row of them leaves
        -- the room, and under them where it doesn't.
        local beside = tall == GLYPH and #list * (GLYPH + GLYPH_GAP) + 190 <= sideW - 32
        ui.weaponSum:ClearAllPoints()
        if tall == 0 then
            ui.weaponSum:SetPoint("TOPLEFT", 16, -14)
        elseif beside then
            ui.weaponSum:SetPoint("RIGHT", ui.weaponBox, "TOPRIGHT", -16, -(12 + GLYPH / 2))
        else
            ui.weaponSum:SetPoint("TOPLEFT", 16, -(12 + tall + 8))
        end
        local boxH = tall == 0 and 44 or (12 + tall + (beside and 12 or 34))
        ui.weaponBox:SetHeight(boxH)
        return y + boxH
    end

    -- A hunter's pet, at the top of the right column: a card with each
    -- ability's next rank as a picture, under a heading for how it's got.
    -- The ones waiting on your pet's level are headed by that level. Returns
    -- where it ends down the column's list: 0 with no pet.
    function ui.PaintPet(pet)
        ui.petHead:SetShown(pet ~= nil)
        ui.petBox:SetShown(pet ~= nil)
        if not pet then return 0 end
        ui.petHead:ClearAllPoints()
        ui.petHead:SetPoint("TOPLEFT", 0, 0)
        ui.petBox:ClearAllPoints()
        ui.petBox:SetPoint("TOPLEFT", 0, -HEAD_H)
        ui.petNone:SetShown(pet.none == true)
        local y = 10
        if pet.none then
            ui.petHead.note:SetText("")
            y = 44
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
                s:SetPoint("TOPLEFT", 16, -y)
                s.text:SetText(group[1]:upper())
                s.count:SetText(#group[2])
                y = y + SUB_H
                local list = {}
                for k, row in ipairs(group[2]) do list[k] = PetEntry(row, pet) end
                y = y + Glyphs(list, 16, HEAD_H + y, sideW - 32, "tiles") + 8
            end
            y = y + 4
        end
        ui.petBox:SetHeight(y)
        return HEAD_H + y
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
        -- The road is as tall as its tallest stop: the sign, the cost, and
        -- its pictures four across. The cards have the rest of the page.
        local levels, rows = {}, 2
        for stop, list in pairs(ahead) do
            levels[#levels + 1] = stop
            rows = math.max(rows, math.ceil(#list / ACROSS))
        end
        table.sort(levels)
        local behindStop
        for _, spell in ipairs(data.spells) do
            local stop = spell.known and Stop(spell.level)
            if stop and stop <= level and (not behindStop or stop > behindStop) then behindStop = stop end
        end
        ui.roadNext = levels[1]
        ui.roadBehind = (behindStop and levels[1]) and behindStop or nil
        if ui.roadBehind then
            local list = {}
            for _, spell in ipairs(data.spells) do
                if spell.known and Stop(spell.level) == behindStop then
                    list[#list + 1] = setmetatable({ dim = true, fixed = true, skipped = false, fresh = false }, { __index = spell })
                end
            end
            ahead[behindStop] = list
            table.insert(levels, 1, behindStop)
            rows = math.max(rows, math.ceil(#list / ACROSS))
        end
        local roadH = math.min(shared - UP_MIN, SIGN + 8 + 16 + 8 + rows * (GLYPH + GLYPH_GAP) + 6)
        -- The spells to train now, in the roomiest layout the cards' room
        -- holds: counted as the rows of what's ready, the fold's line, and
        -- the skipped ones' rows when the fold is open.
        local function Tall(layout)
            local lines = math.ceil(#active / layout.across) + ((showSkipped and #skipped > 0) and math.ceil(#skipped / layout.across) or 0)
            return math.max(lines * layout.high, #now == 0 and VISIT_H or 0) + (#skipped > 0 and FOLD_H or 0)
        end
        local frame = HEAD_H + 2 + STRIP_H + 22   -- the card's heading, line, strip of sums and the note under it
        local layout = LAYOUTS[#LAYOUTS]
        for _, try in ipairs(LAYOUTS) do
            if frame + Tall(try) <= shared - roadH then
                layout = try
                break
            end
        end
        local upH = math.max(UP_MIN, math.min(shared - roadH, frame + Tall(layout)))
        cart:SetHeight(upH)
        ui.sideScroll:SetHeight(upH)
        ui.roadHead:ClearAllPoints()
        ui.roadHead:SetPoint("TOPLEFT", 0, -(top + upH + 24))
        ui.roadScroll:ClearAllPoints()
        ui.roadScroll:SetPoint("TOPLEFT", 0, -(top + upH + 24 + 30))
        ui.roadScroll:SetHeight(roadH)
        ui.road:SetHeight(roadH)

        local at, shown, beside = 0, 0, false
        local function Put(spell)
            shown = shown + 1
            local c = made.cards[shown] or Card()
            made.cards[shown] = c
            local room = c:Lay(layout)
            c.spellID = spell.id
            c.icon:SetTexture(spell.icon)
            c.name:SetWidth(0)
            c.name:SetText(spell.name)
            local fresh = New(spell)
            -- Two across there's no room for the tag after the name: "new"
            -- leads the line under it.
            local tagged = fresh and layout.across == 1
            if Style.Wide(c.name, 0) > room - (tagged and 44 or 0) then c.name:SetWidth(room - (tagged and 44 or 0)) end
            c.new:SetShown(tagged)
            -- A new ability says so in its tag; a higher rank says which.
            local detail = not fresh and spell.rank or nil
            if spell.source == "demon" then detail = spell.group .. " · Grimoire" .. (detail and (" · " .. detail) or "")
            elseif spell.group then detail = spell.group .. (detail and (" · " .. detail) or "")
            elseif spell.via then detail = VIA[spell.via].card .. (detail and (" · " .. detail) or "") end
            if fresh and not tagged then detail = Style.Tint("gold") .. "new|r" .. (detail and (" · " .. detail) or "") end
            c:SetDetail(detail)
            c.hint = (spell.via and (VIA[spell.via].hint .. " ") or "") .. (spell.skipped and "Skipped: right-click to put it back" or "Right-click to skip it")
            if spell.source == "beast" then
                c.cost:SetText(spell.points and (spell.points .. " TP") or "|cff9a9688? TP|r")
            elseif Free(spell) then
                c.cost:SetText("|cff9a9688" .. VIA[spell.via].tag .. "|r")
            else
                c.cost:SetText(Price(spell) or "|cff9a9688?|r")
            end
            local function Flip()
                Training.Skip(spell.id, not spell.skipped)
                Paint()
            end
            c.skip:SetLabel(spell.skipped and "Unskip" or "Skip")
            c.skip:SetScript("OnClick", Flip)
            c:SetScript("OnClick", Flip)
            c:SetAlpha(spell.skipped and 0.6 or 1)
            c:ClearAllPoints()
            if beside then
                -- The second of a pair, beside the one just placed.
                c:SetPoint("TOPLEFT", ROW_W / 2, -(at - layout.high))
                beside = false
            else
                c:SetPoint("TOPLEFT", 0, -at)
                at = at + layout.high
                beside = layout.across == 2
            end
            c:Show()
        end
        for _, spell in ipairs(active) do Put(spell) end
        beside = false
        ui.fold:SetShown(#skipped > 0)
        if #skipped > 0 then
            -- How many, and nothing after: the names ran on after it, cut off (John, 17 Nov 2026:
            -- "i like the +6 skipped with nothing").
            ui.fold.sign:SetText(showSkipped and "-" or "+")
            ui.fold.text:SetText(("|cffc4bfb0%d skipped|r"):format(#skipped))
            ui.fold:ClearAllPoints()
            ui.fold:SetPoint("TOPLEFT", 0, -at)
            at = at + FOLD_H
            if showSkipped then
                for _, spell in ipairs(skipped) do Put(spell) end
            end
        end
        for i = shown + 1, #made.cards do made.cards[i]:Hide() end
        ui.empty:SetShown(#now == 0)
        ui.empty:SetText("Nothing to train right now. The road below shows what's next.")
        ui.cardList:SetHeight(math.max(1, at))
        -- The card is as tall as what's in it, the strip of sums at its foot.
        -- A list too long even two across scrolls inside the card.
        local listH = math.max(1, math.min(math.max(at, #now == 0 and VISIT_H or 0), upH - frame))
        ui.cardScroll:SetHeight(listH)
        ui.cartBox:SetHeight(listH + 2 + STRIP_H)
        ui.cardScroll:UpdateScrollChildRect()
        ui.cardScroll:Place()

        -- The sums: this visit, and what's left after it or how much short.
        ui.visitCost:SetText(cost > 0 and Compat.Money(cost) or (unknown > 0 and "?" or "Nothing"))
        ui.spareLabel:SetText(short and "Short by" or "Left after")
        ui.spareText:SetText(Compat.Money(math.abs(money - cost)))
        ui.spareText:SetTextColor(Style.Color(short and "red" or "green"))
        ui.spareLabel:SetShown(cost > 0)
        ui.spareText:SetShown(cost > 0)
        ui.priceNote:SetText(data.haveTrainer
            and (unknown > 0 and ("%d price%s not seen at a trainer yet."):format(unknown, unknown == 1 and "" or "s") or "")
            or "Prices fill in the first time you open a class trainer.")

        -- The road: a sign for each visit ahead, the next one's in gold, the
        -- last level's ringed in gold. "from": some prices on the way haven't
        -- been seen at a trainer.
        used = {}
        ui.roadHead.note:SetText(rest > 0 and ((restUnknown > 0 and "from " or "") .. Compat.Money(rest) .. " in all") or "")
        ui.band:SetShown(#levels > 0)
        ui.youText:SetShown(#levels > 0)
        ui.youText:SetText(tostring(level))
        ui.roadEmpty:SetShown(#levels == 0)
        -- The road is as long as its visits; what's in view of it is drawn (ui.PaintRoad).
        local long = math.max(width, FIRST_X + math.max(0, #levels - 1) * PITCH + STOP_W + 2)
        ui.road:SetWidth(long)
        ui.band:SetWidth(long)
        ui.roadLevels, ui.roadAhead, ui.roadLong = levels, ahead, long
        ui.PaintYou()
        ui.roadMost = long - width
        ui.roadScroll:UpdateScrollChildRect()
        ui.PlaceRoad()
        ui.PaintRoad(true)
        ui.legend:SetText("A gold frame is a spell new to you; the number is its rank. Point at one for what it does, right-click to skip it."
            .. (ui.roadMost > 0 and "  The mouse wheel moves along the road." or ""))

        -- The right column: the pet, then the weapon skills under it.
        local down = ui.PaintPet(pet)
        down = ui.PaintWeapons(data, down > 0 and down + 14 or 0)
        ui.petList:SetHeight(math.max(1, down))
        ui.sideScroll:UpdateScrollChildRect()
        ui.sideScroll:Place()
        for _, pool in ipairs({ "stops", "glyphs", "tiles", "subs" }) do
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
                             "UNIT_PET", "UNIT_LEVEL", "CRAFT_CLOSE", "UNIT_PET_TRAINING_POINTS" }) do
        -- pcall: not every client has the Beast Training window's events.
        pcall(events.RegisterEvent, events, event)
    end
    -- A burst of news is one repaint: each spell bought at a trainer brings several of these,
    -- and each asked for a repaint of its own. And a pet's news counts only when it's yours.
    local queued = false
    events:RegisterEvent("PLAYER_XP_UPDATE")
    events:SetScript("OnEvent", function(_, event, unit)
        unit = Compat.Plain(unit)
        -- XP moves the road's gold, and nothing else on the page.
        if event == "PLAYER_XP_UPDATE" then
            if page:IsVisible() then xpcall(ui.PaintYou, ns.Report) end
            return
        end
        if event == "UNIT_LEVEL" and unit ~= "pet" then return end
        if event == "UNIT_PET" and unit and unit ~= "player" then return end
        if queued or not page:IsVisible() then return end
        queued = true
        Compat.After(0.3, function()
            queued = false
            if page:IsVisible() then xpcall(Paint, ns.Report) end
        end)
    end)
end, nil, true)
