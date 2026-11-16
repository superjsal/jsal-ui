-- The drop log: how often the creatures you loot have the quest items you're after, counted as
-- you play, so a quest's likely kills can come from Forever itself where nobody else has counted.
-- The numbers anyone has for drop chances are counts of what players saw; past the levels many
-- have played, those counts are thin.
--
-- A loot counts when a corpse's window opens while a quest in your log still needs an item. Each
-- quest item still wanted is then one try for that creature, and one find if the corpse had it.
-- Quest items only drop while a quest needs them, so nothing is counted for an item once its
-- objective is done. A corpse counts once, however often its window is opened.
--
-- Which corpse: the game says where each thing in the window came from (GetLootSourceInfo), so a
-- window opened for several corpses counts each of them, with what that one had. Forever's own
-- code never calls that function and the first version took it to be missing, counting the dead
-- creature targeted and so one loot for a window of several; the game has it. The targeted way
-- is kept for when the game gives no source. A corpse's creature is known by the number in its
-- ID; its name comes from your target when that's the corpse, and is remembered for the others of
-- its kind.
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
    note = "Counts how often the creatures you loot have the quest items you're after, so quest tags can use Forever's own drop chances where few players have been. Quest items only; it stays on your computer unless you share it with your guild. /jsal drops shows what it has.",
    options = {
        -- Sending something of yours to other players, so it's a choice of its own, and off.
        { key = "share", title = "Share drop counts with your guild", default = false,
          note = "Tells guildmates who share theirs how many times each quest item has dropped for you, and adds their counts to yours, so everyone's quest tags learn faster. Only the item's name and two numbers are sent, over the game's hidden addon channel." },
    },
})
ns.LootLog = LootLog

LootLog.FLOOR = 10      -- tries an item needs before its chance is said
local CORPSES = 300     -- corpses remembered as counted, before the oldest are let go
-- Kinds of creature kept, before the one looted longest ago is let go: every kind you loot
-- while a quest wants an item is kept, and nothing ever went.
LootLog.CREATURES = 500
-- An item's finds and tries, kept until a loot changes them: every quest tag asks for each of
-- its items each time it's drawn, and each ask went through every creature kept.
local seenFor, seenIn = {}, nil

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

---------------------------------------------------------------------------
-- Guildmates' counts. With "Share drop counts with your guild" on, each of you tells the others
-- an item's finds and tries (LootLog.Seen's two numbers) when they change, and all of them once
-- on logging in; what's heard is kept apart from your own, by who said it, and the newest word
-- from someone replaces their last, so nothing is counted twice.
---------------------------------------------------------------------------
local SENDERS, ITEMS = 60, 300      -- guildmates kept, and items kept from each
local OLD = 45 * 86400              -- a guildmate not heard from in this long is let go
local MOST = 100000                 -- a count above this isn't believed
local SEND = 40                     -- items told at once, the ones with the most loots

function LootLog.Sharing()
    return LootLog.running and ns.OptionOn("lootlog", "share") and true or false
end

-- The saved guild counts: guild[sender] = { t = when, items = { [lower-case item name] = { finds, tries } } }.
local function Guild()
    local log = Log()
    log.guild = type(log.guild) == "table" and log.guild or {}
    return log.guild
end

-- What a guildmate said of an item. False when it isn't believable.
function LootLog.Heard(sender, itemName, finds, tries, now)
    finds, tries = tonumber(finds), tonumber(tries)
    if type(sender) ~= "string" or sender == "" or type(itemName) ~= "string" then return false end
    if not finds or not tries or finds < 0 or tries < 1 or finds > tries or tries > MOST then return false end
    if #itemName < 1 or #itemName > 80 then return false end
    local guild = Guild()
    local from = guild[sender]
    if type(from) ~= "table" or type(from.items) ~= "table" then
        -- Room for a new voice: the one longest silent goes.
        local count, oldest, oldestAt = 0, nil, nil
        for name, entry in pairs(guild) do
            count = count + 1
            local t = type(entry) == "table" and tonumber(entry.t) or 0
            if not oldestAt or t < oldestAt then oldest, oldestAt = name, t end
        end
        if count >= SENDERS and oldest then guild[oldest] = nil end
        from = { items = {} }
        guild[sender] = from
    end
    from.t = now or 0
    local key = itemName:lower()
    if not from.items[key] then
        local count = 0
        for _ in pairs(from.items) do count = count + 1 end
        if count >= ITEMS then return false end
    end
    from.items[key] = { math.floor(finds), math.floor(tries) }
    return true
