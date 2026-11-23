-- The Professions page: where you stand in the chosen profession on one
-- bar, your professions in a row under it, then two cards side by side: the
-- step to do now with what it takes, and everything the road needs with the
-- way to put it on the shopping list. Across the bottom, the road to the
-- rank's cap, drawn as a road: you at its start, a stop for each step after
-- the one in hand with a round sign at the skill it reaches, a gold stop
-- where the next rank is learned, and the cap at its end. Six stops show at
-- a time; the mouse wheel moves along the rest. The recipes you know are the
-- ones seen the last time its profession window was open.
local _, ns = ...
local Style, Compat, Window, Professions, Road = ns.Style, ns.Compat, ns.Window, ns.Professions, ns.Road

local GAP, TILE_H, NEED_H, RANK_H = 24, 48, 26, Road.RANK_H
local CARD_W = 496                  -- each of the two cards
local TILE_W, TILE_GAP = 242, 16    -- a profession's tile, at its widest
-- Materials listed in the card, two across: room for all of a rank's, so none of a long road's
-- last few is left "not listed".
local MAX_NEEDS = 16
-- The road: a stop every PITCH, the first FIRST_X along, each STOP_W wide
-- for what's under its sign; the band is the road itself, and you stand
-- YOU_X along it.
local PITCH, STOP_W, FIRST_X, YOU_X, BAND_H = 160, 152, 56, 30, 26
local ACROSS = 6                    -- stops that fit across the page at that pitch
local SIGN, ROAD_H = Road.SIGN, Road.ACROSS_H + 4

