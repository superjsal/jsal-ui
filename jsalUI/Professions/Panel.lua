-- A panel beside the profession window: where you stand in the rank, the
-- one thing to make now with what it takes, the steps after it one line
-- each (and when to train the next rank), and everything the road needs
-- against what you have.
local _, ns = ...
local Style, Compat, Professions = ns.Style, ns.Compat, ns.Professions

local Panel = ns.NewModule("professionpanel", {
    title = "Profession road",
    note = "Beside the profession window: what to craft to reach the next rank.",
})

local WIDTH, PAD, STEP_H, ROW_H = 360, 14, 30, 30
-- A step's line with a note under it, a material's line in the card, a line
-- of everything the road needs, and the row for training the next rank.
local NOTE_H, MAT_H, NEED_H, RANK_H = 14, 36, 22, 38
local TAB_H = 24
local MAX_STEPS, MAX_ITEMS = 6, 8
-- The profession window, newer and older.
local TARGETS = {
    function() return ProfessionsFrame end,
    function() return TradeSkillFrame end,
}

local panel, anchor, dismissed
local Paint
-- The tab showing: the road with what it needs, or the recipes to learn.
local tab = "road"
local hooked = {}
local steps, items, unlearned = {}, {}, {}
local showAllUnlearned = false
local DETAIL_H = 42
local SOURCE = { [1] = "Trainer", [2] = "Vendor pattern", [3] = "Drop", [4] = "Quest" }

local function Line(name)
    if not name then return nil end
    local line = Professions.LineByName(name)
    if line then return line end
    for id, source in pairs(ns.ProfessionData) do
        if type(source) == "table" and source.name and name:find(source.name, 1, true) then return id end
    end
end

---------------------------------------------------------------------------
-- The frame.
---------------------------------------------------------------------------
local function Build()
    panel = CreateFrame("Frame", "jsalUIProfessionPanel", UIParent)
    panel:SetWidth(WIDTH)
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:Hide()
    Style.Fill(panel, "window")
    Style.Border(panel, "lineStrong")
    Style.Shadow(panel)

    local bar = CreateFrame("Frame", nil, panel)
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("TOPRIGHT")
    bar:SetHeight(36)
    Style.Fill(bar, "titleBar")
    Style.Rule(bar, "BOTTOM", "line")
    local mark = bar:CreateTexture(nil, "ARTWORK")
    mark:SetTexture("Interface\\AddOns\\jsalUI\\Media\\Logo")
    mark:SetSize(18, 18)
    mark:SetPoint("LEFT", 12, 0)
    local divider = bar:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(Style.Color("lineStrong"))
    divider:SetSize(Compat.OnePixel(bar), 16)
    divider:SetPoint("LEFT", mark, "RIGHT", 10, 0)
    panel.title = Style.Text(bar, 13, "text", nil, true)
    panel.title:SetPoint("LEFT", divider, "RIGHT", 10, 0)
    Style.CloseButton(bar, 36, function()
        dismissed = anchor
        panel:Hide()
    end):SetPoint("TOPRIGHT")

    -- Where you stand: the rank's name, your skill, and one bar from the
    -- rank's first point to its cap with the next rank's training marked.
    panel.skill = Style.Text(panel, 12, "muted")
    panel.skill:SetPoint("TOPLEFT", PAD, -(36 + 14))
    panel.points = Style.Text(panel, 17, "text", nil, true)
    panel.points:SetPoint("TOPRIGHT", -PAD, -(36 + 9))
    panel.points:SetJustifyH("RIGHT")
    panel.track = CreateFrame("Frame", nil, panel)
    panel.track:SetSize(WIDTH - PAD * 2, 6)
    panel.track:SetPoint("TOPLEFT", PAD, -(36 + 36))
    Style.Fill(panel.track, "line")
    panel.fill = panel.track:CreateTexture(nil, "ARTWORK")
    panel.fill:SetPoint("TOPLEFT")
    panel.fill:SetPoint("BOTTOMLEFT")
    panel.fill:SetColorTexture(Style.Color("gold"))
    panel.marker = panel.track:CreateTexture(nil, "OVERLAY")
    panel.marker:SetColorTexture(Style.Color("muted"))
    panel.marker:SetSize(Compat.OnePixel(panel), 12)
    panel.from = Style.Text(panel, 11, "muted")
    panel.from:SetPoint("TOPLEFT", panel.track, "BOTTOMLEFT", 0, -5)
    panel.cap = Style.Text(panel, 11, "muted")
    panel.cap:SetPoint("TOPRIGHT", panel.track, "BOTTOMRIGHT", 0, -5)
    panel.cap:SetJustifyH("RIGHT")
    panel.markText = Style.Text(panel, 11, "muted")

    -- Two tabs, when there are recipes to learn: the panel shows one list
    -- at a time, so it stays shorter than the screen.
    panel.tabs = {}
    local tabW = (WIDTH - PAD * 2 - 6) / 2
    for i, key in ipairs({ "road", "recipes" }) do
        local b = Style.Button(panel, key == "road" and "Your road" or "Recipes to learn", "tab", tabW)
        b:SetHeight(TAB_H)
        b:SetPoint("TOPLEFT", PAD + (i - 1) * (tabW + 6), -(36 + 68))
        b:SetScript("OnClick", function()
            tab = key
            xpcall(Paint, ns.Report)
        end)
        panel.tabs[key] = b
    end

    panel.roadHead = Style.Text(panel, 12, "gold", nil, true)
    panel.roadNote = Style.Text(panel, 12, "muted")
    panel.roadNote:SetJustifyH("RIGHT")
    panel.thenHead = Style.Text(panel, 12, "gold", nil, true)
    panel.thenHead:SetText("THEN")
    panel.thenNote = Style.Text(panel, 12, "muted")
    panel.thenNote:SetJustifyH("RIGHT")
    panel.note = Style.Text(panel, 12, "muted")
    panel.note:SetWidth(WIDTH - PAD * 2)
    panel.rule = panel:CreateTexture(nil, "BORDER")
    panel.rule:SetColorTexture(Style.Color("line"))
    panel.rule:SetSize(WIDTH - PAD * 2, Compat.OnePixel(panel))
    panel.needHead = Style.Text(panel, 12, "gold", nil, true)
    panel.needNote = Style.Text(panel, 12, "muted")
    panel.needNote:SetJustifyH("RIGHT")
    panel.needNote:SetText("have / need")
    panel.where = Style.Text(panel, 12, "muted")
    panel.where:SetWidth(WIDTH - PAD * 2)
    panel.pin = Style.Button(panel, "Show trainer on map", "primary", WIDTH - PAD * 2)
    panel.pin:SetHeight(28)

    -- Recipes not learned yet: a rule, a heading with the count, and a
    -- "Show all" line under the first few.
    panel.rule2 = panel:CreateTexture(nil, "BORDER")
    panel.rule2:SetColorTexture(Style.Color("line"))
    panel.rule2:SetSize(WIDTH - PAD * 2, Compat.OnePixel(panel))
    panel.unlearnedHead = Style.Text(panel, 12, "gold", nil, true)
    panel.unlearnedHead:SetText("NOT LEARNED YET")
    panel.unlearnedCount = Style.Text(panel, 12, "muted")
    panel.unlearnedCount:SetJustifyH("RIGHT")
    panel.laterHead = Style.Text(panel, 12, "gold", nil, true)
    panel.laterHead:SetText("LATER")
    panel.laterCount = Style.Text(panel, 12, "muted")
    panel.laterCount:SetJustifyH("RIGHT")
    panel.showAll = CreateFrame("Button", nil, panel)
    panel.showAll:SetSize(WIDTH - PAD * 2, 18)
    panel.showAll.text = Style.Text(panel.showAll, 12, "muted")
    panel.showAll.text:SetPoint("LEFT")
