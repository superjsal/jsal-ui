-- What your play brings the companion: supplies, eggs found, the paddock
-- and going out with you, how it takes what you do and your emotes, the
-- album and its name.
local _, ns = ...
local Compat, Rules, Pet = ns.Compat, ns.PetRules, ns.Pet
local inner = Pet.inner
local ui = inner.ui
local BOOK_PAGE, Now, Eggs, Sheet = inner.BOOK_PAGE, inner.Now, inner.Eggs, inner.Sheet
local Milestones, Refresh, IsOpen = inner.Milestones, inner.Refresh, inner.IsOpen

function Pet.Earn(supply, count)
    Rules.Earn(Pet.State(), supply, count)
    if IsOpen() then Refresh() end
end

-- Something you did that it may have wished for today. Granted with its
-- page shut, it says so in chat, once.
function Pet.Did(kind)
    local s = Pet.State()
    if s.unchosen then return end       -- no companion yet to wish for anything
    if not Rules.Did(s, kind, Now()) then return end
    if IsOpen() then
        -- A wish can tip the bond up a level: say both, the wish first.
        local more = Milestones(s)
        ui.said = ("%s's wish is granted."):format(s.name) .. (more and (" " .. more) or "")
        Refresh()
    else
        ns.Print(("%s's wish is granted. It's delighted."):format(s.name))
        Milestones(s)
    end
    Pet.Sound("sparkle")
    Pet.React("glad")
end

-- More supplies from your play: a fish caught or a point of Cooking is a
-- treat, a point of First Aid is medicine, a few a day (Rules.Extra).
function Pet.Extra(kind)
    local s = Pet.State()
    local supply = Rules.Extra(s, kind, Now())
    if not supply then return false end
    if ui.window and ui.window:IsShown() then
        ui.said = kind == "fishing" and "A treat, from your catch." or kind == "cooking" and "A treat, from your cooking." or "Medicine, from your bandaging."
        Refresh()
    end
    return true
end

-- The zone you're in, as the game names it.
local function ZoneName()
    local zone = GetRealZoneText and GetRealZoneText() or ""
    return zone ~= "" and zone or nil
end

