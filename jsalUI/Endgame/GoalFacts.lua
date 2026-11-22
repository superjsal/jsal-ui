-- The Endgame page's goal at 60, below level 60, worked out from the Gear plan's own reading of your set
-- (GearGoal.Summary, the one YOUR SET and Home at 60 read) and its sources (GearGoal.From): the pieces you
-- don't wear yet, each with the level it needs; where they come from, by kind; the one sentence on how far
-- the first one is; and where each stands on the road from your level to 60.
local _, ns = ...
local Compat = ns.Compat

local Facts = {}
ns.EndgameGoalFacts = Facts

Facts.CAP = 60
Facts.STACK = 6           -- pictures a column on the road, before a level's pieces take another column
Facts.ICON = 22           -- a picture on the road, and the room between one and the next is 3

-- A vendor's name, from its place ("Creeg Bothunk · The Barrens").
local function VendorOf(place)
    return (place or ""):match("^(.-) · ") or (place ~= "" and place) or "A vendor"
end

local function ByLevel(a, b)
    if a.req ~= b.req then return a.req < b.req end
    return a.id < b.id
end

-- The goal from a summary: { name, own, of, at, empty, chosen, open (slots with no piece chosen),
-- pieces = { { id, e, req, quality, label, from, how } },
-- dungeons = { { name, level, dungeon, pieces } }, quests, crafted, vendors = { { name, level, pieces } },
-- elsewhere, unknown }. A piece with no known level stands at 60.
function Facts.Read(s)
    local Goal = ns.GearGoal
    local chosen = s.chosen or s.of or 0
    local out = { name = s.name, own = s.own, of = s.of or 0, at = s.at or 0, empty = s.empty, pieces = {},
                  chosen = chosen, open = math.max(0, (s.of or 0) - chosen),
                  dungeons = {}, quests = {}, crafted = {}, vendors = {}, elsewhere = {}, unknown = {} }
    local dungeons, vendors = {}, {}
    for _, row in ipairs(s.rows or {}) do
        local e = row.goal and row.goal.e
        if e and e.id then
            local from = Goal and Goal.From and Goal.From(e) or { kind = "unknown", runs = {} }
            local p = { id = e.id, e = e, req = tonumber(e.req) or Facts.CAP, quality = tonumber(e.quality) or 1,
                        label = row.label, equip = row.equip, from = from }
            out.pieces[#out.pieces + 1] = p
            local place = e.place or ""
            if from.kind == "run" then
                -- The first place it drops; a dungeon's level is the one it's tuned to.
                local run = from.runs[1]
                local d = dungeons[run.name]
                if not d then
                    d = { name = run.name, level = run.dungeon and run.dungeon.level, dungeon = run.dungeon, pieces = {} }
                    dungeons[run.name] = d
                    out.dungeons[#out.dungeons + 1] = d
                end
                p.how = run.boss
                d.pieces[#d.pieces + 1] = p
            elseif from.kind == "crafted" then
                p.how = (from.craft and from.craft ~= "") and from.craft or "Crafted"
                out.crafted[#out.crafted + 1] = p
            elseif from.kind == "quest" then
                p.how = place ~= "" and place or "a quest"
                out.quests[#out.quests + 1] = p
            elseif from.kind == "vendor" then
                local name = VendorOf(place)
                local v = vendors[name]
                if not v then
                    v = { name = name, place = place, level = 0, pieces = {} }
                    vendors[name] = v
                    out.vendors[#out.vendors + 1] = v
                end
                v.level = math.max(v.level, p.req)
                v.pieces[#v.pieces + 1] = p
            elseif (from.kind == "zone" and place ~= "") or from.kind == "pvp" then
                p.how = from.text
                out.elsewhere[#out.elsewhere + 1] = p
            else
                -- A drop with no place, or no source at all: said as such, never guessed.
                out.unknown[#out.unknown + 1] = p
            end
        end
    end
    table.sort(out.pieces, ByLevel)
    for _, list in ipairs({ out.quests, out.crafted, out.elsewhere, out.unknown }) do table.sort(list, ByLevel) end
    for _, group in ipairs(out.dungeons) do table.sort(group.pieces, ByLevel) end
    for _, group in ipairs(out.vendors) do table.sort(group.pieces, ByLevel) end
    table.sort(out.dungeons, function(a, b)
        if (a.level or 99) ~= (b.level or 99) then return (a.level or 99) < (b.level or 99) end
        return a.name < b.name
    end)
    table.sort(out.vendors, function(a, b) return a.name < b.name end)
    return out
end

-- An item's name as the Endgame page draws it: the game's (the gear data ships none), or nil while the
-- game hasn't loaded the item. Each one drawn without is noted, and the page draws again when it comes in.
ns.EndgameMissing = ns.EndgameMissing or {}
function ns.EndgameItemName(id)
    local name = Compat.ItemName(id)
    if not name and id then ns.EndgameMissing[id] = true end
    return name
end

-- An item's name, or "a piece" while the game hasn't loaded it.
local function Named(id)
    return ns.EndgameItemName(id) or "a piece"
end

-- How far the first piece is, in one sentence, from what can be had now: "The first is 8 levels away:
-- Mark of Fordring at 52. Most open from 56 to 60." `link(id, name)` writes a piece's name (in its
-- colour on the card).
function Facts.Sentence(g, level, link)
    link = link or function(_, name) return name end
    if g.empty then return "Your set has no pieces yet: choose them in the Gear plan." end
    local pieces = g.pieces
    local open = g.open or 0
    -- A set of yours with places still empty says so, and where to fill them.
    local rest = open > 0 and (" %d slot%s still empty: choose %s in the Gear plan."):format(open, open == 1 and " is" or "s are",
        open == 1 and "its piece" or "their pieces") or ""
    if #pieces == 0 then
        if open == 0 then return "You wear every piece of it." end
        local chosen = g.chosen or 0
        return ("You wear the %s chosen."):format(chosen == 1 and "piece" or (chosen .. " pieces")) .. rest
    end
    return Facts.SentenceOf(g, pieces, level, link) .. rest
end

-- The sentence for the pieces still to get.
function Facts.SentenceOf(g, pieces, level, link)
    local now, later = {}, {}
    for _, p in ipairs(pieces) do
        if p.req <= level then now[#now + 1] = p else later[#later + 1] = p end
    end
    -- Most of what's left: from the first quarter of it on, to the last.
    local function Most(list)
        if #list == 0 then return nil end
        local low, high = list[math.max(1, math.floor(#list / 4) + 1)].req, list[#list].req
        if #list == 1 then return ("It opens at %d."):format(high) end
        if low == high then return ("%s open at %d."):format(#list == #pieces and "All" or "The rest", high) end
        return ("%s open from %d to %d."):format(#list == #pieces and "Most" or "The rest", low, high)
    end
    if #now == 0 then
        local first = later[1]
        local away = first.req - level
        local words = ("The first is %d level%s away: %s at %d."):format(away, away == 1 and "" or "s", link(first.id, Named(first.id)), first.req)
        local rest = {}
        for i = 2, #later do rest[#rest + 1] = later[i] end
        local most = Most(#rest > 0 and later or {})
        return most and (words .. " " .. most) or words
    end
    if #later == 0 then
        return #now == 1 and ("%s can be had now."):format(link(now[1].id, Named(now[1].id)))
            or ("All %d can be had now, starting with %s."):format(#now, link(now[1].id, Named(now[1].id)))
    end
    local lead = #now == 1 and ("%s can be had now."):format(link(now[1].id, Named(now[1].id)))
        or ("%d can be had now, %s first."):format(#now, link(now[1].id, Named(now[1].id)))
    return lead .. " " .. Most(later)
end

-- Where each piece stands on the road from `level` to 60, in a strip `width` wide and `height` tall:
-- { piece, x, y } for each picture's top left. A piece that can be had now stands at your level. A level's
-- pieces stack upwards, Facts.STACK to a column; more take columns side by side, centred on the level.
function Facts.Road(pieces, level, width, height)
    local from = math.min(level, Facts.CAP - 1)
    local span = Facts.CAP - from
    local step = Facts.ICON + 3
    local at, out = {}, {}
    for _, p in ipairs(pieces) do
        local l = math.max(from, math.min(Facts.CAP, p.req))
        at[l] = at[l] or {}
        at[l][#at[l] + 1] = p
    end
    for l, list in pairs(at) do
        local cx = (l - from) / span * (width - Facts.ICON) + Facts.ICON / 2
        -- The level's columns side by side, centred on it, the whole group kept inside the strip.
        local cols = math.ceil(#list / Facts.STACK)
        local groupW = cols * step - 3
        local left = math.max(0, math.min(width - groupW, cx - groupW / 2))
        for i, p in ipairs(list) do
            local col, row = math.floor((i - 1) / Facts.STACK), (i - 1) % Facts.STACK
            out[#out + 1] = { piece = p, level = l, x = math.floor(left + col * step + 0.5), y = height - Facts.ICON - row * step }
        end
    end
    table.sort(out, function(a, b) if a.x ~= b.x then return a.x < b.x end return a.y > b.y end)
    return out
end

-- Where a level stands on the road, in the same strip.
function Facts.LevelX(l, level, width)
    local from = math.min(level, Facts.CAP - 1)
    return (l - from) / (Facts.CAP - from) * (width - Facts.ICON) + Facts.ICON / 2
end
