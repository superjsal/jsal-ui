-- The Gear plan, in a window of its own: your gear slots in one column, in
-- the game's order. Each slot shows its name, what you wear and, in green,
-- the best upgrade near your level for your spec; a green dot marks the
-- slots that have one. Click a slot to see its options beside them: what
-- each adds, where it comes from, its level, and a star to keep it on top.
-- Under them, a box adds an item the plan doesn't list, starred, in the
-- slot it goes in. Weights, beside the spec buttons, opens the spec's stat
-- weights to change, or to fill from a Pawn scale.
local _, ns = ...
local Style, Compat, Window = ns.Style, ns.Compat, ns.Window

local WINDOW_W, WINDOW_H = 1000, 860
local SLOT_W, SLOT_H, GAP, ICON, ROW_H, LIST_GAP = 300, 40, 1, 34, 54, 20
local OPT_H, OPT_GAP = 62, 8   -- an upgrade's card, and the room between two
local GAIN_W = 150             -- room for what an upgrade adds ("+14 AP, +3 Sta")
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

local function Tooltip(frame)
    frame:SetScript("OnEnter", function(self)
        if not (self.item or self.equip or self.note) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.item then
            GameTooltip:SetItemByID(self.item)
        elseif self.equip then
            GameTooltip:SetInventoryItem("player", self.equip)
        else
            GameTooltip:SetText(self.title or "")
        end
        -- A slot names its best upgrade under what you wear.
        if self.note then GameTooltip:AddLine(self.note, Style.Color("green")) end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    Style.Hover(frame)
end

-- An icon in a framed box, so an empty slot still shows where it is.
local function IconBox(parent, size)
    local box = CreateFrame("Frame", nil, parent)
    box:SetSize(size, size)
    Style.Fill(box, "window")
    Style.Border(box, "lineStrong")
    box.icon = box:CreateTexture(nil, "ARTWORK")
    box.icon:SetPoint("TOPLEFT", 1, -1)
    box.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    box.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    return box
end

Window.Page("gear", function(page)
    local G = ns.Gear
    local width, height = page.contentWidth or Window.contentWidth, page.contentHeight or Window.contentHeight
    local paneW = SLOT_W
    local listW = width - paneW - LIST_GAP
    local chosen = "chest"
    local Paint

    -- The top: how many slots can be better, who it's for, and the spec,
    -- which picks the stat weights.
    local title = Style.Text(page, 20, "text", nil, true)
    title:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", 0, -6)
    local who = Style.Text(page, 13, "muted")
    who:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    local specButtons = {}
    for i = 3, 1, -1 do
        local b = Style.Button(page, "", "tab", 124)
        b:SetHeight(26)
        b:SetPoint("TOPRIGHT", page.heading, "BOTTOMLEFT", width - (3 - i) * 128, -8)
        b:SetScript("OnClick", function()
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
    Style.Fill(panel, "window")
    Style.Border(panel, "lineStrong")
    Style.Shadow(panel, 12)
    panel:Hide()
    local panelTitle = Style.Text(panel, 13, "gold", nil, true)
    panelTitle:SetPoint("TOPLEFT", 14, -12)
    local panelHint = Style.Text(panel, 12, "muted")
    panelHint:SetPoint("TOPRIGHT", -14, -13)
    panelHint:SetText("higher counts more")
    local weightRows = {}
    local PaintWeights
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
            if r.key then
                G.RemoveWeight(G.Spec(), r.key)
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

    local top = 58
    -- A slot: its icon (what you wear, or the empty slot), its name, what you
    -- wear and the best upgrade.
    local slotFrames = {}
    local function SlotButton(row, x, y)
        local slot = row.slot
        local b = CreateFrame("Button", nil, page)
        b:SetSize(SLOT_W, SLOT_H)
        b:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", x, -y)
        b.bg = Style.Fill(b, "well")
        b.edges = Style.Border(b, "gold")
        b.box = IconBox(b, ICON)
        b.box:SetPoint("LEFT", 6, 0)
        b.icon = b.box.icon
        -- Two lines: the slot's name, with what its best upgrade adds at
        -- the right, and what you wear. The upgrade's own name is in the
        -- tooltip and beside the slots once it's chosen.
        b.label = Style.Text(b, 11, "muted")
        b.label:SetPoint("TOPLEFT", b.box, "TOPRIGHT", 8, -3)
        b.label:SetText(row.label:upper())
        b.gain = Style.Text(b, 12, "green", nil, true)
        b.gain:SetPoint("TOPRIGHT", b, "TOPRIGHT", -8, -7)
        b.gain:SetJustifyH("RIGHT")
        b.worn = Style.Text(b, 14, "text")
        b.worn:SetPoint("TOPLEFT", b.label, "BOTTOMLEFT", 0, -3)
        b.worn:SetWidth(SLOT_W - ICON - 22)
        b.worn:SetJustifyH("LEFT")
        b.worn:SetWordWrap(false)
        b.slot, b.row = slot, row
        b.equip = row.equip
        Tooltip(b)
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
            SlotButton(row, 0, top + (#slotRows - 1) * (SLOT_H + GAP))
        end
    end

    -- Beside the slots: the chosen slot's plan.
    local list = CreateFrame("Frame", nil, page)
    list:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", paneW + LIST_GAP, -top)
    list:SetSize(listW, height - top - 60)
    Style.Rule(list, "LEFT", "line")
    local wearHead = Style.Text(list, 12, "gold", nil, true)
    wearHead:SetPoint("TOPLEFT", 14, 0)
    local betterHead = Style.Text(list, 12, "gold", nil, true)
    local empty = Style.Text(list, 13, "muted")
    empty:SetWidth(listW - 28)
    empty:SetJustifyH("LEFT")
    -- The options scroll, between their heading and the add box, with a
    -- thin bar on the right when there are more than fit.
    local ADD_H = 58
    local OPT_TOP = 18 + ROW_H + 16 + 20
    local VIEW_H = (height - top - 60) - OPT_TOP - ADD_H
    local scroll, optList = Style.Scroller(list, listW, VIEW_H, nil, 0, OPT_H + OPT_GAP)
    scroll:SetPoint("TOPLEFT", 0, -OPT_TOP)

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
            Style.Fill(r, "well")
            Style.Border(r, "cardLine")
        else
            Style.Rule(r, "BOTTOM", "line")
        end
        r.box = IconBox(r, card and 40 or 36)
        r.box:SetPoint("LEFT", card and 10 or 0, 0)
        r.icon = r.box.icon
        -- A star keeps an upgrade on top: the game's own yellow star (the
        -- raid marker), grey until starred, in a box that reads as a button.
        r.star = CreateFrame("Button", nil, r)
        r.star:SetSize(30, 30)
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
        -- What it adds over what you wear, large, beside the star.
        r.gain = Style.Text(r, 15, "green", nil, true)
        r.gain:SetPoint("RIGHT", r.star, "LEFT", -12, 0)
        r.gain:SetJustifyH("RIGHT")
        r.name = Style.Text(r, 15, "text")
        r.name:SetPoint("TOPLEFT", r.box, "TOPRIGHT", 10, card and -2 or 0)
        r.where = Style.Text(r, 13, "muted")
        r.where:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
        local textW = w - (card and 60 or 46) - (card and (GAIN_W + 12 + 30 + 10 + 10) or 0)
        for _, t in ipairs({ r.name, r.where }) do
            t:SetWidth(textW)
            t:SetJustifyH("LEFT")
            t:SetWordWrap(false)
        end
        r:EnableMouse(true)
        Tooltip(r)
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
    box.hint:SetText("Item ID, link or Wowhead URL")
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
    -- The game's shift-click calls ChatFrameUtil.InsertLink by that name.
    hooksecurefunc(ChatFrameUtil, "InsertLink", ns.Safe(ns.Gear, function(link)
        if box:HasFocus() and type(link) == "string" and link:find("|Hitem:") then box:SetText(link) end
    end))

    local note = Style.Text(page, 12, "muted")
    note:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 0, 0)
    note:SetWidth(width)
    note:SetJustifyH("LEFT")
    note:SetWordWrap(false)
    note:SetText("Items and sources are from Wowhead Forever and what you and your guild have seen; they're incomplete past level 30. Stat weights are WoWSims'.")

    -- The line under an item: where it comes from, and the
    -- level it needs (none shown when it needs none).
    local function Detail(o)
        local bits = {}
        if o.lighter then bits[#bits + 1] = o.lighter end
        local source = G.Source(o)
        -- Profession gear: who can wear it, in red when you can't (yet).
        if o.needs then
            source = source:gsub("^" .. o.needs.name .. " · ", "")
            if source ~= "" then bits[#bits + 1] = source end
            bits[#bits + 1] = (G.HasSkill(o.needs) and "" or RED) .. ("%s %d only"):format(o.needs.name, o.needs.skill)
                .. (G.HasSkill(o.needs) and "" or "|r")
        elseif source ~= "" then
            bits[#bits + 1] = source
        end
        if (o.req or 0) > 0 and not o.needs then bits[#bits + 1] = (o.soon and RED or "") .. "level " .. o.req .. (o.soon and "|r" or "") end
        return table.concat(bits, " · ")
    end

    local paintedSlot
    Paint = function()
        local level = UnitLevel("player") or 1
        local spec = G.Spec()
        local trees = G.Trees()
        for i, b in ipairs(specButtons) do
            b:SetLabel(trees[i].name)
            b:SetSelected(i == spec)
        end
        local className = UnitClass("player") or ""
        who:SetText(("%s %s · level %d"):format(trees[spec].name, className:lower(), level)
            .. (G.CustomWeights(spec) and " · |cffe3b04byour weights|r" or ""))
        weightsButton:SetSelected(panel:IsShown())
        PaintWeights()

        local plans = {}
        for _, row in ipairs(slotRows) do plans[row.key] = G.Plan(row.slot, spec, row.equip) end
        local better, checking = 0, false
        for key, b in pairs(slotFrames) do
            local plan = plans[key]
            local worn = plan.worn
            b.equip = worn.link and worn.equip or nil
            b.title = b.row.label
            local best = plan.options[1]
            if worn.link then
                local name, _, quality, texture = ItemInfo(tonumber(worn.link:match("item:(%d+)")))
                b.icon:SetTexture(texture or (GetInventoryItemTexture and GetInventoryItemTexture("player", worn.equip)))
                b.worn:SetText(Colored(name, quality))
            else
                local _, emptyTexture = GetInventorySlotInfo and GetInventorySlotInfo(b.row.empty)
                b.icon:SetTexture(emptyTexture)
                -- An empty slot with something to put in it is the easiest win.
                b.worn:SetText(best and "|cffe3b04bEmpty|r" or "|cff9a9688Empty|r")
            end
            if best then
                better = better + 1
                b.gain:SetText(best.gains and best.gains ~= "" and best.gains or "Better")
                b.gain:SetTextColor(Style.Color("green"))
                b.note = "Best upgrade: " .. (ItemInfo(best.id) or "...")
            else
                b.gain:SetText(plan.waiting > 0 and "checking..." or "")
                b.gain:SetTextColor(Style.Color("muted"))
                b.note = nil
            end
            checking = checking or plan.waiting > 0
            local on = key == chosen
            b.bg:SetShown(on)
            for _, e in ipairs(b.edges) do e:SetShown(on) end
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
        end
        wornRow.where:SetText("")
        wornRow.star:Hide()
        wornRow.gain:SetText("")
        wornRow:Show()
        betterHead:ClearAllPoints()
        betterHead:SetPoint("TOPLEFT", 14, -(18 + ROW_H + 16))
        betterHead:SetText("BETTER FOR YOU")
        local y = OPT_TOP
        local shown = 0
        for i, o in ipairs(plan.options) do
            local r = Row(i + 1)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 14, -((i - 1) * (OPT_H + OPT_GAP)))
            r.item, r.equip = o.id, nil
            local name, _, quality, texture = ItemInfo(o.id)
            r.icon:SetTexture(texture or Compat.ItemIcon(o.id) or "Interface\\Icons\\INV_Misc_QuestionMark")
            r.name:SetText(Colored(name, quality or o.quality))
            r.where:SetText(Detail(o))
            r.gain:SetText(o.gains or "")
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
        local most = math.max(0, shown * (OPT_H + OPT_GAP) - VIEW_H)
        scroll:SetVerticalScroll(chosen ~= paintedSlot and 0 or math.min(scroll:GetVerticalScroll() or 0, most))
        paintedSlot = chosen
        scroll:UpdateScrollChildRect()
        scroll:Place()
        empty:ClearAllPoints()
        empty:SetPoint("TOPLEFT", 14, -y)
        if shown == 0 then
            empty:SetText(plan.waiting > 0 and "Checking the items near your level..."
                or "Nothing better for this slot near your level that we know of yet.")
            empty:Show()
        else
            empty:Hide()
        end
    end
    page.Refresh = function() Paint() end

    -- Items the game hadn't loaded arrive one by one, and gear changes: the
    -- page repaints once for a batch.
    local waiting
    page:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    page:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    page:SetScript("OnEvent", function()
        if pending and page:IsVisible() then
            local text = pending
            pending = nil
            box:SetText(text)
            Add()
        end
        if waiting or not page:IsVisible() then return end
        waiting = true
        Compat.After(0.3, function()
            waiting = nil
            if page:IsVisible() then Paint() end
        end)
    end)
end, { width = WINDOW_W, height = WINDOW_H })