Window.Page("professions", function(page)
    local width, height = Window.fullWidth, Window.contentHeight
    local selected
    -- Down the page: the row of professions, the two cards, the road. No bar from the rank's first
    -- point to its cap: the skill is at the top right, and the road's gold and its rank stop say
    -- the rest.
    local TILES_Y = 60
    local bodyY = TILES_Y + TILE_H + 20
    local rightX = width - CARD_W

    -- The top: the chosen profession, your skill in it, and its rank.
    local title = Style.Text(page, 23, "text", nil, true)
    title:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", 0, -8)
    local points = Style.Text(page, 23, "text", nil, true)
    points:SetPoint("TOPRIGHT", page.heading, "BOTTOMLEFT", width, -8)
    points:SetJustifyH("RIGHT")
    local sub = Style.Text(page, 13, "muted")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    sub:SetWidth(width - 80)
    sub:SetWordWrap(false)

    -- Your professions, in a row: a click chooses one.
    local cards = {}
    local function Card(i)
        if cards[i] then return cards[i] end
        local c = CreateFrame("Button", nil, page)
        c:SetHeight(TILE_H)
        c.edges = { Style.Box(c, 6, "well", "cardLine").line }
        c.icon = c:CreateTexture(nil, "ARTWORK")
        c.icon:SetSize(28, 28)
        c.icon:SetPoint("LEFT", 12, 0)
        c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        c.name = Style.Text(c, 12, "text", nil, true)
        c.name:SetPoint("TOPLEFT", c.icon, "TOPRIGHT", 8, 2)
        c.name:SetPoint("RIGHT", -6, 0)
        c.name:SetJustifyH("LEFT")
        c.name:SetWordWrap(false)
        c.sub = Style.Text(c, 11, "muted")
        c.sub:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -2)
        cards[i] = c
        return c
    end
    local none = Style.Text(page, 13, "muted")
    none:SetPoint("TOPLEFT", 0, -TILES_Y)
    none:SetWidth(width)

    -- At the left: the step in hand, as a card: what to make, how many, and
    -- each thing it takes with what you have of it.
    local message = Style.Text(page, 13, "muted")
    message:SetWidth(CARD_W)
    message:SetJustifyH("LEFT")
    local nowHead = Style.Section(page, CARD_W)
    local card = Road.NowCard(page, CARD_W)
    -- The next rank, once you're at the skill for it, comes before the card.
    local rankNow = Road.RankRow(page, CARD_W, true)

    -- At the right: everything the road needs, two across in a card, and
    -- along its foot how much is still to get and the way to put the road
    -- on the shopping list. The nearest trainer is under it.
    local needHead = Style.Section(page, CARD_W)
    needHead.note:SetText("have / need")
    local needBox = CreateFrame("Frame", nil, page)
    needBox:SetWidth(CARD_W)
    Style.Box(needBox, 6, "well", "cardLine")
    local needs = {}
    local cellW = (CARD_W - 2) / 2
    local function Need(i)
        if needs[i] then return needs[i] end
        local r = CreateFrame("Frame", nil, needBox)
        r:SetSize(cellW, NEED_H)
        r:SetPoint("TOPLEFT", 1 + ((i - 1) % 2) * cellW, -(7 + math.floor((i - 1) / 2) * NEED_H))
        r.count = Style.Text(r, 12, "muted")
        r.count:SetPoint("RIGHT", -14, 0)
        r.count:SetJustifyH("RIGHT")
        r.name = Style.Text(r, 12, "text")
        r.name:SetPoint("LEFT", 14, 0)
        r.name:SetPoint("RIGHT", r.count, "LEFT", -8, 0)
        r.name:SetJustifyH("LEFT")
        r.name:SetWordWrap(false)
        Style.ItemTip(r, nil, nil, 0)
        needs[i] = r
        return r
    end
    local needStrip = CreateFrame("Frame", nil, needBox)
    needStrip:SetPoint("BOTTOMLEFT", 1, 1)
    needStrip:SetPoint("BOTTOMRIGHT", -1, 1)
    needStrip:SetHeight(34)
    Style.Cap(needStrip, 5, "titleBar", "BOTTOM")
    Style.Rule(needStrip, "TOP", "cardLine")
    local needSum = Style.Text(needStrip, 12, "muted")
    needSum:SetPoint("LEFT", 13, 0)
    local addRoad = Road.ShopLink(needStrip, "Add the road to my shopping list", "The road is on your shopping list", 200)
    addRoad:SetPoint("RIGHT", -13, 0)
    local where = Style.Text(page, 12, "muted")
    where:SetWidth(CARD_W - 90)
    where:SetJustifyH("LEFT")
    where:SetWordWrap(false)
    local pin = CreateFrame("Button", nil, page)
    pin.text = Style.Text(pin, 11, "muted")
    pin.text:SetPoint("RIGHT")
    pin.text:SetText("show on map")
    pin:SetSize(Style.Wide(pin.text, 76), 18)
    pin:SetScript("OnEnter", function(self) self.text:SetTextColor(Style.Color("gold")) end)
    pin:SetScript("OnLeave", function(self) self.text:SetTextColor(Style.Color("muted")) end)

    -- Across the bottom: the road. A band, you at its
    -- start, and the stops along it; longer than the page, the wheel moves
    -- along it and a thin bar under it shows where.
    local roadHead = Style.Section(page, width)
    local scroll = CreateFrame("ScrollFrame", nil, page)
    scroll:SetSize(width, ROAD_H)
    local lane = CreateFrame("Frame", nil, scroll)
    lane:SetSize(width, ROAD_H)
    scroll:SetScrollChild(lane)
    local band = CreateFrame("Frame", nil, lane)
    band:SetPoint("TOPLEFT", 0, -(SIGN - BAND_H) / 2)
    band:SetSize(width, BAND_H)
    Style.Box(band, 13, "titleBar", "lineStrong")
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
    -- The road is one you travel along, its signs a stop apart: it starts at the rank's first
    -- point, the step in hand is its first sign, the
    -- steps you've done stay behind you dimmed, and you move along it, the gold behind you, as
    -- your skill rises. The road was planned afresh from your skill each time, you always at its
    -- start, so the steps you've passed are kept per profession: the one that was next, once
    -- your skill reaches its end. A new rank starts the list again.
    local MIN_FILL, PASSED_MOST = 12, 40
    local function Passed(line, floor, skill, first)
        local all = type(ns.char.profRoad) == "table" and ns.char.profRoad or {}
        ns.char.profRoad = all
        local r = all[line]
        if type(r) ~= "table" or r.floor ~= floor or type(r.passed) ~= "table" then
            r = { floor = floor, passed = {} }
            all[line] = r
        end
        local was = r.next
        if type(was) == "table" and type(was.to) == "number" and was.to <= skill then
            local last = r.passed[#r.passed]
            if not last or last.to < was.to then r.passed[#r.passed + 1] = was end
        end
        -- None ahead of you: a plan changed, or the skill went back.
        while #r.passed > 0 and (r.passed[#r.passed].to or 0) > skill do table.remove(r.passed) end
        while #r.passed > PASSED_MOST do table.remove(r.passed, 1) end
        local spell = first and first.recipe and first.recipe.spell
        if spell then
            -- The same step as before keeps where it started and its most crafts.
            local same = type(was) == "table" and was.spell == spell and was.to == first.to
            r.next = { spell = spell, to = first.to, from = same and math.min(was.from, first.from) or first.from,
                       crafts = same and math.max(was.crafts or 0, first.crafts) or first.crafts }
        else
            r.next = nil
        end
        return r.passed, r.next
    end
    -- A passed step's recipe, by its spell.
    local function RecipeOf(line, spell)
        for _, recipe in ipairs(Professions.Recipes(line) or {}) do
            if recipe.spell == spell then return recipe end
        end
    end
    -- The gold to `reach` along the band, the mark at its end.
    local function PaintYou(reach)
        done:SetShown(reach >= MIN_FILL)
        done:SetWidth(math.max(MIN_FILL, reach - 1))
        you:ClearAllPoints()
        you:SetPoint("CENTER", band, "LEFT", math.max(10, reach), 0)
    end
    local youText = Style.Text(lane, 10, "gold", nil, true)
    youText:SetPoint("TOP", band, "BOTTOMLEFT", YOU_X, -8)
    youText:SetJustifyH("CENTER")
    -- The rank's first point, under the road's start.
    local floorText = Style.Text(lane, 10, "muted", nil, true)
    floorText:SetPoint("TOPLEFT", band, "BOTTOMLEFT", 2, -8)
    -- No dashed middle, as on the Training Planner's road: they were a piece every 22 pixels.
    local PaintRoadView
    -- A stop for each step after the one in hand; the gold one where the
    -- next rank is learned; and the rank's cap, ringed in gold, at the end.
    local steps = {}
    local function Step(i)
        if not steps[i] then
            steps[i] = Road.Stop(lane, STOP_W, true)
            -- Over the road's band, which is the road's child as they are.
            steps[i]:SetFrameLevel((lane:GetFrameLevel() or 0) + 3)
        end
        return steps[i]
    end
    local rankStop = Road.RankStop(lane, STOP_W, true)
    rankStop:SetFrameLevel((lane:GetFrameLevel() or 0) + 3)
    local endSign = CreateFrame("Frame", nil, lane)
    endSign:SetSize(SIGN, SIGN)
    endSign:SetFrameLevel((lane:GetFrameLevel() or 0) + 3)
    Style.Circle(endSign, "well", "gold")
    endSign.level = Style.Text(endSign, 12, "gold", nil, true)
    endSign.level:SetPoint("CENTER")
    endSign.level:SetJustifyH("CENTER")
    local thumb = page:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(Style.Color("thumb"))
    thumb:SetHeight(3)
    thumb:Hide()
    local most = 0
    local function PlaceRoad()
        local at = math.max(0, math.min(most, scroll:GetHorizontalScroll() or 0))
        scroll:SetHorizontalScroll(at)
        thumb:SetShown(most > 0 and scroll:IsShown())
        if most > 0 then
            local size = math.max(40, width * width / (width + most))
            thumb:SetWidth(size)
            thumb:ClearAllPoints()
            thumb:SetPoint("TOPLEFT", scroll, "BOTTOMLEFT", (width - size) * at / most, -2)
        end
    end
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        self:SetHorizontalScroll((self:GetHorizontalScroll() or 0) - delta * PITCH)
        PlaceRoad()
        PaintRoadView()
    end)
    local legend = Style.Text(page, 11, "muted")
    legend:SetPoint("BOTTOMLEFT", 0, 0)
    legend:SetWidth(width)
    legend:SetJustifyH("LEFT")
    legend:SetWordWrap(false)

    -- The road's places near what's in view, one either side: every step to the rank's cap was
    -- painted, a stop with its recipe's picture each, where six show. The wheel paints the next
    -- ones as they come into view; nothing is painted again while the same ones show, unless
    -- `fresh` (the road was laid out). A short road, spread across the page, is all in view.
    local road, roadDrawn
    function PaintRoadView(fresh)
        if not road then return end
        local at = scroll:GetHorizontalScroll() or 0
        local lo, hi = at - PITCH, at + width + PITCH
        local key = road.spread and "all" or (math.floor(lo / PITCH) .. ":" .. math.floor(hi / PITCH))
        if not fresh and key == roadDrawn then return end
        roadDrawn = key
        local o, used = road.o, 0
        rankStop:Hide()
        endSign:Hide()
        for _, item in ipairs(road.items) do
            local mid = road.Middle(item.k)
            if road.spread or (mid >= lo and mid <= hi) then
                local stop
                if item.kind == "step" or item.kind == "passed" then
                    used = used + 1
                    stop = Step(used)
                    Road.PaintStop(stop, item.step, Road.TrainerFor(o.line, item.step))
                    -- Behind you, the sign stays solid over the gold (faded, the gold showed through
                    -- it); its line and number are quieter, its picture and words faded.
                    local behind = item.kind == "passed"
                    stop.disc:Paint("well", behind and "line" or (item.cap and "gold" or "lineStrong"))
                    stop.level:SetTextColor(Style.Color(behind and "muted" or (item.cap and "gold" or "text")))
                    for _, part in ipairs({ stop.icon, stop.name, stop.count }) do part:SetAlpha(behind and 0.45 or 1) end
                    if behind then stop.tag:Hide() end
                elseif item.kind == "rank" then
                    Road.PaintRankStop(rankStop, o.line, o.rank, o.rankIndex, o.rankAt, o.skill)
                    stop = rankStop
                end
                if stop then
                    stop:ClearAllPoints()
                    stop:SetPoint("TOPLEFT", mid - STOP_W / 2, 0)
                    stop:Show()
                else
                    endSign.level:SetText(o.cap)
                    endSign:ClearAllPoints()
                    endSign:SetPoint("TOP", lane, "TOPLEFT", mid, 0)
                    endSign:Show()
                end
            end
        end
        for i = used + 1, #steps do steps[i]:Hide() end
    end

    -- Lays the road out `y` down the page for the plan's steps: a stop for
    -- each step after the one in hand, the next rank's training where it
    -- falls among them (`o.rankAt`, unless `o.ranked` says it's already
    -- shown above), and the cap at its end when the road gets there
    -- (`o.capped`). `note` is said at the right of its heading; `o.trainer`
    -- is who a step learned at a trainer pins.
    local function LayRoad(y, plan, note, o)
        roadHead.title:SetText(("YOUR ROAD TO %d"):format(o.cap))
        roadHead.note:SetText(note)
        roadHead:ClearAllPoints()
        roadHead:SetPoint("TOPLEFT", 0, -y)
        roadHead:Show()
        scroll:ClearAllPoints()
        scroll:SetPoint("TOPLEFT", 0, -(y + 30))
        scroll:Show()
        youText:SetText(tostring(o.skill))
        local ranked = o.ranked
        -- The road's places: a stop for each step after the one in hand, the
        -- next rank's while it's still ahead, and the cap's sign; but a rank
        -- learned at the cap itself is the road's end, with no sign after it
        -- saying the same number, and so is a last step that reaches the cap.
        local ranks = (not ranked and o.ahead) and 1 or 0
        local last = plan[#plan]
        local reached = last ~= nil and (last.to or 0) >= o.cap
        local ends = (o.capped and not (ranks == 1 and o.rankAt >= o.cap) and not reached) and 1 or 0
        local passed = {}
        local kept, nextKept = Passed(o.line, o.floor, o.skill, plan[1])
        for _, kept in ipairs(kept) do
            local recipe = RecipeOf(o.line, kept.spell)
            if recipe then passed[#passed + 1] = { from = kept.from, to = kept.to, crafts = kept.crafts, recipe = recipe } end
        end
        local places = math.max(1, #passed + #plan + ranks + ends)
        -- Six or more stand a PITCH apart, and the wheel moves along them.
        -- Fewer are spread evenly from you to the page's right edge, so a
        -- short road still runs from here to there. Where place k's middle is:
        local function Middle(k)
            if places >= ACROSS then return FIRST_X + k * PITCH + STOP_W / 2 end
            return YOU_X + (k + 1) * (width - STOP_W / 2 - YOU_X) / places
        end
        -- The road's places in order: a stop for each step after the one in hand, the next
        -- rank's where it falls among them, and the cap's sign. Only those near what's in view
        -- are painted (PaintRoadView), as on the Training Planner's road.
        local items = {}
        local function Add(kind, step) items[#items + 1] = { kind = kind, step = step, k = #items } end
        for _, step in ipairs(passed) do Add("passed", step) end
        for i = 1, #plan do
            local step = plan[i]
            if not ranked and o.rankAt and step.from >= o.rankAt then
                Add("rank")
                ranked = true
            end
            Add("step", step)
        end
        if not ranked and o.ahead then Add("rank") end
        if ends == 1 then Add("cap") end
        -- A last step that reaches the cap is the cap's sign too: ringed in gold, as the cap's own
        -- is, until the next rank (Artisan, at 200) raises the cap past it.
        if reached then
            for i = #items, 1, -1 do
                if items[i].kind == "step" then items[i].cap = true break end
            end
        end
        road = { items = items, Middle = Middle, o = o, spread = places < ACROSS, view = road and road.view }
        -- You: between the sign behind you (or the road's start, the rank's first point) and
        -- the next, by your skill between their numbers; clear of both signs.
        local P = #passed
        local nextItem = items[P + 1]
        local nextAt = nextItem and ((nextItem.kind == "step" and nextItem.step.to) or (nextItem.kind == "rank" and o.rankAt) or o.cap)
        -- The road's start: the rank's first point, or lower where your skill is (a rank can be
        -- learned before its first point), from where the step in hand began.
        local backAt = P > 0 and passed[P].to or math.min(o.floor, nextKept and nextKept.from or o.skill, o.skill)
        local backX = P > 0 and (Middle(P - 1) + SIGN / 2 + 10) or 10
        local aheadX = nextItem and (Middle(P) - SIGN / 2 - 10) or backX
        local along = nextAt and math.max(0, math.min(1, (o.skill - backAt) / math.max(1, nextAt - backAt))) or 1
        local youX = backX + along * math.max(0, aheadX - backX)
        PaintYou(youX)
        youText:ClearAllPoints()
        youText:SetPoint("TOP", band, "BOTTOMLEFT", math.max(YOU_X, youX), -8)
        floorText:SetText(backAt)
        floorText:SetShown(P == 0 and youX > 60)
        -- The road is as long as its stops.
        local long = places >= ACROSS and math.max(width, FIRST_X + (places - 1) * PITCH + STOP_W + 2) or width
        lane:SetWidth(long)
        band:SetWidth(long)
        most = long - width
        scroll:UpdateScrollChildRect()
        local view = o.line .. ":" .. P
        if view ~= road.view then
            scroll:SetHorizontalScroll(math.max(0, backX - FIRST_X))
            road.view = view
        end
        PlaceRoad()
        PaintRoadView(true)
        legend:SetText("Point at a step for what it costs and where its pattern is sold."
            .. (most > 0 and "  The mouse wheel moves along the road." or ""))
        legend:Show()
    end

    local function PlaceNow(region, y)
        region:ClearAllPoints()
        region:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -(bodyY + y))
        region:Show()
    end
    local function PlaceRight(region, y)
        region:ClearAllPoints()
        region:SetPoint("TOPLEFT", page, "TOPLEFT", rightX, -(bodyY + y))
        region:Show()
    end

    ---------------------------------------------------------------------
    -- Guild crafters: a card beside your professions. Who makes what has a
    -- window of its own now, Guild Crafts, with the guild's orders beside it;
    -- the card stays here, where it's been looked for, and opens that window
    -- on its Crafters tab.
    ---------------------------------------------------------------------
    local guildCard = CreateFrame("Button", nil, page)
    guildCard:SetHeight(TILE_H)
    guildCard.edges = { Style.Box(guildCard, 6, "well", "cardLine").line }
    local guildIcon = guildCard:CreateTexture(nil, "ARTWORK")
    guildIcon:SetSize(28, 28)
    guildIcon:SetPoint("LEFT", 12, 0)
    guildIcon:SetTexture("Interface\\AddOns\\jsalUI\\Media\\Icons\\guild")
    local guildName = Style.Text(guildCard, 12, "text", nil, true)
    guildName:SetPoint("TOPLEFT", guildIcon, "TOPRIGHT", 8, 2)
    guildName:SetText("Guild crafters")
    local guildSub = Style.Text(guildCard, 11, "muted")
    guildSub:SetPoint("TOPLEFT", guildName, "BOTTOMLEFT", 0, -2)
    guildSub:SetText("who makes what")

    -- Everything of the road, out of sight, before each painting of it.
    local function HideRoad(bar)
        for _, s in ipairs(steps) do s:Hide() end
        for _, r in ipairs(needs) do r:Hide() end
        for _, m in ipairs(card.mats) do m:Hide() end
        for _, region in ipairs({ nowHead, card, rankNow, message, needHead, needBox, where, pin, roadHead, scroll, rankStop, endSign,
                                  thumb, legend }) do
            region:Hide()
        end
        if bar then
            points:Hide()
        end
    end

    -- Each profession's road as last worked out, kept while nothing it's worked out from has
    -- changed: your skill and cap, the recipes you know, what's in your bags, and the prices. A
    -- name the game loads redraws the page, and so does every switch between professions,
    -- and neither works the road out again. `bags` moves when the game says your bags changed.
    local plans, bags = {}, 0
    local Paint
    local function TimedPaint()
        local started = debugprofilestop and debugprofilestop()
        xpcall(Paint, ns.Report)
        if started and ns.Timed then ns.Timed("Professions page, drawn", started) end
    end

    function Paint()
        local mine = Professions.Mine()
        none:SetShown(#mine == 0)
        none:SetText("No crafting professions yet. Learn one at a trainer, and its road shows here.")
        local guildOn = ns.Crafters ~= nil and ns.Crafters.running == true and ns.GuildCrafts ~= nil
        if not selected or not Professions.Name(selected) then
            selected = mine[1] and mine[1].line or nil
        end
        -- The row of professions, with the guild's crafters last in it.
        local tiles = #mine + (guildOn and 1 or 0)
        local tileW = tiles > 0 and math.min(TILE_W, math.floor((width - (tiles - 1) * TILE_GAP) / tiles)) or TILE_W
        local tilesY = #mine > 0 and TILES_Y or (TILES_Y + none:GetStringHeight() + 12)
        guildCard:SetShown(guildOn)
        if guildOn then
            guildCard:ClearAllPoints()
            guildCard:SetSize(tileW, TILE_H)
            guildCard:SetPoint("TOPLEFT", #mine * (tileW + TILE_GAP), -tilesY)
            guildCard:SetScript("OnClick", function() ns.GuildCrafts.Show("crafters") end)
        end
        local current
        for i, p in ipairs(mine) do
            local c = Card(i)
            c:ClearAllPoints()
            c:SetSize(tileW, TILE_H)
            c:SetPoint("TOPLEFT", (i - 1) * (tileW + TILE_GAP), -TILES_Y)
            c:Show()
            c.icon:SetTexture(p.icon)
            c.name:SetText(p.name)
            c.sub:SetText(("%d of %d"):format(p.skill, p.cap))
            Style.SetBorder(c.edges, p.line == selected and "gold" or "cardLine")
            c:SetScript("OnClick", function()
                selected = p.line
                TimedPaint()
            end)
            if p.line == selected then current = p end
        end
        for i = #mine + 1, #cards do cards[i]:Hide() end

        HideRoad(true)
        if not current then
            title:SetText("Professions")
            sub:SetText("What to craft, and how many, to reach each profession's next rank")
            return
        end

        -- Where you stand.
        local skill, cap, line = current.skill, current.cap, current.line
        local rank = Professions.Rank(cap)
        -- The skill its next rank is learned at: the usual, or the profession's own.
        local rankAt = Professions.At(line, rank)
        local rankIndex = 1
        for i, r in ipairs(Professions.RANKS) do if r == rank then rankIndex = i end end
        local floor = rankIndex > 1 and Professions.RANKS[rankIndex - 1].cap or 0
        title:SetText(current.name)
        points:SetText(skill)
        points:Show()
        sub:SetText(rank.name)
        local ahead = rankAt ~= nil and skill < rankAt

        -- What you know: as last seen in its window, else every trainer
        -- recipe up to your skill.
        local seen = Professions.Remembered(line)
        local set = seen and seen.known
        if not set then
            set = {}
            for _, recipe in ipairs(Professions.Recipes(line)) do
                if recipe.how == 1 and recipe.learn <= skill then set[recipe.spell] = true end
            end
        end
        local function known(spell) return set[spell] end
        -- The road runs to the rank's cap, with a break where the next rank
        -- is learned, as the profession panel's does.
        local prices = ns.ItemPrices
        local knownCount = 0
        for _ in pairs(set) do knownCount = knownCount + 1 end
        local key = table.concat({ skill, cap, tostring(rankAt), seen and "seen" or "trainer", knownCount, tostring(Professions.Priced and Professions.Priced()),
            prices and prices.seen or 0, prices and prices.scans or 0, tostring(prices and prices.useAuctionator), bags, tostring(Professions.Plan),
            tostring(Compat.Faction()) }, ";")
        local kept = plans[line]
        local road, totals, stuck
        if kept and kept.key == key then
            road, totals, stuck = kept.road, kept.totals, kept.stuck
        else
            road, totals, stuck = Professions.Plan(line, skill, cap, known, rankAt)
            plans[line] = { key = key, road = road, totals = totals, stuck = stuck }
        end
        local crafts = 0
        for _, step in ipairs(road) do crafts = crafts + step.crafts end
        local unit = Professions.IsGathering(line) and "vein" or "craft"

        -- The nearest trainer for your rank, or the next one once you're
        -- ready for it: a step that's learned at a trainer pins them, and so
        -- does the line under the right card.
        local needed = (rankAt and skill >= rankAt) and rankIndex + 1 or rankIndex
        local trainer = ns.Trainers and ns.Trainers.Nearest("skill" .. line, needed, skill)

        -- The left card, down from its top: `at`.
        local at = 0
        if not seen and not Professions.IsGathering(line) then
            message:SetText(("Open your %s window once so this uses the recipes you know."):format(current.name))
            PlaceNow(message, at)
            at = at + message:GetStringHeight() + 12
        end

        -- The step in hand.
        local first = road[1]
        local last
        if stuck then
            last = ("Past %d, only patterns you'd have to find give skill."):format(stuck)
        elseif skill >= cap and not rankAt then
            last = "That's as far as it goes."
        end
        nowHead.title:SetText(first and "DO THIS NOW" or (skill >= cap and "AT THE CAP" or "NOTHING TO MAKE YET"))
        nowHead.note:SetText(first and ("%d → %d"):format(first.from, first.to) or (last or ""))
        PlaceNow(nowHead, at)
        at = at + 28
        local ranked = false
        if rankAt and skill >= rankAt then
            Road.PaintRank(rankNow, line, rank, rankIndex, rankAt, skill)
            PlaceNow(rankNow, at)
            at = at + RANK_H + 4
            ranked = true
        end
        if first then
            local recipe = first.recipe
            Road.PaintNow(card, line, first, skill, Road.TrainerFor(line, first))
            PlaceNow(card, at)
            at = at + card.tall
            -- The step's crafts onto the shopping list, from the card's foot.
            local shop = ns.Shopping and ns.Shopping.running and not recipe.vein
            card.add:SetShown(shop and true or false)
            card.add:SetScript("OnClick", function() ns.Shopping.TopUp({ first }) end)
            if shop then ns.Shopping.Track(card.add, { first }) end
        end

        -- The right card: everything the road needs, the biggest shortfall
        -- first, two across; how much is still to get; the shopping list.
        local all, short = {}, 0
        for item, need in pairs(totals) do
            local have = Compat.ItemCount(item, true)
            all[#all + 1] = { item = item, need = need, have = have }
            if have < need then short = short + 1 end
        end
        table.sort(all, function(a, b)
            local sa, sb = a.need - a.have, b.need - b.have
            if sa ~= sb then return sa > sb end
            return a.item < b.item
        end)
        local crafting = {}
        for _, step in ipairs(road) do
            if not step.recipe.vein then crafting[#crafting + 1] = step end
        end
        local ry = 0
        if #all > 0 then
            needHead.title:SetText(("EVERYTHING TO %d"):format(cap))
            PlaceRight(needHead, ry)
            ry = ry + 28
            local shown = math.min(#all, MAX_NEEDS)
            for i = 1, shown do
                local entry, r = all[i], Need(i)
                r:Show()
                r.item = entry.item
                r.name:SetText(Compat.ItemName(entry.item) or "...")
                r.count:SetText(("|cff%s%d|r / %d"):format(entry.have >= entry.need and Style.hex.green or Style.hex.red, entry.have, entry.need))
            end
            needSum:SetText((short == 0 and "Everything's in hand" or ("%d still to get"):format(short))
                .. (#all > shown and (", %d more not listed"):format(#all - shown) or ""))
            local shop = ns.Shopping and ns.Shopping.running and #crafting > 0
            addRoad:SetShown(shop and true or false)
            addRoad:SetScript("OnClick", function()
                ns.Shopping.TopUp(crafting)
            end)
            if shop then ns.Shopping.Track(addRoad, crafting) end
            local tall = 7 + math.ceil(shown / 2) * NEED_H + 7 + 34
            needBox:SetHeight(tall)
            PlaceRight(needBox, ry)
            ry = ry + tall
        end
        -- That trainer, with a quiet way to show them on the map.
        if trainer then
            local place = ns.Trainers.Zone(trainer)
            where:SetText(("Nearest trainer: |cffece6d6%s|r%s"):format(trainer.name, place and (", " .. place) or ""))
            PlaceRight(where, ry + 10)
            pin:SetScript("OnClick", function() ns.Trainers.Pin(trainer) end)
            pin:ClearAllPoints()
            pin:SetPoint("TOPRIGHT", page, "TOPLEFT", width, -(bodyY + ry + 8))
            pin:Show()
            ry = ry + 28
        end

        -- The road, under the taller of the two.
        if #road <= 1 and not ahead then return end
        LayRoad(bodyY + math.max(at, ry) + 22, road,
            last or (crafts > 0 and ("about %d %s%s"):format(crafts, unit, crafts == 1 and "" or "s") or ""),
            { line = line, rank = rank, rankIndex = rankIndex, rankAt = rankAt, skill = skill, cap = cap, floor = floor,
              ranked = ranked, ahead = ahead, capped = not stuck and skill < cap, trainer = trainer })
    end

    page.Refresh = TimedPaint
    local events = CreateFrame("Frame")
    for _, event in ipairs({ "SKILL_LINES_CHANGED", "BAG_UPDATE_DELAYED", "ITEM_DATA_LOAD_RESULT" }) do
        pcall(events.RegisterEvent, events, event)
    end
    local queued = false
    events:SetScript("OnEvent", function(_, event)
        if event == "BAG_UPDATE_DELAYED" then bags = bags + 1 end
        if not page:IsVisible() or queued then return end
        queued = true
        Compat.After(0.3, function()
            queued = false
            if page:IsVisible() then TimedPaint() end
        end)
    end)
end, nil, true)
