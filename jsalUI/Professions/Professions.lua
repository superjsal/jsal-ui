-- Professions: where you stand in each, and a road to the next rank. The
-- road takes, level by level, the recipe that gets the next point for the
-- least worth of materials: one that's orange always gives a point; a
-- yellow or green one gives it less often the nearer it is to grey.
local _, ns = ...
local Compat = ns.Compat

local Professions = {}
ns.Professions = Professions

local Data = ns.ProfessionData

-- The ranks: each one's cap, and the skill and level to learn the next.
local RANKS = {
    { cap = 75, name = "Apprentice", next = "Journeyman", at = 50, level = 10 },
    { cap = 150, name = "Journeyman", next = "Expert", at = 125, level = 20 },
    { cap = 225, name = "Expert", next = "Artisan", at = 200, level = 35 },
    { cap = 300, name = "Artisan" },
}
Professions.RANKS = RANKS

-- A recipe from the data, as a table.
local function Recipe(flat)
    local r = { spell = flat[1], learn = flat[2], yellow = flat[3], grey = flat[4], how = flat[5],
                item = flat[6] ~= 0 and flat[6] or nil, makes = flat[7], reagents = {} }
    for i = 8, #flat - 1, 2 do
        r.reagents[#r.reagents + 1] = { item = flat[i], count = flat[i + 1] }
    end
    return r
end

local cache = {}
function Professions.Recipes(line)
    if cache[line] then return cache[line] end
    local source = Data[line]
    if not source then return nil end
    local list = {}
    for i, flat in ipairs(source.recipes) do list[i] = Recipe(flat) end
    cache[line] = list
    return list
end

-- The profession's skill line from its name, as the game names it.
function Professions.LineByName(name)
    for line, source in pairs(Data) do
        if type(source) == "table" and source.name == name then return line end
    end
end

function Professions.Name(line)
    return Data[line] and Data[line].name
end

function Professions.Rank(cap)
    for _, rank in ipairs(RANKS) do
        if cap <= rank.cap then return rank end
    end
    return RANKS[#RANKS]
end

-- What this character knows in a profession, as last seen in its window:
-- { skill, cap, known = { [spell] = true }, seen }.
function Professions.Remember(line, skill, cap, spells)
    ns.char.professions = type(ns.char.professions) == "table" and ns.char.professions or {}
    local known = {}
    for _, spell in ipairs(spells) do known[spell] = true end
    ns.char.professions[line] = { skill = skill, cap = cap, known = known, seen = Compat.ServerTime() }
    -- Guild crafters tells the guild when what you can make has changed.
    if ns.Crafters and ns.Crafters.Changed then ns.Crafters.Changed() end
end

function Professions.Remembered(line)
    local all = type(ns.char.professions) == "table" and ns.char.professions or {}
    return all[line]
end

-- Your professions, from the game's own list: each one's skill line, name,
-- icon, skill and cap, for the ones jsal.ui has recipes for.
-- The game's list has a place for each kind (two main ones, then
-- fishing, cooking and so on) and leaves a gap for one you don't have: so
-- every place is looked at, not only those before the first gap. Stopping
-- at the gap left out whatever came after it (John, 13 Nov 2026, with no
-- Fishing: "doesnt seem to count cooking as a profession").
local function Places(...) return select("#", ...), { ... } end

function Professions.Mine()
    local out = {}
    if not GetProfessions then return out end
    local count, places = Places(GetProfessions())
    for i = 1, count do
        local index = places[i]
        if index then
            local name, icon, skill, cap, _, _, line = GetProfessionInfo(index)
            line = (line and Data[line] and line) or Professions.LineByName(name)
            if line then
                out[#out + 1] = { line = line, name = Data[line].name, icon = icon, skill = skill or 0, cap = cap or 0 }
            end
        end
    end
    return out
end

-- Where a road goes from a skill: the skill the next rank is learned at
-- while you're below it, else the rank's cap.
function Professions.Target(skill, cap)
    local rank = Professions.Rank(cap)
    return (rank.at and skill < rank.at) and rank.at or cap, rank
end

-- The chance a craft at this skill gives a point: always while orange, then
-- falling to nothing at grey.
local function Chance(recipe, skill)
    if skill >= recipe.grey then return 0 end
    if skill < recipe.yellow then return 1 end
    return (recipe.grey - skill) / (recipe.grey - recipe.yellow)
end
Professions.Chance = Chance

-- What makes an item within a profession (a bolt from cloth, a bar from ore).
local madeBy = {}
local function MadeBy(line, item)
    if not madeBy[line] then
        madeBy[line] = {}
        for _, recipe in ipairs(Professions.Recipes(line) or {}) do
            if recipe.item and not madeBy[line][recipe.item] then madeBy[line][recipe.item] = recipe end
        end
    end
    return madeBy[line][item]
end
Professions.MadeBy = MadeBy

-- What an item is worth, in copper: a vendor's price for thread or dye,
-- the worth the data gives every other material, or what it's made from
-- where that's less (a bolt from cloth, a bar from ore). Materials used to
-- count one each, so the road went through forty hides, sixty elixirs or a
-- dozen Righteous Orbs as readily as through leather (John, 13 Nov 2026,
-- shown ours beside Wowhead's: "lets make ours better for sure").
local function ItemWeight(line, item, depth)
    local own = Data.vendor[item] or (Data.value and Data.value[item]) or 100
    local recipe = (depth or 0) < 2 and MadeBy(line, item)
    if not recipe then return own end
    local w = 0
    for _, reagent in ipairs(recipe.reagents) do
        w = w + reagent.count * ItemWeight(line, reagent.item, (depth or 0) + 1)
    end
    return math.min(own, w / math.max(1, recipe.makes or 1))
end

-- The recipe that makes an item, where making it is how you'd come by it:
-- a bolt from cloth, a cured hide from a hide. A leather that's also
-- skinned as it is (heavy leather, or five medium) is worth less than what
-- it would be made from, and is asked for as itself: the road's list read
-- 105 Heavy Leather and 588 Medium and 444 Light for the same crafts.
local function Makes(line, item)
    if Data.gathered and Data.gathered[item] then return nil end
    return MadeBy(line, item)
end
Professions.Makes = Makes

-- Where a rank comes from when it isn't a trainer: First Aid's Expert is a
-- book a vendor sells, and its Artisan a quest (Wowhead's First Aid guide
-- for Forever, 13 Nov 2026). Returns what to do and a line about it, or nil
-- for a rank a trainer teaches.
local FIRST_AID = 129
local OTHER_RANKS = {
    [FIRST_AID] = {
        Expert = { "learn Expert from a book", "Expert First Aid - Under Wraps, sold by a vendor" },
        Artisan = { "learn Artisan from the quest Triage", "a doctor gives it, from level 35" },
    },
}
function Professions.RankFrom(line, name)
    local ranks = OTHER_RANKS[line]
    local from = ranks and ranks[name]
    if from then return from[1], from[2] end
end

-- A craft's cost: its materials, plus a little for the craft itself, so a
-- recipe that only sometimes gives a point isn't picked just for being cheap.
local function Weight(line, recipe)
    if recipe.weight then return recipe.weight end
    local w = 100
    for _, reagent in ipairs(recipe.reagents) do
        w = w + reagent.count * ItemWeight(line, reagent.item)
    end
    recipe.weight = w
    return w
end

-- How much dearer the recipe in hand may be than the best one before the
-- road changes to the other.
Professions.STAY = 1.15
-- How much of its worth a material you already have is let off.
Professions.OWNED = 0.95
-- The chance of a point at which a recipe turns green in the game's list:
-- half way from yellow to grey. The road takes a green recipe only when
-- nothing yellow or orange can be made. Leftovers count as nearly free, so
-- a green recipe that used them up looked cheapest: at 121 the road said
-- Light Leather Pants, three chances in ten, for 40 Light Leather and four
-- Cured Light Hide, and nine of them gave no point at all. (John, 14 Nov
-- 2026: "does this make sense to use light leather pants to get to 125? i
-- just made 5 and did not get a single skillpoint", then "i just made 4
-- more light leather pants and got 0 skill points".)
Professions.GREEN = 0.5
-- The least chance of a point a recipe may have and still be on the road.
Professions.LEAST = 0.1

function Professions.IsVendor(item)
    return Data.vendor[item]
end

-- Whether a pattern can simply be bought: some vendor sells it for coin
-- alone. One that wants a standing with a faction, or a currency of its
-- own, or that no vendor is known to sell, counts on the road only once
-- you have it, as a dropped pattern does. Without the list of who sells
-- what, every vendor pattern counts.
function Professions.Buyable(spell)
    local data = ns.RecipeSources
    if not (data and data.recipes) then return true end
    local entry = data.recipes[spell]
    return entry ~= nil and entry.v ~= nil and entry.n == nil
end

-- How many of a recipe the bags hold enough for.
function Professions.CanMake(recipe)
    local most
    for _, reagent in ipairs(recipe.reagents) do
        local have = Compat.ItemCount(reagent.item, false)
        local n = math.floor(have / reagent.count)
        most = most and math.min(most, n) or n
    end
    return most or 0
end

-- Mining's skill comes from mining ore, not from smelting, so its road is
-- the veins to mine: each from the skill classic WoW sets, a sure point for
-- its first 25 skill, then fewer until it's grey 100 past it. Only the
-- common veins; the ore names the icon. Each is shaped like a recipe.
local MINING = 186
local VEINS = {
    { "Copper Vein", 1, 2770 }, { "Tin Vein", 65, 2771 }, { "Iron Deposit", 125, 2772 },
    { "Mithril Deposit", 175, 3858 }, { "Small Thorium Vein", 245, 10620 }, { "Rich Thorium Vein", 275, 10620 },
}
local veins
local function Veins()
    if not veins then
        veins = {}
        for i, v in ipairs(VEINS) do
            veins[i] = { label = v[1], learn = v[2], yellow = v[2] + 25, grey = v[2] + 100, item = v[3], reagents = {}, how = 1, vein = true }
        end
    end
    return veins
end

function Professions.IsGathering(line) return line == MINING end

-- The road from skill to target. known(spell) says whether a recipe is
-- learned; trainer recipes can be learned along the way, and a pattern a
-- vendor sells for coin can be bought (it counts as half again as costly,
-- so it's picked only when it's clearly better or nothing else gives a
-- point). Dropped and quest patterns, and ones a vendor wants more than
-- coin for, count only once you have them. `breakAt` is a skill no step
-- runs across (the one the next rank is learned at), so the road can say
-- what to do there. Returns the steps ({ from, to, recipe, crafts, safe,
-- learn, buy }: crafts is how many it takes on average, safe how many
-- cover nine times in ten), each reagent's total, the skill where it
-- stopped short if it did, and the materials added for bolts and bars
-- you're short of.
function Professions.Plan(line, skill, target, known, breakAt)
    local recipes = line == MINING and Veins() or Professions.Recipes(line) or {}
    local steps, totals = {}, {}
    -- What's in your bags and bank counts as nearly free until the road has
    -- used it up, so a pile of leather or cloth you already have gets spent
    -- before anything is made or bought.
    local stock = setmetatable({}, { __index = function(t, item)
        local n = Compat.ItemCount(item, true) or 0
        rawset(t, item, n)
        return n
    end })
    local function Cost(recipe)
        local w = Weight(line, recipe)
        for _, reagent in ipairs(recipe.reagents) do
            local owned = math.min(stock[reagent.item], reagent.count)
            if owned > 0 and not Data.vendor[reagent.item] then
                w = w - owned * ItemWeight(line, reagent.item) * Professions.OWNED
            end
        end
        return w
    end
    local s = skill
    local staying
    while s < target do
        local best, bestCost
        local fair, fairCost
        local stayCost, stayFair
        for _, recipe in ipairs(recipes) do
            local mine = recipe.vein or known(recipe.spell)
            -- A recipe you know counts whatever skill the data says it's
            -- learned at (some are taught earlier than that); one from a
            -- trainer counts once your skill reaches it.
            if mine or ((recipe.how == 1 or (recipe.how == 2 and Professions.Buyable(recipe.spell))) and recipe.learn <= s) then
                local chance = Chance(recipe, s)
                -- The last few points before a recipe goes grey take ten
                -- crafts or more each: that's no way forward, so the road
                -- stops there and says so.
                if chance >= Professions.LEAST then
                    local cost = Cost(recipe) / chance + (mine and 0 or 0.01)
                    if not mine and recipe.how == 2 then cost = cost * 1.5 end
                    if not best or cost < bestCost then best, bestCost = recipe, cost end
                    if chance >= Professions.GREEN and (not fair or cost < fairCost) then fair, fairCost = recipe, cost end
                    if recipe == staying then stayCost, stayFair = cost, chance >= Professions.GREEN end
                end
            end
        end
        if not best then break end
        -- Yellow and orange before green: a green one only as a last resort,
        -- and the one in hand isn't kept once it has gone green.
        if fair then
            best, bestCost = fair, fairCost
            if not stayFair then stayCost = nil end
        end
        -- The recipe already being made is kept while it costs little more
        -- than the best, so the road is a few long steps, not one craft of
        -- this between two runs of that.
        if stayCost and stayCost <= bestCost * Professions.STAY then best = staying end
        staying = best
        local chance = Chance(best, s)
        local crafts = 1 / chance
        -- How far the count can stray: each point takes one craft in
        -- `chance`, so the spread of a point is (1 - chance) / chance^2.
        local spread = (1 - chance) / (chance * chance)
        for _, reagent in ipairs(best.reagents) do
            stock[reagent.item] = math.max(0, stock[reagent.item] - reagent.count * crafts)
        end
        local last = steps[#steps]
        if last and last.recipe == best and s ~= breakAt then
            last.to, last.exact, last.spread = s + 1, last.exact + crafts, last.spread + spread
        else
            local learn = not best.vein and not known(best.spell)
            steps[#steps + 1] = { from = s, to = s + 1, recipe = best, exact = crafts, spread = spread,
                                  learn = learn, buy = learn and best.how == 2 }
        end
        s = s + 1
    end
    for _, step in ipairs(steps) do
        step.crafts = math.ceil(step.exact - 0.01)
        -- Enough for nine tries in ten: the average and 1.28 spreads more.
        step.safe = math.max(step.crafts, math.ceil(step.exact + 1.2816 * math.sqrt(step.spread) - 0.01))
        for _, reagent in ipairs(step.recipe.reagents) do
            totals[reagent.item] = (totals[reagent.item] or 0) + reagent.count * step.crafts
        end
    end
    -- A bolt or bar you're short of adds what it's made from.
    local made = {}
    for item, need in pairs(totals) do
        local recipe = Makes(line, item)
        local short = need - Compat.ItemCount(item, true)
        if recipe and short > 0 then
            local times = math.ceil(short / math.max(1, recipe.makes or 1))
            for _, reagent in ipairs(recipe.reagents) do
                made[reagent.item] = (made[reagent.item] or 0) + reagent.count * times
            end
        end
    end
    for item, need in pairs(made) do totals[item] = (totals[item] or 0) + need end
    return steps, totals, s < target and s or nil, made
end
