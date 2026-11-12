-- The companion's life, with no drawing in it: four needs that fall with
-- time, sleep, droppings, a mild sickness, a mood worked out from all of
-- that, the care you give from supplies your play earns, and growing up.
-- Time is passed in (seconds), so the same rules run in the game and in
-- the tests.
local _, ns = ...

local Rules = {}
ns.PetRules = Rules

local HOUR = 3600
Rules.NEEDS = { "hunger", "energy", "fun", "clean" }
Rules.SUPPLIES = { "meal", "treat", "toy", "soap", "medicine" }
Rules.AWAY = 12 * HOUR          -- needs stop falling after this long away
-- Good hours to reach each grown form: about two well-kept days, then a
-- well-kept week. Time away counts for at most half a day at a go.
Rules.GROWN, Rules.FULL = 48, 168
Rules.MAX_DROPPINGS = 4
local TICK = 600                -- time moves on in ten-minute steps
local DIGEST = 45 * 60          -- a meal turns up in the pen this much later
local SICK_FOR = 8 * HOUR       -- sickness passes by itself after this
local PATS_AN_HOUR = 5

-- What each need does in an hour, awake and asleep.
-- Hunger and fun fall slowly enough that half a day away leaves it peckish
-- and a bit bored, never empty.
local AWAKE = { hunger = -4, energy = -6, fun = -3 }
local ASLEEP = { hunger = -2, energy = 25, fun = -1 }

local function Clamp(v) return math.max(0, math.min(100, v)) end

-- The kinds of creature: each one's three forms by name, the pictures
-- they're drawn with, and what a hatchling is called until it's named.
Rules.SPECIES = {
    briarboar = { forms = { "Briarboar", "Thornhog", "Brambletusk" },
                  sprites = { "briarboar", "thornhog", "brambletusk" }, name = "Bramble" },
    wispkin = { forms = { "Wispkin", "Gloamtail", "Wispjester" },
                sprites = { "wispkin", "gloamtail", "wispjester" }, name = "Wisp" },
    scrapwing = { forms = { "Scrapwing", "Jabdrake", "Flarechamp" },
                  sprites = { "scrapwing", "jabdrake", "flarechamp" }, name = "Cinder" },
    stormcub = { forms = { "Stormcub", "Thundermane", "Tempestmane" },
                 sprites = { "stormcub", "thundermane", "tempestmane" }, name = "Bolt" },
    capling = { forms = { "Capling", "Lanternshell", "Bloomsage" },
                sprites = { "capling", "lanternshell", "bloomsage" }, name = "Morel" },
}
-- The eggs your play can turn up, and what hatches from each. `from` is
-- the thing you do that can turn it up, and `chance` how often it does:
-- a quest handed in, coming back from being a ghost, a new level, a
-- flight, and arriving in another zone.
Rules.EGGS = {
    mossy = { name = "Mossy egg", species = "briarboar", from = "quest", chance = 0.03,
              hint = "It smells of rain and bramble." },
    ghostly = { name = "Ghostly egg", species = "wispkin", from = "ghost", chance = 0.15,
                hint = "It's cold, and lighter than it looks." },
    ember = { name = "Ember egg", species = "scrapwing", from = "level", chance = 0.3,
              hint = "It's warm to the touch, and something inside is tapping." },
    storm = { name = "Storm egg", species = "stormcub", from = "flight", chance = 0.06,
              hint = "It hums, and lifts the hair on your arm." },
    toadstool = { name = "Toadstool egg", species = "capling", from = "zone", chance = 0.08,
                  hint = "Something inside it is humming a tune." },
}
-- The three a new player chooses between. The other two are only ever found.
Rules.STARTERS = { "mossy", "ember", "toadstool" }
-- The kinds in the order an album shows them.
Rules.KINDS = { "briarboar", "wispkin", "scrapwing", "stormcub", "capling" }

-- Whether play can turn up an egg for this companion yet: only once it's
-- fully grown, when an egg is something it can make way for.
function Rules.CanFind(s)
    return not s.unchosen and s.form >= 3
