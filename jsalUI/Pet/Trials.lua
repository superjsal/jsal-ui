-- Commands for trying the companion out while it's being made: a look at
-- another form, a trial of settling, making it dirty or poorly on purpose,
-- starting over. They're there only in a beta build, one whose version
-- says so: a release has none of them.
local _, ns = ...
local Rules, Pet = ns.PetRules, ns.Pet
local inner = Pet.inner
local ui = inner.ui
local SIZE, SIZES, SHEETS, LOOKS, Now = inner.SIZE, inner.SIZES, inner.SHEETS, inner.LOOKS, inner.Now
local Own, Sheet, Refresh, IsOpen = inner.Own, inner.Sheet, inner.Refresh, inner.IsOpen

-- Whether a version is a beta's.
function Pet.Trials(version)
    return tostring(version or ""):find("beta", 1, true) ~= nil
end
local function Trial(word, fn)
    if Pet.Trials(ns.version) then ns.Command(word, fn) end
end

-- /jsal pet look: its pen, with it drawn as the next form along, and after
-- the last as itself again. For seeing what it will grow into.
function Pet.Look()
    if not Pet.running then
        return ns.Print("Jsal's Pals is turned off. /jsal settings turns it on.")
    end
    if not IsOpen() then Pet.Open() end
    local s = Pet.State()
    -- On through the list from where it is, past the companion's own form,
    -- and off the end back to the companion itself.
    local at = 0
    for i, look in ipairs(LOOKS) do
        if look == ui.looking then at = i end
    end
    repeat
        at = at + 1
        ui.looking = LOOKS[at]
    until not (ui.looking and Own(ui.looking) and ui.looking.form == s.form)
    ui.walk = nil      -- a new spot, of the size that's drawn now
    ui.said = ui.looking and ((Own(ui.looking) and "A look at it as a %s. /jsal pet look again for the next."
        or "The %s, of a line still to come. /jsal pet look again for the next."):format(ui.looking.name))
        or ("Back to %s as it is."):format(s.name)
    Refresh()
end
Trial("pet look", Pet.Look)

-- /jsal pet special: whatever is in the pen shows off now, without waiting
-- for it to feel like it.
function Pet.ShowOff()
    if not Pet.running then
        return ns.Print("Jsal's Pals is turned off. /jsal settings turns it on.")
    end
    if not IsOpen() then Pet.Open() end
    if not ui.walk then return end
    if Pet.State().asleep then
        ui.said = "It's asleep."
    elseif Pet.Play(ui.walk, Sheet(), "special") then
        ui.said = nil
    end
    Refresh()
end
Trial("pet special", Pet.ShowOff)

-- /jsal pet hatch: the first form in the pen hatches from its egg again,
-- for a look at it. Nothing about the companion changes.
function Pet.Hatch()
    if not Pet.running then
        return ns.Print("Jsal's Pals is turned off. /jsal settings turns it on.")
    end
    if not IsOpen() then Pet.Open() end
    if not ui.walk then return end
    if Pet.State().asleep then
        ui.said = "It's asleep."
    elseif Pet.Play(ui.walk, Sheet(), "hatch") then
        ui.said = nil
        Pet.Sound("hatch")
    else
        ui.said = "Only a first form hatches. /jsal pet look shows one."
    end
    Refresh()
end
Trial("pet hatch", Pet.Hatch)

-- The Grow button: ready to grow, it does, there in its pen as you watch.
-- False when it isn't ready, is asleep, or is already about it.
function Pet.GrowNow()
    local s = Pet.State()
    if not ui.walk or not s.grewFrom or (ui.walk.act and ui.walk.act.name == "grow") then return false end
    -- It grows in its pen, where there's room for the light and you're watching.
    if ui.window and ui.window.out then return false end
    if s.asleep then
        ui.said = ("%s is asleep. It can grow when it wakes."):format(s.name)
        Refresh()
        return false
    end
    -- The light is as large as the larger of the two forms needs, twice as
    -- wide as that form is drawn, and is over where that form will stand:
    -- on the same feet.
    local sprites = Rules.Species(s).sprites
    local was, now = SHEETS[sprites[s.grewFrom] or ""], SHEETS[sprites[s.form] or ""]
    local cell = math.max(was and was.cell or 64, now and now.cell or 64)
    local big = ui.window.out and ui.walk.size or math.max(SIZES[s.grewFrom] or SIZE, SIZES[s.form] or SIZE)
    ui.looking, ui.said = nil, nil
    ui.walk.errand, ui.walk.chase, ui.walk.nap, ui.pen.held, ui.pen.toss = nil, nil, nil, nil, nil
    ui.walk.act = { name = "grow", clock = 0, length = Pet.GROW.length, wide = big * 2 * cell / 64,
        cx = ui.walk.x + ui.walk.size / 2, cy = ui.walk.y + ui.walk.size - big / 2 }
    ui.walk.wait = math.max(ui.walk.wait, 1)
    Pet.Sound("sparkle")
    Refresh()
    return true
end

