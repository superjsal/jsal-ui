-- Crafting profit: every recipe your characters know, with what it costs to
-- make, what it sells for and what's left after the auction house's cut. It
-- has a page of its own, sorted as you choose, and is purely about profit:
-- no levelling view. The page is ProfitPage.lua.
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
    options = {
        { key = "road", title = "Price the road to the next rank", default = true,
          note = "The profession panel's road picks the cheapest way to each point by what its materials cost at these prices, instead of a rough worth of them." },
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

-- A character not logged in for this long leaves the list (a deleted one would stay for
-- good); logging it in again brings it back.
local FORGET = 90 * 86400
local priceMakers

-- This character's recipes, copied into the account's list with when (`t`): only the
-- professions it has now, so one it dropped goes too.
local function Copy()
    local name = Compat.MyName()
    if not name then return end
    local has
    for _, p in ipairs(Professions.Mine and Professions.Mine() or {}) do
        has = has or {}
        has[p.line] = true
    end
    local mine = { t = Compat.ServerTime() }
    local all = type(ns.char.professions) == "table" and ns.char.professions or {}
    for line, p in pairs(all) do
        if type(p) == "table" and type(p.known) == "table" and (not has or has[line]) then
            local list = {}
            for spell in pairs(p.known) do list[#list + 1] = spell end
            table.sort(list)
            mine[line] = list
        end
    end
    local list = Characters()
    list[name] = mine
    for who, entry in pairs(list) do
        if who ~= name and type(entry) == "table" then
            -- One saved before the time was kept starts its count now.
            entry.t = tonumber(entry.t) or mine.t
            if mine.t - entry.t > FORGET then list[who] = nil end
        end
    end
    priceMakers = nil
    CraftProfit.changes = (CraftProfit.changes or 0) + 1
end

-- Whether the rows worked out at `stamp` still hold: no recipe learned and no price seen since,
-- and not at the auction house, where Auctionator's prices can change at any moment.
function CraftProfit.Stamp()
    return (CraftProfit.changes or 0) .. ":" .. (ns.ItemPrices.seen or 0)
end
function CraftProfit.Holds(stamp)
    return stamp == CraftProfit.Stamp() and not CraftProfit.atAuction
end

-- The page's rows took 32 ms to work out on its first open after a reload, even once they were
-- kept between opens. They're worked out ahead now: a while after logging in, and a few seconds
-- after the auction house closes. Not at the auction house, where they aren't kept, and not in a
-- fight. A newer wait replaces an older one. Not after Changed: that comes with every skill
-- point while you craft, and working them out there was a 32 ms stutter a few seconds after each.
local warmRun = 0
function CraftProfit.WarmSoon(after)
    warmRun = warmRun + 1
    local run = warmRun
    local function Try()
        if run ~= warmRun or not CraftProfit.running or CraftProfit.atAuction then return end
        if Compat.InCombat() then return Compat.After(5, Try) end
        local page = ns.CraftProfitPage
        if not (page and page.Warm) then return end
        local started = debugprofilestop()
        xpcall(page.Warm, ns.Report)
        ns.Timed("Crafting profit, worked out ahead", started)
    end
    Compat.After(after, Try)
end

function CraftProfit.Changed()
    if not CraftProfit.running then return end
    Copy()
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
    -- Every known recipe that makes it is tried, and the cheapest counts.
    for _, recipe in ipairs(depth < DEPTH and makers[item] or {}) do
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

-- Which known recipes make each item: all of them, in the same order every time. One was
-- kept, whichever came first, so an item two recipes make (a bar smelted or transmuted) was
-- costed by either, and not always the same one.
local function Makers(known)
    local makers = {}
    for spell in pairs(known) do
        local recipe = RecipeBySpell(spell)
        if recipe and recipe.item then
            local list = makers[recipe.item] or {}
            makers[recipe.item] = list
            list[#list + 1] = recipe
        end
    end
    for _, list in pairs(makers) do
        table.sort(list, function(a, b) return a.spell < b.spell end)
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
--
-- Who makes what is kept for the one paint: the panel asks for each step of its road, and each
-- ask read every character's every recipe over again.
function CraftProfit.CraftPrice(recipe)
    local now = GetTime and GetTime()
    if not priceMakers or not now or priceMakers.at ~= now then
        priceMakers = { at = now, makers = Makers((CraftProfit.Known())) }
    end
    local row = Row(recipe.spell, recipe, priceMakers.makers)
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
-- most profitable one to learn can be found. Each player sees their own
-- professions'. A row's `known` says whether any of your characters has it.
function CraftProfit.AllRows()
    local known, names = CraftProfit.Known()
    local makers = Makers(known)
    local lines = {}
    for _, k in pairs(known) do lines[k.line] = true end
    local rows = {}
    for line, source in pairs(Data) do
        if lines[line] and type(source) == "table" and type(source.recipes) == "table" then
            for _, recipe in ipairs(Professions.Recipes(line) or {}) do
                local spell = recipe.spell
                local mine = RecipeBySpell(spell) and known[spell]
                local row = Row(spell, RecipeBySpell(spell) or recipe, makers)
                row.known, row.who = mine ~= nil, mine and mine.who or nil
                rows[#rows + 1] = row
            end
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
    -- The shopping list hears the auction house too (it starts first): with it on, its ear
    -- is enough, and no search is read twice.
    if not (ns.Shopping and ns.Shopping.running) then
        for _, event in ipairs(ns.ItemPrices.EVENTS) do pcall(events.RegisterEvent, events, event) end
    end
    pcall(events.RegisterEvent, events, "GET_ITEM_INFO_RECEIVED")
    events:RegisterEvent("AUCTION_HOUSE_SHOW")
    events:RegisterEvent("AUCTION_HOUSE_CLOSED")
    local naming = false
    events:SetScript("OnEvent", ns.Safe(CraftProfit, function(_, event, arg1)
        arg1 = Compat.Plain(arg1)
        if event == "AUCTION_HOUSE_SHOW" or event == "AUCTION_HOUSE_CLOSED" then
            -- Whatever Auctionator scanned there is in the next rows.
            CraftProfit.atAuction = event == "AUCTION_HOUSE_SHOW"
            CraftProfit.changes = (CraftProfit.changes or 0) + 1
            if not CraftProfit.atAuction then CraftProfit.WarmSoon(3) end
        elseif event == "GET_ITEM_INFO_RECEIVED" then
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
    -- Copied here and now: Changed waits for the part to be running, which it only is once
    -- this returns, so a character's recipes weren't kept until its profession window opened.
    Copy()
    -- After the Gear plan has filled ahead (it starts at 8 seconds), so the two don't meet.
    CraftProfit.WarmSoon(15)
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
