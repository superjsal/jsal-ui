-- The companion: a small creature of your own that lives in a pen. It
-- wanders, gets hungry, tired, bored and dirty, sleeps, leaves droppings to
-- scoop, and can feel a little poorly. You look after it with supplies your
-- play brings in: a quest handed in is a meal, a flight is a toy, a new
-- level is treats, soap and medicine. Its life is in PetRules.lua; this is
-- its window (a small one of its own, to leave open while you play), the
-- wandering and the supplies. Nothing here runs unless that window is open,
-- apart from noticing what you earn.
local _, ns = ...
local Style, Compat, Rules = ns.Style, ns.Compat, ns.PetRules

local Pet = ns.NewModule("pet", {
    -- Its name, John's pick (12 Nov 2026: "jsal's pals i like it"); a creature is a pal.
    title = "Jsal's Pals",
    -- A new part, so it starts off.
    defaultOn = false,
    note = "A small creature of your own to look after, with supplies your play earns. /jsal pet",
    options = {
        { key = "sound", title = "Sounds", default = true,
          note = "Small sounds as it eats, plays, is bathed, hatches and the rest. The button in the pen's corner is the same switch." },
    },
})
ns.Pet = Pet

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
-- And how many kinds it shows side by side: more than that and it turns
-- over to another page (John, 12 Nov 2026, with eight kinds: "Two pages of four").
local BOOK_PAGE = 4
local SIZES = { 64, 96, 128 }
-- How far down the pen the grass starts: its feet stay below this.
local GRASS = 110
local WIN_W, WIN_H = PEN_W + PAD * 2, 566
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
local stripW, stripH, outSize = 260, STRIP_TOP + 64, 64
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
-- seconds or so (between the two numbers). John, 12 Nov 2026: "while i'm
-- walking and running it doesnt really do its emotes anymore, i'd like for
-- it to still do its other animations", and then "should be able to do it
-- throughout the strip not just at the end".
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
-- while it's coming down past its head: between these two parts of the way.
local TOSS, CATCH_FROM, CATCH_TO = 1.6, 0.76, 0.96
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
-- bubble.png (tools/make_pet_bubble.py) for each. A bubble comes up for
-- BUBBLE_FOR seconds in every BUBBLE_EVERY; a wish, which is there all day
-- until it's granted, only one time in three, so it doesn't nag.
local BUBBLES = { hungry = 0, scoop = 1, dirty = 2, bored = 3, poorly = 4, wish = 5, bags = 6 }
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
    -- One more, in a picture of its own with larger cells: the thing its
    -- kind can do (a fiery punch, a burst of leaves), nine frames in a row.
    -- (`lay.special` names larger cells for one whose special reaches wider.
    -- The Auroracrown's open wings may be cut by the pen's top when it stands
    -- high: John, 12 Nov 2026, "I think its okay if it clips on ocassion",
    -- "Let it roam".)
    sheet.special = { first = 0, count = 9, time = 0.12, file = (file:gsub("_sheet$", "_special")), cell = lay.special or 96, w = 1024, h = 128 }
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
    -- A first form has one more again: its egg rocking, cracking and
    -- breaking open round it, ten frames in a row (tools/make_pet_hatch.py).
    if lay.hatch then
        sheet.hatch = { first = 0, count = 10, time = 0.2, file = (file:gsub("_sheet$", "_hatch")), cell = 96, w = 1024, h = 128 }
    end
    return sheet
