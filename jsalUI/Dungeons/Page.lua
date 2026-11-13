-- The dungeon guide, in a window of its own: a picker on top opens every
-- dungeon and raid in level groups, the ones right for your level in green;
-- the chosen one fills the window below in two tabs. Bosses and loot: a card per boss, two to a row in
-- the game's order, ticked once you've killed it, with its loot listed on
-- it (Wowhead's list with drop chances, and what you and the guild have seen it drop).
-- Quests: the dungeon's quests for your faction, ticked once done, each with
-- where it starts and the quest to do first; a click pins the start on the map.
-- Loot starred in the gear plan has a gold star and edge, and the picker
-- counts each dungeon's starred loot.
local _, ns = ...
local Style, Compat, Window = ns.Style, ns.Compat, ns.Window

local DROP_W, DROP_H, PICKER_H, ROW_H, HEAD_H, BOSS_H, ITEM_H, QUEST_H, CARD_GAP = 340, 520, 34, 50, 28, 38, 38, 48, 12

-- Wowhead's quest sides: 1 Alliance, 2 Horde, 3 both.
local QUEST_SIDE = { [1] = "Alliance", [2] = "Horde" }

local function QuestDone(id)
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then return C_QuestLog.IsQuestFlaggedCompleted(id) and true or false end
    return IsQuestFlaggedCompleted and IsQuestFlaggedCompleted(id) and true or false
end

-- In your quest log now: picked up and not yet handed in.
local function QuestHeld(id)
    if C_QuestLog and C_QuestLog.GetLogIndexForQuestID then
        local index = C_QuestLog.GetLogIndexForQuestID(id)
        return index ~= nil and index > 0
    end
    if GetQuestLogIndexByID then return (GetQuestLogIndexByID(id) or 0) > 0 end
    if not (GetNumQuestLogEntries and GetQuestLogTitle) then return false end
    for i = 1, (GetNumQuestLogEntries()) do
        if select(8, GetQuestLogTitle(i)) == id then return true end
    end
    return false
end

-- Where a quest starts, and the quest before it, from ns.DungeonQuestStarts:
-- { name, who or what starts it, kind (1 NPC, 2 object, 3 item), area, map
-- for a pin (0 inside a dungeon), x, y (0 to 100), the quest before it, and
-- for an item, who drops it and true when that's an object it's found in }.
-- One table, so the page's long functions gain a single upvalue.
local Starts = {}

function Starts.Get(id) return ns.DungeonQuestStarts and ns.DungeonQuestStarts[id] end

function Starts.Area(area)
    if not area or area <= 0 then return nil end
    local name = C_Map and C_Map.GetAreaInfo and Compat.Plain(C_Map.GetAreaInfo(area))
    return name ~= "" and name or nil
end

-- "Gerrig Bonegrip, Ironforge (50, 6)", "Argent Guard Thaelrid, inside
-- Blackfathom Deeps", "from Head of Balnazzar, dropped by Balnazzar in
-- Stratholme"; nil when nothing is known.
function Starts.Where(s)
    if not (s and s[2]) then return nil end
    local who = "|cffc4bfb0" .. s[2] .. "|r"
    local zone = Starts.Area(s[4])
    if s[3] == 3 then
        local by = s[10] and "found in" or "dropped by"
        if s[9] and zone then return ("from %s, %s %s in %s"):format(who, by, s[9], zone) end
        if s[9] then return ("from %s, %s %s"):format(who, by, s[9]) end
        if zone then return ("from %s, %s %s"):format(who, s[10] and "found in" or "dropped in", zone) end
        return ("from %s, a dropped item"):format(who)
    end
    if not zone then return who end
    if s[5] == 0 then return ("%s, inside %s"):format(who, zone) end
    if s[6] and s[6] > 0 then return ("%s, %s (%.0f, %.0f)"):format(who, zone, s[6], s[7] or 0) end
    return ("%s, %s"):format(who, zone)
end

function Starts.Line(id)
    if not ns.DungeonQuestStarts then return nil end
    local where = Starts.Where(Starts.Get(id))
    return "Starts: " .. (where or "not on Wowhead yet")
end

-- The quest before it, when there is one: on this list, or where it starts.
function Starts.First(id, onList, done)
    local s = Starts.Get(id)
    local prev = s and s[8]
    if not prev then return nil end
    local p = Starts.Get(prev)
    local text = "|cffe3b04bFirst:|r |cffece6d6" .. (p and p[1] ~= "" and p[1] or ("quest " .. prev)) .. "|r"
    if done(prev) then return text .. ", done" end
    if onList[prev] then return text .. ", on this list" end
    local where = Starts.Where(p)
    return where and (text .. ", from " .. where) or text
end

-- The spot to pin for a quest: its own start, or the start of the quest
-- before it while that one isn't done. Nil when neither has a spot.
function Starts.Spot(id, done)
    local s = Starts.Get(id)
    if s and s[5] and s[5] > 0 and s[6] and s[6] > 0 then return s end
    local p = s and s[8] and not done(s[8]) and Starts.Get(s[8])
    if p and p[5] and p[5] > 0 and p[6] and p[6] > 0 then return p end
    return nil
end

function Starts.Pin(s)
    local set = ns.Waypoint and ns.Waypoint.Set or function(map, x, y) return Compat.SetWaypoint(map, x, y) end
    local zone = Starts.Area(s[4]) or "?"
    if set(s[5], s[6] / 100, s[7] / 100, s[2], "quest") then
        ns.Print(("Map pin set on %s, %s."):format(s[2], zone))
    else
        ns.Print(("%s is at %.0f, %.0f in %s."):format(s[2], s[6], s[7], zone))
    end
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

local GREEN = Style.Tint("green")

-- The side of the world its entrance is on, in that faction's colour; a
-- dungeon only one faction can enter says so. Contested ones say nothing.
local SIDE_COLOR = { Horde = Style.Tint("red"), Alliance = "|cff5b9be6" }
local function SideText(d)
    local side = d.faction or d.side
    if not side then return nil end
    return SIDE_COLOR[side] .. side .. (d.faction and " only" or " side") .. "|r"
end

-- An item's details, asking the game to load them when it hasn't yet.
local function ItemInfo(id)
    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local name, link, quality, ilvl, req, class, subclass, stack, equipLoc, texture, _, classID, subclassID = get(id)
    if not name and C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
    return name, link, quality, ilvl, req, class, subclass, stack, equipLoc, texture, classID, subclassID
end

-- Whether an item is for you: the gear plan's rules of what each class
-- wears and wields. Nil when the game hasn't loaded the item yet.
local function ForYou(classID, subclassID, equipLoc)
    if not classID then return nil end
    local _, classFile = UnitClass("player")
    return ns.Gear.ForClass(classFile, UnitLevel("player") or 1, classID, subclassID, equipLoc)
end
local RED = Style.Tint("red")

Window.Page("dungeons", function(page)
    local D = ns.Dungeons
    local width, height = page.contentWidth or Window.contentWidth, page.contentHeight or Window.contentHeight
    local rightW = width
    local chosen, scrolled
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
    -- A gold "v", drawn from two short strokes.
    for _, way in ipairs({ -1, 1 }) do
        local stroke = picker:CreateTexture(nil, "ARTWORK")
        stroke:SetSize(8, 2)
        stroke:SetColorTexture(Style.Color("gold"))
        stroke:SetPoint("RIGHT", -14 - (way == -1 and 5 or 0), 0)
        stroke:SetRotation(math.rad(45 * way))
    end
    local key = Style.Text(page, 12, "muted")
    key:SetPoint("LEFT", picker, "RIGHT", 14, 0)

    local drop = CreateFrame("Frame", nil, page)
    drop:SetPoint("TOPLEFT", picker, "BOTTOMLEFT", 0, -4)
    drop:SetSize(DROP_W, DROP_H)
    drop:SetFrameStrata("DIALOG")
    drop:EnableMouse(true)
    Style.Fill(drop, "titleBar")
    Style.Border(drop, "lineStrong")
    drop:Hide()
    local listScroll, list = Style.Scroller(drop, DROP_W - 12, DROP_H - 12, DROP_W - 20)
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
        Style.Border(h, "cardLine")
        h.sign = Style.Text(h, 14, "gold", nil, true)
        h.sign:SetPoint("LEFT", 10, 0)
        h.label = Style.Text(h, 12, "gold", nil, true)
        h.label:SetPoint("LEFT", 26, 0)
        h.note = Style.Text(h, 12, "muted")
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
        r.name = Style.Text(r, 14, "text", nil, true)
        r.name:SetPoint("TOPLEFT", 10, -7)
        r.name:SetWidth(rowW - 56)
        r.name:SetJustifyH("LEFT")
        r.name:SetWordWrap(false)
        r.meta = Style.Text(r, 12, "muted")
        r.meta:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
        r.meta:SetWidth(rowW - 20)
        r.meta:SetJustifyH("LEFT")
        r.meta:SetWordWrap(false)
        r.count = Style.Text(r, 12, "muted")
        r.count:SetPoint("TOPRIGHT", -10, -8)
        r:SetScript("OnClick", function(self)
            chosen = self.dungeon
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
    -- The picker above is the dungeon's name; under it, its level, where it
    -- is, and how many of its bosses you've killed.
    local meta = Style.Text(right, 13, "muted")
    meta:SetPoint("TOPLEFT")
    meta:SetWidth(rightW)
    meta:SetJustifyH("LEFT")
    -- Two tabs: the bosses with their loot, and the dungeon's quests.
    local tab = "bosses"
    local tabs = {}
    for k, t in ipairs({ { "bosses", "Bosses and loot", 150 }, { "quests", "Quests", 120 } }) do
        local b = Style.Button(right, t[2], "tab", t[3])
        b:SetPoint("TOPLEFT", k == 1 and 0 or 156, -28)
        b:SetScript("OnClick", function()
            tab = t[1]
            Paint()
        end)
        tabs[t[1]] = b
    end
    local hint = Style.Text(right, 12, "muted")
    hint:SetPoint("TOPRIGHT", 0, -36)
    hint:SetJustifyH("RIGHT")
    local bossScroll, bossList = Style.Scroller(right, rightW + 8, height - PICKER_H - 16 - 68, rightW)
    bossScroll:SetPoint("TOPLEFT", 0, -68)
    local bossRows, questRows = {}, {}
    local none = Style.Text(bossList, 13, "muted")
    none:SetWidth(rightW - 36)
    none:SetJustifyH("LEFT")
    -- Under each tab: where its lists come from, and that they're incomplete.
    local NOTE = {
        bosses = "Loot and drop chances come from Wowhead Forever and what you and your guild have seen drop. They're incomplete, especially past level 30, and will change as more people play.",
        quests = "Quests and where they start come from Wowhead Forever. Some may be missing, and they'll change as more people play.",
    }
    local note = Style.Text(bossList, 12, "muted")
    note:SetWidth(rightW - 8)
    note:SetJustifyH("LEFT")
    local function PlaceNote(which, y)
        note:SetText(NOTE[which])
        note:ClearAllPoints()
        note:SetPoint("TOPLEFT", 0, -(y + 6))
        note:Show()
        return y + 6 + 32
    end

    -- A boss's card: its name, ticked once you've killed it, and its loot
    -- under it, one item to a line.
    local cardW = math.floor((rightW - CARD_GAP) / 2)
    local function BossRow(i)
        if bossRows[i] then return bossRows[i] end
        local b = CreateFrame("Frame", nil, bossList)
        b:SetSize(cardW, BOSS_H)
        Style.Fill(b, "well")
        Style.Border(b, "cardLine")
        b.head = CreateFrame("Frame", nil, b)
        b.head:SetPoint("TOPLEFT")
        b.head:SetPoint("TOPRIGHT")
        b.head:SetHeight(BOSS_H)
        Style.Rule(b.head, "BOTTOM", "line")
        b.box = CreateFrame("Frame", nil, b.head)
        b.box:SetSize(16, 16)
        b.box:SetPoint("LEFT", 10, 0)
        b.boxFill = Style.Fill(b.box, "wordGreen")
        b.boxEdges = Style.Border(b.box, "lineStrong")
        -- The game's own check mark, in white.
        b.tick = b.box:CreateTexture(nil, "OVERLAY")
        b.tick:SetSize(16, 16)
        b.tick:SetPoint("CENTER", 1, 0)
        b.tick:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        b.tick:SetDesaturated(true)
        b.tick:SetVertexColor(1, 1, 1)
        b.name = Style.Text(b.head, 15, "text", nil, true)
        b.name:SetPoint("LEFT", b.box, "RIGHT", 10, 0)
        b.name:SetWidth(cardW - 120)
        b.name:SetJustifyH("LEFT")
        b.name:SetWordWrap(false)
        b.kills = Style.Text(b.head, 12, "muted")
        b.kills:SetPoint("RIGHT", -10, 0)
        b.none = Style.Text(b, 12, "muted")
        b.none:SetPoint("TOPLEFT", 12, -(BOSS_H + 8))
        b.none:SetWidth(cardW - 24)
        b.none:SetJustifyH("LEFT")
        b.items = {}
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
        q.box:SetPoint("TOPLEFT", 8, -16)
        q.boxFill = Style.Fill(q.box, "wordGreen")
        q.boxEdges = Style.Border(q.box, "lineStrong")
        q.tick = q.box:CreateTexture(nil, "OVERLAY")
        q.tick:SetSize(16, 16)
        q.tick:SetPoint("CENTER", 1, 0)
        q.tick:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        q.tick:SetDesaturated(true)
        q.tick:SetVertexColor(1, 1, 1)
        q.name = Style.Text(q, 14, "text")
        q.name:SetPoint("TOPLEFT", q.box, "TOPRIGHT", 10, 4)
        q.name:SetWidth(rightW - 130)
        q.name:SetJustifyH("LEFT")
        q.name:SetWordWrap(false)
        q.detail = Style.Text(q, 12, "muted")
        q.detail:SetPoint("TOPLEFT", q.name, "BOTTOMLEFT", 0, -3)
        q.detail:SetWidth(rightW - 130)
        q.detail:SetJustifyH("LEFT")
        -- Where it starts, and the quest to do before it, a line each.
        q.starts = Style.Text(q, 12, "muted")
        q.starts:SetPoint("TOPLEFT", q.detail, "BOTTOMLEFT", 0, -3)
        q.starts:SetWidth(rightW - 130)
        q.starts:SetJustifyH("LEFT")
        q.starts:SetWordWrap(false)
        q.first = Style.Text(q, 12, "muted")
        q.first:SetPoint("TOPLEFT", q.starts, "BOTTOMLEFT", 0, -3)
        q.first:SetWidth(rightW - 130)
        q.first:SetJustifyH("LEFT")
        q.first:SetWordWrap(false)
        q.level = Style.Text(q, 13, "muted")
        q.level:SetPoint("RIGHT", -10, 0)
        Style.Rule(q, "BOTTOM", "line")
        q:EnableMouse(true)
        q:SetScript("OnEnter", function(self)
            if not self.quest then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(("quest:%d"):format(self.quest))
            if self.spot then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(("Click to pin %s on your map"):format(self.spot[2]), 0.89, 0.69, 0.29)
            end
            GameTooltip:Show()
        end)
        q:SetScript("OnMouseUp", function(self, button)
            if button == "LeftButton" and self.spot then Starts.Pin(self.spot) end
        end)
        q:SetScript("OnLeave", function() GameTooltip:Hide() end)
        Style.Hover(q)
        questRows[i] = q
        return q
    end

    local itemW = cardW - 24
    local function Item(card, i)
        if card.items[i] then return card.items[i] end
        local it = CreateFrame("Frame", nil, card)
        it:SetSize(itemW, ITEM_H - 4)
        it.icon = it:CreateTexture(nil, "ARTWORK")
        it.icon:SetSize(30, 30)
        it.icon:SetPoint("LEFT")
        it.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        it.name = Style.Text(it, 14, "text")
        it.name:SetPoint("TOPLEFT", it.icon, "TOPRIGHT", 8, 0)
        it.name:SetWidth(itemW - 40)
        it.name:SetJustifyH("LEFT")
        it.name:SetWordWrap(false)
        it.slot = Style.Text(it, 12, "muted")
        it.slot:SetPoint("BOTTOMLEFT", it.icon, "BOTTOMRIGHT", 8, 0)
        it.slot:SetWidth(itemW - 40)
        it.slot:SetJustifyH("LEFT")
        it.slot:SetWordWrap(false)
        it.star = it:CreateTexture(nil, "OVERLAY")
        it.star:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")
        it.star:SetSize(16, 16)
        it.star:SetPoint("RIGHT", 0, 0)
        it.edge = it:CreateTexture(nil, "OVERLAY")
        it.edge:SetColorTexture(Style.Color("gold"))
        it.edge:SetWidth(2)
        it.edge:SetPoint("TOPLEFT", -8, 2)
        it.edge:SetPoint("BOTTOMLEFT", -8, -2)
        it:EnableMouse(true)
        it:SetScript("OnEnter", function(self)
            if not self.item then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(self.item)
            GameTooltip:Show()
        end)
        it:SetScript("OnLeave", function() GameTooltip:Hide() end)
        Style.Hover(it, 4)
        card.items[i] = it
        return it
    end

    -- A boss's loot on its card: Wowhead's list with each item's drop
    -- chance, then anything you or the guild have seen it drop that the list
    -- doesn't have, with how often in the guild's kills. Without Wowhead's
    -- chance, five or more guild kills give one. Returns the card's height.
    local function PaintLoot(card, boss, encounter)
        for _, it in ipairs(card.items) do it:Hide() end
        local list, byId = {}, {}
        local function Add(id)
            if not byId[id] then
                byId[id] = { id = id, item = {} }
                list[#list + 1] = byId[id]
            end
            return byId[id]
        end
        for _, drop in ipairs(ns.DungeonLoot and ns.DungeonLoot[encounter] or {}) do
            Add(drop[1]).chance = drop[2]
        end
        for id, item in pairs(D.Loot()[D.Key(boss)] or {}) do Add(id).item = item end
        local guild = ns.GuildLoot and ns.GuildLoot.On() and ns.GuildLoot.For(encounter)
        local guildKills = 0
        if guild then
            for id, n in pairs(guild.i or {}) do
                Add(id).guild = n
                guildKills = math.max(guildKills, n)
            end
            guildKills = math.max(guildKills, guild.k or 0)
            for _, entry in ipairs(list) do
                if entry.guild and not entry.chance and guildKills >= 5 then
                    entry.guessed = math.floor(entry.guild / guildKills * 100 + 0.5)
                end
            end
        end
        table.sort(list, function(a, b)
            local ca, cb = a.chance or a.guessed or 0, b.chance or b.guessed or 0
            if ca ~= cb then return ca > cb end
            if (a.item.q or 0) ~= (b.item.q or 0) then return (a.item.q or 0) > (b.item.q or 0) end
            return a.id < b.id
        end)
        if #list == 0 then
            card.none:SetText("No loot known yet. It's added when you or a guildmate with jsal.ui loots this boss.")
            card.none:Show()
            return BOSS_H + 46
        end
        card.none:Hide()
        for i, entry in ipairs(list) do
            local it = Item(card, i)
            it:ClearAllPoints()
            it:SetPoint("TOPLEFT", 12, -(BOSS_H + 6 + (i - 1) * ITEM_H))
            it.item = entry.id
            local name, _, quality, _, req, _, subclass, _, equipLoc, texture, classID, subclassID = ItemInfo(entry.id)
            local q = quality or entry.item.q or 1
            it.name:SetText(("|cff%s%s|r"):format(Style.Quality(q), name or entry.item.n or "..."))
            local slot = equipLoc and equipLoc ~= "" and _G[equipLoc] or nil
            local parts = {}
            if entry.chance or entry.guessed then parts[#parts + 1] = ("%d%%"):format(entry.chance or entry.guessed) end
            -- Recipes and other things you don't wear have a blank slot name.
            if slot and slot ~= "" then parts[#parts + 1] = slot end
            if subclass and subclass ~= "" and subclass ~= slot and subclass ~= "Miscellaneous" then parts[#parts + 1] = subclass end
            -- Too high for you yet: its level, in red.
            if req and req > (UnitLevel("player") or 1) then parts[#parts + 1] = ("%slevel %d|r"):format(RED, req) end
            -- Not for your class or armor type: dimmed.
            it:SetAlpha(ForYou(classID, subclassID, equipLoc) == false and 0.55 or 1)
            if entry.guild then
                parts[#parts + 1] = ("guild %d of %d"):format(entry.guild, guildKills)
            elseif (entry.item.seen or 0) > 0 then
                parts[#parts + 1] = entry.item.seen > 1 and ("you've seen it %d×"):format(entry.item.seen) or "you've seen it"
            end
            it.slot:SetText(table.concat(parts, " · "))
            local starred = ns.Gear and ns.Gear.Starred()[entry.id] == true
            it.star:SetShown(starred)
            it.edge:SetShown(starred)
            it.name:SetWidth(itemW - (starred and 62 or 40))
            if starred then it:SetAlpha(1) end
            it.icon:SetTexture(texture or Compat.ItemIcon(entry.id) or "Interface\\Icons\\INV_Misc_QuestionMark")
            it:Show()
        end
        return BOSS_H + 6 + #list * ITEM_H + 4
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
                if D.KillCount(b[2], game, b[3]) > 0 then killed = killed + 1 end
            end
            r.name:SetText(d.name)
            local levelText = ("Level %d+"):format(d.level)
            if Fits(d, level) then levelText = GREEN .. levelText .. "|r" end
            local side = SideText(d)
            r.meta:SetText(levelText .. " · " .. d.zone .. (side and (" · " .. side) or ""))
            local starredHere = ns.Gear and ns.Gear.StarsIn and #ns.Gear.StarsIn(d) or 0
            r.count:SetText((starredHere > 0 and (ns.Gear.STAR .. " |cffe3b04b" .. starredHere .. "|r   ") or "")
                .. ("%d/%d"):format(killed, #d.bosses))
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
        local killed = 0
        for _, b in ipairs(d.bosses) do
            if D.KillCount(b[2], game, b[3]) > 0 then killed = killed + 1 end
        end
        local bits = { (d.raid and "Raid · level %d+" or "Level %d+"):format(d.level), d.zone }
        if SideText(d) then bits[#bits + 1] = SideText(d) end
        bits[#bits + 1] = ("%d of %d bosses killed"):format(killed, #d.bosses)
        meta:SetText(table.concat(bits, " · "))

        for _, q in ipairs(questRows) do q:Hide() end
        for _, row in ipairs(bossRows) do row:Hide() end
        none:Hide()
        local quests = {}
        for _, q in ipairs(ns.DungeonQuests and ns.DungeonQuests[d.id] or {}) do
            local side = QUEST_SIDE[q[5]]
            if not side or side == faction then quests[#quests + 1] = q end
        end
        tabs.quests:SetLabel(#quests > 0 and ("Quests (%d)"):format(#quests) or "Quests")
        tabs.bosses:SetSelected(tab == "bosses")
        tabs.quests:SetSelected(tab == "quests")
        local by = 0
        if tab == "quests" then
            hint:SetText(#quests > 0 and (ns.DungeonQuestStarts and "hover one for its details · click to pin where it starts"
                or "hover one for its details") or "")
            local onList = {}
            for _, q in ipairs(quests) do onList[q[1]] = true end
            for k, q in ipairs(quests) do
                local row = QuestRow(k)
                row.quest = q[1]
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 0, -by)
                local done = QuestDone(q[1])
                row.name:SetText(q[2])
                local bits = { ("From level %d"):format(q[4] or q[3]) }
                if QUEST_SIDE[q[5]] then bits[#bits + 1] = QUEST_SIDE[q[5]] end
                if done then
                    bits[#bits + 1] = "done"
                elseif QuestHeld(q[1]) then
                    bits[#bits + 1] = "|cffe3b04bin your quest log|r"
                end
                row.detail:SetText(table.concat(bits, " · "))
                row.level:SetText(("Level %d"):format(q[3]))
                row.box:SetShown(done)
                -- Without a tick the name starts at the row's edge.
                row.name:ClearAllPoints()
                row.name:SetPoint("TOPLEFT", row, "TOPLEFT", done and 34 or 8, -12)
                Style.SetBorder(row.boxEdges, "wordGreen")
                -- Where it starts, and what comes first, a line each; the row
                -- grows to fit them.
                local starts, first = Starts.Line(q[1]), Starts.First(q[1], onList, QuestDone)
                row.starts:SetText(starts or "")
                row.first:SetText(first or "")
                row.starts:SetShown(starts ~= nil)
                row.first:SetShown(first ~= nil)
                row.spot = not done and Starts.Spot(q[1], QuestDone) or nil
                local h = QUEST_H + (starts and 17 or 0) + (first and 17 or 0)
                row:SetHeight(h)
                row:Show()
                by = by + h
            end
            if #quests == 0 then
                none:ClearAllPoints()
                none:SetPoint("TOPLEFT", 0, -8)
                none:SetText("No quests for this one on Wowhead yet.")
                none:Show()
                by = 40
            end
            by = PlaceNote("quests", by)
            bossList:SetHeight(math.max(1, by))
            bossScroll:SetVerticalScroll(math.min(bossScroll:GetVerticalScroll(), bossScroll:GetVerticalScrollRange()))
            return
        end
        -- The bosses as cards, two to a row in the game's order; a row is as
        -- tall as its taller card.
        hint:SetText("hover an item for its details")
        local rowH = 0
        for k, b in ipairs(d.bosses) do
            local card = BossRow(k)
            card.boss = b[2]
            local col = (k - 1) % 2
            local n = D.KillCount(b[2], game, b[3])
            card.name:SetText(b[3] or b[2])
            card.kills:SetText(n > 0 and ("killed %d×"):format(n) or "")
            card.box:SetShown(n > 0)
            -- Without a tick the name starts at the card's edge, over its loot.
            card.name:ClearAllPoints()
            if n > 0 then
                card.name:SetPoint("LEFT", card.box, "RIGHT", 10, 0)
            else
                card.name:SetPoint("LEFT", card.head, "LEFT", 12, 0)
            end
            Style.SetBorder(card.boxEdges, "wordGreen")
            local h = PaintLoot(card, b[2], b[1])
            card:SetHeight(h)
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", col * (cardW + CARD_GAP), -by)
            card:Show()
            rowH = math.max(rowH, h)
            if col == 1 or k == #d.bosses then
                by = by + rowH + CARD_GAP
                rowH = 0
            end
        end
        for k = #d.bosses + 1, #bossRows do bossRows[k]:Hide() end
        by = PlaceNote("bosses", by)
        bossList:SetHeight(math.max(1, by))
        bossScroll:SetVerticalScroll(math.min(bossScroll:GetVerticalScroll(), bossScroll:GetVerticalScrollRange()))
    end

    page.Refresh = function() Paint() end
    -- Item names and icons the game hadn't loaded yet arrive a moment later.
    -- They come one by one, so the page repaints once for a batch.
    local waiting
    page:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    page:SetScript("OnEvent", function()
        if waiting or not page:IsVisible() or tab ~= "bosses" then return end
        waiting = true
        Compat.After(0.2, function()
            waiting = nil
            if page:IsVisible() then Paint() end
        end)
    end)
-- In a window of its own, with room for the boss cards.
end, { width = 1000, height = 860 })
