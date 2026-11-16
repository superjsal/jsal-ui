-- Quest reward star: when a quest lets you choose a reward, a gold star on
-- the corner of the one the gear plan scores the biggest upgrade for your
-- spec, in the quest window, the quest log and the map. Pointing at a reward
-- that's an upgrade adds a line to its tooltip saying by how much.
--
-- Each reward is scored by the gear plan's own Gear.Better, as the dungeon
-- guide's "+N% for you" is, so a reward and a boss's loot can't disagree. A
-- reward you can't wear, or one no better than what you wear, gets nothing;
-- when no reward is better, no star shows. The game lays rewards out inside
-- QuestInfo_Display (QuestInfo_ShowRewards can't be hooked: its templates
-- hold their own reference to it), so the star is placed after that runs, on
-- a frame of jsal.ui's own over the reward's icon. It sits at the icon's top
-- left: EllesmereUI's money bag for the best-selling reward is at the
-- reward's bottom right, so the two never meet. An item the game hasn't
-- loaded yet is waited for, then the rewards are looked at once more.
local _, ns = ...
local Compat = ns.Compat
local Gear = ns.Gear

local RewardStar = ns.NewModule("rewardstar", {
    title = "Quest reward star",
    -- Something new drawn on the game's own window, so it starts off.
    defaultOn = false,
    note = "When a quest lets you choose a reward, a gold star on the one the Gear plan scores the biggest upgrade for your spec. Point at a reward for how much better it is for you.",
})
ns.RewardStar = RewardStar

local STAR = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1"
local GOLD, GREEN = "|cffe3b04b", "|cff6fcf6f"
-- Looks again as items arrive, up to this many times for one window.
local LOOKS = 8

-- The reward button -> our star over it, and what was found for it.
local stars = setmetatable({}, { __mode = "k" })
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
    local better, share = Gear.Better(id, equipLoc, classID, subclassID)
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
    if #choices < 2 then return nil, false, choices end
    for _, button in ipairs(choices) do
        local id = ItemID(ChoiceItem(button))
        local verdict, share = "wait", nil
        if id then verdict, share = RewardStar.Judge(id) end
        found[button] = { verdict = verdict, share = share }
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

local function Star(button)
    local star = stars[button]
    if star then return star end
    local holder = CreateFrame("Frame", nil, button)
    holder:SetAllPoints()
    holder:SetFrameLevel(button:GetFrameLevel() + 3)
    star = holder:CreateTexture(nil, "OVERLAY")
    star:SetTexture(STAR)
    -- Its middle on the icon's top-left corner; smaller on the map's small rewards.
    local size = (button:GetHeight() or 41) >= 40 and 20 or 16
    star:SetSize(size, size)
    star:SetPoint("CENTER", button.Icon or button, "TOPLEFT", 3, -3)
    stars[button] = star
    return star
end

local function HideAll()
    for _, star in pairs(stars) do star:Hide() end
end

local Look, HookEnter

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
    for _, button in ipairs(choices or {}) do HookEnter(button) end
    if best then Star(best):Show() end
    if waiting and looks < LOOKS then WaitForItems() end
end
RewardStar.Look = Look

-- A fresh window: the items are waited for afresh.
local function Shown()
    looks = 0
    Look()
end

-- The line a reward's tooltip gets: the best, or another that's better.
function RewardStar.Line(button)
    local f = found[button]
    if not (RewardStar.running and f and f.verdict == "better") then return nil end
    local pct = math.floor((f.share or 0) * 100 + 0.5)
    local amount = pct < 1 and "under 1%" or ("+" .. pct .. "%")
    if f.best then
        return ("%s|T%s:0|t Best of these for you: %s (Gear plan)|r"):format(GOLD, STAR, amount)
    end
    return ("%s%s for you (Gear plan)|r"):format(GREEN, amount)
end

local function OnEnter(button)
    if not (button and button.type == "choice") then return end
    local line = RewardStar.Line(button)
    if line and GameTooltip:IsOwned(button) then
        GameTooltip:AddLine(line)
        GameTooltip:Show()
    end
end

-- Each reward button gets the line from a hook on its own OnEnter, once. Forever has no global
-- QuestInfoRewardItemCodeTemplate_OnEnter to hook (the name is only in its XML): hooking it
-- stopped the star turning on at all (John's error, 16 Nov 2026).
local entered = setmetatable({}, { __mode = "k" })
function HookEnter(button)
    if entered[button] or not button.HookScript then return end
    entered[button] = true
    button:HookScript("OnEnter", ns.Safe(RewardStar, OnEnter))
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
    if waiter then waiter:UnregisterAllEvents() end
end