end

-- The star beside a recipe: the game's favourite star, gold when on; a
-- plain dot where this client doesn't have that art.
local function SetStar(tex, on)
    local ok = tex.SetAtlas and pcall(tex.SetAtlas, tex, on and "auctionhouse-icon-favorite" or "auctionhouse-icon-favorite-off")
    if ok and tex.GetAtlas and tex:GetAtlas() then
        tex:SetVertexColor(1, 1, 1)
    else
        tex:SetTexture("Interface\\AddOns\\jsalUI\\Media\\Chess\\dot")
        tex:SetVertexColor(Style.Color(on and "gold" or "lineStrong"))
    end
end

local function UnlearnedRow(i)
    local r = unlearned[i]
    if r then return r end
    r = CreateFrame("Frame", nil, panel)
    r:SetSize(WIDTH - PAD * 2, ROW_H)
    r.star = CreateFrame("Button", nil, r)
    r.star:SetSize(16, 16)
    r.star:SetPoint("LEFT")
    r.star.tex = r.star:CreateTexture(nil, "ARTWORK")
    r.star.tex:SetAllPoints()
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(20, 20)
    r.icon:SetPoint("LEFT", 24, 0)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.source = Style.Text(r, 12, "muted")
    r.source:SetPoint("RIGHT")
    r.source:SetJustifyH("RIGHT")
    r.name = Style.Text(r, 13, "text")
    r.name:SetWordWrap(false)
    r.where = Style.Text(r, 12, "muted")
    r.where:SetWordWrap(false)
    r:EnableMouse(true)
    r:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.item then GameTooltip:SetItemByID(self.item) elseif self.spell then GameTooltip:SetSpellByID(self.spell) end
        local sources = self.detailed and ns.RecipeSourceText
        if sources and self.spell then
            GameTooltip:AddLine(" ")
            sources.Tooltip(GameTooltip, self.spell, self.faction)
            if self.canPin then GameTooltip:AddLine("Click for a map pin on the vendor.", 0.6, 0.59, 0.53) end
        end
        GameTooltip:AddLine("Click the star to keep it in your favourites.", 0.6, 0.59, 0.53)
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r:SetScript("OnMouseUp", function(self)
        if self.detailed and self.canPin and self.spell then
            ns.RecipeSourceText.Pin(self.spell, self.faction)
        end
    end)
    Style.Hover(r, 6)
    unlearned[i] = r
    return r
end

-- A row on one line, or on two with where the recipe comes from under its
-- name and the skill it needs on the right.
local function LayoutRow(r, detailed)
    r:SetHeight(detailed and DETAIL_H or ROW_H)
    r.name:ClearAllPoints()
    r.source:ClearAllPoints()
    r.where:ClearAllPoints()
    if detailed then
        r.source:SetPoint("TOPRIGHT", 0, -5)
        r.name:SetPoint("TOPLEFT", 52, -5)
        r.name:SetPoint("TOPRIGHT", -34, -5)
        r.where:SetPoint("TOPLEFT", 52, -23)
        r.where:SetPoint("TOPRIGHT", 0, -23)
        r.where:Show()
    else
        r.source:SetPoint("RIGHT")
        r.name:SetPoint("LEFT", r.icon, "RIGHT", 8, 0)
        r.name:SetPoint("RIGHT", r.source, "LEFT", -8, 0)
        r.where:Hide()
    end
