-- Quest reward upgrades: when a quest lets you choose a reward, an upgrade
-- arrow on each one the gear plan scores better than what you wear, in the
-- addon's green, and in gold on the biggest upgrade, in the quest window, the
-- quest log and the map. The best one's tooltip says so in jsal.ui's own
-- section, where every item's tooltip says how much better it is
-- (Gear.TooltipLines asks RewardStar.Best). The gold star stays the Gear plan's
-- mark for a piece you starred: a reward you starred shows it too, at the
-- icon's other top corner.
--
-- Each reward is scored by Gear.ItemShare, the same reading as that section's
-- "better than equipped", so the arrow and the tooltip's number can't disagree. A
-- reward you can't wear, or one no better than what you wear, gets no arrow.
-- The game lays rewards out inside QuestInfo_Display (QuestInfo_ShowRewards
-- can't be hooked: its templates hold their own reference to it), so the marks
-- are placed after that runs, on a frame of jsal.ui's own over the reward's
-- icon. The arrow sits at the icon's top left: EllesmereUI's money bag for the
-- best-selling reward is at the reward's bottom right, so the two never meet.
-- An item the game hasn't loaded yet is waited for, then the rewards are
-- looked at once more.
local _, ns = ...
local Compat = ns.Compat
local Gear = ns.Gear

local RewardStar = ns.NewModule("rewardstar", {
    title = "Quest reward upgrades",
    note = "When a quest lets you choose a reward, an arrow on each one that's better than what you wear, gold on the best. Point at a reward for how much better.",
})
ns.RewardStar = RewardStar

-- The game's own upgrade arrow, the one its bags put on a better piece.
local ARROW = "bags-greenarrow"
-- The same arrow inside a line of text.
RewardStar.ARROW = "|A:" .. ARROW .. ":14:14|a"
-- The Gear plan's star, for a reward you starred there.
local STAR = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1"
-- Looks again as items arrive, up to this many times for one window.
local LOOKS = 8

-- The reward button -> our marks over it, and what was found for it.
local marks = setmetatable({}, { __mode = "k" })
local found = setmetatable({}, { __mode = "k" })
local looks, waiter = 0, nil
-- The rewards still loading, by item: only one of these arriving is worth another look.
local awaited = {}

-- A choice's item: its link, or its ID while the game has no link for it yet.
local function ChoiceItem(button)
    local i = button:GetID()
    if QuestInfoFrame and QuestInfoFrame.questLog then
        return GetQuestLogItemLink("choice", i) or select(6, GetQuestLogChoiceInfo(i))
    end
    return GetQuestItemLink("choice", i) or select(6, GetQuestItemInfo("choice", i))
end

local function ItemID(item)
    if type(item) == "number" then return item end
    return type(item) == "string" and tonumber(item:match("item:(%d+)")) or nil
end

-- How a reward compares with what you wear, by the gear plan: "better" and
-- its share of all you wear's score, "no" (not better, or not for you), or
-- "wait" while the game hasn't loaded it. Things you don't wear are "no".
function RewardStar.Judge(id)
    local _, _, _, equipLoc, _, classID, subclassID = C_Item.GetItemInfoInstant(id)
    if not equipLoc then return "wait" end
    if not Gear.INVTYPE[equipLoc] then return "no" end
    local better, share = Gear.ItemShare(id, equipLoc, classID, subclassID)
    if better == nil then return "wait" end
    if better then return "better", share or 0 end
    return "no"
end

-- The shown choices, each with what the gear plan makes of it, and the best.
-- A quest with one reward to take isn't a choice: nothing is marked.
function RewardStar.Score(buttons)
    local choices, waiting = {}, false
    -- What was found for the last quest's rewards goes: the buttons are reused.
    for button in pairs(found) do found[button] = nil end
    for id in pairs(awaited) do awaited[id] = nil end
    for _, button in ipairs(buttons or {}) do
        if button:IsShown() and button.type == "choice" and button.objectType == "item" then
            choices[#choices + 1] = button
        end
    end
    local best, bestShare
    -- One reward to take: only which item it is, for a star you gave it.
    if #choices < 2 then
        for _, button in ipairs(choices) do found[button] = { id = ItemID(ChoiceItem(button)), verdict = "no" } end
        return nil, false, choices
    end
    for _, button in ipairs(choices) do
        local id = ItemID(ChoiceItem(button))
        local verdict, share = "wait", nil
        if id then verdict, share = RewardStar.Judge(id) end
        found[button] = { id = id, verdict = verdict, share = share }
        if verdict == "wait" then
            waiting = true
            if id then awaited[id] = true end
        elseif verdict == "better" and (not best or share > bestShare) then
            best, bestShare = button, share
        end
    end
    if best then found[best].best = true end
    return best, waiting, choices
end

-- A reward's two marks on one frame of our own: the arrow, its middle on the icon's top-left
-- corner, and your star at the top right. Smaller on the map's small rewards.
local function Marks(button)
    local m = marks[button]
    if m then return m end
    local holder = CreateFrame("Frame", nil, button)
    holder:SetAllPoints()
    holder:SetFrameLevel(button:GetFrameLevel() + 3)
    local size = (button:GetHeight() or 41) >= 40 and 20 or 16
    local icon = button.Icon or button
    local arrow = holder:CreateTexture(nil, "OVERLAY")
    if arrow.SetAtlas then pcall(arrow.SetAtlas, arrow, ARROW) end
    -- The game's arrow is green: made grey, then tinted, it takes the addon's green or gold.
    if arrow.SetDesaturated then arrow:SetDesaturated(true) end
    arrow:SetSize(size, size)
    arrow:SetPoint("CENTER", icon, "TOPLEFT", 3, -3)
    local star = holder:CreateTexture(nil, "OVERLAY")
    star:SetTexture(STAR)
    star:SetSize(size - 4, size - 4)
    star:SetPoint("CENTER", icon, "TOPRIGHT", -3, -3)
    arrow.mark, star.mark = "arrow", "yours"
    m = { holder = holder, arrow = arrow, star = star }
    marks[button] = m
    return m
end

local function Tint(texture, key)
    local Style = ns.Style
    if Style and Style.Color then texture:SetVertexColor(Style.Color(key)) end
end

-- The highest level among the frames under this one, however deep, leaving out `skip`.
local function Top(frame, skip, top)
    for _, child in ipairs({ frame:GetChildren() }) do
        if child ~= skip then
            local level = child:GetFrameLevel()
            if level > top then top = level end
            top = Top(child, skip, top)
        end
    end
    return top
end

-- Another addon may frame a reward's icon with an outline of its own. EllesmereUI's is a frame
-- the button holds with the outline's lines on a frame inside that one, a level higher again:
-- so the marks go above every frame under the button, not only the ones it holds itself. It's
-- looked at each time, since an outline can be added after the marks were made.
local function Raise(m, button)
    m.holder:SetFrameLevel(Top(button, m.holder, button:GetFrameLevel()) + 1)
end

local function HideAll()
    for _, m in pairs(marks) do
        m.arrow:Hide()
        m.star:Hide()
    end
end

local Look

local function WaitForItems()
    if not waiter then
        waiter = CreateFrame("Frame")
        waiter:SetScript("OnEvent", ns.Safe(RewardStar, function(self, _, itemID)
            itemID = Compat.Plain(itemID)
            -- Some other item arriving (a bag's, the gear plan's, another addon's) isn't a
            -- reward's: it's waited through. Each one used up a look, and eight of them in a
            -- burst left the reward unstarred when it came.
            if itemID and not awaited[itemID] then return end
            self:UnregisterAllEvents()
            -- The gear plan keeps an item it asked for marked as loading; this one is in.
            if itemID then Gear.Arrived(itemID) end
            local rewards = QuestInfoFrame and QuestInfoFrame.rewardsFrame
            if rewards and rewards:IsVisible() then Look() end
        end))
    end
    waiter:RegisterEvent("GET_ITEM_INFO_RECEIVED")
end

function Look()
    HideAll()
    if not RewardStar.running then return end
    looks = looks + 1
    local rewards = QuestInfoFrame and QuestInfoFrame.rewardsFrame
    if not (rewards and rewards.RewardButtons) then return end
    local best, waiting, choices = RewardStar.Score(rewards.RewardButtons)
    local starred = Gear.Starred and Gear.Starred() or {}
    for _, button in ipairs(choices or {}) do
        local f = found[button]
        local better = f and f.verdict == "better"
        local yours = f and f.id and starred[f.id] and true or false
        if better or yours then
            local m = Marks(button)
            Raise(m, button)
            if better then
                Tint(m.arrow, button == best and "gold" or "green")
                m.arrow.best = button == best
                m.arrow:Show()
            end
            if yours then m.star:Show() end
        end
    end
    if waiting and looks < LOOKS then WaitForItems() end
end
RewardStar.Look = Look

-- A fresh window: the items are waited for afresh.
local function Shown()
    looks = 0
    Look()
end

-- Whether this tooltip is the best reward's: the game's tooltip, held by the
-- reward button with the gold arrow, showing that reward's item. Read each time
-- the tooltip is built, from what was worked out when the window opened. The
-- game builds a reward's tooltip afresh every moment the pointer rests on it,
-- calling the button's own OnEnter method rather than its script, so a line
-- added from a hook on the script is gone at once; jsal.ui's section is built
-- with the tooltip each time, so the word goes there.
function RewardStar.Best(tooltip, id)
    if not (RewardStar.running and id and tooltip and tooltip == GameTooltip and tooltip.GetOwner) then
        return false
    end
    local f = found[tooltip:GetOwner()]
    return (f and f.best and f.id == id) and true or false
end

local hooked = false
function RewardStar:OnEnable()
    if not hooked then
        hooked = true
        hooksecurefunc("QuestInfo_Display", ns.Safe(self, Shown))
    end
end

function RewardStar:OnDisable()
    HideAll()
    for button in pairs(found) do found[button] = nil end
    if waiter then waiter:UnregisterAllEvents() end
end
