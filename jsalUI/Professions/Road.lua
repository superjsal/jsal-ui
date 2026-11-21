-- The road to a profession's next rank, as it's drawn: the step in hand as a
-- card with what it takes and a strip along its foot, a stop with a round
-- sign for each later step, and a gold stop where the next rank is learned.
-- The panel beside the profession window draws its road down itself with
-- these; the Professions page draws its across the page. Also here: the row
-- for a rank you can train now, and the label under the skill bar's mark.
local _, ns = ...
local Style, Compat, Professions = ns.Style, ns.Compat, ns.Professions

local Road = {}
ns.Road = Road
Road.RANK_H = 38
local RANK_H = Road.RANK_H

-- A recipe's name: the item it makes, or the spell for an enchant.
function Road.RecipeName(recipe)
    return recipe.label or (recipe.item and Compat.ItemName(recipe.item)) or (Compat.SpellInfo(recipe.spell)) or "..."
end

function Road.RecipeIcon(recipe)
    return (recipe.item and Compat.ItemIcon(recipe.item)) or select(2, Compat.SpellInfo(recipe.spell))
end

-- What a craft of a step costs and sells for, and what a point of skill
-- comes to over the step after the sale's cut (below nothing when it
-- earns). The first result is false for a vein, or while Crafting profit is
-- off; with a material unpriced there's no cost, and `missing` is which.
local function Costs(recipe, crafts, points)
    if recipe.vein or not (Professions.Priced and Professions.Priced()) then return false end
    local cost, sells, missing = ns.CraftProfit.CraftPrice(recipe)
    if not cost then return true, nil, nil, nil, missing end
    -- A point costs what its crafts' materials do: what they'd sell for isn't taken off.
    return true, cost, sells, math.floor(cost * crafts / math.max(1, points) + 0.5)
end

