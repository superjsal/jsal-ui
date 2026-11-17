-- The road to a profession's next rank, as it's drawn: the step in hand as a
-- card with what it takes, a later step on one line, and the row where the
-- next rank is learned. The Professions page draws its road with these. The
-- panel beside the profession window draws its as a road: the card with a
-- strip along its foot, a stop with a round sign for each later step, and a
-- gold stop where the next rank is learned (the parts at the end of this
-- file).
-- A part made `full` also shows what the step costs and what a point of
-- skill comes to (when Crafting profit has prices), and lists everything
-- the step needs in its tooltip.
local _, ns = ...
local Style, Compat, Professions = ns.Style, ns.Compat, ns.Professions

local Road = {}
ns.Road = Road
Road.STEP_H, Road.NOTE_H, Road.MAT_H, Road.RANK_H = 30, 14, 36, 38
local STEP_H, NOTE_H, MAT_H, RANK_H = Road.STEP_H, Road.NOTE_H, Road.MAT_H, Road.RANK_H

-- A recipe's name: the item it makes, or the spell for an enchant.
function Road.RecipeName(recipe)
    return recipe.label or (recipe.item and Compat.ItemName(recipe.item)) or (Compat.SpellInfo(recipe.spell)) or "..."
end

function Road.RecipeIcon(recipe)
    return (recipe.item and Compat.ItemIcon(recipe.item)) or select(2, Compat.SpellInfo(recipe.spell))
end

-- What a step costs to make and sells for, in a line, and what a point of
-- skill comes to after the sale. Nothing for a vein, or while Crafting
-- profit is off; a material with no price is named instead.
function Road.Priced(recipe, crafts, points)
    if recipe.vein or not (Professions.Priced and Professions.Priced()) then return nil end
    local cost, sells, missing = ns.CraftProfit.CraftPrice(recipe)
    if not cost then return "no price yet for " .. (Compat.ItemName(missing) or "a material"), nil end
    local line = Compat.Money(cost) .. " to make · " .. (sells and ("sells for " .. Compat.Money(sells)) or "no sale price yet")
    local net = cost - (sells and math.floor(sells * (1 - ns.ItemPrices.CUT)) or 0)
    local per = math.floor(net * crafts / math.max(1, points) + 0.5)
    if per < 0 then return line, "earns " .. Compat.Money(-per) .. " a point" end
    return line, Compat.Money(per) .. " a point"
end

-- A line of text that runs up to the price at its right, or to the edge
-- when there's none, and is cut short there, so a long one never runs
-- under the price.
local function EndBefore(text, x, y, row, price, edge)
    text:ClearAllPoints()
    text:SetPoint("TOPLEFT", x, y)
    if price then
        text:SetPoint("RIGHT", price, "LEFT", -10, 0)
    else
        text:SetPoint("RIGHT", row, "RIGHT", edge, 0)
    end
end

