-- The Dungeons page: a picker on top opens every dungeon and raid in level
-- groups, the ones right for your level in green; the chosen one fills the
-- page below in two tabs. Bosses and loot: its bosses in the game's order, ticked once
-- you've killed them, and under the chosen boss its loot (Wowhead's list
-- with drop chances, and anything you've seen it drop). Quests: the
-- dungeon's quests for your faction, ticked once done.
local _, ns = ...
local Style, Compat, Window = ns.Style, ns.Compat, ns.Window

local DROP_W, DROP_H, PICKER_H, ROW_H, HEAD_H, BOSS_H, ITEM_H, QUEST_H = 340, 520, 34, 48, 28, 32, 36, 44

-- Wowhead's quest sides: 1 Alliance, 2 Horde, 3 both.
local QUEST_SIDE = { [1] = "Alliance", [2] = "Horde" }

local function QuestDone(id)
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then return C_QuestLog.IsQuestFlaggedCompleted(id) and true or false end
    return IsQuestFlaggedCompleted and IsQuestFlaggedCompleted(id) and true or false
end

-- Right for your level: from the level it's tuned to, up to five above.
-- More than three below it, it's dimmed.
local function Fits(d, level) return level >= d.level and level <= d.level + 5 end
local function TooHigh(d, level) return d.level > level + 3 end

-- The list's groups, by the level a dungeon is tuned to; raids on their own.
local GROUPS = {
    { label = "LEVELS 10-20", to = 19 },
    { label = "LEVELS 20-30", to = 29 },
    { label = "LEVELS 30-40", to = 39 },
    { label = "LEVELS 40-50", to = 49 },
    { label = "LEVELS 50-60", to = 60 },
    { label = "RAIDS", raid = true },
}
local function GroupOf(d)
    if d.raid then return #GROUPS end
    for g, group in ipairs(GROUPS) do
        if group.to and d.level <= group.to then return g end
    end
    return #GROUPS - 1
end

local QUALITY_HEX ={ [0] = "9d9d9d", "ffffff", "1eff00", "0070dd", "a335ee", "ff8000" }
local GREEN = "|cff56944f"

-- An item's details, asking the game to load them when it hasn't yet.
local function ItemInfo(id)
    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local name, link, quality, ilvl, req, class, subclass, stack, equipLoc, texture = get(id)
    if not name and C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
    return name, link, quality, ilvl, req, class, subclass, stack, equipLoc, texture
end

local function Scroller(parent, width, height)
    local scroll = CreateFrame("ScrollFrame", nil, parent)
    scroll:SetSize(width, height)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(width - 8, 1)
    scroll:SetScrollChild(child)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local target = self:GetVerticalScroll() - delta * 60
        self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), target)))
    end)
    return scroll, child
end

