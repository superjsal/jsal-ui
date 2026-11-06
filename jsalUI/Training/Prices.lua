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

-- Reads every row with all three filters on, then always puts the player's
-- own filter choices back, even if reading went wrong. The game takes the
-- on/off as true or false.
local function ReadTrainer()
    local saved = {}
    for _, kind in ipairs(FILTERS) do
        saved[kind] = GetTrainerServiceTypeFilter(kind) and true or false
        SetTrainerServiceTypeFilter(kind, true)
    end
    local ok, rows, highest = pcall(Rows)
    for _, kind in ipairs(FILTERS) do
        SetTrainerServiceTypeFilter(kind, saved[kind])
    end
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
    -- Saved per trainer and class: a weapon master shows each class the
    -- weapons it can learn, so one class's visit doesn't replace another's.
    local npc, zone = UnitName("npc") or "?", GetZoneText() or "?"
    local key = ("%s @ %s (%s)"):format(npc, zone, classFile or "?")
    -- The window can open several times in one visit; it's only news when
    -- the list has changed.
    local before = ns.db.trainers[key]
    local same = type(before) == "table" and type(before.rows) == "table" and #before.rows == #rows and before.highest == highest
    -- Where the trainer stands, for a map pin: the player is next to them.
    local map, x, y = Compat.PlayerPosition()
    ns.db.trainers[key] = {
        class = classID, classFile = classFile, npc = npc, zone = zone, map = map, x = x, y = y,
        build = (select(2, GetBuildInfo())), seen = Compat.ServerTime(), highest = highest, rows = rows,
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
    local npc, zone = UnitName("npc") or "?", GetZoneText() or "?"
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
-- Not every client has the Beast Training window, and registering an event
-- the client doesn't know is an error.
pcall(events.RegisterEvent, events, "CRAFT_SHOW")
local RECORD = { TRAINER_SHOW = Record, MERCHANT_SHOW = RecordGrimoires, CRAFT_SHOW = RecordBeastTraining }
events:SetScript("OnEvent", function(_, event)
    -- The list fills in a moment after the window opens.
    Compat.After(0.3, function()
        xpcall(RECORD[event], ns.Report)
    end)
end)
