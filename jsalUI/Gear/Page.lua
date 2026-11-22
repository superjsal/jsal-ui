-- The Gear plan, in a wide window of its own, laid out as its At 60 view is: a card with how
-- many slots can be better; a line a slot down the left, with its best upgrade near your level
-- for your spec, what it adds and where it's from, and what you wear under it; and at the right
-- where to go for those upgrades (Run next), or a picked slot's upgrades: where each comes from,
-- its level, what it adds, and a star to keep it on top. Over them, a row of chips shows only
-- the kinds of source you choose; under them, a box adds an item the plan doesn't list,
-- starred, in the slot it goes in. Weights, beside the spec buttons, opens the spec's stat
-- weights to change, or to fill from a Pawn scale.
local _, ns = ...
local Style, Compat, Window = ns.Style, ns.Compat, ns.Window

local WINDOW_W, WINDOW_H = 1240, 960
local OPT_H = 48               -- an upgrade's line in the picked slot's card
local GAIN_W = 118             -- room for what an upgrade adds ("+14 AP, +3 Sta")
local LEVEL_W = 36             -- an upgrade's level column
local FILTER_H = 34            -- the row of chips over the upgrades, and the room under it
local EMPTY_ALPHA = 0.6         -- the game's picture of an empty place, dimmed to read as empty
local RED = Style.Tint("red")

local function ItemInfo(id)
    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local name, link, quality, _, _, _, _, _, _, texture = get(id)
    if not name and C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
    return name, link, quality, texture
end

local function Colored(name, quality)
    return ("|cff%s%s|r"):format(Style.Quality(quality), name or "...")
end

-- A piece's own tooltip, on its picture and name: the item (with the game's compare against
-- what you wear, and jsal.ui's lines), or what you wear there, alone. Nothing where there's no
-- piece.
local function PieceTip(hot)
    if not (hot.item or hot.equip) then return end
    GameTooltip:SetOwner(hot, "ANCHOR_RIGHT")
    if hot.item then
        GameTooltip:SetItemByID(hot.item)
        GameTooltip:Show()
        return
    end
    GameTooltip:SetInventoryItem("player", hot.equip)
    GameTooltip:Show()
    -- What you wear isn't compared with itself.
    for _, compare in ipairs({ ShoppingTooltip1 or false, ShoppingTooltip2 or false }) do
        if compare then compare:Hide() end
    end
end

-- A hot area's width: from where its line starts to the end of the name as written, no wider
-- than the name's column.
local function Reach(hot, from, text)
    local room = text:GetWidth() or 0
    local wide = text:GetStringWidth() or 0
    hot:SetWidth(from + math.max(0, room > 0 and math.min(wide, room) or wide))
end

-- An icon in a framed box, so an empty slot still shows where it is.
local function IconBox(parent, size)
    local box = CreateFrame("Frame", nil, parent)
    box:SetSize(size, size)
    -- Its line and fill in two pictures, not five (Style.Lined): the same box.
    Style.Lined(box, "lineStrong", "window")
    box.icon = box:CreateTexture(nil, "ARTWORK")
    box.icon:SetPoint("TOPLEFT", 1, -1)
    box.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    box.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    return box
end

-- The kinds of source chosen: none is all of them. Kept for every slot while you play; a reload
-- starts again from everything, so a filter you forgot never hides an upgrade.
local sourceOn = {}