end
local SHEETS = {
    briarboar = Packed("briarboar_sheet", { hatch = true, cols = 16, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    thornhog = Packed("thornhog_sheet", { cols = 16, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    brambletusk = Packed("brambletusk_sheet", { cell = 80, cols = 12, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    wispkin = Packed("wispkin_sheet", { hatch = true }),
    gloamtail = Packed("gloamtail_sheet"),
    wispjester = Packed("wispjester_sheet", { cell = 80, cols = 12, w = 1024, h = 512 }),
    scrapwing = Packed("scrapwing_sheet", { hatch = true, cols = 16, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    jabdrake = Packed("jabdrake_sheet", { cell = 80, cols = 12, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    flarechamp = Packed("flarechamp_sheet", { cell = 80, cols = 12, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    stormcub = Packed("stormcub_sheet", { hatch = true, cols = 16, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    thundermane = Packed("thundermane_sheet", { cell = 80, cols = 12, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    tempestmane = Packed("tempestmane_sheet", { cell = 80, cols = 12, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    capling = Packed("capling_sheet", { hatch = true, cols = 16, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    lanternshell = Packed("lanternshell_sheet", { cols = 16, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    bloomsage = Packed("bloomsage_sheet", { cell = 80, cols = 12, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    boltusk = Packed("boltusk_sheet", { hatch = true, cols = 16, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    rumbletrunk = Packed("rumbletrunk_sheet", { cell = 80, cols = 12, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    warmammoth = Packed("warmammoth_sheet", { cell = 80, cols = 12, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    gemlet = Packed("gemlet_sheet", { hatch = true, cell = 80, cols = 12, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    miragehoof = Packed("miragehoof_sheet", { cell = 80, cols = 12, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    sandseer = Packed("sandseer_sheet", { cell = 80, cols = 12, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    pebblebill = Packed("pebblebill_sheet", { hatch = true, cell = 80, cols = 12, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    cobbleback = Packed("cobbleback_sheet", { cell = 80, cols = 12, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    rockwarden = Packed("rockwarden_sheet", { cell = 80, cols = 12, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    snowlet = Packed("snowlet_sheet", { hatch = true, cell = 80, cols = 12, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    frostmantle = Packed("frostmantle_sheet", { cell = 80, cols = 12, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    -- Its wings open wide in its idle and its special: larger cells for both.
    auroracrown = Packed("auroracrown_sheet", { cell = 112, cols = 9, w = 1024, h = 1024, walk = 8, walkTime = 0.1, special = 112 }),
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
}
Pet.LOOKS = LOOKS
Pet.SHEETS = SHEETS

---------------------------------------------------------------------------
-- Wandering, with no drawing in it. A walk is where the creature is (its
-- top left corner in the pen), where it's heading, which way it faces,
-- which frame shows, and how long it still stands before the next stroll.
---------------------------------------------------------------------------
local function Spot(random, size, strip)
    -- Out with you, it only walks to and fro, along the bottom of its strip.
    if strip then return random(0, strip - size), STRIP_TOP end
    -- Its feet are near the bottom of its picture: high enough up the pen
    -- and a small one would be standing on the fence.
    local top = math.max(0, math.floor(GRASS - size * 0.92))
    return random(0, PEN_W - size), random(top, PEN_H - size)
end

-- `size` is how large it's drawn (the largest, unless told).
function Pet.NewWalk(random, size, strip)
    size = size or SIZE
    local x, y = Spot(random, size, strip)
    return { x = x, y = y, tx = x, ty = y, wait = 1, facing = "left", frame = "stand", clock = 0, size = size, strip = strip }
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
            walk.tx, walk.ty = Spot(random, walk.size or SIZE, walk.strip)
            if walk.tx ~= walk.x then walk.facing = walk.tx > walk.x and "right" or "left" end
            walk.clock = 0
        end
        return walk
    end
    local dx, dy = walk.tx - walk.x, walk.ty - walk.y
    local far = math.sqrt(dx * dx + dy * dy)
    local go = SPEED * (walk.running and RUN or 1) * dt
    if far <= go then
        -- There: stand for one to three seconds.
        walk.x, walk.y = walk.tx, walk.ty
        walk.wait = 1 + random(0, 200) / 100
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
    return { key = key, title = title, sub = sub, texture = Art(sprites[s.form] or sprites[1]) }
end

---------------------------------------------------------------------------
-- Its page.
---------------------------------------------------------------------------
local window, pen, body, sprite, prop, effect, mud, snore, title, sub, message, wishLine, bondLine, walk, parts, fold, eggLine, pickLine
local yardToggle, yardParts, yardHead, albumLine, nameBox, renameButton
local yardList, yardBook, bookToggle, bookHead, mute, outButton, ground, sizeButton, bubble
-- The parts of the window that make it a window (its fill, edges and shadow,
-- the pen's edges and meadows): all hidden while it's out with you.
local chrome = {}

-- The name box and its Confirm button, there only while a new hatchling is
-- being named: a companion is named once, as it hatches, and keeps that name.
local function NameBox(open)
    nameBox.open = open and true or false
    nameBox.well:SetShown(nameBox.open)
    renameButton:SetShown(nameBox.open)
    if nameBox.open then
        nameBox:SetText(Pet.State().name)
        nameBox:SetFocus()
        nameBox:HighlightText()
    else
        nameBox:ClearFocus()
    end
end

-- Takes what's typed: Enter and the Confirm button both come here. A name
-- that won't do leaves the box open to try again.
local function TakeName()
    if Pet.Rename(nameBox:GetText()) then NameBox(false) end
end

local eggSlots, picks, roamers, yardRows, album, book = {}, {}, {}, {}, {}, {}
-- Whether the pen is showing the paddock (the companions that have settled)
-- and not the companion you look after; and whether, under the paddock, the
-- album is open and not the list of who has settled.
local yard, albumOpen = false, false
-- Which page of the album is showing, and its arrows and "1 / 2".
local albumPage, bookTurn = 1, {}
local bars, care, heaps = {}, {}, {}
local HEAP_AT = { 30, 140, 260, 380 }
local said

-- A form being looked at ahead of time (/jsal pet look): only what's drawn
-- changes, nothing saved does, and a reload forgets it.
local looking       -- an entry of LOOKS, or nil for the companion as it is
local function Form()
    return looking and looking.form or Pet.State().form
end

-- The name its pictures go by: the look's, or its own form's.
local function Sprite()
    if looking then return looking.sprite end
    local s = Pet.State()
    local sprites = Rules.Species(s).sprites
    return sprites[s.form] or sprites[1]
end

-- What its form is called.
local function FormName(s, form)
    local forms = Rules.Species(s).forms
    return forms[form or s.form] or forms[1]
end

-- Whether a look is one of the companion's own line.
local function Own(look)
    for _, name in ipairs(Rules.Species(Pet.State()).sprites) do
        if name == look.sprite then return true end
    end
    return false
end

-- The eggs you're holding, and the companions settled in the paddock, both
-- kept for the whole account.
local function Eggs()
    if type(ns.db.petEggs) ~= "table" then ns.db.petEggs = {} end
    return ns.db.petEggs
end
local function Settled()
    if type(ns.db.petSettled) ~= "table" then ns.db.petSettled = {} end
    return ns.db.petSettled
end

-- The sheet of the form that's drawn now, if that form has one.
local function Sheet()
    return SHEETS[Sprite()]
end

-- Day, sunset or night in the pen, from how far the day has gone
-- (`pen.shade`): the sunset meadow fades in over the day one for the first
-- half, the night one over that for the second, and what lies on the grass
-- takes the light's colour. The creature takes it as it's painted.
local function Sky()
    local shade = pen.shade or 0
    pen.dusk:SetAlpha(math.min(1, shade * 2))
    pen.night:SetAlpha(math.max(0, shade * 2 - 1))
    local r, g, b = Pet.Light(shade)
    for _, heap in ipairs(heaps) do heap.pile:SetVertexColor(r, g, b) end
    prop:SetVertexColor(r, g, b)
    effect:SetVertexColor(r, g, b)
end

local function PaintWalk()
    local sheet = Sheet()
    local file, left, right, top, bottom
    -- An animation kept in a picture of its own says so: its cells are
    -- counted in that picture, and may be a different size.
    local from = sheet
    if sheet then
        local cell
        cell, from = Pet.Cell(walk, sheet)
        local cols = from.cols or math.floor(from.w / from.cell)
        local col, row = cell % cols, math.floor(cell / cols)
        file = Art(from.file)
        left, right = col * from.cell / from.w, (col + 1) * from.cell / from.w
        top, bottom = row * from.cell / from.h, (row + 1) * from.cell / from.h
    else
        file = Art(Sprite() .. SUFFIX[walk.frame])
        left, right, top, bottom = 0, 1, 0, 1
    end
    -- The sprite is drawn facing left; turned round, its picture is flipped.
    if walk.facing == "right" then left, right = right, left end
    sprite:SetTexCoord(left, right, top, bottom)
    if sprite.file ~= file then
        sprite.file = file
        -- NEAREST keeps each of its pixels a sharp square when drawn larger.
        sprite:SetTexture(file, "CLAMP", "CLAMP", "NEAREST")
    end
    if body.size ~= walk.size then
        body.size = walk.size
        body:SetSize(walk.size, walk.size)
    end
    -- The body is the 64 pixels it stands in; a larger cell's picture spills
    -- over it evenly on every side.
    local drawn = walk.size * (from and from.cell or 64) / 64
    if sprite.drawn ~= drawn then
        sprite.drawn = drawn
        sprite:ClearAllPoints()
        sprite:SetPoint("CENTER", body, "CENTER", 0, 0)
        sprite:SetSize(drawn, drawn)
    end
    -- How it is shows on it. Poorly, it's off-colour, with stars going round
    -- its head, and standing still it shivers; dirty, it's muddy, with flies;
    -- in the bath, the tub and suds, and the mud stays until halfway through;
    -- given medicine, it stays off-colour until halfway through getting well.
    local s, act = Pet.State(), walk.act
    local tick = Pet.tick or 0
    -- Asleep for the night, or having a nap while you're away, it snores.
    snore:SetShown((s.asleep or (walk.nap and not act)) and true or false)
    -- A bath being scrubbed: the mud stays on until it's done, and the suds
    -- come up as the brush goes over it.
    local scrub = pen.held and pen.held.scrub and pen.held or nil
    local over = act and EFFECTS[act.effect] and act.effect or scrub and scrub.scrub > 0 and "bath" or nil
    local early = act and act.clock < act.length / 2
    local washing = over == "bath"
    local dirty = Rules.Dirty(s) or (washing and act and act.grubby and early) or (scrub and scrub.grubby) or false
    local ill = s.sick or (over == "well" and act.ill and early)
    -- The mud is made the first time it's needed.
    if dirty and not mud then
        mud = body:CreateTexture(nil, "ARTWORK", nil, 1)
        mud:SetAllPoints(sprite)
        Compat.Crisp(mud)
        mud:SetDesaturated(true)
        mud:Hide()
        if body.CreateMaskTexture then
            local mask = body:CreateMaskTexture()
            mask:SetAllPoints(body)
            mask:SetTexture(Art("mud_mask"), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE", "NEAREST")
            mud:AddMaskTexture(mask)
            mud.masked = true
        end
    end
    local splotched = dirty and mud.masked
    if mud then
        if splotched then
            -- The same cell of the same picture as the creature, so it moves with it.
            mud:SetTexCoord(left, right, top, bottom)
            if mud.file ~= file then
                mud.file = file
                mud:SetTexture(file, "CLAMP", "CLAMP", "NEAREST")
            end
        end
        mud:SetShown(splotched and true or false)
    end
    -- Its own colour, in the pen's light: dimmed and blue at night, like the meadow.
    local hue = ill and GREEN or dirty and (splotched and GRUBBY or MUDDY) or PLAIN
    local shade = pen.shade or 0
    if sprite.hue ~= hue or sprite.shade ~= shade then
        sprite.hue, sprite.shade = hue, shade
        local r, g, b = Pet.Light(shade)
        sprite:SetVertexColor(hue[1] * r, hue[2] * g, hue[3] * b)
    end
    if mud and mud.shade ~= shade then
        mud.shade = shade
        local r, g, b = Pet.Light(shade)
        mud:SetVertexColor(MUD[1] * r, MUD[2] * g, MUD[3] * b)
    end
    local which = over or s.sick and "sick" or dirty and "dirty" or nil
    if which then
        local fx = EFFECTS[which]
        -- One that plays once goes with its animation; scrubbed suds, with the scrubbing (the first half).
        local part = act and act.effect == which and act.clock / act.length or scrub and scrub.scrub / SCRUB * 0.5 or 0
        local at = fx.time and math.floor(tick / fx.time) % fx.count
            or math.min(fx.count - 1, math.floor(part * fx.count))
        local col, row = (fx.first + at) % 8, math.floor((fx.first + at) / 8)
        effect:SetTexCoord(col / 8, (col + 1) / 8, row / 8, (row + 1) / 8)
        if not effect.file then
            effect.file = Art("effects")
            effect:SetTexture(effect.file, "CLAMP", "CLAMP", "NEAREST")
        end
        effect:Show()
    else
        effect:Hide()
    end
    -- Standing still, or drooped, it shivers now and then.
    local shiver = 0
    local low = act and act.name == "poorly" and sheet and sheet.poorly
    local drooped = low and act.clock >= low.count * low.time and act.clock < low.count * low.time + low.hold
    if pen.coldAt ~= Pet.where then pen.coldAt, pen.cold = Pet.where, Pet.Scene(Pet.where) == "snow" end
    if s.sick and not s.asleep and (not act or drooped) then
        local beat = math.floor(tick * 14)
        if beat % 14 < 4 then shiver = beat % 2 == 0 and 1 or -1 end
    elseif window.out and pen.cold and not act and not walk.nap and walk.wait > 0 then
        -- Out with you in the snow, it shivers now and then where it stands.
        local beat = math.floor(tick * 14)
        if beat % 70 < 6 then shiver = beat % 2 == 0 and 1 or -1 end
    end
    local bx, by = math.floor(walk.x + 0.5) + shiver, -math.floor(walk.y + 0.5)
    if body.bx ~= bx or body.by ~= by then
        body.bx, body.by = bx, by
        body:ClearAllPoints()
        body:SetPoint("TOPLEFT", pen, "TOPLEFT", bx, by)
    end
    -- What's on its mind, in a bubble by its head, for a few seconds now and then.
    local think = pen.thought and BUBBLES[pen.thought]
    local musing = think ~= nil and not act and not s.asleep and not walk.nap and tick % BUBBLE_EVERY < BUBBLE_FOR
        and (pen.thought ~= "wish" or math.floor(tick / BUBBLE_EVERY) % 3 == 0)
    if musing then
        bubble:SetTexCoord(think * 32 / 256, (think + 1) * 32 / 256, 0, 1)
        if bubble.size ~= walk.size then
            bubble.size = walk.size
            bubble:ClearAllPoints()
            bubble:SetPoint("BOTTOMLEFT", body, "TOPRIGHT", -math.floor(walk.size * 0.45), -math.floor(walk.size * 0.35))
        end
    end
    if bubble.on ~= musing then
        bubble.on = musing
        bubble:SetShown(musing)
    end
    -- Its bowl, its treat or its ball, on the grass in front of it while it eats or plays.
    -- Or in your hand, at the pointer, until you say where it goes; or on
    -- its way through the air, lying where it landed, or being brought back.
    local errand, held, toss = walk.errand, pen.held, pen.toss
    local thing = act and act.prop or errand and errand.thing or held and held.thing or toss and "treat"
    local seen = thing ~= nil
    -- What's in your hand is drawn by a picture of its own, over the creature
    -- (`pen.hand`): the brush goes over what it scrubs, not behind it.
    local inHand = false
    if thing then
        local file = Art(thing)
        if prop.file ~= file then
            prop.file = file
            prop:SetTexture(file, "CLAMP", "CLAMP", "NEAREST")
        end
        local over, up = math.floor(walk.size * 0.2), math.floor(walk.size * 0.04)
        prop:ClearAllPoints()
        local way = walk.facing == "right" and 1 or -1
        if act and act.toss then
            -- Caught: from where it was in the air, into its mouth, and gone.
            local t = act.clock / (act.length * 0.3)
            seen = t < 1
            local from, lean = act.from or 0.5, act.lean or 0
            prop:SetPoint("BOTTOM", body, "TOP", math.floor(walk.size * lean * (1 - t)) * way,
                math.floor(walk.size * (from + (-0.45 - from) * t)))
        elseif toss and not (act and act.prop) then
            -- Tossed up: over its head and down again, drifting to its front.
            local t = toss.clock / TOSS
            prop:SetPoint("BOTTOM", body, "TOP", math.floor(walk.size * 0.3 * t) * way, math.floor(walk.size * (Pet.Tossed(t))))
        elseif (act and act.prop) or (errand and (errand.phase == "wait" or errand.phase == "back")) then
            -- Carried home, it's held a little off the ground.
            if errand and errand.phase == "back" and not act then up = up + math.floor(walk.size * 0.22) end
            if walk.facing == "right" then
                prop:SetPoint("BOTTOMLEFT", body, "BOTTOMRIGHT", -over, up)
            else
                prop:SetPoint("BOTTOMRIGHT", body, "BOTTOMLEFT", over, up)
            end
        elseif errand then
            local t = errand.phase == "fly" and errand.fly > 0 and math.min(1, errand.clock / errand.fly) or 1
            local x = errand.sx + (errand.px - errand.sx) * t
            local y = errand.sy + (errand.py - errand.sy) * t - 4 * ARC * t * (1 - t)
            prop:SetPoint("BOTTOMLEFT", pen, "TOPLEFT", math.floor(x + 0.5), -math.floor(y + 0.5))
        else
            local x, y = Compat.CursorAt(pen)
            seen = false
            inHand = x ~= nil and x >= 0 and x <= PEN_W and y >= 0 and y <= PEN_H
            if inHand then
                local hand = pen.hand
                if hand.file ~= file then
                    hand.file = file
                    hand:SetTexture(file, "CLAMP", "CLAMP", "NEAREST")
                end
                hand:ClearAllPoints()
                hand:SetPoint("CENTER", pen, "TOPLEFT", math.floor(x), -math.floor(y))
            end
        end
    end
    prop:SetShown(seen)
    pen.hand:SetShown(inHand)
end

-- How you're getting about, for the companion out with you: on the move or
-- not, going fast (mounted, flying, or quicker than a run), away from the
-- keys, resting in an inn or a city. Asked of the game four times a second
-- at most, and kept in the one table.
local how, howAge, howTurn = { moving = false, fast = false, away = false, resting = false, eating = false }, 1, 0
function Pet.How(elapsed)
    howAge = howAge + (elapsed or 1)
    if howAge >= 0.25 then
        howAge = 0
        -- Whether you're eating or drinking means reading your buffs: once a second is plenty.
        howTurn = (howTurn + 1) % 4
        if howTurn == 0 then how.eating = Compat.Eating() end
        local speed, flying = Compat.Speed(), Compat.OnTaxi()
        how.moving = flying or speed > 0
        how.fast = flying or speed > FAST or (speed > 0 and Compat.Mounted())
        how.away, how.resting = Compat.Away(), Compat.Resting()
    end
    return how
end

-- Out with you, it goes by that, with no drawing in it. While you're on the
-- move it keeps going, never stopping long, and runs when you go fast; when
-- you stop it's free to stand, sit and potter. Away from the keys, or
-- resting and stood still a minute, it yawns, lies down and naps
-- (`walk.nap`) until you're back; then it gets up, and this returns true
-- once, the moment it's ready to say hello.
function Pet.Pace(walk, sheet, how, dt)
    walk.still = how.moving and 0 or (walk.still or 0) + dt
    local sleepy = how.away or (how.resting and walk.still >= REST_NAP)
    if walk.nap then
        if not sleepy then
            walk.nap, walk.yawned, walk.greet = nil, nil, true
            Pet.Play(walk, sheet, "wake")
        end
        return false
    end
    if walk.greet and not walk.act then
        walk.greet = nil
        return true
    end
    if sleepy then
        walk.running = nil
        if not walk.act then
            if not walk.yawned and Pet.Play(walk, sheet, "yawn") then
                walk.yawned = true
            elseif Pet.Play(walk, sheet, "doze") then
                walk.nap = true
            end
        end
        return false
    end
    walk.yawned = nil
    walk.running = how.fast or nil
    if how.moving and not walk.act and walk.wait > 0.2 then walk.wait = 0.2 end
    -- You've sat down to eat or drink: it sits down too, for as long as you do.
    if how.eating and not how.moving and not walk.act and walk.wait > 0 then Pet.Play(walk, sheet, "sit") end
    return false
end

-- Its milestones, each told once: hatching, growing up, a closer bond.
-- They go into your Journal's story, and the newest comes back as a line
-- for whoever is showing the pet.
local function Milestones(s)
    local told = {}
    local form = FormName(s)
    if not s.told then
        s.told = true
        told[#told + 1] = ("%s the %s hatched"):format(s.name, FormName(s, 1))
    end
    if s.grew then
        s.grew = nil
        told[#told + 1] = ("%s has grown into a %s!"):format(s.name, form)
        Pet.Sound("fanfare")
    end
    if s.bonded then
        -- Each level after the first teaches it a trick.
        local level, trick = Rules.Bond(s), false
        for _, one in ipairs(Rules.TRICKS) do
            if one.level == level then trick = true end
        end
        told[#told + 1] = ("%s and you are closer now: %s"):format(s.name, s.bonded)
            .. (trick and ". It has learned a trick: right-click it" or "")
        s.bonded = nil
    end
    local J = ns.Journal
    if J and J.running then
        for _, text in ipairs(told) do J.Note("pet", text) end
    end
    -- Hatching isn't news on its own page; the others are.
    local last = told[#told]
    if last and last:find(" hatched$") then last = nil end
    return last
end

-- Today's wish and the bond, in words.
local function WishText(s)
    local wish, what = Rules.Wish(s, Now())
    if wish.done then return "Today's wish is granted.", true end
    local text = "Today it " .. what.text
    if what.need > 1 then text = ("%s (%d of %d)"):format(text, wish.count, what.need) end
    return text, false
end

local function BondText(s)
    local _, name, points, next = Rules.Bond(s)
    local bond = next and ("Bond: %s · %d of %d"):format(name, points, next) or ("Bond: %s"):format(name)
    -- And how today's company is going: things done with it on your screen.
    local deeds, need = Rules.CompanyToday(s, Now())
    return ("%s   ·   Company today: %s"):format(bond, deeds >= need and "good company" or ("%d of %d"):format(deeds, need))
end

-- How long until it grows, in words; nil once it's fully grown.
local function Growing(s)
    local goal = s.form == 1 and Rules.GROWN or s.form == 2 and Rules.FULL or nil
    if not goal then return nil end
    local days = math.max(1, math.ceil((goal - s.good) / 24))
    return ("grows after about %d more good day%s"):format(days, days == 1 and "" or "s")
end

-- Everything that depends on how it is: the lines at the top, the four
-- bars, the droppings, the buttons and what they'd use.
-- One settled companion wandering the paddock: a frame of its own in the
-- pen, drawn from its sheet at the art's own size (so even a last form is
-- small here, and several fit).
local function PaintRoamer(r)
    local sheet, w = r.sheet, r.walk
    -- Showing off, it's drawn from the picture its special is kept in.
    local cell, from = Pet.Cell(w, sheet)
    local cols = from.cols or math.floor(from.w / from.cell)
    local col, row = cell % cols, math.floor(cell / cols)
    local left, right = col * from.cell / from.w, (col + 1) * from.cell / from.w
    if w.facing == "right" then left, right = right, left end
    r.sprite:SetTexCoord(left, right, row * from.cell / from.h, (row + 1) * from.cell / from.h)
    if r.file ~= from.file then
        r.file = from.file
        r.sprite:SetTexture(Art(from.file), "CLAMP", "CLAMP", "NEAREST")
        r.sprite:SetSize(from.cell, from.cell)
    end
    r.snore:SetShown(r.nap ~= nil and not w.act)
    r.body:ClearAllPoints()
    r.body:SetPoint("TOPLEFT", pen, "TOPLEFT", math.floor(w.x + 0.5), -math.floor(w.y + 0.5))
end

-- A settled companion's time in the paddock, with no drawing in it: it
-- wanders as the one in the pen does, and each time it gets somewhere it may
-- sit down, look about, show off what its kind can do, yawn, dig, or lie down
-- for a nap (`r.nap`, the seconds of sleep still to come) and get up again after.
local NAP = { 8, 20 }       -- a nap lasts between these, in seconds
function Pet.Roam(r, dt, random)
    local w, sheet = r.walk, r.sheet
    if r.nap then
        if w.act then
            Pet.Step(w, dt, random)
        else
            r.nap = r.nap - dt
            if r.nap <= 0 then
                r.nap = nil
                Pet.Play(w, sheet, "wake")
                return
            end
        end
        if not w.act then w.frame = "sleep" end
        return
    end
    local walking = w.wait <= 0
    Pet.Step(w, dt, random)
    if walking and w.wait > 0 and not w.act then
        local pick = random(1, 10)
        if IDLE[pick] then
            Pet.Play(w, sheet, IDLE[pick])
        elseif pick == 6 and Pet.Play(w, sheet, "doze") then
            r.nap = random(NAP[1], NAP[2])
        end
    end
end

-- How far you've raised each kind: the highest form one of yours has
-- reached, by kind, from the companion you have and those that settled.
function Pet.Raised(s, settled)
    local raised = {}
    local function Note(kind, form)
        kind = kind or "briarboar"
        raised[kind] = math.max(raised[kind] or 0, form or 1)
    end
    if not s.unchosen then Note(s.species, s.form) end
    for _, record in ipairs(settled) do Note(record.species, record.form or 3) end
    return raised
end

-- The paddock: the last few to settle wander the meadow, and under it
-- they're listed, with the kinds you've raised so far (the rest in shadow).
local function PaintYard(s)
    local settled = Settled()
    local first = math.max(1, #settled - YARD_MAX + 1)
    for i = 1, YARD_MAX do
        local record = settled[first + i - 1]
        local r = roamers[i]
        if record then
            if not r then
                r = { body = CreateFrame("Frame", nil, pen) }
                r.body:SetSize(64, 64)
                r.sprite = r.body:CreateTexture(nil, "ARTWORK")
                r.sprite:SetPoint("CENTER")
                Compat.Crisp(r.sprite)
                r.snore = Style.Text(r.body, 11, "secondary", nil, true)
                r.snore:SetPoint("BOTTOMLEFT", r.body, "TOPRIGHT", -22, -14)
                r.snore:SetText("z z")
                roamers[i] = r
            end
            if r.record ~= record then
                r.record = record
                local sprites = Rules.Species(record).sprites
                r.sheet = SHEETS[sprites[record.form] or sprites[1]]
                r.walk, r.nap, r.file = Pet.NewWalk(math.random, 64), nil, nil
            end
            r.body:Show()
            PaintRoamer(r)
            yardRows[i]:SetText(("%s the %s · %d day%s together · %s"):format(record.name, FormName(record, record.form),
                record.days or 1, (record.days or 1) == 1 and "" or "s", record.bond or "Wary"))
        else
            if r then
                r.record = nil
                r.body:Hide()
            end
            yardRows[i]:SetText("")
        end
    end
    yardHead:SetText(#settled == 0 and "No one has settled here yet. A fully grown pal settles when you hatch an egg."
        or #settled > YARD_MAX and ("%d have settled here. The last %d:"):format(#settled, YARD_MAX)
        or #settled == 1 and "One has settled here." or ("%d have settled here."):format(#settled))
    -- Under the list, every kind's first form, in shadow until you've raised one.
    local raised, count = Pet.Raised(s, settled), 0
    for i, kind in ipairs(Rules.KINDS) do
        local picture = album[i]
        if not picture.file then
            picture.file = Art(Rules.SPECIES[kind].sprites[1])
            picture:SetTexture(picture.file, "CLAMP", "CLAMP", "NEAREST")
        end
        if raised[kind] then
            count = count + 1
            picture:SetVertexColor(1, 1, 1)
            picture:SetAlpha(1)
        else
            picture:SetVertexColor(0, 0, 0)
            picture:SetAlpha(0.5)
        end
    end
    albumLine:SetText(("Kinds raised: %d of %d"):format(count, #Rules.KINDS))
    -- The album, in the list's place: every form of every kind, a kind to a
    -- column with its three forms down it, each in shadow and unnamed until
    -- one of yours has been it. Its pictures load the first time it's opened.
    yardList:SetShown(not albumOpen)
    yardBook:SetShown(albumOpen)
    bookToggle:SetLabel(albumOpen and "List" or "Album")
    if not albumOpen then return end
    local seen = 0
    local pages = math.ceil(#Rules.KINDS / BOOK_PAGE)
    albumPage = math.max(1, math.min(pages, albumPage))
    bookTurn.count:SetText(("%d / %d"):format(albumPage, pages))
    bookTurn.count:SetShown(pages > 1)
    bookTurn.back:SetShown(pages > 1)
    bookTurn.on:SetShown(pages > 1)
    for i, kind in ipairs(Rules.KINDS) do
        local species = Rules.SPECIES[kind]
        local here = book[i].page == albumPage
        for form, page in ipairs(book[i]) do
            page.picture:SetShown(here)
            page.name:SetShown(here)
            if not page.file then
                page.file = Art(species.sprites[form])
                page.picture:SetTexture(page.file, "CLAMP", "CLAMP", "NEAREST")
            end
            local have = (raised[kind] or 0) >= form
            if have then seen = seen + 1 end
            local light = have and 1 or 0
            page.picture:SetVertexColor(light, light, light)
            page.picture:SetAlpha(have and 1 or 0.5)
            page.name:SetText(have and species.forms[form] or "? ? ?")
        end
    end
    bookHead:SetText(("Forms seen: %d of %d. Each kind grows down its column."):format(seen, #Rules.KINDS * 3))
end

local Layout
local function Refresh()
    -- A new player has no companion yet: three eggs stand on the grass to
    -- choose from, and nothing else of the window is there.
    local s = Pet.State()
    local picking = s.unchosen == true
    if window.picking ~= picking then
        window.picking = picking
        Layout()
    end
    local offer = picking and Offer() or nil
    for i, pick in ipairs(picks) do
        pick:SetShown(picking)
        local kind = offer and Rules.EGGS[offer[i]]
        local file = kind and Art(kind.species .. "_egg")
        if file and pick.file ~= file then
            pick.file = file
            pick.picture:SetTexture(file, "CLAMP", "CLAMP", "NEAREST")
            pick.name:SetText((kind.name:gsub(" egg$", "")))
        end
    end
    body:SetShown(not picking and not yard)
    yardToggle:SetShown(not picking and not window.out)
    if picking then
        yard = false
        title:SetText("Choose your pal")
        pickLine:SetText(said or "Three eggs have turned up. Click one for a closer look.")
        for _, heap in ipairs(heaps) do heap:Hide() end
        pen.dark, pen.shade, walk = 0, 0, nil
        Sky()
        return
    end
    s = Rules.Advance(s, Now())
    if window.yard ~= yard then
        window.yard = yard
        Layout()
    end
    yardToggle:SetLabel(yard and "Back" or ("Paddock · %d"):format(#Settled()))
    if yard then
        title:SetText("The paddock")
        for _, heap in ipairs(heaps) do heap:Hide() end
        prop:Hide()
        -- The paddock is always by day, whatever the hour in the pen.
        pen.dark, pen.shade = 0, 0
        Sky()
        return PaintYard(s)
    end
    for _, r in ipairs(roamers) do r.body:Hide() end
    local _, mood = Rules.Mood(s)
    title:SetText(looking and (Own(looking) and ("%s as a %s"):format(s.name, looking.name) or ("A look at the %s"):format(looking.name))
        or ("%s the %s"):format(s.name, FormName(s)))
    local day = math.floor(math.max(0, Now() - s.born) / 86400) + 1
    local growing = Growing(s)
    sub:SetText(("%s · day %d%s"):format(mood, day, growing and (" · " .. growing) or " · fully grown"))
    -- Not yet told of: it's new, and breaks out of its egg as you first see it.
    local fresh = not s.told
    said = Milestones(s) or said
    message:SetText(said or "")
    local wish, granted = WishText(s)
    wishLine:SetText(wish)
    wishLine:SetTextColor(Style.Color(granted and "muted" or "text"))
    bondLine:SetText(BondText(s))
    for _, need in ipairs(Rules.NEEDS) do
        local bar = bars[need]
        bar.fill:SetWidth(math.max(1, bar.width * s[need] / 100))
        bar.fill:SetColorTexture(Style.Color(s[need] < 20 and "red" or "gold"))
    end
    for i, heap in ipairs(heaps) do heap:SetShown(i <= s.droppings) end
    snore:SetShown(s.asleep)
    -- Asleep, the pen is the same meadow by moonlight, and on the way there
    -- at sunset (tools/make_pet_night.py makes both), drawn over the day one:
    -- how far the day has gone is `shade`, which each frame moves toward
    -- `dark`. First shown, it's already where it should be.
    -- Out with you there's no meadow to darken, and it keeps its own colours.
    -- In its pen it's night while it sleeps, and otherwise as late as the realm's clock says.
    pen.dark = window.out and 0 or s.asleep and 1 or Pet.Hours(Compat.Hour())
    -- The pen is in the kind of country you're in.
    local scene = Pet.Scene(Pet.where)
    if pen.where ~= scene then
        pen.where = scene
        pen.scene:SetTexture(Art(scene), "CLAMP", "CLAMP", "NEAREST")
        pen.dusk:SetTexture(Art(scene .. "_dusk"), "CLAMP", "CLAMP", "NEAREST")
        pen.night:SetTexture(Art(scene .. "_night"), "CLAMP", "CLAMP", "NEAREST")
    end
    -- And what's on its mind, for its bubble.
    local free = 0
    for bag = 0, 4 do free = free + (Compat.BagFree(bag) or 0) end
    pen.thought = Pet.Thought(s, Now(), free)
    if not pen.shade then
        pen.shade = pen.dark
        Sky()
    end
    care.meal:SetLabel(("Feed · %d"):format(s.supplies.meal))
    care.treat:SetLabel(("Treat · %d"):format(s.supplies.treat))
    care.toy:SetLabel(("Play · %d"):format(s.supplies.toy))
    care.soap:SetLabel(("Bath · %d"):format(s.supplies.soap))
    care.medicine:SetLabel(("Medicine · %d"):format(s.supplies.medicine))
    care.medicine:SetEnabled(s.sick)
    -- Newly poorly, or found so as its window opens: a small sad sound, once.
    if s.sick and not pen.sick then Pet.Sound("poorly") end
    pen.sick = s.sick and true or false
    care.lights:SetLabel(s.asleep and "Wake it" or "Lights out")
    -- A form that has grown is drawn larger, and starts from a spot that fits it.
    -- Out with you, every form is at the art's own size, and keeps to its strip.
    local size, strip = SIZES[Form()] or SIZE, nil
    if window.out then size, strip = outSize, stripW end
    if not walk or walk.size ~= size or walk.strip ~= strip then walk = Pet.NewWalk(math.random, size, strip) end
    if fresh and not looking and Pet.Play(walk, Sheet(), "hatch") then Pet.Sound("hatch") end
    PaintWalk()
    -- The eggs you hold, each with its picture, and where they came from.
    local eggs = Eggs()
    local names = {}
    for i, slot in ipairs(eggSlots) do
        local egg = eggs[i]
        local kind = egg and Rules.EGGS[egg.kind]
        slot:SetShown(kind ~= nil)
        if kind then
            local file = Art(kind.species .. "_egg")
            if slot.file ~= file then
                slot.file = file
                slot.picture:SetTexture(file, "CLAMP", "CLAMP", "NEAREST")
            end
            names[#names + 1] = ("%s (%s)"):format(kind.name, egg.from or "found")
        end
    end
    eggLine:SetText(#names > 0 and ("Eggs: " .. table.concat(names, ", "))
        or Rules.CanFind(s) and "No eggs yet. A quest, a flight, a new level, a new zone, a fight won or coming back from the dead can turn one up."
        or ("Eggs turn up from your play once %s is fully grown."):format(s.name))
    -- Just hatched and not yet named: the name box opens by itself, with the
    -- name it would otherwise have ready to type over.
    if s.unnamed and not nameBox.asking then
        nameBox.asking = true
        NameBox(true)
    elseif not s.unnamed then
        nameBox.asking = nil
        if nameBox.open then NameBox(false) end
    end
end
Pet.Refresh = Refresh

-- One piece of care: do it, say what happened, and show how it is now. The
-- menu's badge and Today hear about it too.
-- `show` is the animation that goes with it, played when the care was
-- given and the creature is awake to react ("lights" picks its own: settling
-- down or getting up). `thing` is what's set down beside it meanwhile, and
-- `over` what's drawn over it (EFFECTS). `sound` is what's heard when the
-- care was given ("lights" picks its own too: going to sleep, or waking).
local function Do(act, show, thing, over, sound)
    local s = Pet.State()
    local grubby, ill = Rules.Dirty(s), s.sick
    local ok, what = act(s, Now())
    said = what
    -- In its pen and awake, a meal, a treat or a toy is in your hand first:
    -- where it goes is yours to say (Pet.Clicked, Pet.Petted), and it's heard
    -- when the creature gets to it.
    local here = ok and walk and not s.asleep and not window.out
    local hand = here and IN_HAND[thing] or nil
    -- And a bath is a brush in your hand, to scrub it with.
    local scrub = here and over == "bath"
    if ok and not hand and not scrub then Pet.Sound(sound == "lights" and (s.asleep and "sleep" or "wake") or sound) end
    if ok and walk then walk.errand, walk.chase, pen.held, pen.toss = nil, nil, nil, nil end
    if hand then
        pen.held = { thing = thing, show = show, sound = sound, what = what, clock = 0 }
        said = hand.hint
    elseif scrub then
        pen.held = { thing = "scrubber", show = show, over = over, sound = sound, what = what, clock = 0,
            scrub = 0, grubby = grubby, ill = ill }
        said = "Rub the brush over it to scrub it clean, or click it for a quick wash."
    elseif ok and walk and show then
        if show == "lights" then
            Pet.Play(walk, Sheet(), s.asleep and "doze" or "wake")
        elseif not s.asleep and Pet.Play(walk, Sheet(), show) then
            walk.act.prop, walk.act.effect, walk.act.grubby, walk.act.ill = thing, over, grubby, ill
        end
    end
    Refresh()
end

-- What's in your hand is set down in front of it, where it stands: when you
-- take too long to say where, or click the creature with its bowl or ball.
function Pet.SetDown()
    local held = pen.held
    if not (held and walk) then return end
    pen.held = nil
    if Pet.Play(walk, Sheet(), held.show) then
        if held.over then
            -- The brush: a quick wash, tub and suds and all, as a bath always was.
            walk.act.effect, walk.act.grubby, walk.act.ill = held.over, held.grubby, held.ill
        else
            walk.act.prop = held.thing
        end
    end
    Pet.Sound(held.sound)
    said = held.what
    Refresh()
end

-- The grass was clicked, at (x, y) from the pen's top left corner (where the
-- pointer is, unless told). With something in your hand it goes there, and
-- the creature after it; a ball it has brought back is thrown again; with
-- nothing, the creature comes over.
function Pet.Clicked(x, y)
    if not walk or window.out or yard or pen.toss then return end
    local s = Pet.State()
    if s.unchosen or s.asleep then return end
    if not x then x, y = Compat.CursorAt(pen) end
    if not x then return end
    local held, errand = pen.held, walk.errand
    if held and held.scrub then return end      -- the brush is for the creature, not the grass
    if held then
        pen.held = nil
        local sent = Pet.Send(walk, x, y, held.thing, IN_HAND[held.thing].fly, held.thing == "ball")
        sent.show, sent.sound, sent.what = held.show, held.sound, held.what
        if sent.fetch then Pet.Sound(held.sound) end
        said = held.what
        Refresh()
        -- A throw of the ball counts toward a wish for a game of fetch.
        if sent.fetch then Pet.Did("fetch") end
    elseif errand and errand.phase == "wait" and errand.throws < THROWS then
        local ok, what = Rules.Fetch(s, Now())
        said = what
        if ok then
            Pet.Send(walk, x, y, "ball", IN_HAND.ball.fly, true)
            Pet.Sound("play")
        else
            walk.errand = nil
        end
        Refresh()
        if ok then Pet.Did("fetch") end
    elseif not errand and not walk.act then
        Pet.Call(walk, x, y)
    end
end

-- The creature was clicked: a pat. With its bowl or ball in your hand,
-- that's set down by it. With a treat, the treat is tossed up over its head
-- (`pen.toss`), and the next click on it is the catch: as the treat comes
-- down past its head it leaps and has it, which is a little more fun than
-- one set down; clicked too soon or too late it jumps at nothing, and the
-- one click is all you get. A treat nobody caught lands on the grass, and
-- it's eaten there (Tend).
function Pet.Petted(button)
    if button == "RightButton" then return Pet.Trick() end
    local held, toss = pen.held, pen.toss
    if toss then
        if toss.spent or not walk then return end
        local t = toss.clock / TOSS
        local up, good = Pet.Tossed(t)
        local sheet = Sheet()
        if good then
            pen.toss = nil
            local s = Pet.State()
            local _, what = Rules.Caught(s, Now())
            if Pet.Play(walk, sheet, "catch") or Pet.Play(walk, sheet, "jump") then
                walk.act.prop, walk.act.toss, walk.act.from, walk.act.lean = "treat", true, up, 0.3 * t
            end
            Pet.Sound(toss.sound)
            -- One treat too many is still the news, however it was given.
            said = s.sick and toss.what or what
        else
            toss.spent = true
            Pet.Play(walk, sheet, "jump")
            said = t < CATCH_FROM and "Too soon! It jumps at nothing." or "Too late! It jumps at nothing."
        end
        Refresh()
        -- A catch may be the very thing it wished for today.
        if good then Pet.Did("catch") end
        return
    end
    if not held then return Do(Rules.Pat, "jump", nil, nil, "pat") end
    if held.thing ~= "treat" then return Pet.SetDown() end
    pen.held = nil
    pen.toss = { clock = 0, what = held.what, sound = held.sound }
    -- It stops where it is and watches it go up.
    walk.act, walk.errand, walk.running = nil, nil, nil
    walk.tx, walk.ty, walk.wait = walk.x, walk.y, TOSS + 1
    said = "Up it goes! Click your pal as the treat comes down to it."
    Refresh()
end

-- Right-clicked, it's asked for a trick: one of those its bond has taught
-- it (Rules.Trick), picked by Pet.Pick. In its pen or out with you.
function Pet.Trick()
    if not walk or yard or pen.held or pen.toss or walk.errand or walk.nap then return end
    local s = Pet.State()
    if s.unchosen then return end
    local ok, what, anim = Rules.Trick(s, Now(), Pet.Pick)
    said = what
    if ok then
        walk.chase = nil
        if Pet.Play(walk, Sheet(), anim) or Pet.Play(walk, Sheet(), "jump") then Pet.Sound("pat") end
    end
    Refresh()
end

-- The pointer in its pen: wiggled, it's something to chase. It runs after
-- it for CHASE seconds, and when it gets there it pounces (Rules.Pounce).
local function Chase(sheet, dt)
    local chase = walk.chase
    if pen.held or pen.toss or walk.errand or walk.act or not pen:IsMouseOver() then
        pen.trail = nil
        if chase then walk.chase, walk.running = nil, nil end
        return
    end
    local x, y = Compat.CursorAt(pen)
    if not x then return end
    if not chase then
        pen.trail = pen.trail or {}
        if Pet.Trail(pen.trail, x, y, dt) then walk.chase, pen.trail = { left = CHASE }, nil end
        return
    end
    chase.left = chase.left - dt
    -- Its feet to the pointer, as when it's called over.
    local size = walk.size
    local tx = math.max(0, math.min(PEN_W - size, math.floor(x - size / 2)))
    local ty = math.max(math.max(0, math.floor(GRASS - size * 0.92)), math.min(PEN_H - size, math.floor(y - size * 0.96)))
    local dx, dy = tx - walk.x, ty - walk.y
    if dx * dx + dy * dy <= 36 then
        walk.chase, walk.running, walk.wait = nil, nil, 1
        local _, what = Rules.Pounce(Pet.State(), Now())
        Pet.Play(walk, sheet, "jump")
        Pet.Sound("play")
        said = what
        Refresh()
    elseif chase.left <= 0 then
        walk.chase, walk.running = nil, nil
    else
        walk.tx, walk.ty, walk.wait, walk.running = tx, ty, 0, true
        if dx ~= 0 then walk.facing = dx > 0 and "right" or "left" end
    end
end

-- Food and play in the pen, moved on by `dt`: what's in your hand waits only
-- so long, and an errand says what happened as it goes.
local function Tend(sheet, dt)
    local held = pen.held
    if held and held.scrub then
        -- The brush: it stands still for it, and rubbing the pointer over it
        -- is the scrubbing. Rubbed enough, it's clean, with a sparkle.
        walk.tx, walk.ty, walk.wait = walk.x, walk.y, math.max(walk.wait, 0.5)
        local x, y = Compat.CursorAt(pen)
        local on = x and x >= walk.x and x <= walk.x + walk.size and y >= walk.y and y <= walk.y + walk.size
        if on and held.px then
            local moved = math.abs(x - held.px) + math.abs(y - held.py)
            if moved > 0 then held.scrub, held.clock = held.scrub + math.min(moved, 60), 0 end
        end
        held.px, held.py = on and x or nil, on and y or nil
        if held.scrub >= SCRUB then
            pen.held = nil
            if Pet.Play(walk, sheet, held.show) then
                walk.act.effect, walk.act.clock = held.over, walk.act.length / 2
            end
            Pet.Sound(held.sound)
            said = held.what
            Refresh()
        end
    end
    held = pen.held
    if held then
        held.clock = held.clock + dt
        if held.clock >= HOLD then Pet.SetDown() end
    end
    local toss = pen.toss
    if toss then
        toss.clock = toss.clock + dt
        walk.wait = math.max(walk.wait, 0.5)
        if toss.clock >= TOSS then
            -- Nobody caught it: it's on the grass, and eaten there.
            pen.toss, walk.act = nil, nil
            if Pet.Play(walk, sheet, "eat") then walk.act.prop = "treat" end
            Pet.Sound(toss.sound)
            said = "Missed. It eats it off the grass."
            Refresh()
        end
    end
    local errand = walk.errand
    local did = Pet.Errand(walk, sheet, dt)
    if did == "there" then
        Pet.Sound(errand.sound)
        said = errand.what
        Refresh()
    elseif did == "back" then
        said = errand.throws < THROWS and "It brings it back. Click the grass to throw it again." or "It brings it back, puffed and pleased."
        Refresh()
    end
    Chase(sheet, dt)
end

-- Where you dragged it to is kept.
local function Dropped()
    window:StopMovingOrSizing()
    local point, _, relative, x, y = window:GetPoint(1)
    -- The window and the creature out with you each have a place of their own.
    if point then ns.db[window.out and "petOutAt" or "petAt"] = { point, relative, x, y } end
end

-- Puts the window where it was last left in the way it's showing now: as a
-- window, or out with you (the first time, low in the middle of the screen).
local function Place()
    local at = window.out and ns.db.petOutAt or not window.out and ns.db.petAt
    window:ClearAllPoints()
    if type(at) == "table" and at[1] then
        window:SetPoint(at[1], UIParent, at[2] or at[1], at[3] or 0, at[4] or 0)
    elseif window.out then
        -- The first time: at the very foot of the screen, a little right of the
        -- middle, clear of where the action bars usually are. Dragged, it stays put.
        local wide = UIParent and UIParent.GetWidth and UIParent:GetWidth() or 1366
        window:SetPoint("BOTTOM", UIParent, "BOTTOM", math.floor(wide * 0.23), 0)
    else
        window:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    end
end

-- Out with you, it's one of the pieces Unlock Mode moves (/jsal unlock):
-- named, sized as its strip, and kept in the same spot it's dragged to.
local function Movable()
    if not (ns.Unlock and ns.Unlock.Add) or Pet.movable then return end
    Pet.movable = true
    ns.Unlock.Add({
        key = "Companion", label = "your pal",
        frame = function() return window and window.out and window or nil end,
        size = function() return stripW, stripH end,
        load = function() return ns.db.petOutAt end,
        save = function(point, relative, x, y)
            ns.db.petOutAt = point and { point, relative, x, y } or nil
            if window and window.out then Place() end
        end,
    })
end
Pet.Movable = Movable

-- Escape closes the whole window, like the game's own. The pen on its own
-- is something you leave on screen, so Escape leaves it be.
local function Escapes(on)
    if not UISpecialFrames then return end
    for i = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[i] == "jsalUIPetWindow" then table.remove(UISpecialFrames, i) end
    end
    if on then table.insert(UISpecialFrames, "jsalUIPetWindow") end
end

-- The button beside it: a speaker while its sounds are on, crossed out while they're off.
local function PaintMute()
    local file = Art(ns.OptionOn("pet", "sound") and "sound_on" or "sound_off")
    if mute.file ~= file then
        mute.file = file
        mute.icon:SetTexture(file, "CLAMP", "CLAMP", "NEAREST")
    end
end

-- Its sounds off, or on again: the button in the pen's corner, and the same
-- switch as Sounds under Companion in Settings. Turned on, it chirps to say so.
function Pet.Mute()
    ns.SetOption("pet", "sound", not ns.OptionOn("pet", "sound"))
    if mute then PaintMute() end
    Pet.Sound("pat")
end

-- The whole window, or just the pen with its creature: the small button in
-- the pen's corner swaps between them, and which you chose is kept.
function Layout()
    -- Choosing an egg, it's the whole pen and one line under it, never just the pen.
    local picking = window.picking == true
    -- Out with you: not while there's an egg to choose or a hatchling to name.
    local out = ns.db.petOut == true and not picking and not Pet.State().unnamed
    local small = ns.db.petCompact == true and not picking and not out
    local moved = window.out ~= out
    window.out = out
    window.bar:SetShown(not small and not out)
    parts:SetShown(not small and not out and not picking and not window.yard)
    yardParts:SetShown(window.yard == true and not small and not out and not picking)
    bookToggle:SetShown(window.yard == true and not small and not out and not picking)
    pickLine:SetShown(picking)
    -- Out with you, its buttons are only there while the pointer is over it.
    pen.over = nil
    fold:SetShown(not picking and not out)
    mute:SetShown(not picking and not out)
    outButton:SetShown(not picking and not out and not window.yard)
    sizeButton:Hide()
    sizeButton:SetLabel(("%dx"):format(Pet.OutScale()))
    PaintMute()
    -- Nothing of a window is left then: no fill, no edges, no meadow, and
    -- nothing that would catch a click meant for the game but the creature.
    for _, piece in ipairs(chrome) do piece:SetShown(not out) end
    ground:SetShown(out)
    pen:SetClipsChildren(not out)
    pen:EnableMouse(not out)
    window:EnableMouse(not out)
    window:SetFrameStrata(out and "LOW" or "HIGH")
    pen:ClearAllPoints()
    -- As large as suits this screen, with a strip and a shadow to match.
    local times = Pet.OutScale()
    outSize, stripW, stripH = 64 * times, 130 + 130 * times, STRIP_TOP + 64 * times
    ground:SetSize(40 * times, 10 * times)
    pen:SetSize(out and stripW or PEN_W, out and stripH or PEN_H)
    if out then
        pen:SetPoint("TOPLEFT", 0, 0)
        window:SetSize(stripW, stripH)
    elseif small then
        pen:SetPoint("TOPLEFT", 1, -1)
        window:SetSize(PEN_W + 2, PEN_H + 2)
    elseif picking then
        pen:SetPoint("TOPLEFT", PAD, -(32 + PAD))
        window:SetSize(WIN_W, 32 + PAD + PEN_H + 50)
    else
        pen:SetPoint("TOPLEFT", PAD, -(32 + PAD))
        window:SetSize(WIN_W, WIN_H)
    end
    -- Droppings: on the grass of the pen, or in a row along the strip.
    for i, heap in ipairs(heaps) do
        heap:ClearAllPoints()
        if out then
            heap:SetPoint("BOTTOMLEFT", 8 + (i - 1) * 62, 0)
        else
            heap:SetPoint("TOPLEFT", HEAP_AT[i], -(PEN_H - 40 - (i % 2) * 26))
        end
    end
    if moved then
        Place()
        if window.SetAlpha then window:SetAlpha(1) end
        pen.quiet = nil
    end
    fold:SetLabel((small or out) and "+" or "-")
    Escapes(not small and not out)
end

-- The fold button: the whole window, or just the pen. Out with you, it
-- brings the window back.
function Pet.Fold()
    if ns.db.petOut then
        ns.db.petOut = nil
    else
        ns.db.petCompact = ns.db.petCompact ~= true and true or nil
    end
    if window then
        Layout()
        Refresh()
    end
end

-- Its window is built in four parts, each a function of its own, and not
-- for tidiness: the game's Lua lets one function use at most 60 variables
-- from outside itself, and one function building everything used 74, so the
-- game refused the whole file (12 Nov; the tests' newer Lua allows 255, and
-- limits_test now counts them). Keep each part well under.
local function BuildPen()
    window = Style.Panel("jsalUIPetWindow", WIN_W, WIN_H, "Jsal's Pals")
    title = window.title
    window.bar:SetScript("OnDragStop", Dropped)
    -- Shown or not is kept too, so the pen you left out is there next time.
    -- (Hidden along with the whole interface, it still counts as shown.)
    window:SetScript("OnShow", function() ns.db.petShown = true end)
    window:SetScript("OnHide", function() ns.db.petShown = window:IsShown() and true or nil end)

    pen = CreateFrame("Frame", nil, window)
    pen:SetSize(PEN_W, PEN_H)
    pen:SetPoint("TOPLEFT", PAD, -(32 + PAD))
    pen:SetClipsChildren(true)
    pen.edges = Style.Border(pen, "cardLine")
    -- The meadow: pixel art at half the pen's size, so its pixels match the
    -- creature's. It sits in the top left 170 by 100 of a 256 by 128 picture.
    local scene = pen:CreateTexture(nil, "BACKGROUND")
    pen.scene = scene
    scene:SetAllPoints()
    scene:SetTexture(Art("meadow"), "CLAMP", "CLAMP", "NEAREST")
    scene:SetTexCoord(0, 220 / 256, 0, 100 / 128)
    Compat.Crisp(scene)
    local night = pen:CreateTexture(nil, "BACKGROUND", nil, 2)
    pen.night = night
    night:SetAllPoints()
    night:SetTexture(Art("meadow_night"), "CLAMP", "CLAMP", "NEAREST")
    night:SetTexCoord(0, 220 / 256, 0, 100 / 128)
    night:SetAlpha(0)
    Compat.Crisp(night)
    -- Between the two, the meadow at sunset: dusk and dawn pass through it.
    local dusk = pen:CreateTexture(nil, "BACKGROUND", nil, 1)
    pen.dusk = dusk
    dusk:SetAllPoints()
    dusk:SetTexture(Art("meadow_dusk"), "CLAMP", "CLAMP", "NEAREST")
    dusk:SetTexCoord(0, 220 / 256, 0, 100 / 128)
    dusk:SetAlpha(0)
    Compat.Crisp(dusk)
    -- The pen can be dragged too: with only the pen showing, it's all there is to hold.
    pen:EnableMouse(true)
    pen:RegisterForDrag("LeftButton")
    pen:SetScript("OnDragStart", function()
        pen.dragged = true
        window:StartMoving()
    end)
    pen:SetScript("OnDragStop", Dropped)
    -- A click on the grass (not the end of a drag) is for the creature.
    pen:SetScript("OnMouseUp", ns.Safe(Pet, function(_, button)
        if pen.dragged then
            pen.dragged = nil
        elseif button == nil or button == "LeftButton" then
            Pet.Clicked()
        end
    end))

    -- Droppings: click one to scoop it.
    for i, x in ipairs(HEAP_AT) do
        local heap = CreateFrame("Button", nil, pen)
        heap:SetSize(HEAP_W, HEAP_W)
        local pile = heap:CreateTexture(nil, "ARTWORK")
        pile:SetAllPoints()
        pile:SetTexture(Art("dropping"), "CLAMP", "CLAMP", "NEAREST")
        Compat.Crisp(pile)
        heap.pile = pile
        heap:SetScript("OnClick", function() Do(Rules.Scoop, nil, nil, nil, "scoop") end)
        heap:Hide()
        heaps[i] = heap
    end

    -- The creature: click it for a pat.
    body = CreateFrame("Button", nil, pen)
    body:SetSize(SIZE, SIZE)
    sprite = body:CreateTexture(nil, "ARTWORK")
    sprite:SetAllPoints()
    Compat.Crisp(sprite)
    body:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    body:SetScript("OnClick", function(_, button) Pet.Petted(button) end)
    -- Out with you, the creature is all there is to hold: drag it to move it.
    body:RegisterForDrag("LeftButton")
    body:SetScript("OnDragStart", function() if window.out then window:StartMoving() end end)
    body:SetScript("OnDragStop", function() if window.out then Dropped() end end)
    -- And it has a small shadow under its feet, so it stands on something.
    ground = pen:CreateTexture(nil, "BACKGROUND")
    ground:SetSize(40, 10)
    ground:SetPoint("BOTTOM", body, "BOTTOM", 0, 0)
    ground:SetTexture(Art("shadow"), "CLAMP", "CLAMP", "NEAREST")
    ground:SetTexCoord(0, 40 / 64, 0, 10 / 16)     -- the oval is in the corner of a 64 by 16 picture
    Compat.Crisp(ground)
    ground:Hide()
    chrome = { pen.scene, pen.dusk, pen.night }
    chrome[#chrome + 1] = window.fill
    for _, pieces in ipairs({ window.edges or {}, window.shadow or {}, pen.edges or {} }) do
        for _, piece in ipairs(pieces) do chrome[#chrome + 1] = piece end
    end
    prop = pen:CreateTexture(nil, "ARTWORK")
    prop:SetSize(HEAP_W, HEAP_W)
    Compat.Crisp(prop)
    prop:Hide()
    -- And what's in your hand, on a layer of its own above the creature.
    local above = CreateFrame("Frame", nil, pen)
    above:SetAllPoints()
    above:SetFrameLevel(40)
    pen.hand = above:CreateTexture(nil, "OVERLAY")
    pen.hand:SetSize(HEAP_W, HEAP_W)
    Compat.Crisp(pen.hand)
    pen.hand:Hide()
    bubble = body:CreateTexture(nil, "OVERLAY", nil, 2)
    bubble:SetSize(32, 32)
    bubble:SetTexture(Art("bubble"), "CLAMP", "CLAMP", "NEAREST")
    Compat.Crisp(bubble)
    bubble:Hide()
    effect = body:CreateTexture(nil, "OVERLAY")
    effect:SetAllPoints()
    Compat.Crisp(effect)
    effect:Hide()
    snore = Style.Text(body, 15, "secondary", nil, true)
    snore:SetPoint("BOTTOMLEFT", body, "TOPRIGHT", -26, -20)
    snore:SetText("z z z")

    -- Only while the page is showing: a hidden frame gets no updates.
    local since, pace = 0, 0
    pen:SetScript("OnUpdate", ns.Safe(Pet, function(_, elapsed)
        -- However fast the game draws, it's only looked at thirty times a second.
        pace = pace + elapsed
        if pace < FRAME then return end
        elapsed, pace = pace, 0
        if window.out then
            pen.held, pen.toss = nil, nil
            -- Out with you, it keeps out of a fight: faint and still until it's over.
            local quiet = Compat.InCombat() and true or false
            if quiet ~= pen.quiet then
                local won = pen.quiet == true and not Compat.Dead()
                pen.quiet = quiet
                window:SetAlpha(quiet and 0.25 or 1)
                -- A fight you came through: one time in three, it's glad of it.
                if won and math.random(1, 3) == 1 then Pet.React("won") end
            end
            if quiet then return end
            -- And its two buttons are there only while the pointer is over it.
            local over = pen:IsMouseOver() and true or false
            if over ~= pen.over then
                pen.over = over
                fold:SetShown(over)
                mute:SetShown(over)
                sizeButton:SetShown(over)
            end
            -- Standing about, it turns to look at the pointer when that comes near.
            if over and walk and walk.wait > 0 and not walk.act and not walk.nap then
                local x = Compat.Cursor(pen)
                if x then walk.facing = x < walk.x + walk.size / 2 and "left" or "right" end
            end
        end
        Pet.tick = (Pet.tick or 0) + elapsed
        -- The paddock: its settled companions go about their day, and nothing else moves.
        if yard then
            local dt = math.min(elapsed, 0.1)
            for _, r in ipairs(roamers) do
                if r.record then
                    Pet.Roam(r, dt, math.random)
                    PaintRoamer(r)
                end
            end
            return
        end
        -- Dusk and dawn: the day goes, or comes back, a little each frame.
        if pen.shade and pen.shade ~= pen.dark then
            local by = math.min(elapsed, 0.1) / DUSK
            pen.shade = pen.dark > pen.shade and math.min(pen.dark, pen.shade + by) or math.max(pen.dark, pen.shade - by)
            Sky()
        end
        if not walk then return end
        -- A long hitch (a loading screen) shouldn't fling it across the pen.
        local dt = math.min(elapsed, 0.1)
        if Pet.State().asleep then
            -- Asleep, it stays put, eyes shut, once it has settled down.
            walk.errand, pen.held, pen.toss = nil, nil, nil
            if walk.act then Pet.Step(walk, dt, math.random) end
            if not walk.act then walk.frame = "sleep" end
            walk.wait = math.max(walk.wait, 0.5)
        else
            local sheet = Sheet()
            -- Out with you, it goes by how you're getting about.
            local going = window.out and sheet and Pet.How(elapsed) or nil
            if going and Pet.Pace(walk, sheet, going, dt) then Pet.React("hello") end
            if walk.nap then
                -- Napping while you're away: as when it's asleep, till you're back.
                if walk.act then Pet.Step(walk, dt, math.random) end
                if not walk.act then walk.frame = "sleep" end
                walk.wait = math.max(walk.wait, 0.5)
            else
                if not window.out then Tend(sheet, dt) end
                local walking = walk.wait <= 0
                Pet.Step(walk, dt, math.random)
                -- Just arrived somewhere, and not hurrying after you: now and then it does something.
                local moving = going and going.moving
                if not moving then walk.whim = nil end
                if sheet and not walk.act and not walk.errand and not walk.chase then
                    -- At rest, as it arrives somewhere; on the move with you, wherever it
                    -- is on its strip when the whim takes it. It stops, does it, and goes on.
                    local due
                    if moving then
                        due = Pet.Whim(walk, dt, math.random)
                    else
                        due = walking and walk.wait > 0
                    end
                    local pick = due and Pet.Idle(math.random, moving, Pet.State().sick)
                    if pick then Pet.Play(walk, sheet, pick) end
                end
            end
        end
        PaintWalk()
        -- Its needs move slowly: look again twice a minute.
        since = since + elapsed
        if since >= 30 then
            since = 0
            Refresh()
        end
    end))

    -- In the pen's corner: show only the pen, or everything again.
    fold = Style.Button(pen, "-", "plain", 20)
    fold:SetHeight(20)
    fold:SetPoint("TOPRIGHT", -4, -4)
    fold:SetFrameLevel(50)
    fold:SetAlpha(0.75)
    fold:SetScript("OnClick", function() Pet.Fold() end)

    -- Beside it: the companion's sounds off, or on again.
    mute = Style.Button(pen, "", "plain", 20)
    mute:SetHeight(20)
    mute:SetPoint("TOPRIGHT", -28, -4)
    mute:SetFrameLevel(50)
    mute:SetAlpha(0.75)
    mute.icon = mute:CreateTexture(nil, "OVERLAY")
    mute.icon:SetSize(16, 16)
    mute.icon:SetPoint("CENTER")
    Compat.Crisp(mute.icon)
    mute:SetScript("OnClick", function() Pet.Mute() end)

    -- And beside that: out of its window, to walk about with you as you play.
    outButton = Style.Button(pen, "Out", "plain", 36)
    outButton:SetHeight(20)
    outButton:SetPoint("TOPRIGHT", -52, -4)
    outButton:SetFrameLevel(50)
    outButton:SetAlpha(0.75)
    outButton:SetScript("OnClick", function() Pet.Out() end)

    -- Out with you, in that button's place while the pointer is over it: how
    -- large it's drawn, once, twice or three times its art. A click goes round them.
    sizeButton = Style.Button(pen, "1x", "plain", 28)
    sizeButton:SetHeight(20)
    sizeButton:SetPoint("TOPRIGHT", -52, -4)
    sizeButton:SetFrameLevel(50)
    sizeButton:SetAlpha(0.75)
    sizeButton:SetScript("OnClick", function() Pet.Resize() end)
    sizeButton:Hide()

    -- In the pen's other corner: over to the paddock, and back.
    yardToggle = Style.Button(pen, "Paddock", "plain", 92)
    yardToggle:SetHeight(20)
    yardToggle:SetPoint("TOPLEFT", 4, -4)
    yardToggle:SetFrameLevel(50)
    yardToggle:SetAlpha(0.85)
    yardToggle:SetScript("OnClick", function() Pet.Paddock() end)

end

local function BuildYard()
    -- Under the pen while the paddock shows: who has settled, then the album.
    yardParts = CreateFrame("Frame", nil, window)
    yardParts:SetPoint("TOPLEFT", pen, "BOTTOMLEFT", 0, 0)
    yardParts:SetSize(PEN_W, WIN_H - PEN_H - 32 - PAD)
    yardParts:Hide()
    yardList = CreateFrame("Frame", nil, yardParts)
    yardList:SetAllPoints()
    yardHead = Style.Text(yardList, 12, "text")
    yardHead:SetPoint("TOPLEFT", 0, -10)
    yardHead:SetWidth(PEN_W)
    for i = 1, YARD_MAX do
        local row = Style.Text(yardList, 12, "secondary")
        row:SetPoint("TOPLEFT", 0, -(34 + (i - 1) * 20))
        row:SetWidth(PEN_W)
        row:SetWordWrap(false)
        yardRows[i] = row
    end
    albumLine = Style.Text(yardList, 12, "text")
    albumLine:SetPoint("TOPLEFT", 0, -(44 + YARD_MAX * 20))
    for i = 1, #Rules.KINDS do
        local picture = yardList:CreateTexture(nil, "ARTWORK")
        picture:SetSize(64, 64)
        -- Side by side across the pen, however many kinds there are.
        picture:SetPoint("TOPLEFT", (i - 1) * math.floor((PEN_W - 64) / (#Rules.KINDS - 1)), -(64 + YARD_MAX * 20))
        Compat.Crisp(picture)
        album[i] = picture
    end

    -- The album, in the list's place when its button is pressed: a column
    -- for each kind, its three forms down it at the art's own size (a still
    -- is as large as a cell of its sheet), each with its name under it.
    bookToggle = Style.Button(pen, "Album", "plain", 64)
    bookToggle:SetHeight(20)
    bookToggle:SetPoint("TOPLEFT", 100, -4)
    bookToggle:SetFrameLevel(50)
    bookToggle:SetAlpha(0.85)
    bookToggle:SetScript("OnClick", function() Pet.Album() end)
    bookToggle:Hide()
    yardBook = CreateFrame("Frame", nil, yardParts)
    yardBook:SetAllPoints()
    yardBook:Hide()
    bookHead = Style.Text(yardBook, 12, "text")
    bookHead:SetPoint("TOPLEFT", 0, -10)
    -- Four kinds to a page, each in a column a quarter of the pen wide, and
    -- arrows at the top right to turn the page.
    local wide = math.floor(PEN_W / BOOK_PAGE)
    bookTurn.on = Style.Button(yardBook, ">", "plain", 24)
    bookTurn.on:SetHeight(20)
    bookTurn.on:SetPoint("TOPRIGHT", 0, -6)
    bookTurn.on:SetScript("OnClick", function() Pet.AlbumPage(1) end)
    bookTurn.count = Style.Text(yardBook, 12, "secondary")
    bookTurn.count:SetPoint("RIGHT", bookTurn.on, "LEFT", -6, 0)
    bookTurn.back = Style.Button(yardBook, "<", "plain", 24)
    bookTurn.back:SetHeight(20)
    bookTurn.back:SetPoint("RIGHT", bookTurn.count, "LEFT", -6, 0)
    bookTurn.back:SetScript("OnClick", function() Pet.AlbumPage(-1) end)
    for i, kind in ipairs(Rules.KINDS) do
        local slot = (i - 1) % BOOK_PAGE
        book[i] = { page = math.floor((i - 1) / BOOK_PAGE) + 1 }
        for form, foot in ipairs(BOOK_ROWS) do
            local size = SHEETS[Rules.SPECIES[kind].sprites[form]].cell
            local picture = yardBook:CreateTexture(nil, "ARTWORK")
            picture:SetSize(size, size)
            picture:SetPoint("BOTTOM", yardBook, "TOPLEFT", slot * wide + wide / 2, -foot)
            Compat.Crisp(picture)
            local name = Style.Text(yardBook, 11, "secondary")
            name:SetPoint("TOP", yardBook, "TOPLEFT", slot * wide + wide / 2, -(foot + 2))
            name:SetWidth(wide)
            name:SetJustifyH("CENTER")
            name:SetWordWrap(false)
            book[i][form] = { picture = picture, name = name }
        end
    end

end

local function BuildPicks()
    -- For a new player: three eggs on the grass, each with its name over it,
    -- and a line under the pen that says what to do and what a click found.
    pickLine = Style.Text(window, 12, "text")
    pickLine:SetPoint("TOPLEFT", pen, "BOTTOMLEFT", 0, -12)
    pickLine:SetWidth(PEN_W)
    pickLine:Hide()
    for i = 1, Rules.OFFERED do
        local pick = CreateFrame("Button", nil, pen)
        pick:SetSize(64, 84)
        pick:SetPoint("BOTTOM", pen, "BOTTOMLEFT", math.floor(PEN_W * i / 4), 24)
        -- The bottom middle of its picture, where the egg stands, at twice its size like a creature.
        pick.picture = pick:CreateTexture(nil, "ARTWORK")
        pick.picture:SetSize(64, 64)
        pick.picture:SetPoint("BOTTOM", 0, 0)
        pick.picture:SetTexCoord(0.25, 0.75, 0.5, 1)
        Compat.Crisp(pick.picture)
        -- Which egg it is, and so its picture and name, is said when it's shown (Refresh).
        pick.name = Style.Text(pick, 12, "text", nil, true)
        pick.name:SetPoint("TOP", 0, 0)
        pick:SetScript("OnClick", function() Pet.Choose(i) end)
        pick:Hide()
        picks[i] = pick
    end

end

local function BuildParts()
    -- Everything under the pen hangs from this, PEN_H down from the pen's top.
    parts = CreateFrame("Frame", nil, window)
    parts:SetPoint("TOPLEFT", pen, "BOTTOMLEFT", 0, 0)
    parts:SetSize(PEN_W, WIN_H - PEN_H - 32 - PAD)

    -- How it is, its age and when it grows.
    sub = Style.Text(parts, 12, "secondary")
    sub:SetPoint("TOPLEFT", 0, -10)
    sub:SetWidth(PEN_W)
    sub:SetWordWrap(false)

    -- The four needs, two to a row.
    local half = math.floor(PEN_W / 2)
    for i, need in ipairs(Rules.NEEDS) do
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        local label = Style.Text(parts, 12, "secondary")
        label:SetPoint("TOPLEFT", col * half, -(34 + row * 22))
        label:SetText(NEED_NAME[need])
        local track = parts:CreateTexture(nil, "ARTWORK")
        track:SetPoint("TOPLEFT", col * half + 54, -(39 + row * 22))
        track:SetSize(half - 66, 6)
        track:SetColorTexture(Style.Color("titleBar"))
        local fill = parts:CreateTexture(nil, "OVERLAY")
        fill:SetPoint("TOPLEFT", track, "TOPLEFT")
        fill:SetHeight(6)
        bars[need] = { fill = fill, width = half - 66 }
    end

    -- Today's wish, then the bond, then what just happened.
    wishLine = Style.Text(parts, 12, "text")
    wishLine:SetPoint("TOPLEFT", 0, -84)
    wishLine:SetWidth(PEN_W)
    wishLine:SetWordWrap(false)
    bondLine = Style.Text(parts, 12, "secondary")
    bondLine:SetPoint("TOPLEFT", 0, -102)
    message = Style.Text(parts, 12, "gold")
    message:SetPoint("TOPLEFT", 0, -122)
    message:SetWidth(PEN_W)
    message:SetWordWrap(false)

    -- Care, three to a row, each button with how many it has left.
    local count = 0
    local function Care(key, act, show, thing, over, sound)
        local b = Style.Button(parts, "", "plain", 141)
        b:SetHeight(28)
        b:SetPoint("TOPLEFT", (count % 3) * 149, -(146 + math.floor(count / 3) * 34))
        b:SetScript("OnClick", function() Do(act, show, thing, over, sound) end)
        care[key] = b
        count = count + 1
    end
    Care("meal", Rules.Feed, "eat", "bowl", nil, "eat")
    Care("treat", Rules.Treat, "eat", "treat", nil, "eat")
    Care("toy", Rules.Play, "jump", "ball", nil, "play")
    Care("soap", Rules.Bath, "idle", nil, "bath", "bath")
    Care("lights", Rules.Lights, "lights", nil, nil, "lights")
    Care("medicine", Rules.Medicine, "idle", nil, "well", "well")
    local hint = Style.Text(parts, 11, "muted")
    hint:SetPoint("TOPLEFT", 0, -220)
    hint:SetWidth(PEN_W)
    hint:SetText("Quests bring meals, flights bring toys, fishing and Cooking bring treats, First Aid medicine, a new level some of each. Click it for a pat, right-click for a trick, the grass to call it over, a dropping to scoop it.")
    -- The eggs you hold: what they are, then one picture each to click.
    eggLine = Style.Text(parts, 12, "secondary")
    eggLine:SetPoint("TOPLEFT", 0, -258)
    eggLine:SetWidth(PEN_W)
    eggLine:SetWordWrap(false)
    for i = 1, Rules.MAX_EGGS do
        local slot = CreateFrame("Button", nil, parts)
        slot:SetSize(EGG_W + 8, EGG_W + 4)
        slot:SetPoint("TOPLEFT", (i - 1) * (EGG_W + 12), -278)
        slot.picture = slot:CreateTexture(nil, "ARTWORK")
        slot.picture:SetSize(EGG_W, EGG_W)
        slot.picture:SetPoint("BOTTOM", 0, 0)
        slot.picture:SetTexCoord(0.25, 0.75, 0.5, 1)
        Compat.Crisp(slot.picture)
        slot:SetScript("OnClick", function() Pet.HatchEgg(i) end)
        slot:Hide()
        eggSlots[i] = slot
    end
    -- Beside the eggs, only while a new hatchling is being named: a box for
    -- its name and a button to confirm it. Enter does the same; Escape, or
    -- confirming the name offered, keeps that name.
    renameButton = Style.Button(parts, "Confirm", "plain", 141)
    renameButton:SetHeight(28)
    renameButton:SetPoint("TOPLEFT", 298, -282)
    nameBox = Style.Field(parts, 141)
    nameBox.well:SetPoint("TOPLEFT", 149, -283)
    nameBox.well:Hide()
    nameBox:SetMaxLetters(16)
    nameBox:SetScript("OnEnterPressed", TakeName)
    nameBox:SetScript("OnEscapePressed", function()
        -- Escape keeps the name it has, and that settles it for a new hatchling too.
        Pet.State().unnamed = nil
        NameBox(false)
    end)
    renameButton:SetScript("OnClick", TakeName)
    renameButton:Hide()
end

local function Build()
    BuildPen()
    BuildYard()
    BuildPicks()
    BuildParts()
    Layout()
    Place()
end

local function IsOpen()
    return window ~= nil and window:IsShown() == true
end

-- /jsal pet, the dashboard's menu and Today all come here: its window opens,
-- or closes if it was open.
function Pet.Open()
    if not Pet.running then
        return ns.Print("Jsal's Pals is turned off. /jsal settings turns it on.")
    end
    if not window then Build() end
    if IsOpen() then return window:Hide() end
    said, Pet.armed, yard, albumOpen = nil, nil, false, false
    pen.shade = nil     -- opened, it's day or night at once, with no fade
    Layout()            -- as it was left: a window, the pen alone, or out with you
    Refresh()
    window:Show()
end

---------------------------------------------------------------------------
-- Supplies from your play.
---------------------------------------------------------------------------
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
        said = ("%s's wish is granted."):format(s.name) .. (more and (" " .. more) or "")
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
    if window and window:IsShown() then
        said = kind == "fishing" and "A treat, from your catch." or kind == "cooking" and "A treat, from your cooking." or "Medicine, from your bandaging."
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
    if not Rules.CanFind(Pet.State()) then return false end
    local kind = Rules.EggFrom(source, roll or Pet.Luck())
    if not kind then return false end
    local where = ZoneName() or "your travels"
    if not Rules.FindEgg(Eggs(), kind, where, Now()) then return false end
    local name = Rules.EGGS[kind].name
    local a = name:find("^[AEIOU]") and "an" or "a"
    ns.Print(("You found %s %s in %s! /jsal pet shows your eggs."):format(a, name, where))
    Pet.Sound("fanfare")
    Pet.React("glad")
    local J = ns.Journal
    if J and J.running then J.Note("pet", ("Found %s %s in %s"):format(a, name, where)) end
    if IsOpen() then
        said = ("You found %s %s!"):format(a, name)
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
    yard, albumOpen = not yard, false
    looking, said = nil, nil
    pen.shade = nil     -- back from the paddock, it's day or night at once
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
    ns.db.petOut = ns.db.petOut ~= true and true or nil
    yard, albumOpen, looking, walk = false, false, nil, nil
    pen.shade = nil
    Layout()
    Refresh()
end
ns.Command("pet out", Pet.Out)

-- The size button over it when it's out: once, twice or three times the
-- art's size, round and round, and kept.
function Pet.Resize()
    ns.db.petOutTimes = Pet.OutScale() % 3 + 1
    if not (window and window:IsShown()) then return end
    walk = nil
    Layout()
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
    if not (what and IsOpen() and walk) or yard then return false end
    local s = Pet.State()
    if s.unchosen or s.asleep or walk.nap then return false end
    -- A form with no such animation hops instead.
    if not (Pet.Play(walk, Sheet(), what.show) or Pet.Play(walk, Sheet(), "jump")) then return false end
    walk.act.prop = what.prop
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
    if not (anim and Pet.running and IsOpen() and walk) or yard or pen.held or pen.toss or walk.errand then return false end
    local s = Pet.State()
    if s.unchosen or s.asleep or walk.nap then return false end
    walk.chase = nil
    if not (Pet.Play(walk, Sheet(), anim) or Pet.Play(walk, Sheet(), "jump")) then return false end
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
    if not (window and window:IsShown() and yard) then return end
    albumOpen = not albumOpen
    if albumOpen then albumPage = 1 end
    Refresh()
end

-- The album's arrows: the next page or the one before, round again past the ends.
function Pet.AlbumPage(step)
    if not albumOpen then return end
    local pages = math.ceil(#Rules.KINDS / BOOK_PAGE)
    albumPage = (albumPage - 1 + (step or 1)) % pages + 1
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
    said = what
    if IsOpen() then Refresh() end
    return ok
end

-- A new player's choice between the three eggs. With the window open the
-- first click on an egg only tells you about it, and a second on the same
-- one makes it yours: it hatches there in the pen, with whatever your play
-- had already earned.
function Pet.Choose(index)
    local s = Pet.State()
    local kind = s.unchosen and Rules.EGGS[Offer()[index] or ""]
    if not kind then return end
    if IsOpen() and Pet.armed ~= index then
        Pet.armed = index
        said = ("The %s. %s Click it again to make it yours."):format(kind.name, kind.hint)
        return Refresh()
    end
    Pet.armed = nil
    local young = Rules.New(Now(), nil, kind.species)
    for supply, count in pairs(s.supplies) do
        young.supplies[supply] = math.max(young.supplies[supply] or 0, count)
    end
    young.unnamed = true
    ns.db.pet = young
    looking, walk = nil, nil
    said = ("It's hatching! Name your %s: type a name and press Enter."):format(FormName(young, 1))
    if window then Refresh() end
end

-- A click on one of your eggs. A fully grown companion can settle in the
-- paddock, and the egg hatches in its place: that can't be undone, so the
-- first click only says what will happen and the second does it.
function Pet.HatchEgg(index)
    local s, eggs = Pet.State(), Eggs()
    local egg = eggs[index]
    local kind = egg and Rules.EGGS[egg.kind]
    if not kind then return end
    local ok, why = Rules.CanSettle(s, eggs)
    if not ok then
        Pet.armed = nil
        said = ("%s Once %s is fully grown it can settle in the paddock, and this egg hatches."):format(why, s.name)
    elseif Pet.armed ~= index then
        Pet.armed = index
        said = ("Click again: %s settles in the paddock for good, and the %s hatches."):format(s.name, kind.name)
    else
        Pet.armed = nil
        local old, form = s.name, FormName(s)
        local record, young = Rules.Succeed(s, eggs, index, Now())
        if not record then
            said = young
        else
            local settled = Settled()
            settled[#settled + 1] = record
            ns.db.pet = young
            looking, walk = nil, nil
            local J = ns.Journal
            if J and J.running then
                J.Note("pet", ("%s the %s settled in the paddock after %d day%s"):format(old, form, record.days, record.days == 1 and "" or "s"))
            end
            young.unnamed = true
            said = ("%s has settled in the paddock. Name your new %s: type a name and press Enter."):format(old, FormName(young, 1))
        end
    end
    if IsOpen() then Refresh() end
end

-- A trial (/jsal pet try, /jsal pet new) puts your real companion aside, and
-- only a beta build has the commands that bring it back. So a release that
-- finds one put aside brings it home itself. True when it did.
function Pet.Home()
    local kept = ns.db.petAside
    if Pet.Trials(ns.version) or type(kept) ~= "table" then return false end
    ns.db.pet, ns.db.petEggs, ns.db.petSettled, ns.db.petAside = kept.pet, kept.eggs or {}, kept.settled or {}, nil
    return true
end

function Pet:OnEnable()
    Pet.Home()
    Pet.Movable()
    -- Hear your emotes, once: the game keeps a listener for good.
    if not Pet.hears then
        Pet.hears = Compat.OnEmote(ns.Safe(self, function(token) Pet.Emote(token) end)) or false
    end
    -- A hatchling from the moment the part is switched on, so what you earn
    -- before first opening its page isn't lost.
    Pet.State()
    -- The pen left out on its own comes back after a reload or a login.
    if ns.db.petShown and (ns.db.petCompact or ns.db.petOut) then
        Compat.After(1, function()
            if not (window and window:IsShown()) then Pet.Open() end
            Pet.React("hello")
        end)
    end
    -- Where you are now, so that only going somewhere else counts as a trip.
    local zone = ZoneName()
    Pet.where = zone
    local fished = 0
    local events = CreateFrame("Frame")
    events:RegisterEvent("LOOT_READY")
    events:RegisterEvent("CHAT_MSG_SKILL")
    events:RegisterEvent("QUEST_TURNED_IN")
    events:RegisterEvent("PLAYER_LEVEL_UP")
    events:RegisterEvent("PLAYER_CONTROL_LOST")
    events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    events:RegisterEvent("PLAYER_UNGHOST")
    events:RegisterEvent("PLAYER_DEAD")
    events:RegisterEvent("PLAYER_TARGET_CHANGED")
    events:RegisterEvent("CHAT_MSG_LOOT")
    events:RegisterEvent("CHAT_MSG_TEXT_EMOTE")
    -- Out of a fight. (A boss brought down, ENCOUNTER_END, is kept for rarer
    -- eggs to come: John, 12 Nov 2026.)
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    -- A new spell learned (from a trainer, mostly): the Crystal egg's source.
    -- Not in the first moments after logging in, in case the game says so then.
    events:RegisterEvent("LEARNED_SPELL_IN_SKILL_LINE")
    local learnAfter = Now() + 10
    -- A boss brought down: Onyxia (encounter 1084) may leave the Aurora egg.
    pcall(events.RegisterEvent, events, "ENCOUNTER_END")
    events:SetScript("OnEvent", ns.Safe(self, function(_, event, text, ...)
        -- A chat line can be hidden in a dungeon: then it's nil.
        text = Compat.Plain(text)
        if event == "PLAYER_REGEN_ENABLED" then
            -- A fight you walked away from: once in a long while there's
            -- something in the wreckage.
            if not Compat.Dead() then Pet.Found("fight") end
        elseif event == "ENCOUNTER_END" then
            -- encounterID, encounterName, difficultyID, groupSize, success
            if tonumber(text) == 1084 and Compat.Plain(select(4, ...)) == 1 then Pet.Found("onyxia") end
        elseif event == "LEARNED_SPELL_IN_SKILL_LINE" then
            if Now() >= learnAfter then Pet.Found("learn") end
        elseif event == "LOOT_READY" then
            -- A catch, not a corpse; and the game can say so twice for one catch.
            if Compat.Fished() and Now() - fished >= 2 then
                fished = Now()
                Pet.Extra("fishing")
                Pet.Found("fishing")
            end
        elseif event == "CHAT_MSG_SKILL" then
            -- "Your skill in Cooking has increased to 76."
            if type(text) == "string" then
                if text:find("Cooking", 1, true) then Pet.Extra("cooking")
                elseif text:find("First Aid", 1, true) then Pet.Extra("firstaid") end
            end
        elseif event == "ZONE_CHANGED_NEW_AREA" then
            -- The game also says this as you log in; that isn't a trip.
            local now = ZoneName()
            local moved = now and zone and now ~= zone
            zone = now or zone
            Pet.where = zone
            if window and window:IsShown() then Refresh() end
            if moved then
                Pet.Did("zone")
                Pet.Found("zone")
                Pet.React("zone")
                Pet.Along()
            end
        elseif event == "QUEST_TURNED_IN" then
            Pet.Earn("meal", 1)
            Pet.Did("quest")
            Pet.Found("quest")
            Pet.React("quest")
            Pet.Along()
        elseif event == "PLAYER_LEVEL_UP" then
            Pet.Earn("treat", 2)
            Pet.Earn("soap", 1)
            Pet.Earn("medicine", 1)
            Pet.Found("level")
            Pet.React("level")
            Pet.Along()
        elseif event == "CHAT_MSG_TEXT_EMOTE" then
            -- An emote of yours, by the line it put in chat.
            local emote = Pet.EmoteOf(text)
            if emote then Pet.Emote(emote) end
        elseif event == "PLAYER_TARGET_CHANGED" then
            -- A rare: it perks up, but not every time you look away and back.
            if Compat.TargetRare() and Now() - (Pet.rareAt or 0) >= 30 and Pet.React("rare") then Pet.rareAt = Now() end
        elseif event == "CHAT_MSG_LOOT" then
            -- Yours, and blue or better (by the colour the game gives its name).
            if type(text) == "string" and text:find("^You ") and (text:find("|cff0070dd", 1, true) or text:find("|cffa335ee", 1, true)
                or text:find("|cffff8000", 1, true) or text:find("|cnIQ[345]:")) then
                Pet.React("loot")
            end
        elseif event == "PLAYER_DEAD" then
            Pet.React("died")
        elseif event == "PLAYER_UNGHOST" then
            -- Back among the living, sometimes with something from the other side.
            Pet.Found("ghost")
            Pet.React("back")
        elseif event == "PLAYER_CONTROL_LOST" then
            -- The game takes the controls away as a flight starts (and for
            -- other things): a moment later, see whether you're flying.
            Compat.After(1, ns.Safe(self, function()
                if Compat.OnTaxi() then
                    Pet.Earn("toy", 1)
                    Pet.Did("flight")
                    Pet.Found("flight")
                    Pet.React("flight")
                    Pet.Along()
                end
            end))
        end
    end))
end

ns.Command("pet", function() Pet.Open() end)

-- The commands below this one are for trying things out while it's being
-- made (a look at another form, a trial of settling, making it dirty or
-- poorly on purpose, starting over). They're there only in a beta build, one
-- whose version says so: a release has none of them.
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
        if look == looking then at = i end
    end
    repeat
        at = at + 1
        looking = LOOKS[at]
    until not (looking and Own(looking) and looking.form == s.form)
    walk = nil      -- a new spot, of the size that's drawn now
    said = looking and ((Own(looking) and "A look at it as a %s. /jsal pet look again for the next."
        or "The %s, of a line still to come. /jsal pet look again for the next."):format(looking.name))
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
    if not walk then return end
    if Pet.State().asleep then
        said = "It's asleep."
    elseif Pet.Play(walk, Sheet(), "special") then
        said = nil
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
    if not walk then return end
    if Pet.State().asleep then
        said = "It's asleep."
    elseif Pet.Play(walk, Sheet(), "hatch") then
        said = nil
        Pet.Sound("hatch")
    else
        said = "Only a first form hatches. /jsal pet look shows one."
    end
    Refresh()
end
Trial("pet hatch", Pet.Hatch)

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
        ns.Print("A trial: a fully grown stand-in and three eggs. Click an egg twice to settle it and hatch the egg. /jsal pet try again puts your own pal back.")
    end
    looking, walk, said, Pet.armed = nil, nil, nil, nil
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
    looking, walk, said, Pet.armed = nil, nil, nil, nil
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
    looking, walk, said, Pet.armed = nil, nil, nil, nil
    ns.Print("Started over. Choose an egg.")
    if not IsOpen() then Pet.Open() else Refresh() end
end
-- Beta builds only since 12 Nov 2026 (John: "you can remove the restart when
-- we push to main, i already picked a new companion").
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
    if s.asleep then Rules.Lights(s, Now()) end
    if how == "dirty" then
        s.clean = 20
        s.supplies.soap = math.max(s.supplies.soap, 1)
        said = ("%s is dirty now. Bath puts it right."):format(s.name)
    else
        s.sick, s.sickSince = true, Now()
        s.supplies.medicine = math.max(s.supplies.medicine, 1)
        said = ("%s is poorly now. Medicine puts it right."):format(s.name)
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
    said = "The cupboard is stocked: three of everything."
    if IsOpen() then Refresh() else Pet.Open() end
end
Trial("pet stock", Pet.Stock)

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
    said = "A new wish for today."
    if IsOpen() then Refresh() else Pet.Open() end
end
Trial("pet wish", function() Pet.NewWish() end)
Trial("pet wish fetch", function() Pet.NewWish("fetch") end)
Trial("pet wish catch", function() Pet.NewWish("catch") end)
