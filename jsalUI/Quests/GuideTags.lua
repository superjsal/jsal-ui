-- Quest tags on RestedXP's guide window: beside each step that has you take or do a quest, the
-- quest's tag (its place in a chain, and about how many minutes it will take), for someone who
-- follows the guide's window and keeps the quest tracker hidden.
--
-- The pills are Quest tags' own (QuestTags.MakeTag, Fill and the card), so they read the same
-- here as beside the tracker. They sit left of the window, outside its scrolling list, which
-- hides anything drawn outside it; so each pill is jsal.ui's own frame that follows its step's
-- row: where the window goes, they go, and a pill is out of sight while its row is scrolled
-- away. A step's quest is the one it has you accept; when that one's tag has nothing to say, the
-- first it has you complete whose tag does; a step that only turns one in has no tag, as there's
-- nothing left to decide.
--
-- RestedXP's window is its own: nothing of it is changed, only read. It has two windows. The
-- newer one keeps a row for each step in guideSteps.items, each with its frame and the step's
-- number in the guide; the older one keeps them in RXP.RXPFrame.ScrollChild.framePool, each
-- with its step. The first version read only the older, and in the game said "0 steps in its
-- list" and drew nothing.
local _, ns = ...

local GuideTags = ns.NewModule("guidetags", {
    title = "Quest tags on RestedXP",
    note = "Left of RestedXP's guide window: beside each step that has you take or do a quest, its place in a chain and about how many minutes it will take. For when you follow the guide and keep the quest tracker hidden. Hover a tag for the reasons.",
})
ns.GuideTags = GuideTags

local EDGE = 4            -- between a pill and the window's left edge
local LOOK = 0.2          -- seconds between looks at where the rows are
local FILL = 1            -- seconds between readings of a pill's quest