end

-- An item's finds and tries among your guildmates, and how many of them have it.
function LootLog.GuildSeen(itemName)
    if type(itemName) ~= "string" then return 0, 0, 0 end
    local key = itemName:lower()
    local finds, tries, people = 0, 0, 0
    for _, from in pairs(Guild()) do
        local said = type(from) == "table" and type(from.items) == "table" and from.items[key]
        if type(said) == "table" and tonumber(said[2]) then
            finds, tries, people = finds + (tonumber(said[1]) or 0), tries + said[2], people + 1
        end
    end
    return finds, tries, people
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
                    -- /jsal drops listed an empty name first.
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
        -- Room for a new kind: past the limit, the one looted longest ago goes.
        local count, oldest, oldestAt = 0, nil, nil
        for name, other in pairs(log.creatures) do
            count = count + 1
            local t = type(other) == "table" and tonumber(other.t) or 0
            if not oldestAt or t < oldestAt then oldest, oldestAt = name, t end
        end
        if count >= LootLog.CREATURES and oldest then log.creatures[oldest] = nil end
        c = { n = 0, tries = {}, finds = {} }
        log.creatures[creature] = c
    end
    c.tries = type(c.tries) == "table" and c.tries or {}
    c.finds = type(c.finds) == "table" and c.finds or {}
    c.n = (tonumber(c.n) or 0) + 1
    c.t = Compat.ServerTime()
    seenFor = {}
    for lower, name in pairs(wanted) do
        c.tries[name] = (c.tries[name] or 0) + 1
        if found[lower] then
            c.finds[name] = (c.finds[name] or 0) + 1
            if type(found[lower]) == "number" then log.ids[name] = found[lower] end
        end
        -- An item this creature has had is one whose count just moved: the guild hears of it.
        if (c.finds[name] or 0) > 0 and LootLog.Changed then LootLog.Changed(name) end
    end
    return true
end

-- An item's finds and tries, among the creatures that have had it. The name in any case.
function LootLog.Seen(itemName)
    if type(itemName) ~= "string" then return 0, 0 end
    local lower = itemName:lower()
    local creatures = Log().creatures
    if seenIn ~= creatures then seenFor, seenIn = {}, creatures end
    local kept = seenFor[lower]
    if kept then return kept[1], kept[2] end
    local finds, tries = 0, 0
    for _, c in pairs(creatures) do
        if type(c) == "table" and type(c.finds) == "table" then
            for name, n in pairs(c.finds) do
                if name:lower() == lower and n > 0 then
                    finds = finds + n
                    tries = tries + ((type(c.tries) == "table" and c.tries[name]) or n)
                end
            end
        end
    end
    seenFor[lower] = { finds, tries }
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

-- Your own count and the chance the addon ships, as one: the shipped chance stands in for
-- WEIGHT loots, and your own are added to them, so yours counts from the first loot and takes
-- over as they add up, with no sudden switch at the floor. On its own, a small count of yours
-- runs high: Satyr Horns read 55% at 11 loots, 47% at 17, and ended at 16 in 48, 33%, and the
-- card had been using each in turn. Returns the chance and how many of your loots are in it;
-- with no shipped chance to blend with, your own alone once it has FLOOR loots; nil while the
-- part is off or you have no loot of the item.
LootLog.WEIGHT = 10
function LootLog.Blended(itemName, shipped)
    if not LootLog.running then return nil end
    local finds, tries = LootLog.Seen(itemName)
    if tries <= 0 then return nil end
    if type(shipped) ~= "number" or shipped <= 0 then
        if tries < LootLog.FLOOR then return nil end
        return finds / tries, tries
    end
    local weight = LootLog.WEIGHT
    return (finds + weight * math.min(shipped, 1)) / (tries + weight), tries
end

-- The same, with your guildmates' counts added to yours while you share: the chance, how many
-- loots are in it, and how many of those are the guild's (0 when you don't share or they have
-- none). This is the one the quest tag card asks.
function LootLog.Pooled(itemName, shipped)
    if not LootLog.running then return nil end
    local finds, tries = LootLog.Seen(itemName)
    local theirs = 0
    if LootLog.Sharing() then
        local f, t = LootLog.GuildSeen(itemName)
        finds, tries, theirs = finds + f, tries + t, t
    end
    if tries <= 0 then return nil end
    if type(shipped) ~= "number" or shipped <= 0 then
        if tries < LootLog.FLOOR then return nil end
        return finds / tries, tries, theirs
    end
    local weight = LootLog.WEIGHT
    return (finds + weight * math.min(shipped, 1)) / (tries + weight), tries, theirs
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
            seenFor = {}
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

