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
    title = "Companion",
    -- A new part, so it starts off.
    defaultOn = false,
    note = "A small creature of your own to look after, with supplies your play earns. /jsal pet",
})
ns.Pet = Pet

local MEDIA = "Interface\\AddOns\\jsalUI\\Media\\Pet\\"
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
local SIZES = { 64, 96, 128 }
-- How far down the pen the grass starts: its feet stay below this.
local GRASS = 110
local WIN_W, WIN_H = PEN_W + PAD * 2, 566
local HEAP_W = 32       -- a dropping, and the bowl and ball: 32-pixel pictures
local SPEED = 40          -- pixels a second
local STEP_TIME = 0.28    -- seconds each walking frame shows
local DUSK = 2.5          -- seconds the pen takes to turn from day to night, or back
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
-- picture drawn again in MUD, shown only where mud_mask.tga is solid, so
-- the splotches keep to its shape. Where the game can't mask a picture,
-- it's MUDDY all over and there are no splotches.
local GRUBBY, MUD = { 0.88, 0.8, 0.68 }, { 0.42, 0.29, 0.16 }
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
    sheet.special = { first = 0, count = 9, time = 0.12, file = (file:gsub("_sheet$", "_special")), cell = 96, w = 1024, h = 128 }
    -- A first form has one more again: its egg rocking, cracking and
    -- breaking open round it, ten frames in a row (tools/make_pet_hatch.py).
    if lay.hatch then
        sheet.hatch = { first = 0, count = 10, time = 0.2, file = (file:gsub("_sheet$", "_hatch")), cell = 96, w = 1024, h = 128 }
    end
    return sheet
