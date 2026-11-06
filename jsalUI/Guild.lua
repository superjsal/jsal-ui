-- The Guild tab: who in the guild runs jsal.ui, and today's game scores.
-- It hears only guildmates who have jsal.ui, through addon messages, and
-- keeps what it hears for this session only.
local _, ns = ...
local Style, Compat, Comms, Window = ns.Style, ns.Compat, ns.Comms, ns.Window

local Guild = ns.NewModule("guild", {
    title = "Guild tab",
    note = "Shows guildmates with jsal.ui and today's scores. /jsal guild",
})

local members, answered = {}, {}
local MAX_ROWS = 10

-- What a player tells the guild: "version;wordDay;wordScore;iconDay;iconScore".
local function Status()
    local wordDay, wordScore = ns.DailyWord.Result()
    local iconDay, iconScore = ns.IconGuess.Result()
    return table.concat({
        ns.version,
        wordDay or 0, wordScore or "",
        iconDay or 0, iconScore or "",
    }, ";")
end

local function Store(payload, name)
    local version, wordDay, wordScore, iconDay, iconScore = strsplit(";", payload or "")
    members[name] = {
        version = version,
        wordDay = tonumber(wordDay),
        wordScore = wordScore ~= "" and wordScore or nil,
        iconDay = tonumber(iconDay),
        iconScore = iconScore ~= "" and iconScore or nil,
        seen = GetTime(),
    }
end

local function Record(payload, name)
    Store(payload, name)
    Window.Refresh()
end

-- Tells the guild a game was finished, so the scores update for everyone.
function Guild.Announce()
    if Guild.running and IsInGuild() then
        Comms.Send("ME", Status())
    end
end

function Guild:OnEnable()
    -- "HI" comes from someone logging in: note them and answer once, by
    -- whisper. "ME" is an answer or a score update.
    Comms.On("HI", function(payload, name, _, sender)
        Record(payload, name)
        if name ~= Compat.MyName() and not answered[name] then
            answered[name] = true
            Comms.Send("ME", Status(), "WHISPER", sender)
        end
    end)
    Comms.On("ME", Record)
    Compat.After(8, function()
        if IsInGuild() then Comms.Send("HI", Status()) end
    end)
end

function Guild:OnDisable()
    Comms.On("HI", nil)
    Comms.On("ME", nil)
end

-- Today's scores first: fewest Daily Word tries, then most icons right.
local function Sorted()
    local today = ns.Games.Today()
    local list = {}
    for name, m in pairs(members) do
        local word = m.wordDay == today and m.wordScore or nil
        local icons = m.iconDay == today and m.iconScore or nil
        list[#list + 1] = { name = name, version = m.version, word = word, icons = icons }
    end
    local function WordRank(e)
        if not e.word then return 99 end
        return e.word == "X" and 7 or tonumber(e.word) or 98
    end
    table.sort(list, function(a, b)
        local wa, wb = WordRank(a), WordRank(b)
        if wa ~= wb then return wa < wb end
        local ia, ib = tonumber(a.icons) or -1, tonumber(b.icons) or -1
        if ia ~= ib then return ia > ib end
        return a.name < b.name
    end)
    return list
end

Window.Page("guild", function(page)
    local lead = Style.Text(page, 13, "muted")
    lead:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", 0, -8)
    lead:SetWidth(Window.contentWidth)
    lead:SetText("Guildmates who run jsal.ui, and how they did today. Only guildies with jsal.ui show up.")

    local COLUMNS = { { "Name", 0 }, { "Daily Word", 230 }, { "Icon Guess", 340 }, { "Version", 450 } }
    local header = CreateFrame("Frame", nil, page)
    header:SetSize(Window.contentWidth, 24)
    header:SetPoint("TOPLEFT", lead, "BOTTOMLEFT", 0, -16)
    Style.Rule(header, "BOTTOM", "lineStrong")
    for _, column in ipairs(COLUMNS) do
        local t = Style.Text(header, 11, "muted")
        t:SetPoint("TOPLEFT", column[2], -4)
        t:SetText(column[1]:upper())
    end

    local rows = {}
    for i = 1, MAX_ROWS do
        local row = CreateFrame("Frame", nil, page)
        row:SetSize(Window.contentWidth, 28)
        row:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -(i - 1) * 28)
        Style.Rule(row, "BOTTOM", "line")
        row.cells = {}
        for c, column in ipairs(COLUMNS) do
            local t = Style.Text(row, 13, c == 1 and "text" or "muted")
            t:SetPoint("LEFT", column[2], 0)
            row.cells[c] = t
        end
        rows[i] = row
    end

    local empty = Style.Text(page, 13, "text")
    empty:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -12)
    empty:SetWidth(Window.contentWidth)
    local more = Style.Text(page, 11, "muted")
    more:SetPoint("TOPLEFT", rows[MAX_ROWS], "BOTTOMLEFT", 0, -8)

    page.Refresh = function()
        if Guild.running and IsInGuild() then
            Store(Status(), Compat.MyName())
        end
        local list = Sorted()
        if not Guild.running then
            empty:SetText("The Guild tab is turned off. /jsal settings turns it on.")
        elseif not IsInGuild() then
            empty:SetText("You're not in a guild yet.")
        elseif #list == 0 then
            empty:SetText("No one yet. Guildmates show up as they log in with jsal.ui.")
        end
        empty:SetShown(#list == 0 or not Guild.running or not IsInGuild())
        for i, row in ipairs(rows) do
            local e = Guild.running and list[i]
            row:SetShown(e and true or false)
            if e then
                row.cells[1]:SetText(e.name)
                row.cells[2]:SetText(e.word and (e.word == "X" and "Missed" or (e.word .. " of 6")) or "Not yet")
                row.cells[3]:SetText(e.icons and (e.icons .. " of 10") or "Not yet")
                row.cells[4]:SetText(e.version or "")
            end
        end
        more:SetText(#list > MAX_ROWS and ("and %d more"):format(#list - MAX_ROWS) or "")
    end
end)

ns.Guild = Guild
