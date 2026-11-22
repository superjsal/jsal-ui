-- The Journal's Summary at level 60: its chart becomes SINCE 60, a bar a day since you reached 60, as
-- tall as that day's time in dungeons and raids (today gold, the day with the most bosses green, a red dot
-- over a day you died, a thin line on a day with no night); pointing at one says where, the bosses, the
-- time and the wipes. The nights come from Journal\Nights.lua (or, pretending to be 60, made up).
local _, ns = ...
local Style, Compat = ns.Style, ns.Compat

local S60 = { DAYS = 60 }
ns.JournalSince60 = S60

local function Hours(seconds)
    seconds = math.floor(seconds or 0)
    local h, m = math.floor(seconds / 3600), math.floor(seconds % 3600 / 60)
    if h > 0 then return ("%dh %02dm"):format(h, m) end
    return ("%dm"):format(m)
end
S60.Hours = Hours

-- "1 boss", "13 bosses".
function S60.Bosses(n)
    n = n or 0
    return ("%d boss%s"):format(n, n == 1 and "" or "es")
end

-- "no wipes", "1 wipe", "3 wipes".
function S60.Wipes(n)
    n = n or 0
    if n == 0 then return "no wipes" end
    return ("%d wipe%s"):format(n, n == 1 and "" or "s")
end

-- "died once", "died twice", "died 3 times", or nil.
function S60.Died(n)
    n = n or 0
    if n == 0 then return nil end
    return n == 1 and "died once" or n == 2 and "died twice" or ("died %d times"):format(n)
end

local function DayKey(t) return date("%Y%m%d", t) end