-- /jsal pet grow: it's ready to grow again into the form it has, from the
-- one before, for a look at it. Nothing else about the companion changes.
function Pet.Grow()
    if not Pet.running then
        return ns.Print("Jsal's Pals is turned off. /jsal settings turns it on.")
    end
    if not IsOpen() then Pet.Open() end
    if not ui.walk then return end
    local s = Pet.State()
    if s.asleep then
        ui.said = "It's asleep."
    elseif s.form < 2 then
        ui.said = "It hasn't grown yet. /jsal pet try gives you a grown one to try this on."
    else
        ui.looking = nil
        s.grewFrom = s.form - 1
        ui.said = ("%s is ready to grow again. Press Grow."):format(s.name)
    end
    Refresh()
end
Trial("pet grow", Pet.Grow)

-- /jsal pet weather: each kind of weather in the pen in turn, for a look,
-- whatever the sky is doing and whether or not its option is on; then back
-- to the weather where you are.
Pet.TRY_WEATHER = { { "rain", 1, "rain" }, { "snow", 0.4, "light snow" }, { "snow", 1, "heavy snow" }, { "sand", 1, "a sandstorm" } }
function Pet.TryWeather()
    if not Pet.running then
        return ns.Print("Jsal's Pals is turned off. /jsal settings turns it on.")
    end
    if not IsOpen() then Pet.Open() end
    if not ui.pen then return end
    ui.pen.trying = (ui.pen.trying or 0) + 1
    ui.pen.forced = Pet.TRY_WEATHER[ui.pen.trying]
    if ui.pen.forced then
        ui.said = ("A look at %s in the pen. /jsal pet weather again for the next."):format(ui.pen.forced[3])
    else
        ui.pen.trying = nil
        ui.said = "Back to the weather where you are."
        if Pet.sawWeather then
            ui.said = ui.said .. (" The game says type %s, intensity %.2f."):format(tostring(Pet.sawWeather), Pet.sawMuch or 0)
        end
    end
    Refresh()
end
Trial("pet weather", Pet.TryWeather)

-- /jsal pet try: a trial run of settling and hatching. Your real companion,
-- eggs and paddock are put aside, and in their place are a fully grown
-- stand-in and three eggs to click. /jsal pet try again puts everything
-- back exactly as it was; what's put aside is kept through a reload.
function Pet.Try()
    if not Pet.running then
        return ns.Print("Jsal's Pals is turned off. /jsal settings turns it on.")
    end
    local kept = ns.db.petAside
    if type(kept) == "table" then
        ns.db.pet, ns.db.petEggs, ns.db.petSettled, ns.db.petAside = kept.pet, kept.eggs, kept.settled, nil
        ns.Print(("The trial is over. %s is back, with everything as it was."):format(Pet.State().name))
    else
        ns.db.petAside = { pet = Pet.State(), eggs = ns.db.petEggs, settled = ns.db.petSettled }
        local now = Now()
        local stand = Rules.New(now, "Trial")
        stand.good, stand.form, stand.told = Rules.FULL, 3, true
        ns.db.pet, ns.db.petEggs, ns.db.petSettled = stand, {}, {}
        for _, kind in ipairs({ "ghostly", "ember", "toadstool" }) do
            Rules.FindEgg(ns.db.petEggs, kind, "a trial", now)
        end
        ns.Print("A trial: a fully grown stand-in and three eggs. Click an egg twice and the stand-in takes it into a nest; in a trial it's ready at once, so press Hatch. /jsal pet try again puts your own pal back.")
    end
    Pet.farewell, Pet.letting, Pet.lifting = nil, nil, nil
    ui.looking, ui.walk, ui.said, Pet.armed = nil, nil, nil, nil
    if not IsOpen() then Pet.Open() else Refresh() end
end
Trial("pet try", Pet.Try)

-- /jsal pet new: a trial of the very start. Everything of yours is put
-- aside as /jsal pet try does, and you're shown the three eggs a new player
-- chooses between. /jsal pet try (or new) again puts everything back.
function Pet.TryNew()
    if not Pet.running then
        return ns.Print("Jsal's Pals is turned off. /jsal settings turns it on.")
    end
    if type(ns.db.petAside) == "table" then return Pet.Try() end
    ns.db.petAside = { pet = Pet.State(), eggs = ns.db.petEggs, settled = ns.db.petSettled }
    ns.db.pet, ns.db.petEggs, ns.db.petSettled = nil, {}, {}
    Pet.State()
    ns.Print("A trial of the start: choose an egg as a new player would. /jsal pet try puts your own pal back.")
    ui.looking, ui.walk, ui.said, Pet.armed = nil, nil, nil, nil
    if not IsOpen() then Pet.Open() else Refresh() end
end
Trial("pet new", Pet.TryNew)

