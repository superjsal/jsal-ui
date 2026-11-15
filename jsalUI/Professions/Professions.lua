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
-- for Forever, 13 Nov 2026). Cooking's are the same two ways: its trainers
-- teach Apprentice and Journeyman and no more, and the panel named any cook
-- for Expert (Wowhead's Cooking guide for Forever, 14 Nov 2026: "Expert
-- Cooking comes from The Expert Cookbook, sold by Shandrina or Wulan, and
-- Artisan from the quest Clamlette Surprise"). Returns what to do, a line
-- about it, and who to see for it where that's known, shaped like a trainer
-- for the map pin; or nil for a rank a trainer teaches. Who: Shandrina
-- sells the book to the Alliance in Ashenvale and Wulan to the Horde in
-- Desolace, a gold each; Dirge Quikcleave in Gadgetzan gives and takes the
-- quest, for both sides, from level 35 (Wowhead Forever's pages for item
-- 16072 and quest 6610, 14 Nov 2026).
local FIRST_AID, COOKING, ENCHANTING = 129, 185, 333
local OTHER_RANKS = {
    -- Enchanting's Artisan is a trainer's, but one inside a dungeon: Annora, Master Enchanter,
    -- in Uldaman, for both sides (Wowhead Forever's page for the rank's spell, 13920, 14 Nov
    -- 2026). No trainer outside teaches it, and the row said jsal.ui didn't know one.
    [ENCHANTING] = {
        Artisan = { "train Artisan inside Uldaman", "Annora, Master Enchanter, teaches it there" },
    },
    [COOKING] = {
        Expert = { "learn Expert from a book", "The Expert Cookbook, sold by",
                   a = { npc = 3955, name = "Shandrina", map = 1440, x = 0.494, y = 0.67 },
                   h = { npc = 12033, name = "Wulan", map = 1443, x = 0.262, y = 0.698 } },
        Artisan = { "learn Artisan from the quest Clamlette Surprise", "from level 35, given by",
                    a = { npc = 8125, name = "Dirge Quikcleave", map = 1446, x = 0.526, y = 0.28 } },
    },
    -- First Aid's: Deneb Walker in Arathi Highlands sells the book to the
    -- Alliance and Balai Lok'Wein in Dustwallow Marsh to the Horde; Triage is
    -- Doctor Gustaf VanHowzen's in Dustwallow Marsh for the Alliance and
    -- Doctor Gregory Victor's in Arathi Highlands for the Horde, from level
    -- 35 (Wowhead Forever's pages for item 16084 and quests 6624 and 6622,
    -- 14 Nov 2026; John, of Cooking's: "Find the npcs", "And the quest").
    [FIRST_AID] = {
        Expert = { "learn Expert from a book", "Expert First Aid - Under Wraps, sold by",
                   a = { npc = 2805, name = "Deneb Walker", map = 1417, x = 0.27, y = 0.588 },
                   h = { npc = 13476, name = "Balai Lok'Wein", map = 1445, x = 0.364, y = 0.304 } },
        Artisan = { "learn Artisan from the quest Triage", "from level 35, given by",
                    a = { npc = 12939, name = "Doctor Gustaf VanHowzen", map = 1445, x = 0.676, y = 0.488 },
                    h = { npc = 12920, name = "Doctor Gregory Victor", map = 1417, x = 0.734, y = 0.364 } },
    },
}
-- The skill a rank's next one is learned at, where it isn't the usual. First Aid's Artisan is the
-- quest Triage, which follows Alliance Trauma or Horde Trauma, and those are given at First Aid
-- 225, not 200: "She wouldn't give me the quest when I was lvl 36 with First Aid 210, but I
-- received it right after I hit 225" (the comments on Wowhead Forever's page for Alliance
-- Trauma, quest 6625, read 14 Nov 2026; they are Classic's players, and nobody has yet been seen
-- to take it on Forever). The row said "At 200".
local OTHER_AT = {
    [FIRST_AID] = { Expert = 225 },
}
function Professions.At(line, rank)
    local other = line and OTHER_AT[line]
    return other and rank and other[rank.name] or (rank and rank.at)
end

function Professions.RankFrom(line, name)
    local ranks = OTHER_RANKS[line]
    local from = ranks and ranks[name]
    if not from then return end
    -- The Horde's, where each side has its own; the one there is, where
    -- both share it.
    local who = from.a
    if from.h and UnitFactionGroup and UnitFactionGroup("player") == "Horde" then who = from.h end
    return from[1], from[2], who
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

-- How long before a recipe can be made again, in seconds, or nil: the
-- transmutes, Mooncloth. The road takes one only when nothing else gives a
-- point. It took them as readily as any other: Tailoring's road from 230 to
-- 286 was 63 Mooncloth, one every four days, and Alchemy's from 225 to 261
-- was 45 transmutes of iron to gold, one an hour. (Found by playing every
-- road through, 14 Nov 2026; the waits are the game's own.)
function Professions.Wait(recipe)
    return Data.cooldown and recipe.spell and Data.cooldown[recipe.spell] or nil
end

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

-- The specialisation a recipe needs before a trainer will teach it (Goblin
-- or Gnomish Engineer, Armorsmith, Tribal Leatherworking and the rest), as
-- that specialisation's spell, or nil. The road counted these as any
-- trainer's recipes: Blacksmithing's went through Truesilver Breastplate, an
-- Armorsmith's, and Leatherworking's through Frostsaber Boots, a Tribal
-- Leatherworker's. Now one is on the road only once you know it. (Found by
-- playing every road through, 14 Nov 2026; which recipes, from Wowhead
-- Forever's lists.)
function Professions.Needs(recipe)
    return Data.needs and recipe.spell and Data.needs[recipe.spell] or nil
end

-- The road from skill to target. known(spell) says whether a recipe is
-- learned; trainer recipes can be learned along the way, and a pattern a
-- vendor sells for coin can be bought (it counts as half again as costly,
-- so it's picked only when it's clearly better or nothing else gives a
-- point). Dropped and quest patterns, ones a vendor wants more than coin
-- for, and ones that need a specialisation count only once you have them. `breakAt` is a skill no step
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
        local slow, slowCost
        local stayCost, stayFair, staySlow
        for _, recipe in ipairs(recipes) do
            local mine = recipe.vein or known(recipe.spell)
            -- A recipe you know counts whatever skill the data says it's
            -- learned at (some are taught earlier than that); one from a
            -- trainer counts once your skill reaches it.
            if mine or (not Professions.Needs(recipe) and (recipe.how == 1 or (recipe.how == 2 and Professions.Buyable(recipe.spell))) and recipe.learn <= s) then
                local chance = Chance(recipe, s)
                -- The last few points before a recipe goes grey take ten
                -- crafts or more each: that's no way forward, so the road
                -- stops there and says so.
                if chance >= Professions.LEAST then
                    local cost = Cost(recipe) / chance + (mine and 0 or 0.01)
                    if not mine and recipe.how == 2 then cost = cost * 1.5 end
                    local wait = Professions.Wait(recipe)
                    if wait then
                        if not slow or cost < slowCost then slow, slowCost = recipe, cost end
                    else
                        if not best or cost < bestCost then best, bestCost = recipe, cost end
                        if chance >= Professions.GREEN and (not fair or cost < fairCost) then fair, fairCost = recipe, cost end
                    end
                    if recipe == staying then stayCost, stayFair, staySlow = cost, chance >= Professions.GREEN, wait end
                end
            end
        end
        -- One with a wait only when nothing else gives a point, and the one in
        -- hand isn't kept for being in hand if it has a wait.
        if best then
            if staySlow then stayCost = nil end
        else
            best, bestCost = slow, slowCost
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
