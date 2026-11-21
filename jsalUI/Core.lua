-- jsal.ui's core: saved settings, the module switchboard, the /jsal command
-- and the helpers every other part uses.
local addonName, ns = ...
local Compat = ns.Compat

ns.title = "jsal.ui"

-- A version's numbers and, for a beta ("0.3.14-beta.2"), its beta number.
local function Parts(v)
    v = tostring(v or "")
    local main, beta = v:match("^([%d%.]+)%-beta%.?(%d*)$")
    if not main then main = v:match("^([%d%.]+)") or "" end
    local nums = {}
    for n in main:gmatch("%d+") do nums[#nums + 1] = tonumber(n) end
    return nums, beta and (tonumber(beta) or 0) or nil
end

-- Whether a version is a beta.
function ns.IsBeta(v)
    local _, beta = Parts(v)
    return beta ~= nil
end

-- Whether version a ("0.3.1", "0.3.14-beta.2") is newer than version b, part
-- by part; a version's betas come before it ("0.3.14-beta.2" before "0.3.14").
function ns.Newer(a, b)
    local na, ba = Parts(a)
    local nb, bb = Parts(b)
    for i = 1, math.max(#na, #nb) do
        local x, y = na[i] or 0, nb[i] or 0
        if x ~= y then return x > y end
    end
    if ba == bb then return false end
    if not ba then return true end
    if not bb then return false end
    return ba > bb
end

-- The game reads an addon's list of files, and its version, only when it
-- starts; a /reload reloads the code but not the list. So each release
-- sets the version its code is, and the last version that added files.
-- After an update and a /reload, code newer than the version the game
-- started with means an update came in: a /reload was enough unless it
-- added files since, which load only after a restart.
ns.codeVersion = "0.3.61-beta.1"
ns.restartSince = "0.3.59"
ns.startedVersion = Compat.Metadata(addonName, "Version") or ns.codeVersion
ns.needsRestart = ns.Newer(ns.restartSince, ns.startedVersion)
ns.version = (not ns.needsRestart and ns.Newer(ns.codeVersion, ns.startedVersion)) and ns.codeVersion or ns.startedVersion

function ns.Print(...)
    print("|cffe3b04bjsal.ui|r", ...)
end

-- Passes an error to the game's error handler (BugSack, when it's installed)
-- with its stack intact, and hands it back. It's kept for problem reports
-- first (Errors.lua), and not counted again as the game's handler sees it.
local function Report(err)
    ns.lastError = tostring(err):match("^[^\n]*")
    local errors = ns.Errors
    if errors then pcall(errors.Record, err, true) end
    if errors then errors.passing = true end
    pcall(geterrorhandler(), err)
    if errors then errors.passing = false end
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

-- Every part is switched on once, whatever was saved, for a player who hasn't
-- seen the welcome: the welcome that follows is where they turn off what they
-- don't want, with every part in front of them. It's marked, so a part
-- switched off after that stays off; and a player who has been through the
-- welcome keeps the switches they left it with.
local function AllOnOnce(db)
    if db.allOn then return end
    if not (type(db.setup) == "table" and db.setup.welcome) then
        for key, on in pairs(db.modules) do
            if on == false then db.modules[key] = nil end
        end
    end
    db.allOn = true
end

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

-- Parts put away for now. A shelved part's files stop at their first line,
-- so it's as if it weren't there: no switch in Settings, no entry in the
-- menu, no command, and a line that would name it leaves it out. Its code
-- and what it saved are untouched: take its name off this list and it's
-- back whole.
ns.SHELVED = { chess = true }
function ns.Shelved(key) return ns.SHELVED[key] == true end

-- On a beta, what jsal.ui's memory goes on, for /jsal mem: how much the
-- game's Lua held as each part's file was read, and how much each part's
-- start added. Nothing else of the game's runs between two of jsal.ui's own
-- files or inside a part's start, so the growth there is jsal.ui's.
local mem = ns.IsBeta(ns.version) and { marks = {}, starts = {} } or nil

function ns.NewModule(key, module)
    module.key = key
    module.title = module.title or key
    ns.modules[key] = module
    ns.moduleOrder[#ns.moduleOrder + 1] = module
    if mem then mem.marks[#mem.marks + 1] = { module.title, collectgarbage("count") } end
    return module
end

function ns.ModuleWanted(module)
    local choice = ns.db.modules[module.key]
    if choice == nil then return module.defaultOn ~= false end
    return choice
end

-- A module's own on/off options (module.options: { key, title, note,
-- default }), shown under its switch in Settings. They apply at once.
local function OptionDefault(moduleKey, key)
    local module = ns.modules[moduleKey]
    for _, option in ipairs(module and module.options or {}) do
        if option.key == key then return option.default and true or false end
    end
    return false
end

function ns.OptionOn(moduleKey, key)
    -- Nil while nothing is saved for it. Read with `and`, a player who had never changed an
    -- option got false here, not nil, and every option that starts on read as off: the quick
    -- bar's buttons, the level-up screenshot, the recap, the profession window's extras.
    local saved
    if type(ns.db.options) == "table" then saved = ns.db.options[moduleKey .. "." .. key] end
    if saved == nil then return OptionDefault(moduleKey, key) end
    return saved
end

function ns.SetOption(moduleKey, key, on)
    ns.db.options = type(ns.db.options) == "table" and ns.db.options or {}
    ns.db.options[moduleKey .. "." .. key] = on and true or false
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

-- jsal.ui's slow moments since the last reload: anything that took 10 ms or
-- more, by what it was, for /jsal perf: without it there's no way to tell
-- which part a slow frame came from.
local SLOW_MS = 10
local slow = {}
local function NoteSlow(label, took)
    local s = slow[label]
    if not s then
        s = { count = 0, worst = 0, total = 0 }
        slow[label] = s
    end
    s.count, s.total = s.count + 1, s.total + took
    if took > s.worst then s.worst = took end
end

-- Notes what started at `started` (a debugprofilestop() reading) if it was slow.
function ns.Timed(label, started)
    local took = debugprofilestop() - started
    if took >= SLOW_MS then NoteSlow(label, took) end
end

-- Notes a time however short: the parts of something ns.Timed found slow.
ns.NoteTime = NoteSlow

-- Wraps a module's event handler or callback in the same guard, and notes a
-- slow call by the module and, for an event, the event's name. The arguments
-- go straight to xpcall, which takes them in the game (Blizzard's own code
-- calls it so): a table and a function made on every call came to about 230
-- bytes, and the throttled OnUpdates come through here every frame.
function ns.Safe(module, fn)
    return function(...)
        if module.failed then return end
        local started = debugprofilestop()
        local ok, err = xpcall(fn, Report, ...)
        if not ok then Stop(module, err) end
        local took = debugprofilestop() - started
        if took >= SLOW_MS then
            local name, event = module.title or module.key or "jsal.ui", select(2, ...)
            NoteSlow(type(event) == "string" and event:find("^[%u_]+$") and (name .. ", " .. event) or name, took)
        end
    end
end

local function PrintSlow()
    local rows = {}
    for label, s in pairs(slow) do rows[#rows + 1] = { label = label, count = s.count, worst = s.worst, total = s.total } end
    if #rows == 0 then
        ns.Print("Nothing in jsal.ui has taken 10 ms or more since the last reload.")
        return
    end
    table.sort(rows, function(a, b) return a.worst > b.worst end)
    ns.Print("jsal.ui's slow moments since the last reload, 10 ms or more, the slowest first:")
    for i = 1, math.min(14, #rows) do
        local r = rows[i]
        print(("  %s: %d time%s, average %.0f ms, longest %.0f ms")
            :format(r.label, r.count, r.count == 1 and "" or "s", r.total / r.count, r.worst))
    end
end

local function StartModules()
    for _, module in ipairs(ns.moduleOrder) do
        -- Whether it was switched on as the game loaded: Settings compares
        -- its switch with this, to say which changes wait for a reload.
        module.wantedAtStart = ns.ModuleWanted(module)
        if ns.ModuleWanted(module) and type(module.OnEnable) == "function" then
            -- A measured start (/jsal mem asked for it before this reload)
            -- clears the leftovers either side of each part, so what's left
            -- is what the part holds. It makes the start slow, once.
            local before
            if mem then
                if mem.exact then collectgarbage("collect") end
                before = collectgarbage("count")
            end
            local ok, err = xpcall(function() module:OnEnable() end, Report)
            if mem then
                if mem.exact then collectgarbage("collect") end
                mem.starts[#mem.starts + 1] = { module.title or module.key, collectgarbage("count") - before }
            end
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
        AllOnOnce(jsalUIDB)
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
        -- Daily Word and the Guild Word start fresh once, with the first
        -- version past 0.2.0 (the first the guild plays), so games played to
        -- try it out, and a Guild Word set to test it, don't carry over:
        -- today's game, the Daily Word record, and the saved and played Guild
        -- Word.
        if not ns.db.wordsFresh and ns.version ~= "0.2.0" then
            for _, key in ipairs({ "word", "wordStats", "guildGame", "guildWords" }) do ns.db[key] = nil end
            ns.db.wordsFresh = true
        end
        -- The daily puzzles count from one day later than they first did,
        -- with the same word and round each day; today's Daily Word and Icon
        -- Guess, if saved under the old (one higher) number, move down too,
        -- so neither can be played twice.
        if not ns.db.renumbered then
            for _, key in ipairs({ "word", "icons" }) do
                local game = ns.db[key]
                if type(game) == "table" and type(game.day) == "number" then game.day = game.day - 1 end
            end
            ns.db.renumbered = true
        end
        if mem then mem.files = collectgarbage("count") end
        RunAll(onLoad)
        ns.timings.setup = debugprofilestop() - started
        if mem then
            mem.setup = collectgarbage("count")
            mem.exact, ns.db.memNext = ns.db.memNext == true, nil
        end
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        local started = debugprofilestop()
        if mem then mem.login = collectgarbage("count") end
        StartModules()
        RunAll(onLogin)
        ns.timings.login = debugprofilestop() - started
        if mem then mem.started = collectgarbage("count") end
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
        -- A command is named only while it has somewhere to go: chess while it isn't
        -- put away, install in a version with a look to install.
        local look = ns.Installer and ns.Installer.HasProfile and ns.Installer.HasProfile()
        ns.Print(("/jsal opens the dashboard. Also: /jsal word, /jsal icons, %s/jsal shop, /jsal games, /jsal versions, /jsal settings, %s/jsal bug, /jsal discord.")
            :format(commands.chess and "/jsal chess, " or "", look and "/jsal install, " or ""))
    end
end

-- /jsal mem, on a beta: what jsal.ui's memory goes on. The first time it
-- asks for a reload, since a measured start is slow and isn't every start;
-- after that reload it says what jsal.ui holds now, and where it went.
if mem then
    local function MB(kb) return ("%.1f MB"):format((kb or 0) / 1024) end
    local function Most(rows, limit)
        table.sort(rows, function(a, b) return a[2] > b[2] end)
        for i = 1, math.min(limit, #rows) do
            if rows[i][2] < 100 then break end
            print(("  %s: %s"):format(rows[i][1], MB(rows[i][2])))
        end
    end
    -- What one table keeps, in KB: the game's Lua is cleaned up, the table is
    -- copied, it's cleaned up again, and what it grew by is the table's size
    -- (with its words added, which a copy shares and so doesn't count).
    -- Functions and the game's own frames aren't followed, nor the tables in
    -- `stop`: jsal.ui's other parts, each weighed on its own.
    local function Walk(root, stop, copying)
        local seen, words, count = {}, 0, 0
        local function Word(s)
            if not seen[s] then seen[s] = true; words = words + #s + 25 end
        end
        local function Copy(t)
            if seen[t] then return seen[t] end
            local out = copying and {} or true
            seen[t] = out
            count = count + 1
            for k, v in pairs(t) do
                count = count + 1
                if type(k) == "string" then Word(k) end
                local kind = type(v)
                if kind == "string" then
                    Word(v)
                    if copying then out[k] = v end
                elseif kind == "table" then
                    if not stop[v] and type(rawget(v, 0)) ~= "userdata" then
                        local inner = Copy(v)
                        if copying then out[k] = inner end
                    end
                elseif copying and (kind == "number" or kind == "boolean") then
                    out[k] = v
                end
            end
            return out
        end
        local copy = Copy(root)
        seen = nil
        return copy, words, count
    end
    local function Weigh(root, stop)
        collectgarbage("collect")
        local before = collectgarbage("count")
        local copy, words = Walk(root, stop, true)
        collectgarbage("collect")
        local kb = collectgarbage("count") - before + words / 1024
        copy = nil
        return kb
    end
    -- The largest of a table's own tables, weighed: first counted, which is
    -- quick, so that only the few largest are copied.
    local function Largest(owner, skip, limit)
        local stop, found = { [ns] = true, [_G] = true }, {}
        for _, v in pairs(ns) do if type(v) == "table" then stop[v] = true end end
        for key, v in pairs(owner) do
            if type(v) == "table" and not skip[key] and type(rawget(v, 0)) ~= "userdata" then
                stop[v] = nil
                local ok, _, words, count = pcall(Walk, v, stop, false)
                stop[v] = owner == ns or nil
                if ok then found[#found + 1] = { tostring(key), count * 40 + words, v } end
            end
        end
        table.sort(found, function(a, b) return a[2] > b[2] end)
        local rows = {}
        for i = 1, math.min(limit, #found) do
            local v = found[i][3]
            stop[v] = nil
            local ok, kb = pcall(Weigh, v, stop)
            stop[v] = owner == ns or nil
            if ok then rows[#rows + 1] = { found[i][1], kb } end
        end
        return rows
    end
    local function Tables()
        ns.Print("The largest things jsal.ui keeps, each copied and weighed (this takes a few seconds):")
        Most(Largest(ns, { db = true, char = true }, 14), 14)
        ns.Print("And of what's saved for your account:")
        Most(Largest(ns.db or {}, {}, 8), 8)
    end

    ns.Command("mem", function()
        if not mem.exact then
            ns.db.memNext = true
            Tables()
            ns.Print("For where the rest goes, type /reload, then /jsal mem again: the next start is measured part by part. It starts slower, that once.")
            return
        end
        collectgarbage("collect")
        local now
        if UpdateAddOnMemoryUsage and GetAddOnMemoryUsage then
            UpdateAddOnMemoryUsage()
            now = GetAddOnMemoryUsage(addonName)
        end
        ns.Print(("jsal.ui holds %s now, after a clean-up."):format(now and MB(now) or "an unknown amount"))
        -- Between one part's file and the next, with every file in between
        -- (its data, its helpers) counted to the later one. Clean-ups run
        -- while files are read, so these are rough.
        local files, last = {}, ns.memStarted or 0
        for _, mark in ipairs(mem.marks) do
            files[#files + 1] = { "up to " .. mark[1], mark[2] - last }
            last = mark[2]
        end
        files[#files + 1] = { "after the last part", (mem.files or last) - last }
        ns.Print(("Reading the files: about %s (rough). The most, by the part whose file ends each stretch:"):format(MB((mem.files or 0) - (ns.memStarted or 0))))
        Most(files, 10)
        ns.Print(("Setting up once the settings exist: %s."):format(MB((mem.setup or 0) - (mem.files or 0))))
        ns.Print(("Starting at login: %s. The parts that kept the most:"):format(MB((mem.started or 0) - (mem.login or 0))))
        Most(mem.starts, 12)
        Tables()
    end)
end

-- /jsal perf: how long jsal.ui took to load, and, where the game keeps
-- addon timings, the addons that have cost the most.
ns.Command("perf", function()
    local t = ns.timings
    ns.Print(("Loading took %.0f ms to read the files, %.0f ms to set up and %.0f ms to start at login.")
        :format(t.files or 0, t.setup or 0, t.login or 0))
    PrintSlow()
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
    -- The longest is the game's own, and a reload doesn't clear it: it read 134.8 ms through six
    -- reloads, under words that said "since the last reload".
    ns.Print("Average time each frame, and the longest single frame (the game keeps the longest through a reload):")
    for i = 1, math.min(10, #rows) do
        local r = rows[i]
        print(("  %s: %.3f ms average, %.1f ms longest"):format(r.name, r.average, r.peak))
    end
end)

for _, page in ipairs({ "home", "install", "games", "settings" }) do
    ns.Command(page, function() ns.Window.Open(page) end)
end
-- /jsal guild opens the Games page, where the guild's day is.
ns.Command("guild", function() ns.Window.Open("games") end)

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

-- An update that added files came in while the game was running: after the
-- /reload, say a restart is needed, in chat and across the screen.
ns.OnLogin(function()
    if not ns.needsRestart then return end
    Compat.After(4, function()
        ns.Print(("jsal.ui was updated to %s. Restart the game (exit and start it again, not just /reload) to finish: this update adds new files."):format(ns.codeVersion))
        if UIErrorsFrame then UIErrorsFrame:AddMessage("jsal.ui: restart the game to finish updating", 1, 0.82, 0) end
    end)
end)
