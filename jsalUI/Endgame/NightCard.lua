-- The Endgame page's RAID NIGHT card: WoWSims' consumables for your spec, for the nights you stock
-- for and a night's length you set. A line for each one still short: its picture and name, how
-- many to get, and what that costs (the shopping list's own prices: a vendor's, else an auction
-- price), "you make it" where you do, or "no price". Under the pointer a line shows − and + for
-- its count a night, and an x that takes it off (remembered; "N taken off · show" brings it back).
-- What you have enough of is small pictures; then the total, and a switch that keeps it all on
-- the shopping list. What it works out is RaidNight's.
local _, ns = ...
local Style, Compat = ns.Style, ns.Compat

-- A row is 26 tall, or 42 for a name that takes two lines; the count's column is 40 wide (its - and + inside
-- it), the price's 72, room for "123g 45s" with its coins.
local PAD, ROW, TALL, GET_W, COST_W, X_W = 16, 26, 42, 40, 72, 16
local MAX_ENOUGH = 10
local MUTED, GOLD = "|cff9a9688", "|cffe3b04b"

-- How long a buff lasts, in words: "2 hours", "30 min".
local function Lasts(seconds)
    if seconds >= 3600 then
        local h = seconds / 3600
        return (h == math.floor(h) and ("%d hour%s"):format(h, h == 1 and "" or "s")) or ("%.1f hours"):format(h)
    end
    return ("%d min"):format(math.floor(seconds / 60 + 0.5))
end

-- A small − or + that lights up under the pointer.
local function Sign(parent, glyph)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(14, 20)
    b.text = Style.Text(b, 14, "secondary", nil, true)
    b.text:SetPoint("CENTER")
    b.text:SetText(glyph)
    b:SetScript("OnEnter", function(self) self.text:SetTextColor(Style.Color("gold")) end)
    b:SetScript("OnLeave", function(self) self.text:SetTextColor(Style.Color("secondary")) end)
    return b
end

-- A count in a pill with − and + at its ends: `get` and `set` read and change it.
local function Stepper(parent, get, set)
    local s = CreateFrame("Frame", nil, parent)
    s:SetSize(62, 22)
    Style.PillBox(s, "titleBar", "lineStrong")
    s.count = Style.Text(s, 13, "text", nil, true)
    s.count:SetPoint("CENTER")
    s.minus = Sign(s, "-")
    s.minus:SetPoint("LEFT", 4, 0)
    s.plus = Sign(s, "+")
    s.plus:SetPoint("RIGHT", -4, 0)
    s.minus:SetScript("OnClick", function() set(get() - 1) end)
    s.plus:SetScript("OnClick", function() set(get() + 1) end)
    function s:Paint() self.count:SetText(get()) end
    return s
end

local function Caps(parent, words)
    local t = Style.Text(parent, 11, "muted", nil, true)
    t:SetText(words)
    return t
end