end

-- The game's tooltip for what a row makes; a road step adds everything its
-- crafts need in full (its line has room for only a little), with what's
-- in your bags and bank.
local function Tooltip(frame)
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.item then GameTooltip:SetItemByID(self.item) elseif self.spell then GameTooltip:SetSpellByID(self.spell) end
        if self.needs and #self.needs > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(("For %d, you need:"):format(self.crafts or 1), 0.89, 0.69, 0.29)
            for _, reagent in ipairs(self.needs) do
                local need = reagent.count * (self.crafts or 1)
                local have = Compat.ItemCount(reagent.item, true)
                local enough = have >= need
                GameTooltip:AddDoubleLine(("%d  %s"):format(need, Compat.ItemName(reagent.item) or "..."),
                    ("have %d"):format(have), 1, 1, 1, enough and 0.34 or 1, enough and 0.58 or 0.42, enough and 0.31 or 0.42)
            end
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    Style.Hover(frame, 6)
end

-- A later step, on one line: the skill it covers, what to make and how
-- many; a line under it only when there's something to do first (learn it,
-- buy its pattern).
local function Step(i)
    local s = steps[i]
    if s then return s end
    s = CreateFrame("Frame", nil, panel)
    s:SetSize(WIDTH - PAD * 2, STEP_H)
    s.levels = Style.Text(s, 12, "muted")
    s.levels:SetPoint("TOPLEFT", 0, -6)
    s.icon = s:CreateTexture(nil, "ARTWORK")
    s.icon:SetSize(22, 22)
    s.icon:SetPoint("TOPLEFT", 74, -2)
    s.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    s.count = Style.Text(s, 13, "text", nil, true)
    s.count:SetPoint("TOPRIGHT", 0, -5)
    s.count:SetJustifyH("RIGHT")
    s.name = Style.Text(s, 13, "text")
    s.name:SetPoint("TOPLEFT", 104, -5)
    s.name:SetPoint("RIGHT", s.count, "LEFT", -8, 0)
    s.name:SetJustifyH("LEFT")
    s.name:SetWordWrap(false)
    s.detail = Style.Text(s, 11, "gold")
    s.detail:SetPoint("TOPLEFT", 104, -23)
    s.detail:SetWidth(WIDTH - PAD * 2 - 104)
    s.detail:SetJustifyH("LEFT")
    s.detail:SetWordWrap(false)
    s.rule = s:CreateTexture(nil, "BORDER")
    s.rule:SetColorTexture(Style.Color("line"))
    s.rule:SetPoint("BOTTOMLEFT")
    s.rule:SetPoint("BOTTOMRIGHT")
    s.rule:SetHeight(Compat.OnePixel(s))
    Tooltip(s)
    steps[i] = s
    return s
end

-- The step in hand, as a card: what to make, how many (and how many to be
-- safe), and each thing it takes with what you have of it.
local function Card()
    if panel.card then return panel.card end
    local card = CreateFrame("Frame", nil, panel)
    card:SetWidth(WIDTH - PAD * 2)
    Style.Fill(card, "well")
    card.edge = card:CreateTexture(nil, "ARTWORK")
    card.edge:SetColorTexture(Style.Color("gold"))
    card.edge:SetPoint("TOPLEFT")
    card.edge:SetPoint("BOTTOMLEFT")
    card.edge:SetWidth(3)
    card.icon = card:CreateTexture(nil, "ARTWORK")
    card.icon:SetSize(36, 36)
    card.icon:SetPoint("TOPLEFT", 14, -12)
    card.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    card.count = Style.Text(card, 20, "gold", nil, true)
    card.count:SetPoint("TOPRIGHT", -12, -10)
    card.count:SetJustifyH("RIGHT")
    card.safe = Style.Text(card, 11, "muted")
    card.safe:SetPoint("TOPRIGHT", -12, -36)
    card.safe:SetJustifyH("RIGHT")
    card.name = Style.Text(card, 15, "text", nil, true)
    card.name:SetPoint("TOPLEFT", 60, -11)
    card.name:SetPoint("RIGHT", card.count, "LEFT", -8, 0)
    card.name:SetJustifyH("LEFT")
    card.name:SetWordWrap(false)
    card.detail = Style.Text(card, 12, "muted")
    card.detail:SetPoint("TOPLEFT", 60, -33)
    card.detail:SetWidth(WIDTH - PAD * 2 - 60 - 12)
    card.detail:SetJustifyH("LEFT")
    card.detail:SetWordWrap(false)
    card.rule = card:CreateTexture(nil, "BORDER")
    card.rule:SetColorTexture(Style.Color("line"))
    card.rule:SetPoint("TOPLEFT", 14, -60)
    card.rule:SetSize(WIDTH - PAD * 2 - 28, Compat.OnePixel(card))
    card.mats = {}
    Tooltip(card)
    panel.card = card
    return card
end

