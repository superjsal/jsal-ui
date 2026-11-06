-- Level-up helper: on each new level, a chat line with what's waiting (talent
-- points, new ranks at the class trainer), and at a trainer, how many things
-- you can learn there now and what they cost together.
local _, ns = ...
local Compat = ns.Compat

local LevelUp = ns.NewModule("levelup", {
    title = "Level-up helper",
    note = "What's new on each level, and what a trainer has for you.",
})

local function TalentPoints()
    local ok, points = pcall(Compat.UnspentTalentPoints)
    return ok and points or 0
end

local function PointsLine(points)
    return ("%d talent point%s to spend."):format(points, points == 1 and "" or "s")
end

-- Class trainers have new ranks on even levels.
local function OnLevel(level)
    local parts = { ("Level %d!"):format(level) }
    local points = TalentPoints()
    -- When the talent helper will name the next talent, it says this instead.
    local covered = ns.TalentHelper and ns.TalentHelper.Covers()
    if points > 0 and not covered then parts[#parts + 1] = PointsLine(points) end
    if level % 2 == 0 then parts[#parts + 1] = "Your class trainer has new ranks for you." end
    ns.Print(table.concat(parts, " "))
end

local function OnTrainer()
    if not (GetNumTrainerServices and GetTrainerServiceInfo and GetTrainerServiceCost) then return end
    local count, cost = 0, 0
    for i = 1, GetNumTrainerServices() do
        local _, category = Compat.TrainerService(i)
        if category == "available" then
            count = count + 1
            cost = cost + (GetTrainerServiceCost(i) or 0)
        end
    end
    if count > 0 then
        ns.Print(("You can learn %d thing%s here now, for %s in all."):format(
            count, count == 1 and "" or "s", Compat.Money(cost)))
    end
end

function LevelUp:OnEnable()
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_LEVEL_UP")
    events:RegisterEvent("TRAINER_SHOW")
    events:RegisterEvent("TRAINER_CLOSED")
    -- The trainer window can open several times in one visit; its line
    -- shows once a visit.
    local told = false
    events:SetScript("OnEvent", ns.Safe(self, function(_, event, level)
        if not LevelUp.running then return end
        if event == "PLAYER_LEVEL_UP" then
            -- The new talent point lands a moment after the level.
            Compat.After(2, function() OnLevel(level) end)
        elseif event == "TRAINER_CLOSED" then
            told = false
        elseif not told and UnitExists("npc") then
            told = true
            OnTrainer()
        end
    end))
    self.events = events

    -- A reminder at login when points are waiting.
    Compat.After(6, function()
        local points = TalentPoints()
        local covered = ns.TalentHelper and ns.TalentHelper.Covers()
        if LevelUp.running and points > 0 and not covered then ns.Print("You have " .. PointsLine(points)) end
    end)
end

function LevelUp:OnDisable()
    if self.events then self.events:UnregisterAllEvents() end
end
