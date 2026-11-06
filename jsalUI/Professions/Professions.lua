-- Professions: where you stand in each, and a road to the next rank. The
-- road takes, level by level, the recipe that gets the next point for the
-- fewest materials: one that's orange always gives a point; a yellow or
-- green one gives it less often the nearer it is to grey.
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
end

function Professions.Remembered(line)
    local all = type(ns.char.professions) == "table" and ns.char.professions or {}
    return all[line]
end

-- Your professions, from the game's own list: each one's skill line, name,
-- icon, skill and cap, for the ones jsal.ui has recipes for.
function Professions.Mine()
    local out = {}
    if not GetProfessions then return out end
    for _, index in ipairs({ GetProfessions() }) do
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

-- An item's cost in materials: a vendor's thread or dye counts for little,
-- and a bolt or bar counts as what it's made from.
local function ItemWeight(line, item, depth)
    if Data.vendor[item] then return 0.1 end
    local recipe = (depth or 0) < 2 and MadeBy(line, item)
    if not recipe then return 1 end
    local w = 0
    for _, reagent in ipairs(recipe.reagents) do
        w = w + reagent.count * ItemWeight(line, reagent.item, (depth or 0) + 1)
    end
    return w / math.max(1, recipe.makes or 1)
end

-- A craft's cost: its materials, plus a little for the craft itself, so a
-- recipe that only sometimes gives a point isn't picked just for being cheap.
local function Weight(line, recipe)
    if recipe.weight then return recipe.weight end
    local w = 2
    for _, reagent in ipairs(recipe.reagents) do
        w = w + reagent.count * ItemWeight(line, reagent.item)
    end
    recipe.weight = w
    return w
end

function Professions.IsVendor(item)
    return Data.vendor[item]
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

-- The road from skill to target. known(spell) says whether a recipe is
-- learned; trainer recipes can be learned along the way, patterns only once
-- you have them. Returns the steps ({ from, to, recipe, crafts, learn }),
-- each reagent's total, the skill where it stopped short if it did, and
-- the materials added for bolts and bars you're short of.
function Professions.Plan(line, skill, target, known)
    local recipes = Professions.Recipes(line) or {}
    local steps, totals = {}, {}
    local s = skill
    while s < target do
        local best, bestCost
        for _, recipe in ipairs(recipes) do
            local mine = known(recipe.spell)
            -- A recipe you know counts whatever skill the data says it's
            -- learned at (some are taught earlier than that); one from a
            -- trainer counts once your skill reaches it.
            if mine or (recipe.how == 1 and recipe.learn <= s) then
                local chance = Chance(recipe, s)
                if chance > 0 then
                    local cost = Weight(line, recipe) / chance + (mine and 0 or 0.01)
                    if not best or cost < bestCost then best, bestCost = recipe, cost end
                end
            end
        end
        if not best then break end
        local crafts = 1 / Chance(best, s)
        local last = steps[#steps]
        if last and last.recipe == best then
            last.to, last.exact = s + 1, last.exact + crafts
        else
            steps[#steps + 1] = { from = s, to = s + 1, recipe = best, exact = crafts, learn = not known(best.spell) }
        end
        s = s + 1
    end
    for _, step in ipairs(steps) do
        step.crafts = math.ceil(step.exact - 0.01)
        for _, reagent in ipairs(step.recipe.reagents) do
            totals[reagent.item] = (totals[reagent.item] or 0) + reagent.count * step.crafts
        end
    end
    -- A bolt or bar you're short of adds what it's made from.
    local made = {}
    for item, need in pairs(totals) do
        local recipe = MadeBy(line, item)
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
