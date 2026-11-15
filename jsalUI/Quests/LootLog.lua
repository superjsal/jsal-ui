-- The drop log: how often the creatures you loot have the quest items you're after, counted as
-- you play, so a quest's likely kills can come from Forever itself where nobody else has
-- counted. The numbers anyone has for drop chances are counts of what players saw; past the
-- levels many have played, those counts are thin. (John, 14 Nov 2026, of recording his own: "that
-- sounds fine as well, i'm at the point past the beta at level 30+", then "both, quest items, and
-- it would be opt in most likely": his own quest tags and the data shipped to the guild, and
-- quest items only.)
--
-- A loot counts when a corpse's window opens while a quest in your log still needs an item. Each
-- quest item still wanted is then one try for that creature, and one find if the corpse had it.
-- Quest items only drop while a quest needs them, so nothing is counted for an item once its
-- objective is done. A corpse counts once, however often its window is opened.
--
-- Which corpse: the game says where each thing in the window came from (GetLootSourceInfo), so
-- a window opened for several corpses counts each of them, with what that one had. Forever's own
-- code never calls that function and the first version took it to be missing, counting the dead
-- creature targeted and so one loot for a window of several; John's game has it (his
-- /run print(GetLootSourceInfo): "function: ...", 14 Nov 2026). The targeted way is kept for
-- when the game gives no source. A corpse's creature is known by the number in its ID; its name
-- comes from your target when that's the corpse, and is remembered for the others of its kind.
--
-- An item's chance is its finds over its tries, among the creatures that have had it at least
-- once: a creature that has never had it for you is taken not to drop it. That leans a little
-- high while the counts are small, so nothing is said below FLOOR tries.
local _, ns = ...
local Compat = ns.Compat

local LootLog = ns.NewModule("lootlog", {
    title = "Drop log",
    -- It keeps a record of what you loot, so it starts off.
    defaultOn = false,
    note = "Counts how often the creatures you loot have the quest items you're after, so quest tags can use Forever's own drop chances where few players have been. Quest items only; it stays on your computer. /jsal drops shows what it has.",
})
ns.LootLog = LootLog

LootLog.FLOOR = 10      -- tries an item needs before its chance is said
local CORPSES = 300     -- corpses remembered as counted, before the oldest are let go

-- The saved counts: creatures[name] = { n = loots, tries = { [item] = n }, finds = { [item] = n } },
-- and ids[item name] = item ID, for the build that ships them.
local function Log()
    local log = ns.db.lootLog
    if type(log) ~= "table" then
        log = {}
        ns.db.lootLog = log
    end
    log.creatures = type(log.creatures) == "table" and log.creatures or {}
    log.ids = type(log.ids) == "table" and log.ids or {}
    return log
end

-- The thing an objective names, from "Ghoul Fang: 1/10" or "1/10 Ghoul Fang".
local function Named(text)
    text = text or ""
    return text:match("^(.-):%s*%d+%s*/%s*%d+%s*$") or text:match("^%d+%s*/%s*%d+%s+(.+)$") or text
end
LootLog.Named = Named