-- The quests a step is about, in the order their tags are wanted: the first it has you accept,
-- then each it has you complete. Nil for a step with neither.
function GuideTags.QuestsOf(step)
    local accept, doing = nil, {}
    for _, element in ipairs(type(step) == "table" and type(step.elements) == "table" and step.elements or {}) do
        if type(element) == "table" and type(element.questId) == "number" then
            if element.tag == "accept" and not accept then accept = element.questId end
            if element.tag == "complete" then doing[#doing + 1] = element.questId end
        end
    end
    if accept then table.insert(doing, 1, accept) end
    return doing[1] and doing or nil
end

-- Of those, the one whose tag is shown: the first whose tag has something to say, else the first.
-- What a tag says changes as quests are taken, so this is asked again at each reading.
function GuideTags.Pick(list)
    if not list then return nil end
    local Q = ns.QuestTags
    if list[2] and Q then
        for _, quest in ipairs(list) do
            if Q.Says(quest) then return quest end
        end
    end
    return list[1]
end

-- The quest a step's tag is for now.
function GuideTags.QuestOf(step)
    return GuideTags.Pick(GuideTags.QuestsOf(step))
end

local function Usable(frame)
    return type(frame) == "table" and type(frame.GetTop) == "function"
end

-- RestedXP's window that's showing: its frame, the frame its list shows through, the rows as
-- { row = the step's frame, step = the step, index = its number }, and which window it is. Nil
-- when RestedXP isn't running or has no list of steps.
local function Window()
    local rxp = type(RXP) == "table" and RXP or nil
    if not rxp then return nil end
    local list = {}
    -- The newer window.
    local window = _G["RXPV2GuideWindow"]
    local steps = type(window) == "table" and window.guideSteps
    local scroll = type(steps) == "table" and steps.scroll
    if Usable(window and window.frame) and type(scroll) == "table" and Usable(scroll.scrollframe)
        and type(steps.items) == "table" and window.frame:IsVisible() then
        local guide = type(rxp.currentGuide) == "table" and type(rxp.currentGuide.steps) == "table" and rxp.currentGuide.steps or {}
        for _, item in pairs(steps.items) do
            if type(item) == "table" and Usable(item.frame) then
                list[#list + 1] = { row = item.frame, step = guide[item.index], index = item.index }
            end
        end
        return window.frame, scroll.scrollframe, list, "newer"
    end
    -- The older one.
    local frame = rxp.RXPFrame
    if not Usable(frame) then return nil end
    local view, child = frame.ScrollFrame, frame.ScrollChild
    local rows = type(child) == "table" and child.framePool
    if not Usable(view) or type(rows) ~= "table" then return nil end
    for _, row in ipairs(rows) do
        if Usable(row) then list[#list + 1] = { row = row, step = row.step, index = row.index } end
    end
    return frame, view, list, "older"
end

local function Corner(frame, edge)
    local v = edge == "left" and frame:GetLeft() or edge == "top" and frame:GetTop() or frame:GetBottom()
    return v and v * frame:GetEffectiveScale()
end

-- Whether a row's middle is inside the list's view.
local function InView(row, view)
    local top, bottom = Corner(row, "top"), Corner(row, "bottom")
    local vtop, vbottom = Corner(view, "top"), Corner(view, "bottom")
    local middle = top and bottom and (top + bottom) / 2
    return row:IsVisible() and middle and vtop and vbottom and middle <= vtop and middle >= vbottom and true or false
end

local tags = {}           -- [row] = its pill
local quests = setmetatable({}, { __mode = "k" })   -- [step] = its quests (QuestsOf), or false

local function Hide(tag)
    if tag.seen then
        tag.seen = false
        tag:Hide()
    end
end

-- Puts a row's pill left of the window at the row's height, or hides it: the row has no quest,
-- is scrolled out of the list's view, or the window is closed.
local function Place(entry, view, now)
    local row, step = entry.row, entry.step
    local tag = tags[row]
    local list = step and quests[step]
    if step and list == nil then
        list = GuideTags.QuestsOf(step) or false
        quests[step] = list
    end
    if not (list and InView(row, view)) then
        if tag then Hide(tag) end
        return
    end
    local Q = ns.QuestTags
    if not tag then
        tag = Q.MakeTag(UIParent)
        tags[row] = tag
    end
    -- Read again when the row has a new step, comes back into sight, or a second has gone by.
    if tag.list ~= list or not tag.seen or not tag.filled or now - tag.filled >= FILL then
        tag.list, tag.filled = list, now
        Q.Fill(tag, GuideTags.Pick(list))   -- shows the pill, or hides it when the quest has nothing to say
        tag.seen = true
    end
    local left, vleft = Corner(row, "left"), Corner(view, "left")
    local x = left and vleft and math.floor((vleft - left) / tag:GetEffectiveScale() - EDGE + 0.5) or -EDGE
    if x ~= tag.x or row ~= tag.row then
        tag.x, tag.row = x, row
        tag:ClearAllPoints()
        tag:SetPoint("RIGHT", row, "LEFT", x, 0)
    end
end

function GuideTags.HideAll()
    for _, tag in pairs(tags) do Hide(tag) end
end

-- Every row's pill, put where it belongs now.
function GuideTags.Refresh()
    local frame, view, list = Window()
    if not (GuideTags.running and ns.QuestTags and frame and frame:IsVisible()) then
        GuideTags.HideAll()
        return
    end
    local now = GetTime()
    local live = {}
    for _, entry in ipairs(list) do
        live[entry.row] = true
        Place(entry, view, now)
    end
    -- A row RestedXP has let go of keeps no pill.
    for row, tag in pairs(tags) do
        if not live[row] then Hide(tag) end
    end
end

---------------------------------------------------------------------------
-- Starting and stopping.
---------------------------------------------------------------------------
-- How long your fights last is Quest tags' to learn, while it's on. With only this part on,
-- nothing would, and the minutes would stay a guess: so the same count is kept here, and only
-- while Quest tags is off, so no fight is counted twice.
local started

local function OnEvent(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        local inside = IsInInstance()
        local alone = not (inside or IsInGroup())
        started = alone and not (ns.QuestTags and ns.QuestTags.running) and GetTime() or nil
    elseif event == "PLAYER_REGEN_ENABLED" then
        if started and ns.QuestTags and not ns.QuestTags.running then
            ns.QuestTags.AddFight(GetTime() - started)
        end
        started = nil
    end
end

function GuideTags:OnEnable()
    local events = self.events or CreateFrame("Frame")
    self.events = events
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:SetScript("OnEvent", ns.Safe(self, OnEvent))
    local wait = 0
    events:SetScript("OnUpdate", ns.Safe(self, function(_, elapsed)
        wait = wait + elapsed
        if wait < LOOK then return end
        wait = 0
        GuideTags.Refresh()
    end))
end

function GuideTags:OnDisable()
    if self.events then
        self.events:UnregisterAllEvents()
        self.events:SetScript("OnUpdate", nil)
    end
    started = nil
    GuideTags.HideAll()
end

-- /jsal guidetags: what the part sees, step by step, for when a tag is missing. It's for finding a
-- fault, so the part's note doesn't name it and its card has no tag for it: with one, the tag ran
-- under the card's switch. A step with no tag can be right (a quest not taken yet that stands
-- alone has nothing to say), and a look at the window can't tell that from a fault.
ns.Command("guidetags", function()
    local frame, view, list, kind = Window()
    ns.Print(("Quest tags on RestedXP: %s. RestedXP's window: %s."):format(GuideTags.running and "on" or "off (turn it on under Leveling in /jsal settings)",
        not frame and (type(RXP) == "table" and "running, but without a list of steps jsal.ui knows" or "not found")
        or frame:IsVisible() and ("open, the %s kind, %d steps in its list"):format(kind, #list) or "closed"))
    if not (frame and frame:IsVisible()) then return end
    local Q = ns.QuestTags
    table.sort(list, function(a, b) return (tonumber(a.index) or 0) < (tonumber(b.index) or 0) end)
    local seen = 0
    for _, entry in ipairs(list) do
        if InView(entry.row, view) then
            seen = seen + 1
            local list = GuideTags.QuestsOf(entry.step)
            local quest = GuideTags.Pick(list)
            local says = entry.step and "no quest to take or do: no tag" or "jsal.ui couldn't find this step in the guide"
            if quest and Q then
                local any, step, minutes = Q.Says(quest)
                says = ("quest %d: %s"):format(quest, any and ("tag " .. (step or "") .. ((step and minutes) and " " or "") .. (minutes or ""))
                    or "nothing to say, so no tag")
                if quest ~= list[1] then
                    says = says .. (", as quest %d, the first on the step, has nothing to say"):format(list[1])
                end
            elseif quest then
                says = ("quest %d, but Quest tags' own file isn't loaded"):format(quest)
            end
            ns.Print(("  step %s: %s"):format(tostring(entry.index or "?"), says))
        end
    end
    if seen == 0 then ns.Print("  None of its steps is in the list's view, by where their frames are.") end
end)
