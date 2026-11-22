-- The companion: a small creature of your own that lives in a pen. It
-- wanders, gets hungry, tired, bored and dirty, sleeps, leaves droppings to
-- scoop, and can feel a little poorly. You look after it with supplies your
-- play brings in: a quest handed in is a meal, a flight is a toy, a new
-- level is treats, soap and medicine. Its life is in PetRules.lua. It has a
-- small window of its own, to leave open while you play, and nothing runs
-- unless that window is open, apart from noticing what you earn.
--
-- This file is what the rest stand on: the part and its options, pictures
-- and sounds, sizes, how it wanders, and the saved companion. Then, in the
-- order they load: Pen.lua draws it, Care.lua looks after it, Window.lua
-- builds its window, Supplies.lua is what your play brings, Nest.lua its
-- eggs, Play.lua its games, Events.lua what it notices, Trials.lua the
-- beta's ways to try it.
local _, ns = ...
local Style, Compat, Rules = ns.Style, ns.Compat, ns.PetRules

local Pet = ns.NewModule("pet", {
    -- Its name; a creature is a pal.
    title = "Jsal's Pals",
    note = "A small creature of your own to look after, with supplies your play earns. /jsal pet",
    options = {
        { key = "sound", title = "Sounds", default = true,
          note = "Small sounds as it eats, plays, is bathed, hatches and the rest. The button in the pen's corner is the same switch." },
        -- New, so it starts off.
        { key = "weather", title = "Weather in its pen", default = false,
          note = "When it rains or snows where you are, or a sandstorm blows, it does in the pen too." },
    },
})
ns.Pet = Pet
-- What the pet's files hand each other: each ends by putting in what the
-- later ones use, and each of those starts by taking it out as locals.
-- Nothing outside this folder reads it.
local inner = {}
Pet.inner = inner

local MEDIA = "Interface\\AddOns\\jsalUI\\Media\\Pet\\"
-- Its pictures are PNG, which the game must be told: a path with no ending
-- is looked for as a BLP or a TGA only. (tools/make_pet_format.py goes back.)
local EXT = ".png"
local function Art(name) return MEDIA .. name .. EXT end
-- Its sounds: short ones built by tools/make_pet_sounds.py, played with the
-- game's other sound effects, and only while its Sounds option is on.
local SOUNDS = { "eat", "play", "pat", "scoop", "bath", "well", "sleep", "wake", "hatch", "poorly", "sparkle", "fanfare" }
Pet.SOUNDS = SOUNDS
function Pet.Sound(name)
    if not name or not ns.OptionOn("pet", "sound") then return false end
    pcall(PlaySoundFile, MEDIA .. "Sounds\\" .. name .. ".ogg", "SFX")
    return true
