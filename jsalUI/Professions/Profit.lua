-- Crafting profit: every recipe your characters know, with what it costs to
-- make, what it sells for and what's left after the auction house's cut. A
-- guildmate asked for it (Meow Forfeet, 16 Nov 2026: crafting for gold from
-- auction prices); John picked a dashboard page of its own, "A but with
-- sorting", and "this is purely profit": no levelling view. The page is
-- ProfitPage.lua.
--
-- Prices come from ItemPrices: Auctionator's when it's installed, else your
-- own auction house searches. Each material costs the least of buying it
-- (vendor or auction house) and making it from a recipe one of your
-- characters knows. A recipe missing any price shows no profit at all, and
-- says which item nobody has seen.
local _, ns = ...
local Compat, Professions = ns.Compat, ns.Professions

local CraftProfit = ns.NewModule("craftprofit", {
    title = "Crafting profit",
    note = "A dashboard page of every recipe your characters know, by what it earns at the auction house after its cut. Prices from Auctionator when it's installed, else from your own auction house searches. /jsal profit",
    defaultOn = false,
    options = {
        { key = "road", title = "Price the road to the next rank", default = true,
          note = "The profession panel's road picks the cheapest way to each point by these prices, less what each craft sells back for, instead of a rough worth of its materials." },
    },
})
ns.CraftProfit = CraftProfit

local Data = ns.ProfessionData

---------------------------------------------------------------------------
-- What each of your characters knows, kept for the whole account so every
-- character's recipes count wherever you are: ns.db.craftKnown[realm][name]
-- = { [line] = { spell, ... } }. Copied from what the character saw in its
-- profession window, at login and whenever that changes. A few hundred
-- numbers a character.
---------------------------------------------------------------------------
local function Realm()
    return GetRealmName and GetRealmName() or "?"
end

local function Characters()
    ns.db.craftKnown = type(ns.db.craftKnown) == "table" and ns.db.craftKnown or {}
    local realm = Realm()
    ns.db.craftKnown[realm] = type(ns.db.craftKnown[realm]) == "table" and ns.db.craftKnown[realm] or {}
    return ns.db.craftKnown[realm]
end
CraftProfit.Characters = Characters

