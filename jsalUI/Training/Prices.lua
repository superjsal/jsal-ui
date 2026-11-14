-- Trainer prices. The game's files list every class spell and its level,
-- but prices live on the server and only show at a trainer. So whenever a
-- class trainer opens, its whole list is saved for the account: every spell
-- and rank, the level it needs and its price, including the ones still too
-- high to learn (the trainer's "unavailable" rows).
local _, ns = ...
local Compat = ns.Compat

local Prices = {}
ns.TrainerPrices = Prices

local FILTERS = { "available", "unavailable", "used" }

---------------------------------------------------------------------------
-- How a visit's rows are kept. Every trainer seen is saved for the whole
-- account, some sixty rows each, so a row is one short line of text rather
-- than a table of named fields (a third of the size in the saved file):
--   spell|name|rank|level|cost|kind
-- with nothing between the bars where there's nothing to say, and the kind
-- as a letter: a (available), u (unavailable, level too low), x (learned).
---------------------------------------------------------------------------
local LETTER = { available = "a", unavailable = "u", used = "x" }
local KIND = { a = "available", u = "unavailable", x = "used" }

function Prices.Pack(row)
    local rank, kind = row.rank, row.category
    -- Visits saved before Forever's order was known hold the row's kind
    -- where its rank should be.
    if LETTER[rank] then rank, kind = nil, rank end
    return table.concat({
        row.spell and tostring(row.spell) or "", row.name or "", rank or "",
        tostring(row.level or 0), tostring(row.cost or 0), LETTER[kind] or "",
    }, "|")
end

function Prices.Unpack(text)
    local spell, name, rank, level, cost, kind = text:match("^([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)$")
    if not name then return nil end
    return {
        spell = tonumber(spell), name = name, rank = rank ~= "" and rank or nil,
        level = tonumber(level) or 0, cost = tonumber(cost) or 0, category = KIND[kind],
    }
end

-- A saved visit's rows, each as a table with its fields named. Unpacked
-- once per visit and kept only as long as the visit itself is.
local unpacked = setmetatable({}, { __mode = "k" })
function Prices.RowsOf(visit)
    local saved = type(visit) == "table" and visit.rows
    if type(saved) ~= "table" then return {} end
    local rows = unpacked[saved]
    if not rows then
        rows = {}
        for _, row in ipairs(saved) do
            if type(row) == "string" then row = Prices.Unpack(row) end
            if type(row) == "table" then rows[#rows + 1] = row end
        end
        unpacked[saved] = rows
    end
    return rows
end

-- Visits saved in the older, roomier form are rewritten in this one.
function Prices.Slim()
    local changed = 0
    for _, visit in pairs(type(ns.db.trainers) == "table" and ns.db.trainers or {}) do
        if type(visit) == "table" and type(visit.rows) == "table" then
            local packed, was = {}, false
            for _, row in ipairs(visit.rows) do
                if type(row) == "table" then row, was = Prices.Pack(row), true end
                if type(row) == "string" then packed[#packed + 1] = row end
            end
            if was then visit.rows, changed = packed, changed + 1 end
        end
    end
    return changed
end

-- The spell a trainer row teaches, from the game's tooltip data for it.
local function SpellOf(index)
    if C_TooltipInfo and C_TooltipInfo.GetTrainerService then
        local ok, info = pcall(C_TooltipInfo.GetTrainerService, index)
        if ok and info and info.id then return info.id end
    end
    return nil
end

local function RankOf(spellID)
    local text = spellID and C_Spell and C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(spellID)
    return text and text ~= "" and text or nil
end

local function Rows()
    local rows, highest = {}, 0
    for i = 1, GetNumTrainerServices() do
        local name, category, rank = Compat.TrainerService(i)
        local spell = SpellOf(i)
        rank = rank or RankOf(spell)
        if name and category ~= "header" then
            local level = GetTrainerServiceLevelReq and GetTrainerServiceLevelReq(i) or 0
            -- category: "available", "unavailable" (level too low) or "used" (learned).
            rows[#rows + 1] = {
                spell = spell, name = name, rank = rank ~= "" and rank or nil,
                level = level, cost = GetTrainerServiceCost(i) or 0, category = category,
            }
            highest = math.max(highest, level or 0)
        end
    end
    return rows, highest
end

-- Runs fn with the trainer's filters set as asked ({ available = true },
-- say), then always puts the player's own choices back, even if fn went
-- wrong. Only a filter that isn't already as asked is touched, and only
-- that one is put back: each change makes the game redraw its list, so a
-- filter that's already right is left alone. The game takes the on/off as
-- true or false. Returns pcall's results.
function Prices.WithFilters(want, fn)
    local was = {}
    for _, kind in ipairs(FILTERS) do
        local on = want[kind]
        if on ~= nil then
            local now = GetTrainerServiceTypeFilter(kind) and true or false
            if now ~= on then
                was[kind] = now
                SetTrainerServiceTypeFilter(kind, on)
            end
        end
    end
    local ok, a, b = pcall(fn)
    for _, kind in ipairs(FILTERS) do
        if was[kind] ~= nil then SetTrainerServiceTypeFilter(kind, was[kind]) end
    end
    return ok, a, b
end

-- Reads every row, which needs all three filters on.
local ALL = { available = true, unavailable = true, used = true }
local function ReadTrainer()
    local ok, rows, highest = Prices.WithFilters(ALL, Rows)
    if not ok then error(rows, 0) end
    return rows, highest
end

-- A hunter's Beast Training list, saved for this character: each pet
-- ability by name and rank, the pet level it needs and its cost in training
-- points. Anything not listed is still to be learned by taming.
local function SaveBeastTraining(rows)
    local list = {}
    for _, row in ipairs(rows) do
        list[row.name .. "|" .. (row.rank or "")] = { points = row.cost, level = row.level, kind = row.category }
    end
    if next(list) then ns.char.beastTraining = { seen = Compat.ServerTime(), rows = list } end
end

-- A visit is saved per trainer and class: a weapon master shows each class
-- the weapons it can learn, so one class's visit doesn't replace another's.
local function Key()
    local _, classFile = UnitClass("player")
    return ("%s @ %s (%s)"):format(Compat.Name("npc") or "?", GetZoneText() or "?", classFile or "?")
end

-- The visit saved for the trainer in front of you, if there is one.
function Prices.Here()
    local visit = type(ns.db.trainers) == "table" and ns.db.trainers[Key()] or nil
    return type(visit) == "table" and visit or nil
end

local function Record()
    if not (GetNumTrainerServices and GetTrainerServiceTypeFilter) then return end
    if IsTradeskillTrainer and IsTradeskillTrainer() then return end
    local rows, highest = ReadTrainer()
    if #rows == 0 then return end
    local _, classFile, classID = UnitClass("player")
    ns.db.trainers = type(ns.db.trainers) == "table" and ns.db.trainers or {}
    -- Beast Training opens in this same window, with no one on the other
    -- side. Visits saved that way before are dropped.
    if not UnitExists("npc") then
        for key in pairs(ns.db.trainers) do
            if key:find("^%? @ ") then ns.db.trainers[key] = nil end
        end
        if classFile == "HUNTER" then SaveBeastTraining(rows) end
        return
    end
    -- The rows the trainer marks as learned, kept for this character: the
    -- trainer's own word that you know them, whatever the spell's ID.
    ns.char.trainedSpells = type(ns.char.trainedSpells) == "table" and ns.char.trainedSpells or {}
    for _, row in ipairs(rows) do
        if row.category == "used" then
            if row.spell then ns.char.trainedSpells[row.spell] = true end
            ns.char.trainedSpells[row.name .. "|" .. (row.rank or "")] = true
        end
    end
    local npc, zone = Compat.Name("npc") or "?", GetZoneText() or "?"
    local key = Key()
    -- The window can open several times in one visit; it's only news when
    -- the list has changed.
    local before = ns.db.trainers[key]
    local same = type(before) == "table" and type(before.rows) == "table" and #before.rows == #rows and before.highest == highest
    local packed = {}
    for i, row in ipairs(rows) do packed[i] = Prices.Pack(row) end
    -- Where the trainer stands, for a map pin: the player is next to them.
    local map, x, y = Compat.PlayerPosition()
    ns.db.trainers[key] = {
        class = classID, classFile = classFile, npc = npc, zone = zone, map = map, x = x, y = y,
        build = (select(2, GetBuildInfo())), seen = Compat.ServerTime(), highest = highest, rows = packed,
    }
    if not same then
        ns.Print(("Saved %d spells and prices from %s in %s, up to level %d."):format(#rows, npc, zone, highest))
    end
end

-- A warlock's demon trainer sells Grimoires, books that teach a demon an
-- ability, from a vendor window. Their names say what they teach
-- ("Grimoire of Firebolt (Rank 2)"), so the list and prices are saved too.
local function RecordGrimoires()
    local _, classFile, classID = UnitClass("player")
    if classFile ~= "WARLOCK" then return end
    local books = {}
    for i = 1, Compat.MerchantCount() do
        local name, price = Compat.MerchantItem(i)
        if name and name:find("^Grimoire of ") then
            books[#books + 1] = { name = name, cost = price or 0 }
        end
    end
    if #books == 0 then return end
    ns.db.grimoires = type(ns.db.grimoires) == "table" and ns.db.grimoires or {}
    local npc, zone = Compat.Name("npc") or "?", GetZoneText() or "?"
    ns.db.grimoires[npc .. " @ " .. zone] = {
        class = classID, npc = npc, zone = zone, seen = Compat.ServerTime(), rows = books,
    }
    ns.Print(("Saved %d Grimoires and prices from %s in %s."):format(#books, npc, zone))
end

-- A hunter's Beast Training window lists the pet abilities the hunter can
-- teach, each with the pet level it needs and its cost in training points.
-- What's listed is saved for this character; anything not listed is still
-- to be learned by taming a beast that has it.
local function RecordBeastTraining()
    local _, classFile = UnitClass("player")
    if classFile ~= "HUNTER" or not (GetNumCrafts and GetCraftInfo) then return end
    local beastTraining = Compat.SpellInfo(5149)
    if GetCraftDisplaySkillLine and GetCraftDisplaySkillLine() ~= beastTraining then return end
    local rows = {}
    for i = 1, GetNumCrafts() do
        local name, rank, kind, _, _, points, level = GetCraftInfo(i)
        if name and kind ~= "header" then
            rows[#rows + 1] = { name = name, rank = rank ~= "" and rank or nil, cost = points, level = level, category = kind }
        end
    end
    SaveBeastTraining(rows)
end

local events = CreateFrame("Frame")
events:RegisterEvent("TRAINER_SHOW")
events:RegisterEvent("MERCHANT_SHOW")
events:RegisterEvent("PLAYER_LOGIN")
-- Not every client has the Beast Training window, and registering an event
-- the client doesn't know is an error.
pcall(events.RegisterEvent, events, "CRAFT_SHOW")
local RECORD = { TRAINER_SHOW = Record, MERCHANT_SHOW = RecordGrimoires, CRAFT_SHOW = RecordBeastTraining }
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        xpcall(Prices.Slim, ns.Report)
        return
    end
    -- The list fills in a moment after the window opens.
    Compat.After(0.3, function()
        xpcall(RECORD[event], ns.Report)
        -- The Training panel painted before this was saved; it paints again.
        if Prices.OnSaved then xpcall(Prices.OnSaved, ns.Report) end
    end)
end)