end
-- The window is as wide as the pen plus a margin each side. Each form is
-- drawn at its own size, so a hatchling is small, the middle form reads as
-- an adolescent, and the last is the largest: 64, 96 and 128 pixels for the
-- 64 pixels of art it stands in. At 96 a pixel comes out one or two wide by
-- turns, which a small face shows (uneven eyes): art meant for the middle
-- size is better made 96 pixels to begin with.
local PAD = 10
local PEN_W, PEN_H, SIZE = 440, 200, 128
-- An egg in the row under the buttons: the bottom middle 32 pixels of its
-- 64-pixel picture, where the egg stands, at its own size.
local EGG_W = 32
local YARD_MAX = 6        -- how many settled companions wander the paddock, and are listed under it
-- In the album, how far down its page each row of pictures stands: first
-- forms, then middle ones, then last, the larger ones with more room.
local BOOK_ROWS = { 94, 196, 298 }
-- And how many kinds it shows side by side: more than that and it turns over to
-- another page.
local BOOK_PAGE = 4
local SIZES = { 64, 96, 128 }
-- How far down the pen the grass starts: its feet stay below this.
local GRASS = 110
local WIN_W, WIN_H = PEN_W + PAD * 2, 666
local HEAP_W = 32       -- a dropping, and the bowl, treat and ball: 32-pixel pictures
local SPEED = 40          -- pixels a second
local STEP_TIME = 0.28    -- seconds each walking frame shows
local DUSK = 4            -- seconds the pen takes to turn from day to night, or back
-- Out with you (/jsal pet out): no window and no meadow, only the creature,
-- walking to and fro along a strip, with room over it for its two buttons
-- (STRIP_TOP). How large it is, and so how long and tall its strip, depends
-- on the screen (Pet.OutScale); these are for the art's own size, and
-- Layout works them out afresh.
local STRIP_TOP = 24
-- What the pet's files share: the window, its parts and what it's showing.
-- They're in one table, not locals: each file reads and sets them, and the
-- game's Lua lets a file declare 200 local variables and a function use 60
-- from outside itself (limits_test.lua). A new part of the window goes in
-- here, not in a local of its own.
--   window, pen, body, sprite and the rest: made as the window is built
--   chrome: the parts that make it a window (its fill, edges and shadow,
--     the pen's edges and meadows), all hidden while it's out with you
--   walk: where the creature is and what it's doing (Pet.NewWalk)
--   stripW, stripH, outSize: its strip and its size out with you
--   yard: the pen is showing the paddock (the companions that have
--     settled) and not the companion you look after
--   albumOpen, albumPage: under the paddock, the album is open and not the
--     list of who has settled; and which of its pages is showing
--   said: the line under the pen, what was last said of it
--   looking: a form being looked at ahead of time (/jsal pet look), an
--     entry of LOOKS, or nil for the companion as it is. Only what's drawn
--     changes, nothing saved does, and a reload forgets it.
local ui = { chrome = {}, eggSlots = {}, picks = {}, roamers = {}, yardRows = {}, album = {}, book = {},
    bookTurn = {}, bars = {}, care = {}, heaps = {}, play = { notice = {} },
    stripW = 260, stripH = STRIP_TOP + 64, outSize = 64, yard = false, albumOpen = false, albumPage = 1 }
-- It's drawn at a whole number of times the art's size, so its pixels stay
-- square: once on the game's usual interface (768 units tall), twice on a
-- small, sharp one (1440 units, a unit to a pixel on a 1440 screen), three
-- times on one of 2160. That keeps it about a twelfth of the screen's
-- height for everyone: at the art's own size on a 1440 interface it's no
-- bigger than an action button, and nobody would see what it's doing.
-- That's what it picks for itself; the small button over it (Pet.Resize)
-- lets you pick instead, and what you picked is kept in `petOutTimes`.
function Pet.OutScale()
    local picked = ns.db and ns.db.petOutTimes
    if picked == 1 or picked == 2 or picked == 3 then return picked end
    local tall = UIParent and UIParent.GetHeight and UIParent:GetHeight() or 768
    return math.max(1, math.min(3, math.floor(tall / 720 + 0.25)))
end
-- It's moved and drawn at most this often, however fast the game is drawing:
-- its animations change every tenth of a second or so, so more is wasted work.
local FRAME = 1 / 30
-- Running, it covers the ground this many times as fast as walking. You
-- count as going fast above this many yards a second (a run on foot is 7).
local RUN, FAST = 2.2, 8
-- Out with you, it naps once you've rested and stood still this long, in seconds.
local REST_NAP = 60
-- What it may do when it gets somewhere, one time in eight each (the rest
-- of the time it only stands): sit, look about, show off, yawn and stretch, dig.
local IDLE = { "sit", "idle", "special", "yawn", "dig" }
-- And out with you while you're on the move: the short ones, so it's soon
-- on its way again, and wherever it happens to be on its strip, every WHIM
-- seconds or so (between the two numbers), so it still does them while you
-- walk or run, anywhere along the strip and not only at its end.
local ON_THE_GO = { "special", "cheer", "dig", "yawn", "idle" }
local WHIM = { 4, 9 }
Pet.WHIM = WHIM

-- Counts down to its next whim while it's on the move with you. True when
-- one is due, and the wait for the one after is drawn (`roll(a, b)`).
function Pet.Whim(walk, dt, roll)
    walk.whim = (walk.whim or roll(WHIM[1] * 10, WHIM[2] * 10) / 10) - dt
    if walk.whim > 0 then return false end
    walk.whim = roll(WHIM[1] * 10, WHIM[2] * 10) / 10
    return true
end

-- What it does of its own accord: `roll(a, b)` is the dice. At rest, asked
-- as it arrives somewhere, more often than not something. On the move with
-- you (`moving`), asked when a whim is due, always one of the short ones.
-- Poorly (`sick`), it doesn't show off: mostly it droops where it stands,
-- and sometimes just sits; on the move it only plods on.
function Pet.Idle(roll, moving, sick)
    if sick then
        if moving then return nil end
        local pick = roll(1, 6)
        return pick <= 4 and "poorly" or pick == 5 and "sit" or nil
    end
    if moving then return ON_THE_GO[roll(1, #ON_THE_GO)] end
    return IDLE[roll(1, 8)]
end
-- Food and play in its pen. A meal, a treat or a toy is in your hand for HOLD
-- seconds: click the grass and it's set down or thrown there (in the air for
-- `fly` seconds, ARC pixels high), and the creature goes over to it. A ball
-- it has brought back lies by it for AGAIN seconds, to be thrown again, up to
-- THROWS throws of the one toy.
local HOLD, ARC, AGAIN, THROWS = 4, 46, 4, 3
-- A treat tossed up for it is in the air for TOSS seconds, and can be caught
-- while it's coming down to its head: between these two parts of the way,
-- while the treat sparkles and it's ready to leap (Pet.Glint).
local TOSS, CATCH_FROM, CATCH_TO = 2.0, 0.62, 0.97
-- A bath is scrubbed: SCRUB pixels of rubbing the brush over it. And the
-- pointer, wiggled in its pen (WIGGLE pixels of travel, counted so that a
-- slow pass never adds up), is chased for CHASE seconds.
local SCRUB, CHASE, WIGGLE = 500, 4, 500
local IN_HAND = {
    bowl = { fly = 0, hint = "Click the grass to set its bowl down." },
    treat = { fly = 0.45, hint = "Click the grass to throw the treat, or your pal to toss it up." },
    ball = { fly = 0.5, hint = "Click the grass to throw the ball." },
}
Pet.HOLD, Pet.AGAIN, Pet.THROWS, Pet.TOSS, Pet.SCRUB, Pet.WIGGLE, Pet.CHASE = HOLD, AGAIN, THROWS, TOSS, SCRUB, WIGGLE, CHASE

-- How far the pointer has travelled lately, kept in `trail`: each look adds
-- what it moved and lets some of the old go, so only quick, kept-up movement
-- mounts. True once that's a wiggle.
function Pet.Trail(trail, x, y, dt)
    local moved = trail.x and (math.abs(x - trail.x) + math.abs(y - trail.y)) or 0
    trail.x, trail.y = x, y
    trail.moved = (trail.moved or 0) * math.max(0, 1 - dt * 1.5) + moved
    return trail.moved >= WIGGLE
end

-- Where a tossed treat is, `t` of the way through its flight (0 to 1): how
-- far above the top of the creature's picture, in creature-sizes (below it
-- when negative: its mouth is about 0.45 down, its feet 0.95), and whether
-- a click now catches it. It leaves the mouth's height, goes up over its
-- head, and comes down past the mouth to the grass.
function Pet.Tossed(t)
    t = math.max(0, math.min(1, t))
    return -0.45 - 0.5 * t + 5.2 * t * (1 - t), t >= CATCH_FROM and t <= CATCH_TO
end
-- What can be on its mind, as a small bubble over its head: the cell of
-- bubble.png (tools/make_pet_bubble.py) for each, eight to a row. And what
-- it's telling you about (Pet.Flash): someone whispered you, mail has come,
-- and from `gift` on, each thing it can find (Rules.TRINKETS, in order). A bubble comes up for
-- BUBBLE_FOR seconds in every BUBBLE_EVERY; a wish, which is there all day
-- until it's granted, only one time in three, so it doesn't nag.
local BUBBLES = { hungry = 0, scoop = 1, dirty = 2, bored = 3, poorly = 4, wish = 5, bags = 6, whisper = 7, letter = 8, gift = 9 }
Pet.BUBBLES = BUBBLES
local BUBBLE_EVERY, BUBBLE_FOR, BAGS_FULL = 24, 6, 4
-- Its pen is in the kind of country you're in: a scene for each kind (each
-- with a sunset and a night of its own, tools/make_pet_night.py), by zone.
-- Anywhere not named here is the meadow it began in.
local SCENES = { "meadow", "snow", "desert", "swamp", "coast", "darkwood", "savanna", "volcanic", "jungle" }
local ZONE_SCENE = {}
-- Every zone of the two continents is thought about here, and the dungeons
-- and raids whose country is plain. The green ones left to the meadow:
-- Elwynn Forest, Stormwind City, Loch Modan, Redridge Mountains, Hillsbrad
-- Foothills, Arathi Highlands, The Hinterlands, Teldrassil, Darnassus,
-- Ashenvale, Stonetalon Mountains, Mulgore, Thunder Bluff, Moonglade.
for scene, zones in pairs({
    snow = { "Dun Morogh", "Ironforge", "Winterspring", "Alterac Mountains", "Alterac Valley", "Gnomeregan" },
    desert = { "Tanaris", "Silithus", "Badlands", "Thousand Needles", "Desolace", "Durotar", "Orgrimmar",
        "Blasted Lands", "Zul'Farrak", "Uldaman", "Ruins of Ahn'Qiraj", "Ahn'Qiraj", "Ragefire Chasm" },
    swamp = { "Wetlands", "Swamp of Sorrows", "Dustwallow Marsh", "The Temple of Atal'Hakkar", "Sunken Temple",
        "Onyxia's Lair" },
    coast = { "Darkshore", "Azshara", "Blackfathom Deeps", "The Deadmines" },
    darkwood = { "Duskwood", "Deadwind Pass", "Tirisfal Glades", "Undercity", "Silverpine Forest", "Felwood",
        "Western Plaguelands", "Eastern Plaguelands", "Shadowfang Keep", "Scarlet Monastery", "Scholomance",
        "Stratholme", "Naxxramas", "Razorfen Downs" },
    savanna = { "The Barrens", "Westfall", "Wailing Caverns", "Razorfen Kraul" },
    volcanic = { "Burning Steppes", "Searing Gorge", "Blackrock Mountain", "Blackrock Depths", "Blackrock Spire",
        "Lower Blackrock Spire", "Upper Blackrock Spire", "Molten Core", "Blackwing Lair" },
    jungle = { "Stranglethorn Vale", "Un'Goro Crater", "Feralas", "Zul'Gurub", "Dire Maul", "Maraudon" },
}) do
    for _, zone in ipairs(zones) do ZONE_SCENE[zone:lower()] = scene end
