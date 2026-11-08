-- Report a problem: a player says what went wrong, and jsal.ui adds their
-- version, class, level, zone and jsal.ui's latest errors (Errors.lua). The
-- report goes through the guild's hidden addon channel to whoever takes
-- reports (John, on any of his characters). It waits on the sender's side
-- until he's online, and leaves only once his copy says it has it. Outside
-- his guild, the page offers the report to copy and email instead.
local _, ns = ...
local Style, Compat, Comms, Window = ns.Style, ns.Compat, ns.Comms, ns.Window

local Reports = {}
ns.Reports = Reports

local MAX_TEXT, CHUNK, MAX_PARTS = 400, 180, 8
local RESEND = 120   -- seconds before a report not yet confirmed is sent again
local EMAIL = "dev@jsal.io"

-- Saved for the account: reports waiting to go, reports received (only on
-- the taker's side), and whether this account takes them.
local function Out()
    ns.db.reportsOut = type(ns.db.reportsOut) == "table" and ns.db.reportsOut or {}
    return ns.db.reportsOut
end

local function In()
    ns.db.reportsIn = type(ns.db.reportsIn) == "table" and ns.db.reportsIn or {}
    return ns.db.reportsIn
end

function Reports.Receiving()
    return ns.db ~= nil and ns.db.takesReports == true
end

function Reports.Waiting()
    return #Out()
end

-- The separators the messages use can't appear inside a report.
local function Clean(text)
    return (tostring(text or ""):gsub("[|%^;\r\n]", " "):gsub("%s+", " "):match("^%s*(.-)%s*$"))
end

-- What's added to every report.
function Reports.Details()
    local className = UnitClass("player")
    local zone = GetRealZoneText and GetRealZoneText() or ""
    return ("jsal.ui %s, %s %d, %s"):format(ns.version or "?", className or "?", UnitLevel("player") or 0,
        zone ~= "" and zone or "unknown zone")
end

function Reports.LastError()
    return ns.Errors and ns.Errors.Summary() or "Errors: none lately"
end

-- A report as one line, for copying.
local function AsText(r)
    return ("%s (%s. %s)"):format(r.text, r.details, r.error)
end

-- Splits a report into pieces that fit an addon message, never inside a
-- letter that takes more than one byte.
local function Pieces(whole)
    local list, at = {}, 1
    while at <= #whole do
        local stop = math.min(#whole, at + CHUNK - 1)
        while stop < #whole and stop > at do
            local nextByte = whole:byte(stop + 1)
            if nextByte < 0x80 or nextByte >= 0xC0 then break end
            stop = stop - 1
        end
        list[#list + 1] = whole:sub(at, stop)
        at = stop + 1
    end
    return list
end

-- The guild by name: true for those online now.
local function OnlineNow()
    local online = {}
    for i = 1, (GetNumGuildMembers and GetNumGuildMembers() or 0) do
        local full, _, _, _, _, _, _, _, isOnline = GetGuildRosterInfo(i)
        if full and isOnline then online[Ambiguate(full, "none")] = true end
    end
    return online
end

-- A guildmate online now whose jsal.ui takes reports: their name and the
-- name to whisper them by.
-- Takers heard this session (their jsal.ui said hello), by name, with when.
-- The guild list alone isn't enough: just after someone logs out it still
-- shows them online for a minute or two, and a whisper then only earns a
-- "No player named ..." line in chat. One person can take reports on more
-- than one character (it's for the whole account), so the taker just heard
-- is the one sent to; otherwise the one heard most lately.
local heard = {}

local function Taker(preferred)
    local members = ns.Guild and ns.Guild.Members and ns.Guild.Members() or {}
    local online, me = OnlineNow(), Compat.MyName()
    local function Fits(name)
        local m = members[name]
        return m and m.takesReports and heard[name] and online[name] and name ~= me
    end
    if preferred and Fits(preferred) then return preferred, members[preferred].target or preferred end
    local best
    for name in pairs(members) do
        if Fits(name) and (not best or heard[name] > heard[best]) then best = name end
    end
    if best then return best, members[best].target or best end
end

-- A report written on the account that takes reports needs no whisper: it
-- goes straight into this account's own list.
local function KeepHere()
    local out = Out()
    if #out == 0 then return end
    local me = Compat.MyName() or "you"
    for _, r in ipairs(out) do
        In()[#In() + 1] = { id = r.id, from = me, at = r.at or Compat.ServerTime(), text = r.text or "",
                            details = r.details or "", error = r.error or "" }
    end
    for i = #out, 1, -1 do out[i] = nil end
    Reports.justSent = true
end

-- Sends every waiting report to a taker who's online, at most once every
-- two minutes each, until the taker confirms it.
function Reports.Flush(preferred)
    local out = Out()
    if #out == 0 then return end
    if Reports.Receiving() then return KeepHere() end
    if not IsInGuild() then return end
    local _, target = Taker(preferred)
    if not target then return end
    local now = GetTime()
    for _, r in ipairs(out) do
        -- A different taker (the one just heard) is tried at once.
        if not r.sentAt or r.sentAt + RESEND <= now or r.sentTo ~= target then
            r.sentAt, r.sentTo = now, target
            local pieces = Pieces(table.concat({ r.text, r.details, r.error }, "^"))
            for i, piece in ipairs(pieces) do
                Comms.Send("BR", table.concat({ r.id, i, #pieces, piece }, ";"), "WHISPER", target)
            end
        end
    end
end

-- The Guild tab heard from a guildmate: if they take reports, send.
function Reports.Heard(name)
    local m = ns.Guild and ns.Guild.Members and ns.Guild.Members()[name]
    if m and m.takesReports then
        heard[name] = GetTime()
        Reports.Flush(name)
    end
end

-- Cuts text to at most max bytes, never inside a letter.
local function Cut(text, max)
    if #text <= max then return text end
    local stop = max
    while stop > 0 do
        local nextByte = text:byte(stop + 1)
        if nextByte < 0x80 or nextByte >= 0xC0 then break end
        stop = stop - 1
    end
    return text:sub(1, stop)
end

-- Keeps a report to send and tries at once. Returns false with why when
-- there's nothing to send.
function Reports.Submit(text)
    text = Cut(Clean(text), MAX_TEXT)
    if text == "" then return false, "Say what happened first." end
    local out = Out()
    out[#out + 1] = {
        id = ("%x%03x"):format(Compat.ServerTime() or 0, math.random(0, 4095)),
        text = text, details = Clean(Reports.Details()), error = Clean(Reports.LastError()),
        at = Compat.ServerTime(),
    }
    Reports.Flush()
    return true
end

-- The latest report, or the one being written, as a line to copy.
function Reports.CopyText(text)
    return AsText({ text = Clean(text), details = Clean(Reports.Details()), error = Clean(Reports.LastError()) })
end

---------------------------------------------------------------------------
-- The taker's side: pieces come in, a whole report is kept once and
-- confirmed, and its sender drops it.
---------------------------------------------------------------------------
local partial = {}

local function Received(payload, name, _, sender)
    if not Reports.Receiving() then return end
    local id, i, n, piece = (payload or ""):match("^(%x+);(%d+);(%d+);(.*)$")
    i, n = tonumber(i), tonumber(n)
    if not id or n < 1 or n > MAX_PARTS or i < 1 or i > n then return end
    local key = name .. ":" .. id
    local parts = partial[key]
    if not parts or parts.n ~= n then
        parts = { n = n, got = 0 }
        partial[key] = parts
    end
    if not parts[i] then
        parts[i] = piece
        parts.got = parts.got + 1
    end
    if parts.got < n then return end
    partial[key] = nil
    local text, details, err = strsplit("^", table.concat(parts, "", 1, n))
    local kept = false
    for _, r in ipairs(In()) do
        if r.from == name and r.id == id then kept = true end
    end
    if not kept then
        In()[#In() + 1] = { id = id, from = name, at = Compat.ServerTime(), text = text or "",
                            details = details or "", error = err or "" }
        ns.Print(("A problem report from %s: %s"):format(name, text or ""))
    end
    Comms.Send("BA", id, "WHISPER", sender)
end

local function Confirmed(payload, name)
    local m = ns.Guild and ns.Guild.Members and ns.Guild.Members()[name]
    if not (m and m.takesReports) then return end
    local out = Out()
    for i = #out, 1, -1 do
        if out[i].id == payload then
            table.remove(out, i)
            Reports.justSent = true
        end
    end
    Window.Refresh()
end

Comms.On("BR", Received)
Comms.On("BA", Confirmed)

-- /jsal bug opens the page. /jsal reports lists what came in; "on" and "off"
-- choose whether this account takes reports (John's, once).
ns.Command("bug", function() Window.Open("report") end)
ns.Command("reports", function()
    local list = In()
    if not Reports.Receiving() and #list == 0 then
        return ns.Print("This account doesn't take problem reports.")
    end
    ns.Print(("%d problem report%s received%s."):format(#list, #list == 1 and "" or "s",
        Reports.Receiving() and "" or " (taking reports is off)"))
    for i = math.max(1, #list - 4), #list do
        local r = list[i]
        ns.Print(("%s: %s (%s. %s)"):format(r.from, r.text, r.details, r.error))
    end
end)
ns.Command("reports on", function()
    ns.db.takesReports = true
    ns.Print("This account now takes problem reports from guildmates.")
    if ns.Guild and ns.Guild.running then ns.Guild.Announce() end
end)
ns.Command("reports off", function()
    ns.db.takesReports = nil
    ns.Print("This account no longer takes problem reports.")
end)

-- Waiting reports go once the guild list is in and a taker answers hello.
ns.OnLogin(function()
    Compat.After(20, function() xpcall(Reports.Flush, ns.Report) end)
end)

---------------------------------------------------------------------------
-- The page.
---------------------------------------------------------------------------
Window.Page("report", function(page)
    local width = Window.contentWidth
    local lead = Style.Text(page, 13, "muted")
    lead:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", 0, -8)
    lead:SetWidth(width)
    lead:SetJustifyH("LEFT")
    lead:SetText("Say what happened. Your version, class, level, zone and any jsal.ui error are added for you.")

    local well = CreateFrame("Frame", nil, page)
    well:SetPoint("TOPLEFT", lead, "BOTTOMLEFT", 0, -14)
    well:SetSize(width, 120)
    Style.Fill(well, "well")
    Style.Border(well, "lineStrong")
    local box = CreateFrame("EditBox", nil, well)
    box:SetPoint("TOPLEFT", 10, -8)
    box:SetPoint("BOTTOMRIGHT", -10, 8)
    box:SetMultiLine(true)
    box:SetAutoFocus(false)
    -- Room for the copy version too, which adds the details; a sent report
    -- is still cut to its first 400 letters.
    box:SetMaxLetters(MAX_TEXT + 300)
    box:SetFont(Style.font, 14, "")
    box:SetTextColor(Style.Color("text"))
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    well:EnableMouse(true)
    well:SetScript("OnMouseDown", function() box:SetFocus() end)
    local hint = Style.Text(well, 13, "muted")
    hint:SetPoint("TOPLEFT", 10, -9)
    hint:SetText("What went wrong, and what were you doing?")

    local label = Style.Text(page, 11, "gold", nil, true)
    label:SetPoint("TOPLEFT", well, "BOTTOMLEFT", 0, -18)
    label:SetText("ADDED FOR YOU")
    local added = CreateFrame("Frame", nil, page)
    added:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -6)
    added:SetSize(width, 52)
    Style.Fill(added, "well")
    Style.Border(added, "line")
    local addedText = Style.Text(added, 13, "muted")
    addedText:SetPoint("TOPLEFT", 10, -9)
    addedText:SetWidth(width - 20)
    addedText:SetJustifyH("LEFT")

    local send = Style.Button(page, "Send to John", "primary", 150)
    send:SetPoint("TOPLEFT", added, "BOTTOMLEFT", 0, -18)
    local status = Style.Text(page, 13, "muted")
    status:SetPoint("LEFT", send, "RIGHT", 14, 0)
    status:SetWidth(width - 170)
    status:SetJustifyH("LEFT")

    -- Outside John's guild: the report to copy and email.
    local other = Style.Text(page, 13, "muted")
    other:SetPoint("TOPLEFT", send, "BOTTOMLEFT", 0, -26)
    other:SetWidth(width - 130)
    other:SetJustifyH("LEFT")
    other:SetText("Not in John's guild? Press Copy, then Ctrl+C, and email it to " .. EMAIL .. ".")
    local copy = Style.Button(page, "Copy", "plain", 110)
    copy:SetPoint("TOPRIGHT", send, "BOTTOMLEFT", width, -20)

    local message
    local function Paint()
        hint:SetShown(box:GetText() == "" and not box:HasFocus())
        addedText:SetText(Reports.Details() .. "\n" .. Reports.LastError())
        local waiting = Reports.Waiting()
        if message then
            status:SetText(message)
        elseif waiting > 0 then
            status:SetText(("Waiting to reach John: %d. %s go the next time you're both online."):format(
                waiting, waiting == 1 and "It will" or "They will"))
        elseif Reports.justSent then
            status:SetText("John has it. Thanks for telling him.")
        else
            status:SetText(IsInGuild() and "" or "Reports travel through your guild. Outside one, use Copy below.")
        end
    end
    box:SetScript("OnEditFocusGained", Paint)
    box:SetScript("OnEditFocusLost", Paint)
    box:SetScript("OnTextChanged", function()
        message = nil
        Paint()
    end)
    send:SetScript("OnClick", function()
        local ok, why = Reports.Submit(box:GetText())
        Reports.justSent = nil
        if not ok then
            message = why
        else
            box:SetText("")
            box:ClearFocus()
            message = nil
        end
        Paint()
    end)
    copy:SetScript("OnClick", function()
        local text = box:GetText()
        if Clean(text) == "" then
            message = "Say what happened first."
            return Paint()
        end
        box:SetText(Reports.CopyText(text))
        box:SetFocus()
        box:HighlightText()
        message = "Selected: press Ctrl+C, then paste it into an email to " .. EMAIL .. "."
        Paint()
    end)
    page.Refresh = Paint
end)
