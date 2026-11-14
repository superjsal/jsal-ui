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
    boltusk = { forms = { "Boltusk", "Rumbletrunk", "Warmammoth" },
                sprites = { "boltusk", "rumbletrunk", "warmammoth" }, name = "Rivet" },
    gemlet = { forms = { "Gemlet", "Miragehoof", "Sandseer" },
               sprites = { "gemlet", "miragehoof", "sandseer" }, name = "Mirage" },
    pebblebill = { forms = { "Pebblebill", "Cobbleback", "Rockwarden" },
                   sprites = { "pebblebill", "cobbleback", "rockwarden" }, name = "Flint" },
    snowlet = { forms = { "Snowlet", "Frostmantle", "Auroracrown" },
                sprites = { "snowlet", "frostmantle", "auroracrown" }, name = "Nova" },
    starwhelp = { forms = { "Starwhelp", "Moondrake", "Eclipselord" },
                  sprites = { "starwhelp", "moondrake", "eclipselord" }, name = "Umbra" },
}
-- The eggs your play can turn up, and what hatches from each. `from` is
-- the thing you do that can turn it up, and `chance` how often it does:
-- a quest handed in, coming back from being a ghost, a new level, a
-- flight, arriving in another zone, a fight you come out of alive, a new
-- spell learned, a fish caught, and Onyxia or Ragnaros brought down. Fights and fish
-- come far oftener than the rest, so that chance is far smaller: about one
-- egg in two hundred fights. Bosses are kept for rarer eggs to come.
Rules.EGGS = {
    mossy = { name = "Mossy egg", species = "briarboar", from = "quest", chance = 0.03,
              hint = "It smells of rain and bramble." },
    ghostly = { name = "Ghostly egg", species = "wispkin", from = "ghost", chance = 0.1,
                hint = "It's cold, and lighter than it looks." },
    ember = { name = "Ember egg", species = "scrapwing", from = "level", chance = 0.1,
              hint = "It's warm to the touch, and something inside is tapping." },
    storm = { name = "Storm egg", species = "stormcub", from = "flight", chance = 0.06,
              hint = "It hums, and lifts the hair on your arm." },
    toadstool = { name = "Toadstool egg", species = "capling", from = "zone", chance = 0.08,
                  hint = "Something inside it is humming a tune." },
    steel = { name = "Steel egg", species = "boltusk", from = "fight", chance = 0.005,
              hint = "It's heavy, riveted shut, and now and then it clanks." },
    crystal = { name = "Crystal egg", species = "gemlet", from = "learn", chance = 0.05,
                hint = "It hums in your head before you hear it." },
    riverstone = { name = "River Stone egg", species = "pebblebill", from = "fishing", chance = 0.01,
                   hint = "It's smooth and cold, like a stone from the bottom of a stream." },
    -- The rare one: only Onyxia's hoard holds it, one kill in ten (John, 12 Nov
    -- 2026: "this egg will have a chance to drop when onyxia is killed by you",
    -- then "Yes, one in ten"). Never one a new player is offered.
    aurora = { name = "Aurora egg", species = "snowlet", from = "onyxia", chance = 0.1,
               hint = "It frosts your fingers, and lights shimmer under its shell." },
    -- The legendary one: only Ragnaros leaves it, one kill in ten (John, 13 Nov
    -- 2026: "a legendary dark type dragon", and of the boss to drop it,
    -- "Ragnaros"). Never one a new player is offered.
    eclipse = { name = "Eclipse egg", species = "starwhelp", from = "ragnaros", chance = 0.1,
                hint = "It's darker than its own shadow, with a ring of gold light on it." },
}
-- The bosses whose fall can leave an egg, by the game's own number for the
-- fight (the same in every language), and the `from` their egg names.
Rules.BOSSES = { [1084] = "onyxia", [672] = "ragnaros" }
-- A new player chooses between three eggs, any three of all there are
-- (John, 12 Nov 2026: "lets have all the eggs (3 max) be able to be onboarded
-- randomly"). Before that it was always the first three of this list.
Rules.STARTERS = { "mossy", "ember", "toadstool", "ghostly", "storm", "steel", "crystal", "riverstone" }
Rules.OFFERED = 3
-- Three of them, no two alike. `roll(a, b)` is a whole number from a to b,
-- as math.random gives.
function Rules.Offer(roll)
    local pool, offer = {}, {}
    for i, key in ipairs(Rules.STARTERS) do pool[i] = key end
    for i = 1, Rules.OFFERED do
        local j = math.max(i, math.min(#pool, roll(i, #pool)))
        pool[i], pool[j] = pool[j], pool[i]
        offer[i] = pool[i]
    end
    return offer
end
-- The kinds in the order an album shows them.
Rules.KINDS = { "briarboar", "wispkin", "scrapwing", "stormcub", "capling", "boltusk", "gemlet", "pebblebill", "snowlet", "starwhelp" }

-- Whether play can turn up an egg for this companion yet: only once it's
-- fully grown, when an egg is something it can make way for.
-- (A boss's egg is the exception: it's too rare to miss because yours is
-- still growing. `source` is what you did, as an egg's `from` names it.)
function Rules.CanFind(s, source)
    return not s.unchosen and (s.form >= 3 or Rules.Rare(source))
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
-- A boss's egg is kept aside when those three are held: this many at most.
Rules.MAX_KEPT = 3

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
    if s.grewFrom then
        return "grow", s.name .. " is ready to grow", "Open its pen and press Grow to watch"
    end
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
        -- An egg in the nest warms on the same clock, faster with a closer bond.
        if s.nest then
            s.nest.warm = math.min(Rules.TEND, (s.nest.warm or 0) + hours * Rules.TendSpeed(s))
        end
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
        -- The form it was, kept until you've pressed Grow in its pen and
        -- seen it grow (the earliest, if it was ready twice over): till then
        -- it's drawn and named as it was, and it's "ready to grow".
        s.grewFrom = s.grewFrom or s.form
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
    { kind = "fetch", need = 3, text = "wants a proper game of fetch: three throws" },
    { kind = "catch", need = 1, text = "wants to catch a treat out of the air" },
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

-- Company: what you do in your own play while it's on your screen (a quest
-- handed in, a flight, a new level, another zone). The fifth such thing in
-- a day brings you a point closer, once; and each has a small chance that
-- it digs up a treat or a toy, twice a day at most. Leaving it in its
-- window costs nothing: this only ever adds. `roll` is the luck, 0 up to 1.
-- Returns whether you grew closer, and what it found (or nil).
Rules.COMPANY = { deeds = 5, finds = 2, chance = 0.06 }
function Rules.Company(s, now, roll)
    local day = math.floor(now / DAY)
    if type(s.company) ~= "table" or s.company.day ~= day then s.company = { day = day, deeds = 0, finds = 0 } end
    local c, rule = s.company, Rules.COMPANY
    c.deeds = c.deeds + 1
    local closer = c.deeds == rule.deeds
    if closer then Closer(s, 1) end
    local found
    if c.finds < rule.finds and roll < rule.chance then
        c.finds = c.finds + 1
        found = roll < rule.chance / 2 and "treat" or "toy"
        Rules.Earn(s, found, 1)
    end
    return closer, found
end

-- More supplies from your play: a fish caught or a point of Cooking is a
-- treat, a point of First Aid is medicine. So that it's a pleasant extra
-- and not something to farm: three treats and one medicine a day this way.
-- Returns what was earned, or nil.
Rules.EXTRA = { fishing = { "treat", 3 }, cooking = { "treat", 3 }, firstaid = { "medicine", 1 } }
function Rules.Extra(s, kind, now)
    local rule = Rules.EXTRA[kind]
    if not rule then return nil end
    local day = math.floor(now / DAY)
    if type(s.extra) ~= "table" or s.extra.day ~= day then s.extra = { day = day } end
    local supply, most = rule[1], rule[2]
    if (s.extra[supply] or 0) >= most then return nil end
    s.extra[supply] = (s.extra[supply] or 0) + 1
    Rules.Earn(s, supply, 1)
    return supply
end

-- How today's company stands, for its page: things done so far, and how many it takes.
function Rules.CompanyToday(s, now)
    local c = s.company
    local today = type(c) == "table" and c.day == math.floor(now / DAY)
    return today and c.deeds or 0, Rules.COMPANY.deeds
end

local function Use(s, supply)
    if (s.supplies[supply] or 0) < 1 then return false end
    s.supplies[supply] = s.supplies[supply] - 1
    return true
end

local WANT = {
    meal = "No meals left. Quests you hand in bring more.",
    treat = "No treats left. Fishing, Cooking and a new level bring more.",
    toy = "No toys left. Flights bring more.",
    soap = "No soap left. A new level brings more.",
    medicine = "No medicine left. First Aid and a new level bring more.",
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

-- Another throw of a ball it has just brought back: no toy is used, it's a
-- little more fun and a little more tiring. The pen allows a few of these.
function Rules.Fetch(s, now)
    Rules.Advance(s, now)
    if s.asleep then return false, "It's asleep." end
    if s.sick or s.energy < 20 then return false, "That's enough for now: it lies down by the ball." end
    s.fun, s.energy = Clamp(s.fun + 5), Clamp(s.energy - 3)
    return true, "Off it goes again."
end

-- The pointer, wiggled in its pen, is something to chase, and caught is a
-- little fun: the first few pounces of a day, so it's a game and not a chore.
Rules.POUNCES = 3
function Rules.Pounce(s, now)
    Rules.Advance(s, now)
    local day = math.floor(now / DAY)
    if type(s.pounces) ~= "table" or s.pounces.day ~= day then s.pounces = { day = day, count = 0 } end
    if s.pounces.count < Rules.POUNCES then
        s.pounces.count = s.pounces.count + 1
        s.fun = Clamp(s.fun + 3)
    end
    return true, "It pounces on the pointer!"
end

-- Tricks, which come with the bond: one more at each level after the first.
-- `anim` is the animation that is the trick, `say` what the page says.
Rules.TRICKS = {
    { level = 2, anim = "sit", say = "Sit! Down it goes." },
    { level = 3, anim = "jump", say = "Up! A great hop." },
    { level = 4, anim = "dig", say = "Dig! It sets to." },
    { level = 5, anim = "cheer", say = "Dance! It needs no telling twice." },
    { level = 6, anim = "special", say = "Show them! And it does." },
}
-- The tricks it knows now, and the bond level the next comes at (or nil).
function Rules.Tricks(s)
    local level, known, next = Rules.Bond(s), {}, nil
    for _, trick in ipairs(Rules.TRICKS) do
        if level >= trick.level then
            known[#known + 1] = trick
        elseif not next then
            next = trick.level
        end
    end
    return known, next
end
-- Asked for a trick: true, what to say and the animation; or false and why
-- not. `roll(a, b)` picks among the ones it knows. Nothing is gained or
-- spent: a trick is for the pleasure of it.
function Rules.Trick(s, now, roll)
    Rules.Advance(s, now)
    if s.asleep then return false, "It's asleep." end
    if s.sick then return false, "It's too poorly for tricks." end
    local known, next = Rules.Tricks(s)
    if #known == 0 then
        return false, ("It doesn't know any tricks yet. The first comes when you're %s."):format(Rules.BONDS[next][2])
    end
    local trick = known[math.max(1, math.min(#known, roll(1, #known)))]
    return true, trick.say, trick.anim
end

-- A treat tossed up and caught, not set down: the same treat (Rules.Treat
-- has already been paid), and a little more fun.
function Rules.Caught(s, now)
    Rules.Advance(s, now)
    s.fun = Clamp(s.fun + 5)
    return true, "It jumps and catches it!"
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
    if s.grewFrom then return false, "It's ready to grow: press Grow in its pen first." end
    if #(eggs or {}) < 1 then return false, "Find an egg first, so you're never without a pal." end
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

---------------------------------------------------------------------------
-- The nest. A fully grown companion looks after one egg: it's put in a
-- nest in the pen (s.nest: the egg, and `warm`, the good hours it has had),
-- where it warms while the companion is well, on the clock growing used,
-- and faster with a closer bond. Warm enough, it's ready to hatch, and waits
-- for you as long as you like. When it hatches the companion settles in the
-- paddock, and comes back to the pen now and then to see the one it
-- looked after. (John, 16 Nov 2026: "i think we should add functionality to
-- the egg itself, like your pal taking care of the egg until it is ready to
-- hatch", and "the caretaker pal should show up in the pen every once in a
-- while".)
---------------------------------------------------------------------------
Rules.TEND = 24             -- good hours to warm an egg, at the first level of the bond
Rules.KEEPSAKE = 6          -- the most of the old bond a hatchling starts with: its second level
Rules.VISITS = 2            -- how often a day the one that tended its egg comes by
Rules.VISIT_FOR = 4 * 60    -- and for how long
Rules.VISIT_GAP = 2 * HOUR  -- with this long between, and after hatching

function Rules.CanTend(s)
    if s.form < 3 then return false, "It isn't fully grown yet." end
    if s.grewFrom then return false, "It's ready to grow: press Grow in its pen first." end
    return true
end

-- How fast it warms an egg: half as fast again at the closest bond.
function Rules.TendSpeed(s)
    local level = Rules.Bond(s)
    return 1 + (level - 1) * 0.1
end

-- Puts the egg at that place in the list into the nest. One already there
-- goes back to the list in its place, and the warming starts again. Nil and
-- why when it can't be done.
function Rules.Tend(s, eggs, index, now)
    local ok, why = Rules.CanTend(s)
    if not ok then return nil, why end
    local egg = eggs[index]
    if not (egg and Rules.EGGS[egg.kind]) then return nil, "That egg isn't there." end
    local old = s.nest
    if old then
        eggs[index] = { kind = old.kind, from = old.from, found = old.found }
    else
        table.remove(eggs, index)
    end
    s.nest = { kind = egg.kind, from = egg.from, found = egg.found, warm = 0, since = now }
    return true
end

-- Takes the egg out of the nest, back to the front of the list. False and
-- why with no egg there, or no room for it.
function Rules.Untend(s, eggs)
    local nest = s.nest
    if not nest then return false, "There's no egg in the nest." end
    if #eggs >= Rules.MAX_EGGS then return false, "Your hands are full: let an egg go first." end
    table.insert(eggs, 1, { kind = nest.kind, from = nest.from, found = nest.found })
    s.nest = nil
    return true
end

-- The egg in the nest: its kind (of Rules.EGGS), the hours of good care it
-- still needs at the bond you have, whether it's ready to hatch, and how far
-- along it is from 0 to 1. Nil with no egg there.
function Rules.Tending(s)
    local nest = s.nest
    local kind = type(nest) == "table" and Rules.EGGS[nest.kind]
    if not kind then return nil end
    local warm = math.min(Rules.TEND, nest.warm or 0)
    return kind, (Rules.TEND - warm) / Rules.TendSpeed(s), warm >= Rules.TEND, warm / Rules.TEND
end

-- The egg in the nest hatches, and the companion that tended it settles in
-- the paddock: the record for the paddock, and the hatchling. It keeps the
-- cupboard, starts with a little of the old bond (never more than there
-- was), and remembers who looked after its egg. Nil and why when it can't be
-- done.
function Rules.HatchNest(s, now)
    local ok, why = Rules.CanTend(s)
    if not ok then return nil, why end
    local kind, _, ready = Rules.Tending(s)
    if not kind then return nil, "There's no egg in the nest." end
    if not ready then return nil, "The egg isn't ready to hatch yet." end
    local young = Rules.New(now, nil, kind.species)
    for supply, count in pairs(s.supplies) do
        young.supplies[supply] = math.max(young.supplies[supply] or 0, count)
    end
    young.bond = math.min(s.bond or 0, Rules.KEEPSAKE)
    young.caretaker = { name = s.name, species = s.species or "briarboar", form = s.form }
    -- When it hatched in a nest: the nest stays in the pen as its bed
    -- while it's a hatchling (Rules.Bed).
    young.nested = now
    s.nest = nil
    return Rules.Settled(s, now), young
end

-- The nest it hatched in is a hatchling's bed: it sleeps and naps there
-- for as long as it's a hatchling, and that includes one ready to grow
-- that hasn't yet. (John, 16 Nov 2026, asked what to do about the empty
-- nest: "Bed version sounds great good idea".)
function Rules.Bed(s)
    return s.nested ~= nil and (s.grewFrom or s.form) == 1
end

-- Grown, it has outgrown its nest, which goes: true the once.
function Rules.Outgrown(s)
    if s.nested ~= nil and (s.grewFrom or s.form) > 1 then
        s.nested = nil
        return true
    end
    return false
end

-- Whether the one that tended its egg is visiting, asked whenever the pen
-- is looked at. A visit starts then: the first time in a day, and again
-- once a couple of hours have gone by, twice a day at most. It lasts a few
-- minutes and cheers the young one up a little. None while it sleeps or is
-- poorly, nor in its first hours. The second answer is true the moment a
-- visit starts.
function Rules.Visit(s, now)
    if type(s.caretaker) ~= "table" then return false end
    local day = math.floor(now / DAY)
    local v = s.visit
    if type(v) ~= "table" or v.day ~= day then
        v = { day = day, count = 0 }
        s.visit = v
    end
    if v.till and now < v.till then return true, false end
    if s.asleep or s.sick or v.count >= Rules.VISITS or now - (s.born or 0) < Rules.VISIT_GAP
        or (v.last and now - v.last < Rules.VISIT_GAP) then
        return false
    end
    v.count, v.last, v.till = v.count + 1, now, now + Rules.VISIT_FOR
    s.fun = Clamp(s.fun + 10)
    return true, true
end

-- The kind of egg that doing `source` turns up this time, or nil. `roll`
-- is a number from 0 up to 1: the luck of it.
function Rules.EggFrom(source, roll)
    for kind, egg in pairs(Rules.EGGS) do
        if egg.from == source and roll < egg.chance then return kind end
    end
    return nil
end

-- Whether this is a boss's doing, whose egg is rare.
function Rules.Rare(source)
    for _, from in pairs(Rules.BOSSES) do
        if from == source then return true end
    end
    return false
end

-- A found egg joins the others, if there's room. True when it's kept. A
-- boss's egg has room past the three you hold: it waits at the end of the
-- list, kept aside, and moves up as the ones before it hatch. Then the
-- second answer is true.
function Rules.FindEgg(eggs, kind, from, now)
    local egg = Rules.EGGS[kind]
    if not egg then return false end
    local room = Rules.MAX_EGGS + (Rules.Rare(egg.from) and Rules.MAX_KEPT or 0)
    if #eggs >= room then return false end
    eggs[#eggs + 1] = { kind = kind, from = from, found = now }
    return true, #eggs > Rules.MAX_EGGS
end

-- Supplies your play brings in.
function Rules.Earn(s, supply, count)
    s.supplies[supply] = math.min(20, (s.supplies[supply] or 0) + (count or 1))
end
