-- The Gear plan, in a wide window of its own: your gear slots as a table, in
-- the game's order. Each slot shows its name and what you wear, the best
-- upgrade near your level for your spec by name with where it's from, and in
-- green what it adds. Click a slot to see its upgrades beside them, in
-- columns: where each comes from, its level, what it adds, and a star to
-- keep it on top. Over them, a row of chips shows only the kinds of source
-- you choose. Under them, a box adds an item the plan doesn't list, starred,
-- in the slot it goes in. Weights, beside the spec buttons, opens the spec's
-- stat weights to change, or to fill from a Pawn scale.
local _, ns = ...
local Style, Compat, Window = ns.Style, ns.Compat, ns.Window

local WINDOW_W, WINDOW_H = 1240, 860
local FOOT = 34                    -- under the list: room for the link to the page's small print
local SLOT_W, SLOT_H, GAP, ICON, ROW_H, LIST_GAP = 540, 40, 1, 30, 54, 20
-- With the goal's tabs over the page, the title has a row of its own under them and
-- everything else moves down this much; the slots' rows give up the height between them.
local TABS_ROW = 42
local UP_X = 220               -- in a slot's row, where its best upgrade starts
local OPT_H, OPT_GAP = 54, 6   -- an upgrade's card, and the room between two
local GAIN_W = 118             -- room for what an upgrade adds ("+14 AP, +3 Sta")
local WHERE_X, LEVEL_W = 258, 36   -- on an upgrade's card: where its source starts, and the level column
local FILTER_H = 30            -- the row of chips over the upgrades, and the room under it
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
        local x = 0
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
                local w = math.floor(Style.Wide(b.kindText, #b.word * 7) + 3 + Style.Wide(b.countText, 8) + 12 + 0.5)
                b:SetWidth(w)
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", x, 0)
                b:SetSelected(on)
                b.kindText:SetTextColor(Style.Color(on and "text" or "secondary"))
                b.countText:SetTextColor(Style.Color(on and "gold" or "muted"))
                x = x + w + 5
            end
        end
        return shown
    end
    return F
end

Window.Page("gear", function(page)
    local G = ns.Gear
    local width, height = page.contentWidth or Window.contentWidth, page.contentHeight or Window.contentHeight
    local paneW = SLOT_W
    local listW = width - paneW - LIST_GAP
    local chosen = "chest"
    local Paint, Settle
    -- What belongs to this view alone hangs on a frame of its own, so the goal for the last
    -- level (Gear\GoalPage.lua) can take its place. The spec and its weights are for both.
    page.near = CreateFrame("Frame", nil, page)
    page.near:SetAllPoints(page)

    -- The top: how many slots can be better, who it's for, and the spec,
    -- which picks the stat weights.
    local title = Style.Text(page.near, 20, "text", nil, true)
    title:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", 0, -6)
    local who = Style.Text(page.near, 13, "muted")
    who:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
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

    local top = 68
    -- Over the slots, a name for each column: without them the green numbers
    -- beside a slot with nothing in it read as that slot's own stats. The
    -- slot's own name needs no heading.
    local wearing = Style.Text(page.near, 10, "muted", nil, true)
    -- At the page's left edge, in line with the title over it and the slots' rows under it: over
    -- the slots' names it stood 44 in.
    -- Its column ends where the best upgrade's begins: the longer "SLOT, AND WHAT YOU WEAR" ran
    -- into the next heading. It's held to its column, on one line.
    wearing:SetWidth(UP_X - 10)
    wearing:SetJustifyH("LEFT")
    wearing:SetWordWrap(false)
    wearing:SetText("CURRENTLY EQUIPPED")
    local bestHead = Style.Text(page.near, 10, "muted", nil, true)
    bestHead:SetText("BEST UPGRADE NEAR YOUR LEVEL")
    local adds = Style.Text(page.near, 10, "muted", nil, true)
    adds:SetJustifyH("RIGHT")
    adds:SetText("IT ADDS")
    local slotRule = page.near:CreateTexture(nil, "BORDER")
    slotRule:SetColorTexture(Style.Color("lineStrong"))
    slotRule:SetSize(SLOT_W, 1)
    -- A slot: its icon (what you wear, or the empty slot), its name, what you
    -- wear and the best upgrade.
    local slotFrames = {}
    local function SlotButton(row)
        local slot = row.slot
        local b = CreateFrame("Button", nil, page.near)
        b:SetSize(SLOT_W, SLOT_H)
        local box = Style.Box(b, 5, "well", "gold")
        b.bg, b.edges = box.fill, { box.line }
        b.box = IconBox(b, ICON)
        b.box:SetPoint("LEFT", 6, 0)
        b.icon = b.box.icon
        -- Three columns: the slot's name over what you wear; its best
        -- upgrade by name over where it's from; and what that adds.
        b.label = Style.Text(b, 10, "muted", nil, true)
        b.label:SetPoint("TOPLEFT", b.box, "TOPRIGHT", 8, 0)
        b.label:SetText(row.label:upper())
        b.worn = Style.Text(b, 13, "text")
        b.worn:SetPoint("TOPLEFT", b.label, "BOTTOMLEFT", 0, -2)
        b.worn:SetWidth(UP_X - ICON - 14 - 10)
        b.worn:SetJustifyH("LEFT")
        b.worn:SetWordWrap(false)
        b.gain = Style.Text(b, 13, "green", nil, true)
        b.gain:SetPoint("RIGHT", b, "RIGHT", -10, 0)
        b.gain:SetJustifyH("RIGHT")
        b.best = Style.Text(b, 13, "text")
        b.best:SetPoint("TOPLEFT", b, "TOPLEFT", UP_X, -5)
        b.from = Style.Text(b, 11, "muted")
        b.from:SetPoint("TOPLEFT", b.best, "BOTTOMLEFT", 0, -2)
        for _, t in ipairs({ b.best, b.from }) do
            t:SetWidth(SLOT_W - UP_X - GAIN_W - 18)
            t:SetJustifyH("LEFT")
            t:SetWordWrap(false)
        end
        Style.Rule(b, "BOTTOM", "line")
        b.slot, b.row = slot, row
        b.equip = row.equip
        -- The line lights under the pointer and a click picks it; its pieces each have their
        -- own tooltip: what you wear on its picture and name, the best upgrade on its name and
        -- where it's from.
        Style.Hover(b)
        b.wornHot = Style.HotArea(b, PieceTip)
        b.wornHot:SetPoint("LEFT")
        b.wornHot:SetHeight(SLOT_H)
        b.bestHot = Style.HotArea(b, PieceTip)
        b.bestHot:SetPoint("LEFT", UP_X, 0)
        b.bestHot:SetHeight(SLOT_H)
        b:SetScript("OnClick", function(self)
            chosen = self.row.key
            Paint()
        end)
        slotFrames[row.key] = b
        return b
    end
    -- A row for every place an item goes: both rings and both trinkets get
    -- their own, numbered, as the character pane shows them.
    local slotRows, byKey, firstRow = {}, {}, {}
    for _, s in ipairs(G.SLOTS) do
        for n, equip in ipairs(s.equip) do
            local pair = #s.equip > 1
            local row = {
                slot = s, equip = equip,
                key = pair and (s.key .. n) or s.key,
                label = pair and ("%s %d"):format(s.label, n) or s.label,
                empty = pair and s.empty:gsub("0Slot$", (n - 1) .. "Slot") or s.empty,
            }
            slotRows[#slotRows + 1] = row
            byKey[row.key] = row
            firstRow[s.key] = firstRow[s.key] or row.key
            SlotButton(row)
        end
    end

    -- Beside the slots: the chosen slot's plan.
    local list = CreateFrame("Frame", nil, page.near)
    list:SetWidth(listW)
    Style.Rule(list, "LEFT", "line")
    local wearHead = Style.Text(list, 12, "gold", nil, true)
    wearHead:SetPoint("TOPLEFT", 14, 0)
    -- Under what you wear: the chips that choose which kinds of source show, with the count of
    -- upgrades at the right of the heading.
    local filter = SourceFilter(list, listW, 18 + ROW_H + 8, function() Paint() end)
    -- The upgrades' column headings, lined up with the cards under them.
    local cols = CreateFrame("Frame", nil, list)
    cols:SetSize(listW - 28, 18)
    cols:SetPoint("TOPLEFT", 14, -(18 + ROW_H + 14 + FILTER_H))
    for _, label in ipairs({ { "UPGRADE", 54 }, { "WHERE IT'S FROM", WHERE_X }, { "LEVEL", -(46 + GAIN_W + 12) }, { "IT ADDS", -46 } }) do
        local t = Style.Text(cols, 10, "muted", nil, true)
        if label[2] < 0 then
            t:SetPoint("TOPRIGHT", label[2], 0)
            t:SetJustifyH("RIGHT")
        else
            t:SetPoint("TOPLEFT", label[2], 0)
        end
        t:SetText(label[1])
    end
    Style.Rule(cols, "BOTTOM", "lineStrong")
    local empty = Style.Text(list, 13, "muted")
    empty:SetWidth(listW - 28)
    empty:SetJustifyH("LEFT")
    -- The options scroll, between their heading and the add box, with a
    -- thin bar on the right when there are more than fit.
    local ADD_H = 58
    local OPT_TOP = 18 + ROW_H + 14 + FILTER_H + 18 + 6
    local VIEW_H = (height - top - FOOT) - OPT_TOP - ADD_H
    local scroll, optList = Style.Scroller(list, listW, VIEW_H, nil, 0, OPT_H + OPT_GAP)
    scroll:SetPoint("TOPLEFT", 0, -OPT_TOP)
    -- Where the page's lists start, `down` under the usual place (the goal's tabs' row, or
    -- nothing): the headings, the slots' rows (shorter, so they still end where they did) and
    -- the plan beside them. Done again only when it changes.
    local laid
    local viewH = VIEW_H
    local function Lay(down)
        if laid == down then return end
        laid = down
        local y = top + down
        wearing:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", 0, -(y - 18))
        bestHead:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", UP_X, -(y - 18))
        adds:SetPoint("TOPRIGHT", page.heading, "BOTTOMLEFT", SLOT_W - 10, -(y - 18))
        slotRule:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", 0, -(y - 3))
        local step = SLOT_H + GAP - math.ceil(down / #slotRows)
        for i, row in ipairs(slotRows) do
            local b = slotFrames[row.key]
            b:SetHeight(step - GAP)
            b:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", 0, -(y + (i - 1) * step))
        end
        list:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", paneW + LIST_GAP, -y)
        list:SetHeight(height - y - FOOT)
        viewH = VIEW_H - down
        scroll:SetHeight(viewH)
    end
    Lay(0)

    local rows = {}
    local function Row(i)
        if rows[i] then return rows[i] end
        -- The first row is what you wear, above the scroll; the rest are
        -- the upgrades, a card each, and scroll.
        local card = i > 1
        local w = listW - (card and 28 or 14)
        local r = CreateFrame("Frame", nil, card and optList or list)
        r:SetSize(w, card and OPT_H or ROW_H)
        if card then
            Style.Box(r, 6, "well", "cardLine")
        else
            Style.Rule(r, "BOTTOM", "line")
        end
        r.box = IconBox(r, 36)
        r.box:SetPoint("LEFT", card and 10 or 0, 0)
        r.icon = r.box.icon
        -- A star keeps an upgrade on top: the game's own yellow star (the
        -- raid marker), grey until starred, in a box that reads as a button.
        r.star = CreateFrame("Button", nil, r)
        r.star:SetSize(28, 28)
        r.star:SetPoint("RIGHT", -8, 0)
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
        -- What it adds over what you wear, beside the star: how much better it is as a share
        -- of all you wear ("+3%", the dungeon guide's "for you") over the stats it adds; the
        -- stats alone, in the middle, where there's no share to say.
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
            self.gain:SetPoint("RIGHT", self.star, "LEFT", -10, both and 8 or 0)
        end
        r:Adds(nil, "")
        r.name = Style.Text(r, 14, "text")
        r.name:SetWidth(card and (WHERE_X - 54 - 8) or (w - 46))
        r.name:SetJustifyH("LEFT")
        r.name:SetWordWrap(false)
        -- The upgrade the plan puts first is tagged, under its name.
        r.best = CreateFrame("Frame", nil, r)
        r.best:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
        Style.Fill(r.best, "gold")
        r.best.text = Style.Text(r.best, 10, "onGold", nil, true)
        r.best.text:SetPoint("CENTER")
        r.best.text:SetText("best for you")
        -- As wide as its words, with room each side: the window draws
        -- small text larger than asked, and a box of a set width was
        -- overrun by it.
        local wide = r.best.text.GetStringWidth and r.best.text:GetStringWidth()
        r.best:SetSize(((type(wide) == "number" and wide > 0) and wide or 64) + 16, 18)
        r.best:Hide()
        -- A piece in your bags that's better but isn't the best says so, quietly, in the
        -- same place: put it on while you go for the best.
        r.wear = Style.Tag(r, "wear it now", "green", true)
        r.wear:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
        r.wear:Hide()
        -- Where it's from, in a column of its own: how it's got, over
        -- where or from whom.
        r.how = Style.Text(r, 12, "text")
        r.how:SetPoint("TOPLEFT", WHERE_X, -10)
        r.where = Style.Text(r, 11, "muted")
        r.where:SetPoint("TOPLEFT", r.how, "BOTTOMLEFT", 0, -3)
        for _, t in ipairs({ r.how, r.where }) do
            t:SetWidth(w - WHERE_X - (46 + GAIN_W + 12) - LEVEL_W - 8)
            t:SetJustifyH("LEFT")
            t:SetWordWrap(false)
        end
        -- The level it needs, in a column, red while it's above yours.
        r.level = Style.Text(r, 13, "secondary")
        r.level:SetPoint("RIGHT", -(46 + GAIN_W + 12), 0)
        r.level:SetJustifyH("RIGHT")
        -- The name sits in the middle of the card, or over its tag: "best" or "wear".
        function r:Named(tagged)
            self.best:SetShown(tagged == "best")
            self.wear:SetShown(tagged == "wear")
            self.name:ClearAllPoints()
            if tagged then
                self.name:SetPoint("TOPLEFT", self.box, "TOPRIGHT", 10, 1)
            else
                self.name:SetPoint("LEFT", self.box, "RIGHT", 10, 0)
            end
        end
        r:Named(false)
        -- The piece's tooltip on its picture and name only; the star has its own.
        r.hot = Style.HotArea(r, PieceTip)
        r.hot:SetPoint("LEFT")
        r.hot:SetHeight(card and OPT_H or ROW_H)
        r.hotFrom = (card and 10 or 0) + 36 + 10
        rows[i] = r
        return r
    end

    -- Adding an item the plan doesn't list: its ID, a shift-clicked link
    -- or its Wowhead address. One the game hasn't loaded yet is tried again
    -- when it arrives.
    local box = Style.Field(list, listW - 14 - 96 - 8)
    box.well:SetPoint("BOTTOMLEFT", list, "BOTTOMLEFT", 14, 22)
    box.hint = Style.Text(box.well, 12, "muted")
    box.hint:SetPoint("LEFT", 8, 0)
    box.hint:SetText("Add an item: its ID, a link or a Wowhead URL")
    box:SetScript("OnTextChanged", function(self) box.hint:SetShown(self:GetText() == "" and not self:HasFocus()) end)
    box:SetScript("OnEditFocusGained", function() box.hint:Hide() end)
    box:SetScript("OnEditFocusLost", function(self) box.hint:SetShown(self:GetText() == "") end)
    local addButton = Style.Button(list, "Add", "plain", 96)
    addButton:SetHeight(26)
    addButton:SetPoint("LEFT", box.well, "RIGHT", 8, 0)
    local said = Style.Text(list, 12, "gold")
    said:SetPoint("TOPLEFT", box.well, "BOTTOMLEFT", 0, -6)
    said:SetWidth(listW - 28)
    said:SetJustifyH("LEFT")
    said:SetWordWrap(false)
    local pending
    local function Add()
        local message, ok, slot = G.Add(box:GetText())
        if message == "waiting" then
            pending = box:GetText()
            said:SetText("Looking that item up...")
            return
        end
        pending = nil
        said:SetText(message)
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

    -- Where an item comes from, in two parts: how it's got (crafted, a
    -- quest, who drops it), and where or from whom. Profession gear says who
    -- can wear it, in red when you can't (yet). And the level it needs, as
    -- its own column's text: red while it's above yours, nothing for
    -- profession gear, "any" for an item that needs none.
    local function Where(o)
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

    local paintedSlot, retrying
    Paint = function()
        local level = UnitLevel("player") or 1
        local spec = G.Spec()
        local trees = G.Trees()
        for i, b in ipairs(specButtons) do
            b:SetLabel(trees[i].name)
            b:SetSelected(i == spec)
        end
        local className = UnitClass("player") or ""
        who:SetText(("%s %s, level %d"):format(trees[spec].name, className:lower(), level)
            .. (G.CustomWeights(spec) and "  ·  |cffe3b04byour weights|r" or ""))
        weightsButton:SetSelected(panel:IsShown())
        PaintWeights()
        -- The goal for the last level, when that part is on: its tabs stand at the page's top
        -- left, with the title on a row of its own under them, and with "At 60" chosen its
        -- view is painted in place of this one.
        local inset, goal = 0, false
        if page.Goal then inset, goal = page.Goal(spec) end
        local down = (inset or 0) > 0 and TABS_ROW or 0
        title:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", 0, -(6 + down))
        Lay(down)
        page.near:SetShown(not goal)
        if goal then return end

        -- Timed apart from the drawing, so /jsal perf says which is slow.
        local started = debugprofilestop()
        G.spent = {}
        local plans = {}
        for _, row in ipairs(slotRows) do plans[row.key] = G.Plan(row.slot, spec, row.equip) end
        ns.Timed("Gear plan, working out upgrades", started)
        -- A slow pass: its parts too, each as one line ("Gear plan, upgrades: item stats").
        if debugprofilestop() - started >= 10 then
            for part, ms in pairs(G.spent) do ns.NoteTime("Gear plan, upgrades: " .. part, ms) end
        end
        local better, checking = 0, false
        for key, b in pairs(slotFrames) do
            local plan = plans[key]
            local worn = plan.worn
            b.equip = worn.link and worn.equip or nil
            b.wornHot.equip = b.equip
            b.title = b.row.label
            local best = G.Best(plan)
            if worn.link then
                local name, _, quality, texture = ItemInfo(tonumber(worn.link:match("item:(%d+)")))
                b.icon:SetTexture(texture or (GetInventoryItemTexture and GetInventoryItemTexture("player", worn.equip)))
                b.worn:SetText(Colored(name, quality))
            else
                local _, emptyTexture = GetInventorySlotInfo and GetInventorySlotInfo(b.row.empty)
                b.icon:SetTexture(emptyTexture)
                -- An empty slot with something to put in it is the easiest win.
                b.worn:SetText(best and "|cffe3b04bEmpty|r" or "|cff9a9688Empty|r")
                -- The off hand, under a two-hander: it isn't empty to fill.
                if plan.twoHand then b.worn:SetText("|cff9a9688Taken by your two-hander|r") end
            end
            -- That line has the row to itself, so it gets the room: in the
            -- column for what you wear it was cut short.
            b.worn:SetWidth(plan.twoHand and (SLOT_W - ICON - 30) or (UP_X - ICON - 14 - 10))
            if best then
                better = better + 1
                b.gain:SetText(best.gains and best.gains ~= "" and best.gains or "Better")
                -- The upgrade by name, in its quality's colour, over where
                -- it's from: the slot said only what it adds, and the name
                -- waited in a tooltip.
                local name, _, quality = ItemInfo(best.id)
                b.best:SetText(Colored(name, quality or best.quality))
                local how, place = Where(best)
                b.from:SetText(best.unknown and "where it's from isn't known yet" or (how .. (place ~= "" and (", " .. place) or "")))
                b.bestHot.item = best.id
            else
                b.bestHot.item = nil
                b.gain:SetText("")
                b.best:SetText(plan.twoHand and "" or (plan.waiting > 0 and "|cff9a9688checking...|r" or "|cff5d5b55nothing better yet|r"))
                b.from:SetText("")
            end
            Reach(b.wornHot, 6 + ICON + 8, b.worn)
            local longer = (b.from:GetStringWidth() or 0) > (b.best:GetStringWidth() or 0) and b.from or b.best
            Reach(b.bestHot, 0, longer)
            -- With nothing under it, a line sits in the middle of the row.
            b.best:ClearAllPoints()
            b.best:SetPoint("TOPLEFT", b, "TOPLEFT", UP_X, best and -5 or -13)
            checking = checking or plan.waiting > 0
            local on = key == chosen
            b.bg:SetShown(on)
            for _, e in ipairs(b.edges) do e:SetShown(on) end
        end
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
        if better > 0 then
            title:SetText(("%d slot%s can be better"):format(better, better == 1 and "" or "s"))
        else
            title:SetText(checking and "Checking the items near your level..." or "Nothing better near your level yet")
        end

        -- The chosen slot.
        local slot, plan = byKey[chosen].slot, plans[chosen]
        wearHead:SetText(byKey[chosen].label:upper() .. " · YOU WEAR")
        local wornRow = Row(1)
        wornRow:ClearAllPoints()
        wornRow:SetPoint("TOPLEFT", 14, -18)
        wornRow.item, wornRow.equip = nil, plan.worn.link and plan.worn.equip or nil
        if plan.worn.link then
            local name, _, quality, texture = ItemInfo(tonumber(plan.worn.link:match("item:(%d+)")))
            wornRow.icon:SetTexture(texture)
            wornRow.name:SetText(Colored(name, quality))
        else
            local _, emptyTexture = GetInventorySlotInfo and GetInventorySlotInfo(slot.empty)
            wornRow.icon:SetTexture(emptyTexture)
            wornRow.name:SetText("|cff9a9688Nothing|r")
            -- Under a two-hander: that's what holds the hand, by name.
            if plan.twoHand then
                local name, _, quality, texture = ItemInfo(tonumber(plan.twoHand:match("item:(%d+)")))
                wornRow.icon:SetTexture(texture or emptyTexture)
                wornRow.name:SetText(Colored(name, quality) .. "|cff9a9688, in both hands|r")
                wornRow.equip = 16
            end
        end
        wornRow.where:SetText("")
        wornRow.how:SetText("")
        wornRow.level:SetText("")
        wornRow.star:Hide()
        wornRow:Adds(nil, "")
        wornRow.hot.item, wornRow.hot.equip = nil, wornRow.equip
        Reach(wornRow.hot, wornRow.hotFrom, wornRow.name)
        wornRow:Show()
        -- The upgrades of the kinds chosen; the chips and the count are painted with them.
        local options = filter:Show(plan.options)
        cols:SetShown(#options > 0)
        local shown = 0
        local top = G.Top(plan)
        for i, o in ipairs(options) do
            local r = Row(i + 1)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 14, -((i - 1) * (OPT_H + OPT_GAP)))
            r.item, r.equip = o.id, nil
            local name, _, quality, texture = ItemInfo(o.id)
            r.icon:SetTexture(texture or Compat.ItemIcon(o.id) or "Interface\\Icons\\INV_Misc_QuestionMark")
            -- Lighter armor than yours says what it is, after its name.
            r.name:SetText(Colored(name, quality or o.quality) .. (o.lighter and ("  |cff9a9688" .. o.lighter:lower() .. "|r") or ""))
            local how, place, needs = Where(o)
            r.how:SetText(how)
            r.where:SetText(place)
            r.hot.item, r.hot.equip = o.id, nil
            Reach(r.hot, r.hotFrom, r.name)
            r.level:SetText(needs)
            -- The gold tag is the plan's best upgrade, the most it adds, which the chips may
            -- have hidden; a piece you starred or carry comes first whatever it scores. One you
            -- carry that's better and isn't that one says to wear it now; a star says the rest.
            r:Named((o == top and "best") or ((o.held and o.better and not o.starred) and "wear") or nil)
            -- With no second line, how it's got sits in the middle too.
            r.how:ClearAllPoints()
            r.how:SetPoint("TOPLEFT", WHERE_X, place ~= "" and -10 or -19)
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
        for i = shown + 2, #rows do rows[i]:Hide() end
        -- Back to the top for another slot; kept in range otherwise.
        optList:SetHeight(math.max(1, shown * (OPT_H + OPT_GAP)))
        local most = math.max(0, shown * (OPT_H + OPT_GAP) - viewH)
        scroll:SetVerticalScroll((chosen ~= paintedSlot or filter.moved) and 0 or math.min(scroll:GetVerticalScroll() or 0, most))
        paintedSlot, filter.moved = chosen, nil
        scroll:UpdateScrollChildRect()
        scroll:Place()
        empty:ClearAllPoints()
        -- Under the chips, when the slot has upgrades and the chips hide them all.
        empty:SetPoint("TOPLEFT", 14, -(18 + ROW_H + 16 + (#plan.options > 0 and FILTER_H or 0)))
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
    page.Refresh = function() Paint() end
    if G.GoalView then G.GoalView(page, width, height) end

    -- Items the game hadn't loaded arrive one by one, and gear changes: the
    -- page repaints once for a batch.
    local waiting
    page:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    page:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    page:SetScript("OnEvent", ns.Safe(G, function()
        if pending and page:IsVisible() then
            local text = pending
            pending = nil
            box:SetText(text)
            Add()
        end
        if waiting or not page:IsVisible() then return end
        waiting = true
        Compat.After(0.3, ns.Safe(G, function()
            waiting = nil
            if page:IsVisible() then Paint() end
        end))
    end))
end, { width = WINDOW_W, height = WINDOW_H })