-- What a road step adds to the game's tooltip for what it makes: its note
-- in full when its line had room for only a few words, then everything its
-- crafts need (its line has room for only a little), with what's in your
-- bags and bank.
function Road.Needs(self)
    if self.note then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(self.note, 0.89, 0.69, 0.29, true)
    end
    if not (self.needs and #self.needs > 0) then return end
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

-- The label under the bar's mark for the next rank: centred on the mark,
-- unless that would run it off the bar or into the number at either end;
-- then it stops short of that number. With the mark at the cap itself the
-- label starts with the cap's number, so it takes that number's place.
-- `x` is how far along the bar the mark is, `width` the bar's length.
function Road.PlaceMark(mark, track, x, width, from, cap, atCap)
    local half = Style.Wide(mark, 120) / 2
    local left = Style.Wide(from, 20) + 10
    local right = width - (atCap and 0 or (Style.Wide(cap, 20) + 10))
    cap:SetShown(not atCap)
    mark:ClearAllPoints()
    if x + half > right then
        mark:SetPoint("TOPRIGHT", track, "BOTTOMLEFT", right, -5)
    elseif x - half < left then
        mark:SetPoint("TOPLEFT", track, "BOTTOMLEFT", left, -5)
    else
        mark:SetPoint("TOP", track, "BOTTOMLEFT", x, -5)
    end
end

---------------------------------------------------------------------------
-- The step in hand, as a card: what to make, how many (and how many to be
-- safe), and each thing it takes with what you have of it.
---------------------------------------------------------------------------
function Road.Card(parent, width, full)
    local card = CreateFrame("Frame", nil, parent)
    card:SetWidth(width)
    card.width, card.full = width, full and true or false
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
    card.detail:SetWidth(width - 60 - 12)
    card.detail:SetJustifyH("LEFT")
    card.detail:SetWordWrap(false)
    card.price = Style.Text(card, 11, "secondary")
    card.price:SetPoint("TOPLEFT", 60, -51)
    card.price:SetJustifyH("LEFT")
    card.price:SetWordWrap(false)
    card.price:Hide()
    card.perPoint = Style.Text(card, 11, "gold", nil, true)
    card.perPoint:SetPoint("TOPRIGHT", -12, -51)
    card.perPoint:SetJustifyH("RIGHT")
    card.perPoint:Hide()
    card.rule = card:CreateTexture(nil, "BORDER")
    card.rule:SetColorTexture(Style.Color("line"))
    card.rule:SetPoint("TOPLEFT", 14, -60)
    card.rule:SetSize(width - 28, Compat.OnePixel(card))
    card.mats = {}
    Style.ItemTip(card, card.full and Road.Needs or nil)
    return card
end

-- One thing the card's step takes: its name, have / need, and a line saying
-- where the rest comes from.
local function Mat(card, i)
    local m = card.mats[i]
    if m then return m end
    m = CreateFrame("Frame", nil, card)
    m:SetSize(card.width - 28, MAT_H)
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
    m.note:SetWidth(card.width - 28 - 26)
    m.note:SetJustifyH("LEFT")
    m.note:SetWordWrap(false)
    Style.ItemTip(m, card.full and Road.Needs or nil)
    card.mats[i] = m
    return m
end

-- Fills the card for the road's first step and sets its height. Returns how
-- many materials it shows.
function Road.PaintCard(card, line, first, skill)
    local recipe = first.recipe
    card.item, card.spell = recipe.item, recipe.spell
    card.needs, card.crafts = not recipe.vein and recipe.reagents or nil, first.crafts
    card.icon:SetTexture(Road.RecipeIcon(recipe))
    card.name:SetText(Road.RecipeName(recipe))
    card.count:SetText(("×%d"):format(first.crafts))
    card.safe:SetText((first.safe or 0) > first.crafts and ("%d to be safe"):format(first.safe) or "")
    if recipe.vein then
        card.detail:SetText(("Mine them: a sure point each until %d"):format(recipe.yellow))
    elseif first.buy then
        card.detail:SetText(ns.RecipeSourceText and ns.RecipeSourceText.BuyNote(recipe.spell)
            or ("Buy the pattern from a vendor, from %d"):format(recipe.learn))
    elseif first.learn then
        card.detail:SetText(("Learn it at the trainer, from %d"):format(recipe.learn))
    elseif not recipe.yellow then
        card.detail:SetText("")
    elseif skill < recipe.yellow then
        card.detail:SetText(("a point every craft until %d"):format(recipe.yellow))
    else
        local odds = Professions.Chance and math.max(1, math.floor(Professions.Chance(recipe, skill) * 10 + 0.5)) or 10
        card.detail:SetText(odds >= 10 and "a point from nearly every craft" or ("a point from about %d crafts in 10"):format(odds))
    end
    -- Priced, a line of what it costs and sells for, and a point's cost.
    local priceLine, pointLine
    if card.full then priceLine, pointLine = Road.Priced(recipe, first.crafts, first.to - first.from) end
    card.price:SetText(priceLine or "")
    card.price:SetShown(priceLine ~= nil)
    card.perPoint:SetText(pointLine or "")
    card.perPoint:SetShown(pointLine ~= nil)
    EndBefore(card.price, 60, -51, card, pointLine and card.perPoint, -12)
    local top = priceLine and 74 or 60
    card.rule:ClearAllPoints()
    card.rule:SetPoint("TOPLEFT", 14, -top)
    local my, shown = top + 8, 0
    for i, reagent in ipairs(recipe.reagents) do
        shown = i
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
        -- What's in your bank counts as yours, and is said to be there:
        -- "you have enough" of four hides that are all in the bank reads
        -- as four in your bags.
        local carried = Compat.ItemCount(reagent.item, false) or 0
        if have >= need and carried < need then
            m.note:SetText(("%d to fetch from your bank"):format(need - carried))
        elseif have >= need then
            m.note:SetText("you have enough")
        elseif price then
            m.note:SetText(("vendor · %d more for %s"):format(need - have, Compat.Money((need - have) * price)))
        elseif Professions.MadeBy and Professions.MadeBy(line, reagent.item) then
            m.note:SetText(("%d short · you can make it"):format(need - have))
        else
            m.note:SetText(("%d short"):format(need - have))
        end
        my = my + MAT_H
    end
    for i = shown + 1, #card.mats do card.mats[i]:Hide() end
    card.rule:SetShown(shown > 0)
    card:SetHeight(shown > 0 and (my + 6) or top)
    return shown
end

---------------------------------------------------------------------------
-- A later step, on one line: the skill it covers, what to make and how
-- many; a line under it only when there's something to do first (learn it,
-- buy its pattern) or, on a full one, a price to show. Beside a price, what
-- to do first is said in a few words, and in full in the tooltip.
---------------------------------------------------------------------------
function Road.Step(parent, width, full)
    local s = CreateFrame("Frame", nil, parent)
    s:SetSize(width, STEP_H)
    s.full = full and true or false
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
    s.perPoint = Style.Text(s, 11, "muted")
    s.perPoint:SetPoint("TOPRIGHT", 0, -23)
    s.perPoint:SetJustifyH("RIGHT")
    s.perPoint:Hide()
    s.detail = Style.Text(s, 11, "gold")
    s.detail:SetPoint("TOPLEFT", 104, -23)
    s.detail:SetJustifyH("LEFT")
    s.detail:SetWordWrap(false)
    Style.Rule(s, "BOTTOM", "line")
    Style.ItemTip(s, s.full and Road.Needs or nil)
    return s