-- The days from the one you reached 60 to today (the last 60 of them at most), each with its nights:
-- { t, key, secs, kills, wipes, deaths, places = { names }, nights = { nights } }.
function S60.Days(data, now)
    now = now or Compat.ServerTime()
    local since = data.since60 or now
    local first = math.max(since, now - (S60.DAYS - 1) * 86400)
    local days, byKey = {}, {}
    local t = first
    while DayKey(t) <= DayKey(now) and #days < S60.DAYS do
        local d = { t = t, key = DayKey(t), secs = 0, kills = 0, wipes = 0, deaths = 0, places = {}, nights = {} }
        days[#days + 1] = d
        byKey[d.key] = d
        t = t + 86400
    end
    for _, n in ipairs(data.nights or {}) do
        local d = byKey[DayKey(n.at or 0)]
        if d then
            d.secs = d.secs + (n.secs or 0)
            d.kills, d.wipes, d.deaths = d.kills + (n.kills or 0), d.wipes + (n.wipes or 0), d.deaths + (n.deaths or 0)
            d.nights[#d.nights + 1] = n
            local seen = false
            for _, p in ipairs(d.places) do if p == n.place then seen = true end end
            if not seen and n.place then d.places[#d.places + 1] = n.place end
        end
    end
    return days
end

-- How many nights since 60, of those kept.
function S60.NightsSince(data)
    local n = 0
    for _, night in ipairs(data.nights or {}) do
        if not data.since60 or (night.at or 0) >= data.since60 then n = n + 1 end
    end
    return n
end

-- Kills of the bosses kept (the Summary's count is never less).
function S60.Kills(data)
    local n = 0
    for _, b in pairs(data.bosses or {}) do n = n + (b.kills or 0) end
    return n
end

-- Bosses killed for the first time at 60.
function S60.FirstKills(data)
    local n = 0
    for _, b in pairs(data.bosses or {}) do
        if b.first and (b.lv or 0) >= 60 then n = n + 1 end
    end
    return n
end

-- The chart, on the Summary's own bars (M.Bar), across `width`.
function S60.Chart(M, width, data, now)
    now = now or Compat.ServerTime()
    local days = S60.Days(data, now)
    M.chartHead:SetText("SINCE 60")
    M.legend:SetText("time in dungeons each night")
    M.dotText:SetText("died that night")
    local top, best = 0, nil
    for i, d in ipairs(days) do
        top = math.max(top, d.secs)
        if d.kills > 0 and (not best or d.kills >= days[best].kills) then best = i end
    end
    local n = #days
    local gap = n > 40 and 2 or 4
    local barW = math.max(2, math.min(46, math.floor((width - (n - 1) * gap) / n)))
    for i, d in ipairs(days) do
        local b = M.Bar(i)
        local today = d.key == DayKey(now)
        b:SetWidth(barW)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", (i - 1) * (barW + gap), -(M.chartY + 24))
        b:Show()
        b.fill:SetHeight(d.secs > 0 and math.max(3, top > 0 and M.CHART_H * d.secs / top or 3) or 1)
        b.fill:SetColorTexture(Style.Color((today and "gold") or (i == best and "green") or (d.secs > 0 and "lineStrong") or "line"))
        b.dot:SetShown(d.deaths > 0)
        -- A date under the first day, each week on, and "today" under today.
        local label = today and "today" or ((i == 1 or (i - 1) % 7 == 0) and (n - i >= 2) and (date("%d %b", d.t):gsub("^0", "")) or "")
        b.label:SetText(label)
        b.label:SetTextColor(Style.Color(today and "text" or "muted"))
        local heading = (date("%A %d %B", d.t):gsub(" 0", " "))
        if #d.nights == 0 then
            b.tip = { heading, "No night in a dungeon" }
        else
            b.tip = { heading, table.concat(d.places, ", "),
                      ("%s  ·  %s  ·  %s"):format(S60.Bosses(d.kills), Hours(d.secs), S60.Wipes(d.wipes)) }
        end
    end
    for i = n + 1, #M.bars do M.bars[i]:Hide() end
    local nights = S60.NightsSince(data)
    local most = best and days[best]
    local when = most and (most.key == DayKey(now) and "today" or (date("%d %b", most.t):gsub("^0", "")))
    M.records:SetText(((most and ("most bosses: %d in %s, %s   ·   "):format(most.kills, most.places[1] or "a dungeon", when)) or "")
        .. ("%d night%s"):format(nights, nights == 1 and "" or "s"))
end

---------------------------------------------------------------------------
-- The Story's words for a night and its moments.
---------------------------------------------------------------------------
local MUTED, SECONDARY = "|cff9a9688", "|cffc4bfb0"

-- Coins in short: "31g 40s", "52s", "8c".
local function Coins(copper)
    copper = math.floor(copper or 0)
    local g, s, c = math.floor(copper / 10000), math.floor(copper % 10000 / 100), copper % 100
    if g > 0 then return s > 0 and ("%dg %02ds"):format(g, s) or ("%dg"):format(g) end
    if s > 0 then return ("%ds"):format(s) end
    return ("%dc"):format(c)
end
S60.Coins = Coins

-- A night's record, by the time it began.
local function NightOf(e)
    local N = ns.Journal and ns.Journal.Nights
    for _, n in ipairs(N and N.List() or {}) do
        if n.at == e.night then return n end
    end
    return nil
end

-- A row's words: a night is "Lower Blackrock Spire · 8 bosses in 1h 52m"; inside a night, a first kill
-- is "First kill: X", with the wipes before it; loot is "Found: X"; a death says what you were fighting.
function S60.StoryText(it)
    local e = it.e
    if e.k == "night" then
        return ("%s  %s·  %s in %s|r"):format(e.s or "A dungeon", SECONDARY, S60.Bosses(e.b), Hours((e.m or 0) * 60))
    end
    if not it.inNight then return it.text end
    if e.k == "boss" and e.boss then
        local wipes = e.wipes or 0
        return ("First kill: %s%s"):format(e.boss, wipes > 0 and ("  %s%s|r"):format(MUTED, wipes == 1 and "after a wipe" or ("after %d wipes"):format(wipes)) or "")
    end
    if e.k == "loot" then return ((it.text or ""):gsub("^[^:]+: ", "Found: ")) end
    if e.k == "death" and e.vs then return ("%s  %sfighting %s|r"):format(it.text or "Died", MUTED, e.vs) end
    return it.text
end

-- The line under a night: who with, wipes, deaths, gold looted.
function S60.StoryMore(e)
    local n = NightOf(e)
    if not n then return nil end
    local parts = {}
    local N = ns.Journal.Nights
    local with = N.With(n.with)
    if with then parts[#parts + 1] = "with " .. with end
    parts[#parts + 1] = S60.Wipes(n.wipes)
    parts[#parts + 1] = S60.Died(n.deaths)
    if (n.gold or 0) > 0 then parts[#parts + 1] = Coins(n.gold) .. " looted" end
    return table.concat(parts, "  ·  ")
end
