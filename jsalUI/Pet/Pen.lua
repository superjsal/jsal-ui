-- The companion's pen as it's drawn: which form and sheet it's shown as,
-- the weather, the creature on its walk with what it's holding and what's
-- on its mind, its bond and hearts, and the paddock where the settled ones
-- wander.
local _, ns = ...
local Style, Compat, Rules, Pet = ns.Style, ns.Compat, ns.PetRules, ns.Pet
local inner = Pet.inner
local ui = inner.ui
local Art, PEN_H, PEN_W, YARD_MAX = inner.Art, inner.PEN_H, inner.PEN_W, inner.YARD_MAX
local BOOK_PAGE, FAST, REST_NAP, IDLE, ARC = inner.BOOK_PAGE, inner.FAST, inner.REST_NAP, inner.IDLE, inner.ARC
local TOSS, SCRUB, BUBBLES, BUBBLE_EVERY = inner.TOSS, inner.SCRUB, inner.BUBBLES, inner.BUBBLE_EVERY
local BUBBLE_FOR, EFFECTS, GREEN, MUDDY = inner.BUBBLE_FOR, inner.EFFECTS, inner.GREEN, inner.MUDDY
local PLAIN, GRUBBY, MUD, SUFFIX, SHEETS = inner.PLAIN, inner.GRUBBY, inner.MUD, inner.SUFFIX, inner.SHEETS
local Now = inner.Now

-- The mud on it while it's dirty, made the first time it's needed.
local mud

-- The name box and its Confirm button, there only while a new hatchling is
-- being named: a companion is named once, as it hatches, and keeps that name.
local function NameBox(open)
    ui.nameBox.open = open and true or false
    ui.nameBox.well:SetShown(ui.nameBox.open)
    ui.renameButton:SetShown(ui.nameBox.open)
    if ui.nameBox.open then
        ui.nameBox:SetText(Pet.State().name)
        ui.nameBox:SetFocus()
        ui.nameBox:HighlightText()
    else
        ui.nameBox:ClearFocus()
    end
end

-- Takes what's typed: Enter and the Confirm button both come here. A name
-- that won't do leaves the box open to try again.
local function TakeName()
    if Pet.Rename(ui.nameBox:GetText()) then NameBox(false) end
end

local HEAP_AT = { 100, 180, 260, 380 }

local function Form()
    local s = Pet.State()
    return ui.looking and ui.looking.form or s.grewFrom or s.form
end

-- The name its pictures go by: the look's, or its own form's.
local function Sprite()
    if ui.looking then return ui.looking.sprite end
    local s = Pet.State()
    local sprites = Rules.Species(s).sprites
    -- Ready to grow, and not yet seen growing: it's drawn as it was until
    -- the light has closed over it (Pet.Growing).
    return sprites[s.grewFrom or s.form] or sprites[1]
end

-- What its form is called.
local function FormName(s, form)
    local forms = Rules.Species(s).forms
    return forms[form or s.grewFrom or s.form] or forms[1]
end

-- How many pixels wide and tall a pal's picture is, where it isn't 80: a
-- page that draws one at its own size keeps every pixel square.
local PICTURE = {
    boltusk = 64, briarboar = 64, capling = 64, gloamtail = 64, lanternshell = 64, scrapwing = 64,
    stormcub = 64, thornhog = 64, wispkin = 64, auroracrown = 112, eclipselord = 128,
}