-- The filter over a slot's upgrades: a chip for each kind of source the slot has (a dungeon, a
-- quest, a vendor...), each with how many, and "All". Click one to see only that kind, another to
-- add its kind, "All" for everything again. It holds the count at the right of the slot's heading
-- too: "28 upgrades", or "3 of 28 upgrades". It's a function of its own, apart from the page's,
-- to keep both under the game's limit on what one function may reach outside itself.
local function SourceFilter(list, listW, top, Repaint)
    local G = ns.Gear
    local F = { chips = {} }
    F.count = Style.Text(list, 12, "muted")
    F.count:SetPoint("TOPRIGHT", -14, 0)
    F.count:SetJustifyH("RIGHT")
    F.row = CreateFrame("Frame", nil, list)
    F.row:SetSize(listW - 28, FILTER_H - 8)
    F.row:SetPoint("TOPLEFT", 14, -top)
    local function Chip(key, word)
        local b = Style.Button(F.row, "", "tab", 60)
        b:SetHeight(FILTER_H - 8)
        b.key, b.word = key, word
        b.kindText = Style.Text(b, 12, "secondary", nil, true)
        b.kindText:SetPoint("LEFT", 6, 0)
        b.kindText:SetText(word)
        b.countText = Style.Text(b, 12, "muted")
        b.countText:SetPoint("RIGHT", -6, 0)
        b.countText:SetJustifyH("RIGHT")
        b:SetScript("OnClick", function(self)
            if self.key == "all" then
                for k in pairs(sourceOn) do sourceOn[k] = nil end
            else
                sourceOn[self.key] = not sourceOn[self.key] or nil
            end
            -- The list starts from its top again.
            F.moved = true
            Repaint()
        end)
        F.chips[#F.chips + 1] = b
    end
    Chip("all", "All")
    for _, kind in ipairs(G.SOURCE_KINDS) do Chip(kind.key, kind.label) end

    -- Paints the chips and the count for a slot's upgrades, and returns the ones that show.
    function F:Show(options)
        local shown, counts = G.BySource(options, sourceOn)
        local any = next(sourceOn) ~= nil
        local s = #options == 1 and "" or "s"
        self.count:SetText(#options == 0 and "" or #shown < #options and ("%d of %d upgrade%s"):format(#shown, #options, s)
            or ("%d upgrade%s"):format(#options, s))
        self.row:SetShown(#options > 0)
        local showing = {}
        for _, b in ipairs(self.chips) do
            local all = b.key == "all"
            local n = all and #options or counts[b.key] or 0
            local on = (all and not any) or (not all and sourceOn[b.key] == true)
            -- A kind the slot has none of gets no chip, unless it's chosen: then its chip is how
            -- you take it off again.
            local show = all or n > 0 or on
            b:SetShown(show)
            if show then
                b.countText:SetText(tostring(n))
                b:SetSelected(on)
                b.kindText:SetTextColor(Style.Color(on and "text" or "secondary"))
                b.countText:SetTextColor(Style.Color(on and "gold" or "muted"))
                showing[#showing + 1] = b
            end
        end
        -- Whole chips within the row. While they fit, as they are. A row a little too long closes
        -- up only by what it's over: off the gaps first (evenly, none under 3), then off the
        -- chips' insides (evenly, none under 4 a side), so it ends at the row's right edge. One
        -- that can't fit even then takes as many rows as it needs, as roomy as ever.
        local room = self.row:GetWidth() or 0
        local n = #showing
        local inner, natural = {}, 0
        for i, b in ipairs(showing) do
            inner[i] = Style.Wide(b.kindText, #b.word * 7) + 3 + Style.Wide(b.countText, 8)
            natural = natural + inner[i] + 12
        end
        natural = natural + 5 * math.max(0, n - 1)
        local gap, pad, wrap = 5, 6, false
        local over = natural - room
        if over > 0 then
            local fromGaps = math.min(over, 2 * math.max(0, n - 1))
            local fromPads = over - fromGaps
            if fromPads > 4 * n then
                wrap = true
            else
                if n > 1 then gap = 5 - fromGaps / (n - 1) end
                pad = 6 - fromPads / (2 * n)
            end
        end
        -- Each chip's edges on whole pixels: where it starts and ends worked out exactly, then each
        -- rounded, so the row still ends within half a pixel of where it should.
        local Round = function(v) return math.floor(v + 0.5) end
        local x, y, lines = 0, 0, 1
        for i, b in ipairs(showing) do
            local w = inner[i] + pad * 2
            if wrap and x > 0 and x + w > room then x, y, lines = 0, y - (FILTER_H - 4), lines + 1 end
            local left = Round(x)
            b:SetWidth(Round(x + w) - left)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", left, y)
            b.kindText:SetPoint("LEFT", Round(pad), 0)
            b.countText:SetPoint("RIGHT", -Round(pad), 0)
            x = x + w + gap
        end
        self.lines = lines
        self.row:SetHeight(FILTER_H - 8 + (lines - 1) * (FILTER_H - 4))
        return shown
    end
    return F
end

local MUTED = "|cff9a9688"
-- On a slot's line, from the left: what you wear's picture, a small arrow, the upgrade's picture
-- and its name; what it adds stands in a column that ends this far from the right, a quiet ›
-- after it.
local WORN_X, ARROW_X, UP_X, UP_NAME_X = 78, 110, 130, 164
-- The same columns as At 60's lines, so the two tabs line up.
local LINE_GAIN_R, LINE_GAIN_W = 30, 60
-- Where the upgrade is from, in a column of its own whose right edge is this far from the line's.
local LINE_SOURCE_R = LINE_GAIN_R + LINE_GAIN_W + 8

-- Where an item comes from, in two parts: how it's got (crafted, a quest, who drops it), and
-- where or from whom. Profession gear says who can wear it, in red when you can't (yet). And
-- the level it needs, as its own column's text: red while it's above yours, nothing for
-- profession gear, "any" for an item that needs none.
local function Where(o)
    local G = ns.Gear
    local source = G.Source(o)
    if o.needs then source = (source:gsub("^" .. o.needs.name .. " · ", "")) end
    local how, place = source:match("^(.-) · (.*)$")
    if not how then how, place = source, "" end
    -- No source on Wowhead's list: said, where the column stood empty.
    if how == "" and not o.needs then how, place = "|cff9a9688Not known yet|r", "Wowhead lists no source" end
    -- "Leatherworking · Crafted" reads better the other way up.
    if place:find("^Crafted") then how, place = "Crafted", how .. place:sub(8) end
    if o.needs then
        local only = (G.HasSkill(o.needs) and "" or RED) .. ("%s %d only"):format(o.needs.name, o.needs.skill)
            .. (G.HasSkill(o.needs) and "" or "|r")
        place = place ~= "" and (place .. ", " .. only) or only
    end
    local level = ""
    if not o.needs then
        level = (o.req or 0) > 0 and ((o.soon and RED or "") .. o.req .. (o.soon and "|r" or "")) or "any"
    end
    return how, place, level
end

-- Near your level's card at the top, as At 60's: how many slots can be better, big in gold, a
-- pip a slot (lit for one that can be), and at the right who it's for and from what levels.
local function NearHero(view, width, P)
    local card = CreateFrame("Frame", nil, view)
    card:SetSize(width, P.HERO_H)
    card:SetPoint("TOPLEFT")
    Style.Box(card, 6, "well", "cardLine")
    Style.Edge(card, 6)
    card.count = Style.Text(card, 26, "gold", nil, true)
    card.count:SetPoint("TOPLEFT", 22, -15)
    card.label = Style.Text(card, 15, "secondary")
    card.pips = {}
    for i = 1, P.PLACES do
        local t = card:CreateTexture(nil, "ARTWORK")
        t:SetSize(12, 12)
        t:SetPoint("TOPLEFT", 22 + (i - 1) * 16, -54)
        card.pips[i] = t
    end
    card.who = Style.Text(card, 13, "text")
    card.who:SetPoint("TOPRIGHT", -20, -20)
    card.who:SetJustifyH("RIGHT")
    card.range = Style.Text(card, 12, "muted")
    card.range:SetPoint("TOPRIGHT", card.who, "BOTTOMRIGHT", 0, -8)
    card.range:SetJustifyH("RIGHT")
    -- `better` of `slots` can be; with none, what the page is waiting on or that there's none.
    function card:Paint(better, slots, checking)
        self.count:SetText(better > 0 and better or "")
        self.label:ClearAllPoints()
        if better > 0 then
            self.label:SetPoint("BOTTOMLEFT", self.count, "BOTTOMRIGHT", 10, 3)
            self.label:SetText(better == 1 and "slot can be better" or "slots can be better")
        else
            self.label:SetPoint("TOPLEFT", 22, -20)
            self.label:SetText(checking and "Checking the items near your level..." or "Nothing better near your level yet")
        end
        for i, t in ipairs(self.pips) do
            t:SetShown(i <= slots)
            t:SetColorTexture(Style.Color(i <= better and "gold" or "lineStrong"))
        end
    end
    return card
end

-- A slot's line, led by pictures: what you wear's picture (with its own tooltip), a small arrow,
-- the upgrade's picture and name (with the upgrade's tooltip), where it's from in a word or two,
-- what it adds at the right, and a quiet ›. The whole source is on the right: where to go, or the
-- slot's upgrades once picked.
local function NearLineParts(lines)
    for _, r in ipairs(lines.rows) do
        r.worn = Style.HotArea(r, PieceTip)
        r.worn:SetSize(24, 24)
        r.worn:SetPoint("LEFT", WORN_X, 0)
        -- Its line alone: there is always a picture in it, the game's empty place where nothing is worn.
        Style.Lined(r.worn, "lineStrong")
        r.worn.icon = r.worn:CreateTexture(nil, "ARTWORK")
        r.worn.icon:SetPoint("TOPLEFT", 1, -1)
        r.worn.icon:SetPoint("BOTTOMRIGHT", -1, 1)
        r.worn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.arrow = Style.Text(r, 13, "muted")
        r.arrow:SetPoint("LEFT", ARROW_X, 0)
        r.arrow:SetText("\226\134\146")
        r.box:ClearAllPoints()
        r.box:SetPoint("LEFT", UP_X, 0)
        r.gain:ClearAllPoints()
        r.gain:SetPoint("RIGHT", -LINE_GAIN_R, 0)
        r.gain:SetJustifyH("RIGHT")
        r.source = Style.Text(r, 12, "muted")
        r.source:SetPoint("RIGHT", -LINE_SOURCE_R, 0)
        r.source:SetJustifyH("RIGHT")
        r.source:SetWordWrap(false)
        r.hot:ClearAllPoints()
        r.hot:SetPoint("LEFT", UP_X, 0)
        -- The upgrade's tooltip covers its picture and its name as written.
        function r:Fit()
            local room = self.name:GetWidth() or 0
            local wide = self.name:GetStringWidth() or 0
            self.hot:SetWidth(UP_NAME_X - UP_X + math.max(0, room > 0 and math.min(wide, room) or wide))
        end
    end
end

-- Paints the slots' lines: what you wear and each slot's best upgrade (the most it adds), with
-- where it's from and what it adds; the chosen one lit. Gives how many can be better, of how many slots, and whether
-- any is still waiting on the game.
local function PaintNearLines(lines, slotRows, plans, chosen, P)
    local G = ns.Gear
    local better, slots, checking, counts = 0, 0, false, {}
    -- Each place's upgrade; a ring or trinket worn only once is the upgrade of one place of a pair.
    local tops = G.Tops(slotRows, plans)
    for i, r in ipairs(lines.rows) do
        local row = slotRows[i]
        r:SetShown(row ~= nil)
        if row then
            local plan = plans[row.key]
            local top = tops[row.key]
            local g = lines.GroupOf(row)
            counts[g] = counts[g] or { 0, 0 }
            if not plan.twoHand then
                slots = slots + 1
                counts[g][2] = counts[g][2] + 1
                if top then better, counts[g][1] = better + 1, counts[g][1] + 1 end
            end
            checking = checking or plan.waiting > 0
            r.pickable = true
            r:EnableMouse(true)
            local on = chosen == row.key
            r.lit:SetShown(on)
            r.bar:SetShown(on)
            r.slot:SetText(row.label:upper())
            r.slot:SetTextColor(Style.Color(on and "gold" or "muted"))
            r.picks:SetTextColor(Style.Color(on and "gold" or "muted"))
            r.picks:SetText(#plan.options > 0 and "\226\128\186" or "")
            r.item, r.equip, r.adds, r.lines = nil, nil, nil, nil
            r.gain:SetText("")
            -- What you wear: its picture, or the game's own picture of the empty place, dimmed,
            -- where nothing is; under a two-hander, the two-hander's, greyed.
            local worn = plan.worn
            local hand = plan.twoHand and GetInventoryItemTexture and GetInventoryItemTexture("player", 16)
            r.worn.item, r.worn.equip = nil, nil
            r.worn.icon:SetDesaturated(plan.twoHand and true or false)
            r.worn:SetAlpha(plan.twoHand and 0.4 or 1)
            r.worn.icon:SetAlpha(1)
            if hand then
                r.worn.icon:SetTexture(hand)
                r.worn.equip = 16
            elseif worn.link and not plan.twoHand then
                local _, _, _, texture = ItemInfo(tonumber(worn.link:match("item:(%d+)")))
                r.worn.icon:SetTexture(texture or (GetInventoryItemTexture and GetInventoryItemTexture("player", worn.equip)))
                r.worn.equip = worn.equip
            else
                local empty = G.EmptyPicture(row.slot, row.equip)
                if empty then
                    r.worn.icon:SetTexture(empty)
                    r.worn.icon:SetAlpha(EMPTY_ALPHA)
                else
                    r.worn.icon:SetColorTexture(Style.Color("window"))
                end
            end
            local up = top and not plan.twoHand
            r.arrow:SetShown(up and true or false)
            r.box:SetShown(up and true or false)
            r.name:ClearAllPoints()
            r.name:SetPoint("LEFT", up and UP_NAME_X or (WORN_X + 36), 0)
            if up then
                local name, _, quality, texture = ItemInfo(top.id)
                r.box.icon:SetTexture(texture or Compat.ItemIcon(top.id))
                r.name:SetText(Colored(name, quality or top.quality))
                r.gain:SetText(G.ShareText(top.share) or "")
                r.item, r.adds = top.id, top.gains
            elseif plan.twoHand then
                r.name:SetText(MUTED .. "Taken by your two-hander|r")
            else
                r.name:SetText(MUTED .. (plan.waiting > 0 and "Checking..." or "Nothing better yet") .. "|r")
            end
            -- The name as wide as it's written, up to the column of what it adds.
            r.name:SetWidth(0)
            local room = P.LEFT_W - LINE_GAIN_R - LINE_GAIN_W - 10 - (up and UP_NAME_X or (WORN_X + 36))
            r.name:SetWidth(math.min(Style.Wide(r.name, 200), room))
            -- Its source between the name and what it adds; the name keeps its room, and the
            -- source gives way whole: to its kind, else nothing.
            r.source:SetText("")
            if up then G.ShortSource(r.source, top, P.LEFT_W - LINE_SOURCE_R - (UP_NAME_X + (r.name:GetWidth() or 0) + 12)) end
            r:Fit()
        end
    end
    lines:Arrange(slotRows, function(g)
        local c = counts[g] or { 0, 0 }
        return ("%d of %d can be better"):format(c[1], c[2])
    end)
    return better, slots, checking
end

-- Run next's rows for Near your level: each slot's best upgrade, in the shape At 60's are.
local function NearRuns(slotRows, plans)
    local G, Goal = ns.Gear, ns.GearGoal
    local rows = {}
    local tops = G.Tops(slotRows, plans)
    for _, row in ipairs(slotRows) do
        local plan = plans[row.key]
        local top = plan and not plan.twoHand and tops[row.key]
        if top then
            rows[#rows + 1] = { label = row.label, slot = row.slot, equip = row.equip,
                                goal = { id = top.id, e = top }, gains = top.gains, share = top.share }
        end
    end
    local runs, other, unknown = Goal.Runs(rows, Goal.BEFORE)
    return { rows = rows, runs = runs, other = other, unknown = unknown, slots = #rows, done = 0 }
end

Window.Page("gear", function(page)
    local G = ns.Gear
    local width, height = page.contentWidth or Window.contentWidth, page.contentHeight or Window.contentHeight
    -- The slot picked, by its line's key; none shows Run next.
    local chosen
    local Paint, Settle
    -- What belongs to this view alone hangs on a frame of its own, so the goal for the last
    -- level (Gear\GoalPage.lua) can take its place. The spec and its weights are for both.
    page.near = CreateFrame("Frame", nil, page)
    page.near:SetAllPoints(page)

    -- The spec, which picks the stat weights, at the top right; who it's for is on the card.
    local specButtons = {}
    for i = 3, 1, -1 do
        local b = Style.Button(page, "", "tab", 124)
        b:SetHeight(26)
        b:SetPoint("TOPRIGHT", page.heading, "BOTTOMLEFT", width - (3 - i) * 128, -8)
        b:SetScript("OnClick", function()
            Settle()
            G.SetSpec(i)
            Paint()
        end)
        specButtons[i] = b
    end

    -----------------------------------------------------------------
    -- The weights: each stat the spec values, as a number to change (a
    -- changed one in gold) or a cross to remove it; a stat to add; a box
    -- to paste a Pawn scale into; and Reset.
    -----------------------------------------------------------------
    local WEIGHTS_W, WROW_H = 340, 28
    local weightsButton = Style.Button(page, "Weights", "tab", 100)
    weightsButton:SetHeight(26)
    weightsButton:SetPoint("RIGHT", specButtons[1], "LEFT", -8, 0)
    local panel = CreateFrame("Frame", nil, page)
    panel:SetWidth(WEIGHTS_W)
    panel:SetPoint("TOPRIGHT", specButtons[3], "BOTTOMRIGHT", 0, -6)
    panel:SetFrameStrata("DIALOG")
    panel:EnableMouse(true)
    Style.Lined(panel, "lineStrong", "window")
    Style.Shadow(panel, 12)
    panel:Hide()
    local panelTitle = Style.Text(panel, 13, "gold", nil, true)
    panelTitle:SetPoint("TOPLEFT", 14, -12)
    local panelHint = Style.Text(panel, 12, "muted")
    panelHint:SetPoint("TOPRIGHT", -14, -13)
    panelHint:SetText("higher counts more")
    local weightRows = {}
    local PaintWeights
    -- A weight box with the cursor in it takes what's typed before its row is given another
    -- stat, or another spec's. Left open, it kept the typed number and saved it later under
    -- whatever the row had become: 2 typed for Agility, another spec clicked, Enter pressed,
    -- and that spec's stat was 2.
    Settle = function()
        for _, r in ipairs(weightRows) do
            if r.field:HasFocus() then r.field:ClearFocus() end
        end
    end
    local function Number(v)
        local text = ("%.2f"):format(v or 0):gsub("0+$", ""):gsub("%.$", "")
        return text
    end
    local function WeightRow(i)
        if weightRows[i] then return weightRows[i] end
        local r = CreateFrame("Frame", nil, panel)
        r:SetSize(WEIGHTS_W - 28, WROW_H)
        Style.Rule(r, "BOTTOM", "line")
        r.label = Style.Text(r, 13, "text")
        r.label:SetPoint("LEFT", 0, 0)
        r.field = Style.Field(r, 70)
        r.field.well:SetPoint("RIGHT", -26, 0)
        r.remove = Style.CloseButton(r, 22, function()
            -- The stat this row has now: settling a box can move the rows.
            local key = r.key
            Settle()
            if key then
                G.RemoveWeight(G.Spec(), key)
                Paint()
                PaintWeights()
            end
        end)
        r.remove:SetPoint("RIGHT", 2, 0)
        r.field.well:SetHeight(22)
        r.field:SetJustifyH("RIGHT")
        local function Save(self)
            local v = tonumber(self:GetText())
            if v and r.key and math.abs(v - (r.value or 0)) > 0.0001 then
                G.SetWeight(G.Spec(), r.key, v)
                Paint()
            end
            PaintWeights()
        end
        r.field:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        r.field:SetScript("OnEditFocusLost", Save)
        weightRows[i] = r
        return r
    end
    local pawn = Style.Field(panel, WEIGHTS_W - 28 - 76 - 8)
    pawn:SetMaxLetters(0)
    pawn.hint = Style.Text(pawn.well, 12, "muted")
    pawn.hint:SetPoint("LEFT", 8, 0)
    pawn.hint:SetText("Paste a Pawn scale")
    pawn:SetScript("OnTextChanged", function(self) pawn.hint:SetShown(self:GetText() == "" and not self:HasFocus()) end)
    pawn:SetScript("OnEditFocusGained", function() pawn.hint:Hide() end)
    pawn:SetScript("OnEditFocusLost", function(self) pawn.hint:SetShown(self:GetText() == "") end)
    local importButton = Style.Button(panel, "Use it", "plain", 76)
    importButton:SetHeight(26)
    importButton:SetPoint("LEFT", pawn.well, "RIGHT", 8, 0)
    local resetButton = Style.Button(panel, "Reset to WoWSims", "plain", 150)
    resetButton:SetHeight(26)
    local weightsSaid = Style.Text(panel, 12, "gold")
    weightsSaid:SetWidth(WEIGHTS_W - 28)
    weightsSaid:SetJustifyH("LEFT")
    -- Add a stat: a menu of the ones not listed; the new row waits at 0
    -- with the cursor in it.
    local addStat = Style.Button(panel, "Add a stat", "plain", 130)
    addStat:SetHeight(26)
    local focusKey
    addStat:SetScript("OnClick", function(self)
        local spec, items = G.Spec(), {}
        local function Offer(key, label)
            if not G.WeightShown(spec, key) then
                items[#items + 1] = { label, nil, function()
                    Settle()
                    G.AddWeight(spec, key)
                    focusKey = key
                    Paint()
                    PaintWeights()
                end }
            end
        end
        for _, s in ipairs(G.WEIGHT_STATS) do Offer(s[1], s[2]) end
        for _, d in ipairs(G.WEIGHT_DPS) do Offer(d[1], d[2]) end
        if #items == 0 then
            weightsSaid:SetText("Every stat is listed already.")
        elseif ns.Launcher and ns.Launcher.ShowMenu then
            ns.Launcher.ShowMenu(self, items)
        end
    end)
    local function Import()
        Settle()
        local ok, message = G.ImportPawn(G.Spec(), pawn:GetText())
        weightsSaid:SetText(message or "")
        if ok then
            pawn:SetText("")
            pawn:ClearFocus()
            Paint()
        end
        PaintWeights()
    end
    importButton:SetScript("OnClick", Import)
    pawn:SetScript("OnEnterPressed", Import)
    resetButton:SetScript("OnClick", function()
        Settle()
        G.ResetWeights(G.Spec())
        weightsSaid:SetText("Back to WoWSims' weights.")
        Paint()
        PaintWeights()
    end)
    PaintWeights = function()
        if not panel:IsShown() then return end
        local spec = G.Spec()
        local trees = G.Trees()
        panelTitle:SetText(trees[spec].name .. " weights")
        local base = G.BaseWeights(spec) or { stats = {}, dps = {} }
        local now = G.Weights(spec) or { stats = {}, dps = {} }
        -- Every stat the spec values, by WoWSims or by you.
        local list = {}
        for _, s in ipairs(G.WEIGHT_STATS) do
            if G.WeightShown(spec, s[1]) then
                list[#list + 1] = { key = s[1], label = s[2], value = now.stats[s[1]] or 0, base = base.stats[s[1]] or 0 }
            end
        end
        for _, d in ipairs(G.WEIGHT_DPS) do
            if G.WeightShown(spec, d[1]) then
                list[#list + 1] = { key = d[1], label = d[2], value = now.dps[d[1]] or 0, base = base.dps[d[1]] or 0 }
            end
        end
        for i, e in ipairs(list) do
            local r = WeightRow(i)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 14, -(38 + (i - 1) * WROW_H))
            r.key, r.value = e.key, e.value
            local changed = math.abs(e.value - e.base) > 0.0001
            r.label:SetText(e.label .. (changed and " |cffe3b04b· yours|r" or ""))
            if not r.field:HasFocus() then r.field:SetText(Number(e.value)) end
            r.field:SetTextColor(Style.Color(changed and "gold" or "text"))
            r:Show()
            if focusKey == e.key then
                focusKey = nil
                r.field:SetFocus()
                r.field:HighlightText()
            end
        end
        for i = #list + 1, #weightRows do weightRows[i]:Hide() end
        local y = 38 + #list * WROW_H + 12
        pawn.well:ClearAllPoints()
        pawn.well:SetPoint("TOPLEFT", 14, -y)
        addStat:ClearAllPoints()
        addStat:SetPoint("TOPLEFT", 14, -(y + 34))
        resetButton:ClearAllPoints()
        resetButton:SetPoint("TOPRIGHT", -14, -(y + 34))
        weightsSaid:ClearAllPoints()
        weightsSaid:SetPoint("TOPLEFT", 14, -(y + 70))
        panel:SetHeight(y + 70 + 26)
    end
    weightsButton:SetScript("OnClick", function()
        panel:SetShown(not panel:IsShown())
        weightsSaid:SetText("")
        PaintWeights()
    end)
    page:HookScript("OnHide", function() panel:Hide() end)

    -----------------------------------------------------------------
    -- Near your level, laid out as At 60 is, with its pieces (Gear\GoalPage.lua): a card with
    -- how many slots can be better and a pip a slot; a line a slot down the left under ARMOR,
    -- JEWELRY and WEAPONS, its best upgrade with what it adds and where it's from, what you
    -- wear under it, and how many upgrades it has. At the right, with no slot picked, where to
    -- go for those upgrades (Run next); with one picked, all its upgrades.
    -----------------------------------------------------------------
    local P = G.GoalParts
    local view = CreateFrame("Frame", nil, page.near)
    view:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", 0, -P.TOP)
    view:SetSize(width, height - P.TOP)
    local hero = NearHero(view, width, P)
    local bodyH = height - P.TOP - P.HERO_H - P.HERO_GAP - P.FOOT
    local rowH = math.max(28, math.min(38, math.floor((bodyH - 3 * P.HEAD_H) / P.PLACES)))
    -- A line for every place an item goes: both rings and both trinkets get their own,
    -- numbered, as the character pane shows them.
    local slotRows, byKey, firstRow = {}, {}, {}
    for _, s in ipairs(G.SLOTS) do
        for n, equip in ipairs(s.equip) do
            local pair = #s.equip > 1
            local row = {
                slot = s, equip = equip,
                key = pair and (s.key .. n) or s.key,
                label = pair and ("%s %d"):format(s.label, n) or s.label,
            }
            slotRows[#slotRows + 1] = row
            byKey[row.key] = row
            firstRow[s.key] = firstRow[s.key] or row.key
        end
    end
    -- A click on a line picks its slot; on the picked one, back to Run next.
    local lines = P.SlotList(view, rowH, function(i)
        local key = slotRows[i] and slotRows[i].key
        chosen = chosen ~= key and key or nil
        Paint()
    end, true)
    NearLineParts(lines)
    local rightW = width - P.LEFT_W - P.COL_GAP
    local runs = P.Runs(view, rightW, bodyH, nil, nil, function() chosen = nil Paint() end, "ranked by the upgrades for you")

    -- The picked slot: its heading with the way back, the chips that choose which kinds of
    -- source show, its upgrades in a card that scrolls, and the box to add one.
    local list = CreateFrame("Frame", nil, view)
    list:SetSize(rightW, bodyH)
    list:SetPoint("TOPLEFT", P.LEFT_W + P.COL_GAP, -(P.HERO_H + P.HERO_GAP))
    local listHead = Style.Section(list, rightW)
    listHead:SetPoint("TOPLEFT")
    local back = P.Words(list, "\226\128\185 BACK", function() chosen = nil Paint() end)
    back:SetPoint("RIGHT", listHead, "RIGHT", 0, 0)
    local filter = SourceFilter(list, rightW + 28, P.HEAD_H + 4, function() Paint() end)
    filter.row:ClearAllPoints()
    filter.row:SetPoint("TOPLEFT", 0, -(P.HEAD_H + 4))
    filter.count:Hide()
    local LIST_TOP, NOTE_H, ADD_H = P.HEAD_H + 4 + FILTER_H, 24, 48
    local card = CreateFrame("Frame", nil, list)
    card:SetPoint("TOPLEFT", 0, -LIST_TOP)
    card:SetSize(rightW, bodyH - LIST_TOP - NOTE_H)
    Style.Box(card, 6, "well", "cardLine")
    local viewH = bodyH - LIST_TOP - NOTE_H - ADD_H
    local VIEW_H = viewH
    local scroll, optList = Style.Scroller(card, rightW, viewH, nil, 0, OPT_H)
    scroll:SetPoint("TOPLEFT", 0, 0)
    local empty = Style.Text(card, 13, "muted")
    empty:SetPoint("TOPLEFT", 14, -14)
    empty:SetWidth(rightW - 28)
    empty:SetJustifyH("LEFT")
    local order = Style.Text(list, 12, "muted")
    order:SetPoint("TOPLEFT", card, "BOTTOMLEFT", 0, -6)
    order:SetText("Starred, in your bags and added first, then by what they add.")

    local rows = {}
    -- An upgrade: its picture, its name with its tag beside it (best for you, wear it now), how
    -- it's got and where under it, the level it needs, what it adds, and a star.
    local function Row(i)
        if rows[i] then return rows[i] end
        local w = rightW - 12
        local r = CreateFrame("Frame", nil, optList)
        r:SetSize(w, OPT_H)
        r.rule = Style.Rule(r, "TOP", "line")
        r.box = IconBox(r, 30)
        r.box:SetPoint("LEFT", 12, 0)
        r.icon = r.box.icon
        -- A star keeps an upgrade on top: the game's own yellow star (the raid marker), grey
        -- until starred, in a box that reads as a button.
        r.star = CreateFrame("Button", nil, r)
        r.star:SetSize(26, 26)
        r.star:SetPoint("RIGHT", -10, 0)
        r.star.edges = Style.Border(r.star, "lineStrong")
        r.star.tex = r.star:CreateTexture(nil, "ARTWORK")
        r.star.tex:SetSize(16, 16)
        r.star.tex:SetPoint("CENTER")
        r.star.tex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")
        r.star:SetScript("OnClick", function(self)
            G.ToggleStar(self:GetParent().item)
            Paint()
        end)
        r.star:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.on and "Starred" or "Star it")
            GameTooltip:AddLine(self.on and "Click to take the star off."
                or "Keeps it on top here, and marks it wherever it turns up.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        r.star:SetScript("OnLeave", function() GameTooltip:Hide() end)
        -- What it adds over what you wear, beside the star: how much better it is as a share of
        -- all you wear over the stats it adds; the stats alone where there's no share to say.
        r.gain = Style.Text(r, 13, "green", nil, true)
        r.gain:SetJustifyH("RIGHT")
        r.adds = Style.Text(r, 11, "muted")
        r.adds:SetPoint("TOPRIGHT", r.gain, "BOTTOMRIGHT", 0, -3)
        r.adds:SetJustifyH("RIGHT")
        function r:Adds(share, stats)
            local both = share ~= nil and stats ~= ""
            self.gain:SetText(share or stats)
            self.adds:SetText(both and stats or "")
            self.gain:ClearAllPoints()
            self.gain:SetPoint("RIGHT", self.star, "LEFT", -12, both and 8 or 0)
        end
        r:Adds(nil, "")
        -- The level it needs, in a column, red while it's above yours.
        r.level = Style.Text(r, 13, "secondary")
        r.level:SetPoint("RIGHT", -(48 + GAIN_W), 0)
        r.level:SetJustifyH("RIGHT")
        local textW = w - 52 - (48 + GAIN_W) - LEVEL_W - 8
        r.name = Style.Text(r, 14, "text")
        r.name:SetPoint("TOPLEFT", 52, -8)
        r.name:SetJustifyH("LEFT")
        r.name:SetWordWrap(false)
        -- The best upgrade (the most it adds) is tagged beside its name, in gold.
        r.best = Style.Tag(r, "best for you", "gold", true)
        r.best:SetPoint("LEFT", r.name, "RIGHT", 8, 0)
        r.best:Hide()
        -- A piece in your bags that's better but isn't the best says so, quietly, in the same
        -- place: put it on while you go for the best.
        r.wear = Style.Tag(r, "wear it now", "green", true)
        r.wear:SetPoint("LEFT", r.name, "RIGHT", 8, 0)
        r.wear:Hide()
        -- Where it's from, under its name: how it's got, then where or from whom.
        r.how = Style.Text(r, 12, "secondary")
        r.how:SetPoint("TOPLEFT", 52, -28)
        r.how:SetWordWrap(false)
        r.dot = Style.Text(r, 12, "muted")
        r.dot:SetPoint("LEFT", r.how, "RIGHT", 4, 0)
        r.dot:SetText("·")
        r.where = Style.Text(r, 12, "muted")
        r.where:SetPoint("LEFT", r.dot, "RIGHT", 4, 0)
        r.where:SetJustifyH("LEFT")
        r.where:SetWordWrap(false)
        -- `tagged`: "best", "wear" or nil. The name as wide as it's written, up to its room
        -- beside the tag; the place after how it's got has what's left, and gives way whole.
        function r:Named(tagged)
            self.best:SetShown(tagged == "best")
            self.wear:SetShown(tagged == "wear")
            local tag = tagged == "best" and self.best or tagged == "wear" and self.wear or nil
            self.name:SetWidth(0)
            self.name:SetWidth(math.min(Style.Wide(self.name, 200), textW - (tag and ((tag.wide or 80) + 8) or 0)))
            self.how:SetWidth(0)
            self.how:SetWidth(math.min(Style.Wide(self.how, 80), textW))
            local room = textW - self.how:GetWidth() - 16
            local place = self.where:GetText() or ""
            self.dot:SetShown(place ~= "" and Style.Wide(self.where, #place * 6.5) <= room)
            self.where:SetShown(self.dot:IsShown())
            self.where:SetWidth(math.max(1, room))
        end
        -- The piece's tooltip on its picture and name only; the star has its own.
        r.hot = Style.HotArea(r, PieceTip)
        r.hot:SetPoint("LEFT")
        r.hot:SetHeight(OPT_H)
        r.hotFrom = 52
        rows[i] = r
        return r
    end

    -- Adding an item the plan doesn't list: its ID, a shift-clicked link or its Wowhead
    -- address. One the game hasn't loaded yet is tried again when it arrives.
    local box = Style.Field(card, rightW - 28 - 70 - 8)
    box.well:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 14, 10)
    box.hint = Style.Text(box.well, 12, "muted")
    box.hint:SetPoint("LEFT", 8, 0)
    box.hint:SetText("Add an item: its ID, a link or a Wowhead URL")
    box:SetScript("OnTextChanged", function(self) box.hint:SetShown(self:GetText() == "" and not self:HasFocus()) end)
    box:SetScript("OnEditFocusGained", function() box.hint:Hide() end)
    box:SetScript("OnEditFocusLost", function(self) box.hint:SetShown(self:GetText() == "") end)
    local addButton = Style.Button(card, "Add", "plain", 70)
    addButton:SetHeight(26)
    addButton:SetPoint("LEFT", box.well, "RIGHT", 8, 0)
    -- What adding said, in the note's place under the card.
    local said = Style.Text(list, 12, "gold")
    said:SetPoint("TOPLEFT", card, "BOTTOMLEFT", 0, -6)
    said:SetWidth(rightW)
    said:SetJustifyH("LEFT")
    said:SetWordWrap(false)
    local pending
    local function Add()
        local message, ok, slot = G.Add(box:GetText())
        if message == "waiting" then
            pending = box:GetText()
            said:SetText("Looking that item up...")
            order:Hide()
            return
        end
        pending = nil
        said:SetText(message)
        order:SetShown(message == nil or message == "")
        if ok then
            box:SetText("")
            box:ClearFocus()
            chosen = firstRow[slot.key]
            Paint()
        end
    end
    addButton:SetScript("OnClick", Add)
    box:SetScript("OnEnterPressed", Add)
    page.AddBox = box
    -- Shift-clicking an item while the box has the cursor puts its link there.
    Style.TakesLinks(box, ns.Gear)

    -- The page's small print, read on a hover at its foot: where the items come from, and that
    -- the stat weights are estimates.
    local about = Style.About(page.near, "Items and sources are from Wowhead Forever and what you and your guild have seen; they're incomplete past level 30.\n"
        .. "Stat weights are estimates from WoWSims' Forever sims at level 60: a guide, not the last word. Change them under Weights.")
    about:SetPoint("BOTTOMRIGHT", page, "BOTTOMLEFT", width, 0)

    -- The picked slot's upgrades, of the kinds chosen; the chips and the count with them.
    local paintedSlot
    local function PaintList(plans)
        local row, plan = byKey[chosen], plans[chosen]
        local options = filter:Show(plan.options)
        -- Chips on a second row push the list down by it, and its view is that much shorter.
        local extra = ((filter.lines or 1) - 1) * (FILTER_H - 4)
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", 0, -(LIST_TOP + extra))
        card:SetHeight(bodyH - LIST_TOP - extra - NOTE_H)
        viewH = VIEW_H - extra
        scroll:SetHeight(viewH)
        local count = filter.count:GetText() or ""
        listHead.title:SetText(row.label:upper() .. (count ~= "" and (" · " .. count:upper()) or ""))
        local shown = 0
        -- "best for you" is the slot's own upgrade: a unique ring or trinket that's the pair's
        -- other place's is listed, untagged.
        local top = G.Tops(slotRows, plans)[chosen]
        for i, o in ipairs(options) do
            local r = Row(i)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 0, -((i - 1) * OPT_H))
            r.rule:SetShown(i > 1)
            r.item = o.id
            local name, _, quality, texture = ItemInfo(o.id)
            r.icon:SetTexture(texture or Compat.ItemIcon(o.id) or "Interface\\Icons\\INV_Misc_QuestionMark")
            -- Lighter armor than yours says what it is, after its name.
            r.name:SetText(Colored(name, quality or o.quality) .. (o.lighter and ("  |cff9a9688" .. o.lighter:lower() .. "|r") or ""))
            local how, place, needs = Where(o)
            r.how:SetText(how)
            r.where:SetText(place)
            r.level:SetText(needs)
            -- The gold tag is the plan's best upgrade, the most it adds, which the chips may have
            -- hidden; a piece you starred or carry comes first whatever it scores. One you carry
            -- that's better and isn't that one says to wear it now; a star says the rest.
            r:Named((o == top and "best") or ((o.held and o.better and not o.starred) and "wear") or nil)
            r.hot.item, r.hot.equip = o.id, nil
            Reach(r.hot, r.hotFrom, r.name)
            if o.better == false then
                -- Not better (one you added or carry): said, with what you'd gain and lose.
                local changes = {}
                if o.gains and o.gains ~= "" then changes[#changes + 1] = o.gains end
                if o.losses and o.losses ~= "" then changes[#changes + 1] = o.losses end
                r:Adds("|cff9a9688worse than yours|r", table.concat(changes, ", "))
            else
                r:Adds(G.ShareText(o.share), o.gains or "")
            end
            r.star:Show()
            r.star.tex:SetDesaturated(not o.starred)
            r.star.on = o.starred
            r.star.tex:SetAlpha(o.starred and 1 or 0.6)
            Style.SetBorder(r.star.edges, o.starred and "gold" or "lineStrong")
            r:Show()
            shown = i
        end
        for i = shown + 1, #rows do rows[i]:Hide() end
        -- Back to the top for another slot; kept in range otherwise.
        optList:SetHeight(math.max(1, shown * OPT_H))
        local most = math.max(0, shown * OPT_H - viewH)
        scroll:SetVerticalScroll((chosen ~= paintedSlot or filter.moved) and 0 or math.min(scroll:GetVerticalScroll() or 0, most))
        paintedSlot, filter.moved = chosen, nil
        scroll:UpdateScrollChildRect()
        scroll:Place()
        if shown == 0 then
            empty:SetText(plan.twoHand and "Your two-hander takes both hands, so nothing goes in the off hand. Wear a one-handed weapon to see what could."
                or #plan.options > 0 and ("None of this slot's upgrades is of a kind you've chosen: %d hidden. Click All to see everything."):format(#plan.options)
                or plan.waiting > 0 and "Checking the items near your level..."
                or "Nothing better for this slot near your level that we know of yet.")
            empty:Show()
        else
            empty:Hide()
        end
    end

    local retrying
    -- The items the page last painted (each place's upgrades and what you wear), and how many items
    -- asked for had come then (Gear.arrived): an item that's neither, arriving, changes nothing here.
    -- None while At 60 is showing, which paints items of its own.
    local seen, seenArrived
    Paint = function()
        local level = UnitLevel("player") or 1
        local spec = G.Spec()
        local trees = G.Trees()
        for i, b in ipairs(specButtons) do
            b:SetLabel(trees[i].name)
            b:SetSelected(i == spec)
        end
        weightsButton:SetSelected(panel:IsShown())
        PaintWeights()
        -- The goal for the last level, when that part is on: with "At 60" chosen its view is
        -- painted in place of this one.
        local goal = false
        if page.Goal then goal = select(2, page.Goal(spec)) end
        page.near:SetShown(not goal)
        if goal then
            seen = nil
            return
        end

        -- Timed apart from the drawing, so /jsal perf says which is slow.
        local started = debugprofilestop()
        G.spent = {}
        local plans = {}
        -- The plans kept between paints (Gear.SlotPlan): a click, a chip or a look again with nothing
        -- changed works nothing out, and a slot still waiting on items is made again alone.
        for _, row in ipairs(slotRows) do plans[row.key] = G.SlotPlan(row.slot, false, row.equip) end
        seen, seenArrived = {}, G.arrived
        for _, plan in pairs(plans) do
            for _, o in ipairs(plan.options or {}) do seen[o.id] = true end
            local worn = plan.worn and plan.worn.link and tonumber(plan.worn.link:match("item:(%d+)"))
            if worn then seen[worn] = true end
        end
        ns.Timed("Gear plan, working out upgrades", started)
        -- A slow pass: its parts too, each as one line ("Gear plan, upgrades: item stats").
        if debugprofilestop() - started >= 10 then
            for part, ms in pairs(G.spent) do ns.NoteTime("Gear plan, upgrades: " .. part, ms) end
        end
        local better, slots, checking = PaintNearLines(lines, slotRows, plans, chosen, P)
        hero:Paint(better, slots, checking)
        local className = UnitClass("player") or ""
        hero.who:SetText(("%s %s, level %d"):format(trees[spec].name, className:lower(), level)
            .. (G.CustomWeights(spec) and "  ·  |cffe3b04byour weights|r" or ""))
        hero.range:SetText(("By your weights, from what you can wear at %d to %d"):format(math.max(1, level - G.BELOW), level + G.ABOVE))
        -- Still checking: look again in a couple of seconds by itself. An item asked for again
        -- after two seconds had nothing to repaint the page, which said "checking..." until a
        -- /reload. Once at a time; stops when nothing is waited on.
        if checking and not retrying then
            retrying = true
            Compat.After(2.5, ns.Safe(G, function()
                retrying = false
                if page:IsVisible() then Paint() end
            end))
        end
        -- At the right: the picked slot's upgrades, or with none picked where to go for them.
        list:SetShown(chosen ~= nil)
        runs:SetShown(chosen == nil)
        if chosen then
            PaintList(plans)
        else
            runs:Paint(NearRuns(slotRows, plans), ns.GearGoal.BEFORE, nil)
        end
    end
    page.Refresh = function() Paint() end
    if G.GoalView then G.GoalView(page, width, height) end

    -- Items the game hadn't loaded arrive one by one, and gear changes: the
    -- page repaints once for a batch. The game sends every item anything asks
    -- for (a tooltip, a chat link, another addon), so a batch of items the
    -- page doesn't show, none of them asked for by a plan, is let go. Weighed
    -- when the batch is done, once every frame has heard the items come.
    local waiting, came, other = nil, {}, false
    page:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    page:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    page:SetScript("OnEvent", ns.Safe(G, function(_, event, id)
        id = Compat.Plain(id)
        if pending and page:IsVisible() then
            local text = pending
            pending = nil
            box:SetText(text)
            Add()
        end
        if not page:IsVisible() then return end
        if event == "GET_ITEM_INFO_RECEIVED" then came[#came + 1] = id else other = true end
        if waiting then return end
        waiting = true
        Compat.After(0.3, ns.Safe(G, function()
            local due = other or not seen or G.arrived ~= seenArrived
            for _, item in ipairs(came) do
                if seen and seen[item] then due = true end
            end
            waiting, came, other = nil, {}, false
            if due and page:IsVisible() then Paint() end
        end))
    end))
end, { width = WINDOW_W, height = WINDOW_H })