end

-- Gives it the name you typed, tidied: two to sixteen letters, with spaces,
-- hyphens and apostrophes allowed inside. True and what to say, or false
-- and why not.
function Rules.Rename(s, text)
    text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
    if #text < 2 then return false, "A name needs at least two letters." end
    if #text > 16 then return false, "That's too long for a name: sixteen letters at most." end
    if not text:find("^[%a\128-\255][%a\128-\255 '%-]*$") then
        return false, "A name is letters, with spaces, hyphens or apostrophes inside."
    end
    if text == s.name then return false, "That's its name already." end
    local old = s.name
    s.name = text
    return true, ("%s is called %s now."):format(old, text)
end
Rules.MAX_EGGS = 3

-- Grubby enough to show, and to want a bath.
function Rules.Dirty(s)
    return s.clean < 35
end

-- A companion's kind; one saved before there were kinds is a Briarboar.
function Rules.Species(s)
    return Rules.SPECIES[s.species or "briarboar"] or Rules.SPECIES.briarboar
end

-- A newly hatched companion, with a few supplies to start on.
function Rules.New(now, name, species)
    species = Rules.SPECIES[species] and species or "briarboar"
    return {
        species = species,
        name = name or Rules.SPECIES[species].name, born = now, stamp = now,
        hunger = 70, energy = 80, fun = 70, clean = 100,
        asleep = false, sick = false, droppings = 0, due = {}, sweets = 0, pats = {},
        good = 0, form = 1,
        supplies = { meal = 3, treat = 1, toy = 1, soap = 1, medicine = 1 },
    }
end

-- Its mood, from how it is: a word for the code and one to show.
function Rules.Mood(s)
    if s.sick then return "poorly", "Poorly" end
    if s.asleep then return "asleep", "Asleep" end
    local low, sum = 100, 0
    for _, need in ipairs(Rules.NEEDS) do
        low, sum = math.min(low, s[need]), sum + s[need]
    end
    if low < 20 then return "grumpy", "Grumpy" end
    local average = sum / #Rules.NEEDS
    if average >= 70 then return "happy", "Happy" end
    if average >= 45 then return "content", "Content" end
    return "bored", "Bored"
end

-- The one thing it most wants from you right now: a word for the code, a
-- line to show and a line under it. Nil when it's fine, and while it
-- sleeps: a sleeping pet wants leaving alone.
function Rules.Wants(s)
    if s.sick then
        return "poorly", s.name .. " is poorly", "Medicine mends it at once; a few hours' rest does too"
    end
    if s.asleep then return nil end
    if s.droppings > 0 then
        return "scoop", s.name .. "'s pen needs scooping", "Left lying, it slowly dirties the pen"
    end
    if s.hunger < 35 then
        local meals = s.supplies.meal or 0
        return "hungry", s.name .. " is hungry",
            meals > 0 and ("You have %d meal%s"):format(meals, meals == 1 and "" or "s") or "No meals left: hand in a quest for one"
    end
    if Rules.Dirty(s) then return "dirty", s.name .. " needs a bath", "A bath makes it spotless" end
    if s.fun < 25 then return "bored", s.name .. " is bored", "A pat costs nothing" end
    return nil
end

-- The form it has grown into: 1 hatchling, 2 grown, 3 fully grown.
function Rules.FormFor(good)
    return good >= Rules.FULL and 3 or good >= Rules.GROWN and 2 or 1
end

-- Eating a meal: it fills up, cheers up a little, and a dropping follows
-- later. One dropping per sitting, however many meals it had.
local function Eat(s, now)
    s.hunger, s.fun = Clamp(s.hunger + 40), Clamp(s.fun + 5)
    if not s.due[1] then s.due[1] = now + DIGEST end
end

-- A bowl filled while it slept is eaten when it wakes.
function Rules.Breakfast(s, now)
    if not s.bowl then return end
    s.bowl = nil
    Eat(s, now)
end

