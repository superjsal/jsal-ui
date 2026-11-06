-- Quests on autopilot: accepts quests and turns in finished ones when you
-- talk to a quest giver. Holding Shift skips it, a reward choice is left to
-- you, and grey (trivial) quests and quests that cost gold are left alone.
-- In a group it leaves taking quests from quest givers to you, so an escort
-- doesn't set off before everyone's ready, unless the player switches that
-- off in Settings; quests a groupmate shares, and joining an escort a
-- groupmate starts, are still taken.
local _, ns = ...
local Compat = ns.Compat

local Quests = ns.NewModule("quests", {
    title = "Quests on autopilot",
    note = "Accepts and turns in quests for you. Hold Shift to do it yourself.",
    options = {
        { key = "grouped", title = "Take quests in a group too", default = false,
          note = "Off: in a group, you accept quests yourself, so an escort waits for everyone." },
    },
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

-- In a group, unless the player chose to take quests in a group too.
local function Grouped()
    if ns.OptionOn("quests", "grouped") then return false end
    return IsInGroup and IsInGroup() or (GetNumGroupMembers and GetNumGroupMembers() > 0)
end

-- Whether the quest window open now is a quest a player shared, not a
-- quest giver's.
local function Shared()
    for _, unit in ipairs({ "questnpc", "npc" }) do
        if UnitExists(unit) then return UnitIsPlayer(unit) end
    end
    return false
end

local handlers = {}

function handlers.GOSSIP_SHOW()
    for _, quest in ipairs(Compat.GossipActive()) do
        if quest.isComplete and Fresh("done" .. quest.questID) then
            return Compat.GossipTakeActive(quest.questID)
        end
    end
    if Grouped() then return end
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
    if Grouped() then return end
    for i = 1, GetNumAvailableQuests() do
        local trivial = GetAvailableQuestInfo and GetAvailableQuestInfo(i)
        if not trivial and Fresh("new" .. tostring(GetAvailableTitle(i))) then
            return SelectAvailableQuest(i)
        end
    end
end

function handlers.QUEST_DETAIL()
    if QuestGetAutoAccept and QuestGetAutoAccept() then return end
    if Grouped() and not Shared() then return end
    AcceptQuest()
end

-- A groupmate started an escort: join it, as the game's own popup asks.
function handlers.QUEST_ACCEPT_CONFIRM()
    if ConfirmAcceptQuest then
        ConfirmAcceptQuest()
        if StaticPopup_Hide then StaticPopup_Hide("QUEST_ACCEPT") end
    end
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
    -- pcall: an event this client doesn't have is an error to register.
    for event in pairs(handlers) do pcall(events.RegisterEvent, events, event) end
    events:SetScript("OnEvent", ns.Safe(self, function(_, event)
        if Quests.running and not Paused() then handlers[event]() end
    end))
    self.events = events
end

function Quests:OnDisable()
    if self.events then self.events:UnregisterAllEvents() end
end
