-- Guild loot: the boss kills and drops every guildmate with jsal.ui sees,
-- shared through the game's hidden addon channel, so each boss's card
-- fills in from the whole guild's runs ("guild 3 of 8"). Each kill and drop
-- carries a tag for the group that saw it, so five guildmates in one group
-- count it once (an item dropping twice from one kill counts once too). A short summary rides in the Guild tab's hello; anyone
-- who has heard less asks for the rest. Kept per guild, for the account.
-- Only bosses from the guide are kept, and only uncommon or better items.
local _, ns = ...
local Compat, Comms = ns.Compat, ns.Comms

local GuildLoot = {}
ns.GuildLoot = GuildLoot

-- A kill or drop heard again within this many seconds is the same one.
local SAME = 900
local CHUNK, MAX_PARTS = 180, 40
local ASK_AGAIN, ANSWER_AGAIN = 300, 60

local function On()
    local D = ns.Dungeons
    return D and D.running and ns.OptionOn("dungeons", "share") and IsInGuild and IsInGuild()
end
GuildLoot.On = On

-- The guide's encounter IDs, so nothing else is kept.
local known
local function Known(enc)
    if not known then
        known = {}
        for _, d in ipairs(ns.DungeonData or {}) do
            for _, b in ipairs(d.bosses) do known[b[1]] = true end
        end
    end
    return known[enc]
end

-- What's been heard, kept per guild: { [encounter] = { k = kills, i = { [item] = drops } } }.
function GuildLoot.Book()
    local guild = Compat.GuildName()
    if not guild then return nil end
    ns.db.guildLoot = type(ns.db.guildLoot) == "table" and ns.db.guildLoot or {}
    ns.db.guildLoot[guild] = type(ns.db.guildLoot[guild]) == "table" and ns.db.guildLoot[guild] or {}
    return ns.db.guildLoot[guild]
end

function GuildLoot.For(enc)
    local book = GuildLoot.Book()
    return book and book[enc]
end

local function Entry(book, enc)
    local e = book[enc]
    if type(e) ~= "table" then
        e = { k = 0, i = {} }
        book[enc] = e
    end
    e.i = type(e.i) == "table" and e.i or {}
    e.k = tonumber(e.k) or 0
    return e
end