local function Step(s, t, dt)
    local hours = dt / HOUR
    local rates = s.asleep and ASLEEP or AWAKE
    s.hunger = Clamp(s.hunger + rates.hunger * hours)
    s.energy = Clamp(s.energy + rates.energy * hours)
    s.fun = Clamp(s.fun + rates.fun * hours * (s.sick and 2 or 1))
    -- Only droppings dirty the pen, and slowly: left for half a day, one costs
    -- about what scooping it gives back. With none, it grooms itself clean.
    s.clean = Clamp(s.clean + (s.droppings > 0 and -1.5 * s.droppings or 2) * hours)
    s.sweets = math.max(0, s.sweets - hours / 4)
    -- A meal from a while ago arrives in the pen.
    while s.due[1] and s.due[1] <= t do
        table.remove(s.due, 1)
        s.droppings = math.min(Rules.MAX_DROPPINGS, s.droppings + 1)
    end
    -- Worn out, it sleeps by itself, before tiredness can sour its mood;
    -- rested, it wakes.
    if not s.asleep and s.energy <= 20 then
        s.asleep = true
    elseif s.asleep and s.energy >= 100 then
        s.asleep = false
        Rules.Breakfast(s, t)
    end
    -- A filthy pen makes it poorly; it passes with time if not with medicine.
    if not s.sick and s.clean <= 15 then
        s.sick, s.sickSince = true, t
    elseif s.sick and t - (s.sickSince or t) >= SICK_FOR then
        s.sick, s.sickSince = false, nil
        s.clean = math.max(s.clean, 30)
    end
    local mood = Rules.Mood(s)
    if not s.sick and (mood == "happy" or mood == "content" or mood == "asleep") then
        s.good = s.good + hours
    end
end

-- Brings it up to now. However long you were away, only so much time
-- passes for it, so a week off never comes back to a ruined pet.
function Rules.Advance(s, now)
    local span = math.min(math.max(0, now - s.stamp), Rules.AWAY)
    local t = now - span
    while span > 0 do
        local dt = math.min(TICK, span)
        t, span = t + dt, span - dt
        Step(s, t, dt)
    end
    s.stamp = now
    local form = Rules.FormFor(s.good)
    if form > s.form then
        s.form, s.grew = form, true
    end
    return s
end

---------------------------------------------------------------------------
-- The long run: a bond that grows with every day you look after it, and
-- one small wish a day. Neither is ever lost, and skipping a day costs
-- nothing.
---------------------------------------------------------------------------
local DAY = 86400
-- Each level of the bond, and the points it starts at. With a wish granted
-- and a day's care, a day is worth about six.
Rules.BONDS = {
    { 0, "Wary" }, { 6, "Curious" }, { 18, "Friendly" }, { 40, "Fond" }, { 75, "Devoted" }, { 130, "Inseparable" },
}
-- What it may wish for: something you do in your own play, or with it.
-- `need` is how many times; `text` finishes "Today it ...".
Rules.WISHES = {
    { kind = "quest", need = 1, text = "wants to watch you hand in a quest" },
    { kind = "flight", need = 1, text = "wants to hear about a flight" },
    { kind = "zone", need = 1, text = "wants you to go somewhere else for a while" },
    { kind = "pat", need = 3, text = "wants a proper fuss: three pats" },
    { kind = "treat", need = 1, text = "fancies a treat" },
    { kind = "play", need = 1, text = "wants a game with a toy" },
}
local WISH = {}
for _, wish in ipairs(Rules.WISHES) do WISH[wish.kind] = wish end

-- The bond's level, its name, the points so far, and the points the next
-- level starts at (nil at the last).
function Rules.Bond(s)
    local points, level = s.bond or 0, 1
    for i, step in ipairs(Rules.BONDS) do
        if points >= step[1] then level = i end
    end
    local next = Rules.BONDS[level + 1]
    return level, Rules.BONDS[level][2], points, next and next[1] or nil
end

local function Closer(s, points)
    local before = Rules.Bond(s)
    s.bond = (s.bond or 0) + points
    local after, name = Rules.Bond(s)
    -- A new level is said once, by whoever shows the pet next.
    if after > before then s.bonded = name end
