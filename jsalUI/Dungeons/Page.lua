-- The dungeon guide, in a window of its own: a picker on top opens every
-- dungeon and raid in level groups, the ones right for your level in green;
-- the chosen one fills the window below in two tabs. Bosses and loot: a band
-- a boss, numbered in the game's order and ticked once you've killed it, its
-- loot under it two across (Wowhead's list with drop chances, and what you
-- and the guild have seen it drop): what's on your gear plan first, then
-- what's better than what you wear, then the rest by how often it drops.
-- Quests: the dungeon's quests for your faction, ticked once done, each with
-- where it starts and the quest to do first; a click pins the start on the map.
-- The picker counts each dungeon's starred loot.
local _, ns = ...
local Style, Compat, Window = ns.Style, ns.Compat, ns.Window

local DROP_W, DROP_H, PICKER_H, ROW_H, HEAD_H, BOSS_H, ITEM_H, QUEST_H, CARD_GAP = 340, 520, 34, 50, 28, 30, 38, 48, 12
-- The game's item class for recipes (patterns, plans, schematics).
local RECIPE = 9
-- The tag after an item's name: its words, its fill and its words' colour.
local TAGS = {
    plan = { "on your gear plan", "gold", "onGold" },
    better = { "better for you", "line", "green" },
    prof = { "your profession", "line", "secondary" },
}

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
-- Whether a quest is the other side's though its row says both: something
-- that leads up to it is a quest of theirs alone. Blackrock Depths' The
-- Royal Rescue is listed for both and starts with Thrall, after three
-- Horde quests; an Alliance hunter was shown it. `mine` is 1 for the
-- Alliance, 2 for the Horde.
local sideOf
function Starts.Theirs(id, mine)
    if not mine then return false end
    if not sideOf then
        sideOf = {}
        for _, list in pairs(ns.DungeonQuests or {}) do
            for _, q in ipairs(list) do
                if q[5] == 1 or q[5] == 2 then sideOf[q[1]] = q[5] end
            end
        end
    end
    local s, steps = Starts.Get(id), 0
    while s and s[8] and steps < 12 do
        if sideOf[s[8]] and sideOf[s[8]] ~= mine then return true end
        s, steps = Starts.Get(s[8]), steps + 1
    end
    return false
end