end
local SHEETS = {
    briarboar = Packed("briarboar_sheet", { hatch = true }),
    thornhog = Packed("thornhog_sheet", { cols = 16, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    brambletusk = Packed("brambletusk_sheet", { cell = 80, cols = 12, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    wispkin = Packed("wispkin_sheet", { hatch = true }),
    gloamtail = Packed("gloamtail_sheet"),
    wispjester = Packed("wispjester_sheet", { cell = 80, cols = 12, w = 1024, h = 512 }),
    scrapwing = Packed("scrapwing_sheet", { hatch = true }),
    jabdrake = Packed("jabdrake_sheet", { cell = 80, cols = 12, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    flarechamp = Packed("flarechamp_sheet", { cell = 80, cols = 12, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    stormcub = Packed("stormcub_sheet", { hatch = true, cols = 16, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    thundermane = Packed("thundermane_sheet", { cell = 80, cols = 12, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    tempestmane = Packed("tempestmane_sheet", { cell = 80, cols = 12, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    capling = Packed("capling_sheet", { hatch = true, cols = 16, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    lanternshell = Packed("lanternshell_sheet", { cols = 16, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
    bloomsage = Packed("bloomsage_sheet", { cell = 80, cols = 12, w = 1024, h = 512, walk = 8, walkTime = 0.1 }),
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
}
Pet.LOOKS = LOOKS
Pet.SHEETS = SHEETS

---------------------------------------------------------------------------
-- Wandering, with no drawing in it. A walk is where the creature is (its
-- top left corner in the pen), where it's heading, which way it faces,
-- which frame shows, and how long it still stands before the next stroll.
---------------------------------------------------------------------------
local function Spot(random, size)
    -- Its feet are near the bottom of its picture: high enough up the pen
    -- and a small one would be standing on the fence.
    local top = math.max(0, math.floor(GRASS - size * 0.92))
    return random(0, PEN_W - size), random(top, PEN_H - size)
end

-- `size` is how large it's drawn (the largest, unless told).
function Pet.NewWalk(random, size)
    size = size or SIZE
    local x, y = Spot(random, size)
    return { x = x, y = y, tx = x, ty = y, wait = 1, facing = "left", frame = "stand", clock = 0, size = size }
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

-- The cell of its sheet to show right now.
function Pet.Cell(walk, sheet)
    local act = walk.act
    local anim = act and sheet[act.name]
    if anim then
        -- Played through, then held on its last frame, then (for one that
        -- comes back the way it went) its frames again in reverse.
        local played = anim.count * anim.time + (anim.hold or 0)
        if anim.back and act.clock >= played then
            local gone = math.floor((act.clock - played) / anim.back)
            return anim.first + math.max(0, anim.count - 1 - gone)
        end
        return anim.first + math.min(anim.count - 1, math.floor(act.clock / anim.time))
    end
    if walk.frame == "sleep" then return sheet.sleep end
    if walk.wait <= 0 then
        return sheet.walk.first + math.floor(walk.clock / sheet.walk.time) % sheet.walk.count
    end
    return sheet.stand
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
            walk.tx, walk.ty = Spot(random, walk.size or SIZE)
            if walk.tx ~= walk.x then walk.facing = walk.tx > walk.x and "right" or "left" end
            walk.clock = 0
        end
        return walk
    end
    local dx, dy = walk.tx - walk.x, walk.ty - walk.y
    local far = math.sqrt(dx * dx + dy * dy)
    local go = SPEED * dt
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

-- What it wants from you right now, for Today: a title, a line under it and
-- its picture; nil when it's fine, asleep, or the part is off.
function Pet.Wants()
    if not Pet.running then return nil end
    if Pet.State().unchosen then
        local first = Rules.EGGS[Rules.STARTERS[1]]
        return { key = "egg", title = "Three eggs are waiting", sub = "Choose your companion", texture = MEDIA .. first.species .. "_egg" }
    end
    local s = Rules.Advance(Pet.State(), Now())
    local key, title, sub = Rules.Wants(s)
    if not key then return nil end
    local sprites = Rules.Species(s).sprites
    return { key = key, title = title, sub = sub, texture = MEDIA .. (sprites[s.form] or sprites[1]) }
end

---------------------------------------------------------------------------
-- Its page.
---------------------------------------------------------------------------
local window, pen, body, sprite, prop, effect, mud, snore, title, sub, message, wishLine, bondLine, walk, parts, fold, eggLine, pickLine
local yardToggle, yardParts, yardHead, albumLine, nameBox, renameButton

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

local eggSlots, picks, roamers, yardRows, album = {}, {}, {}, {}, {}
-- Whether the pen is showing the paddock (the companions that have settled)
-- and not the companion you look after.
local yard = false
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

local function PaintWalk()
    local sheet = Sheet()
    local file, left, right, top, bottom
    -- An animation kept in a picture of its own says so: its cells are
    -- counted in that picture, and may be a different size.
    local from = sheet
    if sheet then
        local anim = walk.act and sheet[walk.act.name]
        if type(anim) == "table" and anim.file then from = anim end
        local cell = Pet.Cell(walk, sheet)
        local cols = from.cols or math.floor(from.w / from.cell)
        local col, row = cell % cols, math.floor(cell / cols)
        file = MEDIA .. from.file
        left, right = col * from.cell / from.w, (col + 1) * from.cell / from.w
        top, bottom = row * from.cell / from.h, (row + 1) * from.cell / from.h
    else
        file = MEDIA .. Sprite() .. SUFFIX[walk.frame]
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
    local over = act and EFFECTS[act.effect] and act.effect or nil
    local early = act and act.clock < act.length / 2
    local washing = over == "bath"
    local dirty = Rules.Dirty(s) or (washing and act.grubby and early)
    local ill = s.sick or (over == "well" and act.ill and early)
    -- The mud is made the first time it's needed.
    if dirty and not mud then
        mud = body:CreateTexture(nil, "ARTWORK", nil, 1)
        mud:SetAllPoints(sprite)
        Compat.Crisp(mud)
        mud:SetDesaturated(true)
        mud:SetVertexColor(MUD[1], MUD[2], MUD[3])
        mud:Hide()
        if body.CreateMaskTexture then
            local mask = body:CreateMaskTexture()
            mask:SetAllPoints(body)
            mask:SetTexture(MEDIA .. "mud_mask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE", "NEAREST")
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
    local hue = ill and GREEN or dirty and (splotched and GRUBBY or MUDDY) or PLAIN
    if sprite.hue ~= hue then
        sprite.hue = hue
        sprite:SetVertexColor(hue[1], hue[2], hue[3])
    end
    local which = over or s.sick and "sick" or dirty and "dirty" or nil
    if which then
        local fx = EFFECTS[which]
        local at = fx.time and math.floor(tick / fx.time) % fx.count
            or math.min(fx.count - 1, math.floor(act.clock / act.length * fx.count))
        local col, row = (fx.first + at) % 8, math.floor((fx.first + at) / 8)
        effect:SetTexCoord(col / 8, (col + 1) / 8, row / 8, (row + 1) / 8)
        if not effect.file then
            effect.file = MEDIA .. "effects"
            effect:SetTexture(effect.file, "CLAMP", "CLAMP", "NEAREST")
        end
        effect:Show()
    else
        effect:Hide()
    end
    local shiver = 0
    if s.sick and not s.asleep and not act then
        local beat = math.floor(tick * 14)
        if beat % 14 < 4 then shiver = beat % 2 == 0 and 1 or -1 end
    end
    body:ClearAllPoints()
    body:SetPoint("TOPLEFT", pen, "TOPLEFT", math.floor(walk.x + 0.5) + shiver, -math.floor(walk.y + 0.5))
    -- Its bowl or its ball, on the grass in front of it while it eats or plays.
    local thing = walk.act and walk.act.prop
    if thing then
        local file = MEDIA .. thing
        if prop.file ~= file then
            prop.file = file
            prop:SetTexture(file, "CLAMP", "CLAMP", "NEAREST")
        end
        local over, up = math.floor(walk.size * 0.2), math.floor(walk.size * 0.04)
        prop:ClearAllPoints()
        if walk.facing == "right" then
            prop:SetPoint("BOTTOMLEFT", body, "BOTTOMRIGHT", -over, up)
        else
            prop:SetPoint("BOTTOMRIGHT", body, "BOTTOMLEFT", over, up)
        end
        prop:Show()
    else
        prop:Hide()
    end
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
    end
    if s.bonded then
        told[#told + 1] = ("%s and you are closer now: %s"):format(s.name, s.bonded)
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
    return next and ("Bond: %s · %d of %d"):format(name, points, next) or ("Bond: %s"):format(name)
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
    local cell = Pet.Cell(w, sheet)
    local col, row = cell % sheet.cols, math.floor(cell / sheet.cols)
    local left, right = col * sheet.cell / sheet.w, (col + 1) * sheet.cell / sheet.w
    if w.facing == "right" then left, right = right, left end
    r.sprite:SetTexCoord(left, right, row * sheet.cell / sheet.h, (row + 1) * sheet.cell / sheet.h)
    r.body:ClearAllPoints()
    r.body:SetPoint("TOPLEFT", pen, "TOPLEFT", math.floor(w.x + 0.5), -math.floor(w.y + 0.5))
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
                roamers[i] = r
            end
            if r.record ~= record then
                r.record = record
                local sprites = Rules.Species(record).sprites
                r.sheet = SHEETS[sprites[record.form] or sprites[1]]
                r.walk = Pet.NewWalk(math.random, 64)
                r.sprite:SetSize(r.sheet.cell, r.sheet.cell)
                r.sprite:SetTexture(MEDIA .. r.sheet.file, "CLAMP", "CLAMP", "NEAREST")
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
    yardHead:SetText(#settled == 0 and "No one has settled here yet. A fully grown companion settles when you hatch an egg."
        or #settled > YARD_MAX and ("%d have settled here. The last %d:"):format(#settled, YARD_MAX)
        or #settled == 1 and "One has settled here." or ("%d have settled here."):format(#settled))
    -- The album: every kind's first form, in shadow until you've raised one.
    local raised, count = {}, 0
    if not s.unchosen then raised[s.species or "briarboar"] = true end
    for _, record in ipairs(settled) do raised[record.species or "briarboar"] = true end
    for i, kind in ipairs(Rules.KINDS) do
        local picture = album[i]
        if not picture.file then
            picture.file = MEDIA .. Rules.SPECIES[kind].sprites[1]
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
    for i, pick in ipairs(picks) do
        pick:SetShown(picking)
        if picking and not pick.file then
            pick.file = MEDIA .. Rules.EGGS[Rules.STARTERS[i]].species .. "_egg"
            pick.picture:SetTexture(pick.file, "CLAMP", "CLAMP", "NEAREST")
        end
    end
    body:SetShown(not picking and not yard)
    yardToggle:SetShown(not picking)
    if picking then
        yard = false
        title:SetText("Choose your companion")
        pickLine:SetText(said or "Three eggs have turned up. Click one for a closer look.")
        for _, heap in ipairs(heaps) do heap:Hide() end
        pen.dark, pen.shade, walk = 0, 0, nil
        pen.night:SetAlpha(0)
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
    -- Asleep, the pen is the same meadow by moonlight (tools/make_pet_night.py),
    -- drawn over the day one: how far it has faded in is `shade`, which each
    -- frame moves toward `dark`. First shown, it's already where it should be.
    pen.dark = s.asleep and 1 or 0
    if not pen.shade then
        pen.shade = pen.dark
        pen.night:SetAlpha(pen.shade)
    end
    care.meal:SetLabel(("Feed · %d"):format(s.supplies.meal))
    care.treat:SetLabel(("Treat · %d"):format(s.supplies.treat))
    care.toy:SetLabel(("Play · %d"):format(s.supplies.toy))
    care.soap:SetLabel(("Bath · %d"):format(s.supplies.soap))
    care.medicine:SetLabel(("Medicine · %d"):format(s.supplies.medicine))
    care.medicine:SetEnabled(s.sick)
    care.lights:SetLabel(s.asleep and "Wake it" or "Lights out")
    -- A form that has grown is drawn larger, and starts from a spot that fits it.
    local size = SIZES[Form()] or SIZE
    if not walk or walk.size ~= size then walk = Pet.NewWalk(math.random, size) end
    if fresh and not looking then Pet.Play(walk, Sheet(), "hatch") end
    PaintWalk()
    -- The eggs you hold, each with its picture, and where they came from.
    local eggs = Eggs()
    local names = {}
    for i, slot in ipairs(eggSlots) do
        local egg = eggs[i]
        local kind = egg and Rules.EGGS[egg.kind]
        slot:SetShown(kind ~= nil)
        if kind then
            local file = MEDIA .. kind.species .. "_egg"
            if slot.file ~= file then
                slot.file = file
                slot.picture:SetTexture(file, "CLAMP", "CLAMP", "NEAREST")
            end
            names[#names + 1] = ("%s (%s)"):format(kind.name, egg.from or "found")
        end
    end
    eggLine:SetText(#names > 0 and ("Eggs: " .. table.concat(names, ", "))
        or Rules.CanFind(s) and "No eggs yet. A quest, a flight, a new level, a new zone or coming back from the dead can turn one up."
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
-- `over` what's drawn over it (EFFECTS).
local function Do(act, show, thing, over)
    local s = Pet.State()
    local grubby, ill = Rules.Dirty(s), s.sick
    local ok, what = act(s, Now())
    said = what
    if ok and walk and show then
        if show == "lights" then
            Pet.Play(walk, Sheet(), s.asleep and "doze" or "wake")
        elseif not s.asleep and Pet.Play(walk, Sheet(), show) then
            walk.act.prop, walk.act.effect, walk.act.grubby, walk.act.ill = thing, over, grubby, ill
        end
    end
    Refresh()
end

-- Where you dragged it to is kept.
local function Dropped()
    window:StopMovingOrSizing()
    local point, _, relative, x, y = window:GetPoint(1)
    if point then ns.db.petAt = { point, relative, x, y } end
end

-- Escape closes the whole window, like the game's own. The pen on its own
-- is something you leave on screen, so Escape leaves it be.
local function Escapes(on)
    if not UISpecialFrames then return end
    for i = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[i] == "jsalUIPetWindow" then table.remove(UISpecialFrames, i) end
    end
    if on then table.insert(UISpecialFrames, "jsalUIPetWindow") end
end

-- The whole window, or just the pen with its creature: the small button in
-- the pen's corner swaps between them, and which you chose is kept.
function Layout()
    -- Choosing an egg, it's the whole pen and one line under it, never just the pen.
    local picking = window.picking == true
    local small = ns.db.petCompact == true and not picking
    window.bar:SetShown(not small)
    parts:SetShown(not small and not picking and not window.yard)
    yardParts:SetShown(window.yard == true and not small and not picking)
    pickLine:SetShown(picking)
    fold:SetShown(not picking)
    pen:ClearAllPoints()
    if small then
        pen:SetPoint("TOPLEFT", 1, -1)
        window:SetSize(PEN_W + 2, PEN_H + 2)
    elseif picking then
        pen:SetPoint("TOPLEFT", PAD, -(32 + PAD))
        window:SetSize(WIN_W, 32 + PAD + PEN_H + 50)
    else
        pen:SetPoint("TOPLEFT", PAD, -(32 + PAD))
        window:SetSize(WIN_W, WIN_H)
    end
    fold:SetLabel(small and "+" or "-")
    Escapes(not small)
end

function Pet.Fold()
    ns.db.petCompact = ns.db.petCompact ~= true and true or nil
    if window then Layout() end
end

local function Build()
    window = Style.Panel("jsalUIPetWindow", WIN_W, WIN_H, "Companion")
    title = window.title
    local at = ns.db.petAt
    if type(at) == "table" and at[1] then
        window:ClearAllPoints()
        window:SetPoint(at[1], UIParent, at[2] or at[1], at[3] or 0, at[4] or 0)
    end
    window.bar:SetScript("OnDragStop", Dropped)
    -- Shown or not is kept too, so the pen you left out is there next time.
    -- (Hidden along with the whole interface, it still counts as shown.)
    window:SetScript("OnShow", function() ns.db.petShown = true end)
    window:SetScript("OnHide", function() ns.db.petShown = window:IsShown() and true or nil end)

    pen = CreateFrame("Frame", nil, window)
    pen:SetSize(PEN_W, PEN_H)
    pen:SetPoint("TOPLEFT", PAD, -(32 + PAD))
    pen:SetClipsChildren(true)
    Style.Border(pen, "cardLine")
    -- The meadow: pixel art at half the pen's size, so its pixels match the
    -- creature's. It sits in the top left 170 by 100 of a 256 by 128 picture.
    local scene = pen:CreateTexture(nil, "BACKGROUND")
    pen.scene = scene
    scene:SetAllPoints()
    scene:SetTexture(MEDIA .. "meadow", "CLAMP", "CLAMP", "NEAREST")
    scene:SetTexCoord(0, 220 / 256, 0, 100 / 128)
    Compat.Crisp(scene)
    local night = pen:CreateTexture(nil, "BACKGROUND", nil, 1)
    pen.night = night
    night:SetAllPoints()
    night:SetTexture(MEDIA .. "meadow_night", "CLAMP", "CLAMP", "NEAREST")
    night:SetTexCoord(0, 220 / 256, 0, 100 / 128)
    night:SetAlpha(0)
    Compat.Crisp(night)
    -- The pen can be dragged too: with only the pen showing, it's all there is to hold.
    pen:EnableMouse(true)
    pen:RegisterForDrag("LeftButton")
    pen:SetScript("OnDragStart", function() window:StartMoving() end)
    pen:SetScript("OnDragStop", Dropped)

    -- Droppings: click one to scoop it.
    for i, x in ipairs(HEAP_AT) do
        local heap = CreateFrame("Button", nil, pen)
        heap:SetSize(HEAP_W, HEAP_W)
        heap:SetPoint("TOPLEFT", x, -(PEN_H - 40 - (i % 2) * 26))
        local pile = heap:CreateTexture(nil, "ARTWORK")
        pile:SetAllPoints()
        pile:SetTexture(MEDIA .. "dropping", "CLAMP", "CLAMP", "NEAREST")
        Compat.Crisp(pile)
        heap:SetScript("OnClick", function() Do(Rules.Scoop) end)
        heap:Hide()
        heaps[i] = heap
    end

    -- The creature: click it for a pat.
    body = CreateFrame("Button", nil, pen)
    body:SetSize(SIZE, SIZE)
    sprite = body:CreateTexture(nil, "ARTWORK")
    sprite:SetAllPoints()
    Compat.Crisp(sprite)
    body:SetScript("OnClick", function() Do(Rules.Pat, "jump") end)
    prop = pen:CreateTexture(nil, "ARTWORK")
    prop:SetSize(HEAP_W, HEAP_W)
    Compat.Crisp(prop)
    prop:Hide()
    effect = body:CreateTexture(nil, "OVERLAY")
    effect:SetAllPoints()
    Compat.Crisp(effect)
    effect:Hide()
    snore = Style.Text(body, 15, "secondary", nil, true)
    snore:SetPoint("BOTTOMLEFT", body, "TOPRIGHT", -26, -20)
    snore:SetText("z z z")

    -- Only while the page is showing: a hidden frame gets no updates.
    local since = 0
    pen:SetScript("OnUpdate", ns.Safe(Pet, function(_, elapsed)
        Pet.tick = (Pet.tick or 0) + elapsed
        -- The paddock: its settled companions wander, and nothing else moves.
        if yard then
            local dt = math.min(elapsed, 0.1)
            for _, r in ipairs(roamers) do
                if r.record then
                    Pet.Step(r.walk, dt, math.random)
                    PaintRoamer(r)
                end
            end
            return
        end
        -- Dusk and dawn: the night meadow fades in or out, a little each frame.
        if pen.shade and pen.shade ~= pen.dark then
            local by = math.min(elapsed, 0.1) / DUSK
            pen.shade = pen.dark > pen.shade and math.min(pen.dark, pen.shade + by) or math.max(pen.dark, pen.shade - by)
            pen.night:SetAlpha(pen.shade)
        end
        if not walk then return end
        -- A long hitch (a loading screen) shouldn't fling it across the pen.
        local dt = math.min(elapsed, 0.1)
        if Pet.State().asleep then
            -- Asleep, it stays put, eyes shut, once it has settled down.
            if walk.act then Pet.Step(walk, dt, math.random) end
            if not walk.act then walk.frame = "sleep" end
            walk.wait = math.max(walk.wait, 0.5)
        else
            local walking = walk.wait <= 0
            Pet.Step(walk, dt, math.random)
            -- Just arrived somewhere: now and then it sits, or looks about.
            local sheet = Sheet()
            if sheet and walking and walk.wait > 0 and not walk.act then
                -- One time in six each: it sits, looks about, or shows off.
                local pick = math.random(1, 6)
                if Pet.State().sick then
                    -- Poorly, it doesn't show off: more often than not it just sits down.
                    if pick <= 4 then Pet.Play(walk, sheet, "sit") end
                elseif pick <= 3 then
                    Pet.Play(walk, sheet, pick == 1 and "sit" or pick == 2 and "idle" or "special")
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

    -- In the pen's other corner: over to the paddock, and back.
    yardToggle = Style.Button(pen, "Paddock", "plain", 92)
    yardToggle:SetHeight(20)
    yardToggle:SetPoint("TOPLEFT", 4, -4)
    yardToggle:SetFrameLevel(50)
    yardToggle:SetAlpha(0.85)
    yardToggle:SetScript("OnClick", function() Pet.Paddock() end)

    -- Under the pen while the paddock shows: who has settled, then the album.
    yardParts = CreateFrame("Frame", nil, window)
    yardParts:SetPoint("TOPLEFT", pen, "BOTTOMLEFT", 0, 0)
    yardParts:SetSize(PEN_W, WIN_H - PEN_H - 32 - PAD)
    yardParts:Hide()
    yardHead = Style.Text(yardParts, 12, "text")
    yardHead:SetPoint("TOPLEFT", 0, -10)
    yardHead:SetWidth(PEN_W)
    for i = 1, YARD_MAX do
        local row = Style.Text(yardParts, 12, "secondary")
        row:SetPoint("TOPLEFT", 0, -(34 + (i - 1) * 20))
        row:SetWidth(PEN_W)
        row:SetWordWrap(false)
        yardRows[i] = row
    end
    albumLine = Style.Text(yardParts, 12, "text")
    albumLine:SetPoint("TOPLEFT", 0, -(44 + YARD_MAX * 20))
    for i = 1, #Rules.KINDS do
        local picture = yardParts:CreateTexture(nil, "ARTWORK")
        picture:SetSize(64, 64)
        picture:SetPoint("TOPLEFT", (i - 1) * 84, -(64 + YARD_MAX * 20))
        Compat.Crisp(picture)
        album[i] = picture
    end

    -- For a new player: three eggs on the grass, each with its name over it,
    -- and a line under the pen that says what to do and what a click found.
    pickLine = Style.Text(window, 12, "text")
    pickLine:SetPoint("TOPLEFT", pen, "BOTTOMLEFT", 0, -12)
    pickLine:SetWidth(PEN_W)
    pickLine:Hide()
    for i, key in ipairs(Rules.STARTERS) do
        local pick = CreateFrame("Button", nil, pen)
        pick:SetSize(64, 84)
        pick:SetPoint("BOTTOM", pen, "BOTTOMLEFT", math.floor(PEN_W * i / 4), 24)
        -- The bottom middle of its picture, where the egg stands, at twice its size like a creature.
        pick.picture = pick:CreateTexture(nil, "ARTWORK")
        pick.picture:SetSize(64, 64)
        pick.picture:SetPoint("BOTTOM", 0, 0)
        pick.picture:SetTexCoord(0.25, 0.75, 0.5, 1)
        Compat.Crisp(pick.picture)
        local name = Style.Text(pick, 12, "text", nil, true)
        name:SetPoint("TOP", 0, 0)
        name:SetText((Rules.EGGS[key].name:gsub(" egg$", "")))
        pick:SetScript("OnClick", function() Pet.Choose(i) end)
        pick:Hide()
        picks[i] = pick
    end

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
    local function Care(key, act, show, thing, over)
        local b = Style.Button(parts, "", "plain", 141)
        b:SetHeight(28)
        b:SetPoint("TOPLEFT", (count % 3) * 149, -(146 + math.floor(count / 3) * 34))
        b:SetScript("OnClick", function() Do(act, show, thing, over) end)
        care[key] = b
        count = count + 1
    end
    Care("meal", Rules.Feed, "eat", "bowl")
    Care("treat", Rules.Treat, "eat", "bowl")
    Care("toy", Rules.Play, "jump", "ball")
    Care("soap", Rules.Bath, "idle", nil, "bath")
    Care("lights", Rules.Lights, "lights")
    Care("medicine", Rules.Medicine, "idle", nil, "well")
    local hint = Style.Text(parts, 11, "muted")
    hint:SetPoint("TOPLEFT", 0, -220)
    hint:SetWidth(PEN_W)
    hint:SetText("Quests bring meals, flights bring toys, a new level brings the rest. Click it for a pat, and a dropping to scoop it.")
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
    Layout()
end

local function IsOpen()
    return window ~= nil and window:IsShown() == true
end

-- /jsal pet, the dashboard's menu and Today all come here: its window opens,
-- or closes if it was open.
function Pet.Open()
    if not Pet.running then
        return ns.Print("The companion is turned off. /jsal settings turns it on.")
    end
    if not window then Build() end
    if IsOpen() then return window:Hide() end
    said, Pet.armed, yard = nil, nil, false
    pen.shade = nil     -- opened, it's day or night at once, with no fade
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
        return ns.Print("The companion is turned off. /jsal settings turns it on.")
    end
    if not IsOpen() then Pet.Open() end
    if Pet.State().unchosen then return end
    yard = not yard
    looking, said = nil, nil
    Refresh()
end
ns.Command("pet paddock", Pet.Paddock)

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
    local kind = Rules.EGGS[Rules.STARTERS[index] or ""]
    if not (s.unchosen and kind) then return end
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

function Pet:OnEnable()
    -- A hatchling from the moment the part is switched on, so what you earn
    -- before first opening its page isn't lost.
    Pet.State()
    -- The pen left out on its own comes back after a reload or a login.
    if ns.db.petShown and ns.db.petCompact then
        Compat.After(1, function() if not (window and window:IsShown()) then Pet.Open() end end)
    end
    -- Where you are now, so that only going somewhere else counts as a trip.
    local zone = ZoneName()
    local events = CreateFrame("Frame")
    events:RegisterEvent("QUEST_TURNED_IN")
    events:RegisterEvent("PLAYER_LEVEL_UP")
    events:RegisterEvent("PLAYER_CONTROL_LOST")
    events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    events:RegisterEvent("PLAYER_UNGHOST")
    events:SetScript("OnEvent", ns.Safe(self, function(_, event)
        if event == "ZONE_CHANGED_NEW_AREA" then
            -- The game also says this as you log in; that isn't a trip.
            local now = ZoneName()
            local moved = now and zone and now ~= zone
            zone = now or zone
            if moved then
                Pet.Did("zone")
                Pet.Found("zone")
            end
        elseif event == "QUEST_TURNED_IN" then
            Pet.Earn("meal", 1)
            Pet.Did("quest")
            Pet.Found("quest")
        elseif event == "PLAYER_LEVEL_UP" then
            Pet.Earn("treat", 2)
            Pet.Earn("soap", 1)
            Pet.Earn("medicine", 1)
            Pet.Found("level")
        elseif event == "PLAYER_UNGHOST" then
            -- Back among the living, sometimes with something from the other side.
            Pet.Found("ghost")
        elseif event == "PLAYER_CONTROL_LOST" then
            -- The game takes the controls away as a flight starts (and for
            -- other things): a moment later, see whether you're flying.
            Compat.After(1, ns.Safe(self, function()
                if Compat.OnTaxi() then
                    Pet.Earn("toy", 1)
                    Pet.Did("flight")
                    Pet.Found("flight")
                end
            end))
        end
    end))
end

ns.Command("pet", function() Pet.Open() end)

-- /jsal pet look: its pen, with it drawn as the next form along, and after
-- the last as itself again. For seeing what it will grow into.
function Pet.Look()
    if not Pet.running then
        return ns.Print("The companion is turned off. /jsal settings turns it on.")
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
ns.Command("pet look", Pet.Look)

-- /jsal pet special: whatever is in the pen shows off now, without waiting
-- for it to feel like it.
function Pet.ShowOff()
    if not Pet.running then
        return ns.Print("The companion is turned off. /jsal settings turns it on.")
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
ns.Command("pet special", Pet.ShowOff)

-- /jsal pet hatch: the first form in the pen hatches from its egg again,
-- for a look at it. Nothing about the companion changes.
function Pet.Hatch()
    if not Pet.running then
        return ns.Print("The companion is turned off. /jsal settings turns it on.")
    end
    if not IsOpen() then Pet.Open() end
    if not walk then return end
    if Pet.State().asleep then
        said = "It's asleep."
    elseif Pet.Play(walk, Sheet(), "hatch") then
        said = nil
    else
        said = "Only a first form hatches. /jsal pet look shows one."
    end
    Refresh()
end
ns.Command("pet hatch", Pet.Hatch)

-- /jsal pet try: a trial run of settling and hatching. Your real companion,
-- eggs and paddock are put aside, and in their place are a fully grown
-- stand-in and three eggs to click. /jsal pet try again puts everything
-- back exactly as it was; what's put aside is kept through a reload.
function Pet.Try()
    if not Pet.running then
        return ns.Print("The companion is turned off. /jsal settings turns it on.")
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
        ns.Print("A trial: a fully grown stand-in and three eggs. Click an egg twice to settle it and hatch the egg. /jsal pet try again puts your own companion back.")
    end
    looking, walk, said, Pet.armed = nil, nil, nil, nil
    if not IsOpen() then Pet.Open() else Refresh() end
end
ns.Command("pet try", Pet.Try)

-- /jsal pet new: a trial of the very start. Everything of yours is put
-- aside as /jsal pet try does, and you're shown the three eggs a new player
-- chooses between. /jsal pet try (or new) again puts everything back.
function Pet.TryNew()
    if not Pet.running then
        return ns.Print("The companion is turned off. /jsal settings turns it on.")
    end
    if type(ns.db.petAside) == "table" then return Pet.Try() end
    ns.db.petAside = { pet = Pet.State(), eggs = ns.db.petEggs, settled = ns.db.petSettled }
    ns.db.pet, ns.db.petEggs, ns.db.petSettled = nil, {}, {}
    Pet.State()
    ns.Print("A trial of the start: choose an egg as a new player would. /jsal pet try puts your own companion back.")
    looking, walk, said, Pet.armed = nil, nil, nil, nil
    if not IsOpen() then Pet.Open() else Refresh() end
end
ns.Command("pet new", Pet.TryNew)

-- /jsal pet dirty and /jsal pet sick: the companion in the pen is made
-- dirty, or poorly, there and then, with a bar of soap or a dose of medicine
-- to put it right. For seeing how those look and how the bath and the
-- medicine play. It is your real companion unless a trial is on.
local function Make(how)
    if not Pet.running then
        return ns.Print("The companion is turned off. /jsal settings turns it on.")
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
ns.Command("pet dirty", Pet.Dirty)
ns.Command("pet sick", Pet.Sick)
