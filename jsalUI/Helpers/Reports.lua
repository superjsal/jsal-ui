-- Report a problem: a player says what went wrong, and jsal.ui adds their
-- version, class, level, zone and jsal.ui's latest errors (Errors.lua). The
-- report goes through the guild's hidden addon channel to whoever takes
-- reports. It waits on the sender's side until he's online, and leaves only
-- once his copy says it has it. Outside his guild, the page offers the
-- report to copy and post on jsal.ui's Discord, or email, instead.
local _, ns = ...
local Style, Compat, Comms, Window = ns.Style, ns.Compat, ns.Comms, ns.Window

local Reports = {}
ns.Reports = Reports

local MAX_TEXT, CHUNK, MAX_PARTS = 400, 180, 8
local RESEND = 120   -- seconds before a report not yet confirmed is sent again
local EMAIL = "dev@jsal.io"
-- jsal.ui's Discord: where a problem is reported from outside the guild, and where ideas and
-- questions go. An invite that doesn't expire.
local DISCORD = "https://discord.gg/BfUKeCjNeZ"
Reports.DISCORD = DISCORD

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

-- The same details, each on its own, for the page's card: the version, the
-- character, and where it is.
function Reports.Parts()
    local className = UnitClass("player")
    local zone = GetRealZoneText and GetRealZoneText() or ""
    return "jsal.ui " .. (ns.version or "?"), ("%s, level %d"):format(className or "?", UnitLevel("player") or 0),
        zone ~= "" and zone or "unknown zone"
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
    local online, me = Compat.GuildOnline(), Compat.MyName()
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
local KEEP_IN = 200   -- reports kept on the taker's side; past it the oldest go

-- Whether a name is in your guild, by its roster; with no roster in yet, nobody is.
local function Guildmate(name)
    for i = 1, (GetNumGuildMembers and GetNumGuildMembers() or 0) do
        local full = GetGuildRosterInfo(i)
        if full and Ambiguate(full, "none") == name then return true end
    end
    return false
end

-- Only from a guildmate: a whisper on the hidden channel can come from anyone, and whatever
-- anyone sent was kept, with no end to how much. (One not let in is sent again by its
-- sender's jsal.ui later, so a roster that's late loading loses nothing.)
local function Received(payload, name, _, sender)
    if not Reports.Receiving() or not Guildmate(name) then return end
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
        while #In() > KEEP_IN do table.remove(In(), 1) end
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

-- /jsal bug opens the page. /jsal reports lists what came in (and so does logging in, where there
-- are any); "clear" lets them go; "on" and "off" choose whether this account takes reports.
ns.Command("bug", function() Window.Open("report") end)
function Reports.List()
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
    if #list > 0 then ns.Print("/jsal reports clear lets them go.") end
end
ns.Command("reports", Reports.List)
ns.Command("reports clear", function()
    local n = #In()
    ns.db.reportsIn = {}
    ns.Print(("Cleared %d problem report%s."):format(n, n == 1 and "" or "s"))
end)

-- Logging in (not a /reload) on an account that takes reports, with some kept: the list, after the
-- game's own lines.
function Reports.AtLogin()
    if Reports.Receiving() and #In() > 0 then Reports.List() end
