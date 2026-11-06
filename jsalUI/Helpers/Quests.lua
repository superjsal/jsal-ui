-- Quests on autopilot: accepts quests and turns in finished ones when you
-- talk to a quest giver. Holding Shift skips it, a reward choice is left to
-- you, and grey (trivial) quests and quests that cost gold are left alone.
local _, ns = ...
local Compat = ns.Compat

local Quests = ns.NewModule("quests", {
    title = "Quests on autopilot",
    note = "Accepts and turns in quests for you. Hold Shift to do it yourself.",
})

-- Each quest is tried once every few seconds at most, so a quest the game
-- refuses (a full quest log, say) can't loop.
local tried = {}
local function Fresh(key)
    local now = GetTime()
    if tried[key] and now - tried[key] < 5 then return false end
    tried[key] = now
    return true
end

local function Paused()
    return IsShiftKeyDown()
end

local handlers = {}

function handlers.GOSSIP_SHOW()
    for _, quest in ipairs(Compat.GossipActive()) do
        if quest.isComplete and Fresh("done" .. quest.questID) then
            return Compat.GossipTakeActive(quest.questID)
        end
    end
    for _, quest in ipairs(Compat.GossipAvailable()) do
        if not quest.isTrivial and Fresh("new" .. quest.questID) then
            return Compat.GossipTakeAvailable(quest.questID)
        end
    end
end

-- Older quest givers open a greeting list instead of gossip.
function handlers.QUEST_GREETING()
    for i = 1, GetNumActiveQuests() do
        local title, complete = GetActiveTitle(i)
        if complete and Fresh("done" .. tostring(title)) then
            return SelectActiveQuest(i)
        end
    end
    for i = 1, GetNumAvailableQuests() do
        local trivial = GetAvailableQuestInfo and GetAvailableQuestInfo(i)
        if not trivial and Fresh("new" .. tostring(GetAvailableTitle(i))) then
            return SelectAvailableQuest(i)
        end
    end
end

function handlers.QUEST_DETAIL()
    if QuestGetAutoAccept and QuestGetAutoAccept() then return end
    AcceptQuest()
end

function handlers.QUEST_PROGRESS()
    if (GetQuestMoneyToGet and GetQuestMoneyToGet() or 0) > 0 then return end
    if IsQuestCompletable() then CompleteQuest() end
end

function handlers.QUEST_COMPLETE()
    local choices = GetNumQuestChoices()
    if choices <= 1 then GetQuestReward(choices) end
end

function Quests:OnEnable()
    local events = CreateFrame("Frame")
    for event in pairs(handlers) do events:RegisterEvent(event) end
    events:SetScript("OnEvent", ns.Safe(self, function(_, event)
        if Quests.running and not Paused() then handlers[event]() end
    end))
    self.events = events
end

function Quests:OnDisable()
    if self.events then self.events:UnregisterAllEvents() end
end