end

-- Fills a step's line and sets its height, which it returns.
function Road.PaintStep(s, step)
    local recipe = step.recipe
    s.item, s.spell = recipe.item, recipe.spell
    s.needs, s.crafts = not recipe.vein and recipe.reagents or nil, step.crafts
    s.levels:SetText(("%d → %d"):format(step.from, step.to))
    s.icon:SetTexture(Road.RecipeIcon(recipe))
    s.name:SetText(Road.RecipeName(recipe))
    s.count:SetText(("×%d"):format(step.crafts))
    local todo, short
    if step.buy then
        todo = ns.RecipeSourceText and ns.RecipeSourceText.BuyNote(recipe.spell)
        if todo then
            short = ns.RecipeSourceText.BuyShort and ns.RecipeSourceText.BuyShort(recipe.spell)
        else
            todo, short = ("buy the pattern from a vendor, from %d"):format(recipe.learn), "pattern from a vendor"
        end
    elseif step.learn then
        todo, short = ("learn it at the trainer, from %d"):format(recipe.learn), ("trainer, from %d"):format(recipe.learn)
    end
    local point
    if s.full then point = select(2, Road.Priced(recipe, step.crafts, step.to - step.from)) end
    local said = (point and short) or todo
    s.note = said ~= todo and todo or nil
    s.detail:SetText(said or "")
    s.detail:SetShown(said ~= nil)
    s.perPoint:SetText(point or "")
    s.perPoint:SetShown(point ~= nil)
    EndBefore(s.detail, 104, -23, s, point and s.perPoint, 0)
    local tall = STEP_H + ((todo or point) and NOTE_H or 0)
    s:SetHeight(tall)
    return tall
end

