-- Guild crafters: who in the guild can make what. Each jsal.ui shares the
-- recipes its character knows (as seen the last time the profession window
-- was open) with guildmates who ask. A short fingerprint of them rides in
-- the Guild tab's hello, so a guildmate asks again only after it changes;
-- what they hear is kept between sessions, per guild. The Professions page
-- lists who shares, with their professions, and searches what they make;
-- item tooltips name the guildmates who make the item.
local _, ns = ...
local Compat, Comms, Professions = ns.Compat, ns.Comms, ns.Professions

local Crafters = ns.NewModule("crafters", {
    title = "Guild crafters",
    note = "Shares your recipes with guildmates who have jsal.ui, so anyone can see who makes what. On the Professions page and in item tooltips.",
})
ns.Crafters = Crafters

local CHUNK, MAX_PARTS = 180, 40
local ASK_AGAIN, ANSWER_AGAIN = 300, 60   -- seconds
-- First Aid is everyone's, so it isn't shared.
local SKIP = { [129] = true }
-- The professions with nothing to make: only that you have one is shared.
local GATHER = { [182] = "Herbalism", [393] = "Skinning", [356] = "Fishing" }

-- This character's gathering professions, from the game's list: each one's
-- skill line and skill, lowest line first.
local function Gathering()
    local out = {}
    if not (GetProfessions and GetProfessionInfo) then return out end
    local function Places(...) return select("#", ...), { ... } end
    local count, places = Places(GetProfessions())
    for i = 1, count do
        if places[i] then
            local _, _, skill, _, _, _, line = GetProfessionInfo(places[i])
            if line and GATHER[line] then out[#out + 1] = { line = line, skill = skill or 0 } end
        end
    end
    table.sort(out, function(a, b) return a.line < b.line end)
    return out
end

---------------------------------------------------------------------------
-- Recipes as text: each spell ID in four base-36 letters, so a profession
-- of 150 recipes is about 600 letters.
---------------------------------------------------------------------------
local DIGITS = "0123456789abcdefghijklmnopqrstuvwxyz"

local function Code(n)
    local out = {}
    for i = 4, 1, -1 do
        local d = n % 36
        out[i] = DIGITS:sub(d + 1, d + 1)
        n = math.floor(n / 36)
    end
    return table.concat(out)
end

local function Decode(code)
    return tonumber(code, 36)
end

-- This character's recipes: "line:skill:codes" per profession, joined by ",".
function Crafters.MineText()
    local all = type(ns.char.professions) == "table" and ns.char.professions or {}
    local lines = {}
    for line in pairs(all) do lines[#lines + 1] = line end
    table.sort(lines)
    local parts = {}
    for _, line in ipairs(lines) do
        local p = all[line]
        if not SKIP[line] and type(p) == "table" and type(p.known) == "table" then
            local spells = {}
            for spell in pairs(p.known) do
                if spell > 0 and spell < 36 ^ 4 then spells[#spells + 1] = spell end
            end
            table.sort(spells)
            if #spells > 0 then
                local codes = {}
                for i, spell in ipairs(spells) do codes[i] = Code(spell) end
                parts[#parts + 1] = ("%d:%d:%s"):format(line, p.skill or 0, table.concat(codes))
            end
        end
    end
    -- A gathering profession has no recipes, so it's shared with none, and
    -- its skill in steps of 25: every point would be a new fingerprint, and
    -- the whole guild asking again for the list.
    for _, g in ipairs(Gathering()) do
        parts[#parts + 1] = ("%d:%d:"):format(g.line, g.skill - g.skill % 25)
    end
    return table.concat(parts, ",")
end

-- A short fingerprint of a recipe text: changes whenever the text does.
local function Fingerprint(text)
    if text == "" then return "" end
    local h = 5381
    for i = 1, #text do h = (h * 33 + text:byte(i)) % 2147483647 end
    return ("%x"):format(h)
end

local mineText, mineSig
function Crafters.Signature()
    if not Crafters.running then return "" end
    local text = Crafters.MineText()
    if text ~= mineText then mineText, mineSig = text, Fingerprint(text) end
    return mineSig
end

---------------------------------------------------------------------------
-- What's been heard, kept per guild: name = { sig, seen, text }.
---------------------------------------------------------------------------
local function Heard()
    local guild = Compat.GuildName()
    if not guild then return nil end
    ns.db.crafters = type(ns.db.crafters) == "table" and ns.db.crafters or {}
    ns.db.crafters[guild] = type(ns.db.crafters[guild]) == "table" and ns.db.crafters[guild] or {}
    return ns.db.crafters[guild]
end

-- Made from what's been heard: item (or spell, for crafts that make no
-- item) = { spell, line, item, names = { name = true } }.
local index, dirty = nil, true

local function Build()
    index = { byItem = {}, list = {} }
    local recipes = {}
    for line, source in pairs(ns.ProfessionData) do
        if type(line) == "number" and type(source) == "table" and type(source.recipes) == "table" and not SKIP[line] then
            for _, recipe in ipairs(Professions.Recipes(line) or {}) do recipes[recipe.spell] = { recipe = recipe, line = line } end
        end
    end
    local me = Compat.MyName()
    for name, entry in pairs(Heard() or {}) do
        if name ~= me and type(entry) == "table" and type(entry.text) == "string" then
            for part in entry.text:gmatch("[^,]+") do
                local line, _, codes = part:match("^(%d+):(%d+):(%w*)$")
                line = tonumber(line)
                for code in (codes or ""):gmatch("%w%w%w%w") do
                    local spell = Decode(code)
                    local known = spell and recipes[spell]
                    if known and known.line == line then
                        local key = known.recipe.item or -spell
                        local row = index.byItem[key]
                        if not row then
                            row = { spell = spell, line = line, item = known.recipe.item, names = {} }
                            index.byItem[key] = row
                            index.list[#index.list + 1] = row
                        end
                        row.names[name] = true
                    end
                end
            end
        end
    end
    dirty = false
end

local function Index()
    if dirty or not index then Build() end
    return index
end

-- The guild by name: true for those online now, and where each of them is.
local function OnlineNow()
    local online, zones = {}, {}
    for i = 1, (GetNumGuildMembers and GetNumGuildMembers() or 0) do
        local full, _, _, _, _, zone, _, _, isOnline = GetGuildRosterInfo(i)
        if full and isOnline then
            local name = Ambiguate(full, "none")
            online[name] = true
            zones[name] = type(zone) == "string" and zone ~= "" and zone or nil
        end
    end
    return online, zones
end

-- A row's crafters, online first, then the most recently seen.
local function People(row, online)
    local heard = Heard() or {}
    local list = {}
    for name in pairs(row.names) do
        local entry = heard[name] or {}
        list[#list + 1] = { name = name, online = online[name] == true, seen = entry.seen or 0, target = entry.target or name }
    end
    table.sort(list, function(a, b)
        if a.online ~= b.online then return a.online end
        if a.seen ~= b.seen then return a.seen > b.seen end
        return a.name < b.name
    end)
    return list
end

local function RowName(row)
    return (row.item and Compat.ItemName(row.item)) or (Compat.SpellInfo(row.spell)) or nil
end
Crafters.RowName = RowName

-- Who makes an item: a list of { name, online, seen }, or nil.
function Crafters.ForItem(item)
    if not Crafters.running or not item then return nil end
    local row = Index().byItem[item]
    return row and People(row, OnlineNow()) or nil
end

-- What guildmates make whose name has the text in it: rows of { row, name,
-- people }, crafts someone online makes first. Names not loaded yet are
-- skipped until the game has them.
function Crafters.Search(text, limit)
    text = strtrim(text or ""):lower()
    if text == "" then return {} end
    local online, found = OnlineNow(), {}
    for _, row in ipairs(Index().list) do
        local name = RowName(row)
        if name and name:lower():find(text, 1, true) then
            local people = People(row, online)
            found[#found + 1] = { row = row, name = name, people = people }
        end
    end
    table.sort(found, function(a, b)
        local ao, bo = a.people[1].online, b.people[1].online
        if ao ~= bo then return ao end
        return a.name < b.name
    end)
    for i = (limit or 40) + 1, #found do found[i] = nil end
    return found
end

-- The guildmates who share, online first, then the most recently heard
-- from: each { name, online, zone, seen, target, recipes, profs }, a
-- profession being { line, name, skill, recipes, steps }. `steps`: a
-- gathering profession, whose skill is shared in steps of 25.
function Crafters.Sharing()
    local online, zones = OnlineNow()
    local me, list = Compat.MyName(), {}
    for name, entry in pairs(Heard() or {}) do
        if name ~= me and type(entry) == "table" and type(entry.text) == "string" then
            local person = { name = name, online = online[name] == true, zone = zones[name], seen = entry.seen or 0,
                             target = entry.target or name, recipes = 0, profs = {} }
            for part in entry.text:gmatch("[^,]+") do
                local line, skill, codes = part:match("^(%d+):(%d+):(%w*)$")
                line = tonumber(line)
                local label = line and (Professions.Name(line) or GATHER[line])
                if label and not SKIP[line] then
                    local count = math.floor(#codes / 4)
                    person.recipes = person.recipes + count
                    person.profs[#person.profs + 1] = { line = line, name = label, skill = tonumber(skill) or 0,
                                                        recipes = count, steps = GATHER[line] ~= nil }
                end
            end
            if #person.profs > 0 then list[#list + 1] = person end
        end
    end
    table.sort(list, function(a, b)
        if a.online ~= b.online then return a.online end
        if a.seen ~= b.seen then return a.seen > b.seen end
        return a.name < b.name
    end)
    return list
end

-- What one guildmate makes with one profession, by name: rows as Search
-- gives them, each with that one person. Names the game hasn't loaded yet
-- are left out until it has.
function Crafters.Makes(who, line)
    local online, found = OnlineNow(), {}
    for _, row in ipairs(Index().list) do
        if row.line == line and row.names[who] then
            local name = RowName(row)
            if name then
                found[#found + 1] = { row = row, name = name, people = People({ names = { [who] = true } }, online) }
            end
        end
    end
    table.sort(found, function(a, b) return a.name < b.name end)
    return found
end

-- Opens a whisper to a crafter with a request typed in, ready to send.
function Crafters.Whisper(person, itemName)
    itemName = itemName or "something"
    local article = itemName == "something" and "" or (itemName:match("^[AEIOUaeiou]") and "an " or "a ")
    local line = ("Hi! Could you make me %s%s?"):format(article, itemName)
    local tell = (ChatFrameUtil and ChatFrameUtil.SendTellWithMessage) or ChatFrame_SendTellWithMessage
    if tell then
        tell(person.target or person.name, line)
    else
        ns.Print(("Whisper %s: %s"):format(person.name, line))
    end
end

-- How long ago, in words, for a crafter not online now.
function Crafters.Ago(seen)
    local days = math.floor(((Compat.ServerTime() or 0) - (seen or 0)) / 86400)
    if days <= 0 then return "seen today" end
    if days == 1 then return "seen yesterday" end
    return ("seen %d days ago"):format(days)
end

-- How many guildmates have shared, and in how many professions.
function Crafters.Count()
    local people, lines = 0, {}
    for _, entry in pairs(Heard() or {}) do
        if type(entry) == "table" and entry.text and entry.text ~= "" then
            people = people + 1
            for line in entry.text:gmatch("(%d+):%d+:") do lines[line] = true end
        end
    end
    local n = 0
    for _ in pairs(lines) do n = n + 1 end
    return people, n
end

---------------------------------------------------------------------------
-- The messages: "RQ" asks for someone's recipes; "RP" answers in pieces,
-- "sig;i;n;piece".
---------------------------------------------------------------------------
local asked, answered, partial = {}, {}, {}

-- The Guild tab heard a guildmate's hello: ask for their recipes when their
-- fingerprint is new to us.
function Crafters.HeardHello(name, sig, target)
    if not Crafters.running or not sig or sig == "" or name == Compat.MyName() then return end
    local heard = Heard()
    if not heard then return end
    local entry = heard[name]
    if entry and entry.sig == sig then
        entry.seen = Compat.ServerTime()
        return
    end
    if (asked[name] or -ASK_AGAIN) + ASK_AGAIN > GetTime() then return end
    asked[name] = GetTime()
    Comms.Send("RQ", sig, "WHISPER", target or name)
end

local function Pieces(text)
    local list = {}
    for at = 1, #text, CHUNK do list[#list + 1] = text:sub(at, at + CHUNK - 1) end
    return list
end

local function Asked(_, name, _, sender)
    if (answered[name] or -ANSWER_AGAIN) + ANSWER_AGAIN > GetTime() then return end
    answered[name] = GetTime()
    local sig = Crafters.Signature()
    if sig == "" then return end
    local pieces = Pieces(mineText)
    if #pieces > MAX_PARTS then return end
    for i, piece in ipairs(pieces) do
        Comms.Send("RP", table.concat({ sig, i, #pieces, piece }, ";"), "WHISPER", sender)
    end
end

local function Answered(payload, name, _, sender)
    local sig, i, n, piece = (payload or ""):match("^(%x+);(%d+);(%d+);([%w:,]*)$")
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
    local heard = Heard()
    if not heard then return end
    heard[name] = { sig = sig, seen = Compat.ServerTime(), text = text, target = sender or name }
    dirty = true
    if ns.Window then ns.Window.Refresh() end
end

-- When this character's recipes change (a profession window was opened and
-- something new learned), the guild hears the new fingerprint.
local lastAnnounced
function Crafters.Changed()
    if not Crafters.running then return end
    local sig = Crafters.Signature()
    if sig ~= lastAnnounced and lastAnnounced ~= nil and ns.Guild and ns.Guild.Announce then ns.Guild.Announce() end
    lastAnnounced = sig
end

---------------------------------------------------------------------------
-- Item tooltips: who in the guild makes it.
---------------------------------------------------------------------------
local function AddLines(tooltip, item)
    if not Crafters.running or not item then return end
    if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
    local people = Crafters.ForItem(item)
    if not people or #people == 0 then return end
    local on, off = {}, {}
    for _, p in ipairs(people) do
        if p.online then on[#on + 1] = p.name elseif #off < 3 then off[#off + 1] = p.name end
    end
    tooltip:AddLine(" ")
    tooltip:AddLine("Guild crafters", 0.89, 0.69, 0.29)
    if #on > 0 then tooltip:AddLine(table.concat(on, ", ", 1, math.min(#on, 5)) .. (#on > 5 and (" and " .. (#on - 5) .. " more") or ""), 1, 1, 1, true) end
    if #off > 0 then tooltip:AddLine(table.concat(off, ", ") .. " (offline)", 0.6, 0.59, 0.53, true) end
end

local hooked = false
local function HookTooltips()
    if hooked then return end
    hooked = true
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
            xpcall(AddLines, ns.Report, tooltip, data and data.id)
        end)
    elseif GameTooltip and GameTooltip.HookScript then
        GameTooltip:HookScript("OnTooltipSetItem", function(tooltip)
            local _, link = tooltip:GetItem()
            local item = link and tonumber(link:match("item:(%d+)"))
            xpcall(AddLines, ns.Report, tooltip, item)
        end)
    end
end

function Crafters:OnEnable()
    Comms.On("RQ", Asked)
    Comms.On("RP", Answered)
    HookTooltips()
    lastAnnounced = Crafters.Signature()
end

function Crafters:OnDisable()
    Comms.On("RQ", nil)
    Comms.On("RP", nil)
end