Window.Page("dungeons", function(page)
    local D = ns.Dungeons
    local width, height = Window.contentWidth, Window.contentHeight
    local rightW = width
    local chosen, chosenBoss, scrolled
    local Paint, opened

    -----------------------------------------------------------------
    -- The picker: the chosen dungeon's name; a click opens the list
    -- under it, in its level groups, over the page.
    -----------------------------------------------------------------
    local picker = CreateFrame("Button", nil, page)
    picker:SetSize(DROP_W, PICKER_H)
    picker:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", 0, -8)
    Style.Fill(picker, "well")
    Style.Border(picker, "gold")
    local pickerName = Style.Text(picker, 14, "text", nil, true)
    pickerName:SetPoint("LEFT", 12, 0)
    pickerName:SetWidth(DROP_W - 50)
    pickerName:SetJustifyH("LEFT")
    pickerName:SetWordWrap(false)
    local arrow = picker:CreateTexture(nil, "ARTWORK")
    arrow:SetSize(22, 22)
    arrow:SetPoint("RIGHT", -6, 0)
    arrow:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
    local key = Style.Text(page, 11, "muted")
    key:SetPoint("LEFT", picker, "RIGHT", 14, 0)

    local drop = CreateFrame("Frame", nil, page)
    drop:SetPoint("TOPLEFT", picker, "BOTTOMLEFT", 0, -4)
    drop:SetSize(DROP_W, DROP_H)
    drop:SetFrameStrata("DIALOG")
    drop:EnableMouse(true)
    Style.Fill(drop, "titleBar")
    Style.Border(drop, "lineStrong")
    drop:Hide()
    local listScroll, list = Scroller(drop, DROP_W - 12, DROP_H - 12)
    listScroll:SetPoint("TOPLEFT", 6, -6)
    local rowW = DROP_W - 20
    local rows = {}
    picker:SetScript("OnClick", function()
        drop:SetShown(not drop:IsShown())
        scrolled = false
        Paint()
    end)
    page:SetScript("OnHide", function() drop:Hide() end)

    -- A group's heading: click it to open or close the group.
    local groupHeads = {}
    for g in ipairs(GROUPS) do
        local h = CreateFrame("Button", nil, list)
        h:SetSize(rowW, HEAD_H)
        Style.Fill(h, "well")
        Style.Border(h, "line")
        h.sign = Style.Text(h, 14, "gold", nil, true)
        h.sign:SetPoint("LEFT", 10, 0)
        h.label = Style.Text(h, 12, "gold", nil, true)
        h.label:SetPoint("LEFT", 26, 0)
        h.note = Style.Text(h, 11, "muted")
        h.note:SetPoint("RIGHT", -10, 0)
        h.note:SetJustifyH("RIGHT")
        h:SetScript("OnClick", function()
            opened[g] = not opened[g] or nil
            Paint()
        end)
        groupHeads[g] = h
    end

    local function Row(i)
        if rows[i] then return rows[i] end
        local r = CreateFrame("Button", nil, list)
        r:SetSize(rowW, ROW_H - 4)
        r.bg = Style.Fill(r, "well")
        r.edges = Style.Border(r, "gold")
        r.name = Style.Text(r, 13, "text", nil, true)
        r.name:SetPoint("TOPLEFT", 10, -7)
        r.name:SetWidth(rowW - 56)
        r.name:SetJustifyH("LEFT")
        r.name:SetWordWrap(false)
        r.meta = Style.Text(r, 11, "muted")
        r.meta:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
        r.meta:SetWidth(rowW - 20)
        r.meta:SetJustifyH("LEFT")
        r.meta:SetWordWrap(false)
        r.count = Style.Text(r, 11, "muted")
        r.count:SetPoint("TOPRIGHT", -10, -8)
        r:SetScript("OnClick", function(self)
            chosen, chosenBoss = self.dungeon, nil
            drop:Hide()
            Paint()
        end)
        rows[i] = r
        return r
    end

    -----------------------------------------------------------------
    -- Below: the chosen dungeon, the page's full width.
    -----------------------------------------------------------------
    local right = CreateFrame("Frame", nil, page)
    right:SetPoint("TOPLEFT", picker, "BOTTOMLEFT", 0, -16)
    right:SetSize(rightW, height - PICKER_H - 16)
    local title = Style.Text(right, 20, "text", nil, true)
    title:SetPoint("TOPLEFT")
    title:SetWidth(rightW)
    title:SetJustifyH("LEFT")
    local meta = Style.Text(right, 12, "muted")
    meta:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    meta:SetWidth(rightW)
    meta:SetJustifyH("LEFT")
    -- Two tabs: the bosses with their loot, and the dungeon's quests.
    local tab = "bosses"
    local tabs = {}
    for k, t in ipairs({ { "bosses", "Bosses and loot", 150 }, { "quests", "Quests", 120 } }) do
        local b = Style.Button(right, t[2], "plain", t[3])
        b:SetPoint("TOPLEFT", k == 1 and 0 or 156, -52)
        b:SetScript("OnClick", function()
            tab = t[1]
            Paint()
        end)
        tabs[t[1]] = b
    end
    local hint = Style.Text(right, 11, "muted")
    hint:SetPoint("TOPRIGHT", 0, -60)
    hint:SetJustifyH("RIGHT")
    local bossScroll, bossList = Scroller(right, rightW + 8, height - PICKER_H - 16 - 92)
    bossScroll:SetPoint("TOPLEFT", 0, -92)
    local bossRows, items, questRows = {}, {}, {}
    local none = Style.Text(bossList, 12, "muted")
    none:SetWidth(rightW - 36)
    none:SetJustifyH("LEFT")

    local function BossRow(i)
        if bossRows[i] then return bossRows[i] end
        local b = CreateFrame("Button", nil, bossList)
        b:SetSize(rightW, BOSS_H)
        b.bg = Style.Fill(b, "well")
        b.box = CreateFrame("Frame", nil, b)
        b.box:SetSize(16, 16)
        b.box:SetPoint("LEFT", 8, 0)
        b.boxFill = Style.Fill(b.box, "wordGreen")
        b.boxEdges = Style.Border(b.box, "lineStrong")
        -- The game's own check mark, in white.
        b.tick = b.box:CreateTexture(nil, "OVERLAY")
        b.tick:SetSize(16, 16)
        b.tick:SetPoint("CENTER", 1, 0)
        b.tick:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        b.tick:SetDesaturated(true)
        b.tick:SetVertexColor(1, 1, 1)
        b.name = Style.Text(b, 13, "text")
        b.name:SetPoint("LEFT", b.box, "RIGHT", 10, 0)
        b.name:SetWidth(rightW - 150)
        b.name:SetJustifyH("LEFT")
        b.name:SetWordWrap(false)
        b.kills = Style.Text(b, 12, "muted")
        b.kills:SetPoint("RIGHT", -10, 0)
        Style.Rule(b, "BOTTOM", "line")
        b:SetScript("OnClick", function(self)
            chosenBoss = chosenBoss ~= self.boss and self.boss or nil
            Paint()
        end)
        bossRows[i] = b
        return b
    end

    -- A quest: ticked once you've done it, its level on the right, and
    -- the game's own quest tooltip on hover.
    local function QuestRow(i)
        if questRows[i] then return questRows[i] end
        local q = CreateFrame("Frame", nil, bossList)
        q:SetSize(rightW, QUEST_H)
        q.box = CreateFrame("Frame", nil, q)
        q.box:SetSize(16, 16)
        q.box:SetPoint("LEFT", 8, 0)
        q.boxFill = Style.Fill(q.box, "wordGreen")
        q.boxEdges = Style.Border(q.box, "lineStrong")
        q.tick = q.box:CreateTexture(nil, "OVERLAY")
        q.tick:SetSize(16, 16)
        q.tick:SetPoint("CENTER", 1, 0)
        q.tick:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        q.tick:SetDesaturated(true)
        q.tick:SetVertexColor(1, 1, 1)
        q.name = Style.Text(q, 13, "text")
        q.name:SetPoint("TOPLEFT", q.box, "TOPRIGHT", 10, 4)
        q.name:SetWidth(rightW - 130)
        q.name:SetJustifyH("LEFT")
        q.name:SetWordWrap(false)
        q.detail = Style.Text(q, 11, "muted")
        q.detail:SetPoint("TOPLEFT", q.name, "BOTTOMLEFT", 0, -3)
        q.detail:SetWidth(rightW - 130)
        q.detail:SetJustifyH("LEFT")
        q.level = Style.Text(q, 12, "muted")
        q.level:SetPoint("RIGHT", -10, 0)
        Style.Rule(q, "BOTTOM", "line")
        q:EnableMouse(true)
        q:SetScript("OnEnter", function(self)
            if not self.quest then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(("quest:%d"):format(self.quest))
            GameTooltip:Show()
        end)
        q:SetScript("OnLeave", function() GameTooltip:Hide() end)
        questRows[i] = q
        return q
    end

    local itemW = math.floor((rightW - 36 - 10) / 2)
    local function Item(i)
        if items[i] then return items[i] end
        local it = CreateFrame("Frame", nil, bossList)
        it:SetSize(itemW, ITEM_H - 4)
        it.icon = it:CreateTexture(nil, "ARTWORK")
        it.icon:SetSize(26, 26)
        it.icon:SetPoint("LEFT")
        it.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        it.name = Style.Text(it, 12, "text")
        it.name:SetPoint("TOPLEFT", it.icon, "TOPRIGHT", 8, 0)
        it.name:SetWidth(itemW - 36)
        it.name:SetJustifyH("LEFT")
        it.name:SetWordWrap(false)
        it.slot = Style.Text(it, 11, "muted")
        it.slot:SetPoint("BOTTOMLEFT", it.icon, "BOTTOMRIGHT", 8, 0)
        it.slot:SetWidth(itemW - 36)
        it.slot:SetJustifyH("LEFT")
        it.slot:SetWordWrap(false)
        it:EnableMouse(true)
        it:SetScript("OnEnter", function(self)
            if not self.item then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(self.item)
            GameTooltip:Show()
        end)
        it:SetScript("OnLeave", function() GameTooltip:Hide() end)
        items[i] = it
        return it
    end

    -- A boss's loot: Wowhead's list with each item's drop chance, and
    -- anything you've seen it drop that the list doesn't have.
    local function PaintLoot(boss, encounter, y)
        local list, byId = {}, {}
        for _, drop in ipairs(ns.DungeonLoot and ns.DungeonLoot[encounter] or {}) do
            local entry = { id = drop[1], chance = drop[2], item = {} }
            list[#list + 1] = entry
            byId[drop[1]] = entry
        end
        for id, item in pairs(D.Loot()[D.Key(boss)] or {}) do
            if byId[id] then
                byId[id].item = item
            else
                list[#list + 1] = { id = id, item = item }
            end
        end
        table.sort(list, function(a, b)
            if (a.chance or 0) ~= (b.chance or 0) then return (a.chance or 0) > (b.chance or 0) end
            if (a.item.q or 0) ~= (b.item.q or 0) then return (a.item.q or 0) > (b.item.q or 0) end
            return a.id < b.id
        end)
        if #list == 0 then
            none:ClearAllPoints()
            none:SetPoint("TOPLEFT", 36, -(y + 8))
            none:SetText("No loot known yet. What it drops is added here when you loot it or roll on it.")
            none:Show()
            return y + 40
        end
        none:Hide()
        for i, entry in ipairs(list) do
            local it = Item(i)
            local row, col = math.floor((i - 1) / 2), (i - 1) % 2
            it:ClearAllPoints()
            it:SetPoint("TOPLEFT", 36 + col * (itemW + 10), -(y + 6 + row * ITEM_H))
            it.item = entry.id
            local name, _, quality, _, _, _, subclass, _, equipLoc, texture = ItemInfo(entry.id)
            local q = quality or entry.item.q or 1
            it.name:SetText(("|cff%s%s|r"):format(QUALITY_HEX[q] or "ffffff", name or entry.item.n or "..."))
            local slot = equipLoc and equipLoc ~= "" and _G[equipLoc] or nil
            local parts = {}
            if entry.chance then parts[#parts + 1] = ("%d%%"):format(entry.chance) end
            if slot then parts[#parts + 1] = slot end
            if subclass and subclass ~= "" and subclass ~= slot and subclass ~= "Miscellaneous" then parts[#parts + 1] = subclass end
            if (entry.item.seen or 0) > 0 then
                parts[#parts + 1] = entry.item.seen > 1 and ("you've seen it %d×"):format(entry.item.seen) or "you've seen it"
            end
            it.slot:SetText(table.concat(parts, " · "))
            it.icon:SetTexture(texture or Compat.ItemIcon(entry.id) or "Interface\\Icons\\INV_Misc_QuestionMark")
            it:Show()
        end
        return y + 6 + math.ceil(#list / 2) * ITEM_H + 6
    end

    Paint = function()
        local level = UnitLevel("player") or 1
        local faction = UnitFactionGroup and UnitFactionGroup("player")
        local game = D.GameKills()
        local shown = {}
        for _, d in ipairs(ns.DungeonData or {}) do
            if not d.faction or d.faction == faction then shown[#shown + 1] = d end
        end
        if not chosen then
            for _, d in ipairs(shown) do
                if Fits(d, level) then chosen = d break end
            end
            chosen = chosen or shown[1]
        end

        -- The list, in level groups; the one with the dungeon picked for
        -- you starts open.
        if not opened then
            opened = {}
            opened[GroupOf(chosen)] = true
        end
        key:SetText(GREEN .. "Green|r: right for level " .. level)
        local y, i, chosenY = 0, 0, 0
        local members = {}
        for _, d in ipairs(shown) do
            local g = GroupOf(d)
            members[g] = members[g] or {}
            table.insert(members[g], d)
        end
        for g, group in ipairs(GROUPS) do
            local h = groupHeads[g]
            local inGroup = members[g] or {}
            h:SetShown(#inGroup > 0)
            if #inGroup > 0 then
                h:ClearAllPoints()
                h:SetPoint("TOPLEFT", 0, -y)
                local fits = 0
                for _, d in ipairs(inGroup) do if Fits(d, level) then fits = fits + 1 end end
                h.label:SetText(group.label)
                -- How many it holds; "your level" when one is right for you.
                local noun = group.raid and (#inGroup == 1 and "raid" or "raids") or (#inGroup == 1 and "dungeon" or "dungeons")
                h.note:SetText(fits > 0 and (GREEN .. "your level|r · %d"):format(#inGroup) or ("%d %s"):format(#inGroup, noun))
                h.sign:SetText(opened[g] and "-" or "+")
                y = y + HEAD_H + 4
            end
            for _, d in ipairs(opened[g] and inGroup or {}) do
            i = i + 1
            local r = Row(i)
            r.dungeon = d
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 0, -y)
            local killed = 0
            for _, b in ipairs(d.bosses) do
                if D.KillCount(b[2], game) > 0 then killed = killed + 1 end
            end
            r.name:SetText(d.name)
            local levelText = ("Level %d+"):format(d.level)
            if Fits(d, level) then levelText = GREEN .. levelText .. "|r" end
            r.meta:SetText(levelText .. " · " .. d.zone)
            r.count:SetText(("%d/%d"):format(killed, #d.bosses))
            local on = d == chosen
            if on then chosenY = y end
            r.bg:SetShown(on)
            for _, edge in ipairs(r.edges) do edge:SetShown(on) end
            r:SetAlpha(TooHigh(d, level) and not on and 0.5 or 1)
            r:Show()
            y = y + ROW_H
            end
            if opened[g] and #inGroup > 0 then y = y + 6 end
        end
        for j = i + 1, #rows do rows[j]:Hide() end
        list:SetHeight(math.max(1, y))
        -- The list is as tall as it needs, up to a limit, and opens at the
        -- chosen dungeon.
        local dropH = math.min(DROP_H, y + 12)
        drop:SetHeight(dropH)
        listScroll:SetHeight(dropH - 12)
        if not scrolled and drop:IsShown() then
            scrolled = true
            listScroll:SetVerticalScroll(math.max(0, math.min(listScroll:GetVerticalScrollRange(), chosenY - 2 * ROW_H)))
        end

        -- The chosen dungeon.
        local d = chosen
        if not d then return end
        pickerName:SetText(d.name)
        title:SetText(d.name)
        local killed = 0
        for _, b in ipairs(d.bosses) do
            if D.KillCount(b[2], game) > 0 then killed = killed + 1 end
        end
        local bits = { (d.raid and "Raid · level %d+" or "Level %d+"):format(d.level), d.zone }
        if d.faction then bits[#bits + 1] = d.faction end
        bits[#bits + 1] = ("%d of %d bosses killed"):format(killed, #d.bosses)
        meta:SetText(table.concat(bits, " · "))

        for _, it in ipairs(items) do it:Hide() end
        for _, q in ipairs(questRows) do q:Hide() end
        for _, row in ipairs(bossRows) do row:Hide() end
        none:Hide()
        local quests = {}
        for _, q in ipairs(ns.DungeonQuests and ns.DungeonQuests[d.id] or {}) do
            local side = QUEST_SIDE[q[5]]
            if not side or side == faction then quests[#quests + 1] = q end
        end
        tabs.quests:SetLabel(#quests > 0 and ("Quests (%d)"):format(#quests) or "Quests")
        tabs.bosses:SetKind(tab == "bosses" and "primary" or "plain")
        tabs.quests:SetKind(tab == "quests" and "primary" or "plain")
        local by = 0
        if tab == "quests" then
            hint:SetText(#quests > 0 and "hover one for its details" or "")
            for k, q in ipairs(quests) do
                local row = QuestRow(k)
                row.quest = q[1]
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 0, -by)
                local done = QuestDone(q[1])
                row.name:SetText(q[2])
                local bits = { ("From level %d"):format(q[4] or q[3]) }
                if QUEST_SIDE[q[5]] then bits[#bits + 1] = QUEST_SIDE[q[5]] end
                if done then bits[#bits + 1] = "done" end
                row.detail:SetText(table.concat(bits, " · "))
                row.level:SetText(("Level %d"):format(q[3]))
                row.boxFill:SetShown(done)
                row.tick:SetShown(done)
                Style.SetBorder(row.boxEdges, done and "wordGreen" or "lineStrong")
                row:Show()
                by = by + QUEST_H
            end
            if #quests == 0 then
                none:ClearAllPoints()
                none:SetPoint("TOPLEFT", 0, -8)
                none:SetText("No quests for this one on Wowhead yet.")
                none:Show()
                by = 40
            end
            bossList:SetHeight(math.max(1, by))
            bossScroll:SetVerticalScroll(math.min(bossScroll:GetVerticalScroll(), bossScroll:GetVerticalScrollRange()))
            return
        end
        hint:SetText("click a boss for its loot")
        for k, b in ipairs(d.bosses) do
            local row = BossRow(k)
            row.boss = b[2]
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -by)
            local n = D.KillCount(b[2], game)
            row.name:SetText(b[2])
            row.kills:SetText(n > 0 and ("killed %d×"):format(n) or "")
            row.boxFill:SetShown(n > 0)
            row.tick:SetShown(n > 0)
            Style.SetBorder(row.boxEdges, n > 0 and "wordGreen" or "lineStrong")
            local open = chosenBoss == b[2]
            row.bg:SetShown(open)
            row.name:SetTextColor(Style.Color(open and "gold" or "text"))
            row:Show()
            by = by + BOSS_H
            if open then by = PaintLoot(b[2], b[1], by) end
        end
        for k = #d.bosses + 1, #bossRows do bossRows[k]:Hide() end
        bossList:SetHeight(math.max(1, by))
        bossScroll:SetVerticalScroll(math.min(bossScroll:GetVerticalScroll(), bossScroll:GetVerticalScrollRange()))
    end

    page.Refresh = function() Paint() end
    -- Item names and icons the game hadn't loaded yet arrive a moment later.
    page:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    page:SetScript("OnEvent", function()
        if page:IsVisible() and chosenBoss then Paint() end
    end)
end)
