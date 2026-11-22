-- Raid night: what WoWSims' sims take to a raid for your spec (ConsumablesData), and how many of
-- each to hold for the nights you stock for. One that lasts is enough to cover the night's length
-- (one that outlasts it, one); one used in the moment (a potion, a rune, an explosive) is a plain
-- five a night. A count you set is yours, a night's, and no longer follows the length.
--
-- Simple, the start, is the list's main slots by the kind WoWSims gives each: the flask, elixirs,
-- food, weapon stone or oil, potions and rune. Max DPS adds what it files as extras and explosives.
--
-- Kept per character: Simple or Max DPS, the nights, the night's length in hours, the lines taken
-- off and the counts set by hand. Whether it's on the shopping list is the list's own: a stock
-- named "raid" there.
local _, ns = ...
local Compat = ns.Compat

local RaidNight = {}
ns.RaidNight = RaidNight

RaidNight.HOURS, RaidNight.MIN_HOURS, RaidNight.MAX_HOURS = 3, 1, 8
RaidNight.MAX_NIGHTS = 9
RaidNight.MOMENT = 5      -- a night's worth of what's used in the moment
RaidNight.STOCK = "raid"  -- its name on the shopping list
-- The kinds Simple keeps.
RaidNight.SIMPLE = { flask = true, elixir = true, food = true, weapon = true, potion = true, rune = true }

local function Clamp(n, low, high, default)
    n = math.floor(tonumber(n) or default)
    return math.max(low, math.min(high, n))
end

-- This character's choices: { max (Max DPS; absent for Simple), nights, hours, off = { [item] = true },
-- counts = { [item] = n } }.
function RaidNight.Saved()
    local s = ns.char.raidNight
    if type(s) ~= "table" then
        s = {}
        ns.char.raidNight = s
    end
    s.max = s.max == true or nil
    s.nights = Clamp(s.nights, 1, RaidNight.MAX_NIGHTS, 1)
    s.hours = Clamp(s.hours, RaidNight.MIN_HOURS, RaidNight.MAX_HOURS, RaidNight.HOURS)
    s.off = type(s.off) == "table" and s.off or {}
    s.counts = type(s.counts) == "table" and s.counts or {}
    return s
end

-- Which of WoWSims' lists is yours: the one your At 60 set's sims use, else your talent tree's.
-- Returns the spec's key ("hunter/dps"), its list (nil where WoWSims gives none) and the set's
-- name ("Weave"), nil without one.
function RaidNight.Spec()
    local data = ns.ConsumablesData
    if not data then return nil end
    local _, classFile = UnitClass("player")
    local Goal = ns.GearGoal
    local key, name
    if Goal and Goal.SetKey then key, name = Goal.SetKey() end
    local sets = data.sets[classFile or ""]
    local spec = key and sets and sets[key]
    if not spec then
        local trees = data.trees[classFile or ""]
        spec = trees and trees[ns.Gear and ns.Gear.Spec and ns.Gear.Spec() or 1]
        name = nil
    end
    return spec, spec and data.lists[spec] or nil, name
end

-- A spec's key as words: "paladin/retribution" -> "Retribution paladins".
function RaidNight.SpecWords(spec)
    local class, tree = (spec or ""):match("^(%a+)/(%a+)")
    if not class then return "your spec" end
    return tree:sub(1, 1):upper() .. tree:sub(2) .. " " .. class .. "s"
end

-- How many one night takes of a consumable { item, kind, seconds }.
function RaidNight.PerNight(c, saved)
    saved = saved or RaidNight.Saved()
    local own = tonumber(saved.counts[c[1]])
    if own then return math.max(1, math.floor(own)) end
    if (c[3] or 0) <= 0 then return RaidNight.MOMENT end
    return math.max(1, math.ceil(saved.hours * 3600 / c[3]))
end

