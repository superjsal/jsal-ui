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

-- The place a quest starts in, for grouping the list by where you pick
-- them up, and how such a place sorts: 1 a zone, 2 inside the dungeon,
-- 3 anything else (an item, or nothing known).
function Starts.Place(s)
    if not (s and s[2]) then return "Not on Wowhead yet", 3 end
    if s[3] == 3 then return "From an item", 3 end
    local zone = Starts.Area(s[4])
    if not zone then return "Place not known", 3 end
    if s[5] == 0 then return "Inside " .. zone, 2 end
    return zone, 1
end

-- A place, as the end of a sentence about another quest: "in Ironforge",
-- "inside Gnomeregan", "started by an item"; nil for a place not known.
-- (It read "first Lost Relic Carry, in From an item": John, 13 Nov 2026.)
function Starts.In(place, kind)
    if kind == 1 then return "in " .. place end
    if kind == 2 then return (place:gsub("^Inside ", "inside ")) end
    if place == "From an item" then return "started by an item" end
    return nil
end

-- Who or what starts it, with the spot when there is one: the zone is the
-- heading it sits under.
function Starts.Who(s)
    if not (s and s[2]) then return "" end
    if s[3] == 3 then return Starts.Where(s) or "" end
    if s[5] ~= 0 and s[6] and s[6] > 0 then return ("%s (%.0f, %.0f)"):format(s[2], s[6], s[7] or 0) end
    return s[2]
end

-- The quest that follows one: the lowest-numbered that names it as the one
-- before it.
local following
function Starts.Next(id)
    if not ns.DungeonQuestStarts then return nil end
    if not following then
        following = {}
        for quest, s in pairs(ns.DungeonQuestStarts) do
            local before = s[8]
            if before and (not following[before] or quest < following[before]) then following[before] = quest end
        end
    end
    return following[id]
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