end
Pet.SCENES = SCENES
function Pet.Scene(zone)
    return ZONE_SCENE[tostring(zone or ""):lower()] or "meadow"
end
-- And the hour is the realm's: how far the day has gone by its clock, 0 by
-- day, a half for the two hours of sunset and of dawn, 1 at night.
function Pet.Hours(hour)
    hour = tonumber(hour) or 12
    if hour >= 21 or hour < 5 then return 1 end
    if hour >= 19 or hour < 7 then return 0.5 end
    return 0
end
-- What's on its mind right now, or nil: something it wants from you first,
-- then today's wish, then (as you'd want to know) that your bags are nearly full.
function Pet.Thought(s, now, free)
    local key = Rules.Wants(s)
    if key then return key end
    if s.asleep or s.unchosen then return nil end
    if not Rules.Wish(s, now).done then return "wish" end
    if free and free <= BAGS_FULL then return "bags" end
    return nil
end
-- What's drawn over any creature, whatever its kind: flies and a smell when
-- it's dirty, dizzy stars when it's poorly, a tub of suds and then a sparkle
-- for a bath, green crosses and a pair of hearts as medicine makes it well.
-- One picture of 64-pixel cells, eight to a row, drawn over the 64 pixels
-- it stands in (tools/make_pet_effects.py). The first two go round and
-- round; the others play once, over as long as the animation they go with.
local EFFECTS = {
    dirty = { first = 0, count = 8, time = 0.12 },
    sick = { first = 8, count = 8, time = 0.14 },
    bath = { first = 16, count = 16 },
    well = { first = 32, count = 16 },
    -- Hearts and sparkles, round and round: the second half of getting
    -- well, for a companion doting on the egg it looks after.
    love = { first = 40, count = 8, time = 0.16 },
}
local MUDDY, GREEN, PLAIN = { 0.74, 0.62, 0.46 }, { 0.78, 1, 0.78 }, { 1, 1, 1 }
-- Dirty, it's a little dulled all over (GRUBBY) and has mud on it: the same
-- picture drawn again in MUD, shown only where mud_mask.png is solid, so
-- the splotches keep to its shape. Where the game can't mask a picture,
-- it's MUDDY all over and there are no splotches.
local GRUBBY, MUD = { 0.88, 0.8, 0.68 }, { 0.42, 0.29, 0.16 }
-- The light in the pen, as a colour everything standing in it is drawn in:
-- plain by day, warm at sunset, blue by the moon. `shade` is how far the day
-- has gone, from 0 (day) through a half (the sun going down) to 1 (night).
local SUNSET, MOONLIT = { 1, 0.84, 0.7 }, { 0.62, 0.7, 0.98 }
function Pet.Light(shade)
    local from, to, t = PLAIN, SUNSET, shade * 2
    if shade > 0.5 then from, to, t = SUNSET, MOONLIT, shade * 2 - 1 end
    return from[1] + (to[1] - from[1]) * t, from[2] + (to[2] - from[2]) * t, from[3] + (to[3] - from[3]) * t