-- The quest items still wanted: { [lower-case name] = name }, from every quest in the log.
function LootLog.Wanted()
    local wanted = {}
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and info.questID then
            local objectives = C_QuestLog.GetQuestObjectives(info.questID)
            for _, o in ipairs(type(objectives) == "table" and objectives or {}) do
                if o.type == "item" and not o.finished and (o.numRequired or 0) > (o.numFulfilled or 0) then
                    -- Trimmed, and nothing for an objective whose words haven't loaded:
                    -- /jsal drops listed an empty name first. (John's game, 14 Nov 2026.)
                    local name = Named(o.text):match("^%s*(.-)%s*$")
                    if name ~= "" then wanted[name:lower()] = name end
                end
            end
        end
    end
    return wanted
end

-- One loot of a creature: `wanted` as LootLog.Wanted gives it, `found` the items in the window
-- as { [lower-case name] = item ID or true }.
function LootLog.Count(creature, wanted, found)
    if not creature or not next(wanted) then return false end
    local log = Log()
    local c = log.creatures[creature]
    if type(c) ~= "table" then
        c = { n = 0, tries = {}, finds = {} }
        log.creatures[creature] = c
    end
    c.tries = type(c.tries) == "table" and c.tries or {}
    c.finds = type(c.finds) == "table" and c.finds or {}
    c.n = (tonumber(c.n) or 0) + 1
    for lower, name in pairs(wanted) do
        c.tries[name] = (c.tries[name] or 0) + 1
        if found[lower] then
            c.finds[name] = (c.finds[name] or 0) + 1
            if type(found[lower]) == "number" then log.ids[name] = found[lower] end
        end
    end
    return true
end

-- An item's finds and tries, among the creatures that have had it. The name in any case.
function LootLog.Seen(itemName)
    if type(itemName) ~= "string" then return 0, 0 end
    local lower = itemName:lower()
    local finds, tries = 0, 0
    for _, c in pairs(Log().creatures) do
        if type(c) == "table" and type(c.finds) == "table" then
            for name, n in pairs(c.finds) do
                if name:lower() == lower and n > 0 then
                    finds = finds + n
                    tries = tries + ((type(c.tries) == "table" and c.tries[name]) or n)
                end
            end
        end
    end
    return finds, tries
end

-- The chance a creature that has a quest item has it (0 to 1), and how many loots that's from; or
-- nil while the part is off or the loots are fewer than FLOOR. The quest isn't needed to find it,
-- and is taken so the quest tags can ask as they think: by quest and item.
function LootLog.Chance(questID, itemName)
    if not LootLog.running then return nil end
    local finds, tries = LootLog.Seen(itemName)
    if tries < LootLog.FLOOR then return nil end
    return finds / tries, tries
end

---------------------------------------------------------------------------
-- Watching the loot window.
---------------------------------------------------------------------------
local counted, order = {}, {}

-- The creature whose corpse is being looted: the dead one targeted, not a player. Nil in a
-- dungeon, where the game hides who it is, and for a chest, a plant or a fishing bobber.
local function Corpse()
    if IsFishingLoot and Compat.Plain(IsFishingLoot()) then return nil end
    if not Compat.Plain(UnitExists("target")) or not Compat.Plain(UnitIsDead("target")) then return nil end
    if Compat.Plain(UnitIsPlayer("target")) then return nil end
    return Compat.Name("target"), Compat.GUID("target")
end

-- Whether a corpse has been counted; if not, it is now. Each corpse once, however often its
-- window is opened.
local function Already(guid)
    if counted[guid] then return true end
    counted[guid] = true
    order[#order + 1] = guid
    if #order > CORPSES then counted[table.remove(order, 1)] = nil end
    return false
end

-- The kind of creature a corpse is, from its ID: "Creature-0-4444-0-12-3955-00001A2B3C" is
-- creature 3955. Nil for a chest, an item or a player.
local function Kind(guid)
    return type(guid) == "string" and tonumber(guid:match("^Creature%-.-%-.-%-.-%-.-%-(%d+)%-")) or nil
end
LootLog.Kind = Kind

-- What a kind of creature is called in the log: its name once it's been learned, till then
-- "creature 3955". Learning a name moves what was counted under the number to the name.
local function Called(kind, name)
    local log = Log()
    log.names = type(log.names) == "table" and log.names or {}
    local numbered = "creature " .. kind
    if name and log.names[kind] ~= name then
        log.names[kind] = name
        local was = log.creatures[numbered]
        if type(was) == "table" then
            local c = log.creatures[name]
            if type(c) ~= "table" then
                log.creatures[name] = was
            else
                c.n = (tonumber(c.n) or 0) + (tonumber(was.n) or 0)
                for _, field in ipairs({ "tries", "finds" }) do
                    c[field] = type(c[field]) == "table" and c[field] or {}
                    for item, n in pairs(type(was[field]) == "table" and was[field] or {}) do
                        c[field][item] = (c[field][item] or 0) + n
                    end
                end
            end
            log.creatures[numbered] = nil
        end
    end
    return log.names[kind] or numbered
end

-- The window's things by the corpse each came from: { [corpse's ID] = { [lower-case item name]
-- = item ID or true } }, creatures only, or nil when none of it came from a creature; and
-- whether the game named a source for anything at all. A chest or a plant is a source too, and
-- not a creature: its things are nobody's loot, whatever dead creature is still targeted.
local function BySource()
    if not GetLootSourceInfo then return nil, false end
    local by, any, named = {}, false, false
    for slot = 1, (Compat.Plain(GetNumLootItems()) or 0) do
        local link = Compat.Plain(GetLootSlotLink(slot))
        local name = type(link) == "string" and link:match("%[(.-)%]")
        -- Its sources come in pairs: a corpse's ID, and how many of the thing it had.
        local sources = { GetLootSourceInfo(slot) }
        for i = 1, #sources, 2 do
            local guid = Compat.Plain(sources[i])
            if type(guid) == "string" then named = true end
            if Kind(guid) then
                any = true
                by[guid] = by[guid] or {}
                if name then by[guid][name:lower()] = tonumber(link:match("item:(%d+)")) or true end
            end
        end
    end
    return any and by or nil, named