-- The group's tag: the first of its members' names, the same for everyone in
-- it; alone, your own.
function GuildLoot.GroupTag()
    local names = { UnitName("player") }
    local raid = IsInRaid and IsInRaid()
    local count = raid and GetNumGroupMembers() or (GetNumSubgroupMembers and GetNumSubgroupMembers() or 0)
    for i = 1, count do
        local name = UnitName((raid and "raid" or "party") .. i)
        if name then names[#names + 1] = name end
    end
    table.sort(names)
    return names[1] or "?"
end

local heard = {}
local function Fresh(key)
    local now = GetTime()
    if heard[key] and now - heard[key] < SAME then return false end
    heard[key] = now
    return true
end

local function Changed()
    if ns.Window and ns.Window.IsOpen and ns.Window.IsOpen("dungeons") then ns.Window.Refresh() end
end

-- A kill or drop, ours or a guildmate's: counted once per group and event.
local function Kill(enc, tag)
    if not (Known(enc) and tag and tag ~= "") then return false end
    local book = GuildLoot.Book()
    if not book or not Fresh("k" .. enc .. tag) then return false end
    local e = Entry(book, enc)
    e.k = e.k + 1
    return true
end

local function Drop(enc, item, tag)
    if not (Known(enc) and item and item > 0 and tag and tag ~= "") then return false end
    local book = GuildLoot.Book()
    if not book or not Fresh("d" .. enc .. ":" .. item .. tag) then return false end
    local e = Entry(book, enc)
    e.i[item] = (e.i[item] or 0) + 1
    return true
end

---------------------------------------------------------------------------
-- What this player sees, from the dungeon guide.
---------------------------------------------------------------------------
function GuildLoot.Killed(enc)
    if not On() then return end
    local tag = GuildLoot.GroupTag()
    if Kill(enc, tag) then
        Comms.Send("LK", enc .. ";" .. tag, "GUILD")
        Changed()
    end
end

-- A drop, from the loot window or a roll: the same item from the same boss
-- for the same group is one drop, whoever reports it and however.
function GuildLoot.Dropped(enc, link)
    if not (On() and enc and type(link) == "string") then return end
    local item = tonumber(link:match("item:(%d+)"))
    local color = link:match("|c%x%x(%x%x%x%x%x%x)")
    local low = color and (color:lower() == "9d9d9d" or color:lower() == "ffffff")
    if not item or low then return end
    local tag = GuildLoot.GroupTag()
    if Drop(enc, item, tag) then
        Comms.Send("LD", enc .. ";" .. item .. ";" .. tag, "GUILD")
        Changed()
    end
end

local function HeardKill(payload)
    if not On() then return end
    local enc, tag = (payload or ""):match("^(%d+);([^;]+)$")
    if Kill(tonumber(enc), tag) then Changed() end
end

local function HeardDrop(payload)
    if not On() then return end
    local enc, item, tag = (payload or ""):match("^(%d+);(%d+);([^;]+)$")
    if Drop(tonumber(enc), tonumber(item), tag) then Changed() end
end

---------------------------------------------------------------------------
-- Catching up: the summary in the hello, and the whole list on request.
---------------------------------------------------------------------------
local DIGITS = "0123456789abcdefghijklmnopqrstuvwxyz"
local function Code(n)
    n = math.floor(n)
    if n == 0 then return "0" end
    local out = ""
    while n > 0 do
        local d = n % 36
        out = DIGITS:sub(d + 1, d + 1) .. out
        n = math.floor(n / 36)
    end
    return out
end

-- Kills and drops heard in all, "kills.drops" in base 36.
function GuildLoot.Signature()
    if not On() then return "" end
    local book = GuildLoot.Book()
    if not book then return "" end
    local kills, drops = 0, 0
    for _, e in pairs(book) do
        kills = kills + (tonumber(e.k) or 0)
        for _, n in pairs(type(e.i) == "table" and e.i or {}) do drops = drops + n end
    end
    if kills + drops == 0 then return "" end
    return Code(kills) .. "." .. Code(drops)
end

local function Totals(sig)
    local k, d = (sig or ""):match("^(%w+)%.(%w+)$")
    return tonumber(k or "", 36), tonumber(d or "", 36)
end

-- The whole list as text: "enc:kills:item.n/item.n", joined by ",".
function GuildLoot.Text()
    local book = GuildLoot.Book() or {}
    local encs = {}
    for enc in pairs(book) do encs[#encs + 1] = enc end
    table.sort(encs)
    local parts = {}
    for _, enc in ipairs(encs) do
        local e = book[enc]
        local items = {}
        for item, n in pairs(type(e.i) == "table" and e.i or {}) do items[#items + 1] = Code(item) .. "." .. Code(n) end
        table.sort(items)
        parts[#parts + 1] = Code(enc) .. ":" .. Code(tonumber(e.k) or 0) .. ":" .. table.concat(items, "/")
    end
    return table.concat(parts, ",")
end

-- Another list joined in: the larger count wins for each kill and drop.
function GuildLoot.Merge(text)
    local book = GuildLoot.Book()
    if not book or type(text) ~= "string" then return false end
    local any = false
    for enc36, k36, items in text:gmatch("(%w+):(%w+):([%w%./]*)") do
        local enc, kills = tonumber(enc36, 36), tonumber(k36, 36)
        if enc and kills and Known(enc) then
            local e = Entry(book, enc)
            if kills > e.k then e.k, any = kills, true end
            for item36, n36 in items:gmatch("(%w+)%.(%w+)") do
                local item, n = tonumber(item36, 36), tonumber(n36, 36)
                if item and n and n > (e.i[item] or 0) then e.i[item], any = n, true end
            end
        end
    end
    if any then Changed() end
    return any
end

local function Fingerprint(text)
    local h = 5381
    for i = 1, #text do h = (h * 33 + text:byte(i)) % 2147483647 end
    return ("%x"):format(h)
end

local asked, answered, partial = {}, {}, {}

-- The Guild tab heard a guildmate's hello: ask for their list when they've
-- heard of more kills or drops than we have.
function GuildLoot.HeardHello(name, sig, target)
    if not On() or not sig or sig == "" or name == Compat.MyName() then return end
    local k, d = Totals(sig)
    local myK, myD = Totals(GuildLoot.Signature())
    if not k or ((k <= (myK or 0)) and (d <= (myD or 0))) then return end
    if (asked[name] or -ASK_AGAIN) + ASK_AGAIN > GetTime() then return end
    asked[name] = GetTime()
    Comms.Send("LQ", "", "WHISPER", target or name)
end

local function Asked(_, name, _, sender)
    if not On() then return end
    if (answered[name] or -ANSWER_AGAIN) + ANSWER_AGAIN > GetTime() then return end
    answered[name] = GetTime()
    local text = GuildLoot.Text()
    if text == "" then return end
    local sig = Fingerprint(text)
    local pieces = {}
    for at = 1, #text, CHUNK do pieces[#pieces + 1] = text:sub(at, at + CHUNK - 1) end
    if #pieces > MAX_PARTS then return end
    for i, piece in ipairs(pieces) do
        Comms.Send("LP", table.concat({ sig, i, #pieces, piece }, ";"), "WHISPER", sender)
    end
end

local function Answered(payload, name)
    if not On() then return end
    local sig, i, n, piece = (payload or ""):match("^(%x+);(%d+);(%d+);([%w:,%./]*)$")
    i, n = tonumber(i), tonumber(n)
    if not sig or n < 1 or n > MAX_PARTS or i < 1 or i > n then return end
    local key = name .. ":" .. sig
    local parts = partial[key]
    if not parts or parts.n ~= n then
        parts = { n = n, got = 0 }
        partial[key] = parts
    end
    if not parts[i] then
        parts[i] = piece
        parts.got = parts.got + 1
    end
    if parts.got < n then return end
    partial[key] = nil
    local text = table.concat(parts, "", 1, n)
    if Fingerprint(text) ~= sig then return end
    GuildLoot.Merge(text)
end

Comms.On("LK", HeardKill)
Comms.On("LD", HeardDrop)
Comms.On("LQ", Asked)
Comms.On("LP", Answered)