local function Mat(card, i)
    local m = card.mats[i]
    if m then return m end
    m = CreateFrame("Frame", nil, card)
    m:SetSize(WIDTH - PAD * 2 - 28, MAT_H)
    m.icon = m:CreateTexture(nil, "ARTWORK")
    m.icon:SetSize(18, 18)
    m.icon:SetPoint("TOPLEFT", 0, -2)
    m.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    m.count = Style.Text(m, 13, "muted")
    m.count:SetPoint("TOPRIGHT", 0, -2)
    m.count:SetJustifyH("RIGHT")
    m.name = Style.Text(m, 13, "text")
    m.name:SetPoint("TOPLEFT", 26, -2)
    m.name:SetPoint("RIGHT", m.count, "LEFT", -8, 0)
    m.name:SetJustifyH("LEFT")
    m.name:SetWordWrap(false)
    m.note = Style.Text(m, 11, "muted")
    m.note:SetPoint("TOPLEFT", 26, -19)
    m.note:SetWidth(WIDTH - PAD * 2 - 28 - 26)
    m.note:SetJustifyH("LEFT")
    m.note:SetWordWrap(false)
    Tooltip(m)
    card.mats[i] = m
    return m
end

-- Training the next rank, as a row of its own on the road at the skill
-- it's open from. A click pins the nearest trainer who teaches it.
local function RankRow()
    if panel.rankRow then return panel.rankRow end
    local r = CreateFrame("Button", nil, panel)
    r:SetSize(WIDTH - PAD * 2, RANK_H - 4)
    Style.Fill(r, "well")
    r.edge = r:CreateTexture(nil, "ARTWORK")
    r.edge:SetColorTexture(Style.Color("gold"))
    r.edge:SetPoint("TOPLEFT")
    r.edge:SetPoint("BOTTOMLEFT")
    r.edge:SetWidth(3)
    r.title = Style.Text(r, 12, "gold", nil, true)
    r.title:SetPoint("TOPLEFT", 14, -4)
    r.sub = Style.Text(r, 11, "muted")
    r.sub:SetPoint("TOPLEFT", 14, -19)
    r.sub:SetWidth(WIDTH - PAD * 2 - 28)
    r.sub:SetJustifyH("LEFT")
    r.sub:SetWordWrap(false)
    r:SetScript("OnClick", function(self)
        if self.trainer and ns.Trainers then ns.Trainers.Pin(self.trainer) end
    end)
    r:SetScript("OnEnter", function(self)
        if not self.trainer then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Click to show the trainer on your map.", 0.6, 0.59, 0.53)
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    panel.rankRow = r
    return r
end

-- One line of everything the road needs: its name, and have / need.
local function Item(i)
    local r = items[i]
    if r then return r end
    r = CreateFrame("Frame", nil, panel)
    r:SetSize(WIDTH - PAD * 2, NEED_H)
    r.count = Style.Text(r, 12, "muted")
    r.count:SetPoint("RIGHT")
    r.count:SetJustifyH("RIGHT")
    r.name = Style.Text(r, 12, "text")
    r.name:SetPoint("LEFT")
    r.name:SetPoint("RIGHT", r.count, "LEFT", -8, 0)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    Tooltip(r)
    items[i] = r
    return r
end

local function Place(region, y, x)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", panel, "TOPLEFT", x or PAD, -y)
    region:Show()
end

local function PlaceRight(region, y)
    region:ClearAllPoints()
    region:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, -y)
    region:Show()
end

-- A recipe's name: the item it makes, or the spell for an enchant.
local function RecipeName(recipe)
    return recipe.label or (recipe.item and Compat.ItemName(recipe.item)) or (Compat.SpellInfo(recipe.spell)) or "..."
end

local function RecipeIcon(recipe)
    return (recipe.item and Compat.ItemIcon(recipe.item)) or select(2, Compat.SpellInfo(recipe.spell))
end

