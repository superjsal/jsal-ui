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

local function Rows()
    local rows, highest = {}, 0
    for i = 1, GetNumTrainerServices() do
        local name, rank, category = GetTrainerServiceInfo(i)
        if name and category ~= "header" then
            local level = GetTrainerServiceLevelReq and GetTrainerServiceLevelReq(i) or 0
            rows[#rows + 1] = {
                spell = SpellOf(i), name = name, rank = rank ~= "" and rank or nil,
                level = level, cost = GetTrainerServiceCost(i) or 0,
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

local function Record()
    if not (GetNumTrainerServices and GetTrainerServiceTypeFilter) then return end
    if IsTradeskillTrainer and IsTradeskillTrainer() then return end
    local rows, highest = ReadTrainer()
    if #rows == 0 then return end
    local _, classFile, classID = UnitClass("player")
    ns.db.trainers = type(ns.db.trainers) == "table" and ns.db.trainers or {}
    -- Saved per trainer and class: a weapon master shows each class the
    -- weapons it can learn, so one class's visit doesn't replace another's.
    local npc, zone = UnitName("npc") or "?", GetZoneText() or "?"
    local key = ("%s @ %s (%s)"):format(npc, zone, classFile or "?")
    ns.db.trainers[key] = {
        class = classID, classFile = classFile, npc = npc, zone = zone,
        build = (select(2, GetBuildInfo())), seen = Compat.ServerTime(), highest = highest, rows = rows,
    }
    ns.Print(("Saved %d spells and prices from %s in %s, up to level %d."):format(#rows, npc, zone, highest))
end

local events = CreateFrame("Frame")
events:RegisterEvent("TRAINER_SHOW")
events:SetScript("OnEvent", function()
    -- The list fills in a moment after the window opens.
    Compat.After(0.3, function() xpcall(Record, ns.Report) end)
end)
