-- The dungeon guide, in a window of its own: every dungeon and raid down its
-- left in level groups, the ones right for your level in green; the chosen
-- one fills the rest of the window in three tabs. Bosses and loot: a card
-- a boss, two across, numbered in the game's order and ticked once you've
-- killed it. A card has four lines at most for what you can equip (Wowhead's
-- list with drop chances, and what you and the guild have seen it drop):
-- what you starred in your Gear plan, past four if need be, then what's
-- better than what you wear, the most first, then the likeliest drops;
-- along its foot, small and grey, everything else it drops. A card
-- with something for you has a gold edge. After the last boss, a Trash card
-- for what the dungeon's ordinary creatures drop, where anything is known.
-- Quests: the dungeon's quests for your faction, ticked once done, each with
-- where it starts and the quest to do first; a click pins the start on the map.
-- Map: the dungeon's own map where there is one. The list marks each
-- dungeon's starred loot and the quests in your log for it. The window is as
-- tall as the dungeon needs, and never shorter than the list.
local _, ns = ...
local Style, Compat, Window = ns.Style, ns.Compat, ns.Window

-- The line over the content: the dungeon's name and the tabs.
local PICKER_H = 34
-- A boss's card: its heading, a line a piece, and the strip along its foot
-- for what isn't for you, with its small pictures. Cards are two across,
-- GRID_GAP apart, a row of them ROW_GAP under the last.
local BOSS_H, ITEM_H, STRIP_H, SMALL, GRID_GAP, ROW_GAP = 36, 46, 40, 24, 24, 16
-- The Trash card's heading: its name with a quiet line under it.
local TRASH_H = 52
local METER_W = 52                 -- the bar under a piece's drop chance
-- A card's lines for what you can equip, at most: a piece you starred has its
-- line past them.
local LINES = 4
-- Under the name: a line of words, then the list; and under the list the
-- link to where the numbers come from. The list is never shorter than LIST_MIN.
local TOP_H, FOOT_H, LIST_MIN = 34, 26, 140
-- Under the line that says why no boss was brought to the top, before the first cards.
local WHY_GAP = 12
-- The window: its size when a dungeon needs all of it.
-- The list of dungeons down the left, as the dashboard's menu is: from the
-- window's edge to the line at its right, the rows' width inside it, a
-- heading's height and a row's. The page sits PANEL_PAD in from the window's
-- edge, SIDE_UP under the title bar and SIDE_DOWN over the window's foot.
local SIDE_W, SIDE_ROW_W, SIDE_HEAD, SIDE_ROW = 240, 216, 28, 26
-- Beside the list, the guide as wide as it was on its own, GUIDE_W: its boss
-- cards and its map keep their sizes. The window is the two together.
local GUIDE_W = 1000
local OWN_W, OWN_H = SIDE_W + GUIDE_W, 860
local PANEL_PAD, SIDE_UP, SIDE_DOWN = 22, 15, 17
-- The level the raids are for: below it the list starts with them folded.
local TOP_LEVEL = 60
-- The game's item class for recipes (patterns, plans, schematics).
local RECIPE = 9
-- The tag after an item's name: its words and its tone. A better piece's
-- words are how much better it is; a worse one's (a piece you starred that
-- what you wear has passed), how much worse.
local TAGS = {
    better = { nil, "green" },
    worse = { nil, "red" },
    prof = { "your profession" },
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

-- The game's own quest marks, as over a quest giver's head: a gold ! for a
-- quest you can pick up, grey while you're under the level it's taken at;
-- a ? once it's in your log, grey while it's being done and gold when it's
-- ready to hand in. They stand in place of an "in your quest log" tag.
-- The two pictures are the ones Forever's own QuestUtils uses; grey is the
-- same picture without its colour.
local OFFER_MARK = "Interface\\GossipFrame\\AvailableQuestIcon"
local ACTIVE_MARK = "Interface\\GossipFrame\\ActiveQuestIcon"
local QUEST_SIGN = "|T" .. ACTIVE_MARK .. ":0|t"
local function QuestMark(texture, id, take, mine)
    local held = QuestHeld(id)
    local lit
    if held then
        lit = C_QuestLog and C_QuestLog.IsComplete and C_QuestLog.IsComplete(id) and true or false
    else
        lit = not (take and mine and take > mine)
    end
    texture:SetTexture(held and ACTIVE_MARK or OFFER_MARK)
    texture:SetDesaturated(not lit)
    texture:SetAlpha(lit and 1 or 0.7)
    texture:Show()
    return held
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
-- Power to everyone.
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
-- a time.
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

-- The guide's dungeons for your side, in its order: of one level, your side's first
-- (Dungeons.InOrder). The data's own order where the guide's records aren't loaded.
local function InOrder(faction)
    local D = ns.Dungeons
    if D and D.InOrder then return D.InOrder(faction) end
    local list = {}
    for _, d in ipairs(ns.DungeonData or {}) do
        if not d.faction or d.faction == faction then list[#list + 1] = d end
    end
    return list
end
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

-- What a dungeon is: its level, where its entrance is, and the side it's on.
local function Facts(d)
    local bits = { (d.raid and "Raid \194\183 level %d+" or "Level %d+"):format(d.level), d.zone }
    if SideText(d) then bits[#bits + 1] = SideText(d) end
    return bits
end

-- Why a gear plan was made in a paint, as /jsal perf says it (see Gear.SlotPlan).
local MADE = { first = "made for the first time since loading", changed = "made again after a change",
    waiting = "made again for items still to come" }

-- An item's details, asking the game to load them when it hasn't yet. `missed` counts the
-- ones it hadn't, so a paint knows whether anything it drew is still to come.
local missed = 0
local function ItemInfo(id)
    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local name, link, quality, ilvl, req, class, subclass, stack, equipLoc, texture, _, classID, subclassID = get(id)
    if not name then
        missed = missed + 1
        if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
    end
    return name, link, quality, ilvl, req, class, subclass, stack, equipLoc, texture, classID, subclassID
end

-- How many of a dungeon's listed drops the game hasn't loaded, asking for each when `ask`.
-- Nothing where the game can't be asked: there's then nothing to wait for. Only the items'
-- numbers are looked at, no tooltip.
local function Unloaded(d, ask)
    local request = C_Item and C_Item.RequestLoadItemDataByID
    if not request then return 0 end
    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local n = 0
    for _, b in ipairs(d.bosses) do
        for _, drop in ipairs(ns.DungeonLoot and ns.DungeonLoot[b[1]] or {}) do
            if not get(drop[1]) then
                n = n + 1
                if ask then request(drop[1]) end
            end
        end
    end
    return n
end

-- Whether an item is for you: the gear plan's rules of what each class
-- wears and wields. Nil when the game hasn't loaded the item yet.
local function ForYou(classID, subclassID, equipLoc)
    if not classID then return nil end
    local _, classFile = UnitClass("player")
    return ns.Gear.ForClass(classFile, UnitLevel("player") or 1, classID, subclassID, equipLoc)
end

-- Whether you can't equip a thing at all: a weapon your class never wields,
-- a shield without the use of one, armor heavier than you can wear. Armor
-- lighter than yours is not that: you can wear it, and it may be the better
-- piece. Nor is a weapon your class can learn and you haven't yet.
local function CantEquip(classID, subclassID, equipLoc)
    if ForYou(classID, subclassID, equipLoc) ~= false then return false end
    local _, classFile = UnitClass("player")
    if ns.Gear.CanWear and ns.Gear.CanWear(classFile, UnitLevel("player") or 1, classID, subclassID) then return false end
    return true
end

-- Whether a thing is for other classes only: its own tooltip has a
-- "Classes:" line, and yours isn't on it (Zul'Gurub's Primal Hakkari pieces,
-- which a boss drops nine of; a class set's parts). False when it names no
-- class or names yours; nil while the game hasn't loaded the item. The
-- classes an item names are kept once read (false for none): they don't
-- change, and its tooltip is read once however often the page is drawn.
local classNames, classLine = {}, nil
local function ForOthers(id)
    local names = classNames[id]
    if names == nil then
        local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
        local tip = C_TooltipInfo and C_TooltipInfo.GetItemByID
        if not (tip and get and get(id)) then return nil end
        local data = tip(id)
        if not (data and data.lines) then return nil end
        if not classLine then
            local text = type(ITEM_CLASSES_ALLOWED) == "string" and ITEM_CLASSES_ALLOWED or "Classes: %s"
            text = text:gsub("([%(%)%.%[%]%+%-%*%?%^%$])", "%%%1")
            classLine = "^" .. text:gsub("%%s", "(.+)") .. "$"
        end
        names = false
        for _, line in ipairs(data.lines) do
            local text = line.leftText
            local found = type(text) == "string" and text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):match(classLine)
            if found then
                names = found
                break
            end
        end
        classNames[id] = names
    end
    if not names then return false end
    -- Your class as the game names it, and its two forms where a language has them (Kriegerin, Krieger): a
    -- tooltip's "Classes:" line names a class in one of them, which needn't be the one your character's is.
    local mine, file = UnitClass("player")
    local male = type(LOCALIZED_CLASS_NAMES_MALE) == "table" and LOCALIZED_CLASS_NAMES_MALE[file]
    local female = type(LOCALIZED_CLASS_NAMES_FEMALE) == "table" and LOCALIZED_CLASS_NAMES_FEMALE[file]
    for name in names:gmatch("[^,]+") do
        name = name:match("^%s*(.-)%s*$")
        if name == mine or name == male or name == female then return false end
    end
    return true
end
local RED = Style.Tint("red")

-- What a boss has for you, for its mark on the dungeon's map: whether it drops a piece starred
-- in your Gear plan, and the most any of its drops betters what you wear (nil for none, or
-- while the game hasn't loaded them). By the rules its card sorts its loot by. Given `pieces`,
-- each piece for you is put in it as well: { id, star, gain (nil for a starred piece that's no
-- better) }.
local function BossGear(boss, pieces)
    local G, D = ns.Gear, ns.Dungeons
    if not (G and G.Better) then return false, nil end
    local starred = G.Starred and G.Starred() or {}
    local star, best = false, nil
    local seen = {}
    local function Look(id)
        if seen[id] then return end
        seen[id] = true
        local _, _, _, _, _, _, _, _, equipLoc, _, classID, subclassID = ItemInfo(id)
        local mine = starred[id] == true
        if mine then star = true end
        if classID == RECIPE or (not mine and (CantEquip(classID, subclassID, equipLoc) or ForOthers(id) == true)) then return end
        local is, gain = G.Better(id, equipLoc, classID, subclassID)
        if is and (gain or 0) > (best or -1) then best = gain or 0 end
        if pieces and (mine or is) then pieces[#pieces + 1] = { id = id, star = mine, gain = is and (gain or 0) or nil } end
    end
    for _, drop in ipairs(ns.DungeonLoot and ns.DungeonLoot[boss[1]] or {}) do Look(drop[1]) end
    for id in pairs(D.Loot()[boss[1]] or {}) do Look(id) end
    return star, best
end

-- The bosses your quests need, for their marks on the dungeon's map: { [the boss's place in the
-- dungeon's order] = the quest's name }, with "+1" after it for each further quest that needs
-- the same boss. Nothing says which boss a quest needs, so it's read off the quests in your log:
-- of the dungeon's quests you hold, each objective still to do that names a boss, or an item a
-- boss is known to drop. A quest not picked up yet, or one that wants neither, has no boss.
-- Returned with them: each boss's objectives, { [k] = { { the quest's name, the objective as the
-- game words it } } }, for its tooltip.
local function BossQuests(d)
    local out, lines
    local read = C_QuestLog and C_QuestLog.GetQuestObjectives
    if not read then return nil end
    local byName, byItem
    for _, q in ipairs(ns.DungeonQuests and ns.DungeonQuests[d.id] or {}) do
        local objectives = QuestHeld(q[1]) and read(q[1])
        for _, o in ipairs(type(objectives) == "table" and objectives or {}) do
            if not o.finished and (o.type == "monster" or o.type == "item") then
                -- "Revelosh slain: 0/1", "Tablet of Will: 0/1", or the count first.
                local text = o.text or ""
                local name = (text:match("^(.-):%s*%d+%s*/%s*%d+%s*$") or text:match("^%d+%s*/%s*%d+%s+(.+)$") or text)
                name = name:gsub("%s+slain$", ""):match("^%s*(.-)%s*$"):lower()
                local k
                if name ~= "" and o.type == "monster" then
                    if not byName then
                        byName = {}
                        for i, b in ipairs(d.bosses) do
                            byName[b[2]:lower()] = i
                            if b[3] then byName[b[3]:lower()] = i end
                        end
                    end
                    k = byName[name]
                elseif name ~= "" then
                    if not byItem then
                        byItem = {}
                        for i, b in ipairs(d.bosses) do
                            for _, drop in ipairs(ns.DungeonLoot and ns.DungeonLoot[b[1]] or {}) do
                                local item = ItemInfo(drop[1])
                                if item then byItem[item:lower()] = byItem[item:lower()] or i end
                            end
                        end
                    end
                    k = byItem[name]
                end
                if k then
                    out, lines = out or {}, lines or {}
                    lines[k] = lines[k] or {}
                    lines[k][#lines[k] + 1] = { q[2], text }
                    local has = out[k]
                    if not has then
                        out[k] = { q[2], 0, [q[1]] = true }
                    elseif not has[q[1]] then
                        has[q[1]], has[2] = true, has[2] + 1
                    end
                end
            end
        end
    end
    if not out then return nil end
    for k, has in pairs(out) do out[k] = has[2] > 0 and (has[1] .. " +" .. has[2]) or has[1] end
    return out, lines
end

-- What a boss's tooltip on the map says of you, added to `tip`: each piece on
-- your Gear plan or better than what you wear, with its picture, its name and by how much, the
-- starred ones first; then each quest in your log that needs the boss, with what's left of it as
-- the game words it. Worked out when the boss is pointed at, not before.
local function BossTip(tip, d, k)
    local boss = d.bosses[k]
    if not boss then return end
    local pieces = {}
    BossGear(boss, pieces)
    table.sort(pieces, function(a, b)
        if a.star ~= b.star then return a.star end
        if (a.gain or -1) ~= (b.gain or -1) then return (a.gain or -1) > (b.gain or -1) end
        return a.id < b.id
    end)
    if #pieces > 0 then
        -- No heading over them: their green gains say whose they are.
        tip:AddLine(" ")
        for _, piece in ipairs(pieces) do
            local name, _, quality, _, _, _, _, _, _, texture = ItemInfo(piece.id)
            -- By how much, as its card's tag says it.
            local by = ""
            if piece.gain then
                local pct = math.floor(piece.gain * 100 + 0.5)
                by = pct < 1 and "under 1%" or ("+" .. pct .. "%")
            end
            local star = piece.star and ns.Gear and ns.Gear.STAR or nil
            tip:AddDoubleLine((texture and ("|T" .. texture .. ":16:16:0:0|t ") or "") .. ("|cff%s%s|r"):format(Style.Quality(quality), name or "..."),
                (star and (star .. (by ~= "" and " " or "")) or "") .. by, 1, 1, 1, 0.38, 0.70, 0.35)
        end
    end
    local _, lines = BossQuests(d)
    local last
    for _, line in ipairs(lines and lines[k] or {}) do
        if line[1] ~= last then
            tip:AddLine(" ")
            tip:AddLine("|T" .. ACTIVE_MARK .. ":14:14:0:0|t " .. line[1], 0.89, 0.69, 0.29)
            last = line[1]
        end
        tip:AddLine(line[2], 1, 1, 1)
    end
end
-- On the module too, so they can be asked by themselves.
if ns.Dungeons then ns.Dungeons.BossQuests, ns.Dungeons.BossTip = BossQuests, BossTip end

Window.Page("dungeons", function(page)
    local D = ns.Dungeons
    local width, height = page.contentWidth or Window.contentWidth, page.contentHeight or Window.contentHeight
    local rightW = width - SIDE_W
    local chosen
    local Paint
    -- A dungeon's items come from the game a moment after they're first asked for. Drawn
    -- before that, every drop was "..." and all of them listed, and the page drew itself
    -- again a moment later, shorter and with other words. So a dungeon just picked keeps the
    -- last drawing until its items are in, or HOLD seconds at most; and the dungeons on show
    -- in the list are asked for when pointed at, so the wait is mostly none.
    -- `drawn` is the dungeon whose bosses are on the page, `holding` the one waited for,
    -- `late` those whose wait ran out (not waited for again), `lacking` how many items the
    -- last drawing missed. In one table: the paint has little room left for names of its own.
    local HOLD = 0.5
    local wait = { late = {}, lacking = 0, asked = {} }
    function wait.Count(d)
        local first = not wait.asked[d]
        wait.asked[d] = true
        return Unloaded(d, first)
    end
    -- Each part of a paint, timed, so /jsal perf can say which is slow ("Page: Dungeons,
    -- redraw" was 32 ms, with no word of why). A part is noted only when the paint was slow.
    local spent = {}
    local function Spent(part, since)
        local now = debugprofilestop()
        spent[part] = (spent[part] or 0) + now - since
        return now
    end
    local function NoteParts(started)
        if debugprofilestop() - started < 10 then return end
        for part, ms in pairs(spent) do ns.NoteTime("Dungeons, " .. part, ms) end
    end

    -----------------------------------------------------------------
    -- Down the left: every dungeon in its level group, in the look of the
    -- dashboard's menu. A click on a group's heading folds or opens it; a
    -- click on a dungeon shows it at the right. Rows are made only for the
    -- groups that are open, and kept for the next paint. Pointing at a row
    -- says what it leaves out, and asks the game for that dungeon's items,
    -- so a click on it is mostly drawn at once: no other dungeon's are asked
    -- for. `held` is how many quests in your log are for each dungeon, read
    -- from the log once and kept until the game says the log changed.
    -----------------------------------------------------------------
    local List = { heads = {}, rows = {}, reveal = true }
    local side = CreateFrame("Frame", nil, page)
    side:SetPoint("TOPLEFT", -(PANEL_PAD - 1), SIDE_UP)
    side:SetPoint("BOTTOMLEFT", -(PANEL_PAD - 1), -SIDE_DOWN)
    side:SetWidth(SIDE_W)
    Style.Cap(side, 6, "titleBar", "BOTTOMLEFT")
    Style.Rule(side, "RIGHT", "line")
    -- The list runs from the page's top to its foot, as the page is tall.
    List.scroll, List.child = Style.Scroller(side, SIDE_ROW_W, 100, SIDE_ROW_W, 6, 52)
    List.scroll:ClearAllPoints()
    List.scroll:SetPoint("TOPLEFT", 12, -SIDE_UP)
    List.scroll:SetPoint("BOTTOMRIGHT", -12, SIDE_DOWN)

    -- A group's heading: + or a dash, its name in gold, and at its right how
    -- many it holds, after "your level" where one is right for you.
    function List.Head(g)
        if List.heads[g] then return List.heads[g] end
        local h = CreateFrame("Button", nil, List.child)
        h:SetSize(SIDE_ROW_W, SIDE_HEAD)
        h.sign = Style.Text(h, 14, "gold", nil, true)
        h.sign:SetPoint("LEFT", 4, 0)
        h.label = Style.Text(h, 11, "gold", nil, true)
        h.label:SetPoint("LEFT", 18, 0)
        h.note = Style.Text(h, 11, "muted")
        h.note:SetPoint("RIGHT", -4, 0)
        h.note:SetJustifyH("RIGHT")
        h:SetScript("OnClick", function()
            List.open[g] = not List.open[g] or nil
            List.Paint()
            List.Fit(List.content or 0)
        end)
        Style.Hover(h, 0, 5)
        List.heads[g] = h
        return h
    end

    -- A dungeon's row: its name, and at its right the starred pieces that drop
    -- there, a ? when a quest in your log is for it, and its level. The chosen
    -- one is filled, with a gold mark down its left, as the menu's open page.
    function List.Row(i)
        if List.rows[i] then return List.rows[i] end
        local r = CreateFrame("Button", nil, List.child)
        r:SetSize(SIDE_ROW_W, SIDE_ROW)
        r.lit = Style.Round(r, 5, "well")
        r.mark = r:CreateTexture(nil, "ARTWORK")
        r.mark:SetColorTexture(Style.Color("gold"))
        r.mark:SetSize(3, 18)
        r.mark:SetPoint("LEFT", 0, 0)
        r.level = Style.Text(r, 12, "muted")
        r.level:SetPoint("RIGHT", -8, 0)
        r.level:SetJustifyH("RIGHT")
        r.marks = Style.Text(r, 12, "gold", nil, true)
        r.marks:SetPoint("RIGHT", -32, 0)
        r.marks:SetJustifyH("RIGHT")
        r.name = Style.Text(r, 13, "secondary")
        r.name:SetPoint("LEFT", 12, 0)
        r.name:SetJustifyH("LEFT")
        r.name:SetWordWrap(false)
        r.size = select(2, r.name:GetFont())
        r:SetScript("OnClick", List.Click)
        r:SetScript("OnEnter", List.Enter)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        Style.Hover(r, 0, 5)
        List.rows[i] = r
        return r
    end

    function List.Click(self)
        if not self.dungeon then return end
        chosen = self.dungeon
        Paint()
    end

    -- Pointed at: the dungeon's name, level and place, its bosses you've
    -- killed, and what its marks stand for. Beside the list, at the row.
    function List.Enter(self)
        local d = self.dungeon
        if not d then return end
        if not wait.asked[d] then wait.Count(d) end
        GameTooltip:SetOwner(self, "ANCHOR_NONE")
        GameTooltip:ClearAllPoints()
        GameTooltip:SetPoint("TOPLEFT", self, "TOPRIGHT", 6, 2)
        GameTooltip:SetText(d.name, 1, 1, 1)
        GameTooltip:AddLine(table.concat(Facts(d), " \194\183 "), 0.6, 0.59, 0.53)
        local game, killed = D.GameKills(), 0
        for _, b in ipairs(d.bosses) do
            if D.KillCount(b[2], game, b[3]) > 0 then killed = killed + 1 end
        end
        GameTooltip:AddLine(("%d of %d bosses killed"):format(killed, #d.bosses), 0.6, 0.59, 0.53)
        local stars, quests = self.stars or 0, self.quests or 0
        if stars > 0 then
            GameTooltip:AddLine(stars == 1 and "1 piece you starred drops here" or ("%d pieces you starred drop here"):format(stars), 0.89, 0.69, 0.29)
        end
        if quests > 0 then
            GameTooltip:AddLine(QUEST_SIGN .. " " .. (quests == 1 and "A quest in your log is for here"
                or ("%d quests in your log are for here"):format(quests)), 0.89, 0.69, 0.29)
        end
        GameTooltip:Show()
    end

    -- How many quests in your log are for each dungeon: { [dungeon id] = n }.
    function List.Quests()
        if List.held then return List.held end
        local held, log = {}, C_QuestLog
        if log and log.GetNumQuestLogEntries and log.GetInfo then
            if not List.questFor then
                List.questFor = {}
                for id, quests in pairs(ns.DungeonQuests or {}) do
                    for _, q in ipairs(quests) do
                        local list = List.questFor[q[1]] or {}
                        list[#list + 1] = id
                        List.questFor[q[1]] = list
                    end
                end
            end
            local count = log.GetNumQuestLogEntries()
            for i = 1, count or 0 do
                local info = log.GetInfo(i)
                local ids = info and not info.isHeader and info.questID and List.questFor[info.questID]
                for _, id in ipairs(ids or {}) do held[id] = (held[id] or 0) + 1 end
            end
        end
        List.held = held
        return held
    end

    -- The groups that start open: each with a dungeon right for your level
    -- (or, with none, the one your level is in) and the one after the last of
    -- them, the raids only at the top level. Folded, a group is its count.
    function List.Opening(members, level)
        local open, last = {}, nil
        for g in ipairs(GROUPS) do
            for _, d in ipairs(members[g] or {}) do
                if Fits(d, level) then
                    open[g], last = true, g
                    break
                end
            end
        end
        if not last then
            last = GroupOf({ level = level })
            open[last] = true
        end
        local after = GROUPS[last + 1]
        if after and members[last + 1] and not (after.raid and level < TOP_LEVEL) then open[last + 1] = true end
        return open
    end

    function List.Paint()
        local level = UnitLevel("player") or 1
        local faction = Compat.Faction()
        List.dirty, List.shown = nil, chosen
        local members = {}
        for _, d in ipairs(InOrder(faction)) do
            local g = GroupOf(d)
            members[g] = members[g] or {}
            table.insert(members[g], d)
        end
        List.open = List.open or List.Opening(members, level)
        -- A dungeon shown from elsewhere opens its group, and is brought into view.
        local reveal = List.reveal and chosen
        if reveal then List.open[GroupOf(chosen)] = true end
        List.reveal = nil
        local held = List.Quests()
        local y, i, chosenY = 0, 0, nil
        for g, group in ipairs(GROUPS) do
            local inGroup = members[g]
            if inGroup then
                local h = List.Head(g)
                local fits = 0
                for _, d in ipairs(inGroup) do if Fits(d, level) then fits = fits + 1 end end
                h.label:SetText(group.label)
                h.note:SetText(fits > 0 and (GREEN .. "your level|r \194\183 " .. #inGroup) or tostring(#inGroup))
                h.sign:SetText(List.open[g] and "\226\128\147" or "+")
                h:ClearAllPoints()
                h:SetPoint("TOPLEFT", 0, -y)
                h:Show()
                y = y + SIDE_HEAD
                for _, d in ipairs(List.open[g] and inGroup or {}) do
                    i = i + 1
                    local r = List.Row(i)
                    r.dungeon = d
                    r:ClearAllPoints()
                    r:SetPoint("TOPLEFT", 0, -y)
                    local on = d == chosen
                    if on then chosenY = y end
                    r.lit:SetShown(on)
                    r.mark:SetShown(on)
                    r.name:SetText(d.name)
                    r.name:SetTextColor(Style.Color(on and "text" or "secondary"))
                    if r.size then r.name:SetFont(on and Style.boldFont or Style.font, r.size, "") end
                    r.level:SetText((Fits(d, level) and GREEN or "") .. d.level .. (Fits(d, level) and "|r" or ""))
                    r.stars = ns.Gear and ns.Gear.StarsIn and #ns.Gear.StarsIn(d) or 0
                    r.quests = held[d.id] or 0
                    local said = (r.stars > 0 and (ns.Gear.STAR .. " " .. r.stars) or "")
                        .. (r.stars > 0 and r.quests > 0 and "  " or "") .. (r.quests > 0 and QUEST_SIGN or "")
                    r.marks:SetText(said)
                    -- The name gives way to the marks; its tooltip has it whole.
                    local marks = said ~= "" and r.marks:GetStringWidth()
                    marks = type(marks) == "number" and marks + 6 or 0
                    r.name:SetWidth(SIDE_ROW_W - 12 - 32 - marks)
                    -- Well above your level, dimmed, as in the guide's other lists.
                    r:SetAlpha(TooHigh(d, level) and not on and 0.5 or 1)
                    r:Show()
                    y = y + SIDE_ROW
                end
                if List.open[g] then y = y + 6 end
            elseif List.heads[g] then
                List.heads[g]:Hide()
            end
        end
        for k = i + 1, #List.rows do List.rows[k]:Hide() end
        List.need = y
        List.child:SetHeight(math.max(1, y))
        if reveal and chosenY then
            local room = List.scroll:GetHeight()
            local range = math.max(0, y - ((type(room) == "number" and room > 0) and room or y))
            List.scroll:SetVerticalScroll(math.max(0, math.min(range, chosenY - 2 * SIDE_ROW)))
        end
    end

    -- Over the content, at the list's right: the chosen dungeon's name, how it
    -- sits with your level beside it, and the tabs at the far right.
    local top = CreateFrame("Frame", nil, page)
    top:SetSize(width - SIDE_W, PICKER_H)
    top:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", SIDE_W, -8)
    local title = Style.Text(top, 20, "text", nil, true)
    title:SetPoint("LEFT", 0, 0)
    title:SetWordWrap(false)
    local key = Style.Text(top, 12, "muted")
    key:SetPoint("LEFT", title, "RIGHT", 16, -2)
    function List.Title(d, level)
        title:SetText(d.name)
        if Fits(d, level) then
            key:SetText(GREEN .. "right for level " .. level .. "|r")
        else
            key:SetText(level < d.level and ("from level " .. d.level) or "below your level")
        end
    end
    page:HookScript("OnShow", function() page:RegisterEvent("QUEST_LOG_UPDATE") end)
    page:HookScript("OnHide", function()
        page:UnregisterEvent("QUEST_LOG_UPDATE")
        List.held = nil
    end)

    -----------------------------------------------------------------
    -- Below: the chosen dungeon, the rest of the page's width.
    -----------------------------------------------------------------
    local right = CreateFrame("Frame", nil, page)
    right:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, -16)
    right:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)
    -- The line above is the dungeon's name; under it, its level, where it
    -- is, and how many of its bosses you've killed. On the bosses' tab that
    -- follows the line of how much here is for you.
    local meta = Style.Text(right, 13, "muted")
    meta:SetJustifyH("LEFT")
    meta:SetWordWrap(false)
    -- The tabs, at the right of the name's line: the bosses with their
    -- loot, the dungeon's quests, and its map where there is one.
    -- `tab` is the one shown, and `List.pick` the one you chose: a dungeon with
    -- no map shows its bosses, and the next with one shows its map again.
    local tab = "bosses"
    local tabs = Style.Tabs(right, { { "bosses", "Bosses and loot" }, { "quests", "Quests" }, { "map", "Map" } }, function(name)
        tab, List.pick = name, name
        Paint()
    end)
    tabs:SetPoint("RIGHT", top, "RIGHT", 0, 0)
    local hint = Style.Text(right, 12, "muted")
    hint:SetPoint("TOPRIGHT", 0, -4)
    hint:SetJustifyH("RIGHT")
    local bossScroll, bossList = Style.Scroller(right, rightW + 8, height - PICKER_H - 16 - TOP_H - FOOT_H, rightW)
    bossScroll:SetPoint("TOPLEFT", 0, -TOP_H)
    local bossRows = {}
    local none = Style.Text(bossList, 13, "muted")
    none:SetWidth(rightW - 36)
    none:SetJustifyH("LEFT")
    -- Where each tab's lists come from, and that they're incomplete: said
    -- when the link at the foot is pointed at, not printed on the page.
    local NOTE = {
        bosses = "Loot and drop chances come from Wowhead Forever and what you and your guild have seen drop. They're incomplete, especially past level 30, and will change as more people play.\n"
            .. "\"For you\" is by your Gear plan's stat weights, which are estimates: roll by what you know of your spec.",
        quests = "Quests and where they start come from Wowhead Forever. Some may be missing, and they'll change as more people play.",
    }
    -- The Map tab's words are the shown dungeon's map's own (DungeonMap.About), set as it's drawn.
    local about
    about = Style.About(right, function() return tab == "map" and about.mapNote or NOTE[tab] end)
    about:SetPoint("BOTTOMRIGHT", 0, 0)

    -- The window is as tall as what's in the list, between a least and the
    -- size it was made at; a longer list scrolls. Nor is it shorter than the
    -- dungeons down its left, up to that size. It keeps its top where it is
    -- and grows or shrinks downward.
    local function Fit(need)
        local room = height - PICKER_H - 16 - TOP_H - FOOT_H
        List.content = need
        local listH = math.max(LIST_MIN, math.min(room, need), math.min(room, (List.need or 0) - (height - room)))
        bossScroll:SetHeight(listH)
        local window = page.contentHeight and page:GetParent()
        if type(window) ~= "table" or not window.SetHeight then return listH end
        local left, top = window:GetLeft(), window:GetTop()
        window:SetHeight(OWN_H - (room - listH))
        if left and top then
            window:ClearAllPoints()
            window:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        end
        return listH
    end
    List.Fit = Fit

    -- A boss's card, half the list wide: its number in the order you meet
    -- it, its name (ticked once you've killed it) and its kills over a rule;
    -- under that a line for each piece starred or better than what you wear;
    -- and along its foot a strip of small pictures for the rest it drops.
    local cardW = math.floor((rightW - GRID_GAP) / 2)
    local B = {}
    B.about = about
    B.sum = Style.Text(right, 15, "text", nil, true)
    B.sum:SetPoint("TOPLEFT", 0, -2)
    -- The map, in the list's place. A boss clicked there opens the bosses' tab at its card.
    local mapPane = ns.DungeonMap and ns.DungeonMap.Build(right, rightW, function(k)
        tab, List.pick, B.jump, B.jumpItem = "bosses", "bosses", k, nil
        Paint()
    end)
    if mapPane then
        mapPane:SetPoint("TOPLEFT", 0, -TOP_H)
        mapPane:Hide()
    end
    -- Another dungeon, or its other tab, starts from the top; the same one keeps its place,
    -- held in range. (Only held in range, a dungeon picked while scrolled down another's
    -- bosses opened partway down its own.)
    function B.Scroll(d, tab)
        local top = B.shown ~= d or B.tab ~= tab
        B.shown, B.tab = d, tab
        if top then B.Let() end
        bossScroll:SetVerticalScroll(top and 0 or math.min(bossScroll:GetVerticalScroll(), bossScroll:GetVerticalScrollRange()))
    end
    -- A boss asked for (a sign on the map, a piece on Endgame's goal card) is `B.aim`: its card is brought to
    -- the top of the view, as near as the list's end allows, and held there until you scroll or pick another
    -- dungeon or tab. Held, because the page settles after it is drawn: its items arrive and the cards grow,
    -- and the game works out how far the list can scroll only once it has laid the list out, after the window
    -- is shown, so a scroll set while painting is cut to the range the list had before. Each paint aims again,
    -- in the range the page has just set; when the game's own range comes, the aim is set once more in it.
    -- `B.mark` is a piece of that boss's lit as under the pointer, until the pointer leaves it (`B.lit`, its line).
    function B.Aim(range)
        local m = B.aim and B.models and B.models[B.aim]
        if not m then return end
        bossScroll:SetVerticalScroll(math.max(0, math.min(m.at, range or 0)))
    end
    function B.Light()
        if B.lit then B.lit.lit = nil end
        B.lit = nil
        local m = B.mark and B.aim and B.models and B.models[B.aim]
        for _, card in ipairs(m and bossRows or {}) do
            if card.drawn == m then
                for _, it in ipairs(card.items) do
                    if it.item == B.mark and it:IsShown() then B.lit, it.lit = it, true end
                end
            end
        end
        B.Glow()
    end
    function B.Let()
        if B.lit then B.lit.lit = nil end
        B.aim, B.mark, B.lit, B.why = nil, nil, nil, nil
        if B.glow then B.Glow() end
    end
    -- One light for the whole list, as faint as Style.Hover's, on the line under the pointer (`B.hover`); with
    -- the pointer on none, on the piece asked for while it's lit. Moved to the line's card, under its picture and words.
    function B.Glow()
        local glow = B.glow
        if not glow then
            glow = bossList:CreateTexture(nil, "BACKGROUND", nil, 7)
            local r, g, b = Style.Color("text")
            glow:SetColorTexture(r, g, b, 0.06)
            B.glow = glow
        end
        local it = B.hover or B.lit
        glow.on = it
        if not it then return glow:Hide() end
        glow:SetParent(it:GetParent())
        glow:SetDrawLayer("BACKGROUND", 7)
        glow:ClearAllPoints()
        glow:SetAllPoints(it)
        glow:Show()
    end
    -- Only the cards in view are made, and the cards made are kept and given other bosses as the list scrolls:
    -- `B.models` is every card of the dungeon worked out (B.Model) and placed, and a card frame shows one of them
    -- (`drawn`). A card that stays in view keeps its frame and isn't drawn again. Where the list's height isn't known,
    -- every card is drawn.
    function B.Bind()
        local models = B.models
        if not (models and tab == "bosses") then return end
        local v, room = bossScroll:GetVerticalScroll() or 0, bossScroll:GetHeight()
        local every = not (type(room) == "number" and room > 0)
        local want, free, moved = {}, {}, false
        for k, m in ipairs(models) do want[k] = every or (m.at < v + room and m.at + m.h > v) end
        for _, card in ipairs(bossRows) do
            local k = card.drawn and card.drawn.k
            if k and models[k] == card.drawn and want[k] then
                want[k] = false
            else
                if card.drawn then moved = true end
                card.drawn = nil
                card:Hide()
                free[#free + 1] = card
            end
        end
        for k, m in ipairs(models) do
            if want[k] then
                local card = table.remove(free) or B.Row(#bossRows + 1)
                B.Draw(card, m)
                moved = true
            end
        end
        if not moved then return end
        -- A line under the pointer, or the piece asked for, may have gone with its card.
        if B.hover and not (B.hover:IsShown() and B.hover:GetParent().drawn) then B.hover = nil end
        if B.mark then B.Light() else B.Glow() end
    end
    bossScroll:HookScript("OnVerticalScroll", function() B.Bind() end)
    bossScroll:HookScript("OnScrollRangeChanged", function(self)
        if not (B.aim and tab == "bosses") then return end
        B.Aim(self:GetVerticalScrollRange() or 0)
        self:Place()
    end)
    -- Why no boss was brought to the top: a piece asked for that drops from a creature of the dungeon that
    -- isn't one of its bosses (`B.whyNext` until the bosses' tab is drawn with it, then `B.why`). One line in
    -- the secondary colour, the item's name in its quality's, above the cards; the cards move down by its
    -- height. It goes as the aim does (B.Let), and when the guide closes. Returns the room it takes.
    function B.Say(why)
        B.whyShown = nil
        if not why then
            if B.whyText then B.whyText:Hide() end
            return 0
        end
        local text = B.whyText or Style.Text(bossList, 13, "secondary")
        B.whyText = text
        text:SetWidth(rightW)
        text:SetWordWrap(true)
        text:ClearAllPoints()
        text:SetPoint("TOPLEFT", 0, 0)
        local name = ("|cff%s%s|r"):format(Style.Quality(why.quality or 1),
            (Compat.ItemName and Compat.ItemName(why.item)) or "This piece")
        if why.creature then
            text:SetText(("%s drops from %s, one of the creatures here, not a boss."):format(name, why.creature))
        else
            text:SetText(("%s can drop from any creature here, not from a boss."):format(name))
        end
        text:Show()
        local h = text:GetStringHeight()
        if not (type(h) == "number" and h > 0) then h = 16 end
        B.whyShown = math.ceil(h) + WHY_GAP
        return B.whyShown
    end
    -- A turn of the wheel lets the boss go, and the line: the list is drawn again without it, the view
    -- moved up by the line's room so the cards stay where they were on screen.
    bossScroll:HookScript("OnMouseWheel", function()
        B.Let()
        local shown = B.whyShown
        if not shown then return end
        local v = bossScroll:GetVerticalScroll() - shown
        Paint()
        bossScroll:SetVerticalScroll(math.max(0, v))
    end)
    page:HookScript("OnHide", function() B.why, B.whyNext, B.keep, B.hover = nil, nil, nil, nil end)
    local function BossRow(i)
        if bossRows[i] then return bossRows[i] end
        local b = CreateFrame("Frame", nil, bossList)
        b:SetSize(cardW, BOSS_H)
        Style.Box(b, 6, "well", "cardLine")
        -- Gold down its left, round with the card, when something here is
        -- for you.
        b.edge = Style.Edge(b, 6)
        b.head = CreateFrame("Frame", nil, b)
        b.head:SetPoint("TOPLEFT")
        b.head:SetPoint("TOPRIGHT")
        b.head:SetHeight(BOSS_H)
        Style.Rule(b.head, "BOTTOM", "line")
        b.number = Style.Text(b.head, 13, "gold", nil, true)
        b.number:SetPoint("LEFT", 14, 0)
        b.box = CreateFrame("Frame", nil, b.head)
        b.box:SetSize(16, 16)
        b.box:SetPoint("LEFT", 36, 0)
        -- A green square: its line would be the fill's own colour, inside the fill, so it's the fill alone.
        b.boxFill = Style.Fill(b.box, "wordGreen")
        -- The game's own check mark, in white.
        b.tick = b.box:CreateTexture(nil, "OVERLAY")
        b.tick:SetSize(16, 16)
        b.tick:SetPoint("CENTER", 1, 0)
        b.tick:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        b.tick:SetDesaturated(true)
        b.tick:SetVertexColor(1, 1, 1)
        b.name = Style.Text(b.head, 14, "text", nil, true)
        b.name:SetPoint("LEFT", b.box, "RIGHT", 8, 0)
        b.name:SetWidth(cardW - 190)
        b.name:SetJustifyH("LEFT")
        b.name:SetWordWrap(false)
        b.kills = Style.Text(b.head, 12, "muted")
        b.kills:SetPoint("RIGHT", -14, 0)
        b.none = Style.Text(b, 13, "muted")
        b.none:SetPoint("TOPLEFT", 14, -(BOSS_H + 14))
        b.none:SetWidth(cardW - 28)
        b.none:SetJustifyH("LEFT")
        -- Along the foot, round with the card: the rest it drops.
        b.strip = CreateFrame("Frame", nil, b)
        b.strip:SetPoint("BOTTOMLEFT", 1, 1)
        b.strip:SetPoint("BOTTOMRIGHT", -1, 1)
        Style.Cap(b.strip, 5, "titleBar", "BOTTOM")
        Style.Rule(b.strip, "TOP", "line")
        b.strip.label = Style.Text(b.strip, 10, "muted", nil, true)
        b.strip.label:SetPoint("TOPLEFT", 13, -13)
        b.items, b.smalls = {}, {}
        bossRows[i] = b
        return b
    end
    B.Row = BossRow

    -- The Trash card's heading: no number and no tick, its name and a quiet line under it.
    function B.TrashHead(card)
        card.boss = nil
        card.number:SetText("")
        card.box:Hide()
        card.kills:SetText("")
        card.head:SetHeight(TRASH_H)
        card.name:ClearAllPoints()
        card.name:SetPoint("TOPLEFT", card.head, "TOPLEFT", 14, -11)
        card.name:SetText("Trash")
        if not card.note then
            card.note = Style.Text(card.head, 12, "muted")
            card.note:SetPoint("TOPLEFT", 14, -31)
            card.note:SetText("From the dungeon's ordinary creatures")
        end
        card.note:Show()
    end

    -- The quests tab, made to be read at a glance by anyone. A line of what
    -- there is, column headings, a bar for each place quests start in, a
    -- line for a quest that stands alone, and a card of numbered steps for a
    -- chain, with the step to start at marked.
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
            if self.ownQuest then GameTooltip:AddLine("This dungeon's quest.", 0.77, 0.75, 0.69) end
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

    -- The mark of a quest that's this dungeon's own: jsal.ui's Dungeons
    -- picture, small, where the words "this dungeon's quest" stood on
    -- every such step.
    local function OwnMark(parent)
        local m = CreateFrame("Frame", nil, parent)
        m:SetSize(18, 18)
        m.wide = 18
        m.icon = m:CreateTexture(nil, "ARTWORK")
        m.icon:SetAllPoints()
        m.icon:SetTexture("Interface\\AddOns\\jsalUI\\Media\\Icons\\dungeons")
        return m
    end

    -- A quest that stands alone: its name, who gives it, the level.
    function Q.Line(i)
        if Q.lines[i] then return Q.lines[i] end
        local q = CreateFrame("Frame", nil, bossList)
        q:SetSize(rightW, 26)
        q.level = Style.Text(q, 12, "muted")
        q.level:SetPoint("RIGHT", -10, 0)
        q.level:SetJustifyH("RIGHT")
        q.mark = q:CreateTexture(nil, "ARTWORK")
        q.mark:SetSize(16, 16)
        q.mark:SetPoint("LEFT", 8, 0)
        q.name = Style.Text(q, 13, "text")
        q.name:SetPoint("LEFT", 30, 0)
        q.name:SetWordWrap(false)
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
        -- thing in it.
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
        l.fill = Style.Circle(l.box, "wordGreen", "wordGreen").fill
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
        c.count = Style.Tag(c, "", nil, true)
        c.count:SetPoint("LEFT", c.title, "RIGHT", 8, 0)
        -- Where every step is this dungeon's own, the mark is here once,
        -- and not on each step. Pointing at it says what it means.
        c.own = OwnMark(c)
        c.own:SetPoint("LEFT", c.count, "RIGHT", 10, 0)
        c.own:EnableMouse(true)
        c.own:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Every step is this dungeon's quest")
            GameTooltip:Show()
        end)
        c.own:SetScript("OnLeave", function() GameTooltip:Hide() end)
        c.every = Style.Text(c, 11, "muted")
        c.every:SetPoint("LEFT", c.own, "RIGHT", 6, 0)
        c.every:SetText("every step")
        -- A card that ends in more than one of the dungeon's quests says so.
        c.opens = Style.Tag(c, "", nil, true)
        c.opens:SetPoint("LEFT", c.count, "RIGHT", 6, 0)
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
        -- The line that joins a chain's steps, plain enough to read as one.
        st.rail = st:CreateTexture(nil, "BACKGROUND")
        do
            local r, g, b = Style.Color("muted")
            st.rail:SetColorTexture(r, g, b, 0.6)
        end
        st.rail:SetPoint("TOPLEFT", 25, 0)
        st.rail:SetSize(2, 24)
        st.badge = CreateFrame("Frame", nil, st)
        st.badge:SetHeight(18)
        st.badge:SetPoint("CENTER", st, "LEFT", 26, 0)
        -- A circle, the picture a stop's sign on a road is drawn with. A
        -- run of numbers ("2-8") is wider than it's tall, and a circle
        -- pulled wide is an egg: that one is a box with round corners.
        st.disc = Style.Circle(st.badge, "line", "lineStrong")
        st.pill = Style.PillBox(st.badge, "line", "lineStrong")
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
        -- The step to do now has the quest's mark after its name.
        st.mark = st:CreateTexture(nil, "ARTWORK")
        st.mark:SetSize(16, 16)
        st.mark:SetPoint("LEFT", st.name, "RIGHT", 6, 0)
        st.start = Style.Tag(st, "start here", true, true)
        st.start:SetPoint("LEFT", st.mark, "RIGHT", 4, 0)
        st.own = OwnMark(st)
        st.who = Style.Text(st, 12, "muted")
        st.who:SetPoint("RIGHT", -8, 0)
        st.who:SetJustifyH("LEFT")
        st.who:SetWordWrap(false)
        -- Its own level, where a card ends in quests of different levels.
        st.level = Style.Text(st, 12, "muted")
        st.level:SetPoint("RIGHT", -6, 0)
        st.level:SetJustifyH("RIGHT")
        QuestTip(st)
        Q.steps[i] = st
        return st
    end

    -- The game's own tooltip for a piece, with what the card knows of it
    -- under: how often it's been seen to drop, and why it isn't for you.
    local function DropTip(self)
        if not self.item then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(self.item)
        for _, line in ipairs(self.more or {}) do GameTooltip:AddLine(line, 0.6, 0.59, 0.53, true) end
        GameTooltip:Show()
    end

    -- A colour's three numbers from its six letters.
    local function Hex3(hex)
        return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
    end

    -- A piece for you, a line across its boss's card: its picture in
    -- a line of its quality's colour, its name with a tag after it, what it
    -- is under the name, and at the right how often it drops over a bar
    -- that long.
    local function Item(card, i)
        if card.items[i] then return card.items[i] end
        local it = CreateFrame("Frame", nil, card)
        it:SetSize(cardW, ITEM_H)
        it.rule = Style.Rule(it, "TOP", "line")
        it.line = it:CreateTexture(nil, "BORDER")
        it.line:SetSize(32, 32)
        it.line:SetPoint("LEFT", 14, 0)
        it.icon = it:CreateTexture(nil, "ARTWORK")
        it.icon:SetPoint("TOPLEFT", it.line, "TOPLEFT", 1, -1)
        it.icon:SetPoint("BOTTOMRIGHT", it.line, "BOTTOMRIGHT", -1, 1)
        it.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        it.chance = Style.Text(it, 13, "text", nil, true)
        it.chance:SetPoint("TOPRIGHT", -14, -9)
        it.chance:SetJustifyH("RIGHT")
        it.track = it:CreateTexture(nil, "BORDER")
        it.track:SetColorTexture(Style.Color("window"))
        it.track:SetSize(METER_W, 4)
        it.track:SetPoint("BOTTOMRIGHT", -14, 11)
        it.fill = it:CreateTexture(nil, "ARTWORK")
        it.fill:SetColorTexture(Style.Color("gold"))
        it.fill:SetHeight(4)
        it.fill:SetPoint("LEFT", it.track, "LEFT", 0, 0)
        it.name = Style.Text(it, 14, "text")
        it.name:SetPoint("TOPLEFT", it.line, "TOPRIGHT", 12, 0)
        it.name:SetJustifyH("LEFT")
        it.name:SetWordWrap(false)
        -- How much better it is than what you wear, or worse.
        it.tag = Style.Tag(it, "", nil, true)
        it.tag:SetPoint("LEFT", it.name, "RIGHT", 8, 0)
        -- A piece you starred in your Gear plan has the plan's own star
        -- after its name (the game's yellow one), and its tag after that.
        it.star = it:CreateTexture(nil, "ARTWORK")
        it.star:SetSize(14, 14)
        it.star:SetPoint("LEFT", it.name, "RIGHT", 6, 0)
        it.star:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")
        it.slot = Style.Text(it, 12, "muted")
        it.slot:SetPoint("BOTTOMLEFT", it.line, "BOTTOMRIGHT", 12, 0)
        it.slot:SetWidth(cardW - 58 - 14 - METER_W - 12)
        it.slot:SetJustifyH("LEFT")
        it.slot:SetWordWrap(false)
        it:EnableMouse(true)
        it:SetScript("OnEnter", function(self)
            DropTip(self)
            B.hover = self
            B.Glow()
        end)
        it:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
            -- The piece asked for stays lit until the pointer has been on it and left.
            if B.lit == self then B.mark, B.lit, self.lit = nil, nil, nil end
            if B.hover == self then B.hover = nil end
            B.Glow()
        end)
        card.items[i] = it
        return it
    end

    -- A piece on the strip along its boss's card's foot: its picture, small
    -- and grey. Pointing at it says what it is, how often it drops, and why
    -- it isn't for you where that's so.
    local function Small(card, i)
        if card.smalls[i] then return card.smalls[i] end
        local s = CreateFrame("Frame", nil, card.strip)
        s:SetSize(SMALL, SMALL)
        s.line = Style.Fill(s, "lineStrong")
        s.icon = s:CreateTexture(nil, "ARTWORK")
        s.icon:SetPoint("TOPLEFT", 1, -1)
        s.icon:SetPoint("BOTTOMRIGHT", -1, 1)
        s.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        s.icon:SetDesaturated(true)
        s:SetAlpha(0.55)
        s.away = true
        s:EnableMouse(true)
        s:SetScript("OnEnter", DropTip)
        s:SetScript("OnLeave", function() GameTooltip:Hide() end)
        card.smalls[i] = s
        return s
    end

    -- Puts an item's tag on, or takes it off; returns the room it takes.
    -- `words` are for a tag whose kind has none of its own.
    local function SetTag(it, kind, words)
        it.tagged = kind
        it.tag:SetShown(kind ~= nil)
        if not kind then return 0 end
        local t = TAGS[kind]
        it.tag:Tone(t[2])
        it.tag:Say(t[1] or words)
        return it.tag.wide + 8
    end

    -- How often a piece has been seen to drop, in words: in the guild's
    -- kills (the card's heading says how many those are), or by you.
    local function Seen(entry)
        if entry.guild then return ("dropped %d×"):format(entry.guild) end
        local seen = entry.item.seen or 0
        if seen > 0 then return seen > 1 and ("you've seen it %d×"):format(seen) or "you've seen it" end
        return nil
    end

    -- A boss's loot on its card: Wowhead's list with each item's drop
    -- chance, then anything you or the guild have seen it drop that the list
    -- doesn't have. Without Wowhead's chance, five or more guild kills give
    -- one. A line each for what's on your gear plan, then, LINES in all at
    -- most, for what's better than what you wear, the most first, then for
    -- what else you can equip, likeliest first: a starred piece always has
    -- its line. Everything else is a small picture on the strip along the
    -- card's foot: what you could use first, then what you can't equip,
    -- what's for other classes only and recipes for professions you don't
    -- have, each likeliest first. A piece the game hasn't sent yet waits on
    -- the strip: whether you can equip it isn't known.
    -- `keep` is a piece asked for from elsewhere: it has a line while it's
    -- asked for, and is put on the card if the list doesn't have it. Returns
    -- the card's height, how many pieces are for you (on your gear plan, or
    -- better than what you wear), how many it could tell that of, and the
    -- guild's kills.
    -- The Trash card's loot is `trash` (D.Trash's list): no boss, no drop chance, the creature named where it is.
    -- Worked out without a card, so a card's height is known before one is made: { lines, strip (each piece with
    -- its place on the strip, `x` and `y`), h (the card's height), forYou, sure, guildKills, none (no loot known) }.
    function B.Model(boss, encounter, keep, trash)
        local m = { lines = {}, strip = {}, forYou = 0, sure = 0, guildKills = 0, top = trash and TRASH_H or BOSS_H }
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
        for _, e in ipairs(trash or {}) do
            local entry = Add(e[1])
            entry.creature, entry.item.q = e[2], e[3]
        end
        for id, item in pairs(boss and D.Loot()[encounter or D.Key(boss)] or {}) do Add(id).item = item end
        local guild = encounter and ns.GuildLoot and ns.GuildLoot.On() and ns.GuildLoot.For(encounter)
        local guildKills = 0
        if guild then
            for id, n in pairs(guild.i or {}) do
                -- Until 0.3.52 guild loot couldn't read an item's quality from the game's newer
                -- links, and shared grey and white items with the rest. One only the guild has
                -- seen, that the game says is below uncommon, isn't shown; its count stays in the
                -- guild's list, which every copy still agrees on.
                local quality = not byId[id] and C_Item and C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(id)
                if type(quality) ~= "number" or quality >= 2 then
                    Add(id).guild = n
                    guildKills = math.max(guildKills, n)
                end
            end
            guildKills = math.max(guildKills, guild.k or 0)
            for _, entry in ipairs(list) do
                if entry.guild and not entry.chance and guildKills >= 5 then
                    entry.guessed = math.floor(entry.guild / guildKills * 100 + 0.5)
                end
            end
        end
        if keep then Add(keep) end
        table.sort(list, function(a, b)
            local ca, cb = a.chance or a.guessed or 0, b.chance or b.guessed or 0
            if ca ~= cb then return ca > cb end
            if (a.item.q or 0) ~= (b.item.q or 0) then return (a.item.q or 0) > (b.item.q or 0) end
            return a.id < b.id
        end)
        m.guildKills = guildKills
        if #list == 0 then
            m.none, m.h = true, BOSS_H + 62
            return m
        end
        local starredSet = ns.Gear and ns.Gear.Starred() or {}
        local trades = {}
        -- A recipe's kind is named in the client's language: your professions by the game's name too.
        for _, p in ipairs(ns.Professions and ns.Professions.Mine and ns.Professions.Mine() or {}) do
            trades[p.name or ""] = true
            if type(p.game) == "string" then trades[p.game] = true end
        end
        local mine, others, forYou, sure = {}, {}, 0, 0
        for k, entry in ipairs(list) do
            local _, _, _, _, _, _, subclass, _, equipLoc, _, classID, subclassID = ItemInfo(entry.id)
            entry.at, entry.known = k, classID ~= nil
            entry.starred = starredSet[entry.id] == true
            -- A piece on your gear plan is never put with what isn't for you.
            entry.cant = not entry.starred and CantEquip(classID, subclassID, equipLoc)
            entry.recipe = classID == RECIPE
            entry.prof = entry.recipe and trades[subclass or ""] == true
            -- For other classes only, by its own "Classes:" line.
            entry.classes = not entry.starred and not entry.recipe and ForOthers(entry.id) == true
            entry.better, entry.gain, entry.loss = nil, nil, nil
            if not entry.cant and not entry.classes and not entry.recipe and ns.Gear and ns.Gear.Better then
                local asked = debugprofilestop()
                local is, gain = ns.Gear.Better(entry.id, equipLoc, classID, subclassID)
                Spent("bosses: of which, the Gear plan's upgrade checks", asked)
                if is ~= nil then sure = sure + 1 end
                if is then
                    entry.better, entry.gain = true, gain
                elseif is == false and entry.starred and gain and gain < 0 then
                    -- Starred when it was an upgrade; what you wear has passed it.
                    entry.loss = gain
                end
            end
            entry.away = entry.cant or entry.classes or (entry.recipe and not entry.prof and not entry.starred)
            if entry.starred or entry.better then forYou = forYou + 1 end
            local to = entry.away and others or mine
            to[#to + 1] = entry
        end
        -- The lines: what you starred, as the list has them, then what's better, the most first, then what else
        -- you can equip, as the list has them (likeliest first), as many as there's room for. The rest goes on the
        -- strip, what you could use before what you can't.
        local lines, strip = m.lines, m.strip
        for _, entry in ipairs(mine) do if entry.starred then lines[#lines + 1] = entry end end
        local better = {}
        for _, entry in ipairs(mine) do if entry.better and not entry.starred then better[#better + 1] = entry end end
        table.sort(better, function(a, b)
            if (a.gain or 0) ~= (b.gain or 0) then return (a.gain or 0) > (b.gain or 0) end
            return a.at < b.at
        end)
        for _, entry in ipairs(better) do
            if #lines < LINES then lines[#lines + 1] = entry end
        end
        for _, entry in ipairs(lines) do entry.line = true end
        for _, entry in ipairs(mine) do
            if not entry.line and entry.known and #lines < LINES then
                lines[#lines + 1] = entry
                entry.line = true
            end
        end
        for _, entry in ipairs(mine) do if not entry.line then strip[#strip + 1] = entry end end
        for _, entry in ipairs(others) do strip[#strip + 1] = entry end
        -- The piece asked for is seen, on a line of its own.
        for k, entry in ipairs(strip) do
            if entry.id == keep then
                table.remove(strip, k)
                lines[#lines + 1] = entry
                break
            end
        end
        m.forYou, m.sure = forYou, sure
        m.h = m.top + #lines * ITEM_H
        -- The rest, small along the foot after its label: a second row of them when one won't hold them all.
        if #strip > 0 then
            m.label = ("ALSO DROPS %d"):format(#strip)
            local x0 = 13 + B.Wide(m.label) + 12
            local x, y = x0, 0
            for _, entry in ipairs(strip) do
                if x + SMALL > cardW - 14 then x, y = x0, y + SMALL + 4 end
                entry.x, entry.y = x, y
                x = x + SMALL + 4
            end
            m.stripH = STRIP_H + y
            m.h = m.h + m.stripH
        end
        return m
    end
    -- How wide the strip's label is drawn, by one line of text kept for it, measured once a label.
    B.widths = {}
    function B.Wide(text)
        if B.widths[text] then return B.widths[text] end
        if not B.measure then
            B.measure = Style.Text(right, 10, "muted", nil, true)
            B.measure:Hide()
        end
        B.measure:SetText(text)
        local w = B.measure.GetStringWidth and B.measure:GetStringWidth()
        if type(w) == "number" and w > 0 then
            B.widths[text] = w
            return w
        end
        return 70
    end

    -- A card's loot as B.Model worked it out, on its frame.
    local function PaintLoot(card, m)
        for _, it in ipairs(card.items) do it:Hide() end
        for _, s in ipairs(card.smalls) do s:Hide() end
        card.strip:Hide()
        card.edge:Hide()
        if m.none then
            card.none:SetText("No loot known yet. It's added when you or a guildmate with jsal.ui loots this boss.")
            card.none:Show()
            return
        end
        card.none:Hide()
        card.edge:SetShown(m.forYou > 0)
        local top = m.top
        for k, entry in ipairs(m.lines) do
            local it = Item(card, k)
            it:ClearAllPoints()
            it:SetPoint("TOPLEFT", 0, -(top + (k - 1) * ITEM_H))
            it.rule:SetShown(k > 1)
            it.item = entry.id
            local name, _, quality, _, req, _, subclass, _, equipLoc, texture, classID, subclassID = ItemInfo(entry.id)
            local q = quality or entry.item.q or 1
            -- After its name: the star when it's on your gear plan, then how
            -- much better it is than what you wear, or, for a starred piece
            -- that no longer is, how much worse.
            local kind, words = (entry.better and "better") or (entry.loss and "worse") or (entry.prof and "prof") or nil, "better"
            if entry.better and entry.gain then
                local pct = math.floor(entry.gain * 100 + 0.5)
                words = pct < 1 and "under 1%" or ("+" .. pct .. "%")
            elseif entry.loss then
                local pct = math.floor(-entry.loss * 100 + 0.5)
                words = pct < 1 and "a little worse" or ("-" .. pct .. "%")
            end
            local tagW = SetTag(it, kind, words)
            it.starred = entry.starred
            it.star:SetShown(entry.starred)
            it.tag:ClearAllPoints()
            it.tag:SetPoint("LEFT", entry.starred and it.star or it.name, "RIGHT", 8, 0)
            if entry.starred then tagW = tagW + 20 end
            it.name:SetWidth(0)
            it.name:SetText(("|cff%s%s|r"):format(Style.Quality(q), name or entry.item.n or "..."))
            it.line:SetColorTexture(Hex3(Style.Quality(q)))
            local room = cardW - 58 - 14 - METER_W - 12 - tagW
            local wide = it.name.GetStringWidth and it.name:GetStringWidth()
            if type(wide) ~= "number" or wide <= 0 or wide > room then it.name:SetWidth(room) end
            local slot = equipLoc and equipLoc ~= "" and _G[equipLoc] or nil
            local parts = {}
            -- Recipes and other things you don't wear have a blank slot name.
            if slot and slot ~= "" then parts[#parts + 1] = slot end
            -- Armour's Miscellaneous (a ring, a neck, a trinket) says nothing the slot doesn't: by its IDs, which every
            -- client language shares, and by the English word.
            local misc = (classID == 4 and subclassID == 0) or subclass == "Miscellaneous"
            if subclass and subclass ~= "" and subclass ~= slot and not misc then parts[#parts + 1] = subclass end
            -- On the Trash card, the creature it drops from.
            if entry.creature then parts[#parts + 1] = entry.creature end
            -- Too high for you yet: its level, in red.
            if req and req > (UnitLevel("player") or 1) then parts[#parts + 1] = ("%slevel %d|r"):format(RED, req) end
            it.slot:SetText(table.concat(parts, " · "))
            local chance = entry.chance or entry.guessed
            it.chance:SetText(chance and ("%d%%"):format(chance) or "")
            it.track:SetShown(chance ~= nil)
            it.fill:SetShown(chance ~= nil)
            if chance then it.fill:SetWidth(math.max(1, METER_W * math.min(100, chance) / 100)) end
            -- How often it's been seen is said when it's pointed at.
            it.seen = Seen(entry)
            -- And what its star and a red tag mean.
            local more = {}
            if it.seen then more[#more + 1] = (it.seen:gsub("^%l", string.upper)) .. "." end
            if entry.starred then more[#more + 1] = "Starred in your Gear plan." end
            if entry.loss then more[#more + 1] = "By your Gear plan's weights it's no longer better than what you wear." end
            it.more = #more > 0 and more or nil
            it.icon:SetTexture(texture or Compat.ItemIcon(entry.id) or "Interface\\Icons\\INV_Misc_QuestionMark")
            it:Show()
        end
        if #m.strip > 0 then
            local bar = card.strip
            bar.label:SetText(m.label)
            for k, entry in ipairs(m.strip) do
                local s = Small(card, k)
                s:ClearAllPoints()
                s:SetPoint("TOPLEFT", entry.x, -(8 + entry.y))
                s.item = entry.id
                local _, _, _, _, _, _, _, _, _, texture = ItemInfo(entry.id)
                s.icon:SetTexture(texture or Compat.ItemIcon(entry.id) or "Interface\\Icons\\INV_Misc_QuestionMark")
                local chance, seen = entry.chance or entry.guessed, Seen(entry)
                s.more = {}
                if entry.cant then
                    s.more[1] = "Your class can't equip it."
                elseif entry.classes then
                    s.more[1] = "For other classes only."
                elseif entry.recipe then
                    s.more[1] = entry.prof and "A recipe for your profession." or "A recipe for a profession you don't have."
                end
                if chance then s.more[#s.more + 1] = ("Drops %d%% of the time."):format(chance) end
                if entry.creature then s.more[#s.more + 1] = ("Drops from %s."):format(entry.creature) end
                if seen then s.more[#s.more + 1] = (seen:gsub("^%l", string.upper)) .. "." end
                s:Show()
            end
            bar:SetHeight(m.stripH)
            bar:Show()
        end
    end

    -- A card on its frame: its heading, its loot, its place in the list.
    function B.Draw(card, m)
        local b = m.b
        if b then
            card.head:SetHeight(BOSS_H)
            if card.note then card.note:Hide() end
            card.boss = b[2]
            card.number:SetText(m.k)
            card.name:SetText(b[3] or b[2])
            card.box:SetShown(m.n > 0)
            -- Without a tick the name comes right after the number.
            card.name:ClearAllPoints()
            if m.n > 0 then
                card.name:SetPoint("LEFT", card.box, "RIGHT", 8, 0)
            else
                card.name:SetPoint("LEFT", card.head, "LEFT", 36, 0)
            end
            card.kills:SetText(m.kills)
        else
            B.TrashHead(card)
        end
        PaintLoot(card, m)
        card:SetHeight(m.h)
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", m.left, -m.at)
        card.at, card.drawn = m.at, m
        card:Show()
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

    -- The level column: the quest's own level. The level you can take it at
    -- is said only while you're under it, in red; once you can take it, it
    -- has nothing more to tell you.
    function Q.Level(q, mine)
        local take = q[4] or q[3]
        if take > mine then
            if take >= q[3] then return ("%sneeds level %d|r"):format(RED, take) end
            return ("level %d · %sneeds level %d|r"):format(q[3], RED, take)
        end
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
        -- goes with that one; the rest are what there is to pick up, and
        -- are placed further down, once their chains are known.
        local under, tops, later = {}, {}, 0
        for _, q in ipairs(todo) do
            local e = entries[q[1]]
            if e.before and entries[e.before] and e.before ~= q[1] then
                under[e.before] = under[e.before] or {}
                table.insert(under[e.before], e)
                later = later + 1
            else
                tops[#tops + 1] = e
            end
        end
        local function ByLevel(x, y)
            if x.q[3] ~= y.q[3] then return x.q[3] < y.q[3] end
            return x.q[1] < y.q[1]
        end
        for _, list in pairs(under) do table.sort(list, ByLevel) end
        table.sort(tops, ByLevel)

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
        -- That line shows only when it has more to say than the count the
        -- tab already gives: some above your level, later parts, some done.
        local said = #quests > 0 and (tooLow > 0 or #more > 0)
        for _, region in ipairs({ Q.sum, Q.more, Q.low }) do region:SetShown(said) end
        Q.cols:SetShown(#quests > 0)
        hint:SetText((#quests > 0 and ns.DungeonQuestStarts) and "click a quest, a step or a place for a map pin" or "")
        if #quests > 0 then
            if said then by = by + 28 end
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
        local function Folded(chain, offset)
            offset = offset or 0
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
                    shown[#shown + 1] = { number = ("%d–%d"):format(i + offset, j + offset), name = ("%s, %s parts"):format(chain[i].name, WORDS[count] or count),
                        who = table.concat(route, " → ") .. (done > 0 and done < count and ("  ·  %d done"):format(done) or ""),
                        done = done == count, first = chain[i + done] or chain[i] }
                else
                    j = i
                    shown[#shown + 1] = { number = tostring(i + offset), name = chain[i].name, who = Q.Giver(chain[i].s, true), done = chain[i].done,
                        own = chain[i].own, first = chain[i] }
                end
                i = j + 1
            end
            return shown
        end
        -- A block is what a card or a line shows: one of the dungeon's quests,
        -- or several whose chains share the steps that lead up to them
        -- (`lead`, with each one's own steps after it in `tails`).
        local function PaintCard(block)
            cards = cards + 1
            local c = Q.Card(cards)
            local e, count = block.list[1], 0
            local shown
            if block.tails then
                shown = Folded(block.lead)
                for _, tail in ipairs(block.tails) do
                    for _, step in ipairs(Folded(tail, #block.lead)) do shown[#shown + 1] = step end
                    count = math.max(count, #block.lead + #tail)
                end
            else
                shown, count = Folded(block.chain), #block.chain
            end
            local names = {}
            for i, entry in ipairs(block.list) do names[i] = entry.q[2] end
            c.title:SetText(#names <= 2 and table.concat(names, Style.Tint("muted") .. " and |r")
                or (names[1] .. Style.Tint("muted") .. (" and %d more"):format(#names - 1) .. "|r"))
            c.count:Say(count == 1 and "1 step" or ("%d-step chain"):format(count))
            c.opens:SetShown(#block.list > 1)
            if #block.list > 1 then c.opens:Say(("opens %d quests"):format(#block.list)) end
            -- Every step this dungeon's own: said once, in the heading.
            local every = true
            for _, step in ipairs(block.chain) do
                if not step.own then every = false end
            end
            c.own:SetShown(every)
            c.every:SetShown(every)
            -- The level, once for the card when its quests share one; else
            -- each quest's on its own step.
            local level, same = Q.Level(e.q, mine), true
            for _, entry in ipairs(block.list) do
                if Q.Level(entry.q, mine) ~= level then same = false end
            end
            c.level:SetText(same and level or "")
            local tall = 34 + #shown * 24 + 8
            c:SetHeight(tall)
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", 4, -by)
            c:Show()
            -- Who gives a step is said on the first of a run that share it.
            local lastWho
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
                local run = not step.done and step.number:find("–", 1, true) ~= nil
                st.badge:SetWidth(run and (Q.Wide(st.number, #step.number * 5) + 10) or 18)
                local shape, other = run and st.pill or st.disc, run and st.disc or st.pill
                for _, part in ipairs({ shape.line, shape.fill }) do part:Show() end
                for _, part in ipairs({ other.line, other.fill }) do part:Hide() end
                if step.done then shape:Paint("wordGreen", "wordGreen") elseif start then shape:Paint("gold", "gold") else shape:Paint("line", "lineStrong") end
                st.number:SetTextColor(Style.Color(start and "onGold" or "muted"))
                st.name:SetText(step.name)
                st.name:SetTextColor(Style.Color(start and "text" or "muted"))
                -- The step to do now: its mark, and "start here" until
                -- it's in your log.
                local held = false
                if start then
                    local q = step.first.q
                    held = QuestMark(st.mark, step.first.id, q and (q[4] or q[3]), mine)
                else
                    st.mark:Hide()
                end
                local tagged = start and not held
                st.start:SetShown(tagged)
                st.ownQuest = step.own == true
                st.own:SetShown(step.own == true and not every)
                st.own:ClearAllPoints()
                st.own:SetPoint("LEFT", tagged and st.start or (start and st.mark or st.name), "RIGHT", start and 6 or 8, 0)
                -- The giver starts at its column, or past a long name's tags.
                local ends = 48 + Q.Wide(st.name, 0) + (start and 22 or 0) + (tagged and st.start.wide + 4 or 0)
                    + ((step.own and not every) and st.own.wide + 8 or 0)
                st.who:SetPoint("LEFT", math.max(WHO_X - 4, ends + 14), 0)
                local who = step.who
                if step.done then
                    who = ""
                elseif who == lastWho then
                    who = ""
                else
                    lastWho = who
                end
                st.who:SetText(who)
                local own = not same and step.own and step.first.q or nil
                st.level:SetText(own and Q.Level(own, mine) or "")
                st:SetAlpha(step.done and 0.6 or 1)
                st:ClearAllPoints()
                st:SetPoint("TOPLEFT", 4, -y)
                st:Show()
                y = y + 24
            end
            by = by + tall + 8
        end
        -- A quest alone, on a line. Who gives it is said on the first of a
        -- run of lines that share them.
        local lineWho
        local function PaintLine(e)
            lines = lines + 1
            local row = Q.Line(lines)
            row.quest = e.q[1]
            row.spot = Starts.Spot(e.q[1], QuestDone)
            row.name:SetText(e.q[2])
            QuestMark(row.mark, e.q[1], e.q[4] or e.q[3], mine)
            local who = Q.Giver(e.s, false)
            row.who:SetText(who == lineWho and "" or who)
            lineWho = who
            row.level:SetText(Q.Level(e.q, mine))
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -by)
            row:Show()
            by = by + 26
        end

        -- What there is to pick up, as blocks. A chain's lead is its steps
        -- before the dungeon's own quest. Quests whose leads are the same
        -- steps, with one of them still to do, are one block: the lead
        -- once, then each quest's own steps.
        -- Returns the places they're filed under, in the order they're shown.
        local function Places()
            local blocks, shared = {}, {}
            for _, e in ipairs(tops) do
                local chain = Chain(e)
                local lead, tail, key, open = {}, {}, {}, false
                for _, step in ipairs(chain) do
                    if #tail == 0 and not step.own then
                        lead[#lead + 1] = step
                        key[#key + 1] = step.id
                        if not step.done then open = true end
                    else
                        tail[#tail + 1] = step
                    end
                end
                local id = open and table.concat(key, ",") or nil
                local block = id and shared[id]
                if block then
                    if not block.tails then block.lead, block.tails = lead, { block.tail } end
                    block.list[#block.list + 1] = e
                    block.tails[#block.tails + 1] = tail
                    for _, step in ipairs(tail) do block.chain[#block.chain + 1] = step end
                else
                    block = { list = { e }, chain = #chain > 1 and chain or nil, tail = tail }
                    if id then shared[id] = block end
                    blocks[#blocks + 1] = block
                end
            end
            -- A block is filed where its next step is: for a quest alone, where
            -- it starts; for a chain, where the first step still to do does.
            local places, order = {}, {}
            for _, block in ipairs(blocks) do
                local e = block.list[1]
                local name, kind = e.place, e.kind
                for _, step in ipairs(block.chain or {}) do
                    if not step.done then
                        if step.s then name, kind = Starts.Place(step.s) end
                        break
                    end
                end
                local place = places[name]
                if not place then
                    place = { name = name, kind = kind, blocks = {}, quests = 0 }
                    places[name] = place
                    order[#order + 1] = place
                end
                place.blocks[#place.blocks + 1] = block
                place.quests = place.quests + #block.list
            end
            -- Places, the ones with most to pick up first; inside the dungeon
            -- and the unknown last.
            table.sort(order, function(x, y)
                if x.kind ~= y.kind then return x.kind < y.kind end
                if x.quests ~= y.quests then return x.quests > y.quests end
                return x.name < y.name
            end)
            return order
        end
        for _, place in ipairs(Places()) do
            heads = heads + 1
            local h = Q.Head(heads)
            h.name:SetText(place.name)
            -- What's here: a quest alone is a line, a chain a card.
            local chains, spots = 0, {}
            for _, block in ipairs(place.blocks) do
                if block.chain then chains = chains + 1 end
                for _, e in ipairs(block.list) do
                    local spot = Starts.Spot(e.q[1], QuestDone)
                    if spot then spots[#spots + 1] = spot end
                end
            end
            local count = ("%d quest%s"):format(place.quests, place.quests == 1 and "" or "s")
            if chains > 0 then count = count .. ("  ·  %d chain%s"):format(chains, chains == 1 and "" or "s") end
            h.count:SetText(count)
            h.stops = Starts.Stops(spots)
            -- A different place under this bar starts again at its first stop.
            if h.place ~= place.name then h.place, h.at = place.name, nil end
            h.link:SetShown(#h.stops > 0)
            h.link:SetText(#h.stops > 1 and ("show on map · %d stops"):format(#h.stops) or "show on map")
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", 0, -by)
            h:Show()
            by = by + 36
            lineWho = nil
            for _, block in ipairs(place.blocks) do
                if block.chain then
                    PaintCard(block)
                    lineWho = nil
                else
                    PaintLine(block.list[1])
                end
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
        local started = debugprofilestop()
        spent = {}
        local level = UnitLevel("player") or 1
        local faction = Compat.Faction()
        local game = D.GameKills()
        local t = Spent("boss kills from the game", started)
        -- A dungeon asked for from elsewhere (the Gear plan's "Open guide", a piece on Endgame's goal card) is
        -- the one shown, on the tab asked for and with the boss asked for brought to the top, as from the map.
        if D.wantFrom then
            B.whyNext, D.wantFrom = D.wantFrom, nil
        elseif D.want then
            B.why, B.whyNext = nil, nil
        end
        if D.want then chosen, D.want, List.reveal = D.want, nil, true end
        if D.wantTab then tab, List.pick, D.wantTab = D.wantTab, D.wantTab, nil end
        if D.wantBoss then B.jump, B.jumpItem, D.wantBoss, D.wantItem = D.wantBoss, D.wantItem, nil, nil end
        if not chosen then
            local first
            for _, d in ipairs(InOrder(faction)) do
                first = first or d
                if Fits(d, level) then chosen = d break end
            end
            chosen = chosen or first
        end
        -- The tab you chose, where this dungeon has it.
        if List.pick == "map" and chosen then tab = (mapPane and ns.DungeonMap.Has(chosen)) and "map" or "bosses" end
        if List.dirty or List.shown ~= chosen or List.reveal then List.Paint() end

        t = Spent("the dungeon list", t)
        -- The chosen dungeon.
        local d = chosen
        if not d then return end
        if not wait.drawn then List.Title(d, level) end
        local fresh = tab == "bosses" and d ~= wait.drawn and not wait.late[d]
        if (fresh or not wait.asked[d]) and wait.Count(d) > 0 and fresh and Compat.After then
            if wait.holding ~= d then
                wait.holding = d
                Compat.After(HOLD, ns.Safe(D, function()
                    if wait.holding ~= d then return end
                    wait.holding, wait.late[d] = nil, true
                    if page:IsVisible() then Paint() end
                end))
            end
            return
        end
        wait.holding = nil
        List.Title(d, level)
        local killed = 0
        for _, b in ipairs(d.bosses) do
            if D.KillCount(b[2], game, b[3]) > 0 then killed = killed + 1 end
        end
        local bits = Facts(d)
        bits[#bits + 1] = ("%d of %d bosses killed"):format(killed, #d.bosses)
        meta:SetText(table.concat(bits, " · "))

        for _, pool in ipairs({ Q.lines, Q.heads, Q.priors, Q.cards, Q.steps }) do
            for _, region in ipairs(pool) do region:Hide() end
        end
        for _, region in ipairs({ Q.sum, Q.more, Q.low, Q.cols }) do region:Hide() end
        for _, row in ipairs(bossRows) do
            row:Hide()
            row.drawn = nil
        end
        B.models = nil
        B.sum:Hide()
        B.Say(nil)
        meta:ClearAllPoints()
        meta:SetPoint("TOPLEFT", 0, -3)
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
        tabs:Set("quests", nil, #quests > 0 and #quests or nil)
        local hasMap = mapPane ~= nil and ns.DungeonMap.Has(d)
        tabs:Shown("map", hasMap)
        if tab == "map" and not hasMap then tab = "bosses" end
        tabs:Pick(tab)
        -- What the dungeon's creatures drop: a card after the last boss where anything is known. A piece asked for
        -- that drops from them, and that the card lists, is landed on there, lit, as on a boss's card.
        B.trash = tab == "bosses" and D.Trash and D.Trash(d) or {}
        B.trashK = #B.trash > 0 and #d.bosses + 1 or nil
        local from = B.whyNext or B.why
        for _, e in ipairs(B.trashK and from and from.dungeon == d and B.trash or {}) do
            if e[1] == from.item then
                B.jump, B.jumpItem, B.whyNext, B.why = B.trashK, from.item, nil, nil
                break
            end
        end
        -- A piece asked for keeps its line on its boss's card while this dungeon's bosses are shown.
        if B.jump and B.jumpItem then B.keep = { d = d, k = B.jump, item = B.jumpItem } end
        if B.keep and (B.keep.d ~= d or tab ~= "bosses") then B.keep = nil end
        B.about:Say(tab == "map" and "About this map" or "About these numbers")
        bossScroll:SetShown(tab ~= "map")
        if mapPane then mapPane:SetShown(tab == "map") end
        if tab == "map" then
            hint:SetText("")
            B.about.mapNote = ns.DungeonMap.About(d)
            -- The map marks the bosses with gear for you. An item of theirs the game
            -- hasn't loaded yet is counted, so the map is drawn again when it comes.
            missed = 0
            mapPane:Draw(d, function(k)
                local b = d.bosses[k]
                return D.KillCount(b[2], game, b[3]) > 0
            end, function(k) return BossGear(d.bosses[k]) end, (D.BossQuests(d)), function(tip, k) D.BossTip(tip, d, k) end)
            wait.drawn, wait.lacking = d, missed
            Fit(mapPane.height)
            B.whyNext = nil
            B.Scroll(d, tab)
            NoteParts(started)
            return
        end
        local by = 0
        t = Spent("the dungeon's quests, found", t)
        if tab == "quests" then
            by = Q.Paint(quests, by)
            Spent("the quests tab", t)
            if #quests == 0 then
                none:ClearAllPoints()
                none:SetPoint("TOPLEFT", 0, -8)
                none:SetText("No quests for this one on Wowhead yet.")
                none:Show()
                by = 40
            end
            bossList:SetHeight(math.max(1, by))
            Fit(by)
            B.whyNext = nil
            B.Scroll(d, tab)
            NoteParts(started)
            return
        end
        -- The bosses as cards, two across, in the game's order, under a
        -- line of how much here is for you.
        hint:SetText("")
        local models, forYou, sure = {}, 0, 0
        missed = 0
        if ns.Gear then ns.Gear.made = {} end
        for k = 1, B.trashK or #d.bosses do
            t = debugprofilestop()
            local b = d.bosses[k]
            local keep = B.keep and B.keep.k == k and B.keep.item or nil
            local m = b and B.Model(b[2], b[1], keep) or B.Model(nil, nil, keep, B.trash)
            Spent("bosses: loot, all of it", t)
            m.k, m.b = k, b
            if b then
                m.n = D.KillCount(b[2], game, b[3])
                -- Your kills, and the guild's: said here once, where it was on
                -- every item ("dropped 1× in 1 guild kill").
                local words = {}
                if m.n > 0 then words[#words + 1] = ("killed %d×"):format(m.n) end
                if m.guildKills > 0 then words[#words + 1] = ("%d guild kill%s"):format(m.guildKills, m.guildKills == 1 and "" or "s") end
                m.kills = table.concat(words, "  ·  ")
            end
            forYou, sure = forYou + m.forYou, sure + m.sure
            models[k] = m
        end
        -- Said only when there's something to say: a piece on your gear
        -- plan, or the gear plan could tell what's better (it needs your
        -- spec's weights, and the game to have loaded the items). The
        -- dungeon's level and place follow it on the line.
        local said = sure > 0 or forYou > 0
        B.sum:SetShown(said)
        if said then
            B.sum:SetText(forYou == 0 and "Nothing here is better than what you wear"
                or (forYou == 1 and "1 piece here is for you" or ("%d pieces here are for you"):format(forYou)))
            meta:ClearAllPoints()
            meta:SetPoint("LEFT", B.sum, "RIGHT", 14, 0)
        end
        -- Why no boss was brought to the top, when that's so: a line above the cards.
        local asked = B.whyNext or B.why
        by = B.Say(asked and asked.dungeon == d and asked or nil)
        -- Two across: each pair starts level, the next pair under the
        -- taller of the two.
        for k = 1, #models, 2 do
            local tall = math.max(models[k].h, models[k + 1] and models[k + 1].h or 0)
            for side = 0, 1 do
                local m = models[k + side]
                if m then m.at, m.left = by, side * (cardW + GRID_GAP) end
            end
            by = by + tall + ROW_GAP
        end
        by = math.max(1, by - ROW_GAP)
        bossList:SetHeight(by)
        local listH = Fit(by)
        B.models = models
        t = debugprofilestop()
        B.Scroll(d, tab)
        B.Bind()
        Spent("bosses: cards drawn", t)
        if B.whyNext then B.why, B.whyNext = B.whyNext, nil end
        wait.drawn, wait.lacking = d, missed
        for why, ms in pairs(ns.Gear and ns.Gear.made or {}) do
            spent["bosses: of which, gear plans " .. (MADE[why] or why)] = ms
        end
        -- A boss asked for is brought to the top (B.Aim), its piece lit, and both held while the page settles.
        if B.jump then
            B.Let()
            B.aim, B.mark, B.jump, B.jumpItem = B.jump, B.jumpItem, nil, nil
        end
        if B.aim then
            B.Aim(math.max(0, by - listH))
            B.Light()
        end
        NoteParts(started)
    end

    page.Refresh = function()
        List.dirty = true
        Paint()
    end
    -- Item names and icons the game hadn't loaded yet arrive a moment later.
    -- They come one by one, so the page repaints once for a batch.
    local waiting
    page:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    page:SetScript("OnEvent", function(_, event)
        -- The quest log changed: the list's marks are read again, a moment later for a run of changes.
        if event == "QUEST_LOG_UPDATE" then
            List.held = nil
            if List.soon or not page:IsVisible() then return end
            List.soon = true
            Compat.After(0.2, ns.Safe(D, function()
                List.soon = nil
                if page:IsVisible() then List.Paint() end
            end))
            return
        end
        -- A dungeon waited for is drawn the moment its last item is in.
        if wait.holding then
            if page:IsVisible() and Unloaded(wait.holding) == 0 then Paint() end
            return
        end
        -- Nothing missing from the page: an item that arrived is another dungeon's.
        if waiting or wait.lacking == 0 or not page:IsVisible() or tab == "quests" then return end
        waiting = true
        Compat.After(0.2, ns.Safe(D, function()
            waiting = nil
            if page:IsVisible() then Paint() end
        end))
    end)
-- In a window of its own, with room for the boss cards.
end, { width = OWN_W, height = OWN_H })
