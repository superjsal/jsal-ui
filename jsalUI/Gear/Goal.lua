-- The Gear plan's goal for the last level: for each slot, the best piece for your spec that a
-- level 60 can get, in two stages (before raids, then raids), which of them you already wear,
-- and where the rest come from, a dungeon's pieces together. It can be asked at any level:
-- everything here is worked out as a level 60 of your class would have it.
local _, ns = ...
local Gear = ns.Gear

local Goal = ns.NewModule("geargoal", {
    title = "Gear goal for 60",
    note = "An \"At 60\" view on the Gear plan, open at any level: the best piece for each slot at level 60 for your spec, which of them you already wear, and the dungeons to run for the rest.",
})
ns.GearGoal = Goal
Goal.LEVEL = 60
-- The stages: what's had before raids (dungeons, quests, vendors, crafting), then with raids.
Goal.BEFORE, Goal.RAIDS = 1, 2

function Goal:OnEnable() end
function Goal:OnDisable() end

---------------------------------------------------------------------------
-- Where a piece comes from, as the goal needs it: the bosses that drop it
-- with their chances, and whether that's in the game.
---------------------------------------------------------------------------
-- Raids Wowhead's lists name that the dungeon guide doesn't have: their pieces aren't to be
-- had, so they're no goal. One the guide gains (the game's own tables put it there) counts
-- from then on.
local NOT_YET = { ["Naxxramas"] = true, ["Ahn'Qiraj"] = true, ["Ruins of Ahn'Qiraj"] = true }

-- The dungeon guide's dungeons by name.
local guide
local function Guide()
    if guide and guide.data == ns.DungeonData then return guide.by end
    local by = {}
    guide = { data = ns.DungeonData, by = by }
    for _, d in ipairs(ns.DungeonData or {}) do by[d.name] = d end
    return by
end