-- Something you did that can turn up an egg (see Rules.EGGS). `roll` is
-- the luck of it, from 0 up to 1; left out, it's rolled here. True when an
-- egg was found and there was room to keep it.
Pet.Luck = math.random
function Pet.Found(source, roll)
    -- Not while it's still growing: there aren't so many kinds that eggs should pile up.
    -- (A boss's egg is found all the same, and kept aside when your hands are full.)
    if not Rules.CanFind(Pet.State(), source) then return false end
    local kind = Rules.EggFrom(source, roll or Pet.Luck())
    if not kind then return false end
    local where = ZoneName() or "your travels"
    local name = Rules.EGGS[kind].name
    local a = name:find("^[AEIOU]") and "an" or "a"
    local kept, aside = Rules.FindEgg(Eggs(), kind, where, Now())
    if not kept then
        -- Everyday eggs come and go unseen; a rare one left behind is worth a line.
        if Rules.Rare(source) then
            ns.Print(("There was %s %s in %s, but you can't carry another egg. Hatch one of yours to make room."):format(a, name, where))
        end
        return false
    end
    ns.Print(aside and ("You found %s %s in %s! Your hands are full, so it's kept safe: it takes the place of the next egg you hatch."):format(a, name, where)
        or ("You found %s %s in %s! /jsal pet shows your eggs."):format(a, name, where))
    Pet.Sound("fanfare")
    Pet.React("glad")
    local J = ns.Journal
    if J and J.running then J.Note("pet", ("Found %s %s in %s"):format(a, name, where)) end
    if IsOpen() then
        ui.said = ("You found %s %s!"):format(a, name)
        Refresh()
    end
    return true
end

-- The paddock and back: the pen shows the companions that have settled.
function Pet.Paddock()
    if not Pet.running then
        return ns.Print("Jsal's Pals is turned off. /jsal settings turns it on.")
    end
    if not IsOpen() then Pet.Open() end
    if Pet.State().unchosen then return end
    -- Not while an egg hatches, as Out isn't: in the paddock that scene is never moved on,
    -- and its cover stayed over the way back.
    if ui.pen.hatching then return end
    ui.yard, ui.albumOpen = not ui.yard, false
    ui.looking, ui.said = nil, nil
    ui.pen.shade = nil     -- back from the paddock, it's day or night at once
    Refresh()
end
ns.Command("pet paddock", Pet.Paddock)

-- /jsal pet out, and the Out button in the pen's corner: the creature
-- leaves its window to walk about on your screen while you play, and the
-- same again (or the + over it) brings the window back.
function Pet.Out()
    if not Pet.running then
        return ns.Print("Jsal's Pals is turned off. /jsal settings turns it on.")
    end
    -- Asked for while nothing of it is showing, it comes out.
    if not IsOpen() then
        ns.db.petOut = true
        return Pet.Open()
    end
    -- A hatchling still to be named stays in: the box for its name is in
    -- the window. Out says so, where it did nothing at all, and was then
    -- left switched on for later.
    if ui.pen.hatching then return end
    local s = Pet.State()
    if s.unnamed and ns.db.petOut ~= true then
        -- Short: the line it's said on doesn't wrap, and the box for the
        -- name is right under it.
        ui.said = "Name it first, then it can come out."
        return Refresh()
    end
    ns.db.petOut = ns.db.petOut ~= true and true or nil
    Pet.KeepOutSpot()
    ui.yard, ui.albumOpen, ui.looking, ui.walk = false, false, nil, nil
    ui.pen.shade = nil
    Pet.Layout()
    Refresh()
end
ns.Command("pet out", Pet.Out)

-- The size button over it when it's out: once, twice or three times the
-- art's size, round and round, and kept.
function Pet.Resize()
    ns.db.petOutTimes = Pet.OutScale() % 3 + 1
    if not (ui.window and ui.window:IsShown()) then return end
    ui.walk = nil
    Pet.Layout()
    Refresh()
end

-- Something you did in your own play, seen by the creature if it's on your
-- screen and awake: it does something about it. Which animation, what's set
-- down beside it and what's heard, by what you did.
local REACT = {
    quest = { show = "cheer", sound = "pat" },
    level = { show = "special", sound = "fanfare" },
    flight = { show = "jump", prop = "ball", sound = "play" },
    zone = { show = "idle" },
    died = { show = "poorly", sound = "poorly" },
    back = { show = "cheer", sound = "sparkle" },
    -- You've logged in, or come back to the keys: hello.
    hello = { show = "jump", sound = "pat" },
    -- A fight you came through; a wish granted or an egg found (which have sounds of their own).
    won = { show = "cheer" },
    glad = { show = "cheer" },
    -- Something worth a look: a rare in your sights, a blue or better in your bags.
    rare = { show = "jump", sound = "sparkle" },
    loot = { show = "cheer", sound = "sparkle" },
    -- It has dug something up for you.
    dug = { show = "dig", sound = "scoop" },
}
function Pet.React(kind)
    local what = REACT[kind]
    if not (what and IsOpen() and ui.walk) or ui.yard then return false end
    local s = Pet.State()
    if s.unchosen or s.asleep or ui.walk.nap then return false end
    -- A form with no such animation hops instead.
    if not (Pet.Play(ui.walk, Sheet(), what.show) or Pet.Play(ui.walk, Sheet(), "jump")) then return false end
    ui.walk.act.prop = what.prop
    Pet.Sound(what.sound)
    return true
end

-- It copies you: an emote of yours is one of its own. The game's word for
-- the emote, and what the creature does.
local EMOTES = {
    DANCE = "cheer", CHEER = "cheer", APPLAUD = "cheer", CLAP = "cheer", VICTORY = "cheer", LAUGH = "cheer", LOL = "cheer",
    SIT = "sit", SLEEP = "yawn", YAWN = "yawn",
    WAVE = "jump", HELLO = "jump", HI = "jump", GREET = "jump", KISS = "jump", HUG = "jump", LOVE = "jump",
    CRY = "poorly", SOB = "poorly", ROAR = "special", FLEX = "special",
}
Pet.EMOTES = EMOTES
-- The game's own /dance and the rest can't be listened to as they're done
-- (Forever keeps that door from addons), so they're known by the line they
-- put in chat: "You burst into dance." A word of that line, and the emote
-- it means. English, like the other lines the Companion reads; /sit puts no
-- line in chat, so it's copied only from a macro, or when you sit to eat.
local EMOTE_WORDS = {
    { "dance", "DANCE" }, { "cheer", "CHEER" }, { "applaud", "APPLAUD" }, { "clap", "CLAP" }, { "victory", "VICTORY" },
    { "laugh", "LAUGH" }, { "asleep", "SLEEP" }, { "yawn", "YAWN" }, { "wave", "WAVE" }, { "greet", "HELLO" },
    { "hello", "HELLO" }, { "kiss", "KISS" }, { "hug", "HUG" }, { "love", "LOVE" }, { "cry", "CRY" },
    { "roar", "ROAR" }, { "flex", "FLEX" },
}
-- The emote a chat line of your own is, or nil: a line about someone else
-- ("Thrall dances with you.") isn't yours and is nothing.
function Pet.EmoteOf(text)
    if type(text) ~= "string" or not text:find("^You ") then return nil end
    local line = text:lower()
    for _, word in ipairs(EMOTE_WORDS) do
        if line:find(word[1], 1, true) then return word[2] end
    end
    return nil
end
function Pet.Emote(token)
    -- In a dungeon the game may hide the word; then there's nothing to copy.
    token = Compat.Plain(token)
    local anim = type(token) == "string" and EMOTES[token:upper()] or nil
    if not (anim and Pet.running and IsOpen() and ui.walk) or ui.yard or ui.pen.held or ui.pen.toss or ui.walk.errand then return false end
    local s = Pet.State()
    if s.unchosen or s.asleep or ui.walk.nap then return false end
    ui.walk.chase = nil
    if not (Pet.Play(ui.walk, Sheet(), anim) or Pet.Play(ui.walk, Sheet(), "jump")) then return false end
    if anim == "jump" then Pet.Sound("pat") end
    return true
end

-- And it counts as company: what you do while it's on your screen brings you
-- a little closer once a day, and now and then it digs something up
-- (Rules.Company). `roll` is the luck of that; left out, it's rolled here.
function Pet.Along(roll)
    if not IsOpen() then return false end
    local s = Pet.State()
    if s.unchosen then return false end
    local closer, found = Rules.Company(s, Now(), roll or Pet.Luck())
    if found then
        ns.Print(("%s dug up a %s while you were busy."):format(s.name, found))
        Pet.React("dug")
    end
    if closer then
        ns.Print(("%s has been good company today. You're a little closer."):format(s.name))
    end
    if (found or closer) and IsOpen() then Refresh() end
    return true
end

-- The paddock's album and back to its list: the button beside Back.
function Pet.Album()
    if not (ui.window and ui.window:IsShown() and ui.yard) then return end
    ui.albumOpen = not ui.albumOpen
    if ui.albumOpen then ui.albumPage = 1 end
    Refresh()
end

-- The album's arrows: the next page or the one before, round again past the ends.
function Pet.AlbumPage(step)
    if not ui.albumOpen then return end
    local pages = math.ceil(#Rules.KINDS / BOOK_PAGE)
    ui.albumPage = (ui.albumPage - 1 + (step or 1)) % pages + 1
    Refresh()
end

-- The name for a new hatchling, from the box in its window. Only while
-- it's still unnamed: once named, that's its name.
function Pet.Rename(text)
    local s = Pet.State()
    if s.unchosen or not s.unnamed then return false end
    local old = s.name
    local ok, what = Rules.Rename(s, text)
    local J = ns.Journal
    if ok and J and J.running then J.Note("pet", ("%s is called %s now"):format(old, s.name)) end
    -- Naming a new hatchling, Enter on the name it came with keeps that name.
    if s.unnamed and not ok and (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")) == s.name then
        ok, what = true, ("%s it is."):format(s.name)
    elseif s.unnamed and ok then
        what = ("%s it is."):format(s.name)
    end
    if ok then s.unnamed = nil end
    ui.said = what
    if IsOpen() then Refresh() end
    return ok
end

-- For the pet's other files.
inner.ZoneName = ZoneName
