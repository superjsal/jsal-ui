-- The Endgame page, for level 60 and what leads to it. At 60, three columns: YOUR SET (where your
-- pre-raid set stands, the next run, your build for 60), RAID NIGHT (WoWSims' consumables for your
-- spec, what's short and what it costs), and RAIDS over COOLDOWNS (every character's); the left
-- column has room under YOUR SET for more cards. Below 60 the goal leads: YOUR GOAL AT 60 two columns
-- wide, RAID NIGHT folded to a line under it (Show opens the card), and BUILD FOR 60 over COOLDOWNS at
-- the right; no raids. Everything sits in one scrolling area, for an opened RAID NIGHT below 60. Drawn
-- only while it's open: bags are read again after they change, while the page shows.
local _, ns = ...
local Style, Window = ns.Style, ns.Window

local GAP = 16

Window.Page("endgame", function(page)
    local width, height = Window.fullWidth, Window.contentHeight
    local colW = math.floor((width - 2 * GAP) / 3)
    page.colW = colW

    local scroll, area = Style.Scroller(page, width + 12, height, width, -2, 60)
    scroll:SetPoint("TOPLEFT", 0, 0)
    local set = ns.EndgameSet(area, colW)
    local Paint
    local function Changed() if Paint then Paint() end end
    local night, parts = ns.EndgameNight(area, colW, Changed)
    local column = ns.RaidCards(area, colW)
    -- Below 60's own parts
    local goal = ns.EndgameGoal(area, 2 * colW + GAP)
    local build = ns.EndgameBuild(area, colW)
    local fold = ns.EndgameNightLine(area, 2 * colW + GAP, Changed)
    page.set, page.night, page.nightParts, page.column = set, night, parts, column
    page.goal, page.build, page.fold, page.scroll, page.area = goal, build, fold, scroll, area
    local function At(f, x, y)
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", x, -y)
    end

    -- Every character the Journal has seen, the highest first: this one saved afresh first, as
    -- Pretend gives them.
    local function Characters()
        local known
        if ns.Pretend then
            known = ns.Pretend.Characters()
        else
            if ns.Journal and ns.Journal.SaveCharacter then ns.Journal.SaveCharacter() end
            known = ns.Journal and ns.Journal.Characters() or {}
        end
        local list = {}
        for _, c in pairs(known) do list[#list + 1] = c end
        table.sort(list, function(a, b)
            if (a.level or 0) ~= (b.level or 0) then return (a.level or 0) > (b.level or 0) end
            return (a.name or "") < (b.name or "")
        end)
        return list
    end

    local function AtSixty()
        goal:Hide() build:Hide() fold:Hide()
        set:Show() night:Show()
        At(set, 0, 0)
        set.Paint()
        ns.RaidNight.Sync()
        At(night, colW + GAP, 0)
        ns.EndgameNightPaint(night, parts, height)
        column.Paint(Characters(), 2 * (colW + GAP), 0, height)
        -- At 60 every card keeps within the page: nothing to scroll.
        return 1
    end

    local function BeforeSixty(level)
        set:Hide()
        goal:Show() build:Show()
        At(goal, 0, 0)
        local y = goal.Paint(level) + GAP
        ns.RaidNight.Sync()
        local _, nightList = ns.RaidNight.Spec()
        -- One RAID NIGHT: folded, the line with Show; opened, the card in the line's place, with Hide.
        local open = ns.RaidNight.Saved().open == true and nightList ~= nil
        fold:SetShown(not open)
        night:SetShown(open)
        if open then
            At(night, 0, y)
            y = y + ns.EndgameNightPaint(night, parts, 10000) + GAP
        else
            At(fold, 0, y)
            fold.Paint()
            y = y + fold:GetHeight() + GAP
        end
        At(build, 2 * (colW + GAP), 0)
        local right = build.Paint(level) + GAP
        right = column.Paint(Characters(), 2 * (colW + GAP), right, height - right, true)
        return math.max(y - GAP, right)
    end

    Paint = function()
        for id in pairs(ns.EndgameMissing) do ns.EndgameMissing[id] = nil end
        local level = ns.Pretend and ns.Pretend.Level() or UnitLevel("player") or 1
        local tall = level >= 60 and AtSixty() or BeforeSixty(level)
        area:SetHeight(math.max(1, tall))
    end
    page.Refresh = function() xpcall(Paint, ns.Report) end

    -- Bags read again a moment after they change, while the page shows; and an item whose name the page
    -- drew without (the game hadn't loaded it yet, as after a restart) draws it again when it comes in.
    -- Once for a batch.
    local ITEM_IN = { GET_ITEM_INFO_RECEIVED = true, ITEM_DATA_LOAD_RESULT = true }
    local events = CreateFrame("Frame")
    local waiting = false
    events:SetScript("OnEvent", function(_, event, item)
        item = ns.Compat.Plains(item)
        if ITEM_IN[event] and not (item and ns.EndgameMissing[item]) then return end
        if waiting then return end
        waiting = true
        ns.Compat.After(0.5, function()
            waiting = false
            if page:IsVisible() then page.Refresh() end
        end)
    end)
    local function Listen()
        for _, event in ipairs({ "BAG_UPDATE_DELAYED", "GET_ITEM_INFO_RECEIVED", "ITEM_DATA_LOAD_RESULT" }) do
            pcall(events.RegisterEvent, events, event)
        end
    end
    page:HookScript("OnShow", Listen)
    page:HookScript("OnHide", function() events:UnregisterAllEvents() end)
    if page:IsVisible() then Listen() end
end, nil, true)