end
Pet.EFFECTS = EFFECTS
Pet.PEN_W, Pet.PEN_H, Pet.SIZE, Pet.SIZES, Pet.HEAP_W = PEN_W, PEN_H, SIZE, SIZES, HEAP_W
local NEED_NAME = { hunger = "Fed", energy = "Rested", fun = "Happy", clean = "Clean" }
-- A form without a sheet has three pictures: standing, mid-step and asleep.
local SUFFIX = { stand = "", step = "_step", sleep = "_sleep" }
-- A form with a sheet is animated instead: one picture of 64 cells, eight
-- to a row, its animations one after another. Each is the cell it starts
-- at (counted from 0), how many frames it has and how long each one shows.
-- Every sheet is packed by tools/make_pet_sheet.py, its animations in this
-- order. `lay` is for a creature too large for the usual sheet: how big its
-- cells are, how many to a row, the picture's size, and how many frames it
-- walks in. A larger cell still has the 64 pixels it stands in at its
-- middle, with room around them for it to move.
local function Packed(file, lay)
    lay = lay or {}
    local sheet = { file = file, cell = lay.cell or 64, cols = lay.cols or 8, w = lay.w or 512, h = lay.h or 512 }
    local at = 0
    for _, anim in ipairs({
        { "walk", lay.walk or 4, lay.walkTime or 0.14 }, { "idle", 15, 0.14 }, { "eat", 11, 0.12 }, { "jump", 7, 0.1 },
        { "sit", 10, 0.16 }, { "doze", 8, 0.16 }, { "wake", 9, 0.12 },
    }) do
        sheet[anim[1]] = { first = at, count = anim[2], time = anim[3] }
        at = at + anim[2]
    end
    -- Sitting ends sat down, which isn't how it stands: so it stays sat a
    -- while (`hold`, seconds), then gets up through the same frames
    -- backwards (`back`, seconds a frame), and is standing when it's done.
    sheet.sit.hold, sheet.sit.back = 2.4, 0.08
    -- The cells held while it stands and while it sleeps.
    sheet.stand, sheet.sleep = sheet.idle.first, sheet.doze.first + sheet.doze.count - 1
    -- One more, in a picture of its own with larger cells: the thing its kind
    -- can do (a fiery punch, a burst of leaves), nine frames in a row.
    --
    -- (`lay.specialW`: a wider picture, for nine cells too large for 1024.)
    sheet.special = { first = 0, count = 9, time = 0.12, file = (file:gsub("_sheet$", "_special")), cell = lay.special or 96,
        w = lay.specialW or 1024, h = 128 }
    -- And one for when it's poorly, kept the same way, eight frames: it
    -- droops, stays drooped a while, and straightens up again as sitting does.
    sheet.poorly = { first = 0, count = 8, time = 0.14, hold = 2.6, back = 0.1,
        file = (file:gsub("_sheet$", "_poorly")), cell = 96, w = 1024, h = 128 }
    -- Four more, in one picture of ten 96-pixel cells to a row, a row each
    -- (tools/make_pet_sheet.py, from its Run, Cheer, Dig and Yawn frames): a
    -- run, which it goes about in as it does its walk; a happy dance; a dig
    -- at the ground; and a yawn and stretch.
    local more = (file:gsub("_sheet$", "_more"))
    -- A fifth row is its catch: a leap and a snap at a treat over its head.
    for row, anim in ipairs({ { "run", 0.08 }, { "cheer", 0.11 }, { "dig", 0.11 }, { "yawn", 0.16 }, { "catch", 0.1 } }) do
        sheet[anim[1]] = { first = (row - 1) * 10, count = 8, time = anim[2], file = more, cell = 96, w = 1024, h = 512 }
    end
    -- Stroked, it leans into your hand with its eyes shut: one frame of its
    -- yawn, the one where they're shut (`lay.calm`, counted from 0), held a
    -- moment and held again with each stroke (Pet.Stroking).
    sheet.lean = { first = sheet.yawn.first + (lay.calm or 0), count = 1, time = 0.6, file = more, cell = 96, w = 1024, h = 512 }
    -- Hiding, it crouches where it is: the last frame of sitting down, held
    -- for as long as it hides (Pet.HideStep sets how long).
    sheet.crouch = { first = sheet.sit.first + sheet.sit.count - 1, count = 1, time = 1 }
    -- A treat coming down to it, it gets ready to leap: its catch's second
    -- frame, crouched or looking up, held while the treat sparkles.
    sheet.ready = { first = sheet.catch.first + 1, count = 1, time = 1, file = more, cell = 96, w = 1024, h = 512 }
    -- A first form has one more again: its egg rocking, cracking and
    -- breaking open round it, ten frames in a row (tools/make_pet_hatch.py).
    if lay.hatch then
        sheet.hatch = { first = 0, count = 10, time = 0.2, file = (file:gsub("_sheet$", "_hatch")), cell = 96, w = 1024, h = 128 }
    end
    return sheet
