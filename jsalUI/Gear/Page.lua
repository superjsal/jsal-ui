-- The Gear plan, in a window of its own: your gear slots in one column, in
-- the game's order. Each slot shows its name, what you wear and, in green,
-- the best upgrade near your level for your spec; a green dot marks the
-- slots that have one. Click a slot to see its options beside them: what
-- each adds, where it comes from, its level, and a star to keep it on top.
-- Under them, a box adds an item the plan doesn't list, starred, in the
-- slot it goes in.
local _, ns = ...
local Style, Compat, Window = ns.Style, ns.Compat, ns.Window

local WINDOW_W, WINDOW_H = 1000, 860
local SLOT_W, SLOT_H, GAP, ICON, ROW_H, LIST_GAP = 300, 45, 1, 36, 54, 20
local QUALITY_HEX = { [0] = "9d9d9d", "ffffff", "1eff00", "0070dd", "a335ee", "ff8000" }
local GREEN, RED = "|cff56944f", "|cffd65151"

local function ItemInfo(id)
    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local name, link, quality, _, _, _, _, _, _, texture = get(id)
    if not name and C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
    return name, link, quality, texture
end

local function Colored(name, quality)
    return ("|cff%s%s|r"):format(QUALITY_HEX[quality or 1] or "ffffff", name or "...")
end

