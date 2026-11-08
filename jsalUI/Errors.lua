-- jsal.ui's own errors, kept for problem reports: the last few, each with the
-- file and line it came from, how many times it happened and when, saved for
-- the account so they outlast a /reload. Every error the game sees is looked
-- at, not only those jsal.ui catches itself: with BugSack installed, through
-- its notice of each error it catches; without it, on the way through the
-- game's error handler. Other addons' errors are left out.
local addonName, ns = ...
local Compat = ns.Compat

local Errors = {}
ns.Errors = Errors

local KEEP = 5            -- errors kept
local SHOW = 3            -- the latest few go in a report
local FRESH = 3 * 86400   -- older than three days, an error stays out of reports
local LONGEST = 150       -- the most of one error a report carries

-- Before the saved settings load, errors wait here.
local early = {}

local function List()
    if not ns.db then return early end
    ns.db.errors = type(ns.db.errors) == "table" and ns.db.errors or {}
    return ns.db.errors
end

local function Now()
    return (Compat.ServerTime and Compat.ServerTime()) or time()
end

-- An error's first line, from jsal.ui's own folder on:
-- "Helpers/MenuBar.lua:70: attempt to index a nil value".
function Errors.Short(err)
    local line = tostring(err or ""):match("^[^\n]*") or ""
    return (line:gsub("^.-AddOns[/\\]" .. addonName .. "[/\\]", ""))
end

local function Ours(err)
    local line = tostring(err or ""):match("^[^\n]*") or ""
    return line:find("AddOns[/\\]" .. addonName .. "[/\\]") ~= nil
end

local function Add(list, msg, count, at, version)
    for i, e in ipairs(list) do
        if e.msg == msg then
            table.remove(list, i)
            e.count, e.at, e.version = (e.count or 1) + count, at, version
            list[#list + 1] = e
            return
        end
    end
    list[#list + 1] = { msg = msg, count = count, at = at, version = version }
    while #list > KEEP do table.remove(list, 1) end
end

-- Keeps an error. `known` says it's jsal.ui's for certain (one it caught
-- itself); anything else counts only if it comes from jsal.ui's files.
function Errors.Record(err, known)
    if not known and not Ours(err) then return end
    local msg = Errors.Short(err)
    if msg == "" then return end
    ns.lastError = msg
    Add(List(), msg, 1, Now(), ns.version)
end

-- While jsal.ui hands one of its own errors to the game, it's already kept,
-- so the game's notice of the same error isn't counted again.
Errors.passing = false

local function Heard(err)
    if Errors.passing then return end
    pcall(Errors.Record, err)
end

-- BugSack's error catcher announces each error; without it, jsal.ui looks
-- at each error on its way through the game's handler.
local grabber = BugGrabber
if type(grabber) == "table" and EventRegistry and EventRegistry.RegisterCallback then
    EventRegistry:RegisterCallback("BugGrabber.BugGrabbed", function(_, id)
        local e = grabber.GetErrorByID and grabber:GetErrorByID(id)
        if type(e) == "table" then Heard(e.message) end
    end, Errors)
elseif geterrorhandler and seterrorhandler then
    local previous = geterrorhandler()
    seterrorhandler(function(err, ...)
        Heard(err)
        return previous(err, ...)
    end)
end

-- Errors from before the settings loaded join the saved ones.
ns.OnLoad(function()
    local list = List()
    for _, e in ipairs(early) do Add(list, e.msg, e.count, e.at, e.version) end
    early = {}
end)

local function Ago(seconds)
    if seconds < 90 then return "just now" end
    if seconds < 5400 then return ("%dm ago"):format(math.floor(seconds / 60 + 0.5)) end
    if seconds < 129600 then return ("%dh ago"):format(math.floor(seconds / 3600 + 0.5)) end
    return ("%dd ago"):format(math.floor(seconds / 86400 + 0.5))
end

-- The latest few, newest first, for a report: "Errors: Helpers/MenuBar.lua:70:
-- attempt to index a nil value (x3, 5m ago) / ...". Those from an older
-- version say which.
function Errors.Summary()
    local list, now, parts = List(), Now(), {}
    for i = #list, 1, -1 do
        local e = list[i]
        if #parts >= SHOW then break end
        if now - (e.at or 0) <= FRESH then
            local notes = {}
            if (e.count or 1) > 1 then notes[#notes + 1] = "x" .. e.count end
            notes[#notes + 1] = Ago(now - (e.at or now))
            if e.version and e.version ~= ns.version then notes[#notes + 1] = "in " .. e.version end
            local msg = e.msg
            if #msg > LONGEST then msg = msg:sub(1, LONGEST - 3) .. "..." end
            parts[#parts + 1] = ("%s (%s)"):format(msg, table.concat(notes, ", "))
        end
    end
    if #parts == 0 then return "Errors: none lately" end
    return "Errors: " .. table.concat(parts, " / ")
end