-- This character's recipes, copied into the account's list.
function CraftProfit.Changed()
    if not CraftProfit.running then return end
    local name = Compat.MyName()
    if not name then return end
    local mine = {}
    local all = type(ns.char.professions) == "table" and ns.char.professions or {}
    for line, p in pairs(all) do
        if type(p) == "table" and type(p.known) == "table" then
            local list = {}
            for spell in pairs(p.known) do list[#list + 1] = spell end
            table.sort(list)
            mine[line] = list
        end
    end
    Characters()[name] = mine
    if ns.Window and ns.Window.IsOpen and ns.Window.IsOpen("craftprofit") then ns.Window.Refresh() end
end

-- Every recipe known on this realm: { [spell] = { line, who = { names } } },
-- and the names of the characters that know any.
function CraftProfit.Known()
    local known, names = {}, {}
    for name, lines in pairs(Characters()) do
        if type(lines) == "table" then
            local any = false
            for line, list in pairs(lines) do
                if type(list) == "table" then
                    for _, spell in ipairs(list) do
                        local k = known[spell]
                        if not k then k = { line = line, who = {} }; known[spell] = k end
                        k.who[#k.who + 1] = name
                        any = true
                    end
                end
            end
            if any then names[#names + 1] = name end
        end
    end
    table.sort(names)
    return known, names
end

---------------------------------------------------------------------------
-- Costing.
---------------------------------------------------------------------------
-- Every recipe in the data, by its spell.
local bySpell
local function RecipeBySpell(spell)
    if not bySpell then
        bySpell = {}
        for line, source in pairs(Data) do
            if type(source) == "table" and type(source.recipes) == "table" then
                for _, recipe in ipairs(Professions.Recipes(line) or {}) do
                    recipe.line = recipe.line or line
                    bySpell[recipe.spell] = recipe
                end
            end
        end
    end
    return bySpell[spell]
end
CraftProfit.RecipeBySpell = RecipeBySpell

-- How deep making a material from another recipe goes: a bolt from cloth,
-- a cured hide from a hide; no further.
local DEPTH = 2

-- What one of an item costs you, in copper: the least of buying it and
-- making it from `makers` (item -> a known recipe that makes it). Returns
-- the cost, how ("vendor", "auction" or "craft") and the age of the oldest
-- price behind it; or nil and the item nobody has a price for.
local Cost
local function ItemCost(item, makers, depth)
    local best, how, age = ns.ItemPrices.Of(item)
    local recipe = depth < DEPTH and makers[item]
    if recipe then
        local made, missing, madeAge = Cost(recipe, makers, depth + 1)
        if not missing then
            made = made / math.max(1, recipe.makes or 1)
            if not best or made < best then best, how, age = made, "craft", madeAge end
        end
    end
    if not best then return nil, item end
    return best, how, age or 0
end

-- What a craft's materials cost, the first material with no price, and the
-- age of the oldest price used.
function Cost(recipe, makers, depth)
    local total, missing, oldest = 0, nil, 0
    for _, reagent in ipairs(recipe.reagents) do
        local each, how, age = ItemCost(reagent.item, makers, depth or 0)
        if each then
            total = total + each * reagent.count
            oldest = math.max(oldest, age)
        else
            missing = missing or how
        end
    end
    return math.floor(total + 0.5), missing, oldest
end
CraftProfit.Cost = Cost

-- Which known recipe makes each item.
local function Makers(known)
    local makers = {}
    for spell in pairs(known) do
        local recipe = RecipeBySpell(spell)
        if recipe and recipe.item and not makers[recipe.item] then makers[recipe.item] = recipe end
    end
    return makers
end

-- A recipe as a row of the page: what it makes, what that costs and sells
-- for, the profit after the cut, how old its prices are, and what's missing.
local function Row(spell, recipe, makers)
    local row = { spell = spell, recipe = recipe, line = recipe.line, item = recipe.item, parts = {} }
    row.cost, row.missing, row.age = Cost(recipe, makers, 0)
    -- Each material, for the row's tooltip: how many, and each one's cost and how.
    for _, reagent in ipairs(recipe.reagents) do
        local each, how = ItemCost(reagent.item, makers, 0)
        row.parts[#row.parts + 1] = { item = reagent.item, count = reagent.count, each = each, how = each and how or nil }
    end
    if recipe.item then
        local unit, age = ns.ItemPrices.Auction(recipe.item)
        if unit then
            row.sells = unit * math.max(1, recipe.makes or 1)
            row.age = math.max(row.age, age)
        end
    end
    if row.missing then row.cost = nil end
    if row.cost and row.sells then
        row.profit = math.floor(row.sells * (1 - ns.ItemPrices.CUT)) - row.cost
    end
    row.old = row.age > ns.ItemPrices.OLD
    return row
end

-- One craft priced, for the profession panel's road: what its materials cost
-- (the item nobody has a price for instead, if any) and what it sells for,
-- by the same reckoning as the page's rows.
function CraftProfit.CraftPrice(recipe)
    local row = Row(recipe.spell, recipe, Makers((CraftProfit.Known())))
    return row.cost, row.sells, row.missing
end

-- Every recipe your characters know, one row each.
function CraftProfit.ProfitRows()
    local known, names = CraftProfit.Known()
    local makers = Makers(known)
    local rows = {}
    for spell, k in pairs(known) do
        local recipe = RecipeBySpell(spell)
        if recipe then
            local row = Row(spell, recipe, makers)
            row.who, row.known = k.who, true
            rows[#rows + 1] = row
        end
    end
    return rows, names
end

-- Every recipe of the professions your characters have, known or not, so the
-- most profitable one to learn can be found (John, 16 Nov 2026: "someone
-- might want to sort by what makes the most profit and grab that recipe").
-- A row's `known` says whether any of your characters has it.
function CraftProfit.AllRows()
    local known, names = CraftProfit.Known()
    local makers = Makers(known)
    local lines = {}
    for _, k in pairs(known) do lines[k.line] = true end
    local rows = {}
    for line in pairs(lines) do
        for _, recipe in ipairs(Professions.Recipes(line) or {}) do
            local spell = recipe.spell
            local mine = RecipeBySpell(spell) and known[spell]
            local row = Row(spell, RecipeBySpell(spell) or recipe, makers)
            row.known, row.who = mine ~= nil, mine and mine.who or nil
            rows[#rows + 1] = row
        end
    end
    return rows, names
end

---------------------------------------------------------------------------
-- Starting.
---------------------------------------------------------------------------
function CraftProfit:OnEnable()
    ns.ItemPrices.useAuctionator = true
    local events = CreateFrame("Frame")
    for _, event in ipairs(ns.ItemPrices.EVENTS) do pcall(events.RegisterEvent, events, event) end
    pcall(events.RegisterEvent, events, "GET_ITEM_INFO_RECEIVED")
    local naming = false
    events:SetScript("OnEvent", ns.Safe(CraftProfit, function(_, event, arg1)
        arg1 = Compat.Plain(arg1)
        if event == "GET_ITEM_INFO_RECEIVED" then
            -- A name or quality comes a moment after it's first asked for:
            -- paint once for a burst of them.
            if not naming and ns.Window.IsOpen("craftprofit") then
                naming = true
                Compat.After(0.3, ns.Safe(CraftProfit, function()
                    naming = false
                    -- Only the rows on screen are drawn again, with their names.
                    local page = ns.CraftProfitPage
                    if page and page.PaintList and ns.Window.IsOpen("craftprofit") then page.PaintList() end
                end))
            end
        else
            ns.ItemPrices.OnAuctionEvent(event, arg1)
        end
    end))
    self.events = events
    CraftProfit.Changed()
end

function CraftProfit:OnDisable()
    ns.ItemPrices.useAuctionator = false
    if self.events then self.events:UnregisterAllEvents() end
end

ns.Command("profit", function()
    if CraftProfit.running then
        ns.Window.Open("craftprofit")
    else
        ns.Print("Crafting profit is off. Turn it on in Settings, under Professions.")
    end
end)