---------------------------------------------------------------------------
-- Telling the guild, and hearing it. "DC" is one item: its name, finds and tries. "DQ" asks
-- everyone who shares to say theirs, for someone just logged in.
---------------------------------------------------------------------------
local changed, flushing = {}, false
local lastAnswered

-- Every item of yours with a find, the ones with the most loots first.
local function Mine()
    local items = {}
    for _, c in pairs(Log().creatures) do
        for name, n in pairs(type(c) == "table" and type(c.finds) == "table" and c.finds or {}) do
            if n > 0 then items[name] = true end
        end
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
    return list
end

local function Tell(name, finds, tries)
    if ns.Comms and tries > 0 and not name:find("[;|]") then
        ns.Comms.Send("DC", ("%s;%d;%d"):format(name, finds, tries), "GUILD")
    end
end

function LootLog.TellAll()
    if not (LootLog.Sharing() and IsInGuild()) then return end
    for i, item in ipairs(Mine()) do
        if i > SEND then break end
        Tell(item.name, item.finds, item.tries)
    end
end

-- What changed since the last word, said together a little later, so a run of loots is one
-- message an item and not one a corpse.
local function Flush()
    flushing = false
    if not (LootLog.Sharing() and IsInGuild()) then
        changed = {}
        return
    end
    for name in pairs(changed) do
        local finds, tries = LootLog.Seen(name)
        Tell(name, finds, tries)
    end
    changed = {}
end

function LootLog.Changed(name)
    if not LootLog.Sharing() then return end
    changed[name] = true
    if not flushing then
        flushing = true
        Compat.After(30, ns.Safe(LootLog, Flush))
    end
end

-- Your own word comes back on the guild's channel, under your whole name (Compat.MyName; the
-- game's own name for you is the first name only, and never matched): it was kept as a
-- guildmate's, and your loots counted twice.
local function HeardCount(payload, sender)
    if not LootLog.Sharing() or sender == Compat.MyName() then return end
    local name, finds, tries = (payload or ""):match("^(.-);(%d+);(%d+)$")
    if name then LootLog.Heard(sender, name, finds, tries, Compat.ServerTime()) end
end

local function HeardAsk(_, sender)
    if not LootLog.Sharing() or sender == Compat.MyName() then return end
    -- Once in ten minutes at most, and not all at the same instant as everyone else.
    local now = GetTime()
    if lastAnswered and now - lastAnswered < 600 then return end
    lastAnswered = now
    Compat.After(2 + math.random() * 10, ns.Safe(LootLog, LootLog.TellAll))
end

function LootLog:OnEnable()
    local events = self.events or CreateFrame("Frame")
    self.events = events
    events:RegisterEvent("LOOT_OPENED")
    events:SetScript("OnEvent", ns.Safe(self, Opened))
    -- A guildmate not heard from in a long while is let go.
    local now = Compat.ServerTime()
    for name, from in pairs(Guild()) do
        if type(from) ~= "table" or now - (tonumber(from.t) or 0) > OLD then Guild()[name] = nil end
    end
    if ns.Comms then
        ns.Comms.On("DC", HeardCount)
        ns.Comms.On("DQ", HeardAsk)
        -- A little after logging in: say yours, and ask for theirs.
        Compat.After(20, ns.Safe(self, function()
            if LootLog.Sharing() and IsInGuild() then
                LootLog.TellAll()
                ns.Comms.Send("DQ", "", "GUILD")
            end
        end))
    end
end

function LootLog:OnDisable()
    if self.events then self.events:UnregisterAllEvents() end
    if ns.Comms then
        ns.Comms.On("DC", nil)
        ns.Comms.On("DQ", nil)
    end
    changed = {}
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
    -- been counted.
    local loots, kinds = 0, 0
    for _, c in pairs(Log().creatures) do
        if type(c) == "table" then
            loots, kinds = loots + (tonumber(c.n) or 0), kinds + 1
        end
    end
    ns.Print(("  %d loot%s counted, of %d kind%s of creature."):format(loots, loots == 1 and "" or "s", kinds, kinds == 1 and "" or "s"))
    local people = 0
    for _ in pairs(Guild()) do people = people + 1 end
    ns.Print(LootLog.Sharing() and ("  Sharing with your guild: on. Counts held from %d guildmate%s."):format(people, people == 1 and "" or "s")
        or "  Sharing with your guild: off.")
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
