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

-- A newly hatched companion, with a few supplies to start on.
function Rules.New(now, name)
    return {
        name = name or "Bramble", born = now, stamp = now,
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
    if s.clean < 35 then return "dirty", s.name .. " needs a bath", "A bath makes it spotless" end
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
        return true, "You fill the bowl for when it wakes."
    end
    if s.hunger >= 95 then return false, "It isn't hungry." end
    if not Use(s, "meal") then return false, WANT.meal end
    Eat(s, now)
    return true, "It cleans the bowl."
end

function Rules.Treat(s, now)
    Rules.Advance(s, now)
    if s.asleep then return false, "It's asleep." end
    if not Use(s, "treat") then return false, WANT.treat end
    s.hunger, s.fun = Clamp(s.hunger + 10), Clamp(s.fun + 15)
    s.sweets = s.sweets + 1
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
    return true, "It chases the toy round the pen."
end

function Rules.Scoop(s, now)
    Rules.Advance(s, now)
    if s.droppings < 1 then return false, "Nothing to scoop." end
    s.droppings = s.droppings - 1
    s.clean = Clamp(s.clean + 15)
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
    return true, "It leans into your hand."
end

-- Supplies your play brings in.
function Rules.Earn(s, supply, count)
    s.supplies[supply] = math.min(20, (s.supplies[supply] or 0) + (count or 1))
end
