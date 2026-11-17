-- The Professions page: where you stand in the chosen profession on one
-- bar, your professions in a row under it, then three columns: the step to
-- do now with what it takes; the steps after it, with when the next rank is
-- learned; and everything the road needs, with the nearest trainer. The
-- recipes you know are the ones seen the last time its profession window
-- was open. It reads as the profession panel does.
local _, ns = ...
local Style, Compat, Window, Professions, Road = ns.Style, ns.Compat, ns.Window, ns.Professions, ns.Road

local GAP, TILE_H, NEED_H, RANK_H = 24, 48, 24, Road.RANK_H
local NOW_W, NEED_W = 330, 288      -- the first and last columns; the middle has the rest
local TILE_W, TILE_GAP = 242, 16    -- a profession's tile, at its widest
-- The page's road is the panel's without its prices; true would show them here too.
local FULL = false

Window.Page("professions", function(page)
    local width, height = Window.fullWidth, Window.contentHeight
    local selected
    -- Down the page: the bar, the row of professions, then the three columns.
    local BAR_Y, TILES_Y = 60, 94
    local bodyY = TILES_Y + TILE_H + 20
    -- Across it: what to do now, then the steps after it, then all it takes.
    local thenX = NOW_W + GAP
    local thenW = width - NOW_W - NEED_W - GAP * 2
    local rightX = width - NEED_W
    local rightW = NEED_W

    -- The top: the chosen profession, your skill in it, its rank, and one
    -- bar from the rank's first point to its cap with the next rank marked.
    local title = Style.Text(page, 23, "text", nil, true)
    title:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", 0, -8)
    local points = Style.Text(page, 23, "text", nil, true)
    points:SetPoint("TOPRIGHT", page.heading, "BOTTOMLEFT", width, -8)
    points:SetJustifyH("RIGHT")
    local sub = Style.Text(page, 13, "muted")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    sub:SetWidth(width - 80)
    sub:SetWordWrap(false)
    local track = CreateFrame("Frame", nil, page)
    track:SetSize(width, 6)
    track:SetPoint("TOPLEFT", 0, -BAR_Y)
    Style.Fill(track, "line")
    local fill = track:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT")
    fill:SetPoint("BOTTOMLEFT")
    fill:SetColorTexture(Style.Color("gold"))
    local marker = track:CreateTexture(nil, "OVERLAY")
    marker:SetColorTexture(Style.Color("muted"))
    marker:SetSize(Compat.OnePixel(page), 12)
    local from = Style.Text(page, 11, "muted")
    from:SetPoint("TOPLEFT", track, "BOTTOMLEFT", 0, -5)
    local capText = Style.Text(page, 11, "muted")
    capText:SetPoint("TOPRIGHT", track, "BOTTOMRIGHT", 0, -5)
    capText:SetJustifyH("RIGHT")
    local markText = Style.Text(page, 11, "muted")

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

    -- First: the step in hand, as a card: what to make, how many (and how
    -- many to be safe), and each thing it takes with what you have of it.
    local message = Style.Text(page, 13, "muted")
    message:SetWidth(NOW_W)
    message:SetJustifyH("LEFT")
    local nowHead = Style.Section(page, NOW_W)
    local card = Road.Card(page, NOW_W, FULL)
    -- The next rank, once you're at the skill for it, comes before the card.
    local rankNow = Road.RankRow(page, NOW_W, true)

    -- In the middle: the steps after it, in a list that scrolls when the
    -- road is long.
    local scroll, list = Style.Scroller(page, thenW, height - bodyY, thenW - 8)
    scroll:SetPoint("TOPLEFT", thenX, -bodyY)
    local innerW = thenW - 8
    local thenHead = Style.Section(list, innerW)
    thenHead.title:SetText("THEN")
    local note = Style.Text(list, 12, "muted")
    note:SetWidth(innerW)
    note:SetJustifyH("LEFT")

    -- A later step, on one line; a line under it only when there's
    -- something to do first (learn it, buy its pattern).
    local steps, needs = {}, {}
    local function Step(i)
        if not steps[i] then steps[i] = Road.Step(list, innerW, FULL) end
        return steps[i]
    end

    -- Learning the next rank, as a row of its own where the road reaches
    -- its skill. A click pins the nearest trainer who teaches it.
    local rankRow = Road.RankRow(list, innerW, true)

    -- Last: everything the road needs, then the shopping list and the
    -- nearest trainer.
    local needHead = Style.Section(page, rightW)
    needHead.note:SetText("have / need")
    local function Need(i)
        if needs[i] then return needs[i] end
        local r = CreateFrame("Frame", nil, page)
        r:SetSize(rightW, NEED_H)
        r.count = Style.Text(r, 12, "muted")
        r.count:SetPoint("RIGHT")
        r.count:SetJustifyH("RIGHT")
        r.name = Style.Text(r, 12, "text")
        r.name:SetPoint("LEFT")
        r.name:SetPoint("RIGHT", r.count, "LEFT", -8, 0)
        r.name:SetJustifyH("LEFT")
        r.name:SetWordWrap(false)
        Style.ItemTip(r)
        needs[i] = r
        return r
    end
    local needMore = Style.Text(page, 11, "muted")
    local addRoad = Style.Button(page, "Add the whole road to my shopping list", "plain", rightW)
    addRoad:SetHeight(28)
    local where = Style.Text(page, 12, "muted")
    where:SetWidth(rightW)
    where:SetJustifyH("LEFT")
    where:SetWordWrap(false)
    local pin = Style.Button(page, "Show trainer on map", "primary", rightW)
    pin:SetHeight(28)
    -- How many lines of what's needed fit above the two buttons.
    local maxNeeds = math.max(3, math.floor((height - bodyY - 30 - 120) / NEED_H))

    local function Place(region, y)
        region:ClearAllPoints()
        region:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -y)
        region:Show()
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
        for _, region in ipairs({ nowHead, thenHead, note, card, rankRow, rankNow, message, needHead, needMore, addRoad, where, pin }) do
            region:Hide()
        end
        if bar then
            for _, region in ipairs({ track, from, capText, markText, points }) do region:Hide() end
        end
    end

    local function Paint()
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
                Paint()
            end)
            if p.line == selected then current = p end
        end
        for i = #mine + 1, #cards do cards[i]:Hide() end

        HideRoad(true)
        scroll:SetShown(current ~= nil)
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
        local span = math.max(1, cap - floor)
        for _, region in ipairs({ track, from, capText }) do region:Show() end
        fill:SetWidth(math.max(1, width * math.max(0, math.min(1, (skill - floor) / span))))
        from:SetText(floor)
        capText:SetText(cap)
        local what
        if rankAt and Professions.RankFrom then what = Professions.RankFrom(line, rank.next) end
        local doing = what or (rank.next and ("train " .. rank.next)) or ""
        local ahead = rankAt ~= nil and skill < rankAt
        marker:SetShown(ahead)
        markText:SetShown(ahead)
        if ahead then
            local x = width * (rankAt - floor) / span
            marker:ClearAllPoints()
            marker:SetPoint("CENTER", track, "LEFT", x, 0)
            markText:SetText(("%d · %s"):format(rankAt, doing))
            Road.PlaceMark(markText, track, x, width, from, capText, rankAt >= cap)
        end

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
        local road, totals, stuck = Professions.Plan(line, skill, cap, known, rankAt)
        local crafts = 0
        for _, step in ipairs(road) do crafts = crafts + step.crafts end
        local unit = Professions.IsGathering(line) and "vein" or "craft"

        -- The first column, down from its top: `at`.
        local at, ranked = 0, false
        if not seen and not Professions.IsGathering(line) then
            message:SetText(("Open your %s window once so this uses the recipes you know."):format(current.name))
            PlaceNow(message, at)
            at = at + message:GetStringHeight() + 12
        end

        -- The step in hand.
        local first = road[1]
        nowHead.title:SetText(first and "DO THIS NOW" or (skill >= cap and "AT THE CAP" or "NOTHING TO MAKE YET"))
        nowHead.note:SetText(first and ("%d → %d"):format(first.from, first.to) or "")
        PlaceNow(nowHead, at)
        at = at + 28
        if rankAt and skill >= rankAt then
            Road.PaintRank(rankNow, line, rank, rankIndex, rankAt, skill)
            PlaceNow(rankNow, at)
            at = at + RANK_H + 4
            ranked = true
        end
        if first then
            Road.PaintCard(card, line, first, skill)
            PlaceNow(card, at)
        end

        -- The middle column, down its list: `y`.
        local y = 0
        local function Rank()
            Road.PaintRank(rankRow, line, rank, rankIndex, rankAt, skill)
            Place(rankRow, y)
            y = y + RANK_H
            ranked = true
        end

        -- The steps after it, with the next rank where it falls among them.
        if #road > 1 or ahead then
            thenHead.note:SetText(crafts > 0 and ("to %d · about %d %s%s"):format(cap, crafts, unit, crafts == 1 and "" or "s") or "")
            Place(thenHead, y)
            y = y + 28
        end
        for i = 2, #road do
            local step = road[i]
            if not ranked and rankAt and step.from >= rankAt then Rank() end
            local s = Step(i - 1)
            local tall = Road.PaintStep(s, step)
            Place(s, y)
            y = y + tall
        end
        if not ranked and ahead then Rank() end
        local last
        if stuck then
            last = ("Past %d, only patterns you'd have to find give skill."):format(stuck)
        elseif skill >= cap and not rankAt then
            last = "That's as far as it goes."
        end
        if last then
            note:SetText(last)
            Place(note, y + 4)
            y = y + note:GetStringHeight() + 10
        end
        list:SetHeight(math.max(1, y))
        scroll:UpdateScrollChildRect()
        scroll:Place()

        -- Everything the road needs, the biggest shortfall first.
        local all = {}
        for item, need in pairs(totals) do
            all[#all + 1] = { item = item, need = need, have = Compat.ItemCount(item, true) }
        end
        table.sort(all, function(a, b)
            local sa, sb = a.need - a.have, b.need - b.have
            if sa ~= sb then return sa > sb end
            return a.item < b.item
        end)
        local ry = 0
        if #all > 0 then
            needHead.title:SetText(("EVERYTHING TO %d"):format(cap))
            PlaceRight(needHead, ry)
            ry = ry + 28
            for i, entry in ipairs(all) do
                if i > maxNeeds then break end
                local r = Need(i)
                PlaceRight(r, ry)
                r.item = entry.item
                r.name:SetText(Compat.ItemName(entry.item) or "...")
                r.count:SetText(("|cff%s%d|r / %d"):format(entry.have >= entry.need and Style.hex.green or Style.hex.red, entry.have, entry.need))
                ry = ry + NEED_H
            end
            if #all > maxNeeds then
                needMore:SetText(("and %d more, in the shopping list"):format(#all - maxNeeds))
                PlaceRight(needMore, ry + 2)
                ry = ry + 18
            end
            ry = ry + 12
        end
        -- The whole road onto the shopping list at once.
        local crafting = {}
        for _, step in ipairs(road) do
            if not step.recipe.vein then crafting[#crafting + 1] = step end
        end
        if ns.Shopping and ns.Shopping.running and #crafting > 0 then
            addRoad:SetScript("OnClick", function()
                for _, step in ipairs(crafting) do ns.Shopping.AddCraft(step.recipe.spell, step.crafts) end
            end)
            PlaceRight(addRoad, ry)
            ry = ry + 36
        end
        -- The nearest trainer for your rank, or the next one once you're
        -- ready for it.
        local needed = (rankAt and skill >= rankAt) and rankIndex + 1 or rankIndex
        local trainer = ns.Trainers and ns.Trainers.Nearest("skill" .. line, needed)
        if trainer then
            local place = ns.Trainers.Zone(trainer)
            where:SetText(("Nearest trainer: |cffece6d6%s|r%s"):format(trainer.name, place and (", " .. place) or ""))
            PlaceRight(where, ry + 2)
            ry = ry + 22
            pin:SetScript("OnClick", function() ns.Trainers.Pin(trainer) end)
            PlaceRight(pin, ry)
        end
    end

    page.Refresh = function() xpcall(Paint, ns.Report) end
    local events = CreateFrame("Frame")
    for _, event in ipairs({ "SKILL_LINES_CHANGED", "BAG_UPDATE_DELAYED", "ITEM_DATA_LOAD_RESULT" }) do
        pcall(events.RegisterEvent, events, event)
    end
    local queued = false
    events:SetScript("OnEvent", function()
        if not page:IsVisible() or queued then return end
        queued = true
        Compat.After(0.3, function()
            queued = false
            if page:IsVisible() then xpcall(Paint, ns.Report) end
        end)
    end)
end, nil, true)