local function Tooltip(frame)
    frame:SetScript("OnEnter", function(self)
        if not (self.item or self.equip) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.item then GameTooltip:SetItemByID(self.item) else GameTooltip:SetInventoryItem("player", self.equip) end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
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

    -- The top line: who it's for, and the spec, which picks the stat weights.
    local who = Style.Text(page, 13, "muted")
    who:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", 0, -14)
    local specButtons = {}
    for i = 3, 1, -1 do
        local b = Style.Button(page, "", "plain", 124)
        b:SetHeight(26)
        b:SetPoint("TOPRIGHT", page.heading, "BOTTOMLEFT", width - (3 - i) * 128, -8)
        b:SetScript("OnClick", function()
            G.SetSpec(i)
            Paint()
        end)
        specButtons[i] = b
    end

    local top = 46
    -- A slot: its icon (what you wear, or the empty slot), its name, what you
    -- wear and the best upgrade.
    local slotFrames = {}
    local function SlotButton(slot, x, y)
        local b = CreateFrame("Button", nil, page)
        b:SetSize(SLOT_W, SLOT_H)
        b:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", x, -y)
        b.bg = Style.Fill(b, "well")
        b.edges = Style.Border(b, "gold")
        b.box = IconBox(b, ICON)
        b.box:SetPoint("LEFT", 6, 0)
        b.icon = b.box.icon
        b.dot = b:CreateTexture(nil, "OVERLAY")
        b.dot:SetSize(9, 9)
        b.dot:SetColorTexture(Style.Color("wordGreen"))
        b.dot:SetPoint("CENTER", b.box, "TOPRIGHT", 0, 0)
        -- Three lines: the slot's name, what you wear, the upgrade.
        local textW = SLOT_W - ICON - 22
        b.label = Style.Text(b, 11, "muted")
        b.label:SetPoint("TOPLEFT", b.box, "TOPRIGHT", 8, 2)
        b.label:SetText(slot.label:upper())
        b.worn = Style.Text(b, 14, "text")
        b.worn:SetPoint("TOPLEFT", b.label, "BOTTOMLEFT", 0, -1)
        b.up = Style.Text(b, 13, "muted")
        b.up:SetPoint("TOPLEFT", b.worn, "BOTTOMLEFT", 0, -1)
        for _, t in ipairs({ b.label, b.worn, b.up }) do
            t:SetWidth(textW)
            t:SetJustifyH("LEFT")
            t:SetWordWrap(false)
        end
        b.slot = slot
        b.equip = slot.equip[1]
        Tooltip(b)
        b:SetScript("OnClick", function(self)
            chosen = self.slot.key
            Paint()
        end)
        slotFrames[slot.key] = b
        return b
    end
    local byKey = {}
    for i, s in ipairs(G.SLOTS) do
        byKey[s.key] = s
        SlotButton(s, 0, top + (i - 1) * (SLOT_H + GAP))
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
    local scroll = CreateFrame("ScrollFrame", nil, list)
    scroll:SetPoint("TOPLEFT", 0, -OPT_TOP)
    scroll:SetSize(listW, VIEW_H)
    local optList = CreateFrame("Frame", nil, scroll)
    optList:SetSize(listW, 1)
    scroll:SetScrollChild(optList)
    local track = scroll:CreateTexture(nil, "ARTWORK")
    track:SetColorTexture(Style.Color("line"))
    track:SetWidth(3)
    track:SetPoint("TOPRIGHT")
    track:SetPoint("BOTTOMRIGHT")
    local thumb = scroll:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(Style.Color("muted"))
    thumb:SetWidth(3)
    local function PaintThumb()
        local total = optList:GetHeight() or 0
        local more = total > VIEW_H + 1
        track:SetShown(more)
        thumb:SetShown(more)
        if not more then return end
        local h = math.max(24, VIEW_H * VIEW_H / total)
        local offset = (scroll:GetVerticalScroll() or 0) / (total - VIEW_H) * (VIEW_H - h)
        thumb:SetHeight(h)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOPRIGHT", 0, -offset)
    end
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local most = math.max(0, (optList:GetHeight() or 0) - VIEW_H)
        self:SetVerticalScroll(math.max(0, math.min(most, self:GetVerticalScroll() - delta * ROW_H)))
        PaintThumb()
    end)

    local rows = {}
    local function Row(i)
        if rows[i] then return rows[i] end
        -- The first row is what you wear, above the scroll; the rest scroll.
        local r = CreateFrame("Frame", nil, i == 1 and list or optList)
        r:SetSize(listW - (i == 1 and 14 or 28), ROW_H)
        r.box = IconBox(r, 36)
        r.box:SetPoint("LEFT", 0, 0)
        r.icon = r.box.icon
        r.name = Style.Text(r, 15, "text")
        r.name:SetPoint("TOPLEFT", r.box, "TOPRIGHT", 8, 0)
        r.name:SetWidth(listW - (i == 1 and 14 or 28) - 72)
        r.name:SetJustifyH("LEFT")
        r.name:SetWordWrap(false)
        r.where = Style.Text(r, 13, "muted")
        r.where:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
        r.where:SetWidth(listW - (i == 1 and 14 or 28) - 72)
        r.where:SetJustifyH("LEFT")
        r.where:SetWordWrap(false)
        r.star = CreateFrame("Button", nil, r)
        r.star:SetSize(18, 18)
        r.star:SetPoint("RIGHT", 0, 0)
        r.star.tex = r.star:CreateTexture(nil, "ARTWORK")
        r.star.tex:SetAllPoints()
        -- The game's own yellow star (the raid marker), grey until starred.
        r.star.tex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")
        r.star:SetScript("OnClick", function(self)
            G.ToggleStar(self:GetParent().item)
            Paint()
        end)
        Style.Rule(r, "BOTTOM", "line")
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
            chosen = slot.key
            Paint()
        end
    end
    addButton:SetScript("OnClick", Add)
    box:SetScript("OnEnterPressed", Add)
    page.AddBox = box
    -- Shift-clicking an item while the box has the cursor puts its link there.
    if ChatEdit_InsertLink and hooksecurefunc then
        hooksecurefunc("ChatEdit_InsertLink", function(link)
            if box:HasFocus() and type(link) == "string" and link:find("|Hitem:") then box:SetText(link) end
        end)
    end

    local note = Style.Text(page, 12, "muted")
    note:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 0, 0)
    note:SetWidth(width)
    note:SetJustifyH("LEFT")
    note:SetText("Items and where they come from are from Wowhead Forever and what you and your guild have seen. They're incomplete, especially past level 30, and will change as more people play. Stat weights are WoWSims'.")

    -- The line under an item: what it adds, where it comes from, and the
    -- level it needs (none shown when it needs none).
    local function Detail(o)
        local bits = {}
        if o.gains and o.gains ~= "" then bits[#bits + 1] = GREEN .. o.gains .. "|r" end
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
            b:SetKind(i == spec and "primary" or "plain")
        end
        local className = UnitClass("player") or ""
        who:SetText(("%s %s · level %d"):format(trees[spec].name, className:lower(), level))

        local plans = {}
        for _, s in ipairs(G.SLOTS) do plans[s.key] = G.Plan(s, spec) end
        for key, b in pairs(slotFrames) do
            local plan = plans[key]
            local worn = plan.worn
            b.equip = worn.link and worn.equip or nil
            if worn.link then
                local name, _, quality, texture = ItemInfo(tonumber(worn.link:match("item:(%d+)")))
                b.icon:SetTexture(texture or (GetInventoryItemTexture and GetInventoryItemTexture("player", worn.equip)))
                b.worn:SetText(Colored(name, quality))
            else
                local _, emptyTexture = GetInventorySlotInfo and GetInventorySlotInfo(b.slot.empty)
                b.icon:SetTexture(emptyTexture)
                b.worn:SetText("|cff9a9688empty|r")
            end
            local best = plan.options[1]
            if best then
                local name = ItemInfo(best.id)
                b.up:SetText(GREEN .. "Better: " .. (name or "...") .. "|r")
            else
                b.up:SetText(plan.waiting > 0 and "checking..." or "nothing better yet")
            end
            b.dot:SetShown(best ~= nil)
            local on = key == chosen
            b.bg:SetShown(on)
            for _, e in ipairs(b.edges) do e:SetShown(on) end
        end

        -- The chosen slot.
        local slot, plan = byKey[chosen], plans[chosen]
        wearHead:SetText(slot.label:upper() .. " · YOU WEAR")
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
        wornRow:Show()
        betterHead:ClearAllPoints()
        betterHead:SetPoint("TOPLEFT", 14, -(18 + ROW_H + 16))
        betterHead:SetText("BETTER FOR YOU")
        local y = OPT_TOP
        local shown = 0
        for i, o in ipairs(plan.options) do
            local r = Row(i + 1)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 14, -((i - 1) * ROW_H))
            r.item, r.equip = o.id, nil
            local name, _, quality, texture = ItemInfo(o.id)
            r.icon:SetTexture(texture or Compat.ItemIcon(o.id) or "Interface\\Icons\\INV_Misc_QuestionMark")
            r.name:SetText(Colored(name, quality or o.quality))
            r.where:SetText(Detail(o))
            r.star:Show()
            r.star.tex:SetDesaturated(not o.starred)
            r.star:SetAlpha(o.starred and 1 or 0.5)
            r:Show()
            shown = i
        end
        for i = shown + 2, #rows do rows[i]:Hide() end
        -- Back to the top for another slot; kept in range otherwise.
        optList:SetHeight(math.max(1, shown * ROW_H))
        local most = math.max(0, shown * ROW_H - VIEW_H)
        scroll:SetVerticalScroll(chosen ~= paintedSlot and 0 or math.min(scroll:GetVerticalScroll() or 0, most))
        paintedSlot = chosen
        PaintThumb()
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
