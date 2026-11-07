-- The Journal page, in three tabs: Summary (who you are, your numbers and
-- favourites), Story (the moments, newest first, by kind) and Characters
-- (every character on the account, with gold and rested XP).
local _, ns = ...
local Style, Compat, Window = ns.Style, ns.Compat, ns.Window

local TAB_W, GAP, TILE_H, ROW_H, CARD_H = 130, 8, 70, 26, 86
local MODEL_W, HERO_H = 170, 210

local function Hours(seconds)
    seconds = math.floor(seconds or 0)
    local h, m = math.floor(seconds / 3600), math.floor(seconds % 3600 / 60)
    if h > 0 then return ("%dh %02dm"):format(h, m) end
    return ("%dm"):format(m)
end

local function Count(n)
    n = math.floor(n or 0)
    local s = tostring(n)
    while true do
        local k
        s, k = s:gsub("^(%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    return s
end

local function Miles(yards)
    local miles = (yards or 0) / 1760
    if miles < 1 then return ("%d yd"):format(math.floor(yards or 0)) end
    return ("%.1f mi"):format(miles)
end

local function Gold(copper)
    return ("%dg"):format(math.floor((copper or 0) / 10000))
end

-- Coins in short: "2g 48s", "83s 52c", "5c", with a minus when spent.
local function Coins(copper)
    copper = math.floor(copper or 0)
    local sign = copper < 0 and "-" or ""
    copper = math.abs(copper)
    local g, s, c = math.floor(copper / 10000), math.floor(copper % 10000 / 100), copper % 100
    if g > 0 then return s > 0 and ("%s%dg %ds"):format(sign, g, s) or ("%s%dg"):format(sign, g) end
    if s > 0 then return c > 0 and ("%s%ds %dc"):format(sign, s, c) or ("%s%ds"):format(sign, s) end
    return ("%s%dc"):format(sign, c)
end

-- "today", "yesterday" or "2 Nov".
local function Day(t)
    local now = Compat.ServerTime()
    local today = date("%Y%m%d", now)
    if date("%Y%m%d", t) == today then return "today" end
    if date("%Y%m%d", t + 86400) == today then return "yesterday" end
    return (date("%d %b", t):gsub("^0", ""))
end

local function ClassColor(classFile)
    local c = RAID_CLASS_COLORS and classFile and RAID_CLASS_COLORS[classFile]
    return c and ("|cff%02x%02x%02x"):format(math.floor(c.r * 255), math.floor(c.g * 255), math.floor(c.b * 255)) or "|cffece6d6"
end

Window.Page("journal", function(page)
    local J = ns.Journal
    local width, height = Window.contentWidth, Window.contentHeight
    local tabs, views, current = {}, {}, "summary"

    local function View(key)
        local v = CreateFrame("Frame", nil, page)
        v:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", 0, -52)
        v:SetSize(width, height - 52)
        v:Hide()
        views[key] = v
        return v
    end

    local Paint
    for i, tab in ipairs({ { "summary", "Summary" }, { "story", "Story" }, { "levels", "By level" }, { "characters", "Characters" } }) do
        local b = Style.Button(page, tab[2], "plain", TAB_W)
        b:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", (i - 1) * (TAB_W + 6), -8)
        b:SetScript("OnClick", function()
            current = tab[1]
            Paint()
        end)
        tabs[tab[1]] = b
    end

    -----------------------------------------------------------------
    -- Summary.
    -----------------------------------------------------------------
    local summary = View("summary")
    local modelWell = CreateFrame("Frame", nil, summary)
    modelWell:SetPoint("TOPLEFT")
    modelWell:SetSize(MODEL_W, HERO_H)
    Style.Fill(modelWell, "well")
    Style.Border(modelWell, "line")
    local model = CreateFrame("PlayerModel", nil, modelWell)
    model:SetPoint("TOPLEFT", 1, -1)
    model:SetPoint("BOTTOMRIGHT", -1, 1)
    local name = Style.Text(summary, 20, "text", nil, true)
    name:SetPoint("TOPLEFT", modelWell, "TOPRIGHT", 18, -8)
    local who = Style.Text(summary, 13, "muted")
    who:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -6)
    local fav = Style.Text(summary, 13, "gold")
    fav:SetPoint("TOPLEFT", who, "BOTTOMLEFT", 0, -14)
    local since = Style.Text(summary, 11, "muted")
    since:SetPoint("TOPLEFT", fav, "BOTTOMLEFT", 0, -6)

    local tileW = math.floor((width - 2 * GAP) / 3)
    local tiles = {}
    for i = 1, 9 do
        local t = CreateFrame("Frame", nil, summary)
        t:SetSize(tileW, TILE_H)
        t:SetPoint("TOPLEFT", ((i - 1) % 3) * (tileW + GAP), -(HERO_H + 16 + math.floor((i - 1) / 3) * (TILE_H + GAP)))
        Style.Fill(t, "well")
        Style.Border(t, "line")
        t.n = Style.Text(t, 20, "gold", nil, true)
        t.n:SetPoint("TOPLEFT", 12, -10)
        t.label = Style.Text(t, 12, "text")
        t.label:SetPoint("TOPLEFT", t.n, "BOTTOMLEFT", 0, -4)
        t.note = Style.Text(t, 11, "muted")
        t.note:SetPoint("LEFT", t.label, "RIGHT", 6, 0)
        t.note:SetWidth(tileW - 120)
        t.note:SetWordWrap(false)
        t.note:SetJustifyH("LEFT")
        tiles[i] = t
    end

    local listTop = HERO_H + 16 + 3 * (TILE_H + GAP) + 10
    local halfW = math.floor((width - 24) / 2)
    local function List(x, title)
        local head = Style.Text(summary, 11, "gold", nil, true)
        head:SetPoint("TOPLEFT", x, -listTop)
        head:SetText(title)
        local rows = {}
        for i = 1, 5 do
            local r = CreateFrame("Frame", nil, summary)
            r:SetSize(halfW, ROW_H)
            r:SetPoint("TOPLEFT", x, -(listTop + 20 + (i - 1) * ROW_H))
            Style.Rule(r, "BOTTOM", "line")
            r.key = Style.Text(r, 13, "text")
            r.key:SetPoint("LEFT")
            r.key:SetWidth(halfW - 90)
            r.key:SetWordWrap(false)
            r.key:SetJustifyH("LEFT")
            r.n = Style.Text(r, 13, "gold")
            r.n:SetPoint("RIGHT")
            rows[i] = r
        end
        return rows
    end
    local usedRows = List(0, "MOST USED")
    local zoneRows = List(halfW + 24, "MOST TIME IN")

    local function FillList(rows, entries, format, empty)
        for i, r in ipairs(rows) do
            local e = entries[i]
            r:SetShown(e ~= nil or i == 1)
            r.key:SetText(e and e.key or empty)
            r.n:SetText(e and format(e.n) or "")
        end
    end

    local function PaintSummary()
        local book = J.Book()
        local className, classFile = UnitClass("player")
        model:SetUnit("player")
        model:SetRotation(0.35)
        -- The camera a little closer than the game's default, so the
        -- character fills its frame.
        if model.SetCamDistanceScale then pcall(model.SetCamDistanceScale, model, 0.75) end
        name:SetText(ClassColor(classFile) .. (Compat.MyName() or UnitName("player")) .. "|r")
        who:SetText(("Level %d %s · %s on record"):format(UnitLevel("player"), className or "", Hours(J.Stat("seconds"))))
        local spells = J.Top(book.spells, 5)
        fav:SetText(spells[1] and ("Favourite move: %s, %s times"):format(spells[1].key, Count(spells[1].n)) or "Your favourite move shows once you've cast a few.")
        -- The game's own totals cover the whole life of the character; the
        -- rest is counted from the day the Journal began.
        local day = (date("%d %B %Y", book.since or Compat.ServerTime()):gsub("^0", ""))
        local extras = {}
        for _, e in ipairs({ { "flights", "flight", "flights" }, { "hearths", "hearth", "hearths" }, { "camped", "campfire", "campfires" } }) do
            local n = J.Total(e[1])
            if n > 0 then extras[#extras + 1] = ("%s %s"):format(Count(n), n == 1 and e[2] or e[3]) end
        end
        since:SetText((#extras > 0 and (table.concat(extras, ", ") .. ". ") or "")
            .. ("Distance, jumps and damage counted since %s."):format(day))
        local killers = J.Top(book.killers, 1)
        local source = J.MoneySource()
        local bosses = J.Bosses()
        local duelsWon, duelsLost = J.Total("duelsWon"), J.Total("duelsLost")
        local data = {
            { Count(J.Total("foes")), "Foes defeated", bosses > 0 and (Count(bosses) .. (bosses == 1 and " boss" or " bosses")) or "" },
            { Miles(J.Stat("yards")), "Travelled", "" },
            { Count(J.Total("quests")), "Quests done", "" },
            { Count(J.Total("damage")), "Damage dealt", "" },
            { Count(J.Total("healing")), "Healing done", "" },
            { Count(J.Total("deaths")), "Deaths", killers[1] and ("most to " .. killers[1].key) or "" },
            { Gold(J.Total("earned")), "Gold earned", source and ("most from " .. source) or "" },
            { ("%d-%d"):format(duelsWon, duelsLost), "Duels won and lost", "" },
            { Count(J.Stat("jumps")), "Jumps", "" },
        }
        for i, t in ipairs(tiles) do
            t.n:SetText(data[i][1])
            t.label:SetText(data[i][2])
            t.note:SetText(data[i][3])
        end
        FillList(usedRows, spells, Count, "Nothing cast yet")
        FillList(zoneRows, J.Top(book.zones, 5), Hours, "Nowhere yet")
    end

    -----------------------------------------------------------------
    -- Story.
    -----------------------------------------------------------------
    local story = View("story")
    local filter, offset = nil, 0
    local filters = {}
    for i, f in ipairs({ { nil, "All" }, { "levels", "Levels" }, { "kills", "Kills" }, { "loot", "Loot" },
                         { "deaths", "Deaths" }, { "more", "More" } }) do
        local b = Style.Button(story, f[2], "plain", 84)
        b:SetHeight(24)
        b:SetPoint("TOPLEFT", (i - 1) * 90, 0)
        b:SetScript("OnClick", function()
            filter, offset = f[1], 0
            Paint()
        end)
        filters[#filters + 1] = { key = f[1], button = b }
    end
    local maxRows = math.floor((height - 52 - 40 - 24) / ROW_H)
    local storyRows = {}
    for i = 1, maxRows do
        local r = CreateFrame("Frame", nil, story)
        r:SetSize(width, ROW_H)
        r:SetPoint("TOPLEFT", 0, -(36 + (i - 1) * ROW_H))
        Style.Rule(r, "BOTTOM", "line")
        r.day = Style.Text(r, 12, "muted")
        r.day:SetPoint("LEFT")
        r.day:SetWidth(90)
        r.day:SetJustifyH("LEFT")
        r.text = Style.Text(r, 13, "text")
        r.text:SetPoint("LEFT", 96, 0)
        r.text:SetWidth(width - 260)
        r.text:SetWordWrap(false)
        r.text:SetJustifyH("LEFT")
        r.where = Style.Text(r, 11, "muted")
        r.where:SetPoint("RIGHT")
        r.where:SetWidth(160)
        r.where:SetJustifyH("RIGHT")
        r.where:SetWordWrap(false)
        storyRows[i] = r
    end
    local storyFoot = Style.Text(story, 11, "muted")
    storyFoot:SetPoint("BOTTOMLEFT")
    story:EnableMouseWheel(true)
    story:SetScript("OnMouseWheel", function(_, delta)
        offset = math.max(0, offset - delta * 3)
        Paint()
    end)

    local function PaintStory()
        for _, f in ipairs(filters) do f.button:SetKind(f.key == filter and "primary" or "plain") end
        local list = J.Story(filter)
        offset = math.max(0, math.min(offset, #list - maxRows))
        for i, r in ipairs(storyRows) do
            local e = list[offset + i]
            r:SetShown(e ~= nil)
            if e then
                r.day:SetText(Day(e.t))
                local text = e.s or ""
                if e.k == "level" then text = "|cffe3b04b" .. text .. "|r" .. (e.photo and "  |cff9a9688photo taken|r" or "") end
                if e.k == "loot" and e.q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[e.q] then
                    text = text:gsub(": (.+)$", ": " .. ITEM_QUALITY_COLORS[e.q].hex .. "%1|r")
                end
                r.text:SetText(text)
                r.where:SetText(e.z or "")
            end
        end
        storyFoot:SetText(#list == 0 and "Nothing here yet. It fills in as you play."
            or ("%d moment%s. Scroll for older ones."):format(#list, #list == 1 and "" or "s"))
    end

    -----------------------------------------------------------------
    -- By level: a row per level, newest first, and the totals.
    -----------------------------------------------------------------
    local levels = View("levels")
    local COLS = { { "LEVEL", 56, "LEFT" }, { "TIME", 78 }, { "XP", 76 }, { "XP/HOUR", 68 },
                   { "GOLD IN", 82 }, { "GOLD OUT", 82 }, { "NET", 82 }, { "KILLS", 54 },
                   { "QUESTS", 56 }, { "DEATHS", 56 } }
    local colX, x = {}, 0
    local spare = math.floor((width - 690) / (#COLS - 1))
    for i, col in ipairs(COLS) do
        colX[i] = x
        x = x + col[2] + spare
    end
    local function Cells(parent, size, color, bold)
        local cells = {}
        for i, col in ipairs(COLS) do
            local t = Style.Text(parent, size, color, nil, bold)
            t:SetWidth(col[2])
            t:SetJustifyH(col[3] or "RIGHT")
            t:SetPoint("LEFT", colX[i], 0)
            t:SetWordWrap(false)
            cells[i] = t
        end
        return cells
    end
    local header = CreateFrame("Frame", nil, levels)
    header:SetSize(width, 22)
    header:SetPoint("TOPLEFT")
    Style.Rule(header, "BOTTOM", "lineStrong")
    for i, t in ipairs(Cells(header, 10, "gold", true)) do t:SetText(COLS[i][1]) end
    local levelFoot = Style.Text(levels, 11, "muted")
    levelFoot:SetPoint("BOTTOMLEFT")
    levelFoot:SetWidth(width)
    levelFoot:SetJustifyH("LEFT")
    local totalRow = CreateFrame("Frame", nil, levels)
    totalRow:SetSize(width, ROW_H + 4)
    totalRow:SetPoint("BOTTOMLEFT", 0, 22)
    Style.Rule(totalRow, "TOP", "lineStrong")
    local totalCells = Cells(totalRow, 13, "text", true)
    local levelRows = {}
    local levelMax = math.max(1, math.floor((height - 52 - 22 - (ROW_H + 4) - 30) / ROW_H))
    for i = 1, levelMax do
        local r = CreateFrame("Frame", nil, levels)
        r:SetSize(width, ROW_H)
        r:SetPoint("TOPLEFT", 0, -(24 + (i - 1) * ROW_H))
        Style.Rule(r, "BOTTOM", "line")
        r.cells = Cells(r, 13, "text")
        levelRows[i] = r
    end
    local levelOffset = 0
    levels:EnableMouseWheel(true)
    levels:SetScript("OnMouseWheel", function(_, delta)
        levelOffset = math.max(0, levelOffset - delta * 3)
        Paint()
    end)

    local function PerHour(xp, seconds)
        if not xp or xp <= 0 or not seconds or seconds < 60 then return "-" end
        return Count(xp / (seconds / 3600))
    end
    local function Money(copper)
        return (copper or 0) > 0 and Coins(copper) or "-"
    end
    local function Net(gained, spent)
        local net = (gained or 0) - (spent or 0)
        if net == 0 then return "-" end
        return (net < 0 and "|cffff6b6b" or "|cff56944f") .. Coins(net) .. "|r"
    end
    local function FillRow(cells, label, row)
        local values = { label, Hours(row.seconds), row.xp and row.xp > 0 and Count(row.xp) or "-",
                         PerHour(row.xp, row.seconds), Money(row.earned), Money(row.spent),
                         Net(row.earned, row.spent), Count(row.foes), Count(row.quests), Count(row.deaths) }
        for i, cell in ipairs(cells) do cell:SetText(values[i]) end
    end

    local function PaintLevels()
        local all = J.Book().levels or {}
        local list, total = {}, {}
        for level, row in pairs(all) do
            list[#list + 1] = { level = level, row = row }
            for _, k in ipairs({ "seconds", "xp", "earned", "spent", "foes", "quests", "deaths" }) do
                total[k] = (total[k] or 0) + (row[k] or 0)
            end
        end
        table.sort(list, function(a, b) return a.level > b.level end)
        levelOffset = math.max(0, math.min(levelOffset, #list - levelMax))
        local now = UnitLevel("player")
        for i, r in ipairs(levelRows) do
            local e = list[levelOffset + i]
            r:SetShown(e ~= nil)
            if e then
                local label = tostring(e.level) .. (e.row.partial and "*" or "") .. (e.level == now and "+" or "")
                FillRow(r.cells, label, e.row)
            end
        end
        FillRow(totalCells, "Total", total)
        levelFoot:SetText(("* the Journal began partway through this level   + in progress.   %d level%s recorded."):format(#list, #list == 1 and "" or "s"))
    end

    -----------------------------------------------------------------
    -- Characters.
    -----------------------------------------------------------------
    local chars = View("characters")
    local charHead = Style.Text(chars, 13, "muted")
    charHead:SetPoint("TOPLEFT")
    local cardW = math.floor((width - GAP) / 2)
    local cardRows = math.floor((height - 52 - 30) / (CARD_H + GAP))
    local cards = {}
    for i = 1, cardRows * 2 do
        local c = CreateFrame("Frame", nil, chars)
        c:SetSize(cardW, CARD_H)
        c:SetPoint("TOPLEFT", ((i - 1) % 2) * (cardW + GAP), -(28 + math.floor((i - 1) / 2) * (CARD_H + GAP)))
        Style.Fill(c, "well")
        c.edges = Style.Border(c, "line")
        c.name = Style.Text(c, 14, "text", nil, true)
        c.name:SetPoint("TOPLEFT", 12, -10)
        c.sub = Style.Text(c, 12, "muted")
        c.sub:SetPoint("LEFT", c.name, "RIGHT", 8, 0)
        c.line = Style.Text(c, 12, "muted")
        c.line:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -5)
        c.line:SetWidth(cardW - 24)
        c.line:SetWordWrap(false)
        c.line:SetJustifyH("LEFT")
        c.profs = Style.Text(c, 11, "muted")
        c.profs:SetPoint("TOPLEFT", c.line, "BOTTOMLEFT", 0, -4)
        c.profs:SetWidth(cardW - 24)
        c.profs:SetWordWrap(false)
        c.profs:SetJustifyH("LEFT")
        c.track = CreateFrame("Frame", nil, c)
        c.track:SetSize(cardW - 24, 4)
        c.track:SetPoint("BOTTOMLEFT", 12, 10)
        Style.Fill(c.track, "line")
        c.fill = c.track:CreateTexture(nil, "ARTWORK")
        c.fill:SetPoint("TOPLEFT")
        c.fill:SetPoint("BOTTOMLEFT")
        c.fill:SetColorTexture(Style.Color("blue"))
        c.rest = Style.Text(c, 11, "muted")
        c.rest:SetPoint("BOTTOMRIGHT", c.track, "TOPRIGHT", 0, 4)
        cards[i] = c
    end

    local function PaintCharacters()
        J.SaveCharacter()
        local list, total = {}, 0
        for _, c in pairs(J.Characters()) do
            list[#list + 1] = c
            total = total + (c.money or 0)
        end
        table.sort(list, function(a, b)
            if (a.level or 0) ~= (b.level or 0) then return (a.level or 0) > (b.level or 0) end
            return (a.name or "") < (b.name or "")
        end)
        charHead:SetText(("%d character%s, %s in all. Each joins the list the first time you log in on it.")
            :format(#list, #list == 1 and "" or "s", Compat.Money(total)))
        local me = Compat.MyName()
        for i, card in ipairs(cards) do
            local c = list[i]
            card:SetShown(c ~= nil)
            if c then
                card.name:SetText(ClassColor(c.classFile) .. (c.name or "?") .. "|r")
                card.sub:SetText(("Level %d %s%s"):format(c.level or 0, c.class or "", c.name == me and " · you're on this one" or ""))
                Style.SetBorder(card.edges, c.name == me and "gold" or "line")
                card.line:SetText(("%s · %s"):format(c.zone or "somewhere", Compat.Money(c.money or 0)))
                local profs = {}
                for _, p in ipairs(c.professions or {}) do profs[#profs + 1] = ("%s %d"):format(p.name, p.skill or 0) end
                card.profs:SetText(#profs > 0 and table.concat(profs, ", ") or "No professions")
                local rested = J.RestedNow(c)
                card.track:SetShown(rested ~= nil)
                card.rest:SetShown(rested ~= nil)
                if rested then
                    card.fill:SetWidth(math.max(1, (cardW - 24) * math.min(1, rested / 1.5)))
                    card.rest:SetText(rested >= 1.5 and "Fully rested" or ("Rested %d%%"):format(math.floor(rested * 100)))
                end
            end
        end
    end

    Paint = function()
        for key, b in pairs(tabs) do b:SetKind(key == current and "primary" or "plain") end
        for key, v in pairs(views) do v:SetShown(key == current) end
        if not J.running then return end
        if current == "summary" then PaintSummary()
        elseif current == "story" then PaintStory()
        elseif current == "levels" then PaintLevels()
        else PaintCharacters() end
    end
    page.Refresh = function() xpcall(Paint, ns.Report) end

    local off = Style.Text(page, 13, "muted")
    off:SetPoint("TOPLEFT", page.heading, "BOTTOMLEFT", 0, -52)
    off:SetText("The Journal is switched off in Settings.")
    page:HookScript("OnShow", function() off:SetShown(not J.running) end)
    off:SetShown(not J.running)
end)