end
local login = CreateFrame("Frame")
login:RegisterEvent("PLAYER_ENTERING_WORLD")
login:SetScript("OnEvent", function(self, _, initial)
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    if Compat.Plain(initial) then Compat.After(8, function() xpcall(Reports.AtLogin, ns.Report) end) end
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

-- /jsal discord: the invite, in a box to copy it from. The game can't open a web page, so the
-- link is shown selected, as the Build Planner's share window shows its link: Ctrl+C takes it.
local invite
function Reports.Discord()
    if not invite then
        local WIDTH = 440
        invite = Style.Panel("jsalUIDiscord", WIDTH, 150, "jsal.ui on Discord")
        invite:SetFrameStrata("DIALOG")
        local note = Style.Text(invite, 12, "muted")
        note:SetPoint("TOPLEFT", 16, -44)
        note:SetWidth(WIDTH - 32)
        note:SetJustifyH("LEFT")
        note:SetText("Bugs, ideas and questions. Press Ctrl+C to copy the link, then paste it into your browser.")
        local well = CreateFrame("Frame", nil, invite)
        well:SetPoint("TOPLEFT", 16, -80)
        well:SetSize(WIDTH - 32, 28)
        Style.Box(well, 5, "well", "lineStrong")
        local link = CreateFrame("EditBox", nil, well)
        link:SetPoint("TOPLEFT", 8, 0)
        link:SetPoint("BOTTOMRIGHT", -8, 0)
        link:SetAutoFocus(false)
        link:SetFont(Style.font, 13, "")
        link:SetTextColor(Style.Color("text"))
        link:SetScript("OnEscapePressed", function() invite:Hide() end)
        link:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
        -- The box is for copying from: anything typed over the link puts the link back.
        link:SetScript("OnTextChanged", function(self, typed)
            if typed then
                self:SetText(DISCORD)
                self:HighlightText()
            end
        end)
        well:EnableMouse(true)
        well:SetScript("OnMouseDown", function() link:SetFocus() end)
        local close = Style.Button(invite, "Close", "plain", 90)
        close:SetPoint("BOTTOMRIGHT", -16, 14)
        close:SetScript("OnClick", function() invite:Hide() end)
        invite.link = link
    end
    invite.link:SetText(DISCORD)
    invite:Show()
    invite.link:SetFocus()
    invite.link:HighlightText()
    return invite
end
ns.Command("discord", function() Reports.Discord() end)

-- Waiting reports go once the guild list is in and a taker answers hello.
ns.OnLogin(function()
    Compat.After(20, function() xpcall(Reports.Flush, ns.Report) end)
end)

---------------------------------------------------------------------------
-- The page.
---------------------------------------------------------------------------
Window.Page("report", function(page)
    -- Across the dashboard's whole width: the box to write in at the left,
    -- with Send under it; at the right, what's added for you, and the way
    -- to send it from outside jsal's guild.
    local width = Window.fullWidth
    local SIDE_W, GAP, LABEL_W = 372, 24, 96
    local boxW, sideX = width - SIDE_W - GAP, width - SIDE_W
    local title, lead = Window.Header(page, width)
    title:SetText("Tell jsal what went wrong")
    lead:SetText("Your version, class, level, zone and any jsal.ui error are added for you.")

    local well = CreateFrame("Frame", nil, page)
    well:SetPoint("TOPLEFT", lead, "BOTTOMLEFT", 0, -14)
    well:SetSize(boxW, 320)
    Style.Box(well, 5, "well", "lineStrong")
    local box = CreateFrame("EditBox", nil, well)
    box:SetPoint("TOPLEFT", 12, -10)
    box:SetPoint("BOTTOMRIGHT", -12, 10)
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
    hint:SetPoint("TOPLEFT", 12, -11)
    hint:SetText("What went wrong, and what were you doing?")

    local send = Style.Button(page, "Send to jsal", "primary", 150)
    send:SetPoint("TOPLEFT", well, "BOTTOMLEFT", 0, -14)
    local status = Style.Text(page, 13, "muted")
    status:SetPoint("LEFT", send, "RIGHT", 14, 0)
    status:SetWidth(boxW - 170)
    status:SetJustifyH("LEFT")

    -- What's added for you, a row each: the version, the character, where
    -- it is, the reports still waiting to reach jsal, and the last errors.
    local added = Style.Card(page, "Added for you")
    added:SetPoint("TOPLEFT", lead, "BOTTOMLEFT", sideX, -14)
    added:SetWidth(SIDE_W)
    local rows = {}
    for i, name in ipairs({ "Version", "Character", "Where", "Reports", "Errors" }) do
        local row = CreateFrame("Frame", nil, added)
        row:SetSize(SIDE_W - 28, 28)
        row:SetPoint("TOPLEFT", 14, -(32 + (i - 1) * 28))
        if i > 1 then Style.Rule(row, "TOP", "line") end
        local key = Style.Text(row, 12, "muted")
        key:SetPoint("TOPLEFT", 0, -7)
        key:SetText(name)
        row.value = Style.Text(row, 13, "text")
        row.value:SetPoint("TOPLEFT", LABEL_W, -6)
        row.value:SetWidth(SIDE_W - 28 - LABEL_W)
        row.value:SetJustifyH("LEFT")
        rows[i] = row
    end
    local addedText = rows[5].value

    -- Outside jsal's guild: the report to copy and post on the Discord, or email.
    local other = Style.Text(page, 13, "muted")
    other:SetPoint("TOPLEFT", added, "BOTTOMLEFT", 0, -18)
    other:SetWidth(SIDE_W)
    other:SetJustifyH("LEFT")
    other:SetText("Not in jsal's guild? Press Copy, then Ctrl+C, and post it in bug-reports on jsal.ui's Discord, or email it to "
        .. EMAIL .. ".")
    local copy = Style.Button(page, "Copy", "plain", 110)
    copy:SetPoint("TOPLEFT", other, "BOTTOMLEFT", 0, -10)
    -- And the way there: the invite, to copy.
    local discord = Style.Button(page, "Discord link", "plain", 120)
    discord:SetPoint("LEFT", copy, "RIGHT", 8, 0)
    discord:SetScript("OnClick", function() Reports.Discord() end)

    local message
    local function Paint()
        hint:SetShown(box:GetText() == "" and not box:HasFocus())
        local waiting = Reports.Waiting()
        local version, character, where = Reports.Parts()
        rows[1].value:SetText(version)
        rows[2].value:SetText(character)
        rows[3].value:SetText(where)
        rows[4].value:SetText(waiting == 0 and "none waiting" or (waiting .. " waiting to reach jsal"))
        rows[4].value:SetTextColor(Style.Color(waiting == 0 and "muted" or "text"))
        -- The errors, without the word the row already says. A few long ones
        -- wrap to several lines: the card grows to hold them, and the Copy
        -- line under it moves down with it.
        local errors = (Reports.LastError():gsub("^Errors:%s*", ""))
        addedText:SetText(errors)
        addedText:SetTextColor(Style.Color(errors:find("^none") and "green" or "text"))
        added:SetHeight(32 + 4 * 28 + math.max(28, addedText:GetStringHeight() + 14) + 6)
        if message then
            status:SetText(message)
        elseif waiting > 0 then
            status:SetText(("Waiting to reach jsal: %d. %s go the next time you're both online."):format(
                waiting, waiting == 1 and "It will" or "They will"))
        elseif Reports.justSent then
            status:SetText("jsal has it. Thanks for telling him.")
        else
            status:SetText(IsInGuild() and "" or "Reports travel through your guild. Outside one, use Copy below.")
        end
    end
    box:SetScript("OnEditFocusGained", Paint)
    box:SetScript("OnEditFocusLost", Paint)
    -- Only your own typing clears what was last said. Copy fills the box itself, and where
    -- the game tells of that a moment later, its "press Ctrl+C" was gone as soon as it showed.
    box:SetScript("OnTextChanged", function(_, typed)
        if typed then message = nil end
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
        message = "Selected: press Ctrl+C, then paste it into a post in bug-reports on Discord, or an email to " .. EMAIL .. "."
        Paint()
    end)
    page.Refresh = Paint
end, nil, true)