-- Whether a quest is one your class can take: its row's sixth number is
-- the classes it's for, a bit each by the game's class number, and missing
-- for a quest anyone can take. Zul'Gurub listed every class's Paragons of
-- Power to everyone (John, 13 Nov 2026: "we'll probably need to filter
-- these for current class as well").
function Starts.ForClass(q, classID)
    local classes = q[6]
    if not classes or classes == 0 or not classID then return true end
    return math.floor(classes / 2 ^ (classID - 1)) % 2 == 1
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

-- `stop`: a word more for the chat line, when it's one stop of several.
function Starts.Pin(s, stop)
    local set = ns.Waypoint and ns.Waypoint.Set or function(map, x, y) return Compat.SetWaypoint(map, x, y) end
    local zone = Starts.Area(s[4]) or "?"
    if set(s[5], s[6] / 100, s[7] / 100, s[2], "quest") then
        ns.Print(("Map pin set on %s, %s%s."):format(s[2], zone, stop or ""))
    else
        ns.Print(("%s is at %.0f, %.0f in %s."):format(s[2], s[6], s[7], zone))
    end
end

-- The stops a place's quests start at: givers standing within a few steps
-- of each other are one stop, the stop with most quests first. The game
-- holds one map pin, so a place's "show on map" goes round them a click at
-- a time (John, 13 Nov 2026, of a place with five givers: "this one goes
-- to betina bigglezink only").
function Starts.Stops(spots)
    local stops = {}
    for _, s in ipairs(spots) do
        local found
        for _, stop in ipairs(stops) do
            if stop.spot[5] == s[5] and math.abs(stop.spot[6] - s[6]) <= 3 and math.abs(stop.spot[7] - s[7]) <= 3 then found = stop end
        end
        if found then
            found.count = found.count + 1
        else
            stops[#stops + 1] = { spot = s, count = 1, order = #stops }
        end
    end
    table.sort(stops, function(a, b)
        if a.count ~= b.count then return a.count > b.count end
        return a.order < b.order
    end)
    return stops
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

    -- A boss's band, the list's width: a bar with its number in the order
    -- you meet it, its name (ticked once you've killed it) and its kills,
    -- and its loot under the bar, two across. (They were cards two to a row:
    -- a short card left a hole beside a tall one, and the order read across
    -- then down. John, 14 Nov 2026: "thoughts on the layout of the bosses
    -- itself?")
    local B = {}
    B.sum = Style.Text(bossList, 15, "text", nil, true)
    B.sum:SetPoint("TOPLEFT", 0, -2)
    B.order = Style.Text(bossList, 11, "muted")
    B.order:SetPoint("TOPRIGHT", bossList, "TOPLEFT", rightW, -6)
    B.order:SetJustifyH("RIGHT")
    B.order:SetText("on your gear plan first, then better for you, then by how often it drops")
    local function BossRow(i)
        if bossRows[i] then return bossRows[i] end
        local b = CreateFrame("Frame", nil, bossList)
        b:SetSize(rightW, BOSS_H)
        b.head = CreateFrame("Frame", nil, b)
        b.head:SetPoint("TOPLEFT")
        b.head:SetPoint("TOPRIGHT")
        b.head:SetHeight(BOSS_H)
        Style.Fill(b.head, "well")
        b.number = Style.Text(b.head, 13, "gold", nil, true)
        b.number:SetPoint("LEFT", 12, 0)
        b.box = CreateFrame("Frame", nil, b.head)
        b.box:SetSize(16, 16)
        b.box:SetPoint("LEFT", 34, 0)
        b.boxFill = Style.Fill(b.box, "wordGreen")
        b.boxEdges = Style.Border(b.box, "lineStrong")
        -- The game's own check mark, in white.
        b.tick = b.box:CreateTexture(nil, "OVERLAY")
        b.tick:SetSize(16, 16)
        b.tick:SetPoint("CENTER", 1, 0)
        b.tick:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        b.tick:SetDesaturated(true)
        b.tick:SetVertexColor(1, 1, 1)
        b.name = Style.Text(b.head, 14, "text", nil, true)
        b.name:SetPoint("LEFT", b.box, "RIGHT", 8, 0)
        b.name:SetWidth(rightW - 300)
        b.name:SetJustifyH("LEFT")
        b.name:SetWordWrap(false)
        b.kills = Style.Text(b.head, 12, "muted")
        b.kills:SetPoint("RIGHT", -10, 0)
        b.none = Style.Text(b, 12, "muted")
        b.none:SetPoint("TOPLEFT", 12, -(BOSS_H + 8))
        b.none:SetWidth(rightW - 24)
        b.none:SetJustifyH("LEFT")
        b.items = {}
        bossRows[i] = b
        return b
    end

    -- The quests tab, made to be read at a glance by anyone (John, 13 Nov
    -- 2026: "lets make this as intuitive and easy to read as possible for
    -- anyone using this, or whats the point as they'll just go on wowhead").
    -- A line of what there is, column headings, a bar for each place quests
    -- start in, a line for a quest that stands alone, and a card of numbered
    -- steps for a chain, with the step to start at marked.
    local Q = { lines = {}, heads = {}, priors = {}, cards = {}, steps = {} }
    -- Where the "who gives it" column starts, across the list.
    local WHO_X = math.floor(rightW * 0.42)

    -- The top of the list: what's here, a word when you're under level, and
    -- the column headings.
    function Q.Top()
        if Q.sum then return end
        Q.sum = Style.Text(bossList, 13, "text", nil, true)
        Q.more = Style.Text(bossList, 12, "muted")
        Q.more:SetPoint("LEFT", Q.sum, "RIGHT", 10, 0)
        Q.low = Style.Text(bossList, 12, "muted")
        Q.low:SetJustifyH("RIGHT")
        Q.cols = CreateFrame("Frame", nil, bossList)
        Q.cols:SetSize(rightW, 20)
        local quest = Style.Text(Q.cols, 10, "muted", nil, true)
        quest:SetPoint("LEFT", 10, 0)
        quest:SetText("QUEST")
        local who = Style.Text(Q.cols, 10, "muted", nil, true)
        who:SetPoint("LEFT", WHO_X, 0)
        who:SetText("WHO GIVES IT, AND WHERE")
        local level = Style.Text(Q.cols, 10, "muted", nil, true)
        level:SetPoint("RIGHT", -10, 0)
        level:SetText("LEVEL")
        Style.Rule(Q.cols, "BOTTOM", "lineStrong")
    end

    -- How wide a line of text is drawn, or a guess where that isn't known.
    function Q.Wide(text, guess)
        local w = text.GetStringWidth and text:GetStringWidth()
        return (type(w) == "number" and w > 0) and w or guess
    end

    local function QuestTip(frame)
        frame:EnableMouse(true)
        frame:SetScript("OnEnter", function(self)
            if not self.quest then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(("quest:%d"):format(self.quest))
            if self.spot then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(("Click to pin %s on your map"):format(self.spot[2]), 0.89, 0.69, 0.29)
            end
            GameTooltip:Show()
        end)
        frame:SetScript("OnMouseUp", function(self, button)
            if button == "LeftButton" and self.spot then Starts.Pin(self.spot) end
        end)
        frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
        Style.Hover(frame)
    end

    -- A small label after a name: gold for what to do, plain for what it is.
    local function Tag(parent, gold)
        local t = CreateFrame("Frame", nil, parent)
        t:SetHeight(15)
        t.fill = Style.Fill(t, gold and "gold" or "line")
        t.text = Style.Text(t, 10, gold and "onGold" or "text", nil, gold)
        t.text:SetPoint("CENTER")
        function t:Say(text)
            self.text:SetText(text)
            self.wide = Q.Wide(self.text, #text * 5.2) + 12
            self:SetWidth(self.wide)
        end
        return t
    end

    -- A quest that stands alone: its name, who gives it, the level.
    function Q.Line(i)
        if Q.lines[i] then return Q.lines[i] end
        local q = CreateFrame("Frame", nil, bossList)
        q:SetSize(rightW, 26)
        q.level = Style.Text(q, 12, "muted")
        q.level:SetPoint("RIGHT", -10, 0)
        q.level:SetJustifyH("RIGHT")
        q.name = Style.Text(q, 13, "text")
        q.name:SetPoint("LEFT", 10, 0)
        q.name:SetWordWrap(false)
        q.log = Tag(q)
        q.log:SetPoint("LEFT", q.name, "RIGHT", 8, 0)
        q.log:Say("in your quest log")
        q.who = Style.Text(q, 12, "muted")
        q.who:SetPoint("LEFT", WHO_X, 0)
        q.who:SetPoint("RIGHT", q.level, "LEFT", -12, 0)
        q.who:SetJustifyH("LEFT")
        q.who:SetWordWrap(false)
        Style.Rule(q, "BOTTOM", "line")
        QuestTip(q)
        Q.lines[i] = q
        return q
    end

    -- A place quests start in: its name, how many, and its stops on the map.
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
        -- Each click pins the next stop, round again after the last.
        h:SetScript("OnClick", function(self)
            local stops = self.stops
            if not (stops and stops[1]) then return end
            self.at = (self.at or 0) % #stops + 1
            Starts.Pin(stops[self.at].spot, #stops > 1 and (" (stop %d of %d: click again for the next)"):format(self.at, #stops) or nil)
        end)
        Q.heads[i] = h
        return h
    end

    -- A finished quest, at the foot of the list: ticked, greyed, "done".
    function Q.Prior(i)
        if Q.priors[i] then return Q.priors[i] end
        local l = CreateFrame("Frame", nil, bossList)
        l:SetSize(rightW, 21)
        l.box = CreateFrame("Frame", nil, l)
        l.box:SetSize(12, 12)
        l.box:SetPoint("LEFT", 10, 0)
        l.fill = Style.Fill(l.box, "wordGreen")
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
        l.done:SetText(GREEN .. "done|r")
        l:SetAlpha(0.75)
        Q.priors[i] = l
        return l
    end

    -- A chain: a card headed by the dungeon's quest, with how many steps.
    function Q.Card(i)
        if Q.cards[i] then return Q.cards[i] end
        local c = CreateFrame("Frame", nil, bossList)
        c:SetWidth(rightW - 8)
        Style.Fill(c, "well"):SetAlpha(0.5)
        c.edge = c:CreateTexture(nil, "ARTWORK")
        c.edge:SetColorTexture(Style.Color("gold"))
        c.edge:SetPoint("TOPLEFT")
        c.edge:SetPoint("BOTTOMLEFT")
        c.edge:SetWidth(3)
        c.title = Style.Text(c, 13, "text", nil, true)
        c.title:SetPoint("TOPLEFT", 14, -9)
        c.count = Tag(c)
        c.count:SetPoint("LEFT", c.title, "RIGHT", 8, 0)
        c.level = Style.Text(c, 12, "muted")
        c.level:SetPoint("TOPRIGHT", -6, -10)
        c.level:SetJustifyH("RIGHT")
        Q.cards[i] = c
        return c
    end

    -- A step of a chain: its number on the line that joins them, its name,
    -- what it is, and who gives it.
    function Q.Step(i)
        if Q.steps[i] then return Q.steps[i] end
        local st = CreateFrame("Frame", nil, bossList)
        st:SetSize(rightW - 8, 24)
        -- Above its card: both are the list's children, and at one level the
        -- game may draw the card's fill over the step.
        st:SetFrameLevel(bossList:GetFrameLevel() + 3)
        st.rail = st:CreateTexture(nil, "BACKGROUND")
        st.rail:SetColorTexture(Style.Color("lineStrong"))
        st.rail:SetPoint("TOPLEFT", 26, 0)
        st.rail:SetSize(1, 24)
        st.badge = CreateFrame("Frame", nil, st)
        st.badge:SetHeight(18)
        st.badge:SetPoint("CENTER", st, "LEFT", 26, 0)
        st.badgeFill = Style.Fill(st.badge, "line")
        st.number = Style.Text(st.badge, 10, "muted", nil, true)
        st.number:SetPoint("CENTER")
        st.tick = st.badge:CreateTexture(nil, "OVERLAY")
        st.tick:SetSize(16, 16)
        st.tick:SetPoint("CENTER", 1, 0)
        st.tick:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        st.tick:SetDesaturated(true)
        st.tick:SetVertexColor(1, 1, 1)
        st.name = Style.Text(st, 13, "muted")
        st.name:SetPoint("LEFT", 48, 0)
        st.name:SetWordWrap(false)
        st.start = Tag(st, true)
        st.start:SetPoint("LEFT", st.name, "RIGHT", 8, 0)
        st.start:Say("start here")
        st.own = Tag(st)
        st.own:Say("this dungeon's quest")
        st.who = Style.Text(st, 12, "muted")
        st.who:SetPoint("RIGHT", -8, 0)
        st.who:SetJustifyH("LEFT")
        st.who:SetWordWrap(false)
        QuestTip(st)
        Q.steps[i] = st
        return st
    end

    -- An item, half a band wide: its icon, its name with a tag after it,
    -- what it is under the name, and at the right how often it drops and
    -- how often it has.
    local itemW = math.floor((rightW - 24 - 20) / 2)
    local function Item(card, i)
        if card.items[i] then return card.items[i] end
        local it = CreateFrame("Frame", nil, card)
        it:SetSize(itemW, ITEM_H - 4)
        it.icon = it:CreateTexture(nil, "ARTWORK")
        it.icon:SetSize(30, 30)
        it.icon:SetPoint("LEFT")
        it.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        it.chance = Style.Text(it, 13, "text", nil, true)
        it.chance:SetPoint("TOPRIGHT", 0, -1)
        it.chance:SetJustifyH("RIGHT")
        it.seen = Style.Text(it, 11, "muted")
        it.seen:SetPoint("BOTTOMRIGHT", 0, 1)
        it.seen:SetJustifyH("RIGHT")
        it.name = Style.Text(it, 14, "text")
        it.name:SetPoint("TOPLEFT", it.icon, "TOPRIGHT", 8, 0)
        it.name:SetJustifyH("LEFT")
        it.name:SetWordWrap(false)
        -- Why it's first on the list: on your gear plan, better than what
        -- you wear, or a recipe for a profession of yours.
        it.tag = CreateFrame("Frame", nil, it)
        it.tag:SetPoint("LEFT", it.name, "RIGHT", 8, 0)
        it.tag.fill = Style.Fill(it.tag, "line")
        it.tag.text = Style.Text(it.tag, 10, "text")
        it.tag.text:SetPoint("CENTER")
        it.slot = Style.Text(it, 12, "muted")
        it.slot:SetPoint("BOTTOMLEFT", it.icon, "BOTTOMRIGHT", 8, 0)
        it.slot:SetWidth(itemW - 40 - 90)
        it.slot:SetJustifyH("LEFT")
        it.slot:SetWordWrap(false)
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

    -- Puts an item's tag on, or takes it off; returns the room it takes.
    local function SetTag(it, kind)
        it.tagged = kind
        it.tag:SetShown(kind ~= nil)
        if not kind then return 0 end
        local t = TAGS[kind]
        it.tag.fill:SetColorTexture(Style.Color(t[2]))
        it.tag.text:SetText(t[1])
        it.tag.text:SetTextColor(Style.Color(t[3]))
        local w = it.tag.text.GetStringWidth and it.tag.text:GetStringWidth()
        w = ((type(w) == "number" and w > 0) and w or #t[1] * 5.4) + 12
        it.tag:SetSize(w, 16)
        return w + 8
    end

    -- A boss's loot on its band: Wowhead's list with each item's drop
    -- chance, then anything you or the guild have seen it drop that the list
    -- doesn't have. Without Wowhead's chance, five or more guild kills give
    -- one. What's on your gear plan comes first, then what's better than
    -- what you wear, then the rest, likeliest first. What you can't equip,
    -- and recipes for professions you don't have, fold into one line at the
    -- foot. Returns the band's height, how many pieces are better for you,
    -- how many it could tell that of, and the guild's kills.
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
            return BOSS_H + 34, 0, 0, guildKills
        end
        card.none:Hide()
        local starredSet = ns.Gear and ns.Gear.Starred() or {}
        local trades = {}
        for _, p in ipairs(ns.Professions and ns.Professions.Mine and ns.Professions.Mine() or {}) do trades[p.name or ""] = true end
        local mine, others, recipes, better, sure = {}, {}, 0, 0, 0
        for k, entry in ipairs(list) do
            local _, _, _, _, _, _, subclass, _, equipLoc, _, classID, subclassID = ItemInfo(entry.id)
            entry.at = k
            entry.starred = starredSet[entry.id] == true
            -- A piece on your gear plan is never folded away.
            entry.cant = not entry.starred and CantEquip(classID, subclassID, equipLoc)
            entry.recipe = classID == RECIPE
            entry.prof = entry.recipe and trades[subclass or ""] == true
            if not entry.cant and not entry.recipe and ns.Gear and ns.Gear.Better then
                local is = ns.Gear.Better(entry.id, equipLoc, classID, subclassID)
                if is ~= nil then sure = sure + 1 end
                if is then
                    entry.better = true
                    better = better + 1
                end
            end
            entry.away = entry.cant or (entry.recipe and not entry.prof and not entry.starred)
            if entry.away and entry.recipe then recipes = recipes + 1 end
            local to = entry.away and others or mine
            to[#to + 1] = entry
        end
        local function Rank(e) return e.starred and 1 or (e.better and 2 or 3) end
        table.sort(mine, function(a, b)
            if Rank(a) ~= Rank(b) then return Rank(a) < Rank(b) end
            return a.at < b.at
        end)
        local open = unfolded[boss] == true
        -- Two across; what was folded away starts a row of its own.
        local place, shown = 0, 0
        local function Put(entry)
            place, shown = place + 1, shown + 1
            local it = Item(card, shown)
            it:ClearAllPoints()
            it:SetPoint("TOPLEFT", 12 + ((place - 1) % 2) * (itemW + 20), -(BOSS_H + 6 + math.floor((place - 1) / 2) * ITEM_H))
            it.item = entry.id
            local name, _, quality, _, req, _, subclass, _, equipLoc, texture = ItemInfo(entry.id)
            local q = quality or entry.item.q or 1
            local tagW = SetTag(it, entry.starred and "plan" or (entry.better and "better") or (entry.prof and "prof") or nil)
            it.name:SetWidth(0)
            it.name:SetText(("|cff%s%s|r"):format(Style.Quality(q), name or entry.item.n or "..."))
            local room = itemW - 38 - 56 - tagW
            local wide = it.name.GetStringWidth and it.name:GetStringWidth()
            if type(wide) ~= "number" or wide <= 0 or wide > room then it.name:SetWidth(room) end
            local slot = equipLoc and equipLoc ~= "" and _G[equipLoc] or nil
            local parts = {}
            -- Recipes and other things you don't wear have a blank slot name.
            if slot and slot ~= "" then parts[#parts + 1] = slot end
            if subclass and subclass ~= "" and subclass ~= slot and subclass ~= "Miscellaneous" then parts[#parts + 1] = subclass end
            -- Too high for you yet: its level, in red.
            if req and req > (UnitLevel("player") or 1) then parts[#parts + 1] = ("%slevel %d|r"):format(RED, req) end
            it.slot:SetText(table.concat(parts, " · "))
            it.chance:SetText((entry.chance or entry.guessed) and ("%d%%"):format(entry.chance or entry.guessed) or "")
            -- How often it's been seen: in the guild's kills (the band's bar
            -- says how many those are), or by you.
            if entry.guild then
                it.seen:SetText(("dropped %d×"):format(entry.guild))
            elseif (entry.item.seen or 0) > 0 then
                it.seen:SetText(entry.item.seen > 1 and ("you've seen it %d×"):format(entry.item.seen) or "you've seen it")
            else
                it.seen:SetText("")
            end
            it:SetAlpha(entry.away and 0.55 or 1)
            it.edge:SetShown(entry.starred)
            it.icon:SetTexture(texture or Compat.ItemIcon(entry.id) or "Interface\\Icons\\INV_Misc_QuestionMark")
            it:Show()
        end
        for _, entry in ipairs(mine) do Put(entry) end
        if open then
            place = math.ceil(place / 2) * 2
            for _, entry in ipairs(others) do Put(entry) end
        end
        local h = BOSS_H + 6 + math.ceil(place / 2) * ITEM_H + 4
        if #others > 0 then
            if not card.more then
                card.more = CreateFrame("Button", nil, card)
                card.more:SetSize(rightW - 24, 20)
                card.more.text = Style.Text(card.more, 11, "muted")
                card.more.text:SetPoint("LEFT", 38, 0)
                Style.Hover(card.more, 4)
            end
            local words = {}
            if recipes == 1 then words[#words + 1] = "1 recipe for another profession"
            elseif recipes > 1 then words[#words + 1] = recipes .. " recipes for other professions" end
            if #others > recipes then words[#words + 1] = ("%d more you can't equip"):format(#others - recipes) end
            card.more.text:SetText(open and "Show fewer" or (table.concat(words, " and ") .. " · Show"))
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
        return h, better, sure, guildKills
    end

    -- Who gives a quest: on a quest's own line the place is its heading, so
    -- it's the giver and the spot; on a step, the place is said too.
    function Q.Giver(s, place)
        if not (s and s[2]) then return "" end
        if s[3] == 3 then return Starts.Where(s) or "" end
        local zone, kind = Starts.Place(s)
        local spot = (s[5] ~= 0 and s[6] and s[6] > 0) and ("%.0f, %.0f"):format(s[6], s[7] or 0) or nil
        if not place then return spot and (s[2] .. "  ·  " .. spot) or s[2] end
        if kind == 2 then return s[2] .. "  ·  " .. (zone:gsub("^Inside ", "inside ")) end
        if kind ~= 1 then return s[2] end
        return s[2] .. "  ·  " .. zone .. (spot and (" " .. spot) or "")
    end

    -- The level column: what the quest is, or in red what it needs when
    -- you're under it.
    function Q.Level(q, mine)
        local needs = q[4] or q[3]
        if needs > mine then return ("%sneeds level %d|r"):format(RED, needs) end
        return ("level %d"):format(q[3])
    end

    local WORDS = { "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten" }

    -- Paints the quests tab from `by` down the list, and returns where it
    -- ended.
    function Q.Paint(quests, by)
        Q.Top()
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
        -- goes with that one; the rest are what a place has for you now.
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
                    place = { name = e.place, kind = e.kind, list = {} }
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
        for _, place in ipairs(order) do table.sort(place.list, ByLevel) end
        -- Places, the ones with most to pick up first; inside the dungeon
        -- and the unknown last.
        table.sort(order, function(x, y)
            if x.kind ~= y.kind then return x.kind < y.kind end
            if #x.list ~= #y.list then return #x.list > #y.list end
            return x.name < y.name
        end)

        -- The line at the top: what's here in plain words, and one word
        -- about your level in place of "needs level N" down every row.
        local now = #todo - later
        local tooLow, least = 0, nil
        for _, q in ipairs(todo) do
            local needs = q[4] or q[3]
            if needs > mine then
                tooLow = tooLow + 1
                least = least and math.min(least, needs) or needs
            end
        end
        -- "you can pick up" only when you can: under level for some, it's
        -- "to pick up", and the line at the right says how many are above you.
        Q.sum:SetText(#quests == 0 and "" or ("%d quest%s %s"):format(now, now == 1 and "" or "s", tooLow > 0 and "to pick up" or "you can pick up"))
        Q.sum:ClearAllPoints()
        Q.sum:SetPoint("TOPLEFT", 0, -(by + 4))
        local more = {}
        if later > 0 then more[#more + 1] = ("%d more follow%s those"):format(later, later == 1 and "s" or "") end
        if #finished > 0 then more[#more + 1] = ("%d done"):format(#finished) end
        Q.more:SetText(#more > 0 and ("· " .. table.concat(more, " · ")) or "")
        local many = tooLow == #todo and tooLow > 1 and "all of these need" or ("%d of these need%s"):format(tooLow, tooLow == 1 and "s" or "")
        Q.low:SetText(tooLow > 0 and ("%sYou're level %d: %s level %d or more|r"):format(RED, mine, many, least) or "")
        Q.low:ClearAllPoints()
        Q.low:SetPoint("TOPRIGHT", bossList, "TOPLEFT", rightW, -(by + 5))
        for _, region in ipairs({ Q.sum, Q.more, Q.low, Q.cols }) do region:SetShown(#quests > 0) end
        hint:SetText((#quests > 0 and ns.DungeonQuestStarts) and "click a quest, a step or a place for a map pin" or "")
        if #quests > 0 then
            by = by + 28
            Q.cols:ClearAllPoints()
            Q.cols:SetPoint("TOPLEFT", 0, -by)
            by = by + 28
        end

        local lines, heads, priors, cards, steps = 0, 0, 0, 0, 0
        local function Named(quest)
            local s = Starts.Get(quest)
            return (byId[quest] and byId[quest][2]) or (s and s[1] ~= "" and s[1]) or nil
        end
        -- What follows a quest and isn't one of this dungeon's, if anything.
        local function After(e)
            local after = Starts.Next(e.q[1])
            if after and not byId[after] and not under[e.q[1]] and not QuestDone(after) and Named(after) then return after end
        end
        -- A chain, in order: what leads up to the quest (back to the last
        -- one finished), the quest, what's under it, and what follows. Each
        -- is { id, name, s, own (one of this dungeon's), done }.
        local function Chain(e)
            local chain, lead, id = {}, {}, e.before
            while id and #lead < 12 and not entries[id] do
                lead[#lead + 1] = id
                if QuestDone(id) then break end
                local s = Starts.Get(id)
                id = s and s[8] or nil
            end
            for i = #lead, 1, -1 do
                if Named(lead[i]) then
                    chain[#chain + 1] = { id = lead[i], name = Named(lead[i]), s = Starts.Get(lead[i]), done = QuestDone(lead[i]) }
                end
            end
            local seen = {}
            local function Own(entry)
                if seen[entry] then return end
                seen[entry] = true
                chain[#chain + 1] = { id = entry.q[1], name = entry.q[2], s = entry.s, own = true, q = entry.q }
                for _, child in ipairs(under[entry.q[1]] or {}) do Own(child) end
                local after = After(entry)
                if after then chain[#chain + 1] = { id = after, name = Named(after), s = Starts.Get(after) } end
            end
            Own(e)
            -- A step in your quest log: what's before it is behind you,
            -- finished or never needed, so it's where the chain stands.
            local held
            for i, step in ipairs(chain) do
                if not step.done and QuestHeld(step.id) then held = i end
            end
            for i = 1, (held or 1) - 1 do chain[i].done = true end
            return chain
        end
        -- A run of three or more steps of one name, none of them the
        -- dungeon's own, is one line: "2-7  The True Masters, six parts",
        -- with the places it takes you through.
        local function Folded(chain)
            local shown, i = {}, 1
            while i <= #chain do
                local j = i
                while not chain[i].own and chain[j + 1] and not chain[j + 1].own and chain[j + 1].name == chain[i].name do j = j + 1 end
                if j - i >= 2 then
                    local route, done = {}, 0
                    for k = i, j do
                        local zone, kind = Starts.Place(chain[k].s)
                        if kind == 1 and route[#route] ~= zone then route[#route + 1] = zone end
                        if chain[k].done then done = done + 1 end
                    end
                    if #route > 4 then route = { route[1], route[2], route[3], "…", route[#route] } end
                    local count = j - i + 1
                    shown[#shown + 1] = { number = ("%d–%d"):format(i, j), name = ("%s, %s parts"):format(chain[i].name, WORDS[count] or count),
                        who = table.concat(route, " → ") .. (done > 0 and done < count and ("  ·  %d done"):format(done) or ""),
                        done = done == count, first = chain[i + done] or chain[i] }
                else
                    j = i
                    shown[#shown + 1] = { number = tostring(i), name = chain[i].name, who = Q.Giver(chain[i].s, true), done = chain[i].done,
                        own = chain[i].own, first = chain[i] }
                end
                i = j + 1
            end
            return shown
        end
        local function PaintCard(e, chain)
            cards = cards + 1
            local c = Q.Card(cards)
            local shown = Folded(chain)
            c.title:SetText(e.q[2])
            c.count:Say(("%d step%s"):format(#chain, #chain == 1 and "" or "s"))
            c.level:SetText(Q.Level(e.q, mine))
            local tall = 34 + #shown * 24 + 8
            c:SetHeight(tall)
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", 4, -by)
            c:Show()
            local y, begun = by + 34, false
            for _, step in ipairs(shown) do
                steps = steps + 1
                local st = Q.Step(steps)
                local start = not step.done and not begun
                begun = begun or start
                st.quest = step.first.id
                st.spot = Starts.Spot(step.first.id, QuestDone)
                st.number:SetText(step.done and "" or step.number)
                st.tick:SetShown(step.done == true)
                st.badge:SetWidth(math.max(18, Q.Wide(st.number, #step.number * 5) + 10))
                st.badgeFill:SetColorTexture(Style.Color(step.done and "wordGreen" or (start and "gold" or "line")))
                st.number:SetTextColor(Style.Color(start and "onGold" or "muted"))
                st.name:SetText(step.name)
                st.name:SetTextColor(Style.Color(start and "text" or "muted"))
                -- The step to do now: "start here", or that you have it.
                st.start:SetShown(start)
                if start then st.start:Say(QuestHeld(step.first.id) and "in your quest log" or "start here") end
                st.own:SetShown(step.own == true)
                st.own:ClearAllPoints()
                st.own:SetPoint("LEFT", start and st.start or st.name, "RIGHT", start and 6 or 8, 0)
                -- The giver starts at its column, or past a long name's tags.
                local ends = 48 + Q.Wide(st.name, 0) + (start and st.start.wide + 8 or 0) + (step.own and st.own.wide + 8 or 0)
                st.who:SetPoint("LEFT", math.max(WHO_X - 4, ends + 14), 0)
                st.who:SetText(step.who)
                st:SetAlpha(step.done and 0.6 or 1)
                st:ClearAllPoints()
                st:SetPoint("TOPLEFT", 4, -y)
                st:Show()
                y = y + 24
            end
            by = by + tall + 8
        end
        local function PaintLine(e)
            lines = lines + 1
            local row = Q.Line(lines)
            row.quest = e.q[1]
            row.spot = Starts.Spot(e.q[1], QuestDone)
            row.name:SetText(e.q[2])
            row.log:SetShown(QuestHeld(e.q[1]))
            row.who:SetText(Q.Giver(e.s, false))
            row.level:SetText(Q.Level(e.q, mine))
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -by)
            row:Show()
            by = by + 26
        end
        for _, place in ipairs(order) do
            heads = heads + 1
            local h = Q.Head(heads)
            h.name:SetText(place.name)
            -- What's here: a quest alone is a line, a chain a card.
            local blocks, chains = {}, 0
            for _, e in ipairs(place.list) do
                local chain = Chain(e)
                blocks[#blocks + 1] = { e = e, chain = #chain > 1 and chain or nil }
                if #chain > 1 then chains = chains + 1 end
            end
            local count = ("%d quest%s"):format(#place.list, #place.list == 1 and "" or "s")
            if chains > 0 then count = count .. ("  ·  %d chain%s"):format(chains, chains == 1 and "" or "s") end
            h.count:SetText(count)
            local spots = {}
            for _, e in ipairs(place.list) do
                local spot = Starts.Spot(e.q[1], QuestDone)
                if spot then spots[#spots + 1] = spot end
            end
            h.stops = Starts.Stops(spots)
            -- A different place under this bar starts again at its first stop.
            if h.place ~= place.name then h.place, h.at = place.name, nil end
            h.link:SetShown(#h.stops > 0)
            h.link:SetText(#h.stops > 1 and ("show on map · %d stops"):format(#h.stops) or "show on map")
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", 0, -by)
            h:Show()
            by = by + 36
            for _, block in ipairs(blocks) do
                if block.chain then PaintCard(block.e, block.chain) else PaintLine(block.e) end
            end
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
            h.stops, h.place, h.at = nil, nil, nil
            h.link:Hide()
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", 0, -by)
            h:Show()
            by = by + 36
            for _, q in ipairs(closed) do
                priors = priors + 1
                local l = Q.Prior(priors)
                l.name:SetText(q[2])
                l:ClearAllPoints()
                l:SetPoint("TOPLEFT", 0, -by)
                l:Show()
                by = by + 21
            end
            by = by + 8
        end
        for k = lines + 1, #Q.lines do Q.lines[k]:Hide() end
        for k = heads + 1, #Q.heads do Q.heads[k]:Hide() end
        for k = priors + 1, #Q.priors do Q.priors[k]:Hide() end
        for k = cards + 1, #Q.cards do Q.cards[k]:Hide() end
        for k = steps + 1, #Q.steps do Q.steps[k]:Hide() end
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

        for _, pool in ipairs({ Q.lines, Q.heads, Q.priors, Q.cards, Q.steps }) do
            for _, region in ipairs(pool) do region:Hide() end
        end
        for _, region in ipairs({ Q.sum, Q.more, Q.low, Q.cols }) do region:Hide() end
        for _, row in ipairs(bossRows) do row:Hide() end
        B.sum:Hide()
        B.order:Hide()
        none:Hide()
        local quests = {}
        local classID
        if UnitClass then classID = select(3, UnitClass("player")) end
        local mySide = (faction == "Alliance" and 1) or (faction == "Horde" and 2) or nil
        for _, q in ipairs(ns.DungeonQuests and ns.DungeonQuests[d.id] or {}) do
            local side = QUEST_SIDE[q[5]]
            if (not side or side == faction) and Starts.ForClass(q, classID) and not Starts.Theirs(q[1], mySide) then
                quests[#quests + 1] = q
            end
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
        -- The bosses as bands down the list, in the game's order, under a
        -- line of how much here is better than what you wear.
        hint:SetText("hover an item for its details")
        local heights, better, sure = {}, 0, 0
        for k, b in ipairs(d.bosses) do
            local card = BossRow(k)
            card.boss = b[2]
            local n = D.KillCount(b[2], game, b[3])
            card.number:SetText(k)
            card.name:SetText(b[3] or b[2])
            card.box:SetShown(n > 0)
            -- Without a tick the name comes right after the number.
            card.name:ClearAllPoints()
            if n > 0 then
                card.name:SetPoint("LEFT", card.box, "RIGHT", 8, 0)
            else
                card.name:SetPoint("LEFT", card.head, "LEFT", 34, 0)
            end
            Style.SetBorder(card.boxEdges, "wordGreen")
            local h, more, known, guildKills = PaintLoot(card, b[2], b[1])
            better, sure = better + more, sure + known
            -- Your kills, and the guild's: said here once, where it was on
            -- every item ("dropped 1× in 1 guild kill").
            local words = {}
            if n > 0 then words[#words + 1] = ("killed %d×"):format(n) end
            if guildKills > 0 then words[#words + 1] = ("%d guild kill%s"):format(guildKills, guildKills == 1 and "" or "s") end
            card.kills:SetText(table.concat(words, "  ·  "))
            heights[k] = h
        end
        -- Said only when the gear plan could tell: it needs your spec's
        -- weights, and the game to have loaded the items.
        B.sum:SetShown(sure > 0)
        B.order:SetShown(sure > 0)
        if sure > 0 then
            B.sum:SetText(better == 0 and "Nothing here is better than what you wear"
                or (better == 1 and "1 piece here is better than what you wear"
                    or ("%d pieces here are better than what you wear"):format(better)))
            by = 32
        end
        for k in ipairs(d.bosses) do
            local card = bossRows[k]
            card:SetHeight(heights[k])
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", 0, -by)
            card:Show()
            by = by + heights[k] + CARD_GAP
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
