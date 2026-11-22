-- The Endgame page, for level 60 and what leads to it, in three columns: YOUR SET (where your
-- pre-raid set stands, the next run, your build for 60), RAID NIGHT (WoWSims' consumables for your
-- spec, what's short and what it costs), and RAIDS over COOLDOWNS (every character's). The left
-- column has room under YOUR SET for more cards. Drawn only while it's open: bags are read again
-- after they change, while the page shows.
local _, ns = ...
local Style, Window = ns.Style, ns.Window

local GAP = 16

Window.Page("endgame", function(page)
    local width, height = Window.fullWidth, Window.contentHeight
    local colW = math.floor((width - 2 * GAP) / 3)
    page.colW = colW

    local set = ns.EndgameSet(page, colW)
    set:SetPoint("TOPLEFT", 0, 0)
    local Paint
    local night, parts = ns.EndgameNight(page, colW, function() if Paint then Paint() end end)
    night:SetPoint("TOPLEFT", colW + GAP, 0)
    local column = ns.RaidCards(page, colW)
    page.set, page.night, page.nightParts, page.column = set, night, parts, column

    -- Every character the Journal has seen, the highest first.
    local function Characters()
        local list = {}
        for _, c in pairs(ns.Journal and ns.Journal.Characters() or {}) do list[#list + 1] = c end
        table.sort(list, function(a, b)
            if (a.level or 0) ~= (b.level or 0) then return (a.level or 0) > (b.level or 0) end
            return (a.name or "") < (b.name or "")
        end)
        return list
    end

    Paint = function()
        if ns.Journal and ns.Journal.SaveCharacter then ns.Journal.SaveCharacter() end
        set.Paint()
        ns.RaidNight.Sync()
        ns.EndgameNightPaint(night, parts, height)
        column.Paint(Characters(), 2 * (colW + GAP), 0, height)
    end
    page.Refresh = function() xpcall(Paint, ns.Report) end

    -- Bags read again a moment after they change, while the page shows.
    local events = CreateFrame("Frame")
    local waiting = false
    events:SetScript("OnEvent", function()
        if waiting then return end
        waiting = true
        ns.Compat.After(0.5, function()
            waiting = false
            if page:IsVisible() then page.Refresh() end
        end)
    end)
    page:HookScript("OnShow", function() pcall(events.RegisterEvent, events, "BAG_UPDATE_DELAYED") end)
    page:HookScript("OnHide", function() events:UnregisterAllEvents() end)
    if page:IsVisible() then pcall(events.RegisterEvent, events, "BAG_UPDATE_DELAYED") end
end, nil, true)