---------------------------------------------------------------------------
-- Painting.
---------------------------------------------------------------------------
function Paint()
    local name, skill, cap = Compat.OpenProfession()
    local line = Line(name)
    if not (line and skill and cap) then return panel:Hide() end
    panel.title:SetText(Professions.Name(line))

    -- Where the road goes: the skill the next rank is learned at while
    -- you're below it, else this rank's cap.
    local rank = Professions.Rank(cap)
    local rankIndex = 1
    for i, r in ipairs(Professions.RANKS) do if r == rank then rankIndex = i end end
    local floor = rankIndex > 1 and Professions.RANKS[rankIndex - 1].cap or 0
    panel.skill:SetText(rank.name)
    panel.points:SetText(skill)
    local width = WIDTH - PAD * 2
    local span = math.max(1, cap - floor)
    panel.fill:SetWidth(math.max(1, width * math.max(0, math.min(1, (skill - floor) / span))))
    panel.from:SetText(floor)
    panel.cap:SetText(cap)
    -- The next rank can be trained before this one's cap: marked on the bar
    -- until you're there.
    local ahead = rank.at ~= nil and skill < rank.at
    panel.marker:SetShown(ahead)
    panel.markText:SetShown(ahead)
    if ahead then
        local x = width * (rank.at - floor) / span
        panel.marker:ClearAllPoints()
        panel.marker:SetPoint("CENTER", panel.track, "LEFT", x, 0)
        panel.markText:SetText(("%d · train %s"):format(rank.at, rank.next))
        panel.markText:ClearAllPoints()
        panel.markText:SetPoint("TOP", panel.track, "BOTTOMLEFT", x, -5)
    end

    -- What you know, asked once for the whole list, and kept for the
    -- Professions page, which can't ask while this window is closed.
    local known, saved = {}, {}
    for _, recipe in ipairs(Professions.Recipes(line)) do
        known[recipe.spell] = Compat.KnowsRecipe(recipe.spell)
        if known[recipe.spell] then saved[#saved + 1] = recipe.spell end
    end
    Professions.Remember(line, skill, cap, saved)
    -- The road runs to this rank's cap, and no step runs across the skill
    -- the next rank is trained at, so that has a place of its own on it.
    local road, totals, stuck, made = Professions.Plan(line, skill, cap, function(spell) return known[spell] end, rank.at)

    -- Recipes not learned yet, with where each comes from: starred ones
    -- first, then by the skill they're learned at.
    local missing = {}
    local favourites = ns.ProfFavorites
    local wanted = ns.ProfWindow and ns.ProfWindow.On("unlearned") and favourites and not Professions.IsGathering(line)
    -- With "Where recipes come from" on: the ones your skill is high enough
    -- for come first, under their own heading, and each row names its source.
    local sources = wanted and ns.ProfWindow.On("sources") and ns.RecipeSourceText or nil
    local faction = sources and UnitFactionGroup and UnitFactionGroup("player") or nil
    local ready = 0
    if wanted then
        for _, recipe in ipairs(Professions.Recipes(line)) do
            if not known[recipe.spell] then
                missing[#missing + 1] = recipe
                if sources and recipe.learn <= skill then ready = ready + 1 end
            end
        end
        table.sort(missing, function(a, b)
            if sources then
                local ra, rb = a.learn <= skill, b.learn <= skill
                if ra ~= rb then return ra end
            end
            local fa, fb = favourites.Has(a.spell), favourites.Has(b.spell)
            if fa ~= fb then return fa end
            if a.learn ~= b.learn then return a.learn < b.learn end
            return a.spell < b.spell
        end)
    end

    -- With recipes to learn there are two tabs; without, only the road.
    local view = (#missing > 0 and tab == "recipes") and "recipes" or "road"
    local y = 36 + 68
    for key, b in pairs(panel.tabs) do
        b:SetShown(#missing > 0)
        b:SetSelected(key == view)
    end
    panel.tabs.recipes:SetLabel(("Recipes to learn  |cff9a9688%d|r"):format(#missing))
    if #missing > 0 then y = y + TAB_H + 12 end

    local shown, count, listed, later, mats, ranked = 0, 0, 0, false, 0, false
    if view == "road" then
        local crafts = 0
        for _, step in ipairs(road) do crafts = crafts + step.crafts end
        local unit = Professions.IsGathering(line) and "vein" or "craft"

        -- Training the next rank: from the skill it opens at, or now.
        local function Rank(y)
            local r = RankRow()
            local trainer = ns.Trainers and ns.Trainers.Nearest("skill" .. line, rankIndex + 1)
            local place = trainer and ns.Trainers.Zone(trainer)
            r.trainer = trainer
            r.title:SetText(skill >= rank.at and ("Train %s now"):format(rank.next) or ("At %d, train %s"):format(rank.at, rank.next))
            local parts = {}
            if trainer then parts[#parts + 1] = trainer.name .. (place and (", " .. place) or "") end
            if (UnitLevel("player") or 0) < rank.level then parts[#parts + 1] = ("needs level %d"):format(rank.level) end
            if #parts == 0 then parts[1] = "Any trainer for it can teach you" end
            r.sub:SetText(table.concat(parts, " · "))
            Place(r, y)
            ranked = true
            return RANK_H
        end

        -- The step in hand.
        local first = road[1]
        panel.roadHead:SetText(first and "DO THIS NOW" or (skill >= cap and "AT THE CAP" or "NOTHING TO MAKE YET"))
        Place(panel.roadHead, y + 2)
        panel.roadNote:SetText(first and ("%d → %d"):format(first.from, first.to) or "")
        PlaceRight(panel.roadNote, y + 2)
        y = y + 24
        if rank.at and skill >= rank.at then y = y + Rank(y) + 4 end
        if first then
            local card = Card()
            local recipe = first.recipe
            card.item, card.spell = recipe.item, recipe.spell
            card.needs, card.crafts = not recipe.vein and recipe.reagents or nil, first.crafts
            card.icon:SetTexture(RecipeIcon(recipe))
            card.name:SetText(RecipeName(recipe))
            card.count:SetText(("×%d"):format(first.crafts))
            card.safe:SetText((first.safe or 0) > first.crafts and ("%d to be safe"):format(first.safe) or "")
            if recipe.vein then
                card.detail:SetText(("Mine them: a sure point each until %d"):format(recipe.yellow))
            elseif first.buy then
                card.detail:SetText(ns.RecipeSourceText and ns.RecipeSourceText.BuyNote(recipe.spell)
                    or ("Buy the pattern from a vendor, from %d"):format(recipe.learn))
            elseif first.learn then
                card.detail:SetText(("Learn it at the trainer, from %d"):format(recipe.learn))
            elseif skill < recipe.yellow then
                card.detail:SetText(("a point every craft until %d"):format(recipe.yellow))
            else
                local odds = math.max(1, math.floor(Professions.Chance(recipe, skill) * 10 + 0.5))
                card.detail:SetText(odds >= 10 and "a point from nearly every craft" or ("a point from about %d crafts in 10"):format(odds))
            end
            local my = 68
            for i, reagent in ipairs(recipe.reagents) do
                mats = i
                local m = Mat(card, i)
                m:ClearAllPoints()
                m:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -my)
                m:Show()
                m.item, m.spell = reagent.item, nil
                local need = reagent.count * first.crafts
                local have = Compat.ItemCount(reagent.item, true)
                m.icon:SetTexture(Compat.ItemIcon(reagent.item))
                m.name:SetText(Compat.ItemName(reagent.item) or "...")
                m.count:SetText(("|cff%s%d|r / %d"):format(have >= need and Style.hex.green or Style.hex.red, have, need))
                local price = Professions.IsVendor(reagent.item)
                if have >= need then
                    m.note:SetText("you have enough")
                elseif price then
                    m.note:SetText(("vendor · %d more for %s"):format(need - have, Compat.Money((need - have) * price)))
                elseif Professions.MadeBy(line, reagent.item) then
                    m.note:SetText(("%d short · you can make it"):format(need - have))
                else
                    m.note:SetText(("%d short"):format(need - have))
                end
                my = my + MAT_H
            end
            card.rule:SetShown(mats > 0)
            card:SetHeight(mats > 0 and (my + 6) or 60)
            Place(card, y)
            y = y + card:GetHeight() + 8
            -- The step's crafts onto the shopping list.
            local shop = ns.Shopping and ns.Shopping.running and not recipe.vein
            if shop then
                if not panel.addStep then
                    panel.addStep = Style.Button(panel, "Add this step to my shopping list", "plain", WIDTH - PAD * 2)
                    panel.addStep:SetHeight(26)
                end
                panel.addStep:SetScript("OnClick", function() ns.Shopping.AddCraft(recipe.spell, first.crafts) end)
                Place(panel.addStep, y)
                y = y + 34
            elseif panel.addStep then
                panel.addStep:Hide()
            end
        else
            if panel.card then panel.card:Hide() end
            if panel.addStep then panel.addStep:Hide() end
        end

        -- The steps after it, one line each, with the next rank's training
        -- where it falls among them.
        local more = #road > 1 or (rank.at ~= nil and skill < rank.at)
        if more then
            y = y + 8
            Place(panel.thenHead, y + 2)
            panel.thenNote:SetText(crafts > 0 and ("to %d · about %d %s%s"):format(cap, crafts, unit, crafts == 1 and "" or "s") or "")
            PlaceRight(panel.thenNote, y + 2)
            y = y + 24
        else
            panel.thenHead:Hide()
            panel.thenNote:Hide()
        end
        for i = 2, #road do
            if i - 1 > MAX_STEPS then break end
            local step = road[i]
            if not ranked and rank.at and step.from >= rank.at then y = y + Rank(y) end
            shown = i - 1
            local s = Step(shown)
            s.item, s.spell = step.recipe.item, step.recipe.spell
            s.needs, s.crafts = not step.recipe.vein and step.recipe.reagents or nil, step.crafts
            s.levels:SetText(("%d → %d"):format(step.from, step.to))
            s.icon:SetTexture(RecipeIcon(step.recipe))
            s.name:SetText(RecipeName(step.recipe))
            s.count:SetText(("×%d"):format(step.crafts))
            local todo
            if step.buy then
                todo = ns.RecipeSourceText and ns.RecipeSourceText.BuyNote(step.recipe.spell)
                    or ("buy the pattern from a vendor, from %d"):format(step.recipe.learn)
            elseif step.learn then
                todo = ("learn it at the trainer, from %d"):format(step.recipe.learn)
            end
            s.detail:SetText(todo or "")
            s.detail:SetShown(todo ~= nil)
            s:SetHeight(STEP_H + (todo and NOTE_H or 0))
            Place(s, y)
            y = y + STEP_H + (todo and NOTE_H or 0)
        end
        -- A road that ends before the next rank opens still says when it does.
        if not ranked and rank.at and skill < rank.at and #road - 1 <= MAX_STEPS then y = y + Rank(y) end

        -- More steps than fit, or a road that stops short.
        local note
        if #road - 1 > MAX_STEPS then
            note = ("Then %d more step%s."):format(#road - 1 - MAX_STEPS, #road - 1 - MAX_STEPS == 1 and "" or "s")
        end
        if stuck then
            note = (note and (note .. " ") or "") .. ("Past %d, only patterns you'd have to find give skill."):format(stuck)
        elseif skill >= cap and not rank.at then
            note = "That's as far as it goes."
        end
        if note then
            panel.note:SetText(note)
            Place(panel.note, y + 4)
            y = y + panel.note:GetStringHeight() + 10
        else
            panel.note:Hide()
        end

        -- The whole road onto the shopping list at once.
        local crafting = {}
        for _, step in ipairs(road) do
            if not step.recipe.vein then crafting[#crafting + 1] = step end
        end
        if ns.Shopping and ns.Shopping.running and #crafting > 1 then
            if not panel.addRoad then
                panel.addRoad = Style.Button(panel, "Add the whole road to my shopping list", "plain", WIDTH - PAD * 2)
                panel.addRoad:SetHeight(26)
            end
            panel.addRoad:SetScript("OnClick", function()
                for _, step in ipairs(crafting) do ns.Shopping.AddCraft(step.recipe.spell, step.crafts) end
            end)
            Place(panel.addRoad, y + 4)
            y = y + 34
        elseif panel.addRoad then
            panel.addRoad:Hide()
        end

        -- Everything the road needs, the biggest shortfall first.
        local list = {}
        for item, need in pairs(totals) do
            list[#list + 1] = { item = item, need = need, have = Compat.ItemCount(item, true) }
        end
        table.sort(list, function(a, b)
            local sa, sb = a.need - a.have, b.need - b.have
            if sa ~= sb then return sa > sb end
            return a.item < b.item
        end)
        if #list > 0 then
            y = y + 8
            Place(panel.rule, y)
            y = y + 12
            panel.needHead:SetText(("EVERYTHING TO %d"):format(cap))
            Place(panel.needHead, y + 2)
            PlaceRight(panel.needNote, y + 2)
            y = y + 24
            for i, entry in ipairs(list) do
                if i > MAX_ITEMS then break end
                count = i
                local r = Item(i)
                Place(r, y)
                r.item, r.spell = entry.item, nil
                r.name:SetText(Compat.ItemName(entry.item) or "...")
                local color = entry.have >= entry.need and Style.hex.green or Style.hex.red
                r.count:SetText(("|cff%s%d|r / %d"):format(color, entry.have, entry.need))
                y = y + NEED_H
            end
            if #list > MAX_ITEMS then
                panel.needMore = panel.needMore or Style.Text(panel, 11, "muted")
                panel.needMore:SetText(("and %d more, in the shopping list"):format(#list - MAX_ITEMS))
                Place(panel.needMore, y + 2)
                y = y + 18
            elseif panel.needMore then
                panel.needMore:Hide()
            end
        else
            panel.rule:Hide()
            panel.needHead:Hide()
            panel.needNote:Hide()
            if panel.needMore then panel.needMore:Hide() end
        end
        panel.unlearnedHead:Hide()
        panel.unlearnedCount:Hide()
        panel.showAll:Hide()
    else
        for _, region in ipairs({ panel.roadHead, panel.roadNote, panel.thenHead, panel.thenNote, panel.note, panel.rule,
                                  panel.needHead, panel.needNote }) do
            region:Hide()
        end
        for _, key in ipairs({ "addRoad", "addStep", "card", "needMore" }) do
            if panel[key] then panel[key]:Hide() end
        end

        Place(panel.unlearnedHead, y + 2)
        panel.unlearnedHead:SetText(ready > 0 and "READY TO LEARN" or "NOT LEARNED YET")
        panel.unlearnedCount:SetText(ready > 0 and ready or #missing)
        PlaceRight(panel.unlearnedCount, y + 2)
        y = y + 24
        -- A tab of their own gives them room: more at first, and more again
        -- with Show all.
        local few = sources and 7 or 12
        local limit = showAllUnlearned and (sources and 14 or 22) or few
        for i, recipe in ipairs(missing) do
            if i > limit then break end
            listed = i
            if ready > 0 and i == ready + 1 then
                y = y + 6
                Place(panel.laterHead, y + 2)
                panel.laterCount:SetText(#missing - ready)
                PlaceRight(panel.laterCount, y + 2)
                later = true
                y = y + 24
            end
            local r = UnlearnedRow(i)
            Place(r, y)
            LayoutRow(r, sources ~= nil)
            r.item, r.spell = recipe.item, recipe.spell
            r.detailed, r.faction = sources ~= nil, faction
            r.icon:SetTexture(RecipeIcon(recipe))
            r.name:SetText(RecipeName(recipe))
            if sources then
                r.source:SetText(recipe.learn)
                r.source:SetTextColor(Style.Color(recipe.learn <= skill and "green" or "muted"))
                r.where:SetText(sources.Line(recipe.spell, faction) or SOURCE[recipe.how] or "Other")
                local vendor = sources.Vendors(recipe.spell, faction)[1]
                r.canPin = vendor and vendor.map and vendor.map > 0 or false
            else
                r.source:SetText(("%s · %d"):format(SOURCE[recipe.how] or "Other", recipe.learn))
                r.source:SetTextColor(Style.Color("muted"))
                r.canPin = false
            end
            SetStar(r.star.tex, favourites.Has(recipe.spell))
            r.star:SetScript("OnClick", function()
                favourites.Toggle(recipe.spell)
                xpcall(Paint, ns.Report)
            end)
            y = y + (sources and DETAIL_H or ROW_H)
        end
        if #missing > few then
            local rest = #missing - listed
            panel.showAll.text:SetText(showAllUnlearned
                and (rest > 0 and ("%d more · Show fewer"):format(rest) or "Show fewer")
                or ("%d more · Show all"):format(rest))
            panel.showAll:SetScript("OnClick", function()
                showAllUnlearned = not showAllUnlearned
                xpcall(Paint, ns.Report)
            end)
            Place(panel.showAll, y + 2)
            y = y + 22
        else
            panel.showAll:Hide()
        end
    end
    for i = shown + 1, #steps do steps[i]:Hide() end
    if panel.card then
        for i = mats + 1, #panel.card.mats do panel.card.mats[i]:Hide() end
    end
    if panel.rankRow and not ranked then panel.rankRow:Hide() end
    for i = count + 1, #items do items[i]:Hide() end
    for i = listed + 1, #unlearned do unlearned[i]:Hide() end
    panel.rule2:Hide()
    if not later then
        panel.laterHead:Hide()
        panel.laterCount:Hide()
    end

    -- The nearest trainer who teaches your rank, or the next one once
    -- you're ready for it, with a map pin.
    local needed = (rank.at and skill >= rank.at) and rankIndex + 1 or rankIndex
    local trainer = ns.Trainers and ns.Trainers.Nearest("skill" .. line, needed)
    if trainer then
        y = y + 10
        local place = ns.Trainers.Zone(trainer)
        panel.where:SetText(("Nearest trainer: |cffece6d6%s|r%s"):format(trainer.name, place and (", " .. place) or ""))
        Place(panel.where, y)
        y = y + 22
        panel.pin:SetScript("OnClick", function() ns.Trainers.Pin(trainer) end)
        Place(panel.pin, y)
        y = y + 28
    else
        panel.where:Hide()
        panel.pin:Hide()
    end
    panel:SetHeight(y + PAD)
end

---------------------------------------------------------------------------
-- Opening beside the profession window.
---------------------------------------------------------------------------
-- Whether the panel belongs on screen: its window is open and the panel
-- wasn't closed there.
local function Wanted()
    return Panel.running and anchor ~= nil and anchor:IsShown() and dismissed ~= anchor
end

-- The game's own window can have tabs sticking out of its right edge (one
-- per profession); the panel starts after them, measured on screen and put
-- in its own scale. A reach of more than a tab's width is something else (an
-- open menu), so it's ignored.
-- The shopping list opens beside the window the same way.
function ns.TabsReach(frame, beside)
    local reach, right = 0, frame:GetRight()
    if right then
        local scale = frame:GetEffectiveScale()
        local edges = { frame:GetChildren() }
        edges[#edges + 1] = frame.ProfessionsOverviewTab
        for _, tab in ipairs(frame.rightProfessionTabs or {}) do edges[#edges + 1] = tab end
        for _, child in ipairs(edges) do
            local edge = child ~= beside and child:IsShown() and child:GetRight()
            if edge then
                local past = edge * child:GetEffectiveScale() - right * scale
                if past > reach and past <= 100 * scale then reach = past end
            end
        end
        reach = reach / beside:GetEffectiveScale()
    end
    return reach
end

local function PlaceBeside(frame)
    local reach = ns.TabsReach(frame, panel)
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", frame, "TOPRIGHT", 6 + reach, 0)
end

local function OpenBeside(frame)
    if not Panel.running or dismissed == frame or not frame:IsShown() then return end
    if not panel then Build() end
    anchor = frame
    panel:SetFrameStrata(frame:GetFrameStrata())
    panel:SetFrameLevel(frame:GetFrameLevel() + 10)
    PlaceBeside(frame)
    panel:Show()
    xpcall(Paint, ns.Report)
    -- The panel opens a frame after the window, when the tabs may not have
    -- settled yet, so it measures them again a moment later.
    Compat.After(0.1, function()
        if anchor == frame and frame:IsShown() then PlaceBeside(frame) end
    end)
    -- If the profession's details weren't in yet, look again every tenth of
    -- a second for up to a second.
    local tries = 0
    local function Retry()
        tries = tries + 1
        if anchor ~= frame or not Wanted() or panel:IsShown() or tries > 10 then return end
        panel:Show()
        xpcall(Paint, ns.Report)
        if not panel:IsShown() then Compat.After(0.1, Retry) end
    end
    if not panel:IsShown() then Compat.After(0.1, Retry) end
end

local function Hook()
    if Compat.GamepadUI() then return end
    for _, find in ipairs(TARGETS) do
        local frame = find()
        if frame and not hooked[frame] then
            hooked[frame] = true
            -- Drawn a frame later, outside the game's own showing of it.
            frame:HookScript("OnShow", function()
                Compat.After(0, function() OpenBeside(frame) end)
            end)
            frame:HookScript("OnHide", function()
                if dismissed == frame then dismissed = nil end
                if anchor == frame and panel then
                    panel:Hide()
                    anchor = nil
                end
            end)
            if frame:IsShown() then OpenBeside(frame) end
        end
    end
end

-- Paints the panel again, if it is up.
function Panel.Refresh()
    if panel and panel:IsShown() then xpcall(Paint, ns.Report) end
end

function Panel:OnEnable()
    local events = CreateFrame("Frame")
    events:RegisterEvent("ADDON_LOADED")
    for _, event in ipairs({ "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED", "SKILL_LINES_CHANGED",
                             "BAG_UPDATE_DELAYED", "ITEM_DATA_LOAD_RESULT", "NEW_RECIPE_LEARNED" }) do
        pcall(events.RegisterEvent, events, event)
    end
    -- A burst of updates (crafting, item names arriving) repaints once. On
    -- the first open after a reload the profession's details arrive after
    -- the window shows, so an update also brings back a panel that hid
    -- for lack of them, unless it was closed, and does it on the next frame.
    local queued = false
    events:SetScript("OnEvent", function(_, event)
        if event == "ADDON_LOADED" then return Hook() end
        if not (panel and Wanted()) or queued then return end
        queued = true
        Compat.After(panel:IsShown() and 0.3 or 0, function()
            queued = false
            if Wanted() then
                panel:Show()
                xpcall(Paint, ns.Report)
            end
        end)
    end)
    self.events = events
    Hook()
end

function Panel:OnDisable()
    if self.events then self.events:UnregisterAllEvents() end
    if panel then panel:Hide() end
end