end

-- The first feed, pat and scoop of each day bring you a little closer.
local function Cared(s, now, what)
    local day = math.floor(now / DAY)
    if type(s.cared) ~= "table" or s.cared.day ~= day then s.cared = { day = day } end
    if s.cared[what] then return end
    s.cared[what] = true
    Closer(s, 1)
end

-- Today's wish: the same one all day, a different one tomorrow. Its kind,
-- how far along it is, and whether it's been granted.
function Rules.Wish(s, now)
    local day = math.floor(now / DAY)
    if type(s.wish) ~= "table" or s.wish.day ~= day or not WISH[s.wish.kind] then
        local pick = (day * 7 + math.floor((s.born or 0) / 60)) % #Rules.WISHES + 1
        s.wish = { day = day, kind = Rules.WISHES[pick].kind, count = 0 }
    end
    return s.wish, WISH[s.wish.kind]
end

-- Something happened that it might have wished for. True the moment the
-- wish is granted: it's delighted, and you're closer for it.
function Rules.Did(s, kind, now)
    local wish, what = Rules.Wish(s, now)
    if wish.done or wish.kind ~= kind then return false end
    wish.count = wish.count + 1
    if wish.count < what.need then return false end
    wish.done = true
    s.fun = Clamp(s.fun + 20)
    Closer(s, 3)
    return true
end

local function Use(s, supply)
    if (s.supplies[supply] or 0) < 1 then return false end
    s.supplies[supply] = s.supplies[supply] - 1
    return true
end

local WANT = {
    meal = "No meals left. Quests you hand in bring more.",
    treat = "No treats left. A new level brings more.",
    toy = "No toys left. Flights bring more.",
    soap = "No soap left. A new level brings more.",
    medicine = "No medicine left. A new level brings more.",
}

-- Each kind of care: true and what happened, or false and why not.
function Rules.Feed(s, now)
    Rules.Advance(s, now)
    if s.asleep then
        -- No need to wake it: the bowl waits.
        if s.bowl then return false, "The bowl is full for when it wakes." end
        if not Use(s, "meal") then return false, WANT.meal end
        s.bowl = true
        -- Filling its bowl is looking after it, awake or not.
        Cared(s, now, "feed")
        return true, "You fill the bowl for when it wakes."
    end
    if s.hunger >= 95 then return false, "It isn't hungry." end
    if not Use(s, "meal") then return false, WANT.meal end
    Eat(s, now)
    Cared(s, now, "feed")
    return true, "It cleans the bowl."
end

function Rules.Treat(s, now)
    Rules.Advance(s, now)
    if s.asleep then return false, "It's asleep." end
    if not Use(s, "treat") then return false, WANT.treat end
    s.hunger, s.fun = Clamp(s.hunger + 10), Clamp(s.fun + 15)
    s.sweets = s.sweets + 1
    Rules.Did(s, "treat", now)
    if s.sweets > 3 and not s.sick then
        s.sick, s.sickSince = true, now
        return true, "One treat too many: it feels poorly."
    end
    return true, "It loves that."
end

function Rules.Play(s, now)
    Rules.Advance(s, now)
    if s.asleep then return false, "It's asleep." end
    if s.sick then return false, "It's too poorly to play." end
    if s.energy < 20 then return false, "It's too tired to play." end
    if not Use(s, "toy") then return false, WANT.toy end
    s.fun, s.energy = Clamp(s.fun + 35), Clamp(s.energy - 10)
    Rules.Did(s, "play", now)
    return true, "It chases the toy round the pen."
end

function Rules.Scoop(s, now)
    Rules.Advance(s, now)
    if s.droppings < 1 then return false, "Nothing to scoop." end
    s.droppings = s.droppings - 1
    s.clean = Clamp(s.clean + 15)
    Cared(s, now, "scoop")
    return true, "Scooped."
end

function Rules.Bath(s, now)
    Rules.Advance(s, now)
    if s.asleep then return false, "It's asleep." end
    if s.clean >= 95 then return false, "It's clean already." end
    if not Use(s, "soap") then return false, WANT.soap end
    s.clean = 100
    return true, "Clean again."