-- What a road's part adds to the game's tooltip for what it makes. Its
-- facts, a line each: what it is on the left, the number on the right
-- ({ left, right, tone =, rtone = }; one with no right is words on a line of
-- their own). Then what its crafts need, as have / need, with what's in your
-- bags and bank counted. Last, what a click on it does. A part with a
-- `note` (a material) says that in gold.
function Road.Needs(self)
    if self.facts and #self.facts > 0 then
        GameTooltip:AddLine(" ")
        for _, fact in ipairs(self.facts) do
            local lr, lg, lb = Style.Color(fact.tone or "text")
            if fact[2] then
                local rr, rg, rb = Style.Color(fact.rtone or "text")
                GameTooltip:AddDoubleLine(fact[1], fact[2], lr, lg, lb, rr, rg, rb)
            else
                GameTooltip:AddLine(fact[1], lr, lg, lb, true)
            end
        end
    end
    if self.note then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(self.note, 0.89, 0.69, 0.29, true)
    end
    if self.needs and #self.needs > 0 then
        local gr, gg, gb = Style.Color("gold")
        local mr, mg, mb = Style.Color("muted")
        local tr, tg, tb = Style.Color("text")
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine(("For %d"):format(self.crafts or 1), "have / need", gr, gg, gb, mr, mg, mb)
        for _, reagent in ipairs(self.needs) do
            local need = reagent.count * (self.crafts or 1)
            local have = Compat.ItemCount(reagent.item, true)
            GameTooltip:AddDoubleLine(Compat.ItemName(reagent.item) or "...",
                ("|cff%s%d|r / %d"):format(have >= need and Style.hex.green or Style.hex.red, have, need), tr, tg, tb, mr, mg, mb)
        end
    end
    if self.hint then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(self.hint, Style.Color("muted"))
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
-- Learning the next rank, as a row of its own where the road reaches its
-- skill. A click pins the nearest trainer who teaches it, and its tooltip says so, not the
-- row's own words, which would run off the end of a long one. (`inline` is no longer read.)
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
    r:SetScript("OnEnter", function(self)
        if not self.trainer then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Click to show them on your map.", 0.6, 0.59, 0.53)
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
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
    end
    if not what and (UnitLevel("player") or 0) < rank.level then parts[#parts + 1] = ("needs level %d"):format(rank.level) end
    if #parts == 0 then parts[1] = "jsal.ui doesn't know a trainer for it" end
    r.sub:SetText(table.concat(parts, " · "))
end

---------------------------------------------------------------------------
-- The road drawn as a road: down the panel beside the profession window,
-- across the Professions page. The
-- step in hand is a card: what to make, how many, a line for each thing it
-- takes, and a strip along its foot. A later step is a stop: a round sign at
-- the skill it reaches, then what to make and how many. Where the next rank
-- is learned is a gold stop among them. Each says only what's needed to act
-- on it; the rest (what it costs, how surely it gives a point, where a
-- pattern is sold) is in its tooltip.
---------------------------------------------------------------------------
Road.STOP_H, Road.SIGN = 50, 38
-- A stop on a road that runs across the page has what it teaches under its
-- sign: this tall in all.
Road.ACROSS_H = 150
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

-- Where a click on a step puts the map pin, when the step asks something of
-- you first: on the vendor who sells its pattern (with where recipes come
-- from switched on, and their spot known), or on `trainer` for one that's
-- learned. Returns the click, and the words for it in the tooltip.
local function Way(step, trainer)
    local spell = step.recipe.spell
    if step.buy then
        local sources = ns.RecipeSourceText
        local who, faction
        if sources and sources.Seller then who, faction = sources.Seller(spell) end
        if who then return function() sources.Pin(spell, faction) end, "Click to pin the vendor on your map" end
    elseif step.learn and trainer and ns.Trainers then
        return function() ns.Trainers.Pin(trainer) end, "Click to pin the trainer on your map"
    end
end

-- A step's first facts for its tooltip: the skill it covers, then what it
-- asks of you first, with who sells or teaches it on a line of their own.
local function Facts(step, trainer)
    local recipe = step.recipe
    local facts = { { "On your road", ("%d to %d"):format(step.from, step.to), tone = "gold" } }
    if step.buy then
        local sources = ns.RecipeSourceText
        local who, copper, limited
        if sources and sources.BuyFrom then who, copper, limited = sources.BuyFrom(recipe.spell) end
        local other = not who and sources and sources.BuyNote and sources.BuyNote(recipe.spell)
        if who then
            facts[#facts + 1] = { "Buy the pattern", copper and Compat.Money(copper) or nil }
            facts[#facts + 1] = { who .. (limited and " · limited stock" or ""), tone = "muted" }
        elseif other then
            -- No vendor sells it to you: a drop, a quest, the other side's.
            facts[#facts + 1] = { "Get the pattern" }
            facts[#facts + 1] = { other, tone = "muted" }
        else
            facts[#facts + 1] = { "Buy the pattern", "from a vendor" }
        end
    elseif step.learn then
        facts[#facts + 1] = { "Learn at the trainer", ("from %d"):format(recipe.learn) }
        if trainer and ns.Trainers then
            local place = ns.Trainers.Zone(trainer)
            facts[#facts + 1] = { trainer.name .. (place and (", " .. place) or ""), tone = "muted" }
        end
    end
    return facts
end

-- What a point of skill comes to, as a fact.
local function PointFact(per)
    return { "A point", Compat.Money(per) }
end

-- A click on a part pins what its step set for it, if anything.
local function Pin(self)
    if self.pin then self.pin() end
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

-- Words along a card's foot that put something on the shopping list: gold,
-- lit under the pointer. Once the list has all of it, they say so in muted
-- words and aren't lit; a click then only opens the list.
function Road.ShopLink(parent, action, done, wide)
    local b = CreateFrame("Button", nil, parent)
    b.text = Style.Text(b, 12, "gold", nil, true)
    b.text:SetPoint("RIGHT")
    function b:SetListed(on)
        self.listed = on and true or false
        self.text:SetText(on and done or action)
        self.text:SetTextColor(Style.Color(on and "muted" or "gold"))
        self:SetSize(Style.Wide(self.text, wide), 22)
    end
    b:SetScript("OnEnter", function(self)
        if not self.listed then self.text:SetTextColor(Style.Color("goldHover")) end
    end)
    b:SetScript("OnLeave", function(self) self.text:SetTextColor(Style.Color(self.listed and "muted" or "gold")) end)
    b:SetListed(false)
    return b
end

function Road.NowCard(parent, width)
    local card = CreateFrame("Button", nil, parent)
    card:SetScript("OnClick", Pin)
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
    card.add = Road.ShopLink(card.strip, "Add to shopping list", "On your shopping list", 130)
    card.add:SetPoint("RIGHT", -13, 0)
    Style.ItemTip(card, Road.Needs, 6)
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
    Style.ItemTip(m, Road.Needs, nil, 0)
    card.mats[i] = m
    return m
end

-- Fills the card for the road's first step and sets its height. Returns how
-- many materials it shows. `trainer` is who a click pins when the step is
-- learned at one.
function Road.PaintNow(card, line, first, skill, trainer)
    local recipe = first.recipe
    card.pin, card.hint = Way(first, trainer)
    card.item, card.spell = recipe.item, recipe.spell
    card.needs, card.crafts = not recipe.vein and recipe.reagents or nil, first.crafts
    card.icon:SetTexture(Road.RecipeIcon(recipe))
    card.name:SetText(Road.RecipeName(recipe))
    card.count:SetText(("×%d"):format(first.crafts))
    -- Under the name, the one thing to know: what to do before you can
    -- make it; else what a point of skill costs; else how surely a craft
    -- gives one. The others are in the tooltip.
    local todo = Todo(first)
    local priced, cost, sells, per, missing = Costs(recipe, first.crafts, first.to - first.from)
    local pointLine = per and (Compat.Money(per) .. " a point") or nil
    local sure = Sure(recipe, skill)
    local said = todo or pointLine or sure or ""
    card.detail:SetText(said)
    card.detail:SetTextColor(Style.Color(todo and "gold" or "muted"))
    -- All of it in the tooltip, a line a fact.
    local facts = Facts(first, trainer)
    if cost then
        facts[#facts + 1] = { "To make", Compat.Money(cost) }
        facts[#facts + 1] = { "Sells for", sells and Compat.Money(sells) or "no price yet" }
        facts[#facts + 1] = PointFact(per)
    elseif priced then
        facts[#facts + 1] = { "No price yet for " .. (Compat.ItemName(missing) or "a material"), tone = "muted" }
    end
    local gives = sure and sure:match("^a point (.+)$")
    if gives then
        facts[#facts + 1] = { "Gives a point", gives }
    elseif sure then
        facts[#facts + 1] = { sure, tone = "muted" }
    end
    if (first.safe or 0) > first.crafts then facts[#facts + 1] = { "To be safe", ("make %d"):format(first.safe) } end
    card.facts = facts
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
    card.tall = shown > 0 and (y + NOW_STRIP) or NOW_TOP
    card:SetHeight(card.tall)
    return shown
end

-- A later step, a stop on the road: a round sign with the skill it reaches,
-- then what to make, a pill when there's something to do first, and how
-- many. Down a road they're on a line beside the sign; `across` one, under
-- it: the picture, the name on up to two lines, then how many and the pill.
-- A click on one with a pill puts the map pin where that's got.
function Road.Stop(parent, width, across)
    local s = CreateFrame("Button", nil, parent)
    s:SetScript("OnClick", Pin)
    s:SetSize(width, across and Road.ACROSS_H or Road.STOP_H)
    s.width, s.across = width, across and true or false
    s.sign = CreateFrame("Frame", nil, s)
    s.sign:SetSize(Road.SIGN, Road.SIGN)
    s.sign:SetPoint(across and "TOP" or "LEFT")
    s.disc = Style.Circle(s.sign, "well", "lineStrong")
    s.level = Style.Text(s.sign, 12, "text", nil, true)
    s.level:SetPoint("CENTER")
    s.level:SetJustifyH("CENTER")
    s.icon = s:CreateTexture(nil, "ARTWORK")
    s.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    s.count = Style.Text(s, 13, "text", nil, true)
    s.name = Style.Text(s, 13, "text")
    s.tag = Style.Tag(s, "", nil, true)
    if across then
        s.icon:SetSize(36, 36)
        s.icon:SetPoint("TOP", 0, -(Road.SIGN + 12))
        s.name:SetPoint("TOP", 0, -(Road.SIGN + 12 + 36 + 6))
        s.name:SetSize(width - 12, 32)
        s.name:SetJustifyH("CENTER")
        s.name:SetJustifyV("TOP")
        s.tag:SetPoint("LEFT", s.count, "RIGHT", 6, 0)
    else
        s.icon:SetSize(26, 26)
        s.icon:SetPoint("LEFT", Road.SIGN + 12, 0)
        s.count:SetPoint("RIGHT")
        s.count:SetJustifyH("RIGHT")
        s.name:SetPoint("LEFT", Road.SIGN + 12 + 26 + 10, 0)
        s.name:SetJustifyH("LEFT")
        s.name:SetWordWrap(false)
        s.tag:SetPoint("LEFT", s.name, "RIGHT", 8, 0)
    end
    Style.ItemTip(s, Road.Needs)
    return s
end

function Road.PaintStop(s, step, trainer)
    local recipe = step.recipe
    s.pin, s.hint = Way(step, trainer)
    s.item, s.spell = recipe.item, recipe.spell
    s.needs, s.crafts = not recipe.vein and recipe.reagents or nil, step.crafts
    s.level:SetText(step.to)
    s.icon:SetTexture(Road.RecipeIcon(recipe))
    s.count:SetText(("×%d"):format(step.crafts))
    local word = select(2, Todo(step))
    s.tag:SetShown(word ~= nil)
    if word then s.tag:Say(word) end
    if s.across then
        -- How many, and the pill after it, in the middle under the name.
        s.name:SetText(Road.RecipeName(recipe))
        s.count:ClearAllPoints()
        s.count:SetPoint("TOP", s, "TOP", word and -(s.tag.wide + 6) / 2 or 0, -(Road.SIGN + 12 + 36 + 6 + 34))
    else
        Fit(s.name, Road.RecipeName(recipe), s.width - (Road.SIGN + 48) - 44 - (word and s.tag.wide + 8 or 0))
    end
    -- In its tooltip: the skill it covers, what to do first, and what a
    -- point costs.
    local facts = Facts(step, trainer)
    local per = select(4, Costs(recipe, step.crafts, step.to - step.from))
    if per then facts[#facts + 1] = PointFact(per) end
    s.facts = facts
end

-- Learning the next rank, a gold stop where the road reaches its skill:
-- what to do, who teaches it, and "show on map". A click pins the trainer.
-- `across` a road, those are under the sign, a line each.
function Road.RankStop(parent, width, across)
    local r = CreateFrame("Button", nil, parent)
    r:SetSize(width, across and Road.ACROSS_H or Road.STOP_H)
    r.width, r.across = width, across and true or false
    r.sign = CreateFrame("Frame", nil, r)
    r.sign:SetSize(Road.SIGN, Road.SIGN)
    r.sign:SetPoint(across and "TOP" or "LEFT")
    Style.Circle(r.sign, "gold", "gold")
    r.level = Style.Text(r.sign, 12, "onGold", nil, true)
    r.level:SetPoint("CENTER")
    r.level:SetJustifyH("CENTER")
    r.link = Style.Text(r, 11, "muted")
    r.link:SetText("show on map")
    r.title = Style.Text(r, 13, "text", nil, true)
    r.sub = Style.Text(r, 12, "muted")
    r.sub:SetWordWrap(false)
    if across then
        -- Under the sign, each as wide as the stop and on two lines at most:
        -- a long one ("Learn Artisan from the quest Triage") ran past the
        -- stop's sides and over what stood beside it.
        r.title:SetPoint("TOP", 0, -(Road.SIGN + 14))
        r.title:SetWidth(width - 8)
        r.title:SetJustifyH("CENTER")
        r.sub:SetPoint("TOP", r.title, "BOTTOM", 0, -4)
        r.sub:SetWidth(width - 8)
        r.sub:SetWordWrap(true)
        r.sub:SetJustifyH("CENTER")
        for _, text in ipairs({ r.title, r.sub }) do
            if text.SetMaxLines then text:SetMaxLines(2) end
        end
        r.link:SetPoint("TOP", r.sub, "BOTTOM", 0, -6)
        r.link:SetJustifyH("CENTER")
    else
        r.link:SetPoint("RIGHT")
        r.link:SetJustifyH("RIGHT")
        r.title:SetPoint("LEFT", Road.SIGN + 12, 0)
        r.sub:SetPoint("LEFT", r.title, "RIGHT", 8, 0)
        r.sub:SetJustifyH("LEFT")
    end
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
    if r.across then
        r.sub:SetText(words)
    else
        Fit(r.sub, words, r.width - (Road.SIGN + 12) - Style.Wide(r.title, 110) - 8 - (trainer and 84 or 0))
    end
end
