-- The Journal's By boss tab, By level's sibling: four records (first kills, the quickest fight, the boss
-- killed most, the hardest by wipes), then a line a dungeon or raid, the one you were in last first and
-- open, its count of bosses killed with a pip a boss beside it; open, a row a boss: its first kill, the
-- group it was with (all of them when pointed at), how long that fight took, kills, wipes, the last kill. A boss not yet killed is grey, "not yet". A raid has a "raid" tag. At 60
-- the dungeons you've been in at 60 come first, with a total line, then the dungeons of the climb. A
-- kill from before the Journal kept bosses is counted, from the game's statistics, without a date.
-- Only open dungeons' rows are drawn; the tab is built when first opened.
local _, ns = ...
local Style, Compat = ns.Style, ns.Compat

local B = { ROW_H = 30, LINE_H = 36, LINE_GAP = 10, TOP = 104, RECORD_H = 64, PIP_W = 8, PIP_GAP = 2 }

local function Clock(seconds)
    seconds = math.floor(seconds or 0)
    return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

local function Day(t)
    if not t then return "" end
    local now = Compat.ServerTime()
    if date("%Y%m%d", t) == date("%Y%m%d", now) then return "today" end
    if date("%Y%m%d", t + 86400) == date("%Y%m%d", now) then return "yesterday" end
    return (date("%d %b", t):gsub("^0", ""))
end