end

function Rules.Medicine(s, now)
    Rules.Advance(s, now)
    if not s.sick then return false, "It isn't poorly." end
    if not Use(s, "medicine") then return false, WANT.medicine end
    s.sick, s.sickSince = false, nil
    s.clean = math.max(s.clean, 30)
    return true, "It perks up."
end

-- Lights out, or lights on. Woken before it's rested, it sulks a little.
function Rules.Lights(s, now)
    Rules.Advance(s, now)
    if s.asleep then
        s.asleep = false
        Rules.Breakfast(s, now)
        if s.energy < 40 then
            s.fun = Clamp(s.fun - 5)
            return true, "Woken too soon, it sulks."
        end
        return true, "It wakes up."
    end
    if s.energy >= 90 then return false, "It isn't sleepy." end
    s.asleep = true
    return true, "Lights out."
end

-- A pat: a lift that costs nothing, a few times an hour, so a pet with no
-- toys can still be kept cheerful.
function Rules.Pat(s, now)
    Rules.Advance(s, now)
    if s.asleep then return false, "It's asleep." end
    local recent = {}
    for _, at in ipairs(s.pats) do
        if now - at < HOUR then recent[#recent + 1] = at end
    end
    s.pats = recent
    if #recent >= PATS_AN_HOUR then return false, "It's had enough fuss for now." end
    recent[#recent + 1] = now
    s.fun = Clamp(s.fun + 5)
    Cared(s, now, "pat")
    Rules.Did(s, "pat", now)
    return true, "It leans into your hand."
end

---------------------------------------------------------------------------
-- The paddock: a fully grown companion can be settled there, where it
-- stays yours and needs no more care, and an egg hatched in its place. It
-- takes an egg to settle one, so you're never without a companion.
---------------------------------------------------------------------------
function Rules.CanSettle(s, eggs)
    if s.form < 3 then return false, "It isn't fully grown yet." end
    if #(eggs or {}) < 1 then return false, "Find an egg first, so you're never without a companion." end
    return true
end

-- What the paddock remembers of a companion: its kind, name, how long you
-- had it and how close you were.
function Rules.Settled(s, now)
    local _, bond = Rules.Bond(s)
    return {
        species = s.species or "briarboar", name = s.name, form = s.form,
        born = s.born, settled = now, days = math.floor(math.max(0, now - s.born) / DAY) + 1, bond = bond,
    }
end

-- Settles the companion and hatches the egg at that place in the list:
-- the record for the paddock and the new hatchling, which keeps what was in
-- the cupboard. Nil and why when it can't be done.
function Rules.Succeed(s, eggs, index, now)
    local ok, why = Rules.CanSettle(s, eggs)
    if not ok then return nil, why end
    local egg = eggs[index]
    local kind = egg and Rules.EGGS[egg.kind]
    if not kind then return nil, "That egg isn't there." end
    table.remove(eggs, index)
    local young = Rules.New(now, nil, kind.species)
    for supply, count in pairs(s.supplies) do
        young.supplies[supply] = math.max(young.supplies[supply] or 0, count)
    end
    return Rules.Settled(s, now), young
end

-- The kind of egg that doing `source` turns up this time, or nil. `roll`
-- is a number from 0 up to 1: the luck of it.
function Rules.EggFrom(source, roll)
    for kind, egg in pairs(Rules.EGGS) do
        if egg.from == source and roll < egg.chance then return kind end
    end
    return nil
end

-- A found egg joins the others, if there's room. True when it's kept.
function Rules.FindEgg(eggs, kind, from, now)
    if not Rules.EGGS[kind] or #eggs >= Rules.MAX_EGGS then return false end
    eggs[#eggs + 1] = { kind = kind, from = from, found = now }
    return true
end

-- Supplies your play brings in.
function Rules.Earn(s, supply, count)
    s.supplies[supply] = math.min(20, (s.supplies[supply] or 0) + (count or 1))
end