-- Every boss in the guide that drops an item: { boss, name (the dungeon's), dungeon, chance, raid }.
local drops
local function Drops()
    if drops and drops.loot == ns.DungeonLoot and drops.data == ns.DungeonData then return drops.by end
    local by = {}
    drops = { loot = ns.DungeonLoot, data = ns.DungeonData, by = by }
    for _, d in ipairs(ns.DungeonData or {}) do
        for _, b in ipairs(d.bosses or {}) do
            for _, drop in ipairs(ns.DungeonLoot and ns.DungeonLoot[b[1]] or {}) do
                local list = by[drop[1]] or {}
                by[drop[1]] = list
                list[#list + 1] = { boss = b[3] or b[2], name = d.name, dungeon = d, chance = drop[2], raid = d.raid and true or false }
            end
        end
    end
    return by
end

-- An item's source: `kind` is "run" (a dungeon or raid), "crafted", "quest", "vendor", "zone",
-- "world" or "unknown"; `runs` the places it drops in a run; `text` how the others read
-- ("Crafted, Leatherworking"); `notYet` for a piece of a raid that isn't in the game. Worked
-- out once for an entry and kept on it.
function Goal.From(e)
    if e.from then return e.from end
    local from = { runs = {} }
    for _, d in ipairs(Drops()[e.id] or {}) do from.runs[#from.runs + 1] = d end
    local set = {}
    for _, kind in ipairs(Gear.SourceKinds(e)) do set[kind] = true end
    local place = e.place or ""
    if #from.runs == 0 and set.dungeon then
        -- Named on Wowhead's list alone: "Darkmaster Gandling · Scholomance", or the place.
        local boss, name = place:match("^(.-) · (.*)$")
        name = name or place
        local d = Guide()[name]
        if NOT_YET[name] and not d then
            from.notYet = true
        else
            from.runs[1] = { boss = boss, name = name, dungeon = d, raid = d and d.raid and true or false }
        end
    end
    if set.crafted then from.craft = Gear.Source(e):match("^(.-) · Crafted") or "" end
    if #from.runs > 0 then
        from.kind = "run"
    elseif set.crafted then
        from.kind, from.text = "crafted", "Crafted" .. (from.craft ~= "" and (", " .. from.craft) or "")
    elseif set.quest then
        from.kind, from.text = "quest", "Quest" .. (place ~= "" and (", " .. place) or "")
    elseif set.vendor then
        from.kind, from.text = "vendor", "Vendor" .. (place ~= "" and (", " .. place) or "")
    elseif set.zone then
        from.kind, from.text = "zone", place ~= "" and place or "Drop"
    elseif set.world then
        from.kind, from.text = "world", "World drop"
    elseif set.pvp then
        from.kind, from.text = "pvp", "PvP"
    else
        from.kind, from.text = "unknown", ""
    end
    e.from = from
    return from
end

-- The pieces got by a quest, a vendor or a craft that need a raid first (GearData's `raid`):
-- a raid's quest or trader, a craft of what only drops in a raid. Read once.
local raidOnly
local function RaidOnly(id)
    if not raidOnly then
        raidOnly = {}
        for n in ((ns.GearData and ns.GearData.raid) or ""):gmatch("%d+") do raidOnly[tonumber(n)] = true end
    end
    return raidOnly[id] == true
end

-- A piece of one side's quartermaster in the Barrens and its twin from the other's (GearData's
-- `twins`, "Horde:Alliance"): a WoWSims set's piece your side can't buy is its twin. Read once.
local twinOf
local function Twin(id, side)
    if not twinOf then
        twinOf = { {}, {} }
        for h, a in ((ns.GearData and ns.GearData.twins) or ""):gmatch("(%d+):(%d+)") do
            twinOf[1][tonumber(h)] = tonumber(a)
            twinOf[2][tonumber(a)] = tonumber(h)
        end
    end
    return twinOf[side] and twinOf[side][id] or id
end

-- The first stage a piece can be a goal in, nil for never. A boss the guide lists outside a
-- raid is before raids; one in a raid waits for the raids, and so does a piece that needs a
-- raid first by another road (up to the same item level: past it, it's a raid's still to
-- come). Anything else (a craft, a quest, a vendor, PvP, a drop out in
-- the world) has nothing that says it's in the game, and Wowhead lists pieces of raids still to
-- come, so it counts only up to the item level dungeons give (`ceiling`): above that it's a
-- raid's piece by another road.
function Goal.Stage(e, ceiling)
    local from = Goal.From(e)
    if from.notYet then return nil end
    if RaidOnly(e.id) then return (e.ilvl or 0) <= ceiling and Goal.RAIDS or nil end
    if from.kind == "run" then
        for _, r in ipairs(from.runs) do
            if not r.raid then return Goal.BEFORE end
        end
        return Goal.RAIDS
    end
    return (e.ilvl or 0) <= ceiling and Goal.BEFORE or nil
end

---------------------------------------------------------------------------
-- The pieces a level 60 of your class could wear, a slot type at a time,
-- read out of GearData's text once and kept.
---------------------------------------------------------------------------
local ROW = "^(%d+),(%d+),(%d+),(%d+),(-?%d+),(%d+),(%d+),(%d+),(%d+),(%d+)$"
local pools = {}
local function Pool(ctx, invType)
    local data = ctx.data
    local line = data.items[invType] or ""
    local kept = pools[invType]
    if kept and kept.key == ctx.key and kept.line == line then return kept end
    kept = { key = ctx.key, line = line }
    pools[invType] = kept
    local bit = ctx.classID and 2 ^ (ctx.classID - 1) or 0
    local level, classFile = Goal.LEVEL, ctx.classFile
    for entry in line:gmatch("[^;]+") do
        local id, req, ilvl, cls, sub, s, reqclass, q, kind, place = entry:match(ROW)
        if id then
            local r, il, rc, c, sb = tonumber(req), tonumber(ilvl), tonumber(reqclass), tonumber(cls), tonumber(sub)
            local at = Gear.LevelOf(r, il)
            -- An off-hand weapon is asked about as a one-hander when a 60 of the class dual
            -- wields: the game's own answer is for the level you are.
            local mine = Gear.ForClass(classFile, level, c, sb, (invType == 22 and ctx.dual) and 13 or invType)
            if r <= level and at >= level - Gear.BELOW and at <= level + Gear.ABOVE
                and (s == "0" or tonumber(s) == ctx.side)
                and (rc == 0 or bit == 0 or math.floor(rc / bit) % 2 == 1)
                and (mine or Gear.CanWear(classFile, level, c, sb)) then
                local e = Gear.Entry(data, id, req, ilvl, invType, q, kind, place)
                e.lighter = not mine and Gear.ARMOR_NAMES[sb] or nil
                -- Profession gear (an engineer's goggles): asked of its tooltip when it's scored.
                e.skilled = kind == "4" and il - math.max(r, 1) >= 12 or nil
                kept[#kept + 1] = e
            end
        end
    end
    return kept
end

-- The slot types that fit a slot at 60: a one-hander in the off hand too, for a class that
-- dual wields by then.
local function Types(slot, ctx)
    if slot.key == "off" and ctx.dual then return { 14, 22, 23, 13 } end
    return slot.types
end

-- The highest item level a boss outside a raid drops for your class: what "before raids" goes up to.
local function Ceiling(ctx)
    local top
    for _, slot in ipairs(Gear.SLOTS) do
        for _, invType in ipairs(slot.types) do
            for _, e in ipairs(Pool(ctx, invType)) do
                if (e.ilvl or 0) > (top or 0) then
                    for _, r in ipairs(Goal.From(e).runs) do
                        if r.dungeon and not r.raid then
                            top = e.ilvl
                            break
                        end
                    end
                end
            end
        end
    end
    return top or (Goal.LEVEL + Gear.ABOVE)
end

-- Whether you have a profession at all: its gear is a goal for you alone.
local function Have(name)
    local P = ns.Professions
    if not (name and P and P.Mine) then return false end
    local ok, mine = pcall(P.Mine)
    for _, p in ipairs(ok and mine or {}) do
        if p.name and p.name:lower() == name:lower() then return true end
    end
    return false
end

-- A slot's pieces with their worth for your spec, best first: { e, id, stats, score, stage,
-- unknown }. One the game hasn't sent yet is counted in ctx.waiting and left out.
local function Scored(slot, ctx)
    local list = {}
    for _, invType in ipairs(Types(slot, ctx)) do
        for _, e in ipairs(Pool(ctx, invType)) do
            local stage = Goal.Stage(e, ctx.ceiling)
            local need = false
            if stage and e.skilled then need = Gear.SkillNeed(e.id) end
            if stage and need == nil then
                ctx.waiting = ctx.waiting + 1
            elseif stage and not (need and not Have(need.name)) and not (e.kind == "Quest" and Gear.RewardTaken(e.id)) then
                local stats = Gear.Stats(e.id)
                if stats then
                    list[#list + 1] = { e = e, id = e.id, stats = stats, score = Gear.Score(stats, ctx.weights, slot.dps) or 0,
                                        stage = stage, unknown = Goal.From(e).kind == "unknown" }
                elseif not Gear.GivenUp(e.id) then
                    ctx.waiting = ctx.waiting + 1
                end
            end
        end
    end
    table.sort(list, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return a.id < b.id
    end)
    return list
end

-- What you wear in one of the game's equipment places, with its worth where it sits.
local function Worn(equip, slot, ctx)
    local link = GetInventoryItemLink and GetInventoryItemLink("player", equip)
    local stats = link and Gear.Stats(link) or {}
    return { equip = equip, link = link, id = link and tonumber(link:match("item:(%d+)")) or nil, stats = stats,
             score = link and (Gear.Score(stats, ctx.weights, slot.dps) or 0) or 0 }
end

---------------------------------------------------------------------------
-- Choosing: for the places of one slot, the best of what you wear and what
-- you could get.
---------------------------------------------------------------------------
-- `worn` is the slot's places as you wear them, `list` its scored pieces. A piece you wear
-- keeps its place (the row is done) while nothing with a known source beats it; the best
-- pieces take the weakest places. A place nothing known beats, that a piece of no known
-- source does, has that piece as its goal, marked. Rows come back in the places' own order.
function Goal.Choose(worn, list, stage, skip)
    -- Two pieces of one name (a ring of a quest chain's several, a unique one) can't be worn
    -- together: only the best of a name is offered, and none of the name of one you wear.
    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local function Named(id) return id and get and get(id) or nil end
    local wearing, names = {}, {}
    for _, w in ipairs(worn) do
        if w.id then
            wearing[w.id] = true
            local name = Named(w.id)
            if name then names[name] = true end
        end
    end
    local known, unknown = {}, {}
    for _, c in ipairs(list) do
        if c.stage <= stage and not wearing[c.id] and c.id ~= skip then
            local name = Named(c.id)
            if not (name and names[name]) then
                if name then names[name] = true end
                if c.unknown then unknown[#unknown + 1] = c else known[#known + 1] = c end
            end
        end
    end
    local order = {}
    for i, w in ipairs(worn) do order[i] = w end
    table.sort(order, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return a.equip < b.equip
    end)
    local taken, keep = 0, 0
    for _ = 1, #order do
        local c, w = known[taken + 1], order[keep + 1]
        if c and c.score > w.score + 0.01 then taken = taken + 1 else keep = keep + 1 end
    end
    local rows, nextUnknown = {}, 1
    for i, w in ipairs(order) do
        local row = { equip = w.equip, worn = w }
        if i > keep then
            row.goal = known[i - keep]
        else
            local u = unknown[nextUnknown]
            if u and u.score > w.score + 0.01 then
                row.goal, row.unknown = u, true
                nextUnknown = nextUnknown + 1
            elseif w.link then
                row.done = true
            else
                -- Nothing worn and nothing found to wear: not a slot to count.
                row.none = true
            end
        end
        rows[#rows + 1] = row
    end
    table.sort(rows, function(a, b) return a.equip < b.equip end)
    return rows
end

-- The best piece of a list for a stage with a known source, leaving out one item and what you wear.
local function Top(list, stage, skip, wearing)
    for _, c in ipairs(list) do
        if c.stage <= stage and not c.unknown and c.id ~= skip and not (wearing and wearing[c.id]) then return c end
    end
end

-- Your hands: a two-hander, or a one-hander with something in the off hand, whichever is
-- worth more for your spec. With a two-hander as the goal the off hand is taken, and isn't a
-- slot to fill.
local function Hands(ctx, stage, main, off)
    local mainSlot, offSlot = main.slot, off.slot
    local wornMain, wornOff = Worn(16, mainSlot, ctx), Worn(17, offSlot, ctx)
    local both = Gear.TwoHander() ~= nil
    local twos, ones = {}, {}
    for _, c in ipairs(main.list) do
        if c.e.slotType == 17 then twos[#twos + 1] = c else ones[#ones + 1] = c end
    end
    local wearing = {}
    if wornMain.id then wearing[wornMain.id] = true end
    if wornOff.id then wearing[wornOff.id] = true end
    local bestTwo, bestOne = Top(twos, stage, nil, wearing), Top(ones, stage, nil, wearing)
    local asTwo = math.max(bestTwo and bestTwo.score or 0, both and wornMain.score or 0)
    local oneScore = math.max(bestOne and bestOne.score or 0, both and 0 or wornMain.score)
    -- The same one-hander can't be in both hands.
    local mainPick = bestOne and bestOne.score > (both and 0 or wornMain.score) + 0.01 and bestOne.id or nil
    local bestOff = Top(off.list, stage, mainPick, wearing)
    local asPair = oneScore + math.max(bestOff and bestOff.score or 0, wornOff.score)
    -- What you hold already wins a tie.
    local two = both and asTwo >= asPair - 0.01 or (not both and asTwo > asPair + 0.01)
    local idle = { equip = 16, link = wornMain.link, id = wornMain.id, stats = wornMain.stats, score = 0 }
    -- A weapon of the other kind is no rival for the place (it counts as nothing there), but
    -- it's still what the row says you wear.
    if two then
        local row = Goal.Choose({ both and wornMain or idle }, twos, stage)[1]
        row.worn = wornMain
        return row, { equip = 17, worn = wornOff, taken = true }
    end
    local mainRow = Goal.Choose({ both and idle or wornMain }, ones, stage)[1]
    mainRow.worn = wornMain
    -- What's in the main hand, or is to be, isn't offered for the other one.
    local offRow = Goal.Choose({ wornOff }, off.list, stage, mainRow.goal and mainRow.goal.id or wornMain.id)[1]
    return mainRow, offRow
end

---------------------------------------------------------------------------
-- Where to go: the rows still to fill, a dungeon's pieces together.
---------------------------------------------------------------------------
-- From a stage's rows: `runs`, a dungeon or raid each with its pieces ({ row, boss, more,
-- chance }), the share of runs that bring at least one (`any`, from the chances known), most
-- pieces first; `other`, the rows got another way; and how many have no known source. Before
-- raids only dungeons are runs; with raids, both.
function Goal.Runs(rows, stage)
    local by, runs, other, unknown = {}, {}, {}, 0
    for _, row in ipairs(rows) do
        local from = row.goal and Goal.From(row.goal.e)
        if from and not row.done then
            if from.kind == "unknown" then
                unknown = unknown + 1
            elseif from.kind == "run" then
                local pieces = {}
                for _, r in ipairs(from.runs) do
                    if stage == Goal.RAIDS or not r.raid then
                        local piece = pieces[r.name]
                        if not piece then
                            piece = { row = row, boss = r.boss, best = r.chance or 0, more = -1, miss = 1 }
                            pieces[r.name] = piece
                            local run = by[r.name]
                            if not run then
                                run = { name = r.name, dungeon = r.dungeon, raid = r.raid, pieces = {} }
                                by[r.name] = run
                                runs[#runs + 1] = run
                            end
                            run.pieces[#run.pieces + 1] = piece
                        end
                        -- Several bosses of one dungeon: named by the likeliest, the chances together.
                        piece.more = piece.more + 1
                        if (r.chance or 0) > piece.best then piece.boss, piece.best = r.boss, r.chance end
                        if r.chance and r.chance > 0 then
                            piece.miss = piece.miss * (1 - math.min(r.chance, 100) / 100)
                            piece.known = true
                        end
                    end
                end
            else
                other[#other + 1] = row
            end
        end
    end
    for _, run in ipairs(runs) do
        local miss, known = 1, false
        for _, piece in ipairs(run.pieces) do
            if piece.known then
                piece.chance = (1 - piece.miss) * 100
                miss, known = miss * piece.miss, true
            end
        end
        run.any = known and (1 - miss) or nil
        table.sort(run.pieces, function(a, b)
            if (a.chance or -1) ~= (b.chance or -1) then return (a.chance or -1) > (b.chance or -1) end
            return a.row.equip < b.row.equip
        end)
    end
    table.sort(runs, function(a, b)
        if #a.pieces ~= #b.pieces then return #a.pieces > #b.pieces end
        if (a.any or 0) ~= (b.any or 0) then return (a.any or 0) > (b.any or 0) end
        return a.name < b.name
    end)
    return runs, other, unknown
end

---------------------------------------------------------------------------
-- The goal, both stages: kept until something it's worked out from changes
-- (Gear.PlansChanged), and worked out again while items are still arriving.
---------------------------------------------------------------------------
local function Side()
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    return faction == "Alliance" and 1 or faction == "Horde" and 2 or 0
end

-- A stage's rows, in the slots' order, each with its label, what it adds and how much better
-- it is as a share of all you wear.
local function StageRows(ctx, stage, lists)
    local rows = {}
    local function Add(row, slot, label)
        row.slot, row.label = slot, label
        if row.goal then
            row.gains = Gear.Gains(row.goal.stats, row.worn.stats, ctx.weights, slot.dps)
            row.share = ctx.total > 0 and (row.goal.score - row.worn.score) / ctx.total or nil
        end
        rows[#rows + 1] = row
    end
    for _, slot in ipairs(Gear.SLOTS) do
        if slot.key == "main" then
            local mainRow, offRow = Hands(ctx, stage, lists.main, lists.off)
            Add(mainRow, slot, slot.label)
            Add(offRow, lists.off.slot, lists.off.slot.label)
        elseif slot.key ~= "off" then
            local worn = {}
            for i, equip in ipairs(slot.equip) do worn[i] = Worn(equip, slot, ctx) end
            for i, row in ipairs(Goal.Choose(worn, lists[slot.key].list, stage)) do
                Add(row, slot, #slot.equip > 1 and (slot.label .. " " .. i) or slot.label)
            end
        end
    end
    local done, slots = 0, 0
    for _, row in ipairs(rows) do
        if not (row.taken or row.none) then
            slots = slots + 1
            if row.done then done = done + 1 end
        end
    end
    local runs, other, unknown = Goal.Runs(rows, stage)
    return { rows = rows, done = done, slots = slots, runs = runs, other = other, unknown = unknown }
end

---------------------------------------------------------------------------
-- WoWSims Forever's pre-raid sets (GearData.prebis): the goal before raids
-- where your class has one, from its sims, which know what weights can't
-- (the hit cap, a weapon and a bow picked as a pair). The weights' own best
-- for each slot are kept as its other choices.
---------------------------------------------------------------------------
-- The game's equipment places, in the sets' order.
local SET_EQUIP = { 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17, 18 }

-- Your class's builds with a set, and the one your talent tree starts on (nil for a tree
-- WoWSims has no set for).
function Goal.Builds(classFile, spec)
    local all = ns.GearData and ns.GearData.prebis and ns.GearData.prebis[classFile or ""]
    if not all then return nil end
    local start = all.default and all.default[spec or 1]
    return all, start or nil
end

-- A set's piece for a slot: the slot's scored one where it's there, else one made for it.
local function SetPiece(id, list, slot, ctx)
    for _, c in ipairs(list) do
        if c.id == id then return c end
    end
    local e = Gear.Lookup(id) or { id = id, ilvl = 0, kind = "", place = "" }
    local stats = Gear.Stats(id)
    -- Waited on while it's coming; one the game never sends is given up on, as the slots' own are.
    if not stats and not Gear.GivenUp(id) then ctx.waiting = ctx.waiting + 1 end
    stats = stats or {}
    return { e = e, id = id, stats = stats, score = Gear.Score(stats, ctx.weights, slot.dps) or 0, stage = Goal.BEFORE }
end

-- The rows of a stage whose goal is a set (`ids`, 17 in the sets' order): each place has the
-- set's piece; one you wear is done, in either place of a pair; an empty off hand under a
-- two-hander is taken.
-- `base`, where given, is WoWSims' set for the same places: each row keeps its piece (`base`),
-- the way back to it from a piece of yours.
local function SetRows(ctx, ids, lists, own, base)
    local slotOf, worn = {}, {}
    for _, slot in ipairs(Gear.SLOTS) do
        for _, equip in ipairs(slot.equip) do slotOf[equip] = slot end
    end
    for _, equip in ipairs(SET_EQUIP) do worn[equip] = Worn(equip, slotOf[equip], ctx) end
    local main = ids[15] or 0
    local _, _, _, loc
    if main > 0 and C_Item and C_Item.GetItemInfoInstant then _, _, _, loc = C_Item.GetItemInfoInstant(main) end
    local mainEntry = main > 0 and Gear.Lookup(main) or nil
    local twoHand = loc == "INVTYPE_2HWEAPON" or (mainEntry and mainEntry.slotType == 17) or false
    local rows = {}
    for i, equip in ipairs(SET_EQUIP) do
        local slot, id = slotOf[equip], ids[i] or 0
        local pair = #slot.equip > 1
        local row = { equip = equip, worn = worn[equip], slot = slot,
                      label = pair and (slot.label .. " " .. (equip == slot.equip[1] and 1 or 2)) or slot.label }
        if id == 0 then
            -- A place of a set of yours left empty is one to fill: it counts, and has picks.
            if equip == 17 and twoHand then row.taken = true elseif own then row.open = true else row.none = true end
        else
            local piece = SetPiece(id, lists[slot.key].list, slot, ctx)
            row.pick = piece
            local wearing = worn[equip].id == id
            for _, other in ipairs(pair and slot.equip or {}) do
                if worn[other].id == id then wearing = true end
            end
            if wearing then
                row.done = true
            else
                row.goal = piece
                row.gains = Gear.Gains(piece.stats, row.worn.stats, ctx.weights, slot.dps)
                row.share = ctx.total > 0 and (piece.score - row.worn.score) / ctx.total or nil
            end
        end
        local baseId = base and base[i] or 0
        if baseId > 0 then row.base = baseId == id and row.pick or SetPiece(baseId, lists[slot.key].list, slot, ctx) end
        rows[#rows + 1] = row
    end
    local done, slots = 0, 0
    for _, row in ipairs(rows) do
        if not (row.taken or row.none) then
            slots = slots + 1
            if row.done then done = done + 1 end
        end
    end
    local runs, other, unknown = Goal.Runs(rows, Goal.BEFORE)
    return { rows = rows, done = done, slots = slots, runs = runs, other = other, unknown = unknown }
end

-- A slot's other choices: the weights' best for the slot in a stage (before raids by
-- default), leaving out the goal's own pieces and anything of their names, up to `n`, each
-- with how it stands against the slot's goal by your weights (`against`, a share: -0.02 is
-- 2% under it).
function Goal.Others(read, row, n, stage)
    stage = stage or Goal.BEFORE
    local out = {}
    local pick = row and (row.pick or row.goal)
    local list = (pick or (row and row.open)) and read.lists and read.lists[row.slot.key]
    if not list then return out end
    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local skip, names = {}, {}
    for _, r in ipairs(read[stage].rows) do
        local own = r.pick or r.goal
        if r.slot == row.slot and own then
            skip[own.id] = true
            local name = get and get(own.id)
            if name then names[name] = true end
        end
    end
    -- WoWSims' piece for the place first, where it isn't the pick: the way back to it.
    local base = row.base
    if base and not (pick and pick.id == base.id) then
        skip[base.id] = true
        local name = get and get(base.id)
        if name then names[name] = true end
        out[1] = { piece = base, base = true, against = pick and pick.score > 0 and (base.score - pick.score) / pick.score or nil }
    end
    local first = #out
    for _, c in ipairs(list.list) do
        local name = get and get(c.id)
        if c.stage <= stage and not c.unknown and not skip[c.id] and not (name and names[name]) then
            if name then names[name] = true end
            out[#out + 1] = { piece = c, against = pick and pick.score > 0 and (c.score - pick.score) / pick.score or nil }
            if #out - first >= (n or 3) then break end
        end
    end
    return out
end

---------------------------------------------------------------------------
-- Sets of your own, kept for the character (ns.char.prebisSets): each a
-- name, its 17 item IDs in the sets' order, the build it was started from,
-- and a key ("own" and a number) that stays when it's renamed.
---------------------------------------------------------------------------
function Goal.OwnSets()
    if not ns.char then return {} end
    ns.char.prebisSets = type(ns.char.prebisSets) == "table" and ns.char.prebisSets or {}
    return ns.char.prebisSets
end

function Goal.OwnSet(key)
    for _, set in ipairs(Goal.OwnSets()) do
        if set.key == key then return set end
    end
end

local function Changed() Gear.PlansChanged() end

-- A new set from `ids` (copied; nil for an empty one), named `name` or "My set" and the
-- lowest number no set of yours has; its key, which is never used again.
function Goal.NewSet(ids, from, name)
    local sets = Goal.OwnSets()
    ns.char.prebisNext = (tonumber(ns.char.prebisNext) or 0) + 1
    local copy = {}
    for i = 1, #SET_EQUIP do copy[i] = tonumber(ids and ids[i]) or 0 end
    if not name then
        local taken = {}
        for _, set in ipairs(sets) do taken[set.name] = true end
        local n = 1
        while taken["My set " .. n] do n = n + 1 end
        name = "My set " .. n
    end
    local set = { key = "own" .. ns.char.prebisNext, name = name, ids = copy, from = from }
    sets[#sets + 1] = set
    Changed()
    return set.key
end

function Goal.RenameSet(key, name)
    local set = Goal.OwnSet(key)
    name = name and name:match("^%s*(.-)%s*$") or ""
    if set and name ~= "" then
        set.name = name:sub(1, 24)
        Changed()
    end
end

function Goal.DeleteSet(key)
    local sets = Goal.OwnSets()
    for i, set in ipairs(sets) do
        if set.key == key then
            table.remove(sets, i)
            Changed()
            return
        end
    end
end

-- Puts an item in place `i` of a set of your own (the sets' order).
function Goal.SetSlot(key, i, id)
    local set = Goal.OwnSet(key)
    if set and i and i >= 1 and i <= #SET_EQUIP then
        set.ids[i] = tonumber(id) or 0
        Changed()
    end
end

-- A set of yours given `ids` (copied) in place of its own: a change saved over it.
function Goal.SaveSet(key, ids)
    local set = Goal.OwnSet(key)
    if not set then return end
    for i = 1, #SET_EQUIP do set.ids[i] = tonumber(ids and ids[i]) or 0 end
    Changed()
end

-- Whether an item fits place `i` (the sets' order): its kind of slot, or for the off hand
-- what a hand holds. Nil while the game hasn't sent it.
function Goal.Fits(id, i)
    if not (C_Item and C_Item.GetItemInfoInstant) then return nil end
    local _, _, _, loc = C_Item.GetItemInfoInstant(id)
    if not loc then return nil end
    local invType = Gear.INVTYPE and Gear.INVTYPE[loc]
    local equip = SET_EQUIP[i]
    for _, slot in ipairs(Gear.SLOTS) do
        for _, e in ipairs(slot.equip) do
            if e == equip then
                for _, t in ipairs(slot.types) do
                    if t == invType then return true end
                end
                if equip == 17 and (invType == 13 or invType == 21) then return true end
                return false
            end
        end
    end
    return false
end

-- The set that's your goal before raids, as the view chooses it: one of yours, or WoWSims'
-- build (the one kept for the character, else the tree's own; full or cheap). Its 17 IDs and
-- its name; nil with none.
-- A WoWSims build's set (full or cheap) as 17 IDs, each from your side's quartermaster.
local function IdsOf(build, cheap, side)
    local ids = {}
    for n in ((cheap and build.cheap) or build.full or ""):gmatch("%d+") do ids[#ids + 1] = Twin(tonumber(n), side) end
    return ids
end

function Goal.ChosenSet()
    local keptChoice = ns.char and type(ns.char.prebis) == "table" and ns.char.prebis or {}
    local own = keptChoice.build and Goal.OwnSet(keptChoice.build)
    if own then return own.ids, own.name end
    local _, classFile = UnitClass("player")
    local builds, start = Goal.Builds(classFile, Gear.Spec())
    local chosen
    for _, b in ipairs(builds or {}) do
        if b.key == keptChoice.build then chosen = b end
    end
    for _, b in ipairs(chosen and {} or builds or {}) do
        if b.key == start then chosen = b end
    end
    if not chosen then return nil end
    return IdsOf(chosen, keptChoice.cheap, Side()), chosen.name
end

-- The WoWSims build your At 60 set is (or a set of yours started from), and its name: for the
-- Build Planner's YOUR SET. nil for a set of yours started empty, or a tree with no set.
function Goal.SetKey()
    local keptChoice = ns.char and type(ns.char.prebis) == "table" and ns.char.prebis or {}
    local own = keptChoice.build and Goal.OwnSet(keptChoice.build)
    local _, classFile = UnitClass("player")
    local builds, start = Goal.Builds(classFile, Gear.Spec())
    local key = own and own.from or keptChoice.build
    for _, b in ipairs(builds or {}) do
        if b.key == key then return b.key, b.name end
    end
    if own then return nil end
    for _, b in ipairs(builds or {}) do
        if b.key == start then return b.key, b.name end
    end
end

-- Whether an item is in your set and not worn: the slot it's for ("Trinket 1"), else nil. For
-- the drop alert: worked out again only when the plans change.
local wantedStamp, wanted
function Goal.Wanted(id)
    if wantedStamp ~= Gear.planStamp then
        wantedStamp, wanted = Gear.planStamp, {}
        local ids = Goal.ChosenSet()
        for i, n in ipairs(ids or {}) do
            local equip = SET_EQUIP[i]
            for _, slot in ipairs(Gear.SLOTS) do
                for k, e in ipairs(slot.equip) do
                    if e == equip and n > 0 then wanted[n] = #slot.equip > 1 and (slot.label .. " " .. k) or slot.label end
                end
            end
        end
    end
    local slot = id and wanted[id]
    local equipped = C_Item and C_Item.IsEquippedItem
    if slot and equipped and equipped(id) then return nil end
    return slot
end

local kept
local KEEP = 600
-- { [Goal.BEFORE] = stage, [Goal.RAIDS] = stage, waiting, ceiling, set, lists }, or
-- { noWeights = true } for a spec with no weights. A stage: { rows, done, slots, runs, other,
-- unknown }; a row: { slot, label, equip, worn, goal, done, taken, none, unknown, gains, share,
-- pick (a set's piece) }. `build` and `cheap` choose the set (the tree's own build, full, by
-- default); `set` says which it is: { builds, key, name, cheap, hasCheap }, nil with none.
-- `draft`, where given, is 17 IDs in the sets' order: a change to the set not yet saved, read in
-- the set's place.
function Goal.Read(spec, build, cheap, draft)
    spec = spec or Gear.Spec()
    cheap = cheap and true or false
    local drafted = draft and table.concat(draft, ",") or ""
    local now = GetTime and GetTime()
    if kept and kept.stamp == Gear.planStamp and kept.spec == spec and kept.build == build and kept.cheap == cheap and kept.drafted == drafted
        and now and kept.at and now - kept.at < KEEP and (kept.waiting == 0 or kept.at == now) then
        return kept
    end
    local weights = Gear.Weights(spec)
    local _, classFile, classID = UnitClass("player")
    local out = { stamp = Gear.planStamp, spec = spec, build = build, cheap = cheap, drafted = drafted, at = now, waiting = 0 }
    kept = out
    if not (weights and ns.GearData) then
        out.noWeights = true
        return out
    end
    local class = Gear.CLASS_GEAR[classFile or ""]
    local ctx = { data = ns.GearData, weights = weights, classFile = classFile, classID = classID, side = Side(), waiting = 0,
                  dual = (class and class.dualWield and Goal.LEVEL >= class.dualWield) or Gear.DualWields(classFile, Goal.LEVEL) }
    ctx.key = table.concat({ classFile or "", classID or 0, ctx.side, ctx.dual and 1 or 0 }, ":")
    ctx.ceiling = Ceiling(ctx)
    ctx.total = Gear.WornTotal(weights)
    local lists = {}
    for _, slot in ipairs(Gear.SLOTS) do lists[slot.key] = { slot = slot, list = Scored(slot, ctx) } end
    out.lists = lists
    local builds, start = Goal.Builds(classFile, spec)
    -- The build asked for, or the tree's own when it's none of WoWSims' (a set of yours, or one deleted).
    local chosen
    for _, b in ipairs(builds or {}) do
        if b.key == build then chosen = b end
    end
    for _, b in ipairs(chosen and {} or builds or {}) do
        if b.key == start then chosen = b end
    end
    local own = build and Goal.OwnSet(build)
    if own then
        local fromName
        for _, b in ipairs(builds or {}) do
            if b.key == own.from then fromName = b.name end
        end
        out.set = { builds = builds or {}, key = own.key, name = own.name, own = true, from = fromName, ids = own.ids, hasCheap = false }
        -- WoWSims' set it was started from (else the tree's), for the way back to its pieces.
        local from
        for _, b in ipairs(builds or {}) do
            if b.key == own.from then from = b end
        end
        for _, b in ipairs(from and {} or builds or {}) do
            if b.key == start then from = b end
        end
        out[Goal.BEFORE] = SetRows(ctx, draft or own.ids, lists, true, from and IdsOf(from, false, ctx.side))
        chosen = own
    elseif chosen then
        local ids = IdsOf(chosen, cheap, ctx.side)
        out.set = { builds = builds, key = chosen.key, name = chosen.name, cheap = cheap and chosen.cheap ~= nil, hasCheap = chosen.cheap ~= nil, ids = ids }
        out[Goal.BEFORE] = SetRows(ctx, draft or ids, lists, nil, ids)
    else
        out[Goal.BEFORE] = StageRows(ctx, Goal.BEFORE, lists)
    end
    out[Goal.RAIDS] = StageRows(ctx, Goal.RAIDS, lists)
    -- With raids, nothing of the set is given up for a raid's piece the weights think less of.
    if chosen then
        local raids, changed = out[Goal.RAIDS], false
        for i, row in ipairs(raids.rows) do
            local pick = out[Goal.BEFORE].rows[i] and out[Goal.BEFORE].rows[i].pick
            if pick and row.goal and row.goal.score < pick.score then
                row.goal, row.pick, row.unknown, changed = pick, pick, nil, true
                row.gains = Gear.Gains(pick.stats, row.worn.stats, ctx.weights, row.slot.dps)
                row.share = ctx.total > 0 and (pick.score - row.worn.score) / ctx.total or nil
            end
        end
        if changed then raids.runs, raids.other, raids.unknown = Goal.Runs(raids.rows, Goal.RAIDS) end
    end
    out.waiting, out.ceiling = ctx.waiting, ctx.ceiling
    return out
end