-- The dungeons and raids, each with its bosses as they stand: { d, bosses = { { id, name, rec, kills } },
-- killed, kills, wipes, last, at60 }. Only places with a boss killed or fought; `game` is the game's own
-- boss-kill statistics (or nil, pretending), for kills from before the Journal kept them.
function B.Places(life, game)
    local D = ns.Dungeons
    local bosses, since = life.bosses or {}, life.since60
    local out = {}
    for _, d in ipairs(ns.DungeonData or {}) do
        local p = { d = d, bosses = {}, killed = 0, kills = 0, wipes = 0, last = nil, at60 = false, any = false }
        for _, b in ipairs(d.bosses or {}) do
            local rec = bosses[b[1]]
            local kills = rec and rec.kills or 0
            if game and D and D.KillCount then kills = math.max(kills, D.KillCount(b[2], game, b[3]) or 0) end
            local row = { id = b[1], name = b[2], rec = rec, kills = kills }
            p.bosses[#p.bosses + 1] = row
            if kills > 0 then p.killed = p.killed + 1 end
            p.kills, p.wipes = p.kills + kills, p.wipes + (rec and rec.wipes or 0)
            if rec or kills > 0 then p.any = true end
            local seen = rec and (rec.last or rec.first)
            if seen and (not p.last or seen > p.last) then p.last = seen end
            if since and rec and ((rec.first or 0) >= since or (rec.last or 0) >= since or (rec.lv or 0) >= 60) then p.at60 = true end
        end
        if p.any then out[#out + 1] = p end
    end
    table.sort(out, function(a, b)
        if a.at60 ~= b.at60 then return a.at60 end
        if (a.last or 0) ~= (b.last or 0) then return (a.last or 0) > (b.last or 0) end
        return (a.d.level or 0) > (b.d.level or 0)
    end)
    return out
end

-- A first kill's group as the tooltip lists it: the names kept, a line each, then "and N more" for those
-- only counted (a name the game kept back, or past the four kept); a raid, its two counts. Nil for none.
function B.Group(w)
    if type(w) ~= "table" then return nil end
    local N = type(ns.Journal.Nights) == "table" and ns.Journal.Nights or nil
    if w.raid or #w == 0 then
        local said = N and N.With(w)
        return said and { said } or nil
    end
    local lines = {}
    for i = 1, #w do lines[i] = w[i] end
    local more = (w.others or #w) - #w
    if more > 0 then lines[#lines + 1] = ("and %d more"):format(more) end
    return lines
end

-- The four records, from the places' bosses.
function B.Records(places, life)
    local r = { first = 0, of = 0 }
    for _, p in ipairs(places) do
        if p.at60 or not life.since60 then r.of = r.of + #p.bosses end
        for _, b in ipairs(p.bosses) do
            local rec = b.rec
            if rec and rec.first and (not life.since60 or (rec.lv or 0) >= 60) then r.first = r.first + 1 end
            if rec and rec.fight and rec.fight > 0 and (not r.quick or rec.fight < r.quick.n) then r.quick = { name = b.name, n = rec.fight } end
            if b.kills > 0 and (not r.most or b.kills > r.most.n) then r.most = { name = b.name, n = b.kills } end
            if rec and (rec.wipes or 0) > 0 and (not r.hard or rec.wipes > r.hard.n) then r.hard = { name = b.name, n = rec.wipes } end
        end
    end
    return r
end

function ns.JournalByBoss(view, width, height, Repaint)
    local W = { rows = {}, open = {}, offset = 0, records = {} }
    -- A dungeon's pips start just after its count and end before GROUP at the most bosses any dungeon
    -- has (Blackrock Depths' 21: 208 across, so 340 to 548).
    W.X = { name = 12, first = 330, pips = 340, with = 566, fight = 720, kills = 800, wipes = 880, last = width - 8 }
    W.room = height - 52 - B.TOP - (B.LINE_H + 14) - 40
    W.max = math.max(1, math.floor(W.room / B.ROW_H))

    -- The records, four across.
    W.recordW = math.floor((width - 3 * 12) / 4)
    for i, rec in ipairs({ { "FIRST KILLS", "text" }, { "QUICKEST", "green" }, { "MOST KILLED", "text" }, { "HARDEST", "red" } }) do
        local c = CreateFrame("Frame", nil, view)
        c:SetSize(W.recordW, B.RECORD_H)
        c:SetPoint("TOPLEFT", (i - 1) * (W.recordW + 12), 0)
        Style.Box(c, 6, "well", "cardLine")
        c.head = Style.Text(c, 11, "gold", nil, true)
        c.head:SetPoint("TOPLEFT", 16, -14)
        c.head:SetText(rec[1])
        c.under = Style.Text(c, 12, "muted")
        c.under:SetPoint("TOPLEFT", 16, -33)
        c.under:SetWidth(W.recordW - 32 - 70)
        c.under:SetWordWrap(false)
        c.under:SetJustifyH("LEFT")
        c.value = Style.Text(c, 14, rec[2], nil, true)
        c.value:SetPoint("RIGHT", -16, 0)
        c.value:SetJustifyH("RIGHT")
        if i == 1 then
            c.big = Style.Text(c, 26, "text", nil, true)
            c.big:SetPoint("LEFT", 16 + Style.Wide(c.head, 90) + 14, 0)
        end
        W.records[i] = c
    end

    local header = CreateFrame("Frame", nil, view)
    header:SetSize(width, 20)
    header:SetPoint("TOPLEFT", 0, -(B.TOP - 24))
    Style.Rule(header, "BOTTOM", "lineStrong")
    for _, col in ipairs({ { "BOSS", "name", true }, { "FIRST KILL", "first" }, { "GROUP", "with", true }, { "FIGHT", "fight" },
                           { "KILLS", "kills" }, { "WIPES", "wipes" }, { "LAST", "last" } }) do
        local t = Style.Text(header, 10, "muted", nil, true)
        if col[3] then
            t:SetPoint("LEFT", W.X[col[2]], 0)
        else
            t:SetPoint("RIGHT", header, "LEFT", W.X[col[2]], 0)
            t:SetJustifyH("RIGHT")
        end
        t:SetText(col[1])
    end

    -- A line: a dungeon's (a click opens or closes it) or a boss's row.
    local function Right(r, x, bold)
        local t = Style.Text(r, 12, "secondary", nil, bold)
        t:SetPoint("RIGHT", r, "LEFT", x, 0)
        t:SetJustifyH("RIGHT")
        return t
    end
    function W.Row(i)
        if W.rows[i] then return W.rows[i] end
        local r = CreateFrame("Button", nil, view)
        r:SetSize(width, B.ROW_H)
        Style.Rule(r, "BOTTOM", "line")
        r.band = Style.Fill(r, "well")
        r.edge = r:CreateTexture(nil, "ARTWORK")
        r.edge:SetColorTexture(Style.Color("gold"))
        r.edge:SetPoint("TOPLEFT")
        r.edge:SetPoint("BOTTOMLEFT")
        r.edge:SetWidth(3)
        r.name = Style.Text(r, 12, "text")
        r.name:SetPoint("LEFT", W.X.name + 18, 0)
        r.name:SetJustifyH("LEFT")
        r.name:SetWordWrap(false)
        -- A dungeon's line: its name in bold, the level it's tuned to, and a tag for a raid.
        r.title = Style.Text(r, 13, "text", nil, true)
        r.title:SetPoint("LEFT", W.X.name, 0)
        r.from = Style.Text(r, 11, "muted")
        r.from:SetPoint("LEFT", r.title, "RIGHT", 8, 0)
        r.raid = Style.Tag(r, "raid", nil, true)
        r.raid:SetPoint("LEFT", r.from, "RIGHT", 8, 0)
        r.first = Right(r, W.X.first)
        r.with = Style.Text(r, 12, "secondary")
        r.with:SetPoint("LEFT", W.X.with, 0)
        r.with:SetWidth(W.X.fight - W.X.with - 50)
        r.with:SetWordWrap(false)
        r.with:SetJustifyH("LEFT")
        -- Pointed at, the group in full: the names kept (four at most), then how many more; a raid's counts.
        r.withHot = CreateFrame("Frame", nil, r)
        r.withHot:SetPoint("LEFT", W.X.with, 0)
        r.withHot:SetHeight(B.ROW_H)
        r.withHot:EnableMouse(true)
        r.withHot:SetScript("OnEnter", function(self)
            local lines = self.lines
            if not lines then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("First kill with")
            for _, line in ipairs(lines) do GameTooltip:AddLine(line, 1, 1, 1) end
            GameTooltip:Show()
        end)
        r.withHot:SetScript("OnLeave", function() GameTooltip:Hide() end)
        r.fight, r.kills, r.wipes, r.last = Right(r, W.X.fight), Right(r, W.X.kills), Right(r, W.X.wipes), Right(r, W.X.last)
        r.pips = {}
        r:SetScript("OnClick", function(self)
            if not self.place then return end
            W.open[self.place] = not self.opened
            Repaint()
        end)
        W.rows[i] = r
        return r
    end
    function W.Pip(r, k)
        local t = r.pips[k]
        if not t then
            t = r:CreateTexture(nil, "ARTWORK")
            t:SetSize(B.PIP_W, 10)
            r.pips[k] = t
        end
        return t
    end

    W.total = CreateFrame("Frame", nil, view)
    W.total:SetSize(width, B.LINE_H)
    Style.Rule(W.total, "TOP", "lineStrong")
    W.totalName = Style.Text(W.total, 12, "text", nil, true)
    W.totalName:SetPoint("LEFT", W.X.name, 0)
    W.totalFirst = Right(W.total, W.X.first, true)
    W.totalKills = Right(W.total, W.X.kills, true)
    W.totalWipes = Right(W.total, W.X.wipes, true)
    W.foot = Style.Text(view, 11, "muted")
    W.foot:SetWidth(width)
    W.foot:SetJustifyH("LEFT")
    W.empty = Style.Text(view, 13, "muted")
    W.empty:SetPoint("TOPLEFT", 0, -B.TOP)
    W.empty:SetText("No boss yet. Your first dungeon boss shows here, with when, who with and how long it took.")
    view:EnableMouseWheel(true)
    view:SetScript("OnMouseWheel", function(_, delta)
        W.offset = math.max(0, W.offset - delta * 3)
        Repaint()
    end)

    local function Paint()
        local life = (ns.Pretend and ns.Pretend.JournalData()) or (type(ns.Journal.Nights) == "table" and ns.Journal.Nights.Data()) or {}
        local pretending = ns.Pretend and ns.Pretend.on
        local game = (not pretending and ns.Dungeons and ns.Dungeons.GameKills) and ns.Dungeons.GameKills() or nil
        local places = B.Places(life, game)
        local rec = B.Records(places, life)
        local at60 = life.since60 ~= nil and ((ns.Pretend and ns.Pretend.Level()) or UnitLevel("player") or 1) >= 60
        -- The records.
        local cards = W.records
        cards[1].under:SetText(at60 and "since 60" or "so far")
        cards[1].big:SetText(tostring(rec.first))
        cards[1].value:SetText(rec.of > 0 and ("of %d"):format(rec.of) or "")
        cards[1].value:SetTextColor(Style.Color("text"))
        for i, held in ipairs({ false, rec.quick, rec.most, rec.hard }) do
            if i > 1 then
                cards[i].under:SetText(held and held.name or "none yet")
                cards[i].value:SetText(not held and "" or (i == 2 and Clock(held.n)) or (i == 3 and ("×%d"):format(held.n))
                    or ("%d wipe%s"):format(held.n, held.n == 1 and "" or "s"))
            end
        end
        -- The lines: a dungeon a line, and under an open one a row a boss. The first starts open.
        local items, total, dividedAt = {}, { killed = 0, of = 0, kills = 0, wipes = 0 }, nil
        for k, p in ipairs(places) do
            local key = p.d.name
            local open = W.open[key]
            if open == nil then open = k == 1 end
            if at60 and not p.at60 and not dividedAt then dividedAt = #items + 1 end
            items[#items + 1] = { place = p, open = open, key = key }
            if open then
                for _, b in ipairs(p.bosses) do items[#items + 1] = { boss = b } end
            end
            if not at60 or p.at60 then
                total.killed, total.of = total.killed + p.killed, total.of + #p.bosses
                total.kills, total.wipes = total.kills + p.kills, total.wipes + p.wipes
            end
        end
        W.empty:SetShown(#items == 0)
        local function Tall(it, first) return it.place and (B.LINE_H + (first and 0 or B.LINE_GAP)) or B.ROW_H end
        local room, last = W.room, #items + 1
        while last > 1 and room >= Tall(items[last - 1]) do
            last = last - 1
            room = room - Tall(items[last])
        end
        W.offset = math.max(0, math.min(W.offset, last - 1))
        local y, used, totalAt = 0, 0, nil
        for i = W.offset + 1, #items do
            local it = items[i]
            -- At 60, the total line under the dungeons of 60, before those of the climb.
            if i == dividedAt and not totalAt then
                totalAt = y
                y = y + B.LINE_H + 8
            end
            local h = Tall(it, y == 0)
            if y + h > W.room then break end
            used = used + 1
            local r = W.Row(used)
            local own = it.place and B.LINE_H or B.ROW_H
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 0, -(B.TOP + y + h - own))
            r:SetHeight(own)
            r:Show()
            r.place, r.opened = it.key, it.open
            r:EnableMouse(it.place ~= nil)
            for _, pip in ipairs(r.pips) do pip:Hide() end
            r.title:SetShown(it.place ~= nil)
            r.name:SetShown(it.place == nil)
            if it.place then
                local p = it.place
                r.band:Show()
                r.edge:SetShown(it.open)
                r.title:SetText(Style.Tint("gold") .. (it.open and "–" or "+") .. "|r  " .. p.d.name)
                r.from:SetText(p.d.level and ("from %d"):format(p.d.level) or "")
                r.raid:SetShown(p.d.raid == true)
                r.first:SetText(("%d of %d"):format(p.killed, #p.bosses))
                r.first:SetTextColor(Style.Color("text"))
                r.with:SetText("")
                r.withHot:Hide()
                for k, b in ipairs(p.bosses) do
                    local pip = W.Pip(r, k)
                    pip:ClearAllPoints()
                    pip:SetPoint("LEFT", W.X.pips + (k - 1) * (B.PIP_W + B.PIP_GAP), 0)
                    pip:SetColorTexture(Style.Color(b.kills > 0 and "gold" or "lineStrong"))
                    pip:Show()
                end
                r.fight:SetText("")
                r.kills:SetText(tostring(p.kills))
                r.wipes:SetText(tostring(p.wipes))
                r.wipes:SetTextColor(Style.Color(p.wipes > 0 and "red" or "muted"))
                r.last:SetText(Day(p.last))
            else
                local b, recd = it.boss, it.boss.rec
                local killed = b.kills > 0
                r.band:Hide()
                r.edge:Hide()
                r.raid:Hide()
                r.from:SetText("")
                r.name:SetText(b.name)
                r.name:SetTextColor(Style.Color(killed and "text" or "muted"))
                local first = recd and recd.first
                r.first:SetText(first and Day(first) or (killed and "earlier" or "not yet"))
                r.first:SetTextColor(Style.Color((first and Day(first) == "today") and "gold" or ((first and "secondary") or "muted")))
                local N = type(ns.Journal.Nights) == "table" and ns.Journal.Nights or nil
                r.with:SetText(recd and N and N.With(recd.with, true) or "")
                r.withHot.lines = recd and B.Group(recd.with) or nil
                r.withHot:SetShown(r.withHot.lines ~= nil)
                if r.withHot.lines then r.withHot:SetWidth(math.max(20, Style.Wide(r.with, #(r.with:GetText() or "") * 6.6))) end
                r.fight:SetText(recd and recd.fight and Clock(recd.fight) or "")
                r.kills:SetText(killed and tostring(b.kills) or "")
                local wipes = recd and recd.wipes or 0
                r.wipes:SetText((killed or wipes > 0) and tostring(wipes) or "")
                r.wipes:SetTextColor(Style.Color(wipes > 0 and "red" or "muted"))
                r.last:SetText(recd and recd.last and Day(recd.last) or "")
            end
            y = y + h
        end
        for i = used + 1, #W.rows do W.rows[i]:Hide() end
        -- The total: under the dungeons of 60 when there are those of the climb after them, else at the end.
        W.total:SetShown(#items > 0)
        W.total:ClearAllPoints()
        if not totalAt then
            totalAt = y + 8
            y = y + B.LINE_H + 8
        end
        W.total:SetPoint("TOPLEFT", 0, -(B.TOP + totalAt))
        W.totalName:SetText(at60 and "At 60" or "All")
        W.totalFirst:SetText(("%d of %d"):format(total.killed, total.of))
        W.totalKills:SetText(tostring(total.kills))
        W.totalWipes:SetText(tostring(total.wipes))
        W.totalWipes:SetTextColor(Style.Color(total.wipes > 0 and "red" or "muted"))
        local notes = {}
        if at60 and dividedAt then notes[#notes + 1] = "Then the dungeons of the climb, further down." end
        if game then notes[#notes + 1] = "A kill from before this version is counted, without its date." end
        if W.offset > 0 or W.offset + used < #items then notes[#notes + 1] = "Scroll for the rest." end
        notes[#notes + 1] = "Click a dungeon to open or close it."
        W.foot:ClearAllPoints()
        W.foot:SetPoint("TOPLEFT", 0, -(B.TOP + y + 14))
        W.foot:SetText(#items > 0 and table.concat(notes, " ") or "")
    end
    return Paint
end

ns.JournalByBossParts = B