-- /jsal pet restart: start over for real, as a new player. The companion,
-- your eggs and the paddock are gone for good, and you choose an egg again.
-- It can't be undone, so the first time only says so; typed again, it's done.
function Pet.Restart()
    if not Pet.running then
        return ns.Print("Jsal's Pals is turned off. /jsal settings turns it on.")
    end
    if not Pet.restarting then
        Pet.restarting = true
        return ns.Print("This starts over for good: your pal, your eggs and the paddock are all lost, and you choose a new egg. /jsal pet restart again to do it.")
    end
    Pet.restarting = nil
    -- What a trial put aside goes too: a release has no command to end one,
    -- and starting over means everything.
    ns.db.pet, ns.db.petEggs, ns.db.petSettled, ns.db.petAside = nil, {}, {}, nil
    Pet.State()
    ui.looking, ui.walk, ui.said, Pet.armed = nil, nil, nil, nil
    ns.Print("Started over. Choose an egg.")
    if not IsOpen() then Pet.Open() else Refresh() end
end
-- Beta builds only.
Trial("pet restart", Pet.Restart)

-- /jsal pet dirty and /jsal pet sick: the companion in the pen is made
-- dirty, or poorly, there and then, with a bar of soap or a dose of medicine
-- to put it right. For seeing how those look and how the bath and the
-- medicine play. It is your real companion unless a trial is on.
local function Make(how)
    if not Pet.running then
        return ns.Print("Jsal's Pals is turned off. /jsal settings turns it on.")
    end
    if not IsOpen() then Pet.Open() end
    local s = Pet.State()
    if s.asleep and not Rules.Lights(s, Now()) then
        -- Too worn out to wake: for a trial, it's rested enough.
        s.energy = math.max(s.energy, 40)
        Rules.Lights(s, Now())
    end
    if how == "dirty" then
        s.clean = 20
        s.supplies.soap = math.max(s.supplies.soap, 1)
        ui.said = ("%s is dirty now. Bath puts it right."):format(s.name)
    else
        s.sick, s.sickSince = true, Now()
        s.supplies.medicine = math.max(s.supplies.medicine, 1)
        ui.said = ("%s is poorly now. Medicine puts it right."):format(s.name)
    end
    Refresh()
end
function Pet.Dirty() Make("dirty") end
function Pet.Sick() Make("sick") end
Trial("pet dirty", Pet.Dirty)
Trial("pet sick", Pet.Sick)

-- /jsal pet stock: the cupboard is topped up to three of everything, and
-- today's treats are forgotten, so that feeding, treats and play can be
-- tried without waiting on quests, flights and fish. Beta builds only.
function Pet.Stock()
    if not Pet.running then
        return ns.Print("Jsal's Pals is turned off. /jsal settings turns it on.")
    end
    local s = Pet.State()
    if s.unchosen then return ns.Print("Choose an egg first.") end
    for _, supply in ipairs({ "meal", "treat", "toy", "soap", "medicine" }) do
        s.supplies[supply] = math.max(s.supplies[supply] or 0, 3)
    end
    s.sweets = 0
    ui.said = "The cupboard is stocked: three of everything."
    if IsOpen() then Refresh() else Pet.Open() end
end
Trial("pet stock", Pet.Stock)

-- /jsal pet boss onyxia, /jsal pet boss ragnaros: as if that boss had just
-- fallen with the luck on your side, so its egg and what's said of it can be
-- seen without a raid and a one-in-ten roll. The egg is a real one. Beta
-- builds only.
function Pet.Boss(source)
    if not Pet.running then
        return ns.Print("Jsal's Pals is turned off. /jsal settings turns it on.")
    end
    if Pet.State().unchosen then return ns.Print("Choose an egg first.") end
    if not Rules.Rare(source) then return ns.Print("No boss of that name leaves an egg.") end
    -- (Found says what happened, kept or left behind.)
    Pet.Found(source, 0)
end
for _, source in pairs(Rules.BOSSES) do
    Trial("pet boss " .. source, function() Pet.Boss(source) end)
end

-- /jsal pet wish: today's wish is swapped for the next kind in the list,
-- not yet granted, so a wish can be tried on a day it didn't fall on (or
-- once today's is done). "/jsal pet wish fetch" and "/jsal pet wish catch"
-- ask for those two (a command is matched whole, so each is its own). Beta
-- builds only; a wish granted this way counts like any other.
function Pet.NewWish(kind)
    if not Pet.running then
        return ns.Print("Jsal's Pals is turned off. /jsal settings turns it on.")
    end
    local s = Pet.State()
    if s.unchosen then return ns.Print("Choose an egg first.") end
    local now = Now()
    local wish = Rules.Wish(s, now)
    local at, asked = 0, nil
    kind = type(kind) == "string" and kind:lower():match("^%s*(%a+)") or nil
    for i, one in ipairs(Rules.WISHES) do
        if one.kind == wish.kind then at = i end
        if one.kind == kind then asked = one.kind end
    end
    s.wish = { day = wish.day, kind = asked or Rules.WISHES[at % #Rules.WISHES + 1].kind, count = 0 }
    ui.said = "A new wish for today."
    if IsOpen() then Refresh() else Pet.Open() end
end
Trial("pet wish", function() Pet.NewWish() end)
Trial("pet wish fetch", function() Pet.NewWish("fetch") end)
Trial("pet wish catch", function() Pet.NewWish("catch") end)
