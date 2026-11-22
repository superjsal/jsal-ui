-- Raid lockouts and long profession cooldowns, every character's, for the Journal's Characters tab.
--
-- Each is saved on its character as the moment it ends (the server's clock), so nothing ticks:
-- a lockout past its reset is no longer drawn and is dropped at the next login, and a cooldown
-- past its end reads ready. Only a character itself can change its own, so what it saw last
-- stays true while you play another.
--
-- Raids: the game's saved instances, read when it answers RequestRaidInfo. Which bosses were
-- killed it doesn't say, only how many. Cooldowns: the recipes and items in CooldownData, read at
-- login, while the profession window is open, and after a craft or an item's use. A read that
-- says nothing never clears a cooldown already saved: whether the game answers with the
-- profession window closed isn't known.
local _, ns = ...
local Compat = ns.Compat

local Lockouts = {}
ns.Lockouts = Lockouts

local MAX_RAIDS = 20      -- lockouts kept a character, at most
local recipes = {}        -- [recipe spell] = true, for a craft that starts a cooldown

-- What the last reads found, for /jsal lockouts: not saved.
local raidsRead           -- when the game last listed this character's raids
local last = {}           -- [cooldown's name] = { known, left, how, at }

local function Me()
    local J = ns.Journal
    local name = Compat.MyName()
    if not (J and name) then return nil end
    if not J.Characters()[name] then J.SaveCharacter() end
    return J.Characters()[name]
end

---------------------------------------------------------------------------
-- Reading.
---------------------------------------------------------------------------
-- Every saved instance the game lists for this character: { name, ends, bosses killed, bosses }.
function Lockouts.ReadRaids()
    local c = Me()
    if not c then return end
    local now = Compat.ServerTime()
    local list = {}
    for i = 1, GetNumSavedInstances() or 0 do
        local name, _, reset, _, locked, extended, _, _, _, _, total, done = GetSavedInstanceInfo(i)
        name, reset = Compat.Plains(name, reset)
        if type(name) == "string" and (locked or extended) and (tonumber(reset) or 0) > 0 and #list < MAX_RAIDS then
            list[#list + 1] = { name, now + math.floor(reset), tonumber(done) or 0, tonumber(total) or 0 }
        end
    end
    c.lockouts = list
    raidsRead = now
end

-- Seconds left on a recipe's cooldown, as the game says it; nil when it says nothing.
local function RecipeLeft(spell)
    local ui = C_TradeSkillUI
    if not (ui and ui.GetRecipeCooldown) then return nil end
    local ok, left = pcall(ui.GetRecipeCooldown, spell)
    return ok and type(left) == "number" and left or nil
end

-- Seconds left on an item's own cooldown; nil when it has none running.
local function ItemLeft(item)
    local get = (C_Container and C_Container.GetItemCooldown) or (C_Item and C_Item.GetItemCooldown)
    if not get then return nil end
    local ok, start, duration = pcall(get, item)
    if not (ok and type(start) == "number" and type(duration) == "number" and start > 0 and duration > 2) then return nil end
    return start + duration - GetTime()
end

-- Reads every long cooldown this character has. `how`: "login", "window" or "craft".
function Lockouts.ReadCooldowns(how)
    local c = Me()
    if not c then return end
    local now = Compat.ServerTime()
    c.cooldowns = type(c.cooldowns) == "table" and c.cooldowns or {}
    for _, cd in ipairs(ns.CooldownData or {}) do
        local known, left = false, nil
        if cd.item then
            known = Compat.ItemCount(cd.item, true) > 0
            left = ItemLeft(cd.item)
        else
            for _, spell in ipairs(cd.spells) do
                if Compat.KnowsRecipe(spell) then known = true end
                local l = RecipeLeft(spell)
                if l and l > 0 and (not left or l > left) then left = l end
            end
        end
        if left and left > 0 then
            c.cooldowns[cd.name] = now + math.floor(left + 0.5)
        elseif known and c.cooldowns[cd.name] == nil then
            -- Known, and nothing says it's waiting: ready.
            c.cooldowns[cd.name] = 0
        end
        last[cd.name] = { known = known or (left or 0) > 0, left = left, how = how, at = now }
    end
end

-- Drops every character's lockouts past their reset, and cooldowns no longer in the data.
function Lockouts.Prune(now)
    local J = ns.Journal
    if not J then return end
    now = now or Compat.ServerTime()
    local names = {}
    for _, cd in ipairs(ns.CooldownData or {}) do names[cd.name] = true end
    for _, c in pairs(J.Characters()) do
        if type(c.lockouts) == "table" then
            for i = #c.lockouts, 1, -1 do
                local l = c.lockouts[i]
                if type(l) ~= "table" or (tonumber(l[2]) or 0) <= now then table.remove(c.lockouts, i) end
            end
        end
        if type(c.cooldowns) == "table" then
            for name in pairs(c.cooldowns) do
                if not names[name] then c.cooldowns[name] = nil end
            end
        end
    end
end

---------------------------------------------------------------------------
-- What the Characters tab draws, worked out when it's drawn.
---------------------------------------------------------------------------
-- Time left, short: "2d 15h", "14h", "35m".
function Lockouts.Left(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    local d, h, m = math.floor(seconds / 86400), math.floor(seconds % 86400 / 3600), math.floor(seconds % 3600 / 60)
    if d > 0 then return h > 0 and ("%dd %dh"):format(d, h) or ("%dd"):format(d) end
    if h > 0 then return ("%dh"):format(h) end
    return ("%dm"):format(math.max(1, m))
end

-- The raids anyone is saved to, in DungeonData's order and then by name: each with when it
-- resets (the soonest), who is saved and how far (`saved`, most bosses first), and the
-- level-60 characters who are free of it (`free`). Then the known raids no one is saved to.
function Lockouts.Raids(characters, now)
    local by, order = {}, {}
    local sixties = {}
    for _, c in ipairs(characters) do
        if (c.level or 0) >= 60 then sixties[#sixties + 1] = c end
        for _, l in ipairs(type(c.lockouts) == "table" and c.lockouts or {}) do
            if type(l) == "table" and type(l[1]) == "string" and (tonumber(l[2]) or 0) > now then
                local r = by[l[1]]
                if not r then
                    r = { name = l[1], ends = l[2], saved = {}, free = {} }
                    by[l[1]], order[#order + 1] = r, r
                end
                r.ends = math.min(r.ends, l[2])
                r.saved[#r.saved + 1] = { c = c, done = tonumber(l[3]) or 0, of = tonumber(l[4]) or 0 }
            end
        end
    end
    local rank, nobody = {}, {}
    for i, d in ipairs(ns.DungeonData or {}) do
        if d.raid then
            rank[d.name] = i
            if not by[d.name] then nobody[#nobody + 1] = d.name end
        end
    end
    table.sort(order, function(a, b)
        local ra, rb = rank[a.name] or 1e9, rank[b.name] or 1e9
        if ra ~= rb then return ra < rb end
        return a.name < b.name
    end)
    for _, r in ipairs(order) do
        local saved = {}
        for _, s in ipairs(r.saved) do saved[s.c] = true end
        table.sort(r.saved, function(a, b)
            if a.done ~= b.done then return a.done > b.done end
            return (a.c.name or "") < (b.c.name or "")
        end)
        for _, c in ipairs(sixties) do
            if not saved[c] then r.free[#r.free + 1] = c end
        end
    end
    return order, nobody, #sixties
end

-- The cooldowns anyone has, in CooldownData's order: each with who has it (`rows`, the ready
-- first, then the soonest), and how many are ready in all.
function Lockouts.Cooldowns(characters, now)
    local out, ready = {}, 0
    for _, cd in ipairs(ns.CooldownData or {}) do
        local rows = {}
        for _, c in ipairs(characters) do
            local ends = type(c.cooldowns) == "table" and tonumber(c.cooldowns[cd.name])
            if ends then
                local left = math.max(0, ends - now)
                rows[#rows + 1] = { c = c, left = left }
                if left == 0 then ready = ready + 1 end
            end
        end
        if #rows > 0 then
            table.sort(rows, function(a, b)
                if a.left ~= b.left then return a.left < b.left end
                return (a.c.name or "") < (b.c.name or "")
            end)
            out[#out + 1] = { name = cd.name, rows = rows }
        end
    end
    return out, ready
end

---------------------------------------------------------------------------
-- Listening.
---------------------------------------------------------------------------
local frame = CreateFrame("Frame")
local pending

-- One read a second at most, a moment after what started it.
local function Soon(how)
    if pending then return end
    pending = true
    Compat.After(1, function()
        pending = nil
        if ns.Journal and ns.Journal.running then xpcall(Lockouts.ReadCooldowns, ns.Report, how) end
    end)
end

for _, cd in ipairs(ns.CooldownData or {}) do
    for _, spell in ipairs(cd.spells or {}) do recipes[spell] = true end
end
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "UPDATE_INSTANCE_INFO", "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE",
                         "UNIT_SPELLCAST_SUCCEEDED", "BAG_UPDATE_COOLDOWN" }) do
    pcall(frame.RegisterEvent, frame, event)
end
frame:SetScript("OnEvent", ns.Safe(ns.Journal, function(_, event, a, b, c)
    a, b, c = Compat.Plains(a, b, c)
    if not (ns.Journal and ns.Journal.running) then return end
    if event == "PLAYER_ENTERING_WORLD" then
        -- At login only; the game's own lists are ready a few seconds in.
        frame:UnregisterEvent("PLAYER_ENTERING_WORLD")
        Compat.After(6, function()
            if not ns.Journal.running then return end
            xpcall(Lockouts.Prune, ns.Report)
            xpcall(Lockouts.ReadCooldowns, ns.Report, "login")
            if RequestRaidInfo then RequestRaidInfo() end
        end)
    elseif event == "UPDATE_INSTANCE_INFO" then
        Lockouts.ReadRaids()
    elseif event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_LIST_UPDATE" then
        Soon("window")
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if a == "player" and c and recipes[c] then Soon("craft") end
    elseif event == "BAG_UPDATE_COOLDOWN" then
        Soon("craft")
    end
end))

-- /jsal lockouts: what was read for this character, and when, for a level-60 player to tell us.
ns.Command("lockouts", function()
    local now = Compat.ServerTime()
    local function Ago(t)
        if not t then return "not yet" end
        return now - t < 60 and "just now" or (Lockouts.Left(now - t) .. " ago")
    end
    local c = Me()
    local saved = c and type(c.lockouts) == "table" and #c.lockouts or 0
    ns.Print(("Raids: the game's list read %s, %d saved."):format(Ago(raidsRead), saved))
    for _, cd in ipairs(ns.CooldownData or {}) do
        local l = last[cd.name]
        local ends = c and type(c.cooldowns) == "table" and c.cooldowns[cd.name]
        local said = not l and "not read yet"
            or (l.left and l.left > 0) and ("the game said %s left"):format(Lockouts.Left(l.left))
            or "the game said nothing"
        ns.Print(("  %s: %s, %s (%s, %s)%s"):format(cd.name, l and (l.known and "known" or "not known") or "?", said,
            l and l.how or "-", l and Ago(l.at) or "-",
            ends and ("; saved: " .. (ends > now and (Lockouts.Left(ends - now) .. " left") or "ready")) or "; nothing saved"))
    end
end)
