-- Guild orders: ask the guild for a craft or an enchant, and accept what
-- guildmates ask for. An order is waiting for a crafter, being made, sent,
-- or done; whoever asked can cancel it, whoever accepted can give it back.
-- An item is sent by handing it over: a letter to whoever asked, or a
-- finished trade with them, with the item in it, marks it sent by itself.
-- There's no button for it: one that said "sent" let an order be sent with
-- nothing handed over. An enchant is marked done by the crafter. It's done
-- when whoever asked marks it received. One never marked received is "not
-- confirmed" after a week.
-- Orders travel through the game's hidden addon channel to guildmates who
-- have jsal.ui with this on, and each jsal.ui passes on what it has heard,
-- so an order outlives the session it was posted in. Kept per guild, for
-- the account. Nothing is traded, mailed or paid for you: this is a notice
-- board, and the game's own trade window still does the handover.
local _, ns = ...
local Compat, Comms, Professions = ns.Compat, ns.Comms, ns.Professions

local Orders = ns.NewModule("orders", {
    title = "Guild orders",
    note = "Ask the guild for a craft or an enchant, and accept what guildmates ask for, in Guild Crafts. Orders reach guildmates who have jsal.ui with this on. /jsal crafts",
})
ns.Orders = Orders

local DAY = 86400
-- An order nobody accepts closes after OPEN_FOR. A finished one is shown for
-- SHOWN more. Everything about an order is forgotten LIFE after it was
-- asked, by everyone at the same moment (the moment is in its name), so one
-- that was cancelled can't come back from a guildmate who was away.
local OPEN_FOR, SHOWN, LIFE = 7 * DAY, 3 * DAY, 14 * DAY
Orders.OPEN_FOR, Orders.SHOWN, Orders.LIFE = OPEN_FOR, SHOWN, LIFE
-- How many are kept for a guild, and how many of your own can be open.
local MAX, MINE_MAX = 80, 5
Orders.MAX, Orders.MINE_MAX = MAX, MINE_MAX
local NOTE, NAME = 60, 40
Orders.NOTE = NOTE
-- A time this far past the realm's clock isn't believed.
local AHEAD = 600
-- A chat line only for an order asked in the last few minutes: catching up
-- at login is told by the count, not a line each.
local FRESH = 600
local PACK = 230                          -- letters in one message
local ASK_AGAIN, ASK_ANYONE, ANSWER_AGAIN = 300, 20, 60

-- The states, as one letter each: open, taken, sent (in a trade; before
-- 0.3.57 also by a button), mailed (sent by a letter), done, gone (cancelled).
local STATES = { o = true, t = true, s = true, m = true, d = true, x = true }
local SENT = { s = true, m = true }

local function On()
    return Orders.running and IsInGuild and IsInGuild() and true or false
end

---------------------------------------------------------------------------
-- Recipes: every one by its spell, with its profession.
---------------------------------------------------------------------------
local bySpell
function Orders.Recipe(spell)
    if not bySpell then
        bySpell = {}
        for line, source in pairs(ns.ProfessionData) do
            if type(line) == "number" and type(source) == "table" and type(source.recipes) == "table" then
                for _, recipe in ipairs(Professions.Recipes(line) or {}) do
                    bySpell[recipe.spell] = { recipe = recipe, line = line }
                end
            end
        end
    end
    local found = spell and bySpell[spell]
    if found then return found.recipe, found.line end
end

-- Whether this character knows a recipe, as its profession window last showed.
function Orders.CanMake(spell)
    local all = type(ns.char.professions) == "table" and ns.char.professions or {}
    for _, p in pairs(all) do
        if type(p) == "table" and type(p.known) == "table" and p.known[spell] then return true end
    end
    return false
end

-- What an order makes, by name: the item's, or the spell's for an enchant.
-- Nil until the game has the name.
function Orders.Name(order)
    local recipe = Orders.Recipe(order.spell)
    if recipe and recipe.item then return Compat.ItemName(recipe.item) end
    return (Compat.SpellInfo(order.spell))
end