end
-- (`calm` in each: which frame of its yawn has its eyes shut, for Pet.Stroking.)
local SHEETS = {
    briarboar = Packed("briarboar_sheet", { calm = 6, hatch = true, cols = 16, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    thornhog = Packed("thornhog_sheet", { calm = 5, cols = 16, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    brambletusk = Packed("brambletusk_sheet", { calm = 5, cell = 80, cols = 12, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    wispkin = Packed("wispkin_sheet", { calm = 4, hatch = true }),
    gloamtail = Packed("gloamtail_sheet", { calm = 0 }),
    wispjester = Packed("wispjester_sheet", { calm = 0, cell = 80, cols = 12, w = 1024, h = 512 }),
    scrapwing = Packed("scrapwing_sheet", { calm = 6, hatch = true, cols = 16, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    jabdrake = Packed("jabdrake_sheet", { calm = 6, cell = 80, cols = 12, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    flarechamp = Packed("flarechamp_sheet", { calm = 6, cell = 80, cols = 12, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    stormcub = Packed("stormcub_sheet", { calm = 5, hatch = true, cols = 16, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    thundermane = Packed("thundermane_sheet", { calm = 5, cell = 80, cols = 12, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    tempestmane = Packed("tempestmane_sheet", { calm = 5, cell = 80, cols = 12, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    capling = Packed("capling_sheet", { calm = 5, hatch = true, cols = 16, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    lanternshell = Packed("lanternshell_sheet", { calm = 6, cols = 16, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    bloomsage = Packed("bloomsage_sheet", { calm = 5, cell = 80, cols = 12, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    boltusk = Packed("boltusk_sheet", { calm = 5, hatch = true, cols = 16, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    rumbletrunk = Packed("rumbletrunk_sheet", { calm = 5, cell = 80, cols = 12, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    warmammoth = Packed("warmammoth_sheet", { calm = 5, cell = 80, cols = 12, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    gemlet = Packed("gemlet_sheet", { calm = 4, hatch = true, cell = 80, cols = 12, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    miragehoof = Packed("miragehoof_sheet", { calm = 5, cell = 80, cols = 12, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    sandseer = Packed("sandseer_sheet", { calm = 5, cell = 80, cols = 12, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    pebblebill = Packed("pebblebill_sheet", { calm = 6, hatch = true, cell = 80, cols = 12, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    cobbleback = Packed("cobbleback_sheet", { calm = 6, cell = 80, cols = 12, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    rockwarden = Packed("rockwarden_sheet", { calm = 6, cell = 80, cols = 12, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    snowlet = Packed("snowlet_sheet", { calm = 5, hatch = true, cell = 80, cols = 12, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    frostmantle = Packed("frostmantle_sheet", { calm = 6, cell = 80, cols = 12, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    -- Its wings open wide in its idle and its special: larger cells for both.
    auroracrown = Packed("auroracrown_sheet", { calm = 5, cell = 112, cols = 9, w = 1024, h = 1024, walk = 8, walkTime = 0.1, special = 112 }),
    starwhelp = Packed("starwhelp_sheet", { calm = 5, hatch = true, cell = 80, cols = 12, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    moondrake = Packed("moondrake_sheet", { calm = 5, cell = 80, cols = 12, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    -- The largest of them all: its open wings are 120 pixels across.
    eclipselord = Packed("eclipselord_sheet", { calm = 6, cell = 128, cols = 16, w = 2048, h = 1024, walk = 8, walkTime = 0.1,
        special = 128, specialW = 2048 }),
    glumbill = Packed("glumbill_sheet", { calm = 0, hatch = true, cell = 80, cols = 12, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    broodstork = Packed("broodstork_sheet", { calm = 0, cell = 80, cols = 12, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    dreadmire = Packed("dreadmire_sheet", { calm = 0, cell = 80, cols = 12, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
}
-- Everything /jsal pet look can show, in the order it shows them, one line
-- of three after another. `form` is which of the three sizes it's drawn at.
local LOOKS = {
    { sprite = "briarboar", name = "Briarboar", form = 1 },
    { sprite = "thornhog", name = "Thornhog", form = 2 },
    { sprite = "brambletusk", name = "Brambletusk", form = 3 },
    { sprite = "wispkin", name = "Wispkin", form = 1 },
    { sprite = "gloamtail", name = "Gloamtail", form = 2 },
    { sprite = "wispjester", name = "Wispjester", form = 3 },
    { sprite = "scrapwing", name = "Scrapwing", form = 1 },
    { sprite = "jabdrake", name = "Jabdrake", form = 2 },
    { sprite = "flarechamp", name = "Flarechamp", form = 3 },
    { sprite = "stormcub", name = "Stormcub", form = 1 },
    { sprite = "thundermane", name = "Thundermane", form = 2 },
    { sprite = "tempestmane", name = "Tempestmane", form = 3 },
    { sprite = "capling", name = "Capling", form = 1 },
    { sprite = "lanternshell", name = "Lanternshell", form = 2 },
    { sprite = "bloomsage", name = "Bloomsage", form = 3 },
    { sprite = "boltusk", name = "Boltusk", form = 1 },
    { sprite = "rumbletrunk", name = "Rumbletrunk", form = 2 },
    { sprite = "warmammoth", name = "Warmammoth", form = 3 },
    { sprite = "gemlet", name = "Gemlet", form = 1 },
    { sprite = "miragehoof", name = "Miragehoof", form = 2 },
    { sprite = "sandseer", name = "Sandseer", form = 3 },
    { sprite = "pebblebill", name = "Pebblebill", form = 1 },
    { sprite = "cobbleback", name = "Cobbleback", form = 2 },
    { sprite = "rockwarden", name = "Rockwarden", form = 3 },
    { sprite = "snowlet", name = "Snowlet", form = 1 },
    { sprite = "frostmantle", name = "Frostmantle", form = 2 },
    { sprite = "auroracrown", name = "Auroracrown", form = 3 },
    { sprite = "starwhelp", name = "Starwhelp", form = 1 },
    { sprite = "moondrake", name = "Moondrake", form = 2 },
    { sprite = "eclipselord", name = "Eclipselord", form = 3 },
    { sprite = "glumbill", name = "Glumbill", form = 1 },
    { sprite = "broodstork", name = "Broodstork", form = 2 },
    { sprite = "dreadmire", name = "Dreadmire", form = 3 },
}
Pet.LOOKS = LOOKS
Pet.SHEETS = SHEETS

---------------------------------------------------------------------------
-- Wandering, with no drawing in it. A walk is where the creature is (its top
-- left corner in the pen), where it's heading, which way it faces, which
-- frame shows, and how long it still stands before the next stroll.
---------------------------------------------------------------------------
-- `keep`: the furthest right it may go, while there's a nest at the pen's
-- right to keep off. `corner`: the right edge and top of the hiding place
-- (x, y), not to stop behind: standing there is hide and seek, when a click
-- finds it.
local function Spot(random, size, strip, keep, corner)
    -- Out with you, it only walks to and fro, along the bottom of its strip.
    if strip then return random(0, strip - size), STRIP_TOP end
    -- Its feet are near the bottom of its picture: high enough up the pen
    -- and a small one would be standing on the fence.
    local top = math.max(0, math.floor(GRASS - size * 0.92))
    local right = math.max(0, math.min(PEN_W - size, keep or PEN_W))
    local x, y = random(0, right), random(top, PEN_H - size)
    if corner and x + size * 0.3 < corner.x and y + size * 0.9 > corner.y then
        x = random(math.min(right, math.ceil(corner.x - size * 0.3)), right)
    end
    return x, y
end

-- `size` is how large it's drawn (the largest, unless told).
function Pet.NewWalk(random, size, strip)
    size = size or SIZE
    local x, y = Spot(random, size, strip)
    return { x = x, y = y, tx = x, ty = y, wait = 1, facing = "left", frame = "stand", clock = 0, size = size, strip = strip }
end

-- Doting on the egg, while it stands by its nest: a happy hop as it gets
-- there, then it sits down beside the egg; hearts rise from the nest as it
-- arrives and every few seconds after. Over, when it strolls off again or
-- the nest is gone. Returns "hearts" on a frame they should rise.
function Pet.Dote(walk, sheet, dt)
    local d = walk.doting
    if not d then return nil end
    if walk.wait <= 0 or not walk.keep then
        walk.doting = nil
        return nil
    end
    walk.facing = "right"
    d.clock = d.clock + dt
    if walk.act then return nil end
    if d.step == 0 then
        d.step, d.hearts = 1, d.clock + 3
        if sheet then Pet.Play(walk, sheet, "cheer") end
        return "hearts"
    elseif d.step == 1 then
        d.step = 2
        if sheet then Pet.Play(walk, sheet, "sit") end
    elseif d.clock >= d.hearts then
        d.hearts = d.clock + 3
        return "hearts"
    end
    return nil
end

-- Starts a short animation (eating, a jump, settling down): it stays where
-- it is until that's played through. A form with no sheet has none.
function Pet.Play(walk, sheet, name)
    local anim = sheet and sheet[name]
    if type(anim) ~= "table" then return false end
    walk.act = { name = name, clock = 0,
        length = anim.count * anim.time + (anim.hold or 0) + (anim.back and anim.count * anim.back or 0) }
    return true
end

-- The cell to show right now, and what it's a cell of: its sheet, or an
-- animation kept in a picture of its own (which then says its file and the
-- size of its cells).
function Pet.Cell(walk, sheet)
    local act = walk.act
    local anim = act and sheet[act.name]
    if anim then
        local from = anim.file and anim or sheet
        -- Played through, then held on its last frame, then (for one that
        -- comes back the way it went) its frames again in reverse.
        local played = anim.count * anim.time + (anim.hold or 0)
        if anim.back and act.clock >= played then
            local gone = math.floor((act.clock - played) / anim.back)
            return anim.first + math.max(0, anim.count - 1 - gone), from
        end
        return anim.first + math.min(anim.count - 1, math.floor(act.clock / anim.time)), from
    end
    if walk.frame == "sleep" then return sheet.sleep, sheet end
    if walk.wait <= 0 then
        -- On its way somewhere, at a walk or (`walk.running`) at a run.
        local gait = walk.running and sheet.run or sheet.walk
        return gait.first + math.floor(walk.clock / gait.time) % gait.count, gait.file and gait or sheet
    end
    return sheet.stand, sheet
end

-- Moves the walk on by `dt` seconds.
function Pet.Step(walk, dt, random)
    if walk.act then
        walk.act.clock = walk.act.clock + dt
        if walk.act.clock >= walk.act.length then walk.act = nil end
        walk.frame = "stand"
        return walk
    end
    if walk.wait > 0 then
        walk.wait = walk.wait - dt
        walk.frame = "stand"
        if walk.wait <= 0 then
            walk.tx, walk.ty = Spot(random, walk.size or SIZE, walk.strip, walk.keep, walk.corner)
            -- With an egg to look after, one stroll in three is back to the
            -- nest's side, where it stays a while, facing it.
            if walk.keep and random(1, 3) == 1 then
                walk.tx, walk.ty, walk.beside = math.max(0, walk.keep), PEN_H - (walk.size or SIZE), true
            end
            if walk.tx ~= walk.x then walk.facing = walk.tx > walk.x and "right" or "left" end
            walk.clock = 0
        end
        return walk
    end
    local dx, dy = walk.tx - walk.x, walk.ty - walk.y
    local far = math.sqrt(dx * dx + dy * dy)
    local go = SPEED * (walk.running and RUN or 1) * (walk.brisk or 1) * dt
    if far <= go then
        -- There: stand for one to three seconds; by its nest, for longer,
        -- turned toward it.
        walk.x, walk.y = walk.tx, walk.ty
        walk.wait = 1 + random(0, 200) / 100
        if walk.beside then
            walk.beside = nil
            walk.wait, walk.facing = walk.wait + 6, "right"
            -- And there it dotes on the egg (Pet.Dote).
            walk.doting = { clock = 0, step = 0 }
        end
        walk.frame = "stand"
        return walk
    end
    walk.x, walk.y = walk.x + dx / far * go, walk.y + dy / far * go
    walk.clock = walk.clock + dt
    walk.frame = math.floor(walk.clock / STEP_TIME) % 2 == 0 and "step" or "stand"
    return walk
end

-- Clicked on the grass with nothing in your hand, it comes over: its feet
-- to where you clicked, as near as the pen lets it.
function Pet.Call(walk, cx, cy)
    local size = walk.size
    local top = math.max(0, math.floor(GRASS - size * 0.92))
    walk.tx = math.max(0, math.min(PEN_W - size, math.floor(cx - size / 2)))
    walk.ty = math.max(top, math.min(PEN_H - size, math.floor(cy - size * 0.96)))
    if walk.tx ~= walk.x then walk.facing = walk.tx > walk.x and "right" or "left" end
    walk.wait, walk.clock = 0, 0
    return walk
end

-- Something set down or thrown to (cx, cy) in the pen, and the creature sent
-- after it: an errand. It's worked out here where the creature will stand to
-- have the thing just in front of its feet, where a bowl or ball is always
-- drawn, so the thing lands exactly where it will be when the creature gets
-- there. `fly` is how long it's in the air; `fetch` that it's to be brought
-- back to where the creature stood when it was first thrown.
function Pet.Send(walk, cx, cy, thing, fly, fetch)
    local size = walk.size
    local over, up = math.floor(size * 0.2), math.floor(size * 0.04)
    local top = math.max(0, math.floor(GRASS - size * 0.92))
    local function Stand(facing)
        local tx = facing == "left" and cx + HEAP_W / 2 - over or cx - HEAP_W / 2 - size + over
        tx = math.max(0, math.min(PEN_W - size, math.floor(tx)))
        return tx, facing == "left" and tx + over - HEAP_W or tx + size - over
    end
    local facing = cx < walk.x + size / 2 and "left" or "right"
    local tx, px = Stand(facing)
    if px < 0 or px > PEN_W - HEAP_W then
        facing = facing == "left" and "right" or "left"
        tx, px = Stand(facing)
    end
    local ty = math.max(top, math.min(PEN_H - size, math.floor(cy + up - size)))
    local old = walk.errand
    walk.errand = { thing = thing, fetch = fetch, fly = fly or 0, phase = "fly", clock = 0, facing = facing,
        tx = tx, ty = ty, px = px, py = ty + size - up, sx = (PEN_W - HEAP_W) / 2, sy = PEN_H,
        homeX = old and old.homeX or walk.x, homeY = old and old.homeY or walk.y,
        throws = (old and old.throws or 0) + 1 }
    -- It stands and watches while the thing is in the air.
    walk.act, walk.running, walk.wait = nil, nil, (fly or 0) + 1
    walk.facing = cx < walk.x + size / 2 and "left" or "right"
    return walk.errand
end

-- Moves an errand on by `dt` seconds, before Pet.Step moves the walk, and
-- says what just happened, if anything: "landed" (it sets off at a run),
-- "there" (it has reached its food and starts on it; the errand is over),
-- "got" (it has the ball and turns for home), "back" (it's home, the ball at
-- its feet for another throw), "over" (nobody threw it again).
function Pet.Errand(walk, sheet, dt)
    local e = walk.errand
    if not e then return nil end
    e.clock = e.clock + dt
    if e.phase == "fly" then
        if e.clock < e.fly then return nil end
        e.phase, walk.tx, walk.ty, walk.wait, walk.clock, walk.running = "go", e.tx, e.ty, 0, 0, true
        if e.tx ~= walk.x then walk.facing = e.tx > walk.x and "right" or "left" end
        return "landed"
    elseif e.phase == "go" then
        if walk.wait <= 0 then return nil end
        walk.facing = e.facing
        if e.fetch then
            e.phase, walk.tx, walk.ty, walk.wait, walk.clock = "back", e.homeX, e.homeY, 0, 0
            if e.homeX ~= walk.x then walk.facing = e.homeX > walk.x and "right" or "left" end
            return "got"
        end
        walk.running, walk.errand = nil, nil
        if Pet.Play(walk, sheet, e.show or "eat") then walk.act.prop = e.thing end
        return "there"
    elseif e.phase == "back" then
        if walk.wait <= 0 then return nil end
        walk.running = nil
        e.phase, e.clock, walk.wait = "wait", 0, AGAIN
        return "back"
    elseif e.clock >= (e.throws >= THROWS and 1.5 or AGAIN) then
        walk.errand = nil
        return "over"
    end
    return nil
end

---------------------------------------------------------------------------
-- Your companion, kept for the whole account.
---------------------------------------------------------------------------
local function Now() return Compat.ServerTime() end

-- The saved companion. The first time, or when what's saved isn't one,
-- there's a stand-in marked `unchosen`: it keeps the supplies your play
-- earns until you've chosen an egg (Pet.Choose), and is never shown.
function Pet.State()
    local s = ns.db.pet
    if type(s) ~= "table" or type(s.supplies) ~= "table" or type(s.stamp) ~= "number" or type(s.due) ~= "table" then
        s = Rules.New(Now())
        s.unchosen = true
        ns.db.pet = s
    end
    return s
end

-- The three eggs a new player is offered: any three of all the kinds there
-- are, drawn once (Pet.Pick is the dice) and kept with the stand-in, so
-- they're the same three each time the window opens until one is chosen.
-- Starting over draws again.
Pet.Pick = math.random
local function Offer()
    local s = Pet.State()
    local offer, good = s.offer, false
    if type(offer) == "table" and #offer == Rules.OFFERED then
        good = true
        for _, key in ipairs(offer) do
            if not Rules.EGGS[key] then good = false end
        end
    end
    if not good then
        offer = Rules.Offer(Pet.Pick)
        s.offer = offer
    end
    return offer
end

-- What it wants from you right now, for Today: a title, a line under it and
-- its picture; nil when it's fine, asleep, or the part is off.
function Pet.Wants()
    if not Pet.running then return nil end
    if Pet.State().unchosen then
        local first = Rules.EGGS[Offer()[1]]
        return { key = "egg", title = "Three eggs are waiting", sub = "Choose your pal", texture = Art(first.species .. "_egg") }
    end
    local s = Rules.Advance(Pet.State(), Now())
    local key, title, sub = Rules.Wants(s)
    if not key then return nil end
    local sprites = Rules.Species(s).sprites
    return { key = key, title = title, sub = sub, texture = Art(sprites[s.grewFrom or s.form] or sprites[1]) }
end

-- Asleep for the night, or napping while you're away: lying down, it takes no notice of the pointer (it
-- doesn't turn to look at it or feel it stroke) until it wakes.
local function Asleep()
    return (Pet.State().asleep or (ui.walk and ui.walk.nap)) and true or false
end

-- For the pet's other files.
inner.Asleep = Asleep
inner.Art, inner.PAD, inner.SIZE, inner.PEN_H, inner.PEN_W, inner.EGG_W = Art, PAD, SIZE, PEN_H, PEN_W, EGG_W
inner.YARD_MAX, inner.BOOK_ROWS, inner.BOOK_PAGE, inner.SIZES = YARD_MAX, BOOK_ROWS, BOOK_PAGE, SIZES
inner.GRASS, inner.WIN_W, inner.WIN_H, inner.HEAP_W, inner.DUSK = GRASS, WIN_W, WIN_H, HEAP_W, DUSK
inner.STRIP_TOP, inner.ui, inner.FRAME, inner.FAST, inner.REST_NAP = STRIP_TOP, ui, FRAME, FAST, REST_NAP
inner.IDLE, inner.ARC, inner.THROWS, inner.HOLD, inner.CATCH_FROM = IDLE, ARC, THROWS, HOLD, CATCH_FROM
inner.CATCH_TO, inner.TOSS, inner.SCRUB, inner.CHASE, inner.IN_HAND = CATCH_TO, TOSS, SCRUB, CHASE, IN_HAND
inner.BUBBLES, inner.BUBBLE_EVERY, inner.BUBBLE_FOR, inner.SCENES = BUBBLES, BUBBLE_EVERY, BUBBLE_FOR, SCENES
inner.EFFECTS, inner.MUDDY, inner.GREEN, inner.PLAIN, inner.MUD = EFFECTS, MUDDY, GREEN, PLAIN, MUD
inner.GRUBBY, inner.NEED_NAME, inner.SUFFIX, inner.SHEETS = GRUBBY, NEED_NAME, SUFFIX, SHEETS
inner.LOOKS, inner.Now, inner.Offer = LOOKS, Now, Offer
