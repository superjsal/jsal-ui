-- The Journal page, in four tabs: Summary (who you are, how far to the
-- next level, your levels as a chart, your numbers and favourites), Story (the moments by day, newest first, by kind), By level
-- (what each level took, and brought) and Characters
-- (every character on the account, a row each: level, where it is, its
-- gold, its professions and its rested XP).
local _, ns = ...
local Style, Compat, Window = ns.Style, ns.Compat, ns.Window

local TAB_W, GAP, MODEL_W = 130, 8, 170

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

-- How long ago a time was, in the words you'd use: "today", "3 days ago",
-- "2 weeks ago", "4 months ago".
local function Ago(t)
    local days = math.floor((Compat.ServerTime() - t) / 86400)
    if days <= 0 then return "today" end
    if days == 1 then return "yesterday" end
    if days < 14 then return days .. " days ago" end
    if days < 60 then return math.floor(days / 7) .. " weeks ago" end
    return math.floor(days / 30) .. " months ago"
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
        local b = Style.Button(page, tab[2], "tab", TAB_W)
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
    -- Summary: who you are, how far to the next level, three things about
    -- you, your levels as a chart, your numbers with a picture each, and
    -- your favourites as bars. (It was a block of grey words beside the
    -- model and nine boxes of numbers. John, 14 Nov 2026: "anything we can
    -- do to make this more fun to look at as well?")
    local M = { cards = {}, bars = {}, tiles = {}, HERO_H = 196, CHART_H = 64, TILE_H = 54, LIST_H = 26,
                ICONS = "Interface\\Icons\\" }
    M.TILE_ICON = { "Ability_DualWield", "Ability_Rogue_Sprint", "INV_Misc_Note_01", "INV_Misc_Head_Dragon_01", "Ability_Hunter_EagleEye",
                    "Ability_Rogue_FeignDeath", "INV_Misc_Coin_01", "Ability_Warrior_Challange", "Ability_Hunter_AspectOfTheMonkey" }
    local modelWell = CreateFrame("Frame", nil, summary)
    modelWell:SetPoint("TOPLEFT")
    modelWell:SetSize(MODEL_W, M.HERO_H)
    Style.Fill(modelWell, "well")
    Style.Border(modelWell, "cardLine")
    local model = CreateFrame("PlayerModel", nil, modelWell)
    model:SetPoint("TOPLEFT", 1, -1)
    model:SetPoint("BOTTOMRIGHT", -1, 1)
    -- Your pal, in the corner beside you.
    M.palBox = CreateFrame("Frame", nil, modelWell)
    M.palBox:SetSize(44, 44)
    M.palBox:SetPoint("BOTTOMRIGHT", -6, 6)
    M.palBox:SetFrameLevel((model:GetFrameLevel() or 1) + 2)
    M.pal = M.palBox:CreateTexture(nil, "ARTWORK")
    M.pal:SetAllPoints()

    M.heroX = MODEL_W + 18
    M.heroW = width - M.heroX
    local name = Style.Text(summary, 20, "text", nil, true)
    name:SetPoint("TOPLEFT", M.heroX, -2)
    local who = Style.Text(summary, 13, "secondary")
    who:SetPoint("TOPLEFT", M.heroX, -32)
    M.record = Style.Text(summary, 12, "muted")
    M.record:SetPoint("TOPRIGHT", 0, -33)
    M.record:SetJustifyH("RIGHT")
    -- Your pace, in XP a second: over the level you're on and the two
    -- before it, once that's ten minutes of play. It was this level alone,
    -- and a level begun with hours of standing about made the next one a
    -- week away: 3,121 XP in 7h 38m of trying out pals read "about 108h 17m
    -- at your pace", by someone whose last level took two hours. (John, 16
    -- Nov 2026, of that line in his own screenshot: "what is this?", then
    -- "Yes, fix it".)
    function M.Pace(levels, level)
        local xp, seconds = 0, 0
        for l = level, level - 2, -1 do
            local row = levels[l]
            if row then xp, seconds = xp + (row.xp or 0), seconds + (row.seconds or 0) end
        end
        return seconds >= 600 and xp > 0 and xp / seconds or nil
    end
    -- How far to the next level, and how long that is at your pace.
    M.track = CreateFrame("Frame", nil, summary)
    M.track:SetSize(M.heroW, 8)
    M.track:SetPoint("TOPLEFT", M.heroX, -58)
    Style.Fill(M.track, "line")
    M.fill = M.track:CreateTexture(nil, "ARTWORK")
    M.fill:SetPoint("TOPLEFT")
    M.fill:SetPoint("BOTTOMLEFT")
    M.fill:SetColorTexture(Style.Color("gold"))
    M.toNext = Style.Text(summary, 11, "secondary")
    M.toNext:SetPoint("TOPLEFT", M.heroX, -72)
    M.pace = Style.Text(summary, 11, "muted")
    M.pace:SetPoint("TOPRIGHT", 0, -72)
    M.pace:SetJustifyH("RIGHT")
    -- Three things about you, a card each: its heading, a picture, what it
    -- is and a line under it.
    M.cardW = math.floor((M.heroW - 16) / 3)
    for i = 1, 3 do
        local c = CreateFrame("Frame", nil, summary)
        c:SetSize(M.cardW, 70)
        c:SetPoint("TOPLEFT", M.heroX + (i - 1) * (M.cardW + 8), -96)
        Style.Fill(c, "well")
        c.head = Style.Text(c, 10, "gold", nil, true)
        c.head:SetPoint("TOPLEFT", 12, -8)
        -- The picture in the corner, so the words have the card's width:
        -- beside it they had two thirds, and "nothing has killed you" was cut.
        c.icon = c:CreateTexture(nil, "ARTWORK")
        c.icon:SetSize(22, 22)
        c.icon:SetPoint("TOPRIGHT", -8, -6)
        c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        c.what = Style.Text(c, 13, "text", nil, true)
        c.what:SetPoint("TOPLEFT", 12, -30)
        c.what:SetWidth(M.cardW - 24)
        c.what:SetWordWrap(false)
        c.note = Style.Text(c, 11, "muted")
        c.note:SetPoint("TOPLEFT", 12, -49)
        c.note:SetWidth(M.cardW - 24)
        c.note:SetWordWrap(false)
        M.cards[i] = c
    end
    function M.Card(i, head, what, note, icon)
        local c = M.cards[i]
        c.head:SetText(head)
        c.what:SetText(what)
        c.note:SetText(note)
        c.icon:SetTexture(icon or (M.ICONS .. "INV_Misc_QuestionMark"))
    end
    local since = Style.Text(summary, 11, "muted")
    since:SetPoint("TOPLEFT", M.heroX, -(M.HERO_H - 16))
    since:SetWidth(M.heroW)
    since:SetWordWrap(false)
    since:SetJustifyH("LEFT")

    -- Your levels: a bar a level for the time it took, the one you're on in
    -- gold and the fastest in green, a red dot over one you died on.
    M.chartY = M.HERO_H + 18
    M.chartHead = Style.Text(summary, 12, "gold", nil, true)
    M.chartHead:SetPoint("TOPLEFT", 0, -M.chartY)
    M.chartHead:SetText("YOUR LEVELS")
    M.legend = Style.Text(summary, 11, "muted")
    M.legend:SetPoint("LEFT", M.chartHead, "RIGHT", 14, 0)
    M.legend:SetText("time on each level")
    M.dot = summary:CreateTexture(nil, "ARTWORK")
    M.dot:SetSize(4, 4)
    M.dot:SetColorTexture(Style.Color("red"))
    M.dot:SetPoint("LEFT", M.legend, "RIGHT", 14, 0)
    M.dotText = Style.Text(summary, 11, "muted")
    M.dotText:SetPoint("LEFT", M.dot, "RIGHT", 5, 0)
    M.dotText:SetText("died on it")
    M.records = Style.Text(summary, 11, "muted")
    M.records:SetPoint("TOPRIGHT", 0, -(M.chartY + 1))
    M.records:SetJustifyH("RIGHT")
    M.base = summary:CreateTexture(nil, "ARTWORK")
    M.base:SetColorTexture(Style.Color("lineStrong"))
    M.base:SetPoint("TOPLEFT", 0, -(M.chartY + 24 + M.CHART_H))
    M.base:SetSize(width, 1)
    -- A level's place in the chart, as tall as the chart so it's easy to
    -- point at: its bar stands on the line, and pointing says what the
    -- level took.
    function M.Bar(i)
        if M.bars[i] then return M.bars[i] end
        local b = CreateFrame("Frame", nil, summary)
        b:SetHeight(M.CHART_H)
        b.fill = b:CreateTexture(nil, "ARTWORK")
        b.fill:SetPoint("BOTTOMLEFT")
        b.fill:SetPoint("BOTTOMRIGHT")
        b.dot = b:CreateTexture(nil, "OVERLAY")
        b.dot:SetSize(4, 4)
        b.dot:SetColorTexture(Style.Color("red"))
        b.dot:SetPoint("BOTTOM", b.fill, "TOP", 0, 3)
        b.label = Style.Text(b, 10, "muted")
        b.label:SetPoint("TOP", b, "BOTTOM", 0, -5)
        b:EnableMouse(true)
        b:SetScript("OnEnter", function(self)
            if not self.tip then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(self.tip[1])
            GameTooltip:AddLine(self.tip[2], 1, 1, 1)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        M.bars[i] = b
        return b
    end

    -- Your numbers, three across: a picture, the number, what it counts and
    -- a few words beside that.
    M.tilesY = M.chartY + 24 + M.CHART_H + 26
    M.tileW = math.floor((width - 2 * GAP) / 3)
    for i = 1, 9 do
        local t = CreateFrame("Frame", nil, summary)
        t:SetSize(M.tileW, M.TILE_H)
        t:SetPoint("TOPLEFT", ((i - 1) % 3) * (M.tileW + GAP), -(M.tilesY + math.floor((i - 1) / 3) * (M.TILE_H + GAP)))
        Style.Fill(t, "well")
        t.icon = t:CreateTexture(nil, "ARTWORK")
        t.icon:SetSize(30, 30)
        t.icon:SetPoint("LEFT", 12, 0)
        t.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        t.icon:SetTexture(M.ICONS .. M.TILE_ICON[i])
        t.n = Style.Text(t, 17, "gold", nil, true)
        t.n:SetPoint("TOPLEFT", 52, -7)
        t.label = Style.Text(t, 12, "text")
        t.label:SetPoint("TOPLEFT", 52, -31)
        -- Beside the number, where there's more room than beside the
        -- words under it ("Gold earned" left "most from ve...").
        t.note = Style.Text(t, 11, "muted")
        t.note:SetPoint("BOTTOMLEFT", t.n, "BOTTOMRIGHT", 8, 2)
        t.note:SetPoint("RIGHT", t, "RIGHT", -10, 0)
        t.note:SetWordWrap(false)
        t.note:SetJustifyH("RIGHT")
        M.tiles[i] = t
    end

    -- Your favourites, as bars: the longest is the most, in gold.
    M.listY = M.tilesY + 3 * (M.TILE_H + GAP) + 10
    M.halfW = math.floor((width - 24) / 2)
    function M.List(x, title, pictures)
        local head = Style.Text(summary, 12, "gold", nil, true)
        head:SetPoint("TOPLEFT", x, -M.listY)
        head:SetText(title)
        local rows = { NAME_X = pictures and 26 or 0 }
        for i = 1, 5 do
            local r = CreateFrame("Frame", nil, summary)
            r:SetSize(M.halfW, M.LIST_H)
            r:SetPoint("TOPLEFT", x, -(M.listY + 22 + (i - 1) * M.LIST_H))
            if i == 1 then Style.Rule(r, "TOP", "lineStrong") end
            if pictures then
                r.icon = r:CreateTexture(nil, "ARTWORK")
                r.icon:SetSize(18, 18)
                r.icon:SetPoint("LEFT", 0, 0)
                r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            end
            r.key = Style.Text(r, 12, "text")
            r.key:SetPoint("LEFT", rows.NAME_X, 0)
            r.key:SetWidth(138 - rows.NAME_X)
            r.key:SetWordWrap(false)
            r.key:SetJustifyH("LEFT")
            r.track = CreateFrame("Frame", nil, r)
            r.track:SetSize(M.halfW - 146 - 66, 6)
            r.track:SetPoint("LEFT", 146, 0)
            Style.Fill(r.track, "line")
            r.bar = r.track:CreateTexture(nil, "ARTWORK")
            r.bar:SetPoint("TOPLEFT")
            r.bar:SetPoint("BOTTOMLEFT")
            r.n = Style.Text(r, 12, "secondary")
            r.n:SetPoint("RIGHT")
            r.n:SetJustifyH("RIGHT")
            rows[i] = r
        end
        return rows
    end
    local usedRows = M.List(0, "MOST USED", true)
    local zoneRows = M.List(M.halfW + 24, "MOST TIME IN")
    M.foot = Style.Text(summary, 11, "muted")
    M.foot:SetPoint("TOPLEFT", 0, -(M.listY + 22 + 5 * M.LIST_H + 10))

    local function FillList(rows, entries, format, empty)
        local most = entries[1] and entries[1].n or 0
        for i, r in ipairs(rows) do
            local e = entries[i]
            r:SetShown(e ~= nil or i == 1)
            r.key:SetText(e and e.key or empty)
            r.n:SetText(e and format(e.n) or "")
            r.n:SetTextColor(Style.Color(i == 1 and "gold" or "secondary"))
            r.track:SetShown(e ~= nil)
            if e then
                r.bar:SetWidth(math.max(1, (M.halfW - 146 - 66) * (most > 0 and e.n / most or 0)))
                r.bar:SetColorTexture(Style.Color(i == 1 and "gold" or "lineStrong"))
            end
            if r.icon then
                r.icon:SetShown(e ~= nil)
                -- A move's picture, by its name: the game knows the ones you know.
                if e then r.icon:SetTexture(select(2, Compat.SpellInfo(e.key)) or (M.ICONS .. "INV_Misc_QuestionMark")) end
            end
        end
    end

    local function PaintSummary()
        local book = J.Book()
        local levels = book.levels or {}
        local className, classFile = UnitClass("player")
        local level = UnitLevel("player") or 1
        model:SetUnit("player")
        model:SetRotation(0.35)
        -- The camera a little closer than the game's default, so the
        -- character fills its frame.
        if model.SetCamDistanceScale then pcall(model.SetCamDistanceScale, model, 0.75) end
        name:SetText(ClassColor(classFile) .. (Compat.MyName() or UnitName("player")) .. "|r")
        who:SetText(("Level %d %s"):format(level, className or ""))
        local seconds = J.Stat("seconds")
        M.record:SetText(Hours(seconds) .. " on record")

        -- To the next level: how far, and how long at your pace (M.Pace).
        local xp, max = UnitXP and UnitXP("player") or 0, UnitXPMax and UnitXPMax("player") or 0
        for _, region in ipairs({ M.track, M.toNext, M.pace }) do region:SetShown(max > 0) end
        if max > 0 then
            local part = math.max(0, math.min(1, xp / max))
            M.fill:SetWidth(math.max(1, M.heroW * part))
            M.toNext:SetText(("%d%% of the way to %d"):format(math.floor(part * 100), level + 1))
            local rate = M.Pace(levels, level)
            M.pace:SetText(rate and ("about %s at your pace"):format(Hours((max - xp) / rate)) or "")
        end

        -- Three things about you.
        local spells, zones = J.Top(book.spells, 5), J.Top(book.zones, 5)
        local killer = J.Top(book.killers, 1)[1]
        M.Card(1, "FAVOURITE MOVE", spells[1] and spells[1].key or "None yet",
            spells[1] and (Count(spells[1].n) .. " times") or "shows once you've cast a few",
            spells[1] and select(2, Compat.SpellInfo(spells[1].key)) or nil)
        M.Card(2, "HOME GROUND", zones[1] and zones[1].key or "Nowhere yet", zones[1] and (Hours(zones[1].n) .. " there") or "",
            M.ICONS .. "INV_Misc_Map_01")
        -- What you were fighting when you died, most often. Deaths from
        -- before that was counted have no name to them.
        local deaths = J.Total("deaths")
        M.Card(3, "NEMESIS", killer and killer.key or (deaths > 0 and "Not known yet" or "No one yet"),
            killer and ("%s death%s fighting it"):format(Count(killer.n), killer.n == 1 and "" or "s")
                or (deaths > 0 and "counted from now on" or "you haven't died"),
            M.ICONS .. "INV_Misc_Bone_HumanSkull_01")
        -- Under them: hearths and campfires, and the pal you keep.
        local extras = {}
        for _, e in ipairs({ { "hearths", "hearth", "hearths" }, { "camped", "campfire", "campfires" } }) do
            local n = J.Total(e[1])
            if n > 0 then extras[#extras + 1] = ("%s %s"):format(Count(n), n == 1 and e[2] or e[3]) end
        end
        local pal = ns.Pet and ns.Pet.Portrait and ns.Pet.Portrait() or nil
        M.palBox:SetShown(pal ~= nil)
        if pal then
            M.pal:SetTexture(pal.texture)
            extras[#extras + 1] = ("with %s the %s"):format(pal.name or "your pal", pal.form or "pal")
        end
        since:SetText(table.concat(extras, "  ·  "))

        -- The chart: every level up to yours, the ones the Journal has a
        -- row for as tall as the time they took.
        local top, last, sum, fastest, longest = 0, level, { seconds = 0, foes = 0, quests = 0, n = 0 }, nil, nil
        for lv, row in pairs(levels) do
            local took = row.seconds or 0
            last, top = math.max(last, lv), math.max(top, took)
            sum.seconds, sum.foes, sum.quests, sum.n = sum.seconds + took, sum.foes + (row.foes or 0), sum.quests + (row.quests or 0), sum.n + 1
            -- The fastest and the longest, of the levels seen start to end.
            if lv ~= level and not row.partial and took >= 60 then
                if not fastest or took < levels[fastest].seconds then fastest = lv end
                if not longest or took > levels[longest].seconds then longest = lv end
            end
        end
        local gap = last > 40 and 2 or 3
        local barW = math.max(2, math.min(24, math.floor((width - (last - 1) * gap) / last)))
        for i = 1, last do
            local b, row = M.Bar(i), levels[i]
            local took = row and row.seconds or 0
            b:SetWidth(barW)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", (i - 1) * (barW + gap), -(M.chartY + 24))
            b:Show()
            b.fill:SetHeight(math.max(2, top > 0 and M.CHART_H * took / top or 2))
            b.fill:SetColorTexture(Style.Color(i == level and "gold" or (i == fastest and "green") or (row and "lineStrong") or "line"))
            b.dot:SetShown(row ~= nil and (row.deaths or 0) > 0)
            -- A number under the first, each tenth and yours, where they don't crowd.
            local tenth = i == 1 or i % 10 == 0
            local mine = i == level and i > 2 and i % 10 > 1 and i % 10 < 9
            b.label:SetText((tenth or mine or (i == level and last < 10)) and i or "")
            b.label:SetTextColor(Style.Color(i == level and "text" or "muted"))
            b.tip = { "Level " .. i, row and ("%s%s  ·  %s kills  ·  %s quests  ·  %s deaths"):format(Hours(took), i == level and " so far" or "",
                Count(row.foes), Count(row.quests), Count(row.deaths)) or "Before the Journal began" }
        end
        for i = last + 1, #M.bars do M.bars[i]:Hide() end
        M.records:SetText((fastest and longest and fastest ~= longest)
            and ("fastest: %d in %s   ·   longest: %d in %s"):format(fastest, Hours(levels[fastest].seconds), longest, Hours(levels[longest].seconds)) or "")

        -- The numbers. The game's own totals cover the whole life of the
        -- character; a rate beside one is from the Journal's own counting,
        -- over the time it has counted.
        local source = J.MoneySource()
        local bosses = J.Bosses()
        local duelsWon, duelsLost = J.Total("duelsWon"), J.Total("duelsLost")
        local hours = seconds / 3600
        local function Rate(n, per, unit)
            if per <= 0 or n <= 0 then return "" end
            return Count(math.floor(n / per + 0.5)) .. unit
        end
        local data = {
            { Count(J.Total("foes")), "Foes defeated", sum.seconds >= 3600 and Rate(sum.foes, sum.seconds / 3600, " an hour") or "" },
            { Miles(J.Stat("yards")), "Travelled", hours >= 1 and ("%.1f mph"):format(J.Stat("yards") / 1760 / hours) or "" },
            { Count(J.Total("quests")), "Quests done", sum.n >= 2 and Rate(sum.quests, sum.n, " a level") or "" },
            { Count(bosses), bosses == 1 and "Dungeon boss" or "Dungeon bosses", "" },
            { Count(J.Total("flights")), "Flights taken", "" },
            { Count(deaths), "Deaths", "" },
            { Gold(J.Total("earned")), "Gold earned", source and ("most from " .. source) or "" },
            { ("%d-%d"):format(duelsWon, duelsLost), "Duels won and lost", "" },
            { Count(J.Stat("jumps")), "Jumps", hours >= 1 and Rate(J.Stat("jumps"), hours, " an hour") or "" },
        }
        for i, t in ipairs(M.tiles) do
            t.n:SetText(data[i][1])
            t.label:SetText(data[i][2])
            t.note:SetText(data[i][3])
        end
        FillList(usedRows, spells, Count, "Nothing cast yet")
        FillList(zoneRows, zones, Hours, "Nowhere yet")
        M.foot:SetText(("Distance and jumps are counted since %s."):format((date("%d %B %Y", book.since or Compat.ServerTime()):gsub("^0", ""))))
    end

    -----------------------------------------------------------------
    -- Story: the moments by day, newest first. A day has a heading; a
    -- moment has its time, a square in its kind's colour (the filter
    -- buttons wear the same), its words, and where it was when the words
    -- don't already say. The same thing several times in a day is one row
    -- that says how many. (It was one flat list with "today" down the left
    -- of every row and the place on all of them: John's screenshot,
    -- 14 Nov 2026.)
    -----------------------------------------------------------------
    local story = View("story")
    local S = { filters = {}, rows = {}, heads = {}, offset = 0, TOP = 30, HEAD_H = 34, ROW_H = 26, TALL_H = 42, TEXT_X = 86 }
    S.room = height - 52 - S.TOP - 24
    S.TINT = { level = { Style.Color("gold") }, kill = { Style.Color("red") }, boss = { Style.Color("red") },
               loot = { 0.30, 0.62, 1 }, death = { Style.Color("muted") }, pet = { 0.94, 0.42, 0.54 } }
    S.OTHER = { 0.36, 0.76, 0.69 }
    for i, f in ipairs({ { nil, "All" }, { "levels", "Levels", "level" }, { "kills", "Kills", "kill" }, { "loot", "Loot", "loot" },
                         { "deaths", "Deaths", "death" }, { "pals", "Pals", "pet" }, { "more", "More" } }) do
        local b = Style.Button(story, f[2], "tab", 84)
        b:SetHeight(24)
        b:SetPoint("TOPLEFT", (i - 1) * 90, 0)
        if f[3] then
            local c = S.TINT[f[3]]
            local mark = b:CreateTexture(nil, "ARTWORK")
            mark:SetSize(7, 7)
            mark:SetPoint("LEFT", 9, 0)
            mark:SetColorTexture(c[1], c[2], c[3])
            -- The word moves over for it.
            if b.label then
                b.label:ClearAllPoints()
                b.label:SetPoint("CENTER", 7, 0)
            end
        end
        b:SetScript("OnClick", function()
            S.filter, S.offset = f[1], 0
            Paint()
        end)
        S.filters[#S.filters + 1] = { key = f[1], button = b }
    end
    S.count = Style.Text(story, 12, "muted")
    S.count:SetPoint("TOPRIGHT", 0, -5)
    S.count:SetJustifyH("RIGHT")
    local storyFoot = Style.Text(story, 11, "muted")
    storyFoot:SetPoint("BOTTOMLEFT")
    story:EnableMouseWheel(true)
    story:SetScript("OnMouseWheel", function(_, delta)
        S.offset = math.max(0, S.offset - delta * 3)
        Paint()
    end)

    -- A day's heading: "TODAY", "YESTERDAY" or "12 NOVEMBER".
    function S.DayHead(t)
        local word = Day(t)
        if word == "today" or word == "yesterday" then return word:upper() end
        local form = date("%Y", t) == date("%Y", Compat.ServerTime()) and "%d %B" or "%d %B %Y"
        return ((date(form, t):gsub("^0", "")):upper())
    end

    -- The time of day, by the clock the game is set to show.
    function S.Clock(t)
        local h, m = tonumber(date("%H", t)) or 0, date("%M", t)
        if GetCVarBool and GetCVarBool("timeMgrUseMilitaryTime") then return ("%d:%s"):format(h, m) end
        return ("%d:%s %s"):format((h + 11) % 12 + 1, m, h < 12 and "am" or "pm")
    end

    -- What the page lists, from the moments newest first: a heading where a
    -- day starts, then a row a moment. The same words again in a day join
    -- the row that already has them. A pal's moment of two sentences has its
    -- second on a line of its own.
    function S.Items(list)
        local items, day, head, byText = {}, nil, nil, nil
        for _, e in ipairs(list) do
            local t = e.t or 0
            local d = date("%Y%m%d", t)
            if d ~= day then
                day, head, byText = d, S.DayHead(t), {}
                items[#items + 1] = { head = head, h = S.HEAD_H }
            end
            local key = tostring(e.k) .. ":" .. tostring(e.s)
            local same = byText[key]
            if same then
                same.n = same.n + 1
                if e.z and not same.seen[e.z] then
                    same.seen[e.z] = true
                    same.places[#same.places + 1] = e.z
                end
            else
                local text, more = e.s or "", nil
                if e.k == "pet" then
                    local first, rest = text:match("^(.-[%.!]) (.+)$")
                    if first then text, more = first, rest end
                end
                local it = { e = e, n = 1, day = head, text = text, more = more, places = { e.z }, seen = {},
                             h = more and S.TALL_H or S.ROW_H }
                if e.z then it.seen[e.z] = true end
                byText[key] = it
                items[#items + 1] = it
            end
        end
        return items
    end

    function S.Head(i)
        local h = S.heads[i]
        if h then return h end
        h = CreateFrame("Frame", nil, story)
        h:SetSize(width, S.HEAD_H - 6)
        Style.Rule(h, "BOTTOM", "lineStrong")
        h.text = Style.Text(h, 11, "secondary", nil, true)
        h.text:SetPoint("BOTTOMLEFT", 0, 7)
        S.heads[i] = h
        return h
    end

    function S.Row(i)
        local r = S.rows[i]
        if r then return r end
        r = CreateFrame("Frame", nil, story)
        r:SetSize(width, S.ROW_H)
        Style.Rule(r, "BOTTOM", "line")
        r.time = Style.Text(r, 11, "muted")
        r.time:SetPoint("TOPRIGHT", r, "TOPLEFT", 58, -7)
        r.time:SetJustifyH("RIGHT")
        r.mark = r:CreateTexture(nil, "ARTWORK")
        r.mark:SetSize(7, 7)
        r.mark:SetPoint("TOPLEFT", 68, -10)
        r.text = Style.Text(r, 13, "text")
        r.text:SetPoint("TOPLEFT", S.TEXT_X, -5)
        r.text:SetWordWrap(false)
        r.text:SetJustifyH("LEFT")
        r.more = Style.Text(r, 11, "muted")
        r.more:SetPoint("TOPLEFT", S.TEXT_X, -24)
        r.more:SetWidth(width - S.TEXT_X - 190)
        r.more:SetWordWrap(false)
        r.more:SetJustifyH("LEFT")
        -- How many times, on a row that stands for several.
        r.times = CreateFrame("Frame", nil, r)
        r.times:SetPoint("TOPLEFT", r.text, "TOPRIGHT", 8, -1)
        Style.Fill(r.times, "line")
        r.times.text = Style.Text(r.times, 10, "text")
        r.times.text:SetPoint("CENTER")
        r.where = Style.Text(r, 11, "muted")
        r.where:SetPoint("TOPRIGHT", 0, -7)
        r.where:SetWidth(180)
        r.where:SetJustifyH("RIGHT")
        r.where:SetWordWrap(false)
        S.rows[i] = r
        return r
    end

    local function PaintStory()
        for _, f in ipairs(S.filters) do f.button:SetSelected(f.key == S.filter) end
        local list = J.Story(S.filter)
        local items = S.Items(list)
        -- The furthest down the list can start with the page still full,
        -- with room kept for the day's heading at the top.
        local room, last = S.room - S.HEAD_H, #items + 1
        while last > 1 and room >= items[last - 1].h do
            last = last - 1
            room = room - items[last].h
        end
        S.offset = math.max(0, math.min(S.offset, last - 1))
        local y, at, heads, rows = 0, S.offset + 1, 0, 0
        local function Head(text)
            heads = heads + 1
            local h = S.Head(heads)
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", 0, -(S.TOP + y))
            h.text:SetText(text)
            h:Show()
            y = y + S.HEAD_H
        end
        -- A page that starts partway through a day still names the day.
        if items[at] and not items[at].head then Head(items[at].day) end
        while items[at] and y + items[at].h <= S.room do
            local it = items[at]
            if it.head then
                Head(it.head)
            else
                rows = rows + 1
                local r, e = S.Row(rows), it.e
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", 0, -(S.TOP + y))
                r:SetHeight(it.h)
                r.time:SetText(S.Clock(e.t or 0))
                local c = S.TINT[e.k] or S.OTHER
                r.mark:SetColorTexture(c[1], c[2], c[3])
                local text = it.text
                if e.k == "level" then text = "|cffe3b04b" .. text .. "|r" .. (e.photo and "  |cff9a9688photo taken|r" or "") end
                if e.k == "loot" and e.q then
                    text = text:gsub(": (.+)$", ": |cff" .. Style.Quality(e.q) .. "%1|r")
                end
                -- Where it was, unless the words already name the place.
                local place = table.concat(it.places, ", ")
                if #it.places == 1 and it.text:find(it.places[1], 1, true) then place = "" end
                r.where:SetText(place)
                -- Its own width first: a row is used again, and a line cut
                -- to the last one's width would measure no wider than that.
                r.text:SetWidth(0)
                r.text:SetText(text)
                local room = width - S.TEXT_X - (place ~= "" and 190 or 8) - (it.n > 1 and 40 or 0)
                local wide = r.text.GetStringWidth and r.text:GetStringWidth()
                r.text:SetWidth((type(wide) == "number" and wide > 0) and math.min(room, wide + 2) or room)
                r.more:SetText(it.more or "")
                r.times:SetShown(it.n > 1)
                if it.n > 1 then
                    r.times.text:SetText("×" .. it.n)
                    local w = r.times.text.GetStringWidth and r.times.text:GetStringWidth()
                    r.times:SetSize(((type(w) == "number" and w > 0) and w or 16) + 12, 16)
                end
                r:Show()
                y = y + it.h
            end
            at = at + 1
        end
        for i = heads + 1, #S.heads do S.heads[i]:Hide() end
        for i = rows + 1, #S.rows do S.rows[i]:Hide() end
        S.count:SetText(#list == 0 and "" or ("%d moment%s"):format(#list, #list == 1 and "" or "s"))
        storyFoot:SetText(#list == 0 and "Nothing here yet. It fills in as you play."
            or ((items[at] or S.offset > 0) and "Scroll for older and newer days." or ""))
    end

    -----------------------------------------------------------------
    -- By level: the levels in tens, newest first, each ten a line with its
    -- own sums that opens to a row a level; the ten you're in starts open.
    -- Then the totals. (John, 14 Nov 2026, of thirty rows: "i think we can
    -- sort the levels by 10s and have drop downs so it doesnt get too hard
    -- to read".) With the tens to break the page up there's room to
    -- breathe: a ten's line is taller with a gap over it, a level has a thin
    -- rule under it where every other one had a band (of the tens, drawn
    -- tight: "we can make this visually less constricting now that we can
    -- group"). The level
    -- you're on is marked, XP an hour has a bar beside it, gold and silver
    -- each have a place of their own so a column reads down, the net has
    -- its sign and colour, and a death is red. (John's screenshot,
    -- 14 Nov 2026: ten columns of grey numbers, "4g 31s" beside "84s 10c".)
    -----------------------------------------------------------------
    local levels = View("levels")
    local L = { rows = {}, open = {}, offset = 0, ROW_H = 30, GROUP_H = 36, GROUP_GAP = 12, TOP = 24, BAR_W = 36, GOLD = 34 }
    -- Where each column ends; the level's is where it starts.
    L.X = { level = 12, time = 144, xp = 214, bar = width - 504, rate = width - 416, earned = width - 338, spent = width - 258,
            net = width - 178, foes = width - 130, quests = width - 70, deaths = width - 8 }
    -- The room for the lines, over the totals and the words under them.
    L.room = height - 52 - L.TOP - (L.ROW_H + 14) - 44
    L.max = math.max(1, math.floor(L.room / L.ROW_H))

    -- One row's words, on a frame: each a line of text ending at its column.
    function L.Cells(parent, size, bold)
        local cells = {}
        local function Right(x)
            local t = Style.Text(parent, size, "secondary", nil, bold)
            t:SetPoint("RIGHT", parent, "LEFT", x, 0)
            t:SetJustifyH("RIGHT")
            return t
        end
        cells.level = Style.Text(parent, size + 1, "text", nil, true)
        cells.level:SetPoint("LEFT", L.X.level, 0)
        cells.time, cells.xp, cells.rate = Right(L.X.time), Right(L.X.xp), Right(L.X.rate)
        for _, key in ipairs({ "earned", "spent", "net" }) do
            cells[key .. "Gold"] = Right(L.X[key] - L.GOLD)
            cells[key] = Right(L.X[key])
        end
        cells.foes, cells.quests, cells.deaths = Right(L.X.foes), Right(L.X.quests), Right(L.X.deaths)
        return cells
    end

    local header = CreateFrame("Frame", nil, levels)
    header:SetSize(width, 20)
    header:SetPoint("TOPLEFT")
    Style.Rule(header, "BOTTOM", "lineStrong")
    for _, col in ipairs({ { "LEVEL", "level", true }, { "TIME", "time" }, { "XP", "xp" }, { "XP AN HOUR", "rate" }, { "GOLD IN", "earned" },
                           { "GOLD OUT", "spent" }, { "NET", "net" }, { "KILLS", "foes" }, { "QUESTS", "quests" }, { "DEATHS", "deaths" } }) do
        local t = Style.Text(header, 10, "muted", nil, true)
        if col[3] then
            t:SetPoint("LEFT", L.X[col[2]], 0)
        else
            t:SetPoint("RIGHT", header, "LEFT", L.X[col[2]], 0)
            t:SetJustifyH("RIGHT")
        end
        t:SetText(col[1])
    end
    for i = 1, L.max do
        -- A level's row, or the line for a ten of them, which a click opens
        -- and closes.
        local r = CreateFrame("Button", nil, levels)
        r:SetScript("OnClick", function(self)
            if not self.ten then return end
            L.open[self.ten] = not self.opened
            Paint()
        end)
        r:SetSize(width, L.ROW_H)
        Style.Rule(r, "BOTTOM", "line")
        r.band = Style.Fill(r, "well")
        r.edge = r:CreateTexture(nil, "ARTWORK")
        r.edge:SetColorTexture(Style.Color("gold"))
        r.edge:SetPoint("TOPLEFT")
        r.edge:SetPoint("BOTTOMLEFT")
        r.edge:SetWidth(3)
        r.cells = L.Cells(r, 12)
        -- The level you're on.
        r.now = CreateFrame("Frame", nil, r)
        r.now:SetPoint("LEFT", r.cells.level, "RIGHT", 8, 0)
        Style.Fill(r.now, "gold")
        r.now.text = Style.Text(r.now, 10, "onGold", nil, true)
        r.now.text:SetPoint("CENTER")
        r.now.text:SetText("now")
        local wide = r.now.text.GetStringWidth and r.now.text:GetStringWidth()
        r.now:SetSize(((type(wide) == "number" and wide > 0) and wide or 20) + 12, 16)
        -- How fast the level went, beside the fastest of them.
        r.track = CreateFrame("Frame", nil, r)
        r.track:SetSize(L.BAR_W, 4)
        r.track:SetPoint("LEFT", L.X.bar, 0)
        Style.Fill(r.track, "line")
        r.bar = r.track:CreateTexture(nil, "ARTWORK")
        r.bar:SetPoint("TOPLEFT")
        r.bar:SetPoint("BOTTOMLEFT")
        r.bar:SetColorTexture(Style.Color("gold"))
        L.rows[i] = r
    end
    local totalRow = CreateFrame("Frame", nil, levels)
    totalRow:SetSize(width, L.ROW_H + 6)
    Style.Rule(totalRow, "TOP", "lineStrong")
    L.total = L.Cells(totalRow, 12, true)
    local levelFoot = Style.Text(levels, 11, "muted")
    levelFoot:SetWidth(width)
    levelFoot:SetJustifyH("LEFT")
    levels:EnableMouseWheel(true)
    levels:SetScript("OnMouseWheel", function(_, delta)
        L.offset = math.max(0, L.offset - delta * 3)
        Paint()
    end)

    -- XP an hour, or nil for a level with none, or under a minute of it.
    function L.Rate(xp, seconds)
        if not xp or xp <= 0 or not seconds or seconds < 60 then return nil end
        return xp / (seconds / 3600)
    end

    -- An amount in a money column: the gold in its place and the silver in
    -- its, so both line up down the page. Under a gold it's silver alone,
    -- and under a silver, copper. Nothing is a grey dash.
    function L.Money(cells, key, copper, sign, color)
        copper = math.floor(math.abs(copper or 0))
        local g, s, c = math.floor(copper / 10000), math.floor(copper % 10000 / 100), copper % 100
        local gold, small = "", "-"
        if g > 0 then gold, small = ("%s%dg"):format(sign, g), ("%02ds"):format(s)
        elseif s > 0 then small = ("%s%ds"):format(sign, s)
        elseif c > 0 then small = ("%s%dc"):format(sign, c) end
        for _, cell in ipairs({ cells[key .. "Gold"], cells[key] }) do
            cell:SetTextColor(Style.Color(copper > 0 and color or "muted"))
            cell:SetAlpha(copper > 0 and 1 or 0.6)
        end
        cells[key .. "Gold"]:SetText(gold)
        cells[key]:SetText(small)
    end

    function L.Fill(cells, label, row, color)
        cells.level:SetText(label)
        cells.time:SetText(Hours(row.seconds))
        cells.xp:SetText(row.xp and row.xp > 0 and Count(row.xp) or "-")
        local rate = L.Rate(row.xp, row.seconds)
        cells.rate:SetText(rate and Count(rate) or "-")
        for _, key in ipairs({ "time", "xp", "foes", "quests" }) do cells[key]:SetTextColor(Style.Color(color)) end
        cells.rate:SetTextColor(Style.Color("text"))
        L.Money(cells, "earned", row.earned, "", color)
        L.Money(cells, "spent", row.spent, "", color)
        local net = (row.earned or 0) - (row.spent or 0)
        L.Money(cells, "net", net, net < 0 and "–" or "+", net < 0 and "red" or "green")
        cells.foes:SetText(Count(row.foes))
        cells.quests:SetText(Count(row.quests))
        local deaths = row.deaths or 0
        cells.deaths:SetText(Count(deaths))
        cells.deaths:SetTextColor(Style.Color(deaths > 0 and "red" or "muted"))
        cells.deaths:SetAlpha(deaths > 0 and 1 or 0.6)
        return rate
    end

    local function PaintLevels()
        local all = J.Book().levels or {}
        local now = UnitLevel("player")
        local groups, byTen, total, best, began, count = {}, {}, {}, 0, nil, 0
        for level, row in pairs(all) do
            count = count + 1
            local ten = math.floor(level / 10) * 10
            local g = byTen[ten]
            if not g then
                g = { ten = ten, levels = {}, sum = {} }
                byTen[ten] = g
                groups[#groups + 1] = g
            end
            g.levels[#g.levels + 1] = { level = level, row = row }
            for _, k in ipairs({ "seconds", "xp", "earned", "spent", "foes", "quests", "deaths" }) do
                total[k] = (total[k] or 0) + (row[k] or 0)
                g.sum[k] = (g.sum[k] or 0) + (row[k] or 0)
            end
            best = math.max(best, L.Rate(row.xp, row.seconds) or 0)
            if row.partial then began = level end
        end
        table.sort(groups, function(a, b) return a.ten > b.ten end)
        -- The page's lines: a line a ten, and under an open one its levels.
        -- With levels in one ten only, there's nothing to fold.
        local items, tens = {}, #groups > 1
        for _, g in ipairs(groups) do
            table.sort(g.levels, function(a, b) return a.level > b.level end)
            local open = true
            if tens then
                open = L.open[g.ten]
                if open == nil then open = g.ten == math.floor(now / 10) * 10 end
                items[#items + 1] = { group = g, open = open }
            end
            if open then
                for k, e in ipairs(g.levels) do items[#items + 1] = { level = e.level, row = e.row, k = k } end
            end
        end
        -- How tall a line is: a ten's is taller, with a gap over it unless
        -- it heads the page.
        local function Tall(it, first)
            return it.group and (L.GROUP_H + (first and 0 or L.GROUP_GAP)) or L.ROW_H
        end
        -- The furthest down the page can start and still be full.
        local room, last = L.room, #items + 1
        while last > 1 and room >= Tall(items[last - 1]) do
            last = last - 1
            room = room - Tall(items[last])
        end
        L.offset = math.max(0, math.min(L.offset, last - 1))
        local y, used = 0, 0
        for i = L.offset + 1, #items do
            local it = items[i]
            local h = Tall(it, y == 0)
            if y + h > L.room or used >= #L.rows then break end
            used = used + 1
            local r = L.rows[used]
            local own = it.group and L.GROUP_H or L.ROW_H
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 0, -(L.TOP + y + h - own))
            r:SetHeight(own)
            r:Show()
            r.ten, r.opened = it.group and it.group.ten or nil, it.open
            r:EnableMouse(it.group ~= nil)
            local rate
            if it.group then
                -- A ten: "+" to open or "–" to close, its levels, and the
                -- same sums across as a level has.
                local ten = it.group.ten
                local label = ten == 0 and "1–9" or (ten >= 60 and "60" or (ten .. "–" .. (ten + 9)))
                rate = L.Fill(r.cells, Style.Tint("gold") .. (it.open and "–" or "+") .. "|r  " .. label, it.group.sum, "text")
                r.band:Show()
                r.band:SetAlpha(1)
                r.edge:Hide()
                r.now:Hide()
            else
                -- A level: the one you're on has a fill, a gold edge and a tag.
                local mine = it.level == now
                rate = L.Fill(r.cells, tostring(it.level), it.row, "secondary")
                r.band:SetShown(mine)
                r.band:SetAlpha(0.6)
                r.edge:SetShown(mine)
                r.now:SetShown(mine)
            end
            r.track:SetShown(rate ~= nil and best > 0)
            if rate and best > 0 then r.bar:SetWidth(math.max(1, L.BAR_W * rate / best)) end
            y = y + h
        end
        for i = used + 1, #L.rows do L.rows[i]:Hide() end
        local more = L.offset > 0 or L.offset + used < #items
        totalRow:ClearAllPoints()
        totalRow:SetPoint("TOPLEFT", 0, -(L.TOP + y + 10))
        L.Fill(L.total, "Total", total, "text")
        local notes = {}
        if all[now] then notes[#notes + 1] = "The level you're on is still in progress." end
        if began then notes[#notes + 1] = ("Level %d is where the Journal began, partway through."):format(began) end
        notes[#notes + 1] = ("%d level%s recorded%s."):format(count, count == 1 and "" or "s", more and ", scroll for the rest" or "")
        if tens then notes[#notes + 1] = "Click a ten to open or close it." end
        levelFoot:ClearAllPoints()
        levelFoot:SetPoint("TOPLEFT", 0, -(L.TOP + y + 10 + L.ROW_H + 6 + 14))
        levelFoot:SetText(table.concat(notes, "  "))
    end

    -----------------------------------------------------------------
    -- Characters.
    -----------------------------------------------------------------
    local chars = View("characters")
    -- A table, one row a character, the same thing in the same place down
    -- the list: who it is, its level, where it is, its gold, its professions
    -- and its rested XP. (They were cards, two across, most of them "0
    -- copper" and "No professions", and "you're on this one" ran past its
    -- card's edge: John's screenshot, 14 Nov 2026.)
    local CHAR_H = 54
    local COL = { name = 14, level = 232, where = 268, gold = 466, profs = 486, rest = width - 90 }
    local charCount = Style.Text(chars, 17, "text", nil, true)
    charCount:SetPoint("TOPLEFT", 0, 0)
    local charGold = Style.Text(chars, 13, "muted")
    charGold:SetPoint("BOTTOMLEFT", charCount, "BOTTOMRIGHT", 12, 1)
    local charCols = CreateFrame("Frame", nil, chars)
    charCols:SetSize(width, 18)
    charCols:SetPoint("TOPLEFT", 0, -36)
    for _, label in ipairs({ { "CHARACTER", COL.name }, { "LEVEL", COL.level, true }, { "WHERE", COL.where }, { "GOLD", COL.gold, true },
                             { "PROFESSIONS", COL.profs }, { "RESTED", COL.rest } }) do
        local t = Style.Text(charCols, 10, "muted", nil, true)
        if label[3] then
            t:SetPoint("TOPRIGHT", charCols, "TOPLEFT", label[2], 0)
            t:SetJustifyH("RIGHT")
        else
            t:SetPoint("TOPLEFT", label[2], 0)
        end
        t:SetText(label[1])
    end
    Style.Rule(charCols, "BOTTOM", "lineStrong")
    local charRows = math.max(1, math.floor((height - 52 - 58 - 30) / CHAR_H))
    local cards = {}
    for i = 1, charRows do
        local c = CreateFrame("Frame", nil, chars)
        c:SetSize(width, CHAR_H)
        c:SetPoint("TOPLEFT", 0, -(58 + (i - 1) * CHAR_H))
        -- The one you're on has a fill and a gold edge.
        c.fill = Style.Fill(c, "well")
        c.edge = c:CreateTexture(nil, "ARTWORK")
        c.edge:SetColorTexture(Style.Color("gold"))
        c.edge:SetPoint("TOPLEFT")
        c.edge:SetPoint("BOTTOMLEFT")
        c.edge:SetWidth(3)
        Style.Rule(c, "BOTTOM", "line")
        c.name = Style.Text(c, 14, "text", nil, true)
        c.name:SetPoint("TOPLEFT", COL.name, -9)
        c.name:SetWidth(COL.level - COL.name - 34)
        c.name:SetJustifyH("LEFT")
        c.name:SetWordWrap(false)
        -- Under the name: its class, and when you last played it, or a tag
        -- for the one you're on.
        c.sub = Style.Text(c, 11, "muted")
        c.sub:SetPoint("TOPLEFT", COL.name, -30)
        c.now = CreateFrame("Frame", nil, c)
        c.now:SetPoint("LEFT", c.sub, "RIGHT", 6, 0)
        Style.Fill(c.now, "gold")
        c.now.text = Style.Text(c.now, 10, "onGold", nil, true)
        c.now.text:SetPoint("CENTER")
        c.now.text:SetText("playing now")
        local wide = c.now.text.GetStringWidth and c.now.text:GetStringWidth()
        c.now:SetSize(((type(wide) == "number" and wide > 0) and wide or 62) + 14, 17)
        c.level = Style.Text(c, 15, "text", nil, true)
        c.level:SetPoint("RIGHT", c, "LEFT", COL.level, 0)
        c.level:SetJustifyH("RIGHT")
        c.where = Style.Text(c, 12, "secondary")
        c.where:SetPoint("LEFT", COL.where, 0)
        c.where:SetWidth(COL.gold - COL.where - 84)
        c.where:SetJustifyH("LEFT")
        c.where:SetWordWrap(false)
        c.gold = Style.Text(c, 12, "text")
        c.gold:SetPoint("RIGHT", c, "LEFT", COL.gold, 0)
        c.gold:SetJustifyH("RIGHT")
        c.profs = Style.Text(c, 11, "secondary")
        c.profs:SetPoint("LEFT", COL.profs, 0)
        c.profs:SetWidth(COL.rest - COL.profs - 10)
        c.profs:SetJustifyH("LEFT")
        if c.profs.SetMaxLines then c.profs:SetMaxLines(3) end
        c.track = CreateFrame("Frame", nil, c)
        c.track:SetSize(80, 5)
        c.track:SetPoint("TOPLEFT", COL.rest, -17)
        Style.Fill(c.track, "line")
        c.bar = c.track:CreateTexture(nil, "ARTWORK")
        c.bar:SetPoint("TOPLEFT")
        c.bar:SetPoint("BOTTOMLEFT")
        c.bar:SetColorTexture(Style.Color("blue"))
        c.rest = Style.Text(c, 11, "muted")
        cards[i] = c
    end
    local charFoot = Style.Text(chars, 11, "muted")

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
        charCount:SetText(("%d character%s"):format(#list, #list == 1 and "" or "s"))
        charGold:SetText(#list > 1 and (Compat.Money(total) .. " between them") or "")
        local me = Compat.MyName()
        for i, card in ipairs(cards) do
            local c = list[i]
            card:SetShown(c ~= nil)
            if c then
                local mine = c.name == me
                card.fill:SetShown(mine)
                card.edge:SetShown(mine)
                card.name:SetText(ClassColor(c.classFile) .. (c.name or "?") .. "|r")
                card.now:SetShown(mine)
                card.sub:SetText((c.class or "") .. ((mine or c.updated) and "  ·  " or "")
                    .. ((not mine and c.updated) and ("played " .. Ago(c.updated)) or ""))
                card.level:SetText(c.level or "?")
                -- A character too low to have done much is quieter.
                card.level:SetTextColor(Style.Color((c.level or 0) >= 10 and "text" or "muted"))
                card.where:SetText(c.zone or "somewhere")
                -- Nothing to show is said in grey, so it steps back.
                local money = c.money or 0
                card.gold:SetText(money > 0 and Compat.Money(money) or "none")
                card.gold:SetTextColor(Style.Color(money > 0 and "text" or "muted"))
                card.gold:SetAlpha(money > 0 and 1 or 0.6)
                local profs = {}
                for _, p in ipairs(c.professions or {}) do profs[#profs + 1] = ("%s %d"):format(p.name, p.skill or 0) end
                card.profs:SetText(#profs > 0 and table.concat(profs, ", ") or "none yet")
                card.profs:SetTextColor(Style.Color(#profs > 0 and "secondary" or "muted"))
                card.profs:SetAlpha(#profs > 0 and 1 or 0.6)
                -- Rested: a bar, and how much of a level it is. Nothing at
                -- 60, where there's no level left to rest for.
                local rested = J.RestedNow(c)
                card.track:SetShown(rested ~= nil)
                card.rest:ClearAllPoints()
                if rested then
                    card.bar:SetWidth(math.max(1, 80 * math.min(1, rested / 1.5)))
                    card.rest:SetPoint("TOPLEFT", COL.rest, -27)
                    card.rest:SetText(rested >= 1.5 and ("|cff" .. Style.Quality(3) .. "fully rested|r") or ("%d%% of a level"):format(math.floor(rested * 100)))
                    card.rest:SetAlpha(1)
                else
                    card.rest:SetPoint("LEFT", COL.rest, 0)
                    card.rest:SetText((c.level or 0) >= 60 and "" or "not known yet")
                    card.rest:SetAlpha(0.6)
                end
            end
        end
        local shown = math.min(#list, #cards)
        charFoot:ClearAllPoints()
        charFoot:SetPoint("TOPLEFT", 0, -(58 + shown * CHAR_H + 12))
        charFoot:SetText((#list > #cards and ("And %d more. "):format(#list - #cards) or "")
            .. "A character joins the list the first time you log in on it.")
    end

    Paint = function()
        for key, b in pairs(tabs) do b:SetSelected(key == current) end
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