-- Your pal as it is now, for a page that shows it beside you (Home, the
-- Journal's Summary): its name, what its form is called, its picture and
-- the picture's size. Nil with the part off, or before an egg is chosen.
function Pet.Portrait()
    if not Pet.running then return nil end
    local s = Pet.State()
    if s.unchosen then return nil end
    local sprites = Rules.Species(s).sprites
    local sprite = sprites[s.grewFrom or s.form] or sprites[1]
    return { name = s.name, form = FormName(s), texture = Art(sprite), size = PICTURE[sprite] or 80 }
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

-- Weather in the pen, the same as where you are (its option, off to start):
-- for each kind the game tells of, one 128-pixel picture that's repeated
-- across the pen and slid (tools/make_pet_weather.py), over a wash of colour
-- (`tint`, as faint as `dim[1]` when it's light and as strong as `dim[2]` at
-- its hardest). Each layer slides `dx`, `dy` pixels a second and may `sway`
-- from side to side; a second is there only from `from` on, and `ox`, `oy`
-- set it apart from the first. Only snow has a heavy look, with that second
-- layer: rain and a sandstorm are drawn one way however hard they come down.
Pet.WEATHER = {
    rain = { file = "weather_rain", tint = { 0.14, 0.2, 0.31 }, dim = { 0.12, 0.12 },
        layers = { { dx = -120, dy = 440, alpha = 0.75 } } },
    snow = { file = "weather_snow", tint = { 0.8, 0.85, 0.93 }, dim = { 0.08, 0.14 },
        layers = { { dx = 0, dy = 60, sway = 6, alpha = 0.8 }, { dx = 0, dy = 100, sway = -9, alpha = 1, from = 0.5, ox = 54, oy = 70 } } },
    sand = { file = "weather_sand", tint = { 0.75, 0.58, 0.33 }, dim = { 0.14, 0.14 },
        layers = { { dx = -420, dy = 50, alpha = 0.8 } } },
}
-- Where a layer's picture lies `clock` seconds on, as the part of it the pen
-- shows: left, right, top, bottom, in pictures (the pen is several wide).
function Pet.WeatherCoords(layer, clock)
    local x = math.floor((layer.ox or 0) + layer.dx * clock + (layer.sway or 0) * math.sin(clock * 0.9)) % 128
    local y = math.floor((layer.oy or 0) + layer.dy * clock) % 128
    local left, top = -x / 128, -y / 128
    return left, left + PEN_W / 128, top, top + PEN_H / 128
end
-- The weather to draw, and how hard from 0 to 1; nil for none. A beta's
-- /jsal pet weather shows one for a look, whatever the sky is doing.
function Pet.Weather()
    if ui.pen and ui.pen.forced then return ui.pen.forced[1], ui.pen.forced[2] end
    if not ns.OptionOn("pet", "weather") then return nil end
    local kind, much, raw, rawMuch = Compat.Weather()
    -- What the game last said is kept, and nothing is said in chat: a beta
    -- build used to print it each time it changed, to learn what the game's
    -- numbers were. /jsal pet weather, on a beta build, says it when it goes
    -- back to the weather where you are.
    if raw then Pet.sawWeather, Pet.sawMuch = raw, rawMuch end
    if not kind or not much or much <= 0 then return nil end
    return kind, math.min(1, much)
end

-- Growing into its next form. With the good hours for it, it's "ready to
-- grow" and waits, as it was, for you to press Grow in its pen (Pet.GrowNow),
-- so it's never missed. Then motes of gold drift in and a ball of light grows
-- over it (`gather` seconds), the ball throbs while it changes underneath
-- (it's the new form from `turn` on), then bursts (from `burst`) and there
-- it is, grown. One picture of sixteen 128-pixel cells, eight to a row
-- (tools/make_pet_grow.py), drawn over it at twice the size it stands in.
Pet.GROW = { file = "grow", gather = 1.4, turn = 1.7, burst = 2, length = 2.96 }
-- The cell of that picture to show, `clock` seconds in.
function Pet.GrowCell(clock)
    local g = Pet.GROW
    if clock < g.gather then return math.floor(clock / 0.2) end
    if clock < g.burst then return 7 - math.floor((clock - g.gather) / 0.1) % 2 end
    return 8 + math.min(7, math.floor((clock - g.burst) / 0.12))
end
-- Called as its window moves it on, awake. Turns it into its new form once
-- the light has closed over it (true then, once: its window has more to
-- say), and has it show off when the light has gone.
function Pet.Growing(walk, s)
    local act = walk.act
    if act and act.name == "grow" then
        if s.grewFrom and act.clock >= Pet.GROW.turn then
            s.grewFrom, s.grown, walk.grown = nil, true, true
            Pet.Sound("fanfare")
            return true
        end
    elseif walk.grown and not act then
        walk.grown = nil
        local sheet = Sheet()
        if not Pet.Play(walk, sheet, "special") then Pet.Play(walk, sheet, "jump") end
    end
    return false
end

-- The weather over the pen: over the creature and everything on the
-- grass, under the pen's buttons. Nothing of it is made until there's
-- weather to draw; it isn't shown out with you (the real thing is all
-- round you) or while an egg is being chosen. The paddock has it too.
function Pet.PaintWeather()
    local kind, much = Pet.Weather()
    local look = kind and Pet.WEATHER[kind]
    local show = look ~= nil and not ui.window.out and not ui.window.picking
    ui.pen.weather, ui.pen.much = show and kind or nil, show and much or nil
    if not show then
        if ui.weather then ui.weather:Hide() end
        return
    end
    local w = ui.weather
    if not w then
        w = CreateFrame("Frame", nil, ui.pen)
        ui.weather = w
        w:SetAllPoints()
        w:SetFrameLevel(40)
        w.tint = w:CreateTexture(nil, "BACKGROUND")
        w.tint:SetAllPoints()
        w.layers = {}
        for i = 1, 2 do
            local t = w:CreateTexture(nil, "ARTWORK", nil, i)
            t:SetAllPoints()
            Compat.Crisp(t)
            w.layers[i] = t
        end
    end
    if w.kind ~= kind then
        w.kind = kind
        w.tint:SetColorTexture(look.tint[1], look.tint[2], look.tint[3])
        for _, t in ipairs(w.layers) do t:SetTexture(Art(look.file), "REPEAT", "REPEAT", "NEAREST") end
    end
    w.tint:SetAlpha(look.dim[1] + (look.dim[2] - look.dim[1]) * much)
    for i, t in ipairs(w.layers) do
        local layer = look.layers[i]
        if layer then t:SetAlpha(layer.alpha) end
        t:SetShown(layer ~= nil and much >= (layer.from or 0))
    end
    w:Show()
    Pet.SlideWeather(Pet.tick or 0)
end
-- Moves it on: called as often as the pen is drawn.
function Pet.SlideWeather(clock)
    local w = ui.weather
    local look = w and w:IsShown() and Pet.WEATHER[w.kind]
    if not look then return end
    for i, t in ipairs(w.layers) do
        if look.layers[i] then t:SetTexCoord(Pet.WeatherCoords(look.layers[i], clock)) end
    end
end

-- Day, sunset or night in the pen, from how far the day has gone
-- (`pen.shade`): the sunset meadow fades in over the day one for the first
-- half, the night one over that for the second, and what lies on the grass
-- takes the light's colour. The creature takes it as it's painted.
local function Sky()
    local shade = ui.pen.shade or 0
    ui.pen.dusk:SetAlpha(math.min(1, shade * 2))
    ui.pen.night:SetAlpha(math.max(0, shade * 2 - 1))
    local r, g, b = Pet.Light(shade)
    for _, heap in ipairs(ui.heaps) do heap.pile:SetVertexColor(r, g, b) end
    ui.prop:SetVertexColor(r, g, b)
    ui.effect:SetVertexColor(r, g, b)
    if ui.hideSpot then ui.hideSpot.picture:SetVertexColor(r, g, b) end
end

local function PaintWalk()
    local sheet = Sheet()
    local file, left, right, top, bottom
    -- An animation kept in a picture of its own says so: its cells are
    -- counted in that picture, and may be a different size.
    local from = sheet
    if sheet then
        local cell
        cell, from = Pet.Cell(ui.walk, sheet)
        local cols = from.cols or math.floor(from.w / from.cell)
        local col, row = cell % cols, math.floor(cell / cols)
        file = Art(from.file)
        left, right = col * from.cell / from.w, (col + 1) * from.cell / from.w
        top, bottom = row * from.cell / from.h, (row + 1) * from.cell / from.h
    else
        file = Art(Sprite() .. SUFFIX[ui.walk.frame])
        left, right, top, bottom = 0, 1, 0, 1
    end
    -- The sprite is drawn facing left; turned round, its picture is flipped.
    if ui.walk.facing == "right" then left, right = right, left end
    ui.sprite:SetTexCoord(left, right, top, bottom)
    if ui.sprite.file ~= file then
        ui.sprite.file = file
        -- NEAREST keeps each of its pixels a sharp square when drawn larger.
        ui.sprite:SetTexture(file, "CLAMP", "CLAMP", "NEAREST")
    end
    if ui.body.size ~= ui.walk.size then
        ui.body.size = ui.walk.size
        ui.body:SetSize(ui.walk.size, ui.walk.size)
    end
    -- The body is the 64 pixels it stands in; a larger cell's picture spills
    -- over it evenly on every side.
    local drawn = ui.walk.size * (from and from.cell or 64) / 64
    if ui.sprite.drawn ~= drawn then
        ui.sprite.drawn = drawn
        ui.sprite:ClearAllPoints()
        ui.sprite:SetPoint("CENTER", ui.body, "CENTER", 0, 0)
        ui.sprite:SetSize(drawn, drawn)
    end
    -- How it is shows on it. Poorly, it's off-colour, with stars going round
    -- its head, and standing still it shivers; dirty, it's muddy, with flies;
    -- in the bath, the tub and suds, and the mud stays until halfway through;
    -- given medicine, it stays off-colour until halfway through getting well.
    local s, act = Pet.State(), ui.walk.act
    local tick = Pet.tick or 0
    -- Asleep for the night, or having a nap while you're away, it snores.
    ui.snore:SetShown((s.asleep or (ui.walk.nap and not act)) and true or false)
    -- A bath being scrubbed: the mud stays on until it's done, and the suds
    -- come up as the brush goes over it.
    local scrub = ui.pen.held and ui.pen.held.scrub and ui.pen.held or nil
    local over = act and EFFECTS[act.effect] and act.effect or scrub and scrub.scrub > 0 and "bath" or nil
    local early = act and act.clock < act.length / 2
    local washing = over == "bath"
    local dirty = Rules.Dirty(s) or (washing and act and act.grubby and early) or (scrub and scrub.grubby) or false
    local ill = s.sick or (over == "well" and act.ill and early)
    -- The mud is made the first time it's needed.
    if dirty and not mud then
        mud = ui.body:CreateTexture(nil, "ARTWORK", nil, 1)
        mud:SetAllPoints(ui.sprite)
        Compat.Crisp(mud)
        mud:SetDesaturated(true)
        mud:Hide()
        if ui.body.CreateMaskTexture then
            local mask = ui.body:CreateMaskTexture()
            mask:SetAllPoints(ui.body)
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
    local shade = ui.pen.shade or 0
    if ui.sprite.hue ~= hue or ui.sprite.shade ~= shade then
        ui.sprite.hue, ui.sprite.shade = hue, shade
        local r, g, b = Pet.Light(shade)
        ui.sprite:SetVertexColor(hue[1] * r, hue[2] * g, hue[3] * b)
    end
    if mud and mud.shade ~= shade then
        mud.shade = shade
        local r, g, b = Pet.Light(shade)
        mud:SetVertexColor(MUD[1] * r, MUD[2] * g, MUD[3] * b)
    end
    local which = over or s.sick and "sick" or dirty and "dirty" or ui.walk.doting and "love" or nil
    if which then
        local fx = EFFECTS[which]
        -- One that plays once goes with its animation; scrubbed suds, with the scrubbing (the first half).
        local part = act and act.effect == which and act.clock / act.length or scrub and scrub.scrub / SCRUB * 0.5 or 0
        local at = fx.time and math.floor(tick / fx.time) % fx.count
            or math.min(fx.count - 1, math.floor(part * fx.count))
        local col, row = (fx.first + at) % 8, math.floor((fx.first + at) / 8)
        ui.effect:SetTexCoord(col / 8, (col + 1) / 8, row / 8, (row + 1) / 8)
        if not ui.effect.file then
            ui.effect.file = Art("effects")
            ui.effect:SetTexture(ui.effect.file, "CLAMP", "CLAMP", "NEAREST")
        end
        ui.effect:Show()
    else
        ui.effect:Hide()
    end
    -- Growing: the light over it, and over everything else on it. It keeps
    -- its own colour at night: it's light.
    if act and act.name == "grow" then
        if not ui.grow then
            ui.grow = ui.body:CreateTexture(nil, "OVERLAY", nil, 3)
            ui.grow:SetTexture(Art(Pet.GROW.file), "CLAMP", "CLAMP", "NEAREST")
            Compat.Crisp(ui.grow)
        end
        -- It stays where it started, whatever size the creature under it becomes.
        if ui.grow.wide ~= act.wide or ui.grow.cx ~= act.cx or ui.grow.cy ~= act.cy then
            ui.grow.wide, ui.grow.cx, ui.grow.cy = act.wide, act.cx, act.cy
            ui.grow:ClearAllPoints()
            ui.grow:SetPoint("CENTER", ui.pen, "TOPLEFT", act.cx, -act.cy)
            ui.grow:SetSize(act.wide, act.wide)
        end
        local cell = Pet.GrowCell(act.clock)
        local col, row = cell % 8, math.floor(cell / 8)
        ui.grow:SetTexCoord(col / 8, (col + 1) / 8, row / 2, (row + 1) / 2)
        ui.grow:Show()
    elseif ui.grow then
        ui.grow:Hide()
    end
    -- Standing still, or drooped, it shivers now and then.
    local shiver = 0
    local low = act and act.name == "poorly" and sheet and sheet.poorly
    local drooped = low and act.clock >= low.count * low.time and act.clock < low.count * low.time + low.hold
    if ui.pen.coldAt ~= Pet.where then ui.pen.coldAt, ui.pen.cold = Pet.where, Pet.Scene(Pet.where) == "snow" end
    if s.sick and not s.asleep and (not act or drooped) then
        local beat = math.floor(tick * 14)
        if beat % 14 < 4 then shiver = beat % 2 == 0 and 1 or -1 end
    elseif ui.window.out and ui.pen.cold and not act and not ui.walk.nap and ui.walk.wait > 0 then
        -- Out with you in the snow, it shivers now and then where it stands.
        local beat = math.floor(tick * 14)
        if beat % 70 < 6 then shiver = beat % 2 == 0 and 1 or -1 end
    end
    -- Leaning into your hand, it's a pixel or two nearer it.
    local lean = act and act.name == "lean" and (ui.walk.facing == "right" and 1 or -1) * math.max(1, math.floor(ui.walk.size / 48)) or 0
    local bx, by = math.floor(ui.walk.x + 0.5) + shiver + lean, -math.floor(ui.walk.y + 0.5)
    if ui.body.bx ~= bx or ui.body.by ~= by then
        ui.body.bx, ui.body.by = bx, by
        ui.body:ClearAllPoints()
        ui.body:SetPoint("TOPLEFT", ui.pen, "TOPLEFT", bx, by)
    end
    -- What's on its mind, in a bubble by its head, for a few seconds now and
    -- then; or news it's telling you (Pet.Flash), at once and whatever it's doing.
    local flash = ui.play.flash
    local think = flash and flash.cell or ui.pen.thought and BUBBLES[ui.pen.thought]
    local musing = think ~= nil and not s.asleep and not ui.walk.nap and (flash ~= nil or (not act and tick % BUBBLE_EVERY < BUBBLE_FOR
        and (ui.pen.thought ~= "wish" or math.floor(tick / BUBBLE_EVERY) % 3 == 0)))
    if musing then
        local col, row = think % 8, math.floor(think / 8)
        ui.bubble:SetTexCoord(col / 8, (col + 1) / 8, row / 4, (row + 1) / 4)
        if ui.bubble.size ~= ui.walk.size then
            ui.bubble.size = ui.walk.size
            ui.bubble:ClearAllPoints()
            ui.bubble:SetPoint("BOTTOMLEFT", ui.body, "TOPRIGHT", -math.floor(ui.walk.size * 0.45), -math.floor(ui.walk.size * 0.35))
        end
    end
    if ui.bubble.on ~= musing then
        ui.bubble.on = musing
        ui.bubble:SetShown(musing)
    end
    -- Its bowl, its treat or its ball, on the grass in front of it while it eats or plays.
    -- Or in your hand, at the pointer, until you say where it goes; or on
    -- its way through the air, lying where it landed, or being brought back.
    local errand, held, toss = ui.walk.errand, ui.pen.held, ui.pen.toss
    local thing = act and act.prop or errand and errand.thing or held and held.thing or toss and "treat"
    local seen = thing ~= nil
    -- What's in your hand is drawn by a picture of its own, over the creature
    -- (`pen.hand`): the brush goes over what it scrubs, not behind it.
    local inHand = false
    if thing then
        local file = Art(thing)
        if ui.prop.file ~= file then
            ui.prop.file = file
            ui.prop:SetTexture(file, "CLAMP", "CLAMP", "NEAREST")
        end
        local over, up = math.floor(ui.walk.size * 0.2), math.floor(ui.walk.size * 0.04)
        ui.prop:ClearAllPoints()
        local way = ui.walk.facing == "right" and 1 or -1
        if act and act.toss then
            -- Caught: from where it was in the air, into its mouth, and gone.
            local t = act.clock / (act.length * 0.3)
            seen = t < 1
            local from, lean = act.from or 0.5, act.lean or 0
            ui.prop:SetPoint("BOTTOM", ui.body, "TOP", math.floor(ui.walk.size * lean * (1 - t)) * way,
                math.floor(ui.walk.size * (from + (-0.45 - from) * t)))
        elseif toss and not (act and act.prop) then
            -- Tossed up: over its head and down again, drifting to its front.
            local t = toss.clock / TOSS
            ui.prop:SetPoint("BOTTOM", ui.body, "TOP", math.floor(ui.walk.size * 0.3 * t) * way, math.floor(ui.walk.size * (Pet.Tossed(t))))
        elseif (act and act.prop) or (errand and (errand.phase == "wait" or errand.phase == "back")) then
            -- Carried home, it's held a little off the ground.
            -- (And a letter it's bringing you, held up to show you.)
            if (errand and errand.phase == "back" and not act) or (act and act.carry) then up = up + math.floor(ui.walk.size * 0.22) end
            if ui.walk.facing == "right" then
                ui.prop:SetPoint("BOTTOMLEFT", ui.body, "BOTTOMRIGHT", -over, up)
            else
                ui.prop:SetPoint("BOTTOMRIGHT", ui.body, "BOTTOMLEFT", over, up)
            end
        elseif errand then
            local t = errand.phase == "fly" and errand.fly > 0 and math.min(1, errand.clock / errand.fly) or 1
            local x = errand.sx + (errand.px - errand.sx) * t
            local y = errand.sy + (errand.py - errand.sy) * t - 4 * ARC * t * (1 - t)
            ui.prop:SetPoint("BOTTOMLEFT", ui.pen, "TOPLEFT", math.floor(x + 0.5), -math.floor(y + 0.5))
        else
            local x, y = Compat.CursorAt(ui.pen)
            seen = false
            inHand = x ~= nil and x >= 0 and x <= PEN_W and y >= 0 and y <= PEN_H
            if inHand then
                local hand = ui.pen.hand
                if hand.file ~= file then
                    hand.file = file
                    hand:SetTexture(file, "CLAMP", "CLAMP", "NEAREST")
                end
                hand:ClearAllPoints()
                hand:SetPoint("CENTER", ui.pen, "TOPLEFT", math.floor(x), -math.floor(y))
            end
        end
    end
    ui.prop:SetShown(seen)
    ui.pen.hand:SetShown(inHand)
    Pet.Glint(toss and not toss.spent and not (act and act.prop) and toss.clock / TOSS or nil)
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
        if s.grewFrom then
            -- Ready, and waiting for you: what it grows into isn't said yet.
            told[#told + 1] = ("%s is ready to grow! Press Grow in its pen to watch."):format(s.name)
        else
            told[#told + 1] = ("%s has grown into a %s!"):format(s.name, form)
            Pet.Sound("fanfare")
        end
    end
    -- Seen growing, a moment ago (its fanfare went with that).
    if s.grown then
        s.grown = nil
        told[#told + 1] = ("%s has grown into a %s!"):format(s.name, form)
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

-- What's wrong when a need is low, and each need's own colour for its pips.
Pet.LOW = { hunger = "hungry", energy = "tired", fun = "bored", clean = "dirty" }
Pet.NEED_TINT = { hunger = { 0.89, 0.58, 0.29 }, energy = { 0.44, 0.64, 0.88 }, fun = { 0.94, 0.42, 0.54 }, clean = { 0.36, 0.76, 0.69 } }

-- How it is, as you'd say it out loud: "Bramble is happy, but hungry".
function Pet.Headline(s)
    local mood = Rules.Mood(s)
    local text = ("%s is %s"):format(s.name, mood)
    if s.sick or s.asleep then return text end
    local low, which = 100, nil
    for _, need in ipairs(Rules.NEEDS) do
        if s[need] < low then low, which = s[need], need end
    end
    if low < 35 and Pet.LOW[which] ~= mood then
        text = text .. (mood == "grumpy" and ": " or ", but ") .. Pet.LOW[which]
    end
    return text
end

-- The bond as hearts, one a level, with how far the next is; and today's
-- company, the things done with it on your screen, as marks.
function Pet.PaintBond(s)
    local level, name, points, next = Rules.Bond(s)
    for i, heart in ipairs(ui.hearts) do
        heart:SetDesaturated(i > level)
        heart:SetAlpha(i > level and 0.5 or 1)
    end
    local after = Rules.BONDS[level + 1]
    ui.bondLine:SetText((next and after) and ("%s  |cff9a9688%d more to %s|r"):format(name, next - points, after[2])
        or (name .. "  |cff9a9688as close as can be|r"))
    local deeds, need = Rules.CompanyToday(s, Now())
    ui.company:SetText(deeds >= need and "good company today" or "with you today")
    ui.company.deeds, ui.company.need = deeds, need
    for i, mark in ipairs(ui.marks) do
        mark:SetShown(i <= need)
        mark:SetColorTexture(Style.Color(i <= deeds and "gold" or "lineStrong"))
    end
end

-- Three hearts rise from a care button toward the pen and fade: a small
-- thank-you for looking after it. Each starts a little after the last and a
-- little to one side. Where the game can't say where things are, or can't
-- animate, there are none.
function Pet.Hearts(from)
    if not (ui.window and ui.pen and from) then return end
    local fx, fy = from:GetCenter()
    local px, py = ui.pen:GetCenter()
    if not (fx and fy and px and py) then return end
    ui.floaters = ui.floaters or {}
    for i = 1, 3 do
        local f = ui.floaters[i]
        if not f then
            f = CreateFrame("Frame", nil, ui.window)
            f:SetSize(16, 16)
            f:SetFrameLevel(60)
            f.picture = f:CreateTexture(nil, "OVERLAY")
            f.picture:SetAllPoints()
            f.picture:SetTexture(Art("heart"), "CLAMP", "CLAMP", "NEAREST")
            Compat.Crisp(f.picture)
            f.group = f.CreateAnimationGroup and f:CreateAnimationGroup()
            if f.group then
                f.rise = f.group:CreateAnimation("Translation")
                f.rise:SetDuration(0.9)
                f.rise:SetSmoothing("OUT")
                f.fade = f.group:CreateAnimation("Alpha")
                f.fade:SetFromAlpha(1)
                f.fade:SetToAlpha(0)
                f.fade:SetDuration(0.4)
                f.group:SetScript("OnFinished", function() f:Hide() end)
            end
            f:Hide()
            ui.floaters[i] = f
        end
        if not f.group then return end
        local wait = (i - 1) * 0.12
        f.group:Stop()
        f:ClearAllPoints()
        f:SetPoint("CENTER", from, "CENTER", (i - 2) * 12, 8)
        -- Most of the way to the pen, drifting toward its middle.
        f.rise:SetOffset((px - fx) * 0.5 + (i - 2) * 14, (py - fy) * 0.7)
        f.rise:SetStartDelay(wait)
        f.fade:SetStartDelay(wait + 0.5)
        f:Show()
        f.group:Play()
    end
end

-- The care buttons: each one's word and how many are left, greyed with none,
-- and the one it needs now in gold, bobbing.
function Pet.DressCare(s)
    local wants = { meal = s.hunger < 35, toy = s.fun < 35, soap = s.clean < 35, lights = s.energy < 35, medicine = s.sick and true or false }
    for key, b in pairs(ui.care) do
        local left = s.supplies[key]
        -- Worn out and asleep, it can't be woken yet (Rules.Lights): "Wake it" is greyed like a
        -- button with nothing left, and says why when pointed at. A click still says so too.
        local tired = key == "lights" and s.asleep and s.energy <= Rules.WORN
        b.why = tired and "It's too tired to wake yet. Give it a little while." or nil
        local none = left == 0 or (key == "medicine" and not s.sick) or tired
        local wanted = wants[key] == true and not none and (key == "medicine" or not s.asleep)
        b.word:SetText(key == "lights" and (s.asleep and "Wake it" or "Lights out") or b.name)
        -- Asleep, its button is a sun to wake it, where a moon put it to bed.
        if key == "lights" then
            b.art:SetTexture(Art(s.asleep and "care_wake" or "care_lights"), "CLAMP", "CLAMP", "NEAREST")
        end
        b.word:SetTextColor(Style.Color(wanted and "gold" or (none and "muted" or "text")))
        b.count:SetText(left and tostring(left) or "")
        b.count:SetTextColor(Style.Color((left or 0) > 0 and "onGold" or "muted"))
        b.badge:SetShown(left ~= nil)
        b.badge:SetColorTexture(Style.Color((left or 0) > 0 and "gold" or "lineStrong"))
        b.art:SetDesaturated(none)
        b.art:SetAlpha(none and 0.4 or 1)
        for _, edge in ipairs(b.frame) do edge:SetShown(wanted) end
        b.bobbing = wanted
        if not wanted and not b.pressed then b.art:SetPoint("TOP", 0, -11) end
    end
end

-- The needed one's picture bobs: up four pixels and back in just under a second, set in its
-- place each time it's drawn, so nothing it does can carry the button away. A pressed one dips.
local BOB_HIGH, BOB_TIME = 4, 0.9
function Pet.BobCare(clock)
    if not ui.care then return end
    local up = math.floor(BOB_HIGH * (1 - math.cos((clock or 0) * 2 * math.pi / BOB_TIME)) / 2 + 0.5)
    for _, b in pairs(ui.care) do
        if b.bobbing and not b.pressed then b.art:SetPoint("TOP", 0, -11 + up) end
    end
end

local function Growing(s)
    if s.grewFrom then return "ready to grow" end
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
    -- At the art's own size in the paddock. One that has come to visit the
    -- pen is drawn as the pen draws its form (`r.size`): at the paddock's
    -- size it stood half as tall as the hatchling it had come to see.
    local drawn = (r.size or 64) * from.cell / 64
    if r.file ~= from.file or r.drawn ~= drawn then
        r.file, r.drawn = from.file, drawn
        r.sprite:SetTexture(Art(from.file), "CLAMP", "CLAMP", "NEAREST")
        r.sprite:SetSize(drawn, drawn)
    end
    -- In the light of the hour, as the pen's own companion is: the paddock
    -- has dusk and night now.
    local shade = ui.pen.shade or 0
    if r.shade ~= shade then
        r.shade = shade
        r.sprite:SetVertexColor(Pet.Light(shade))
    end
    r.snore:SetShown(r.nap ~= nil and not w.act)
    r.body:ClearAllPoints()
    r.body:SetPoint("TOPLEFT", ui.pen, "TOPLEFT", math.floor(w.x + 0.5), -math.floor(w.y + 0.5))
end

-- Who's drawn over whom: a pal nearer the front (its feet lower in the pen) over one behind it,
-- whichever way they walk. In the pen the visitor goes over or under yours (whose nest rim and
-- hiding place stay over it); in the paddock, its companions by where they stand. A level
-- changes only when the order does.
local function Foot(w, size) return (w.y or 0) + (size or w.size or 64) end
function Pet.Layer()
    local pen = ui.pen:GetFrameLevel() or 1
    if ui.yard then
        local list = {}
        for _, r in ipairs(ui.roamers) do
            if r.record and r.walk then list[#list + 1] = r end
        end
        table.sort(list, function(a, b) return Foot(a.walk) < Foot(b.walk) end)
        for i, r in ipairs(list) do
            local want = pen + 2 + i
            if r.level ~= want then r.level = want; r.body:SetFrameLevel(want) end
        end
        return
    end
    local v = ui.visitor
    if v and v.on and v.walk and ui.walk then
        local mine = ui.body:GetFrameLevel() or (pen + 3)
        local want = Foot(v.walk, v.size) > Foot(ui.walk, ui.walk.size) and mine + 3 or mine - 1
        if v.level ~= want then v.level = want; v.body:SetFrameLevel(want) end
    end
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
    if not s.unchosen then Note(s.species, s.grewFrom or s.form) end
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
        local r = ui.roamers[i]
        if record then
            if not r then
                r = { body = CreateFrame("Frame", nil, ui.pen) }
                r.body:SetSize(64, 64)
                r.sprite = r.body:CreateTexture(nil, "ARTWORK")
                r.sprite:SetPoint("CENTER")
                Compat.Crisp(r.sprite)
                r.snore = Style.Text(r.body, 11, "secondary", nil, true)
                r.snore:SetPoint("BOTTOMLEFT", r.body, "TOPRIGHT", -22, -14)
                r.snore:SetText("z z")
                ui.roamers[i] = r
            end
            if r.record ~= record then
                r.record = record
                local sprites = Rules.Species(record).sprites
                r.sheet = SHEETS[sprites[record.form] or sprites[1]]
                r.walk, r.nap, r.file = Pet.NewWalk(math.random, 64), nil, nil
            end
            r.body:Show()
            PaintRoamer(r)
            -- The one that looked after your companion's egg says so: it's who comes by the pen.
            local care = s.caretaker
            local visits = care and not s.unchosen and record.name == care.name and (record.species or "briarboar") == care.species
            ui.yardRows[i]:SetText(("%s the %s · %d day%s together · %s%s"):format(record.name, FormName(record, record.form),
                record.days or 1, (record.days or 1) == 1 and "" or "s", record.bond or "Wary",
                visits and (" · visits " .. s.name) or ""))
        else
            if r then
                r.record = nil
                r.body:Hide()
            end
            ui.yardRows[i]:SetText("")
        end
    end
    ui.yardHead:SetText(#settled == 0 and "No one has settled here yet. A fully grown pal settles when the egg it looks after hatches."
        or #settled > YARD_MAX and ("%d have settled here. The last %d:"):format(#settled, YARD_MAX)
        or #settled == 1 and "One has settled here." or ("%d have settled here."):format(#settled))
    -- Under the list, every kind's first form, in shadow until you've raised one.
    local raised, count = Pet.Raised(s, settled), 0
    for i, kind in ipairs(Rules.KINDS) do
        local picture = ui.album[i]
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
    ui.albumLine:SetText(("Kinds raised: %d of %d"):format(count, #Rules.KINDS))
    -- The album, in the list's place: every form of every kind, a kind to a
    -- column with its three forms down it, each in shadow and unnamed until
    -- one of yours has been it. Its pictures load the first time it's opened.
    ui.yardList:SetShown(not ui.albumOpen)
    ui.yardBook:SetShown(ui.albumOpen)
    ui.bookToggle:SetLabel(ui.albumOpen and "List" or "Album")
    if not ui.albumOpen then return end
    local seen = 0
    local pages = math.ceil(#Rules.KINDS / BOOK_PAGE)
    ui.albumPage = math.max(1, math.min(pages, ui.albumPage))
    ui.bookTurn.count:SetText(("%d / %d"):format(ui.albumPage, pages))
    ui.bookTurn.count:SetShown(pages > 1)
    ui.bookTurn.back:SetShown(pages > 1)
    ui.bookTurn.on:SetShown(pages > 1)
    for i, kind in ipairs(Rules.KINDS) do
        local species = Rules.SPECIES[kind]
        local here = ui.book[i].page == ui.albumPage
        for form, page in ipairs(ui.book[i]) do
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
    ui.bookHead:SetText(("Forms seen: %d of %d. Each kind grows down its column."):format(seen, #Rules.KINDS * 3))
end

-- For the pet's other files.
inner.NameBox, inner.TakeName, inner.HEAP_AT, inner.Form = NameBox, TakeName, HEAP_AT, Form
inner.FormName, inner.Own, inner.Eggs, inner.Settled, inner.Sheet = FormName, Own, Eggs, Settled, Sheet
inner.Sky, inner.PaintWalk, inner.Milestones, inner.WishText = Sky, PaintWalk, Milestones, WishText
inner.Growing, inner.PaintRoamer, inner.PaintYard = Growing, PaintRoamer, PaintYard