-- Whether you can't equip a thing at all: a weapon your class never
-- wields, a shield without the use of one, armor heavier than you can wear.
-- Armor lighter than yours is not that: you can wear it, and it may be the
-- better piece (John, 13 Nov 2026: "if its a good cloth piece for some
-- reason it'll still show?", "some warriors equip nonplate gear for dps").
-- Nor is a weapon your class can learn and you haven't yet.
local function CantEquip(classID, subclassID, equipLoc)
    if ForYou(classID, subclassID, equipLoc) ~= false then return false end
    local _, classFile = UnitClass("player")
    if ns.Gear.CanWear and ns.Gear.CanWear(classFile, UnitLevel("player") or 1, classID, subclassID) then return false end
    return true
end
local RED = Style.Tint("red")

Window.Page("dungeons", function(page)
    local D = ns.Dungeons
    local width, height = page.contentWidth or Window.contentWidth, page.contentHeight or Window.contentHeight
    local rightW = width
    local chosen, scrolled
    local Paint, opened
    -- The bosses whose folded loot (what you can't equip) has been opened.
    local unfolded = {}

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
    local bossRows = {}
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

    -- The quests tab, by where they start: a bar for each place, a line
    -- for each quest, and a ticked line for a finished quest above the one
    -- it opens.
    local Q = { lines = {}, heads = {}, priors = {} }
    function Q.Line(i)
        if Q.lines[i] then return Q.lines[i] end
        local q = CreateFrame("Frame", nil, bossList)
        q:SetSize(rightW, 25)
        -- Joins it to the line above: the quest it follows.
        q.down = q:CreateTexture(nil, "ARTWORK")
        q.down:SetColorTexture(Style.Color("lineStrong"))
        q.down:SetPoint("TOPLEFT", 15, 6)
        q.down:SetSize(1, 18)
        q.across = q:CreateTexture(nil, "ARTWORK")
        q.across:SetColorTexture(Style.Color("lineStrong"))
        q.across:SetPoint("TOPLEFT", 15, -12)
        q.across:SetSize(10, 1)
        q.level = Style.Text(q, 12, "muted")
        q.level:SetPoint("RIGHT", -10, 0)
        q.level:SetJustifyH("RIGHT")
        q.name = Style.Text(q, 13, "text")
        q.name:SetWordWrap(false)
        q.who = Style.Text(q, 11, "muted")
        q.who:SetPoint("LEFT", q.name, "RIGHT", 10, 0)
        q.who:SetWordWrap(false)
        q.note = Style.Text(q, 11, "gold")
        q.note:SetPoint("LEFT", q.who, "RIGHT", 12, 0)
        q.note:SetPoint("RIGHT", q.level, "LEFT", -12, 0)
        q.note:SetJustifyH("LEFT")
        q.note:SetWordWrap(false)
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
        Q.lines[i] = q
        return q
    end
    function Q.Head(i)
        if Q.heads[i] then return Q.heads[i] end
        local h = CreateFrame("Button", nil, bossList)
        h:SetSize(rightW, 30)
        Style.Fill(h, "well")
        -- The place is what the list is sorted by, so it's the largest
        -- thing in it (John, 13 Nov 2026: "make the location text slightly
        -- bigger to emphasize the location").
        h.name = Style.Text(h, 14, "text", nil, true)
        h.name:SetPoint("LEFT", 10, 0)
        h.count = Style.Text(h, 12, "muted")
        h.count:SetPoint("LEFT", h.name, "RIGHT", 8, 0)
        h.link = Style.Text(h, 11, "gold")
        h.link:SetPoint("RIGHT", -10, 0)
        h.link:SetText("show on map")
        h:SetScript("OnClick", function(self)
            if self.spot then Starts.Pin(self.spot) end
        end)
        Q.heads[i] = h
        return h
    end
    -- The quest before another, above it: a finished one ticked and greyed
    -- with "done" after its name; one still to do, that isn't one of the
    -- dungeon's own, with an empty box and where it starts.
    function Q.Prior(i)
        if Q.priors[i] then return Q.priors[i] end
        local l = CreateFrame("Frame", nil, bossList)
        l:SetSize(rightW, 21)
        l.box = CreateFrame("Frame", nil, l)
        l.box:SetSize(12, 12)
        l.box:SetPoint("LEFT", 10, 0)
        l.fill = Style.Fill(l.box, "wordGreen")
        l.edges = Style.Border(l.box, "lineStrong")
        l.tick = l.box:CreateTexture(nil, "OVERLAY")
        l.tick:SetSize(14, 14)
        l.tick:SetPoint("CENTER", 1, 0)
        l.tick:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        l.tick:SetDesaturated(true)
        l.tick:SetVertexColor(1, 1, 1)
        l.name = Style.Text(l, 12, "muted")
        l.name:SetPoint("LEFT", l.box, "RIGHT", 8, 0)
        l.name:SetWordWrap(false)
        l.done = Style.Text(l, 11, "muted")
        l.done:SetPoint("LEFT", l.name, "RIGHT", 8, 0)
        Q.priors[i] = l
        return l
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
        -- At the right: how often it drops, and under that how often the
        -- guild has seen it.
        it.chance = Style.Text(it, 13, "text", nil, true)
        it.chance:SetPoint("TOPRIGHT", 0, -1)
        it.chance:SetJustifyH("RIGHT")
        it.seen = Style.Text(it, 11, "muted")
        it.seen:SetPoint("BOTTOMRIGHT", 0, 1)
        it.seen:SetJustifyH("RIGHT")
        it.name = Style.Text(it, 14, "text")
        it.name:SetPoint("TOPLEFT", it.icon, "TOPRIGHT", 8, 0)
        it.name:SetWidth(itemW - 40 - 70)
        it.name:SetJustifyH("LEFT")
        it.name:SetWordWrap(false)
        it.slot = Style.Text(it, 12, "muted")
        it.slot:SetPoint("BOTTOMLEFT", it.icon, "BOTTOMRIGHT", 8, 0)
        it.slot:SetWidth(itemW - 40 - 150)
        it.slot:SetJustifyH("LEFT")
        it.slot:SetWordWrap(false)
        it.star = it:CreateTexture(nil, "OVERLAY")
        it.star:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")
        it.star:SetSize(16, 16)
        it.star:SetPoint("TOPRIGHT", it.chance, "TOPLEFT", -6, 1)
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
        if card.more then card.more:Hide() end
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
        -- What you can't equip is folded into one line at the foot of the
        -- card, to open; a piece on your gear plan is never folded away.
        local starredSet = ns.Gear and ns.Gear.Starred() or {}
        local mine, others = {}, {}
        for _, entry in ipairs(list) do
            local _, _, _, _, _, _, _, _, equipLoc, _, classID, subclassID = ItemInfo(entry.id)
            entry.cant = starredSet[entry.id] ~= true and CantEquip(classID, subclassID, equipLoc)
            local to = entry.cant and others or mine
            to[#to + 1] = entry
        end
        local open = unfolded[boss] == true
        local shown = {}
        for _, entry in ipairs(mine) do shown[#shown + 1] = entry end
        if open then
            for _, entry in ipairs(others) do shown[#shown + 1] = entry end
        end
        for i, entry in ipairs(shown) do
            local it = Item(card, i)
            it:ClearAllPoints()
            it:SetPoint("TOPLEFT", 12, -(BOSS_H + 6 + (i - 1) * ITEM_H))
            it.item = entry.id
            local name, _, quality, _, req, _, subclass, _, equipLoc, texture = ItemInfo(entry.id)
            local q = quality or entry.item.q or 1
            it.name:SetText(("|cff%s%s|r"):format(Style.Quality(q), name or entry.item.n or "..."))
            local slot = equipLoc and equipLoc ~= "" and _G[equipLoc] or nil
            local parts = {}
            -- Recipes and other things you don't wear have a blank slot name.
            if slot and slot ~= "" then parts[#parts + 1] = slot end
            if subclass and subclass ~= "" and subclass ~= slot and subclass ~= "Miscellaneous" then parts[#parts + 1] = subclass end
            -- Too high for you yet: its level, in red.
            if req and req > (UnitLevel("player") or 1) then parts[#parts + 1] = ("%slevel %d|r"):format(RED, req) end
            it.slot:SetText(table.concat(parts, " · "))
            it.chance:SetText((entry.chance or entry.guessed) and ("%d%%"):format(entry.chance or entry.guessed) or "")
            -- How often it's been seen: in the guild's kills, or by you.
            if entry.guild then
                it.seen:SetText(("dropped %d× in %d guild kill%s"):format(entry.guild, guildKills, guildKills == 1 and "" or "s"))
            elseif (entry.item.seen or 0) > 0 then
                it.seen:SetText(entry.item.seen > 1 and ("you've seen it %d×"):format(entry.item.seen) or "you've seen it")
            else
                it.seen:SetText("")
            end
            it:SetAlpha(entry.cant and 0.55 or 1)
            local starred = starredSet[entry.id] == true
            it.star:SetShown(starred)
            it.edge:SetShown(starred)
            it.icon:SetTexture(texture or Compat.ItemIcon(entry.id) or "Interface\\Icons\\INV_Misc_QuestionMark")
            it:Show()
        end
        local h = BOSS_H + 6 + #shown * ITEM_H + 4
        if #others > 0 then
            if not card.more then
                card.more = CreateFrame("Button", nil, card)
                card.more:SetSize(itemW, 20)
                card.more.text = Style.Text(card.more, 11, "muted")
                card.more.text:SetPoint("LEFT", 38, 0)
                Style.Hover(card.more, 4)
            end
            card.more.text:SetText(open and "Show fewer" or ("%d more you can't equip · Show"):format(#others))
            card.more:SetScript("OnClick", function()
                unfolded[boss] = not open or nil
                Paint()
            end)
            card.more:ClearAllPoints()
            card.more:SetPoint("TOPLEFT", 12, -(h - 2))
            card.more:Show()
            h = h + 24
        elseif card.more then
            card.more:Hide()
        end
        return h
    end

    -- Paints the quests tab from `by` down the list, and returns where it
    -- ended.
    function Q.Paint(quests, by)
        -- By where they start, so one trip picks up every quest a place
        -- has. A place lists what can be picked up there now; a chain's
        -- later parts sit under its first part, wherever they start, as
        -- they can't be taken yet (John, 13 Nov 2026, of parts listed each
        -- under its own place and tagged: "a little confused on why some
        -- are 2 of 2 and one is 1 of 2"; the tag went once the parts sat
        -- together). A finished quest is ticked above the one it
        -- opens ("can we make it clearer which one thats done belongs to
        -- which questline if jts a prereq?"); what's finished and opens
        -- nothing goes last.
        local mine = UnitLevel("player") or 1
        local byId, todo, finished = {}, {}, {}
        for _, q in ipairs(quests) do byId[q[1]] = q end
        for _, q in ipairs(quests) do
            local to = QuestDone(q[1]) and finished or todo
            to[#to + 1] = q
        end
        -- Each quest still to do, with its place and the one before it.
        local entries, opens = {}, {}
        for _, q in ipairs(todo) do
            local s = Starts.Get(q[1])
            local e = { q = q, s = s, before = s and s[8] or nil }
            e.place, e.kind = Starts.Place(s)
            if e.before and QuestDone(e.before) then opens[e.before] = true end
            entries[q[1]] = e
        end
        -- A later part: its first part is on the list and still to do. It
        -- goes under that one; the rest are what a place has for you now.
        local under, places, order, later = {}, {}, {}, 0
        for _, q in ipairs(todo) do
            local e = entries[q[1]]
            if e.before and entries[e.before] and e.before ~= q[1] then
                under[e.before] = under[e.before] or {}
                table.insert(under[e.before], e)
                later = later + 1
            else
                local place = places[e.place]
                if not place then
                    place = { name = e.place, kind = e.kind, list = {}, after = 0 }
                    places[e.place] = place
                    order[#order + 1] = place
                end
                place.list[#place.list + 1] = e
            end
        end
        local function ByLevel(x, y)
            if x.q[3] ~= y.q[3] then return x.q[3] < y.q[3] end
            return x.q[1] < y.q[1]
        end
        for _, list in pairs(under) do table.sort(list, ByLevel) end
        -- How many wait behind each of a place's quests, however deep.
        local function Behind(e, seen)
            local n = 0
            for _, child in ipairs(under[e.q[1]] or {}) do
                if not seen[child] then
                    seen[child] = true
                    n = n + 1 + Behind(child, seen)
                end
            end
            return n
        end
        for _, place in ipairs(order) do
            table.sort(place.list, ByLevel)
            local seen = {}
            for _, e in ipairs(place.list) do place.after = place.after + Behind(e, seen) end
        end
        -- Places, the ones with most to pick up first; inside the dungeon
        -- and the unknown last.
        table.sort(order, function(x, y)
            if x.kind ~= y.kind then return x.kind < y.kind end
            if #x.list ~= #y.list then return #x.list > #y.list end
            return x.name < y.name
        end)
        local now = #todo - later
        local counts = { ("%d to pick up now"):format(now) }
        if later > 0 then counts[#counts + 1] = ("%d after %s"):format(later, now == 1 and "it" or "those") end
        if #finished > 0 then counts[#counts + 1] = ("%d done"):format(#finished) end
        if ns.DungeonQuestStarts then counts[#counts + 1] = "click a quest or a place for a map pin" end
        hint:SetText(#quests > 0 and table.concat(counts, " · ") or "")

        local lines, heads, priors = 0, 0, 0
        -- done: a finished quest; else one to do first, and where.
        local function Prior(name, done, where)
            priors = priors + 1
            local l = Q.Prior(priors)
            l.name:SetText(name)
            l.fill:SetShown(done)
            l.tick:SetShown(done)
            l.done:SetText(done and (GREEN .. "done|r") or ("first" .. (where and (", " .. where) or "")))
            l:SetAlpha(done and 0.75 or 1)
            l:ClearAllPoints()
            l:SetPoint("TOPLEFT", 0, -by)
            l:Show()
            by = by + 21
        end
        -- parent: the entry it sits under, for a later part.
        local function Line(e, joined, parent)
            local q, s = e.q, e.s
            lines = lines + 1
            local row = Q.Line(lines)
            row.quest = q[1]
            row.spot = Starts.Spot(q[1], QuestDone)
            row.down:SetShown(joined)
            row.across:SetShown(joined)
            row.name:ClearAllPoints()
            row.name:SetPoint("LEFT", joined and 32 or 10, 0)
            row.name:SetText(q[2])
            -- A part you can't take yet is greyed.
            row.name:SetTextColor(Style.Color(parent and "muted" or "text"))
            -- Who starts it; for a later part that starts somewhere else,
            -- where that is, as its heading isn't the one above it.
            local who = Starts.Who(s)
            -- With neither known it says nothing: its place under its
            -- first part says it follows (it read "then:" and stopped, for
            -- a quest Wowhead has no start for: John's screenshot, 13 Nov
            -- 2026).
            if parent and e.place ~= parent.place then
                local where = Starts.In(e.place, e.kind)
                if where and who ~= "" then
                    who = ("then, %s: %s"):format(where, who)
                elseif where then
                    who = "then, " .. where
                elseif who ~= "" then
                    who = "then: " .. who
                end
            end
            row.who:SetText(who)
            -- What to know before going: it's in your log, or you're too
            -- low for it. What comes before and after it is drawn as lines
            -- above and below, never said here.
            local notes = {}
            if QuestHeld(q[1]) then notes[#notes + 1] = "in your quest log" end
            if (q[4] or q[3]) > mine then notes[#notes + 1] = ("%sneeds level %d|r"):format(RED, q[4] or q[3]) end
            row.note:SetText(table.concat(notes, " · "))
            row.level:SetText(("level %d"):format(q[3]))
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -by)
            row:Show()
            by = by + 25
        end
        -- What follows a quest and isn't one of this dungeon's: a line under
        -- it, as a later part has, so a chain that goes on past the list
        -- shows it (John, 13 Nov 2026: "should we add something for that
        -- then?").
        local function Beyond(id, e)
            local s = Starts.Get(id)
            if not (s and s[1] ~= "") then return end
            lines = lines + 1
            local row = Q.Line(lines)
            row.quest = id
            row.spot = (s[5] and s[5] > 0 and s[6] and s[6] > 0) and s or nil
            row.down:Show()
            row.across:Show()
            row.name:ClearAllPoints()
            row.name:SetPoint("LEFT", 32, 0)
            row.name:SetText(s[1])
            row.name:SetTextColor(Style.Color("muted"))
            local place, kind = Starts.Place(s)
            local where, who = Starts.In(place, kind), Starts.Who(s)
            row.who:SetText("then" .. ((where and place ~= e.place) and (", " .. where) or "") .. (who ~= "" and (": " .. who) or ""))
            row.note:SetText("")
            row.level:SetText("")
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -by)
            row:Show()
            by = by + 25
        end
        -- A chain reads the same way whichever of its parts are this
        -- dungeon's own: the quest before, above; the quest after, below.
        -- (The first part off the list was a gold note, "first The True
        -- Masters, in Burning Steppes": John, 13 Nov 2026, "confused on the
        -- first, i thought we were chaining them now?")
        local drawn = {}
        local function Emit(e, parent)
            if drawn[e] then return end
            drawn[e] = true
            local joined = parent ~= nil
            if not parent and e.before then
                -- Everything that leads up to it, back to the last one
                -- finished: each a line, the earliest at the top (John, 13
                -- Nov 2026: "if a start of the quest chains to a quest you
                -- need to do in a dungeon it should chain appropriately").
                local lead, id = {}, e.before
                while id and #lead < 6 and not entries[id] do
                    lead[#lead + 1] = id
                    if QuestDone(id) then break end
                    local s = Starts.Get(id)
                    id = s and s[8] or nil
                end
                for i = #lead, 1, -1 do
                    local quest = lead[i]
                    local first = Starts.Get(quest)
                    local name = (byId[quest] and byId[quest][2]) or (first and first[1] ~= "" and first[1]) or ("quest " .. quest)
                    if QuestDone(quest) then
                        Prior(name, true)
                    else
                        Prior(name, false, first and Starts.In(Starts.Place(first)) or nil)
                    end
                end
                joined = #lead > 0
            end
            Line(e, joined, parent)
            for _, child in ipairs(under[e.q[1]] or {}) do Emit(child, e) end
            local after = Starts.Next(e.q[1])
            if after and not byId[after] and not under[e.q[1]] and not QuestDone(after) then Beyond(after, e) end
        end
        for _, place in ipairs(order) do
            heads = heads + 1
            local h = Q.Head(heads)
            h.name:SetText(place.name)
            local count = ("%d quest%s"):format(#place.list, #place.list == 1 and "" or "s")
            if place.after > 0 then count = count .. (", and %d after %s"):format(place.after, #place.list == 1 and "it" or "them") end
            h.count:SetText(count)
            h.spot = nil
            for _, e in ipairs(place.list) do
                h.spot = h.spot or Starts.Spot(e.q[1], QuestDone)
            end
            h.link:SetShown(h.spot ~= nil)
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", 0, -by)
            h:Show()
            by = by + 36
            for _, e in ipairs(place.list) do Emit(e) end
            by = by + 8
        end
        -- Finished, and opening nothing still to do: last.
        local closed = {}
        for _, q in ipairs(finished) do
            if not opens[q[1]] then closed[#closed + 1] = q end
        end
        if #closed > 0 then
            heads = heads + 1
            local h = Q.Head(heads)
            h.name:SetText("Done")
            h.count:SetText(("%d quest%s, with nothing after %s"):format(#closed, #closed == 1 and "" or "s", #closed == 1 and "it" or "them"))
            h.spot = nil
            h.link:Hide()
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", 0, -by)
            h:Show()
            by = by + 36
            for _, q in ipairs(closed) do Prior(q[2], true) end
            by = by + 8
        end
        for k = lines + 1, #Q.lines do Q.lines[k]:Hide() end
        for k = heads + 1, #Q.heads do Q.heads[k]:Hide() end
        for k = priors + 1, #Q.priors do Q.priors[k]:Hide() end
        return by
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
        -- Beside the picker: how the dungeon chosen sits with your level.
        -- (It read "Green: right for level 30", a key to the list's colours
        -- that looked like a word on item colours.)
        if not chosen then
            key:SetText("")
        elseif Fits(chosen, level) then
            key:SetText(GREEN .. "right for level " .. level .. "|r")
        else
            key:SetText(level < chosen.level and ("from level " .. chosen.level) or "below your level")
        end
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

        for _, pool in ipairs({ Q.lines, Q.heads, Q.priors }) do
            for _, region in ipairs(pool) do region:Hide() end
        end
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
            by = Q.Paint(quests, by)
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
        hint:SetText((ns.Gear and ns.Gear.STAR and (ns.Gear.STAR .. " on your gear plan · ") or "") .. "hover an item for its details")
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
