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
    local known, count = {}, 0
    for _, spell in ipairs(spells) do
        if not known[spell] then known[spell], count = true, count + 1 end
    end
    -- The panel remembers on every repaint, mostly with nothing new: the rest is told only
    -- when the skill, the cap or a recipe has changed.
    local was = ns.char.professions[line]
    local same = type(was) == "table" and was.skill == skill and was.cap == cap and type(was.known) == "table"
    if same then
        local had = 0
        for spell in pairs(was.known) do
            had = had + 1
            if not known[spell] then same = false break end
        end
        same = same and had == count
    end
    ns.char.professions[line] = { skill = skill, cap = cap, known = known, seen = Compat.ServerTime() }
    if same then return end
    -- Guild crafters tells the guild when what you can make has changed.
    if ns.Crafters and ns.Crafters.Changed then ns.Crafters.Changed() end
    -- Crafting profit keeps every character's recipes for the whole account.
    if ns.CraftProfit and ns.CraftProfit.Changed then ns.CraftProfit.Changed() end
end

function Professions.Remembered(line)
    local all = type(ns.char.professions) == "table" and ns.char.professions or {}
    return all[line]
end

-- Your professions, from the game's own list: each one's skill line, name,
-- icon, skill and cap, for the ones jsal.ui has recipes for. The game's
-- list has a place for each kind (two main ones, then fishing, cooking and
-- so on) and leaves a gap for one you don't have: so every place is looked
-- at, not only those before the first gap. Stopping at the gap left out
-- whatever came after it.
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

-- What an item is worth, in copper: a vendor's price for thread or dye, the worth the data
-- gives every other material, or what it's made from where that's less (a bolt from cloth, a
-- bar from ore). Materials used to count one each, so the road went through forty hides, sixty
-- elixirs or a dozen Righteous Orbs as readily as through leather.
--
-- With Crafting profit's "Price the road" on, a material is worth what it costs you to buy (a
-- vendor's price, else the auction price from ItemPrices) where that's known, and the data's
-- worth only where it isn't. What a craft would sell for doesn't count: the road is the cheapest
-- way to the cap in what you buy, not a bet on selling forty pieces of armour. Set for one road
-- at a time by Plan, with its own memory of what it has looked up.
--
-- Real prices are weighed only against real prices. A material nobody has a price for was
-- weighed by the data's rough worth, far below an auction price, so the road took a recipe for
-- being unknown. Now, step by step (Plan sets `priced`): the recipes whose materials all have
-- prices are weighed against each other by them, and one with a price missing is left out; a
-- step where none has them all goes by the rough worth, every recipe alike.
local priced, seen, whole

local function Priced()
    return ns.CraftProfit ~= nil and ns.CraftProfit.running == true and ns.ItemPrices ~= nil
        and ns.OptionOn("craftprofit", "road")
end
Professions.Priced = Priced

-- What a pattern costs at the cheapest vendor who sells it to your side, in
-- copper, or nil when that isn't known.
local function PatternPrice(spell)
    local sources = ns.RecipeSourceText
    if not (sources and sources.Vendors) then return nil end
    local vendor = sources.Vendors(spell, UnitFactionGroup and UnitFactionGroup("player") or nil)[1]
    return vendor and vendor.copper and vendor.copper > 0 and vendor.copper or nil
end

-- Whether an item has a real price: one to buy it at, or one for all it's made from.
local function HasPrice(line, item, depth)
    if ns.ItemPrices.Of(item) then return true end
    local recipe = (depth or 0) < 2 and MadeBy(line, item)
    if not recipe then return false end
    for _, reagent in ipairs(recipe.reagents) do
        if not HasPrice(line, reagent.item, (depth or 0) + 1) then return false end
    end
    return true
end

-- Whether every material of a recipe has one, looked up once a road.
local function AllPriced(line, recipe)
    local known = whole[recipe]
    if known == nil then
        known = true
        for _, reagent in ipairs(recipe.reagents) do
            if not HasPrice(line, reagent.item) then known = false break end
        end
        whole[recipe] = known
    end
    return known
end

