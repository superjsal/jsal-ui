-- jsal.ui's core: saved settings, the module switchboard, the /jsal command
-- and the helpers every other part uses.
local addonName, ns = ...
local Compat = ns.Compat

ns.title = "jsal.ui"
ns.version = Compat.Metadata(addonName, "Version") or "dev"

function ns.Print(...)
    print("|cffe3b04bjsal.ui|r", ...)
end

-- Passes an error to the game's error handler (BugSack, when it's installed)
-- with its stack intact, and hands it back.
local function Report(err)
    geterrorhandler()(err)
    return err
end
ns.Report = Report

-- Saved settings: account-wide in jsalUIDB, per character in jsalUICharDB.
-- Missing keys are filled from these defaults on every load, so a new
-- setting appears without wiping the old ones.
local DEFAULTS = {
    modules = {},  -- module key = false when the player turned it off
    window = {},   -- where the dashboard was last dragged to
    nudged = {},   -- look versions already announced in chat
}
local CHAR_DEFAULTS = {}

local function Fill(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then target[key] = {} end
            Fill(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
    return target
end

-- Work that has to wait until the player leaves combat.
local waiting = {}
function ns.AfterCombat(fn)
    if not Compat.InCombat() then return fn() end
    waiting[#waiting + 1] = fn
end

-- Core parts hook in here: OnLoad runs once the settings exist, OnLogin once
-- the player is in the world.
local onLoad, onLogin = {}, {}
function ns.OnLoad(fn) onLoad[#onLoad + 1] = fn end
function ns.OnLogin(fn) onLogin[#onLogin + 1] = fn end

local function RunAll(list)
    for _, fn in ipairs(list) do
        xpcall(fn, Report)
    end
end

-- Modules: every part beyond the core (the games, the Guild tab, the
-- planners) registers here and starts at login inside a guard. An error
-- turns that one module off for the session and goes to BugSack, so one
-- broken module never takes the rest down.
ns.modules = {}
ns.moduleOrder = {}

function ns.NewModule(key, module)
    module.key = key
    module.title = module.title or key
    ns.modules[key] = module
    ns.moduleOrder[#ns.moduleOrder + 1] = module
    return module
end

function ns.ModuleWanted(module)
    local choice = ns.db.modules[module.key]
    if choice == nil then return module.defaultOn ~= false end
    return choice
end

local function Stop(module, err)
    if module.failed then return end
    module.failed = err
    module.running = false
    if type(module.OnDisable) == "function" then
        pcall(module.OnDisable, module)
    end
    ns.Print(module.title .. " hit an error and turned itself off until the next reload.")
end

-- Wraps a module's event handler or callback in the same guard.
function ns.Safe(module, fn)
    return function(...)
        if module.failed then return end
        local count, args = select("#", ...), { ... }
        local ok, err = xpcall(function() return fn(unpack(args, 1, count)) end, Report)
        if not ok then Stop(module, err) end
    end
end

local function StartModules()
    for _, module in ipairs(ns.moduleOrder) do
        if ns.ModuleWanted(module) and type(module.OnEnable) == "function" then
            local ok, err = xpcall(function() module:OnEnable() end, Report)
            if ok then
                module.running = true
            else
                Stop(module, err)
            end
        end
    end
end

-- How long jsal.ui's own loading took, in milliseconds, for /jsal perf:
-- reading its files, its setup once settings exist, and its start at login.
ns.timings = {}

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        local started = debugprofilestop()
        ns.timings.files = started - (ns.loadStarted or started)
        jsalUIDB = Fill(type(jsalUIDB) == "table" and jsalUIDB or {}, DEFAULTS)
        jsalUICharDB = Fill(type(jsalUICharDB) == "table" and jsalUICharDB or {}, CHAR_DEFAULTS)
        ns.db, ns.char = jsalUIDB, jsalUICharDB
        -- The daily games used to be saved per character. A character's
        -- saved games move to the account once, and only where the
        -- account has none yet.
        for _, key in ipairs({ "word", "wordStats", "icons", "iconBest", "guildGame" }) do
            if ns.char[key] ~= nil then
                if ns.db[key] == nil then ns.db[key] = ns.char[key] end
                ns.char[key] = nil
            end
        end
        RunAll(onLoad)
        ns.timings.setup = debugprofilestop() - started
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        local started = debugprofilestop()
        StartModules()
        RunAll(onLogin)
        ns.timings.login = debugprofilestop() - started
    elseif event == "PLAYER_REGEN_ENABLED" and #waiting > 0 then
        local now = waiting
        waiting = {}
        RunAll(now)
    end
end)

-- /jsal opens the dashboard; a word after it goes to a page or a game.
local commands = {}
function ns.Command(word, fn) commands[word] = fn end

SLASH_JSALUI1 = "/jsal"
SLASH_JSALUI2 = "/jsalui"
SlashCmdList.JSALUI = function(message)
    local command = strtrim(message or ""):lower()
    if command == "" then
        ns.Window.Toggle()
    elseif commands[command] then
        commands[command]()
    elseif command == "version" then
        ns.Print("version " .. ns.version)
    else
        ns.Print("/jsal opens the dashboard. Also: /jsal word, /jsal icons, /jsal guild, /jsal settings, /jsal install.")
    end
end

-- /jsal perf: how long jsal.ui took to load, and, where the game keeps
-- addon timings, the addons that have cost the most since the last reload.
ns.Command("perf", function()
    local t = ns.timings
    ns.Print(("Loading took %.0f ms to read the files, %.0f ms to set up and %.0f ms to start at login.")
        :format(t.files or 0, t.setup or 0, t.login or 0))
    local profiler = C_AddOnProfiler
    local metric = Enum and Enum.AddOnProfilerMetric
    if not (profiler and profiler.GetAddOnMetric and metric and metric.SessionAverageTime) then
        ns.Print("This client doesn't keep timings for each addon.")
        return
    end
    local count = (C_AddOns and C_AddOns.GetNumAddOns or GetNumAddOns)()
    local rows = {}
    for i = 1, count do
        local name = (C_AddOns and C_AddOns.GetAddOnInfo or GetAddOnInfo)(i)
        if name and Compat.IsAddOnLoaded(name) then
            local ok, average = pcall(profiler.GetAddOnMetric, name, metric.SessionAverageTime)
            local _, peak = pcall(profiler.GetAddOnMetric, name, metric.PeakTime)
            if ok and average then rows[#rows + 1] = { name = name, average = average, peak = tonumber(peak) or 0 } end
        end
    end
    table.sort(rows, function(a, b) return a.average > b.average end)
    ns.Print("Average time each frame, and the longest single frame, since the last reload:")
    for i = 1, math.min(10, #rows) do
        local r = rows[i]
        print(("  %s: %.3f ms average, %.1f ms longest"):format(r.name, r.average, r.peak))
    end
end)

for _, page in ipairs({ "home", "install", "games", "guild", "settings" }) do
    ns.Command(page, function() ns.Window.Open(page) end)
end

-- The game's addon menu by the minimap.
function jsalUI_OnCompartmentClick()
    ns.Window.Toggle()
end

function jsalUI_OnCompartmentEnter(_, button)
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    GameTooltip:SetText(ns.title)
    GameTooltip:AddLine("Click to open the dashboard.", 1, 1, 1)
    GameTooltip:Show()
end

function jsalUI_OnCompartmentLeave()
    GameTooltip:Hide()
end