-- What the whole order takes: { item, count } for each material.
function Orders.Materials(order)
    local recipe = Orders.Recipe(order.spell)
    local list = {}
    for _, reagent in ipairs(recipe and recipe.reagents or {}) do
        list[#list + 1] = { item = reagent.item, count = reagent.count * (order.n or 1) }
    end
    return list
end

-- What those materials cost, in copper; nil when one has no price.
function Orders.Cost(order)
    if not (ns.ItemPrices and ns.ItemPrices.Of) then return nil end
    local total = 0
    for _, m in ipairs(Orders.Materials(order)) do
        local each = ns.ItemPrices.Of(m.item)
        if not each then return nil end
        total = total + each * m.count
    end
    return total > 0 and total or nil
end

---------------------------------------------------------------------------
-- The book: every order heard, by its name, kept per guild.
---------------------------------------------------------------------------
local DIGITS = "0123456789abcdefghijklmnopqrstuvwxyz"
local function Code(n)
    n = math.floor(n)
    if n <= 0 then return "0" end
    local out = ""
    while n > 0 do
        local d = n % 36
        out = DIGITS:sub(d + 1, d + 1) .. out
        n = math.floor(n / 36)
    end
    return out
end

-- An order's name says who asked and when: "Ann Lee@k2j9x", with ".2" after
-- it for a second one in the same second.
local function Parts(id)
    local by, t = (id or ""):match("^([^@;~|]+)@(%w+)%.?%d*$")
    t = t and tonumber(t, 36)
    if by and t and #by <= NAME then return by, t end
end

local function Book()
    local guild = Compat.GuildName()
    if not guild then return nil end
    ns.db.orders = type(ns.db.orders) == "table" and ns.db.orders or {}
    ns.db.orders[guild] = type(ns.db.orders[guild]) == "table" and ns.db.orders[guild] or {}
    return ns.db.orders[guild]
end
Orders.Book = Book

-- Lets go of what's past its life, and of the oldest past MAX: finished ones
-- first, then by age.
local function Prune(book)
    local now, list = Compat.ServerTime(), {}
    for id, o in pairs(book) do
        if type(o) ~= "table" or type(o.t) ~= "number" or now > o.t + LIFE then
            book[id] = nil
        else
            list[#list + 1] = o
        end
    end
    if #list <= MAX then return end
    table.sort(list, function(a, b)
        local af, bf = a.s == "d" or a.s == "x", b.s == "d" or b.s == "x"
        if af ~= bf then return af end
        if a.t ~= b.t then return a.t < b.t end
        return a.id < b.id
    end)
    for i = 1, #list - MAX do book[list[i].id] = nil end
end

-- Where an order stands now: "waiting", "making", "sent", "unconfirmed",
-- "done", or nil for one not shown any more (cancelled, closed by itself, or
-- finished a while ago). One sent and not marked received in OPEN_FOR is
-- "unconfirmed": never called done, since nobody said they had it.
function Orders.State(order, now)
    now = now or Compat.ServerTime()
    if order.s == "o" then return now <= order.t + OPEN_FOR and "waiting" or nil end
    if order.s == "t" then return "making" end
    if SENT[order.s] then
        local e = order.e or order.t
        if now <= e + OPEN_FOR then return "sent" end
        return now <= e + OPEN_FOR + SHOWN and "unconfirmed" or nil
    end
    if order.s == "d" then return now <= (order.e or order.t) + SHOWN and "done" or nil end
    return nil
end

local function Changed()
    if ns.Window and ns.Window.Refresh then ns.Window.Refresh() end
    if Orders.OnChange then Orders.OnChange() end
end

---------------------------------------------------------------------------
-- An order as a line of text, and back.
-- "name;revision;changed;state;spell;count;have;on;crafter;note"
---------------------------------------------------------------------------
local function Clean(text, limit)
    text = tostring(text or ""):gsub("[;~|%c]", " "):gsub("%s+", " ")
    text = text:match("^%s*(.-)%s*$")
    -- At most `limit` bytes, as the line to the guild carries, cut between letters so none is sent broken.
    return ns.Cut(text, limit)
end

local function Line(o)
    return table.concat({
        o.id, o.r, Code(o.e), o.s, Code(o.spell), o.n or 1, o.have and 1 or 0,
        o.on and Code(o.on) or "", o.c or "", Clean(o.note, NOTE),
    }, ";")
end
Orders.Line = Line

-- Nil for anything that isn't a whole, believable order.
local function Read(line)
    local id, r, e, s, spell, n, have, on, c, note =
        (line or ""):match("^([^;]+);(%d+);(%w+);(%a);(%w+);(%d+);([01]);(%w*);([^;]*);([^;]*)$")
    if not id then return nil end
    local by, t = Parts(id)
    local now = Compat.ServerTime()
    r, e, spell, n = tonumber(r), tonumber(e, 36), tonumber(spell, 36), tonumber(n)
    if not (by and r and e and spell and n) then return nil end
    if t > now + AHEAD or e > now + AHEAD or now > t + LIFE then return nil end
    if r < 1 or r > 9999 or n < 1 or n > 200 or not STATES[s] or #c > NAME then return nil end
    if (s == "t" or SENT[s]) and c == "" then return nil end
    if not Orders.Recipe(spell) then return nil end
    return {
        id = id, by = by, t = t, r = r, e = e, s = s, spell = spell, n = n, have = have == "1",
        on = on ~= "" and tonumber(on, 36) or nil, c = c ~= "" and c or nil,
        note = note ~= "" and Clean(note, NOTE) or nil,
    }
end
Orders.Read = Read

-- Of two tellings of one order, the later revision stands. Two changes made
-- from the same revision (two crafters accepting at once): the earlier one,
-- then the crafter's name, so every jsal.ui settles on the same one.
local function Wins(new, old)
    if new.r ~= old.r then return new.r > old.r end
    if new.e ~= old.e then return new.e < old.e end
    if (new.c or "") ~= (old.c or "") then return (new.c or "") < (old.c or "") end
    return new.s < old.s
end

---------------------------------------------------------------------------
-- What's new to this character: orders it can make that it hasn't looked at.
---------------------------------------------------------------------------
local function Seen()
    ns.char.ordersSeen = type(ns.char.ordersSeen) == "table" and ns.char.ordersSeen or {}
    return ns.char.ordersSeen
end

-- The For you list was looked at: nothing on it is new any more.
function Orders.Looked()
    local book, seen = Book(), Seen()
    if not book then return end
    for id in pairs(seen) do
        if not book[id] then seen[id] = nil end
    end
    for id in pairs(book) do seen[id] = true end
end

---------------------------------------------------------------------------
-- Hearing an order.
---------------------------------------------------------------------------
local function Label(order)
    local name = Orders.Name(order) or "something"
    return (order.n or 1) > 1 and ("%d %s"):format(order.n, name) or name
end

-- A line in chat for what changes things for you.
local function Tell(new, old)
    local me = Compat.MyName()
    if not old then
        if new.s == "o" and new.by ~= me and Orders.CanMake(new.spell)
            and Compat.ServerTime() - new.t <= FRESH then
            ns.Print(("%s ordered %s from the guild, and you can make it. Accept it in /jsal crafts."):format(new.by, Label(new)))
        end
        return
    end
    if new.by == me then
        if new.s == "t" and (old.s ~= "t" or old.c ~= new.c) and new.c ~= me then
            ns.Print(("%s accepted your order for %s."):format(new.c, Label(new)))
        elseif new.s == "o" and old.s == "t" then
            ns.Print(("%s gave up your order for %s. It's open for another crafter."):format(old.c or "The crafter", Label(new)))
        elseif new.s == "m" and not SENT[old.s] then
            ns.Print(("%s mailed you your order of %s. Once it's in your bags, mark it received in /jsal crafts.")
                :format(new.c or "The crafter", Label(new)))
        elseif new.s == "s" and not SENT[old.s] then
            ns.Print(("%s handed you your order of %s. Once you have it, mark it received in /jsal crafts.")
                :format(new.c or "The crafter", Label(new)))
        elseif new.s == "d" and old.s ~= "d" and not SENT[old.s] then
            ns.Print(("%s finished your order for %s."):format(new.c or "A guildmate", Label(new)))
        end
    elseif (old.s == "t" or SENT[old.s]) and old.c == me then
        if new.s == "x" then
            ns.Print(("%s cancelled their order for %s, which you'd accepted."):format(new.by, Label(new)))
        elseif new.s == "t" and old.s == "t" and new.c ~= me then
            ns.Print(("%s accepted %s's order for %s just before you did."):format(new.c, new.by, Label(new)))
        elseif new.s == "d" then
            ns.Print(("%s received the %s you made."):format(new.by, Label(new)))
        end
    end
end

-- Takes an order in: "new", "changed", or nil when what's kept stands.
local function Merge(new, quiet)
    local book = Book()
    if not book then return nil end
    local old = book[new.id]
    if old and not Wins(new, old) then return nil end
    book[new.id] = new
    if not old then Prune(book) end
    if not quiet then Tell(new, old) end
    return old and "changed" or "new"
end

local function Heard(payload)
    if not On() then return end
    local any = false
    for line in (payload or ""):gmatch("[^~]+") do
        local order = Read(line)
        if order and Merge(order) then any = true end
    end
    if any then Changed() end
end

---------------------------------------------------------------------------
-- Asking, accepting and the rest. Each gives true, or false and why.
---------------------------------------------------------------------------
local function Send(order)
    Comms.Send("OO", Line(order), "GUILD")
end

local function Step(order, state, crafter)
    order.r, order.e, order.s, order.c = order.r + 1, Compat.ServerTime(), state, crafter
    Send(order)
    Changed()
    return true
end

local function Find(id)
    local book = On() and Book()
    local order = book and book[id]
    if not order then return nil, "That order is gone." end
    return order
end

-- How many of your own are open now.
local function MineOpen(book, me, now)
    local n = 0
    for _, o in pairs(book) do
        if o.by == me and (o.s == "t" or (o.s == "o" and now <= o.t + OPEN_FOR)) then n = n + 1 end
    end
    return n
end

function Orders.Post(spell, count, have, on, note)
    if not Orders.running then return false, "Guild orders are off. Turn them on in Settings, under Professions." end
    local book = IsInGuild and IsInGuild() and Book()
    if not book then return false, "Orders go to your guild: join one to order something." end
    if not Orders.Recipe(spell) then return false, "Pick something a profession makes." end
    local me, now = Compat.MyName(), Compat.ServerTime()
    if MineOpen(book, me, now) >= MINE_MAX then
        return false, ("You already have %d open orders. Cancel one, or wait until one is sent."):format(MINE_MAX)
    end
    count = math.max(1, math.min(200, math.floor(tonumber(count) or 1)))
    local id, k = me .. "@" .. Code(now), 1
    while book[id] do
        k = k + 1
        id = me .. "@" .. Code(now) .. "." .. k
    end
    local order = {
        id = id, by = me, t = now, r = 1, e = now, s = "o", spell = spell, n = count, have = have and true or false,
        on = tonumber(on), note = note and Clean(note, NOTE) ~= "" and Clean(note, NOTE) or nil,
    }
    book[id] = order
    Prune(book)
    Seen()[id] = true
    Send(order)
    Changed()
    return true, order
end

function Orders.Accept(id)
    local order, why = Find(id)
    if not order then return false, why end
    local me = Compat.MyName()
    if order.by == me then return false, "You can't accept your own order." end
    if Orders.State(order) ~= "waiting" then return false, "Someone else has already accepted it." end
    if not Orders.CanMake(order.spell) then return false, "You don't know that recipe. If you've just learned it, open your profession window first." end
    return Step(order, "t", me)
end

-- Gives an accepted order back: it waits for a crafter again.
function Orders.Release(id)
    local order, why = Find(id)
    if not order then return false, why end
    if not (order.s == "t" and order.c == Compat.MyName()) then return false, "Only the crafter who accepted it can give it up." end
    return Step(order, "o", nil)
end

-- The crafter's "Mark done", for an enchant: it was given in a trade, so it's done.
function Orders.Done(id)
    local order, why = Find(id)
    if not order then return false, why end
    if not (order.s == "t" and order.c == Compat.MyName()) then return false, "Only the crafter who accepted it can mark it done." end
    return Step(order, "d", order.c)
end

-- An item handed over: it's on its way, and done once whoever asked marks it
-- received. `mailed` when a letter carried it, else a trade did. Called from
-- the letter and the trade (Orders.Mailed, Orders.Traded), never a button.
function Orders.Sent(id, mailed)
    local order, why = Find(id)
    if not order then return false, why end
    if not (order.s == "t" and order.c == Compat.MyName()) then return false, "Only the crafter who accepted it can mark it sent." end
    return Step(order, mailed and "m" or "s", order.c)
end

-- The asker's "Mark received".
function Orders.GotIt(id)
    local order, why = Find(id)
    if not order then return false, why end
    if order.by ~= Compat.MyName() or not (order.s == "o" or order.s == "t" or SENT[order.s]) then return false, "Only the person who ordered it can mark it received." end
    return Step(order, "d", order.c)
end

-- Whether an order makes an item (one that can be mailed), not an enchant.
function Orders.MakesItem(order)
    local recipe = Orders.Recipe(order.spell)
    return recipe and recipe.item and true or false
end

-- A letter, from the moment Send is pressed until the game says it went:
-- who it's to, and how many of each item it carries.
local letter
local function Addressee(name)
    return tostring(name or ""):gsub("%-.*$", ""):gsub("^%s+", ""):gsub("%s+$", ""):lower()
end

function Orders.Mailing(to, items)
    letter = to and { to = Addressee(to), items = items or {} } or nil
end

-- Something went to `to` (a name) carrying `items` (item = how many): each
-- order you accepted from them, for an item it carried, is sent. Gives how many.
local function HandedOver(to, items, mailed)
    local book = to and On() and Book()
    if not book then return 0 end
    local me, ids, n = Compat.MyName(), {}, 0
    to = Addressee(to)
    for id, o in pairs(book) do
        local recipe = o.s == "t" and o.c == me and Addressee(o.by) == to and Orders.Recipe(o.spell)
        if recipe and recipe.item and ((items or {})[recipe.item] or 0) > 0 then ids[#ids + 1] = id end
    end
    table.sort(ids)
    for _, id in ipairs(ids) do
        if Orders.Sent(id, mailed) then n = n + 1 end
    end
    return n
end

-- The letter went: each order you accepted from whoever it was to, for an
-- item it carried, is sent. Gives how many.
function Orders.Mailed()
    local sent = letter
    letter = nil
    if not sent then return 0 end
    return HandedOver(sent.to, sent.items, true)
end

-- A trade with `with` finished, with `items` (item = how many) on your side
-- of it: each order you accepted from them, for one of those, is sent.
function Orders.Traded(with, items)
    return HandedOver(with, items, false)
end

function Orders.Cancel(id)
    local order, why = Find(id)
    if not order then return false, why end
    if order.by ~= Compat.MyName() or not (order.s == "o" or order.s == "t") then return false, "Only the person who ordered it can cancel it, and only before it's sent." end
    return Step(order, "x", order.c)
end

---------------------------------------------------------------------------
-- The lists the window shows, newest first.
---------------------------------------------------------------------------
local function Newest(a, b)
    if a.t ~= b.t then return a.t > b.t end
    return a.id < b.id
end

local function LatestDone(a, b)
    if (a.e or 0) ~= (b.e or 0) then return (a.e or 0) > (b.e or 0) end
    return a.id < b.id
end

-- For you: `todo` (you accepted them), `waiting` (open, and you know the
-- recipe), `sent` (you sent them; whoever asked hasn't marked them
-- received), `unconfirmed` (sent over a week ago and never marked received),
-- `done` (you made them, lately), and how many more are waiting for a
-- profession you don't have.
function Orders.ForMe()
    local out = { todo = {}, waiting = {}, sent = {}, unconfirmed = {}, done = {}, other = 0, open = 0 }
    local book = On() and Book()
    if not book then return out end
    local me, now = Compat.MyName(), Compat.ServerTime()
    for _, o in pairs(book) do
        local state = Orders.State(o, now)
        if state == "waiting" or state == "making" then out.open = out.open + 1 end
        if state == "making" and o.c == me then
            out.todo[#out.todo + 1] = o
        elseif state == "waiting" and o.by ~= me then
            if Orders.CanMake(o.spell) then out.waiting[#out.waiting + 1] = o else out.other = out.other + 1 end
        elseif (state == "sent" or state == "unconfirmed") and o.c == me and o.by ~= me then
            out[state][#out[state] + 1] = o
        elseif state == "done" and o.c == me and o.by ~= me then
            out.done[#out.done + 1] = o
        end
    end
    table.sort(out.todo, Newest)
    table.sort(out.waiting, Newest)
    table.sort(out.sent, LatestDone)
    table.sort(out.unconfirmed, LatestDone)
    table.sort(out.done, LatestDone)
    return out
end

-- Your own orders: `waiting`, `making`, `sent` (on their way to you: mark
-- them received), `unconfirmed` (sent over a week ago, never marked
-- received) and `done`.
function Orders.Mine()
    local out = { waiting = {}, making = {}, sent = {}, unconfirmed = {}, done = {} }
    local book = On() and Book()
    if not book then return out end
    local me, now = Compat.MyName(), Compat.ServerTime()
    for _, o in pairs(book) do
        local state = o.by == me and Orders.State(o, now)
        if state then out[state][#out[state] + 1] = o end
    end
    table.sort(out.waiting, Newest)
    table.sort(out.making, Newest)
    table.sort(out.sent, LatestDone)
    table.sort(out.unconfirmed, LatestDone)
    table.sort(out.done, LatestDone)
    return out
end

-- What waits on you, by the tab it's on: orders you accepted and are making
-- for someone (For you), and yours that were sent to you, to mark received
-- (Your orders).
function Orders.WaitingOnMe()
    local book = On() and Book()
    if not book then return 0, 0 end
    local me, now, making, sent = Compat.MyName(), Compat.ServerTime(), 0, 0
    for _, o in pairs(book) do
        local state = Orders.State(o, now)
        if state == "making" and o.c == me then
            making = making + 1
        elseif state == "sent" and o.by == me then
            sent = sent + 1
        end
    end
    return making, sent
end

-- The number for the menu and the quick button: what waits on you (orders
-- you accepted, and yours that were sent to you), and with `new`, also the
-- orders you could accept that you haven't looked at yet.
function Orders.Badge(new)
    local book = On() and Book()
    if not book then return 0 end
    local me, now, seen, n = Compat.MyName(), Compat.ServerTime(), Seen(), 0
    for id, o in pairs(book) do
        local state = Orders.State(o, now)
        if state == "making" and o.c == me then
            n = n + 1
        elseif state == "sent" and o.by == me then
            n = n + 1
        elseif new and state == "waiting" and o.by ~= me and not seen[id] and Orders.CanMake(o.spell) then
            n = n + 1
        end
    end
    return n
end

---------------------------------------------------------------------------
-- Catching up: a summary in the hello, and the whole book on request.
---------------------------------------------------------------------------
-- How many orders are kept and their revisions added up, in base 36.
function Orders.Signature()
    local book = On() and Book()
    if not book then return "" end
    Prune(book)
    local count, sum = 0, 0
    for _, o in pairs(book) do count, sum = count + 1, sum + (tonumber(o.r) or 0) end
    if count == 0 then return "" end
    return Code(count) .. "." .. Code(sum)
end

local function Totals(sig)
    local c, s = (sig or ""):match("^(%w+)%.(%w+)$")
    return tonumber(c or "", 36), tonumber(s or "", 36)
end

local asked, answered, lastAsk = {}, {}, -ASK_ANYONE

-- The Guild tab heard a guildmate's hello: ask for their orders when they
-- have heard of more than we have. One guildmate at a time: a login brings
-- the whole guild's answers at once, and the first list usually has it all.
function Orders.HeardHello(name, sig, target)
    if not On() or not sig or sig == "" or name == Compat.MyName() then return end
    local count, sum = Totals(sig)
    if not count then return end
    local myCount, mySum = Totals(Orders.Signature())
    if count <= (myCount or 0) and sum <= (mySum or 0) then return end
    local now = GetTime()
    if (asked[name] or -ASK_AGAIN) + ASK_AGAIN > now or lastAsk + ASK_ANYONE > now then return end
    asked[name], lastAsk = now, now
    Comms.Send("OQ", "", "WHISPER", target or name)
end

-- The book as messages: as many orders in each as fit.
local function Packed()
    local book, lines = Book() or {}, {}
    for _, o in pairs(book) do lines[#lines + 1] = Line(o) end
    table.sort(lines)
    local out, at = {}, nil
    for _, line in ipairs(lines) do
        if at and #at + 1 + #line <= PACK then
            at = at .. "~" .. line
        else
            if at then out[#out + 1] = at end
            at = line
        end
    end
    if at then out[#out + 1] = at end
    return out
end
Orders.Packed = Packed

local function Asked(_, name, _, sender)
    if not On() then return end
    if (answered[name] or -ANSWER_AGAIN) + ANSWER_AGAIN > GetTime() then return end
    answered[name] = GetTime()
    Prune(Book())
    for _, text in ipairs(Packed()) do Comms.Send("OO", text, "WHISPER", sender or name) end
end

function Orders:OnEnable()
    Comms.On("OO", Heard)
    Comms.On("OQ", Asked)
    local book = IsInGuild and IsInGuild() and Book()
    if book then Prune(book) end
    if ns.OrderMail then ns.OrderMail.Start() end
end

function Orders:OnDisable()
    Comms.On("OO", nil)
    Comms.On("OQ", nil)
    if ns.OrderMail then ns.OrderMail.Stop() end
end