-- What an item is worth from the data alone, by profession: it never changes, so it's worked out
-- once. Not kept, it would be worked out again for every material of every recipe at every point
-- of the road, two makings deep: a third of Leatherworking's road, which took 24 ms to plan and
-- hitched the Professions page on every switch. Priced, the road's own `seen` keeps it, as prices
-- can change between roads.
local plainWorth = {}
local function ItemWeight(line, item, depth)
    local key = (depth or 0) == 0 and priced and seen and item
    if key and seen[key] then return seen[key] end
    local plain = (depth or 0) == 0 and not priced and plainWorth[line]
    if plain and plain[item] then return plain[item] end
    local rough = Data.vendor[item] or (Data.value and Data.value[item]) or 100
    local recipe = (depth or 0) < 2 and MadeBy(line, item)
    local made
    if recipe then
        local w, real = 0, true
        for _, reagent in ipairs(recipe.reagents) do
            if priced and not HasPrice(line, reagent.item, (depth or 0) + 1) then real = false end
            w = w + reagent.count * ItemWeight(line, reagent.item, (depth or 0) + 1)
        end
        -- Priced, making it counts only when all it's made from has a price.
        if real then made = w / math.max(1, recipe.makes or 1) end
    end
    local own
    if priced then
        local buy = ns.ItemPrices.Of(item)
        own = (buy and made) and math.min(buy, made) or buy or made or rough
    else
        own = made and math.min(rough, made) or rough
    end
    if key then seen[key] = own end
    if (depth or 0) == 0 and not priced then
        plainWorth[line] = plainWorth[line] or {}
        plainWorth[line][item] = own
    end
    return own
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
-- book a vendor sells, and its Artisan a quest. Cooking's are the same two
-- ways: its trainers teach Apprentice and Journeyman and no more, and the
-- panel named any cook for Expert. Returns what to do, a line about it, and
-- who to see for it where that's known, shaped like a trainer for the map
-- pin; or nil for a rank a trainer teaches. Who: Shandrina sells the book
-- to the Alliance in Ashenvale and Wulan to the Horde in Desolace, a gold
-- each; Dirge Quikcleave in Gadgetzan gives and takes the quest, for both
-- sides, from level 35.
local FIRST_AID, COOKING, ENCHANTING = 129, 185, 333
local OTHER_RANKS = {
    -- Enchanting's Artisan is a trainer's, but one inside a dungeon: Annora, Master Enchanter,
    -- in Uldaman, for both sides. No trainer outside teaches it, and the row said jsal.ui
    -- didn't know one.
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
    -- 35.
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
-- received it right after I hit 225". The row said "At 200".
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
-- What it sells for isn't taken off: a road that counted on selling what it
-- made went through 41 pieces of Turtle Scale armour where Thick Leather and
-- Silken Thread take you to the same skill for far less.
-- A vein is no craft: its ore is only its icon.
local function Weight(line, recipe)
    if priced then
        if seen[recipe] then return seen[recipe] end
    elseif recipe.weight then
        return recipe.weight
    end
    local w = 100
    for _, reagent in ipairs(recipe.reagents) do
        w = w + reagent.count * ItemWeight(line, reagent.item)
    end
    if priced then
        seen[recipe] = w
    else
        recipe.weight = w
    end
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
-- Cured Light Hide, and nine of them gave no point at all.
Professions.GREEN = 0.5
-- The least chance of a point a recipe may have and still be on the road.
Professions.LEAST = 0.1
-- A step shorter than this many points is folded into the step before or after it, where that
-- recipe still gives a point as surely as a yellow one over those skills and costs at most
-- DETOUR times as much there: a pattern bought for four points, three of one thing between two
-- runs of another, are trips and switches a road to the cap is better without.
Professions.SHORT = 5
Professions.DETOUR = 1.5

-- What a recipe costs over the skills from `from` to `to`, or nil where it can't give a point
-- as surely as a green one there, isn't open to you yet or has a wait.
local function Over(line, recipe, from, to, open, known)
    if recipe.vein or Professions.Wait(recipe) then return nil end
    local mine = known(recipe.spell)
    local total = 0
    for s = from, to - 1 do
        local chance = Chance(recipe, s)
        if chance < Professions.GREEN or not open(recipe, mine, s) then return nil end
        total = total + Weight(line, recipe) / chance
    end
    return total
end

-- Folds the road's short steps into a neighbour, then joins the steps that are one recipe again.
-- A step isn't folded across `breakAt`, where the road stops to say the next rank is due.
-- With `pricing`, a short step and a neighbour are weighed by real prices only when both
-- recipes have them for every material, and by the rough worth otherwise: like against like,
-- as on the road itself.
local function FoldShort(line, steps, open, known, breakAt, pricing)
    local i = 1
    while i <= #steps do
        local step = steps[i]
        local before, after = steps[i - 1], steps[i + 1]
        local into
        if step.to - step.from < Professions.SHORT and not step.recipe.vein and (before or after) then
            local best
            for _, side in ipairs({ before or false, after or false }) do
                local crosses = side and ((side == before and step.from == breakAt) or (side == after and step.to == breakAt))
                if side and not crosses then
                    priced = pricing and AllPriced(line, step.recipe) and AllPriced(line, side.recipe) or false
                    local own = 0
                    for s = step.from, step.to - 1 do
                        own = own + Weight(line, step.recipe) / math.max(Professions.LEAST, Chance(step.recipe, s))
                    end
                    local cost = Over(line, side.recipe, step.from, step.to, open, known)
                    -- The side that costs least against the step's own cost, weighed the same way.
                    local share = cost and cost / own
                    if share and share <= Professions.DETOUR and (not best or share < best) then
                        best, into = share, side
                    end
                end
            end
        end
        if into then
            local recipe = into.recipe
            for s = step.from, step.to - 1 do
                local chance = Chance(recipe, s)
                into.exact = into.exact + 1 / chance
                into.spread = into.spread + (1 - chance) / (chance * chance)
            end
            into.from, into.to = math.min(into.from, step.from), math.max(into.to, step.to)
            table.remove(steps, i)
            i = math.max(1, i - 1)
        else
            i = i + 1
        end
    end
    -- Two runs of one recipe that now meet are one step.
    i = 2
    while i <= #steps do
        local a, b = steps[i - 1], steps[i]
        if a.recipe == b.recipe and a.to == b.from and b.from ~= breakAt then
            a.to, a.exact, a.spread = b.to, a.exact + b.exact, a.spread + b.spread
            table.remove(steps, i)
        else
            i = i + 1
        end
    end
end

-- How long before a recipe can be made again, in seconds, or nil: the
-- transmutes, Mooncloth. The road takes one only when nothing else gives a
-- point. It took them as readily as any other: Tailoring's road from 230 to
-- 286 was 63 Mooncloth, one every four days, and Alchemy's from 225 to 261
-- was 45 transmutes of iron to gold, one an hour.
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
-- Leatherworker's. Now one is on the road only once you know it.
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
    local pricing = Priced()
    priced, seen, whole = pricing, pricing and {} or nil, {}
    -- Only the recipes that could be a step of this road: one still short of a few points a craft at
    -- the skill it starts from (a recipe only gets less likely to give a point as you go), and one
    -- you know or could learn before the cap. At 158 most of Leatherworking's are neither, and
    -- looking at them all at every point of the road made a switch between professions lag. The
    -- road it finds is the same.
    local recipes = {}
    for _, recipe in ipairs(line == MINING and Veins() or Professions.Recipes(line) or {}) do
        if Chance(recipe, skill) >= Professions.LEAST and (recipe.vein or recipe.learn < target or known(recipe.spell)) then
            recipes[#recipes + 1] = recipe
        end
    end
    local totals = {}
    -- What's in your bags and bank counts as nearly free until the road has
    -- used it up, so a pile of leather or cloth you already have gets spent
    -- before anything is made or bought. Not counting, it's all bought.
    local function Stock(counting)
        return setmetatable({}, { __index = function(t, item)
            local n = counting and Compat.ItemCount(item, true) or 0
            rawset(t, item, n)
            return n
        end })
    end
    -- A recipe the road may take at a skill: one you know, or one a trainer teaches or a
    -- vendor sells for coin, once your skill reaches it.
    local function Open(recipe, mine, at)
        return mine or (not Professions.Needs(recipe) and (recipe.how == 1 or (recipe.how == 2 and Professions.Buyable(recipe.spell))) and recipe.learn <= at)
    end
    -- The road a point at a time from `stock`: its steps, the skill it reached, and whether
    -- anything you have made a recipe cheaper.
    local function Walk(stock)
        local used = false
        local function Cost(recipe)
            local w = Weight(line, recipe)
            for _, reagent in ipairs(recipe.reagents) do
                local owned = math.min(stock[reagent.item], reagent.count)
                if owned > 0 and not Data.vendor[reagent.item] then
                    used = true
                    w = w - owned * ItemWeight(line, reagent.item) * Professions.OWNED
                end
            end
            -- Never below 1. Priced, a craft that sells for what goes in costs next to nothing
            -- before what you own comes off, and a cost below nothing made the recipe with the
            -- smaller chance of a point look the better one.
            return math.max(1, w)
        end
        local steps = {}
        local s = skill
        local staying
        while s < target do
            local best, bestCost
            local fair, fairCost
            local slow, slowCost
            local stayCost, stayFair, staySlow
            -- Real prices decide this step if any recipe it could take has them all.
            if pricing then
                priced = false
                for _, recipe in ipairs(recipes) do
                    if Open(recipe, recipe.vein or known(recipe.spell), s) and Chance(recipe, s) >= Professions.LEAST
                        and AllPriced(line, recipe) then
                        priced = true
                        break
                    end
                end
            end
            for _, recipe in ipairs(recipes) do
                local mine = recipe.vein or known(recipe.spell)
                -- A recipe you know counts whatever skill the data says it's
                -- learned at (some are taught earlier than that); one from a
                -- trainer counts once your skill reaches it.
                if Open(recipe, mine, s) then
                    local chance = Chance(recipe, s)
                    -- The last few points before a recipe goes grey take ten
                    -- crafts or more each: that's no way forward, so the road
                    -- stops there and says so.
                    if chance >= Professions.LEAST and (not priced or AllPriced(line, recipe)) then
                        local cost = Cost(recipe) / chance + (mine and 0 or 0.01)
                        if not mine and recipe.how == 2 then
                            -- Priced, a pattern to buy adds its price, shared by the
                            -- points it can give before it turns green; else it
                            -- counts half again as costly.
                            local pattern = priced and PatternPrice(recipe.spell)
                            if pattern then
                                cost = cost + pattern / math.max(1, math.floor((recipe.yellow + recipe.grey) / 2) - s)
                            else
                                cost = cost * 1.5
                            end
                        end
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
        FoldShort(line, steps, Open, known, breakAt, pricing)
        return steps, s, used
    end
    -- What a road comes to, counting what you have once, in the order the road uses it: the
    -- same measure for either road. A pattern to buy adds its price, or half again.
    local function Spend(steps, mode)
        priced = mode
        local left, total = Stock(true), 0
        for _, step in ipairs(steps) do
            local recipe = step.recipe
            total = total + 100 * step.exact
            for _, reagent in ipairs(recipe.reagents) do
                local need = reagent.count * step.exact
                local owned = Data.vendor[reagent.item] and 0 or math.min(left[reagent.item], need)
                left[reagent.item] = left[reagent.item] - owned
                total = total + (need - owned * Professions.OWNED) * ItemWeight(line, reagent.item)
            end
            if step.buy then
                total = total + (mode and PatternPrice(recipe.spell) or 0.5 * Weight(line, recipe) * step.exact)
            end
        end
        return total
    end
    -- Spending what you have as soon as a recipe can use it isn't always where it saves most:
    -- at 158 Leatherworking took 34 Thick Leather you had for Thick Armor Kit at 175, while
    -- Guardian Gloves still gave a point a craft, went back to the Gloves, then bought Thick
    -- Leather for the same Kits at 194 (John, 19 Nov 2026: "see why its like that"). So where
    -- what you have changed the road and it goes back to a recipe it left, the road is found
    -- again as if you had nothing, and the one that comes to less, counting what you have either
    -- way, is kept. Only then: finding it twice every time took twice as long.
    local steps, s, used = Walk(Stock(true))
    local back = false
    if used then
        local left = {}
        for i, step in ipairs(steps) do
            if left[step.recipe] then back = true break end
            if steps[i + 1] and steps[i + 1].recipe ~= step.recipe then left[step.recipe] = true end
        end
    end
    if back then
        local plain, plainAt = Walk(Stock(false))
        if plainAt >= s then
            local mode = pricing
            for _, list in ipairs({ steps, plain }) do
                for _, step in ipairs(list) do
                    if mode and not AllPriced(line, step.recipe) then mode = false end
                end
            end
            if Spend(plain, mode) < Spend(steps, mode) then steps, s = plain, plainAt end
        end
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
    priced = false
    return steps, totals, s < target and s or nil, made
end
