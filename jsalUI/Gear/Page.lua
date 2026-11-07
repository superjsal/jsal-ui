-- The Gear plan page: your gear slots around your character, like the game's
-- own character pane. Each slot shows what you wear and, in green, the best
-- upgrade near your level for your spec; a green dot marks the slots that
-- have one. Click a slot to see its options beside the pane: where each
-- comes from, what it adds, and a star to keep it at the top.
local _, ns = ...
local Style, Compat, Window = ns.Style, ns.Compat, ns.Window

local SLOT_W, SLOT_H, MODEL_W, GAP, ICON, ROW_H, LIST_GAP = 150, 50, 104, 6, 34, 44, 18
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

Window.Page("gear", function(page)
    local G = ns.Gear
    local width, height = Window.contentWidth, Window.contentHeight
    local paneW = SLOT_W * 2 + MODEL_W + GAP * 2
    local listW = width - paneW - LIST_GAP
    local chosen = "chest"
    local Paint

    -- The top line: who it's for, and the spec, which picks the stat weights.
    local who = Style.Text(page, 13, "muted")
    who:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", 0, -14)
    local specButtons = {}
    for i = 3, 1, -1 do
        local b = Style.Button(page, "", "plain", 112)
        b:SetHeight(26)
        b:SetPoint("TOPRIGHT", page.heading, "BOTTOMLEFT", width - (3 - i) * 116, -8)
        b:SetScript("OnClick", function()
            G.SetSpec(i)
            Paint()
        end)
        specButtons[i] = b
    end

    local top = 46
    -- The character in the middle.
    local well = CreateFrame("Frame", nil, page)
    well:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", SLOT_W + GAP, -top)
    well:SetSize(MODEL_W, 6 * (SLOT_H + GAP) - GAP)
    Style.Fill(well, "well")
    Style.Border(well, "line")
    local model = CreateFrame("PlayerModel", nil, well)
    model:SetPoint("TOPLEFT", 1, -1)
    model:SetPoint("BOTTOMRIGHT", -1, 1)

    -- A slot: its icon (what you wear, or the empty slot), its name, what you
    -- wear and the best upgrade. Left-hand slots read left to right; right-
    -- hand ones mirror them, text towards the character.
    local slotFrames = {}
    local function SlotButton(slot, x, y, mirror)
        local b = CreateFrame("Button", nil, page)
        b:SetSize(SLOT_W, SLOT_H)
        b:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", x, -y)
        b.bg = Style.Fill(b, "well")
        b.edges = Style.Border(b, "gold")
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(ICON, ICON)
        b.icon:SetPoint(mirror and "RIGHT" or "LEFT", mirror and -6 or 6, 0)
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b.dot = b:CreateTexture(nil, "OVERLAY")
        b.dot:SetSize(9, 9)
        b.dot:SetColorTexture(Style.Color("wordGreen"))
        b.dot:SetPoint("CENTER", b.icon, mirror and "TOPLEFT" or "TOPRIGHT", 0, 0)
        local textW = SLOT_W - ICON - 18
        local anchor, side = mirror and "TOPRIGHT" or "TOPLEFT", mirror and "LEFT" or "RIGHT"
        b.label = Style.Text(b, 10, "muted")
        b.label:SetPoint(anchor, b.icon, mirror and "TOPLEFT" or "TOPRIGHT", mirror and -6 or 6, 1)
        b.label:SetText(slot.label:upper())
        b.worn = Style.Text(b, 12, "text")
        b.worn:SetPoint(anchor, b.label, mirror and "BOTTOMRIGHT" or "BOTTOMLEFT", 0, -2)
        b.up = Style.Text(b, 11, "muted")
        b.up:SetPoint(anchor, b.worn, mirror and "BOTTOMRIGHT" or "BOTTOMLEFT", 0, -2)
        for _, t in ipairs({ b.label, b.worn, b.up }) do
            t:SetWidth(textW)
            t:SetJustifyH(mirror and "RIGHT" or "LEFT")
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
    local left = { "head", "neck", "shoulder", "back", "chest", "wrist" }
    local right = { "hands", "waist", "legs", "feet", "finger", "trinket" }
    local bottom = { "main", "off", "ranged" }
    local byKey = {}
    for _, s in ipairs(G.SLOTS) do byKey[s.key] = s end
    for i, key in ipairs(left) do SlotButton(byKey[key], 0, top + (i - 1) * (SLOT_H + GAP), false) end
    for i, key in ipairs(right) do SlotButton(byKey[key], SLOT_W + MODEL_W + GAP * 2, top + (i - 1) * (SLOT_H + GAP), true) end
    local bottomY = top + 6 * (SLOT_H + GAP) + 8
    local bottomW = SLOT_W * 3 + GAP * 2
    local bottomX = math.floor((paneW - bottomW) / 2)
    for i, key in ipairs(bottom) do SlotButton(byKey[key], bottomX + (i - 1) * (SLOT_W + GAP), bottomY, false) end

    -- Beside the pane: the chosen slot's plan.
    local list = CreateFrame("Frame", nil, page)
    list:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", paneW + LIST_GAP, -top)
    list:SetSize(listW, height - top - 60)
    Style.Rule(list, "LEFT", "line")
    local wearHead = Style.Text(list, 11, "gold", nil, true)
    wearHead:SetPoint("TOPLEFT", 14, 0)
    local betterHead = Style.Text(list, 11, "gold", nil, true)
    local empty = Style.Text(list, 12, "muted")
    empty:SetWidth(listW - 28)
    empty:SetJustifyH("LEFT")
    local rows = {}
    local function Row(i)
        if rows[i] then return rows[i] end
        local r = CreateFrame("Frame", nil, list)
        r:SetSize(listW - 14, ROW_H)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(28, 28)
        r.icon:SetPoint("LEFT", 0, 0)
        r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.name = Style.Text(r, 12, "text")
        r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 8, 1)
        r.name:SetWidth(listW - 150)
        r.name:SetJustifyH("LEFT")
        r.name:SetWordWrap(false)
        r.where = Style.Text(r, 11, "muted")
        r.where:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -2)
        r.where:SetWidth(listW - 66)
        r.where:SetJustifyH("LEFT")
        r.where:SetWordWrap(false)
        r.gain = Style.Text(r, 11, "muted")
        r.gain:SetPoint("TOPRIGHT", -26, -6)
        r.gain:SetJustifyH("RIGHT")
        r.star = CreateFrame("Button", nil, r)
        r.star:SetSize(18, 18)
        r.star:SetPoint("TOPRIGHT", 0, -3)
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

    local note = Style.Text(page, 11, "muted")
    note:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 0, 0)
    note:SetWidth(width)
    note:SetJustifyH("LEFT")
    note:SetText("Items and where they come from are from Wowhead Forever and what you and your guild have seen. They're incomplete, especially past level 30, and will change as more people play. Stat weights are WoWSims'.")

    -- One line for an item: where it comes from and its level.
    local function Where(o)
        local bits = {}
        if o.kind ~= "" then bits[#bits + 1] = o.kind end
        if o.place ~= "" then bits[#bits + 1] = o.place end
        bits[#bits + 1] = (o.soon and RED or "") .. "level " .. math.max(o.req, 1) .. (o.soon and "|r" or "")
        return table.concat(bits, " · ")
    end

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
        model:SetUnit("player")
        model:SetRotation(0.35)

        local plans = {}
        for _, s in ipairs(G.SLOTS) do plans[s.key] = G.Plan(s, spec) end
        for key, b in pairs(slotFrames) do
            local plan = plans[key]
            local worn = plan.worn
            b.equip = worn.equip
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
        wornRow.gain:SetText("")
        wornRow.star:Hide()
        wornRow:Show()
        betterHead:ClearAllPoints()
        betterHead:SetPoint("TOPLEFT", 14, -(18 + ROW_H + 16))
        betterHead:SetText("BETTER FOR YOU")
        local y = 18 + ROW_H + 16 + 20
        local maxRows = math.floor((height - top - 60 - y) / ROW_H)
        local shown = 0
        for i, o in ipairs(plan.options) do
            if i > maxRows then break end
            local r = Row(i + 1)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 14, -(y + (i - 1) * ROW_H))
            r.item, r.equip = o.id, nil
            local name, _, quality, texture = ItemInfo(o.id)
            r.icon:SetTexture(texture or Compat.ItemIcon(o.id) or "Interface\\Icons\\INV_Misc_QuestionMark")
            r.name:SetText(Colored(name, quality or o.quality))
            r.where:SetText(Where(o))
            r.gain:SetText(GREEN .. o.gains .. "|r")
            r.star:Show()
            r.star.tex:SetDesaturated(not o.starred)
            r.star:SetAlpha(o.starred and 1 or 0.5)
            r:Show()
            shown = i
        end
        for i = shown + 2, #rows do rows[i]:Hide() end
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
        if waiting or not page:IsVisible() then return end
        waiting = true
        Compat.After(0.3, function()
            waiting = nil
            if page:IsVisible() then Paint() end
        end)
    end)
end)