end

local function Opened()
    if IsFishingLoot and Compat.Plain(IsFishingLoot()) then return end
    local by, named = BySource()
    if by then
        -- Each corpse in the window is a loot of its creature, with what that corpse had.
        local wanted = LootLog.Wanted()
        local targetName, targetGUID = Compat.Name("target"), Compat.GUID("target")
        for guid, found in pairs(by) do
            if not Already(guid) and next(wanted) then
                LootLog.Count(Called(Kind(guid), guid == targetGUID and targetName or nil), wanted, found)
            end
        end
        return
    end
    -- A source was named and it wasn't a creature: a chest, a plant, a thing on the ground. The
    -- dead creature still targeted didn't have what's in it.
    if named then return end
    -- No source given: the dead creature targeted, as one loot.
    local creature, guid = Corpse()
    if not creature then return end
    if guid and Already(guid) then return end
    local wanted = LootLog.Wanted()
    if not next(wanted) then return end
    local found = {}
    for slot = 1, (Compat.Plain(GetNumLootItems()) or 0) do
        local link = Compat.Plain(GetLootSlotLink(slot))
        local name = type(link) == "string" and link:match("%[(.-)%]")
        if name then found[name:lower()] = tonumber(link:match("item:(%d+)")) or true end
    end
    LootLog.Count(creature, wanted, found)
end

function LootLog:OnEnable()
    local events = self.events or CreateFrame("Frame")
    self.events = events
    events:RegisterEvent("LOOT_OPENED")
    events:SetScript("OnEvent", ns.Safe(self, Opened))
end

function LootLog:OnDisable()
    if self.events then self.events:UnregisterAllEvents() end
end

-- /jsal drops: what the log holds, the items with the most tries first.
ns.Command("drops", function()
    local items = {}
    for _, c in pairs(Log().creatures) do
        for name in pairs(type(c) == "table" and type(c.finds) == "table" and c.finds or {}) do items[name] = true end
    end
    local list = {}
    for name in pairs(items) do
        local finds, tries = LootLog.Seen(name)
        list[#list + 1] = { name = name, finds = finds, tries = tries }
    end
    table.sort(list, function(a, b)
        if a.tries ~= b.tries then return a.tries > b.tries end
        return a.name < b.name
    end)
    ns.Print(("Drop log: %s. %d quest item%s seen."):format(LootLog.running and "on" or "off (turn it on under Leveling in /jsal settings)",
        #list, #list == 1 and "" or "s"))
    -- What it has counted and what it's looking for, so "0 seen" says why: an item is listed
    -- only once it has dropped, and "0 quest items seen" alone didn't say whether any loot had
    -- been counted. (John's first /jsal drops, 14 Nov 2026.)
    local loots, kinds = 0, 0
    for _, c in pairs(Log().creatures) do
        if type(c) == "table" then
            loots, kinds = loots + (tonumber(c.n) or 0), kinds + 1
        end
    end
    ns.Print(("  %d loot%s counted, of %d kind%s of creature."):format(loots, loots == 1 and "" or "s", kinds, kinds == 1 and "" or "s"))
    local names = {}
    for _, name in pairs(LootLog.Wanted()) do names[#names + 1] = name end
    table.sort(names)
    if #names == 0 then
        ns.Print("  No quest in your log needs an item right now, so a loot isn't counted.")
    else
        ns.Print("  Your quests still need: " .. table.concat(names, ", ") .. ".")
    end
    for i = 1, math.min(#list, 15) do
        local row = list[i]
        ns.Print(("  %s: %d in %d loots (%d%%)%s"):format(row.name, row.finds, row.tries,
            math.floor(row.finds / row.tries * 100 + 0.5), row.tries < LootLog.FLOOR and ", too few to use yet" or ""))
    end
    if #list > 15 then ns.Print(("  and %d more."):format(#list - 15)) end
end)