---------------------------------------------------------------------------
-- Learning the next rank, as a row of its own where the road reaches its
-- skill. A click pins the nearest trainer who teaches it. `inline` says so
-- in the row's own words; without it the row says so in a tooltip.
---------------------------------------------------------------------------
function Road.RankRow(parent, width, inline)
    local r = CreateFrame("Button", nil, parent)
    r:SetSize(width, RANK_H - 4)
    r.inline = inline and true or false
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
    r.sub:SetWidth(width - 28)
    r.sub:SetJustifyH("LEFT")
    r.sub:SetWordWrap(false)
    r:SetScript("OnClick", function(self)
        if self.trainer and ns.Trainers then ns.Trainers.Pin(self.trainer) end
    end)
    if not r.inline then
        r:SetScript("OnEnter", function(self)
            if not self.trainer then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Click to show them on your map.", 0.6, 0.59, 0.53)
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    return r
end

-- Says what the next rank takes and who teaches it. Some ranks aren't a
-- trainer's to teach: a book, or a quest.
function Road.PaintRank(r, line, rank, rankIndex, rankAt, skill)
    local what, about, who
    if Professions.RankFrom then what, about, who = Professions.RankFrom(line, rank.next) end
    local trainer = who or (not what and ns.Trainers and ns.Trainers.Nearest("skill" .. line, rankIndex + 1)) or nil
    local place = trainer and ns.Trainers.Zone(trainer)
    r.trainer = trainer
    local doing = what or (rank.next and ("train " .. rank.next)) or ""
    r.title:SetText(skill >= rankAt and (doing:sub(1, 1):upper() .. doing:sub(2) .. " now") or ("At %d, %s"):format(rankAt, doing))
    local parts = {}
    if about and not who then parts[#parts + 1] = about end
    if trainer then
        parts[#parts + 1] = (who and (about .. " ") or "") .. trainer.name .. (place and (", " .. place) or "")
            .. (r.inline and " · click for a map pin" or "")
    end
    if not what and (UnitLevel("player") or 0) < rank.level then parts[#parts + 1] = ("needs level %d"):format(rank.level) end
    if #parts == 0 then parts[1] = "jsal.ui doesn't know a trainer for it" end
    r.sub:SetText(table.concat(parts, " · "))
end

---------------------------------------------------------------------------
-- The road drawn as a road, for the panel beside the profession window. The
-- step in hand is a card: what to make, how many, a line for each thing it
-- takes, and a strip along its foot. A later step is a stop: a round sign at
-- the skill it reaches, then what to make and how many. Where the next rank
-- is learned is a gold stop among them. Each says only what's needed to act
-- on it; the rest (what it costs, how surely it gives a point, where a
-- pattern is sold) is in its tooltip.
---------------------------------------------------------------------------
Road.STOP_H, Road.SIGN = 50, 38
local NOW_TOP, NOW_MAT, NOW_STRIP = 64, 30, 34

-- What a step asks of you before you can make it, and that in a word for a
-- pill: buy its pattern, or learn it at the trainer.
local function Todo(step)
    local recipe = step.recipe
    if step.buy then
        local note = ns.RecipeSourceText and ns.RecipeSourceText.BuyNote(recipe.spell)
        return note or ("Buy the pattern from a vendor, from %d"):format(recipe.learn), "pattern"
    elseif step.learn then
        return ("Learn it at the trainer, from %d"):format(recipe.learn), "learn"
    end
end

-- How surely a craft of it gives a point at your skill, in words.
local function Sure(recipe, skill)
    if recipe.vein then return ("Mine them: a sure point each until %d"):format(recipe.yellow) end
    if not recipe.yellow then return nil end
    if skill < recipe.yellow then return ("a point every craft until %d"):format(recipe.yellow) end
    local odds = Professions.Chance and math.max(1, math.floor(Professions.Chance(recipe, skill) * 10 + 0.5)) or 10
    return odds >= 10 and "a point from nearly every craft" or ("a point from about %d crafts in 10"):format(odds)
end

-- A name as wide as its words, cut short at `room`.
local function Fit(text, words, room)
    text:SetWidth(0)
    text:SetText(words)
    if Style.Wide(text, #words * 7) > room then text:SetWidth(room) end
end

function Road.NowCard(parent, width)
    local card = CreateFrame("Frame", nil, parent)
    card:SetWidth(width)
    card.width = width
    Style.Box(card, 6, "well", "cardLine")
    card.edge = Style.Edge(card, 6)
    card.icon = card:CreateTexture(nil, "ARTWORK")
    card.icon:SetSize(36, 36)
    card.icon:SetPoint("TOPLEFT", 14, -14)
    card.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    card.count = Style.Text(card, 17, "gold", nil, true)
    card.count:SetPoint("RIGHT", card, "TOPRIGHT", -14, -NOW_TOP / 2)
    card.count:SetJustifyH("RIGHT")
    card.name = Style.Text(card, 15, "text", nil, true)
    card.name:SetPoint("TOPLEFT", 62, -14)
    card.name:SetPoint("RIGHT", card.count, "LEFT", -8, 0)
    card.name:SetJustifyH("LEFT")
    card.name:SetWordWrap(false)
    card.detail = Style.Text(card, 12, "muted")
    card.detail:SetPoint("TOPLEFT", 62, -35)
    card.detail:SetPoint("RIGHT", card.count, "LEFT", -8, 0)
    card.detail:SetJustifyH("LEFT")
    card.detail:SetWordWrap(false)
    card.mats = {}
    -- Along its foot, round with the card: how its materials stand, and the
    -- way to put them on the shopping list.
    card.strip = CreateFrame("Frame", nil, card)
    card.strip:SetPoint("BOTTOMLEFT", 1, 1)
    card.strip:SetPoint("BOTTOMRIGHT", -1, 1)
    card.strip:SetHeight(NOW_STRIP)
    Style.Cap(card.strip, 5, "titleBar", "BOTTOM")
    Style.Rule(card.strip, "TOP", "cardLine")
    card.sum = Style.Text(card.strip, 12, "muted")
    card.sum:SetPoint("LEFT", 13, 0)
    card.add = CreateFrame("Button", nil, card.strip)
    card.add.text = Style.Text(card.add, 12, "gold", nil, true)
    card.add.text:SetPoint("RIGHT")
    card.add.text:SetText("Add to shopping list")
    card.add:SetSize(Style.Wide(card.add.text, 130), 22)
    card.add:SetPoint("RIGHT", -13, 0)
    card.add:SetScript("OnEnter", function(self) self.text:SetTextColor(Style.Color("goldHover")) end)
    card.add:SetScript("OnLeave", function(self) self.text:SetTextColor(Style.Color("gold")) end)
    Style.ItemTip(card, Road.Needs)
    return card
end

-- One thing the card's step takes, on a line: its picture and name, a pill
-- for where the rest of it is (your bank, a vendor, your own craft), and
-- have / need. Pointing at it says the rest.
local function NowMat(card, i)
    local m = card.mats[i]
    if m then return m end
    m = CreateFrame("Frame", nil, card)
    m:SetSize(card.width - 2, NOW_MAT)
    Style.Rule(m, "TOP", "line")
    m.icon = m:CreateTexture(nil, "ARTWORK")
    m.icon:SetSize(18, 18)
    m.icon:SetPoint("LEFT", 14, 0)
    m.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    m.count = Style.Text(m, 13, "muted")
    m.count:SetPoint("RIGHT", -14, 0)
    m.count:SetJustifyH("RIGHT")
    m.name = Style.Text(m, 13, "text")
    m.name:SetPoint("LEFT", 42, 0)
    m.name:SetJustifyH("LEFT")
    m.name:SetWordWrap(false)
    m.tag = Style.Tag(m, "", nil, true)
    m.tag:SetPoint("LEFT", m.name, "RIGHT", 8, 0)
    Style.ItemTip(m, Road.Needs)
    card.mats[i] = m
    return m
end

-- Fills the card for the road's first step and sets its height. Returns how
-- many materials it shows.
function Road.PaintNow(card, line, first, skill)
    local recipe = first.recipe
    card.item, card.spell = recipe.item, recipe.spell
    card.needs, card.crafts = not recipe.vein and recipe.reagents or nil, first.crafts
    card.icon:SetTexture(Road.RecipeIcon(recipe))
    card.name:SetText(Road.RecipeName(recipe))
    card.count:SetText(("×%d"):format(first.crafts))
    -- Under the name, the one thing to know: what to do before you can
    -- make it; else what a point of skill costs; else how surely a craft
    -- gives one. The others are in the tooltip.
    local todo = Todo(first)
    local priceLine, pointLine = Road.Priced(recipe, first.crafts, first.to - first.from)
    local sure = Sure(recipe, skill)
    local said = todo or pointLine or sure or ""
    card.detail:SetText(said)
    card.detail:SetTextColor(Style.Color(todo and "gold" or "muted"))
    local more = {}
    if sure and said ~= sure then more[#more + 1] = (sure:gsub("^%l", string.upper)) .. "." end
    if priceLine then more[#more + 1] = (priceLine:gsub("^%l", string.upper)) .. "." end
    if pointLine and said ~= pointLine then more[#more + 1] = (pointLine:gsub("^%l", string.upper)) .. "." end
    if (first.safe or 0) > first.crafts then more[#more + 1] = ("Make %d to be safe."):format(first.safe) end
    card.note = #more > 0 and table.concat(more, "\n") or nil
    local y, shown, short = NOW_TOP, 0, 0
    for i, reagent in ipairs(recipe.reagents) do
        shown = i
        local m = NowMat(card, i)
        m:ClearAllPoints()
        m:SetPoint("TOPLEFT", card, "TOPLEFT", 1, -y)
        m:Show()
        m.item, m.spell = reagent.item, nil
        local need = reagent.count * first.crafts
        local have = Compat.ItemCount(reagent.item, true)
        m.icon:SetTexture(Compat.ItemIcon(reagent.item))
        m.count:SetText(("|cff%s%d|r / %d"):format(have >= need and Style.hex.green or Style.hex.red, have, need))
        local price = Professions.IsVendor(reagent.item)
        -- What's in your bank counts as yours, and is said to be there:
        -- enough of four hides that are all in the bank reads as four in
        -- your bags.
        local carried = Compat.ItemCount(reagent.item, false) or 0
        local words
        if have >= need and carried < need then
            words, m.note = "bank", ("%d to fetch from your bank."):format(need - carried)
        elseif have >= need then
            m.note = "You have enough."
        elseif price then
            words, m.note = "vendor", ("%d more from a vendor, for %s."):format(need - have, Compat.Money((need - have) * price))
        elseif Professions.MadeBy and Professions.MadeBy(line, reagent.item) then
            words, m.note = "make", ("%d short: you can make it."):format(need - have)
        else
            m.note = ("%d short."):format(need - have)
        end
        if have < need then short = short + 1 end
        m.tag:SetShown(words ~= nil)
        if words then m.tag:Say(words) end
        Fit(m.name, Compat.ItemName(reagent.item) or "...", card.width - 2 - 42 - 14 - 78 - (words and m.tag.wide + 8 or 0))
        y = y + NOW_MAT
    end
    for i = shown + 1, #card.mats do card.mats[i]:Hide() end
    card.strip:SetShown(shown > 0)
    card.sum:SetText(("%d material%s, %s"):format(shown, shown == 1 and "" or "s", short == 0 and "all in hand" or (short .. " short")))
    card:SetHeight(shown > 0 and (y + NOW_STRIP) or NOW_TOP)
    return shown
end

-- A later step, a stop on the road: a round sign with the skill it reaches,
-- then what to make, a pill when there's something to do first, and how many.
function Road.Stop(parent, width)
    local s = CreateFrame("Frame", nil, parent)
    s:SetSize(width, Road.STOP_H)
    s.width = width
    s.sign = CreateFrame("Frame", nil, s)
    s.sign:SetSize(Road.SIGN, Road.SIGN)
    s.sign:SetPoint("LEFT")
    s.disc = Style.Circle(s.sign, "well", "lineStrong")
    s.level = Style.Text(s.sign, 12, "text", nil, true)
    s.level:SetPoint("CENTER")
    s.level:SetJustifyH("CENTER")
    s.icon = s:CreateTexture(nil, "ARTWORK")
    s.icon:SetSize(26, 26)
    s.icon:SetPoint("LEFT", Road.SIGN + 12, 0)
    s.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    s.count = Style.Text(s, 13, "text", nil, true)
    s.count:SetPoint("RIGHT")
    s.count:SetJustifyH("RIGHT")
    s.name = Style.Text(s, 13, "text")
    s.name:SetPoint("LEFT", Road.SIGN + 12 + 26 + 10, 0)
    s.name:SetJustifyH("LEFT")
    s.name:SetWordWrap(false)
    s.tag = Style.Tag(s, "", nil, true)
    s.tag:SetPoint("LEFT", s.name, "RIGHT", 8, 0)
    Style.ItemTip(s, Road.Needs)
    return s
end

function Road.PaintStop(s, step)
    local recipe = step.recipe
    s.item, s.spell = recipe.item, recipe.spell
    s.needs, s.crafts = not recipe.vein and recipe.reagents or nil, step.crafts
    s.level:SetText(step.to)
    s.icon:SetTexture(Road.RecipeIcon(recipe))
    s.count:SetText(("×%d"):format(step.crafts))
    local todo, word = Todo(step)
    s.tag:SetShown(word ~= nil)
    if word then s.tag:Say(word) end
    Fit(s.name, Road.RecipeName(recipe), s.width - (Road.SIGN + 48) - 44 - (word and s.tag.wide + 8 or 0))
    -- In its tooltip: what to do first, in full, and what a point costs.
    local more = {}
    if todo then more[#more + 1] = todo .. "." end
    local point = select(2, Road.Priced(recipe, step.crafts, step.to - step.from))
    if point then more[#more + 1] = (point:gsub("^%l", string.upper)) .. "." end
    more[#more + 1] = ("Takes your skill from %d to %d."):format(step.from, step.to)
    s.note = table.concat(more, "\n")
end

-- Learning the next rank, a gold stop where the road reaches its skill:
-- what to do, who teaches it, and "show on map". A click pins the trainer.
function Road.RankStop(parent, width)
    local r = CreateFrame("Button", nil, parent)
    r:SetSize(width, Road.STOP_H)
    r.width = width
    r.sign = CreateFrame("Frame", nil, r)
    r.sign:SetSize(Road.SIGN, Road.SIGN)
    r.sign:SetPoint("LEFT")
    Style.Circle(r.sign, "gold", "gold")
    r.level = Style.Text(r.sign, 12, "onGold", nil, true)
    r.level:SetPoint("CENTER")
    r.level:SetJustifyH("CENTER")
    r.link = Style.Text(r, 11, "muted")
    r.link:SetPoint("RIGHT")
    r.link:SetJustifyH("RIGHT")
    r.link:SetText("show on map")
    r.title = Style.Text(r, 13, "text", nil, true)
    r.title:SetPoint("LEFT", Road.SIGN + 12, 0)
    r.sub = Style.Text(r, 12, "muted")
    r.sub:SetPoint("LEFT", r.title, "RIGHT", 8, 0)
    r.sub:SetJustifyH("LEFT")
    r.sub:SetWordWrap(false)
    r:SetScript("OnClick", function(self)
        if self.trainer and ns.Trainers then ns.Trainers.Pin(self.trainer) end
    end)
    r:SetScript("OnEnter", function(self) self.link:SetTextColor(Style.Color("gold")) end)
    r:SetScript("OnLeave", function(self) self.link:SetTextColor(Style.Color("muted")) end)
    return r
end

-- Says what the next rank takes and who teaches it. Some ranks aren't a
-- trainer's to teach: a book, or a quest.
function Road.PaintRankStop(r, line, rank, rankIndex, rankAt, skill)
    local what, about, who
    if Professions.RankFrom then what, about, who = Professions.RankFrom(line, rank.next) end
    local trainer = who or (not what and ns.Trainers and ns.Trainers.Nearest("skill" .. line, rankIndex + 1)) or nil
    r.trainer = trainer
    r.level:SetText(rankAt)
    local doing = what or (rank.next and ("train " .. rank.next)) or ""
    r.title:SetText(doing:sub(1, 1):upper() .. doing:sub(2) .. (skill >= rankAt and " now" or ""))
    local parts = {}
    if about and not who then parts[#parts + 1] = about end
    if trainer then parts[#parts + 1] = (who and (about .. " ") or "") .. trainer.name end
    if not what and (UnitLevel("player") or 0) < rank.level then parts[#parts + 1] = ("needs level %d"):format(rank.level) end
    if #parts == 0 then parts[1] = "jsal.ui doesn't know a trainer for it" end
    r.link:SetShown(trainer ~= nil)
    local words = table.concat(parts, " · ")
    Fit(r.sub, words, r.width - (Road.SIGN + 12) - Style.Wide(r.title, 110) - 8 - (trainer and 84 or 0))
end