-- Each consumable not taken off: { item, kind, lasts, per (a night), want (all nights), have,
-- short, own (a count set by hand) }; and the items taken off.
function RaidNight.Lines()
    local _, list = RaidNight.Spec()
    local saved = RaidNight.Saved()
    local lines, off = {}, {}
    for _, c in ipairs(list or {}) do
        if not RaidNight.Chosen(c, saved) then
            -- An extra while Simple is chosen: not on the card at all.
        elseif saved.off[c[1]] then
            off[#off + 1] = c[1]
        else
            local per = RaidNight.PerNight(c, saved)
            local want = per * saved.nights
            local have = Compat.ItemCount(c[1], true)
            lines[#lines + 1] = { item = c[1], kind = c[2], lasts = c[3], per = per, want = want, have = have,
                                  short = math.max(0, want - have), own = saved.counts[c[1]] ~= nil }
        end
    end
    return lines, off
end

-- How many of each to hold, by item: what the shopping list keeps as the stock.
function RaidNight.Wants()
    local want = {}
    for _, line in ipairs((RaidNight.Lines())) do want[line.item] = line.want end
    return want
end

-- Whether it's on the shopping list.
function RaidNight.Listed()
    return ns.Shopping ~= nil and ns.Shopping.Stocked(RaidNight.STOCK) ~= nil
end

-- What the list holds follows a change here (nights, the length, a count, a line on or off).
function RaidNight.Sync()
    if not RaidNight.Listed() then return end
    local want, held = RaidNight.Wants(), ns.Shopping.Stocked(RaidNight.STOCK)
    local same = true
    for item, n in pairs(want) do if held[item] ~= n then same = false end end
    for item in pairs(held) do if not want[item] then same = false end end
    if not same then ns.Shopping.Stock(RaidNight.STOCK, want) end
end

-- Puts it on the shopping list, or takes it off.
function RaidNight.SetListed(on)
    if not ns.Shopping then return end
    if on then
        ns.Shopping.Stock(RaidNight.STOCK, RaidNight.Wants())
        ns.Shopping.Open()
    else
        ns.Shopping.Unstock(RaidNight.STOCK)
    end
end

-- Whether a consumable { item, kind, seconds } is in the list chosen: all of it with Max DPS,
-- Simple's kinds without.
function RaidNight.Chosen(c, saved)
    saved = saved or RaidNight.Saved()
    return saved.max == true or RaidNight.SIMPLE[c[2]] == true
end

-- Max DPS (all of WoWSims' list) or Simple.
function RaidNight.SetMax(on)
    RaidNight.Saved().max = on and true or nil
    RaidNight.Sync()
end

function RaidNight.SetNights(n)
    RaidNight.Saved().nights = Clamp(n, 1, RaidNight.MAX_NIGHTS, 1)
    RaidNight.Sync()
end

function RaidNight.SetHours(n)
    RaidNight.Saved().hours = Clamp(n, RaidNight.MIN_HOURS, RaidNight.MAX_HOURS, RaidNight.HOURS)
    RaidNight.Sync()
end

-- A night's count of one, set by hand; back to following the length when it's what that gives.
function RaidNight.SetCount(c, n)
    local saved = RaidNight.Saved()
    n = math.max(1, math.floor(tonumber(n) or 1))
    saved.counts[c[1]] = nil
    if RaidNight.PerNight(c, saved) ~= n then saved.counts[c[1]] = n end
    RaidNight.Sync()
end

function RaidNight.TakeOff(item, off)
    RaidNight.Saved().off[item] = off and true or nil
    RaidNight.Sync()
end

-- Its line on the shopping list.
if ns.Shopping and ns.Shopping.stockLines then
    ns.Shopping.stockLines[RaidNight.STOCK] = {
        title = "Raid night", count = "%d consumables", icon = "Interface\\AddOns\\jsalUI\\Media\\Icons\\endgame",
        note = "WoWSims' consumables for your spec, for the nights on the Endgame page. What a raid uses comes back on the list.",
        dropped = function() if ns.Window and ns.Window.Refresh then ns.Window.Refresh() end end,
    }
end