-- The card, `width` wide. Paint(room) fills it in no more than `room` of height and returns its
-- height; `changed` is called after anything on it changes what the page shows.
function ns.EndgameNight(parent, width, changed)
    local RN = ns.RaidNight
    local card = CreateFrame("Frame", nil, parent)
    card:SetWidth(width)
    Style.Box(card, 6, "well", "cardLine")
    local inner = width - 2 * PAD
    local nameW = inner - 28 - GET_W - 6 - COST_W
    local function Changed()
        if changed then changed() end
    end

    local title = Style.Text(card, 12, "gold", nil, true)
    title:SetPoint("TOPLEFT", PAD, -14)
    title:SetText("RAID NIGHT")
    local whose = Style.Text(card, 12, "muted")
    whose:SetPoint("TOPRIGHT", -PAD, -14)
    whose:SetJustifyH("RIGHT")
    local rule = card:CreateTexture(nil, "ARTWORK")
    rule:SetColorTexture(Style.Color("line"))
    rule:SetPoint("TOPLEFT", PAD, -38)
    rule:SetPoint("TOPRIGHT", -PAD, -38)
    rule:SetHeight(1)
    local intro = Style.Text(card, 12, "muted")
    intro:SetWidth(inner)
    intro:SetJustifyH("LEFT")
    -- Simple (the list's main slots) or Max DPS (all of it).
    local choice = Style.Tabs(card, { { "simple", "Simple" }, { "max", "Max DPS" } }, function(key)
        RN.SetMax(key == "max")
        Changed()
    end, nil, true)

    -- Stock for [− 1 +] nights · N to get; a night is [− 3 +] hours.
    local stockFor = Style.Text(card, 13, "text")
    stockFor:SetText("Stock for")
    local nights = Stepper(card, function() return RN.Saved().nights end, function(n) RN.SetNights(n) Changed() end)
    nights:SetPoint("LEFT", stockFor, "RIGHT", 8, 0)
    local nightWord = Style.Text(card, 13, "text")
    nightWord:SetPoint("LEFT", nights, "RIGHT", 8, 0)
    local toGet = Style.Text(card, 13, "muted", nil, true)
    toGet:SetJustifyH("RIGHT")
    local aNight = Style.Text(card, 12, "muted")
    aNight:SetText("A night is")
    local hours = Stepper(card, function() return RN.Saved().hours end, function(n) RN.SetHours(n) Changed() end)
    hours:SetPoint("LEFT", aNight, "RIGHT", 8, 0)
    local hourWord = Style.Text(card, 12, "muted")
    hourWord:SetPoint("LEFT", hours, "RIGHT", 8, 0)
    local headFor, headGet, headCost = Caps(card, "FOR ONE NIGHT"), Caps(card, "GET"), Caps(card, "COSTS")
    headGet:SetJustifyH("CENTER")
    headCost:SetJustifyH("RIGHT")

    local rows = {}
    -- A row, made the first time it's needed and kept.
    local function Row(i)
        if rows[i] then return rows[i] end
        local r = CreateFrame("Button", nil, card)
        r:SetSize(inner, ROW)
        r:RegisterForClicks("LeftButtonUp")
        r.rule = r:CreateTexture(nil, "ARTWORK")
        r.rule:SetColorTexture(Style.Color("line"))
        r.rule:SetPoint("BOTTOMLEFT")
        r.rule:SetPoint("BOTTOMRIGHT")
        r.rule:SetHeight(1)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(20, 20)
        r.icon:SetPoint("LEFT")
        r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.name = Style.Text(r, 13, "text")
        r.name:SetPoint("LEFT", r.icon, "RIGHT", 8, 0)
        r.name:SetWidth(nameW)
        r.name:SetWordWrap(false)
        r.name:SetJustifyH("LEFT")
        r.get = Style.Text(r, 13, "text", nil, true)
        r.get:SetPoint("CENTER", r, "RIGHT", -(COST_W + 6 + GET_W / 2), 0)
        r.minus = Sign(r, "-")
        r.minus:SetPoint("RIGHT", r, "RIGHT", -(COST_W + 6 + GET_W - 14), 0)
        r.plus = Sign(r, "+")
        r.plus:SetPoint("LEFT", r, "RIGHT", -(COST_W + 6 + 14), 0)
        r.cost = Style.Text(r, 12, "text")
        r.cost:SetPoint("RIGHT")
        r.cost:SetJustifyH("RIGHT")
        r.cost:SetWidth(COST_W)
        r.cost:SetWordWrap(false)
        r.x = CreateFrame("Button", nil, r)
        r.x:SetSize(X_W, ROW)
        r.x:SetPoint("RIGHT")
        r.x.text = Style.Text(r.x, 14, "muted")
        r.x.text:SetPoint("CENTER")
        r.x.text:SetText("×")
        r.glow = r:CreateTexture(nil, "BACKGROUND", nil, 7)
        r.glow:SetAllPoints()
        local tr, tg, tb = Style.Color("text")
        r.glow:SetColorTexture(tr, tg, tb, 0.06)
        -- Lit while the pointer is on the row or one of its buttons: the row's light, the − and +, the x
        -- (red under the pointer) in the price's place, and the line's tooltip. It is read from where the
        -- pointer is, never from which enter or leave came last, so the same state results whatever order
        -- the game sends them in. `may` is false where the row can't be lit: a redraw passes whether it
        -- was lit, so a line that moves up under the pointer is lit for what it now holds, and a row
        -- under another window, which the game sends nothing, stays dark.
        local function Light(may)
            local on = may and r:IsVisible() and r:IsMouseOver() or false
            r.lit = on
            local live = on and r.line ~= nil
            r.glow:SetShown(on)
            r.minus:SetShown(live)
            r.plus:SetShown(live)
            r.x:SetShown(live)
            r.cost:SetShown(not live)
            r.x.text:SetTextColor(Style.Color(live and r.x:IsMouseOver() and "red" or "muted"))
            if on and r.item then
                GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
                GameTooltip:SetItemByID(r.item)
                for _, line in ipairs(r.notes or {}) do GameTooltip:AddLine(line, Style.Color("text")) end
                GameTooltip:Show()
            elseif GameTooltip:IsOwned(r) then
                GameTooltip:Hide()
            end
        end
        r.Light = Light
        local function Pointer() Light(true) end
        r:SetScript("OnEnter", Pointer)
        r:SetScript("OnLeave", Pointer)
        for _, b in ipairs({ r.minus, r.plus }) do
            b:HookScript("OnEnter", Pointer)
            b:HookScript("OnLeave", Pointer)
        end
        r.x:SetScript("OnEnter", Pointer)
        r.x:SetScript("OnLeave", Pointer)
        r.minus:SetScript("OnClick", function() if r.line then RN.SetCount(r.line, r.per - 1) Changed() end end)
        r.plus:SetScript("OnClick", function() if r.line then RN.SetCount(r.line, r.per + 1) Changed() end end)
        r.x:SetScript("OnClick", function() if r.item then RN.TakeOff(r.item, true) Changed() end end)
        -- A line taken off: a click puts it back.
        r:SetScript("OnClick", function(self) if self.back then RN.TakeOff(self.item, false) Changed() end end)
        Light(false)
        rows[i] = r
        return r
    end

    -- "2 taken off · show"; the lines taken off show under it, each put back with a click.
    local showOff = false
    local offLink = CreateFrame("Button", nil, card)
    offLink.text = Style.Text(offLink, 12, "muted")
    offLink.text:SetPoint("LEFT")
    offLink:SetScript("OnClick", function() showOff = not showOff Changed() end)
    offLink:SetScript("OnEnter", function(self) self.text:SetTextColor(Style.Color("text")) end)
    offLink:SetScript("OnLeave", function(self) self.text:SetTextColor(Style.Color("muted")) end)

    local enoughLabel = Style.Text(card, 12, "muted")
    enoughLabel:SetText("You have enough of")
    local enough = {}
    for i = 1, MAX_ENOUGH do
        local t = card:CreateTexture(nil, "ARTWORK")
        t:SetSize(18, 18)
        t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        t:SetAlpha(0.45)
        enough[i] = t
    end
    local enoughMore = Style.Text(card, 12, "muted")
    local totalRule = card:CreateTexture(nil, "ARTWORK")
    totalRule:SetColorTexture(Style.Color("line"))
    totalRule:SetHeight(1)
    local total = Style.Text(card, 13, "muted")
    total:SetWidth(inner)
    total:SetWordWrap(false)
    total:SetJustifyH("LEFT")
    local switchRule = card:CreateTexture(nil, "ARTWORK")
    switchRule:SetColorTexture(Style.Color("line"))
    switchRule:SetHeight(1)
    local switch = Style.Switch(card, function(on)
        RN.SetListed(on)
        Changed()
    end)
    local switchLabel = Style.Text(card, 13, "text", nil, true)
    switchLabel:SetText("Keep it on my shopping list")
    switchLabel:SetPoint("LEFT", switch, "RIGHT", 10, 0)
    local switchNote = Style.Text(card, 12, "muted")
    switchNote:SetWidth(inner)
    switchNote:SetJustifyH("LEFT")
    local none = Style.Text(card, 13, "muted")
    none:SetPoint("TOPLEFT", PAD, -50)
    none:SetWidth(inner)
    none:SetJustifyH("LEFT")
    card.rows, card.parts = rows, { switch = switch, total = total, toGet = toGet, offLink = offLink, enough = enough,
                                     whose = whose, none = none, intro = intro, switchNote = switchNote, enoughLabel = enoughLabel,
                                     choice = choice }
    return card, {
        Row = Row, offLink = offLink, setShowOff = function(on) showOff = on end, showOff = function() return showOff end,
        stockFor = stockFor, nights = nights, nightWord = nightWord, aNight = aNight, hours = hours, hourWord = hourWord,
        heads = { headFor, headGet, headCost }, enoughLabel = enoughLabel, enough = enough, enoughMore = enoughMore,
        totalRule = totalRule, total = total, switchRule = switchRule, switch = switch, switchLabel = switchLabel,
        switchNote = switchNote, none = none, intro = intro, whose = whose, toGet = toGet, inner = inner, choice = choice,
        nameW = nameW,
    }
end

-- A cost as the card writes it: to the silver once it's a gold or more, to the gold from a hundred, so it
-- fits its column whole.
function ns.EndgameNightRounded(copper)
    if copper >= 1000000 then return math.floor(copper / 10000 + 0.5) * 10000 end
    if copper >= 10000 then return math.floor(copper / 100 + 0.5) * 100 end
    return copper
end

-- The words of a line's price: what the short ones cost, "you cook it" / "you make it", or
-- "no price". Returns the words and the copper (nil for none).
function ns.EndgameNightCost(line)
    local Shopping = ns.Shopping
    local recipe, profession
    if Shopping and Shopping.MakerOf then recipe, profession = Shopping.MakerOf(line.item) end
    if recipe then return profession == 185 and "you cook it" or "you make it", nil, true end
    local price = ns.ItemPrices and ns.ItemPrices.Of(line.item)
    if not price then return MUTED .. "no price|r", nil end
    local cost = price * line.short
    return Compat.Money(ns.EndgameNightRounded(cost)), cost
end

-- What a line's tooltip adds: how long it lasts and what a night takes, and what you have.
function ns.EndgameNightNotes(line, hours)
    local notes = {}
    if line.own then
        notes[1] = ("Your count: %d a night."):format(line.per)
    elseif (line.lasts or 0) > 0 then
        notes[1] = ("Lasts %s: %d for a %d-hour night."):format(Lasts(line.lasts), line.per, hours)
    else
        notes[1] = ("Used in the moment: %d a night."):format(line.per)
    end
    notes[2] = ("You have %d of %d."):format(line.have, line.want)
    notes[3] = MUTED .. "- and + change a night's count; the x takes it off.|r"
    return notes
end

-- Fills the card from top to bottom in `room`; returns its height.
function ns.EndgameNightPaint(card, p, room)
    local RN = ns.RaidNight
    local saved = RN.Saved()
    local spec, list, setName = RN.Spec()
    local below = (ns.Pretend and ns.Pretend.Level() or UnitLevel("player") or 0) < 60
    local whose = setName and ("WoWSims' " .. setName) or (spec and ("WoWSims' " .. RN.ListWords(spec))) or ""
    p.whose:SetText(list and (whose .. " · " .. (saved.max and "max DPS" or "simple")) or whose)
    local parts = { p.stockFor, p.nights, p.nightWord, p.aNight, p.hours, p.hourWord, p.toGet, p.totalRule, p.total,
                    p.switchRule, p.switch, p.switchLabel, p.switchNote, p.heads[1], p.heads[2], p.heads[3], p.choice }
    if not list then
        for _, r in ipairs(parts) do r:Hide() end
        for _, r in ipairs(card.rows) do r:Hide() end
        p.offLink:Hide() p.enoughLabel:Hide() p.enoughMore:Hide() p.intro:Hide()
        for _, t in ipairs(p.enough) do t:Hide() end
        p.none:SetText(("WoWSims gives no consumables for %s yet, so there's nothing to stock."):format(spec and RN.SpecWords(spec) or "your spec"))
        p.none:Show()
        card:SetHeight(96)
        return 96
    end
    p.none:Hide()
    for _, r in ipairs(parts) do r:Show() end
    local y = 50
    local function At(region, x, dy)
        region:ClearAllPoints()
        region:SetPoint("TOPLEFT", card, "TOPLEFT", PAD + (x or 0), -(y + (dy or 0)))
    end
    p.intro:SetShown(below)
    if below then
        At(p.intro)
        p.intro:SetText(("What %s take to a raid. Most of it keeps: stock up as you go."):format(
            setName and ("WoWSims' " .. setName .. " sims") or ("WoWSims' sims for " .. RN.SpecWords(spec))))
        y = y + 40
    end
    -- Simple or Max DPS.
    At(p.choice)
    p.choice:Pick(saved.max and "max" or "simple")
    y = y + 36
    -- The nights and the length.
    p.stockFor:ClearAllPoints()
    p.stockFor:SetPoint("LEFT", card, "TOPLEFT", PAD, -(y + 11))
    p.nights:Paint()
    p.nightWord:SetText(saved.nights == 1 and "night" or "nights")
    p.aNight:ClearAllPoints()
    p.aNight:SetPoint("LEFT", card, "TOPLEFT", PAD, -(y + 41))
    p.hours:Paint()
    p.hourWord:SetText(saved.hours == 1 and "hour" or "hours")
    p.toGet:ClearAllPoints()
    p.toGet:SetPoint("RIGHT", card, "TOPRIGHT", -PAD, -(y + 11))
    y = y + 62
    -- The column heads.
    p.heads[1]:SetText(saved.nights == 1 and "FOR ONE NIGHT" or ("FOR %d NIGHTS"):format(saved.nights))
    At(p.heads[1], 28)
    p.heads[2]:ClearAllPoints()
    p.heads[2]:SetPoint("TOP", card, "TOPRIGHT", -(PAD + COST_W + 6 + GET_W / 2), -y)
    p.heads[3]:ClearAllPoints()
    p.heads[3]:SetPoint("TOPRIGHT", card, "TOPRIGHT", -PAD, -y)
    y = y + 18

    local lines, off = RN.Lines()
    local short, full = {}, {}
    for _, line in ipairs(lines) do
        if line.short > 0 then short[#short + 1] = line else full[#full + 1] = line end
    end
    -- What fits: the rows, then the lines under them (taken off, enough, the total, the switch).
    local under = (#off > 0 and 24 or 0) + (#full > 0 and 30 or 0) + 44 + 92
    local shownOff = p.showOff() and off or {}
    local limit = room - under - 16
    -- A line's name on one line, or on two when it's wider than its room: whole words, never cut.
    local function Name(r, text)
        r.name:SetText(text)
        local two = Style.Wide(r.name, #text * 6.6) > p.nameW
        r.name:SetWordWrap(two)
        r:SetHeight(two and TALL or ROW)
        return two and TALL or ROW
    end
    local total, unpriced, toGet = 0, 0, 0
    local n = 0
    for _, line in ipairs(short) do
        toGet = toGet + line.short
        local words, cost, made = ns.EndgameNightCost(line)
        if cost then total = total + cost elseif not made then unpriced = unpriced + 1 end
        local r = p.Row(n + 1)
        local h = Name(r, ns.EndgameItemName(line.item) or "...")
        if y + h <= limit then
            n = n + 1
            r.line, r.back, r.item, r.per = { line.item, line.kind, line.lasts }, nil, line.item, line.per
            r:SetAlpha(1)
            r.icon:SetTexture(Compat.ItemIcon(line.item))
            r.get:SetText(line.short)
            r.cost:SetText(words)
            r.notes = ns.EndgameNightNotes(line, saved.hours)
            At(r)
            r:Show()
            r.Light(r.lit)
            y = y + h
        end
    end
    for _, item in ipairs(shownOff) do
        local r = p.Row(n + 1)
        local h = Name(r, ns.EndgameItemName(item) or "...")
        if y + h <= limit then
            n = n + 1
            r.line, r.back, r.item, r.per = nil, true, item, 0
            r:SetAlpha(0.5)
            r.icon:SetTexture(Compat.ItemIcon(item))
            r.get:SetText("")
            r.cost:SetText(GOLD .. "put back|r")
            r.notes = { "Taken off. Click to put it back." }
            At(r)
            r:Show()
            r.Light(r.lit)
            y = y + h
        end
    end
    for i = n + 1, #card.rows do card.rows[i]:Hide() end
    p.toGet:SetText(toGet > 0 and (GOLD .. toGet .. "|r " .. MUTED .. "to get|r") or "|cff62b35aall held|r")

    y = y + 6
    p.offLink:SetShown(#off > 0)
    if #off > 0 then
        p.offLink.text:SetText(("%d taken off · %s"):format(#off, p.showOff() and "hide" or "show"))
        p.offLink:SetSize(Style.Wide(p.offLink.text, 120), 18)
        At(p.offLink)
        y = y + 24
    end
    -- The pictures start after the words, as many as fit with room for "+N" after them.
    p.enoughLabel:SetShown(#full > 0)
    local start = math.floor(Style.Wide(p.enoughLabel, 112) + 10)
    local fits = math.max(1, math.floor((p.inner - start - 28) / 22))
    local shown = math.min(#full, fits, #p.enough)
    for i, t in ipairs(p.enough) do
        local line = full[i]
        t:SetShown(i <= shown)
        if i <= shown then
            t:SetTexture(Compat.ItemIcon(line.item))
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", card, "TOPLEFT", PAD + start + (i - 1) * 22, -(y - 2))
        end
    end
    p.enoughMore:SetShown(#full > shown)
    if #full > 0 then
        At(p.enoughLabel, 0, 1)
        if #full > shown then
            p.enoughMore:SetText(("+%d"):format(#full - shown))
            At(p.enoughMore, start + shown * 22, 1)
        end
        y = y + 30
    end
    p.totalRule:ClearAllPoints()
    p.totalRule:SetPoint("TOPLEFT", card, "TOPLEFT", PAD, -y)
    p.totalRule:SetPoint("TOPRIGHT", card, "TOPRIGHT", -PAD, -y)
    y = y + 12
    local text
    if total > 0 then
        text = ("About |cffece6d6%s|r in all"):format(Compat.Money(total)) .. (unpriced > 0 and (" · %d not priced"):format(unpriced) or "")
    elseif unpriced > 0 then
        text = ("%d not priced yet"):format(unpriced)
    else
        text = toGet > 0 and "Nothing to buy: you make what's short" or "You hold all of it"
    end
    p.total:SetText(text)
    At(p.total)
    y = y + 32
    p.switchRule:ClearAllPoints()
    p.switchRule:SetPoint("TOPLEFT", card, "TOPLEFT", PAD, -y)
    p.switchRule:SetPoint("TOPRIGHT", card, "TOPRIGHT", -PAD, -y)
    y = y + 12
    local shopping = ns.Shopping
    local pretend = ns.Pretend ~= nil and not ns.Pretend.Listable()
    local can = shopping ~= nil and shopping.running == true and not pretend
    local on = can and RN.Listed()
    p.switch:SetOn(on)
    p.switch:SetEnabled(can)
    p.switch:SetAlpha(can and 1 or 0.5)
    At(p.switch)
    y = y + 28
    p.switchNote:SetText(pretend and "Pretending to be 60: the shopping list is left as it is."
        or not can and "The shopping list is switched off in Settings."
        or on and "What's short is on the list now, and what a raid uses comes back on it."
        or "When it's on, what's short goes on the list and comes back as you use it.")
    At(p.switchNote)
    y = y + 36 + 16
    card:SetHeight(y)
    return y
end
