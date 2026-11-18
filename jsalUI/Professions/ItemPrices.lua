-- What an item costs, one way for every part of jsal.ui that prices one (the
-- shopping list, Crafting profit): a vendor's price from the data; else an
-- auction price, Auctionator's when it's installed and Crafting profit is on,
-- else the lowest seen in your own auction house searches, kept per realm
-- with when it was seen. Each price comes with its age, so an old one can say
-- so. The searches are remembered here too, whichever part is listening.
local _, ns = ...
local Compat, Professions = ns.Compat, ns.Professions

local ItemPrices = {}
ns.ItemPrices = ItemPrices

local DAY = 86400

-- The auction house's cut of a sale at a faction's own auction house, as a
-- sale's "Auction successful" mail shows it on Forever.
ItemPrices.CUT = 0.05
-- A price older than this is shown as old, and one older than FORGET is let
-- go. Both are short: on a young realm prices move from one day to the
-- next, and a price from last week says little about today's auction house.
-- Letting go also keeps the saved file from holding every item ever seen in
-- a search. These two numbers are the ones to turn as the economy settles.
ItemPrices.OLD = 3 * DAY
ItemPrices.FORGET = 7 * DAY

-- Lets go of the remembered prices past FORGET, on every realm, and of
-- anything there that isn't a price. Gives how many went.
function ItemPrices.Sweep()
    local all = type(ns.db.ahPrices) == "table" and ns.db.ahPrices or {}
    local now, gone = Compat.ServerTime(), 0
    for realm, prices in pairs(all) do
        if type(prices) ~= "table" then
            all[realm] = nil
        else
            for item, seen in pairs(prices) do
                if type(seen) ~= "table" or type(seen.price) ~= "number"
                    or now - (tonumber(seen.seen) or 0) > ItemPrices.FORGET then
                    prices[item] = nil
                    gone = gone + 1
                end
            end
            if next(prices) == nil then all[realm] = nil end
        end
    end
    return gone
end

-- Prices remembered from your own searches, for this realm. The first ask
-- since the game loaded sweeps out the ones too old to keep.
local swept = false
local function Remembered()
    if not swept then
        swept = true
        ItemPrices.Sweep()
    end
    local realm = GetRealmName and GetRealmName() or "?"
    ns.db.ahPrices = type(ns.db.ahPrices) == "table" and ns.db.ahPrices or {}
    ns.db.ahPrices[realm] = type(ns.db.ahPrices[realm]) == "table" and ns.db.ahPrices[realm] or {}
    return ns.db.ahPrices[realm]
end

-- How many prices have been seen since the game loaded: a window that keeps
-- what it worked out from prices works it out again once this has moved.
ItemPrices.seen = 0
function ItemPrices.See(item, unit)
    if not (item and unit and unit > 0) then return end
    Remembered()[item] = { price = math.floor(unit), seen = Compat.ServerTime() }
    ItemPrices.seen = ItemPrices.seen + 1
end

---------------------------------------------------------------------------
-- Auctionator, another addon, read only through its public API and only
-- when Crafting profit asks for it. As its API's own notes say:
-- GetAuctionPriceByItemID(callerID, itemID) is the last price it saw, in
-- copper, or nil; GetAuctionAgeByItemID(callerID, itemID) is how many days
-- ago, or nil past 21 days. A price with no age is counted old.
---------------------------------------------------------------------------
ItemPrices.useAuctionator = false
local CALLER = "jsal.ui"

local function AuctionatorAPI()
    if not ItemPrices.useAuctionator then return nil end
    local a = Auctionator
    local api = type(a) == "table" and type(a.API) == "table" and a.API.v1
    if type(api) == "table" and type(api.GetAuctionPriceByItemID) == "function" then return api end
end

function ItemPrices.HasAuctionator()
    return AuctionatorAPI() ~= nil
end

local function FromAuctionator(item)
    local api = AuctionatorAPI()
    if not api then return nil end
    local ok, price = pcall(api.GetAuctionPriceByItemID, CALLER, item)
    if not ok or type(price) ~= "number" or price <= 0 then return nil end
    local age = 22 * DAY
    if type(api.GetAuctionAgeByItemID) == "function" then
        local fine, days = pcall(api.GetAuctionAgeByItemID, CALLER, item)
        if fine and type(days) == "number" then age = days * DAY end
    end
    return math.floor(price), age
end

-- How many auction prices came from each place since Counting() was last
-- called, so a window can say where its prices really came from: Auctionator
-- installed but not yet scanned has none, and the shopping list said "from
-- Auctionator" all the same.
local counted = {}
function ItemPrices.Counting()
    counted = {}
    return counted
end

-- Where a window's prices came from, in a few words, from what was counted.
function ItemPrices.From(count)
    if count.auctionator and count.searched then return "Auctionator and your own searches" end
    if count.auctionator then return "Auctionator" end
    return "your own searches"
end

-- An item's auction price: copper, how long ago it was seen in seconds, and
-- where it came from ("auctionator" or "searched"); nil when none is known.
function ItemPrices.Auction(item)
    local price, age = FromAuctionator(item)
    if price then
        counted.auctionator = (counted.auctionator or 0) + 1
        return price, age, "auctionator"
    end
    local seen = Remembered()[item]
    if type(seen) == "table" and type(seen.price) == "number" then
        counted.searched = (counted.searched or 0) + 1
        return seen.price, math.max(0, Compat.ServerTime() - (tonumber(seen.seen) or 0)), "searched"
    end
end

-- What one of an item costs to buy: a vendor's price if a vendor sells it,
-- else its auction price. Returns copper, "vendor" or "auction", and its age.
function ItemPrices.Of(item)
    local vendor = Professions.IsVendor(item)
    if vendor then return vendor, "vendor", 0 end
    local price, age = ItemPrices.Auction(item)
    if price then return price, "auction", age end
end

---------------------------------------------------------------------------
-- Your own auction house searches: whichever kind of auction house this
-- client has, the lowest prices it shows are remembered.
---------------------------------------------------------------------------
ItemPrices.EVENTS = { "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", "COMMODITY_SEARCH_RESULTS_UPDATED", "AUCTION_ITEM_LIST_UPDATE" }

local function SeeBrowse()
    local ah = C_AuctionHouse
    if ah and ah.GetBrowseResults then
        for _, r in ipairs(ah.GetBrowseResults() or {}) do
            ItemPrices.See(r.itemKey and r.itemKey.itemID, r.minPrice)
        end
    end
end

local function SeeCommodity(item)
    local ah = C_AuctionHouse
    local first = ah and ah.GetCommoditySearchResultInfo and ah.GetCommoditySearchResultInfo(item, 1)
    if first then ItemPrices.See(item, first.unitPrice) end
end

-- The older auction house's list: each row's buyout per item.
local function SeeOldList()
    if not (GetNumAuctionItems and GetAuctionItemInfo) then return end
    local lowest = {}
    for i = 1, (GetNumAuctionItems("list")) do
        local _, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, item = GetAuctionItemInfo("list", i)
        if item and buyout and buyout > 0 and count and count > 0 then
            local unit = buyout / count
            if not lowest[item] or unit < lowest[item] then lowest[item] = unit end
        end
    end
    for item, unit in pairs(lowest) do ItemPrices.See(item, unit) end
end

-- One of EVENTS happened: remember what it shows.
function ItemPrices.OnAuctionEvent(event, arg1)
    if event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" then
        SeeBrowse()
    elseif event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
        SeeCommodity(arg1)
    elseif event == "AUCTION_ITEM_LIST_UPDATE" then
        SeeOldList()
    end
end
