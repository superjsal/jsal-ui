-- Looking after the companion: the whole window brought up to date
-- (Refresh), what each care button does, what a click or a stroke in the
-- pen does, the tick that moves it along, and where the window sits.
local _, ns = ...
local Style, Compat, Rules, Pet = ns.Style, ns.Compat, ns.PetRules, ns.Pet
local inner = Pet.inner
local ui = inner.ui
local Art, PEN_H, PEN_W, SIZE, SIZES = inner.Art, inner.PEN_H, inner.PEN_W, inner.SIZE, inner.SIZES
local GRASS, HOLD, THROWS, CATCH_FROM = inner.GRASS, inner.HOLD, inner.THROWS, inner.CATCH_FROM
local CATCH_TO, TOSS, CHASE, SCRUB = inner.CATCH_TO, inner.TOSS, inner.CHASE, inner.SCRUB
local IN_HAND, Now, Offer, NameBox, Form = inner.IN_HAND, inner.Now, inner.Offer, inner.NameBox, inner.Form
local FormName, Own, Eggs, Settled, Sheet = inner.FormName, inner.Own, inner.Eggs, inner.Settled, inner.Sheet
local Sky, PaintWalk, Milestones, WishText = inner.Sky, inner.PaintWalk, inner.Milestones, inner.WishText
local Growing, PaintYard = inner.Growing, inner.PaintYard

local function Refresh()
    -- What it wants has changed (its pen scooped, fed, well again): Home
    -- says what it wants, so an open dashboard is told.
    local want = Pet.Wants()
    local wanted = want and want.key or false
    if wanted ~= ui.wanted then
        ui.wanted = wanted
        if ns.Window and ns.Window.Refresh then ns.Window.Refresh() end
    end
    -- A new player has no companion yet: three eggs stand on the grass to
    -- choose from, and nothing else of the window is there.
    local s = Pet.State()
    local picking = s.unchosen == true
    if ui.window.picking ~= picking then
        ui.window.picking = picking
        Pet.Layout()
    end
    local offer = picking and Offer() or nil
    for i, pick in ipairs(ui.picks) do
        pick:SetShown(picking)
        local kind = offer and Rules.EGGS[offer[i]]
        local file = kind and Art(kind.species .. "_egg")
        if file and pick.file ~= file then
            pick.file = file
            pick.picture:SetTexture(file, "CLAMP", "CLAMP", "NEAREST")
            pick.name:SetText((kind.name:gsub(" egg$", "")))
        end
    end
    ui.body:SetShown(not picking and not ui.yard)
    ui.yardToggle:SetShown(not picking and not ui.window.out)
    if picking then
        ui.yard = false
        ui.title:SetText("Choose your pal")
        ui.pickLine:SetText(ui.said or "Three eggs have turned up. Click one for a closer look.")
        for _, heap in ipairs(ui.heaps) do heap:Hide() end
        ui.pen.dark, ui.pen.shade, ui.walk = 0, 0, nil
        Sky()
        Pet.PaintNest(s)
        Pet.PaintVisitor(s)
        Pet.PaintPlay(s)
        return
    end
    s = Rules.Advance(s, Now())
    if ui.window.yard ~= ui.yard then
        ui.window.yard = ui.yard
        Pet.Layout()
    end
    ui.yardToggle:SetLabel(ui.yard and "Back" or ("Paddock · %d"):format(#Settled()))
    if ui.yard then
        ui.title:SetText("The paddock")
        for _, heap in ipairs(ui.heaps) do heap:Hide() end
        ui.prop:Hide()
        -- The paddock has scenery of its own for the kind of country you're in,
        -- as late as the realm's clock says, under the weather where you are.
        Pet.Backdrop("paddock_" .. Pet.Scene(Pet.where))
        ui.pen.dark = Pet.Hours(Compat.Hour())
        ui.pen.shade = ui.pen.dark
        Sky()
        Pet.PaintNest(s)
        Pet.PaintVisitor(s)
        Pet.PaintWeather()
        Pet.PaintPlay(s)
        return PaintYard(s)
    end
    for _, r in ipairs(ui.roamers) do r.body:Hide() end
    ui.title:SetText(ui.looking and (Own(ui.looking) and ("%s as a %s"):format(s.name, ui.looking.name) or ("A look at the %s"):format(ui.looking.name))
        or ("%s the %s"):format(s.name, FormName(s)))
    local day = math.floor(math.max(0, Now() - s.born) / 86400) + 1
    local growing = Growing(s)
    -- How it is, as you'd say it; under it, its age and when it grows.
    ui.headline:SetText(Pet.Headline(s))
    ui.sub:SetText(("Day %d · %s"):format(day, growing or Pet.TendWords(s, Eggs()) or "fully grown"))
    -- The one that looked after its egg may have come by.
    Pet.PaintVisitor(s)
    -- Not yet told of: it's new, and breaks out of its egg as you first see it.
    local fresh = not s.told
    local outgrown = Rules.Outgrown(s)
    ui.said = Milestones(s) or ui.said
    -- Grown out of the nest it hatched in: the nest goes, and it's said once.
    if outgrown then ui.said = (ui.said and (ui.said .. " ") or "") .. ("%s has outgrown its nest."):format(s.name) end
    ui.message:SetText(ui.said or "")
    local wish, granted = WishText(s)
    ui.wishLine:SetText(wish)
    ui.wishLine:SetTextColor(Style.Color(granted and "muted" or "text"))
    ui.wishTag:SetText(granted and "done" or "not yet")
    ui.wishTag:SetTextColor(Style.Color(granted and "green" or "muted"))
    Pet.PaintBond(s)
    -- Each need as five pips in a colour of its own; a low one is red, and
    -- says what's wrong.
    for _, need in ipairs(Rules.NEEDS) do
        local bar = ui.bars[need]
        local full = s[need] <= 0 and 0 or math.max(1, math.floor(s[need] / 20 + 0.5))
        local low = s[need] < 20
        for i, pip in ipairs(bar.pips) do
            if i > full then
                -- An empty pip is a grey you can see: the title bar's colour
                -- was a shade off the window's.
                pip:SetColorTexture(Style.Color("lineStrong"))
            elseif low then
                pip:SetColorTexture(Style.Color("red"))
            else
                pip:SetColorTexture(bar.tint[1], bar.tint[2], bar.tint[3])
            end
        end
        bar.label:SetTextColor(Style.Color(low and "red" or "secondary"))
        bar.low:SetText(low and (Pet.LOW[need] .. "!") or "")
    end
    for i, heap in ipairs(ui.heaps) do heap:SetShown(i <= s.droppings) end
    ui.snore:SetShown(s.asleep)
    -- Ready to grow: the button for it, until it is pressed. Only in its pen:
    -- out with you it waits.
    ui.growButton:SetShown(s.grewFrom ~= nil and not s.unchosen and not ui.looking and not ui.window.out
        and not (ui.walk and ui.walk.act and ui.walk.act.name == "grow"))
    -- Asleep, the pen is the same meadow by moonlight, and on the way there
    -- at sunset (tools/make_pet_night.py makes both), drawn over the day one:
    -- how far the day has gone is `shade`, which each frame moves toward
    -- `dark`. First shown, it's already where it should be.
    -- Out with you there's no meadow to darken, and it keeps its own colours.
    -- In its pen it's night while it sleeps, and otherwise as late as the realm's clock says.
    ui.pen.dark = ui.window.out and 0 or s.asleep and 1 or Pet.Hours(Compat.Hour())
    -- The pen is in the kind of country you're in.
    Pet.Backdrop(Pet.Scene(Pet.where))
    -- And what's on its mind, for its bubble.
    local free = 0
    for bag = 0, 4 do free = free + (Compat.BagFree(bag) or 0) end
    ui.pen.thought = Pet.Thought(s, Now(), free)
    Pet.PaintWeather()
    -- The egg it's looking after, in its nest; and the button to hatch it.
    Pet.PaintNest(s)
    if not ui.pen.shade then
        ui.pen.shade = ui.pen.dark
        Sky()
    end
    ui.care.meal:SetLabel(("Feed · %d"):format(s.supplies.meal))
    ui.care.treat:SetLabel(("Treat · %d"):format(s.supplies.treat))
    ui.care.toy:SetLabel(("Play · %d"):format(s.supplies.toy))
    ui.care.soap:SetLabel(("Bath · %d"):format(s.supplies.soap))
    ui.care.medicine:SetLabel(("Medicine · %d"):format(s.supplies.medicine))
    ui.care.medicine:SetEnabled(s.sick)
    -- Newly poorly, or found so as its window opens: a small sad sound, once.
    if s.sick and not ui.pen.sick then Pet.Sound("poorly") end
    ui.pen.sick = s.sick and true or false
    ui.care.lights:SetLabel(s.asleep and "Wake it" or "Lights out")
    Pet.DressCare(s)
    -- A form that has grown is drawn larger, and starts from a spot that fits it.
    -- Out with you, every form is at the art's own size, and keeps to its strip.
    local size, strip = SIZES[Form()] or SIZE, nil
    if ui.window.out then size, strip = ui.outSize, ui.stripW end
    local anew = not ui.walk or ui.walk.size ~= size or ui.walk.strip ~= strip
    if anew then
        local was = ui.walk
        ui.walk = Pet.NewWalk(math.random, size, strip)
        if strip then Pet.KeepOnScreen() end
        -- Changing under the light it grows in: it stays where it stands, its
        -- feet where they were, and goes on with what it was about.
        if was and was.act and was.act.name == "grow" and was.strip == strip then
            local x = math.max(0, math.min((strip or PEN_W) - size, was.x + (was.size - size) / 2))
            local y = strip and ui.walk.y or math.max(0, math.min(PEN_H - size, was.y + was.size - size))
            ui.walk.x, ui.walk.y, ui.walk.tx, ui.walk.ty = x, y, x, y
            ui.walk.act, ui.walk.grown, ui.walk.facing, ui.walk.wait = was.act, was.grown, was.facing, 1
        end
    end
    Pet.KeepOffNest()
    -- Asleep already as its window opens, or as it's drawn anew (back from out with you, or after a
    -- /reload): it's in bed, lying down, not stood up to walk there.
    if s.asleep and (anew or ui.opening) and not (ui.walk.act and ui.walk.act.name == "grow") then Pet.Abed(ui.walk) end
    ui.opening = nil
    -- One that hatched in its nest a moment ago is put there, and has hatched already.
    local hatched = Pet.PlaceHatchling()
    if fresh and not ui.looking and not hatched and Pet.Play(ui.walk, Sheet(), "hatch") then Pet.Sound("hatch") end
    PaintWalk()
    -- The eggs you hold, each with its picture, and where they came from.
    local eggs = Eggs()
    local names = {}
    for i, slot in ipairs(ui.eggSlots) do
        local egg = eggs[i]
        local kind = egg and Rules.EGGS[egg.kind]
        slot:SetShown(kind ~= nil)
        slot.egg = kind and kind.name or nil
        if kind then
            local file = Art(kind.species .. "_egg")
            if slot.file ~= file then
                slot.file = file
                slot.picture:SetTexture(file, "CLAMP", "CLAMP", "NEAREST")
            end
            names[#names + 1] = ("%s (%s)"):format(kind.name, egg.from or "found")
        end
    end
    -- (A boss's egg kept aside, past the three shown, is counted at the front,
    -- where a long line isn't cut.)
    local aside = #eggs - #ui.eggSlots
    local nested = Rules.Tending(s)
    ui.eggLine:SetText(nested and #names == 0 and ("In the nest: %s."):format(nested.name)
        or #names > 0 and ((nested and ("In the nest: %s. Waiting: "):format(nested.name)
            or aside > 0 and ("Eggs (%d more kept safe): "):format(aside) or "Eggs: ") .. table.concat(names, ", "))
        or Rules.CanFind(s) and "No eggs yet. A quest, a flight, a new level, a new zone, a fight won or coming back from the dead can turn one up."
        or ("Eggs turn up from your play once %s is fully grown."):format(s.name))
    -- The card for a companion that has just settled, over the top of the page.
    Pet.PaintFarewell()
    Pet.PaintPlay(s)
    -- Repainted while an egg is hatching, the buttons stay greyed.
    if ui.pen.busy then Pet.Grey(true) end
    -- Just hatched and not yet named: the name box opens by itself, with the
    -- name it would otherwise have ready to type over.
    if s.unnamed and not ui.nameBox.asking then
        ui.nameBox.asking = true
        NameBox(true)
    elseif not s.unnamed then
        ui.nameBox.asking = nil
        if ui.nameBox.open then NameBox(false) end
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
    -- Not while an egg is hatching: the scene has the pen to itself.
    if ui.pen and ui.pen.hatching then return false end
    ui.play.touched = Pet.tick or 0
    local s = Pet.State()
    local grubby, ill = Rules.Dirty(s), s.sick
    local ok, what = act(s, Now())
    ui.said = what
    -- In its pen and awake, a meal, a treat or a toy is in your hand first:
    -- where it goes is yours to say (Pet.Clicked, Pet.Petted), and it's heard
    -- when the creature gets to it.
    local here = ok and ui.walk and not s.asleep and not ui.window.out
    local hand = here and IN_HAND[thing] or nil
    -- And a bath is a brush in your hand, to scrub it with.
    local scrub = here and over == "bath"
    if ok and not hand and not scrub then Pet.Sound(sound == "lights" and (s.asleep and "sleep" or "wake") or sound) end
    if ok and ui.walk then ui.walk.errand, ui.walk.chase, ui.pen.held, ui.pen.toss = nil, nil, nil, nil end
    if hand then
        ui.pen.held = { thing = thing, show = show, sound = sound, what = what, clock = 0 }
        ui.said = hand.hint
    elseif scrub then
        ui.pen.held = { thing = "scrubber", show = show, over = over, sound = sound, what = what, clock = 0,
            scrub = 0, grubby = grubby, ill = ill }
        ui.said = "Rub the brush over it to scrub it clean, or click it for a quick wash."
    elseif ok and ui.walk and show then
        if show == "lights" then
            Pet.Play(ui.walk, Sheet(), s.asleep and "doze" or "wake")
        elseif not s.asleep and Pet.Play(ui.walk, Sheet(), show) then
            ui.walk.act.prop, ui.walk.act.effect, ui.walk.act.grubby, ui.walk.act.ill = thing, over, grubby, ill
        end
    end
    Refresh()
    return ok
end

-- What's in your hand is set down in front of it, where it stands: when you
-- take too long to say where, or click the creature with its bowl or ball.
function Pet.SetDown()
    local held = ui.pen.held
    if not (held and ui.walk) then return end
    ui.pen.held = nil
    if Pet.Play(ui.walk, Sheet(), held.show) then
        if held.over then
            -- The brush: a quick wash, tub and suds and all, as a bath always was.
            ui.walk.act.effect, ui.walk.act.grubby, ui.walk.act.ill = held.over, held.grubby, held.ill
        else
            ui.walk.act.prop = held.thing
        end
    end
    Pet.Sound(held.sound)
    ui.said = held.what
    Refresh()
end

-- The grass was clicked, at (x, y) from the pen's top left corner (where the
-- pointer is, unless told). With something in your hand it goes there, and
-- the creature after it; a ball it has brought back is thrown again; with
-- nothing, the creature comes over.
function Pet.Clicked(x, y)
    if not ui.walk or ui.window.out or ui.yard or ui.pen.toss then return end
    local s = Pet.State()
    if s.unchosen or s.asleep then return end
    if not x then x, y = Compat.CursorAt(ui.pen) end
    if not x then return end
    ui.play.touched = Pet.tick or 0
    if Pet.Seek(x, y) then return end
    local held, errand = ui.pen.held, ui.walk.errand
    if held and held.scrub then return end      -- the brush is for the creature, not the grass
    if held then
        ui.pen.held = nil
        local sent = Pet.Send(ui.walk, x, y, held.thing, IN_HAND[held.thing].fly, held.thing == "ball")
        sent.show, sent.sound, sent.what = held.show, held.sound, held.what
        if sent.fetch then Pet.Sound(held.sound) end
        ui.said = held.what
        Refresh()
        -- A throw of the ball counts toward a wish for a game of fetch.
        if sent.fetch then Pet.Did("fetch") end
    elseif errand and errand.phase == "wait" and errand.throws < THROWS then
        local ok, what = Rules.Fetch(s, Now())
        ui.said = what
        if ok then
            Pet.Send(ui.walk, x, y, "ball", IN_HAND.ball.fly, true)
            Pet.Sound("play")
        else
            ui.walk.errand = nil
        end
        Refresh()
        if ok then Pet.Did("fetch") end
    elseif not errand and not ui.walk.act then
        Pet.Call(ui.walk, x, y)
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
    ui.play.touched = Pet.tick or 0
    -- Hiding: there it is!
    if button ~= "RightButton" and Pet.Seek(nil, nil, true) then return end
    if button == "RightButton" then return Pet.Trick() end
    local held, toss = ui.pen.held, ui.pen.toss
    if toss then
        if toss.spent or not ui.walk then return end
        local t = toss.clock / TOSS
        local up, good = Pet.Tossed(t)
        local sheet = Sheet()
        if good then
            ui.pen.toss = nil
            local s = Pet.State()
            local _, what = Rules.Caught(s, Now())
            if Pet.Play(ui.walk, sheet, "catch") or Pet.Play(ui.walk, sheet, "jump") then
                ui.walk.act.prop, ui.walk.act.toss, ui.walk.act.from, ui.walk.act.lean = "treat", true, up, 0.3 * t
            end
            Pet.Sound(toss.sound)
            -- One treat too many is still the news, however it was given.
            ui.said = s.sick and toss.what or what
        else
            toss.spent = true
            Pet.Play(ui.walk, sheet, "jump")
            ui.said = t < CATCH_FROM and "Too soon! It jumps at nothing." or "Too late! It jumps at nothing."
        end
        Refresh()
        -- A catch may be the very thing it wished for today.
        if good then Pet.Did("catch") end
        return
    end
    if not held then return Do(Rules.Pat, "jump", nil, nil, "pat") end
    if held.thing ~= "treat" then return Pet.SetDown() end
    ui.pen.held = nil
    ui.pen.toss = { clock = 0, what = held.what, sound = held.sound }
    -- It stops where it is and watches it go up.
    ui.walk.act, ui.walk.errand, ui.walk.running = nil, nil, nil
    ui.walk.tx, ui.walk.ty, ui.walk.wait = ui.walk.x, ui.walk.y, TOSS + 1
    ui.said = "Up it goes! Click your pal when the treat sparkles."
    Refresh()
end

-- Right-clicked, it's asked for a trick: one of those its bond has taught
-- it (Rules.Trick), picked by Pet.Pick. In its pen or out with you.
function Pet.Trick()
    if not ui.walk or ui.yard or ui.pen.held or ui.pen.toss or ui.walk.errand or ui.walk.nap then return end
    local s = Pet.State()
    if s.unchosen then return end
    local ok, what, anim = Rules.Trick(s, Now(), Pet.Pick)
    ui.said = what
    if ok then
        ui.walk.chase = nil
        if Pet.Play(ui.walk, Sheet(), anim) or Pet.Play(ui.walk, Sheet(), "jump") then Pet.Sound("pat") end
    end
    Refresh()
end

-- The pointer in its pen: wiggled, it's something to chase. It runs after
-- it for CHASE seconds, and when it gets there it pounces (Rules.Pounce).
local function Chase(sheet, dt)
    local chase = ui.walk.chase
    if ui.pen.held or ui.pen.toss or ui.walk.errand or ui.walk.act or (ui.play.rub and ui.play.rub.strokes > 0) or not ui.pen:IsMouseOver() then
        ui.pen.trail = nil
        if chase then ui.walk.chase, ui.walk.running = nil, nil end
        return
    end
    local x, y = Compat.CursorAt(ui.pen)
    if not x then return end
    if not chase then
        ui.pen.trail = ui.pen.trail or {}
        if Pet.Trail(ui.pen.trail, x, y, dt) then ui.walk.chase, ui.pen.trail = { left = CHASE }, nil end
        return
    end
    chase.left = chase.left - dt
    -- Its feet to the pointer, as when it's called over.
    local size = ui.walk.size
    local tx = math.max(0, math.min(PEN_W - size, math.floor(x - size / 2)))
    local ty = math.max(math.max(0, math.floor(GRASS - size * 0.92)), math.min(PEN_H - size, math.floor(y - size * 0.96)))
    local dx, dy = tx - ui.walk.x, ty - ui.walk.y
    if dx * dx + dy * dy <= 36 then
        ui.walk.chase, ui.walk.running, ui.walk.wait = nil, nil, 1
        local _, what = Rules.Pounce(Pet.State(), Now())
        Pet.Play(ui.walk, sheet, "jump")
        Pet.Sound("play")
        ui.said = what
        Refresh()
    elseif chase.left <= 0 then
        ui.walk.chase, ui.walk.running = nil, nil
    else
        ui.walk.tx, ui.walk.ty, ui.walk.wait, ui.walk.running = tx, ty, 0, true
        if dx ~= 0 then ui.walk.facing = dx > 0 and "right" or "left" end
    end
end

-- Food and play in the pen, moved on by `dt`: what's in your hand waits only
-- so long, and an errand says what happened as it goes.
local function Tend(sheet, dt)
    local held = ui.pen.held
    if held and held.scrub then
        -- The brush: it stands still for it, and rubbing the pointer over it
        -- is the scrubbing. Rubbed enough, it's clean, with a sparkle.
        ui.walk.tx, ui.walk.ty, ui.walk.wait = ui.walk.x, ui.walk.y, math.max(ui.walk.wait, 0.5)
        local x, y = Compat.CursorAt(ui.pen)
        local on = x and x >= ui.walk.x and x <= ui.walk.x + ui.walk.size and y >= ui.walk.y and y <= ui.walk.y + ui.walk.size
        if on and held.px then
            local moved = math.abs(x - held.px) + math.abs(y - held.py)
            if moved > 0 then held.scrub, held.clock = held.scrub + math.min(moved, 60), 0 end
        end
        held.px, held.py = on and x or nil, on and y or nil
        if held.scrub >= SCRUB then
            ui.pen.held = nil
            if Pet.Play(ui.walk, sheet, held.show) then
                ui.walk.act.effect, ui.walk.act.clock = held.over, ui.walk.act.length / 2
            end
            Pet.Sound(held.sound)
            ui.said = held.what
            Refresh()
        end
    end
    held = ui.pen.held
    if held then
        held.clock = held.clock + dt
        if held.clock >= HOLD then Pet.SetDown() end
    end
    local toss = ui.pen.toss
    if toss then
        toss.clock = toss.clock + dt
        ui.walk.wait = math.max(ui.walk.wait, 0.5)
        -- Coming down to it: it gets ready to leap, for as long as it can be caught.
        if not (toss.ready or toss.spent) and toss.clock >= CATCH_FROM * TOSS then
            toss.ready = true
            if Pet.Play(ui.walk, sheet, "ready") then ui.walk.act.length = (CATCH_TO - CATCH_FROM) * TOSS end
        end
        if toss.clock >= TOSS then
            -- Nobody caught it: it's on the grass, and eaten there.
            ui.pen.toss, ui.walk.act = nil, nil
            if Pet.Play(ui.walk, sheet, "eat") then ui.walk.act.prop = "treat" end
            Pet.Sound(toss.sound)
            ui.said = "Missed. It eats it off the grass."
            Refresh()
        end
    end
    local errand = ui.walk.errand
    local did = Pet.Errand(ui.walk, sheet, dt)
    if did == "there" then
        Pet.Sound(errand.sound)
        ui.said = errand.what
        Refresh()
    elseif did == "back" then
        ui.said = errand.throws < THROWS and "It brings it back. Click the grass to throw it again." or "It brings it back, puffed and pleased."
        Refresh()
    end
    Chase(sheet, dt)
end

-- Out with you, only the creature's own picture keeps to the screen, right up to each edge: its strip may run
-- off one, and its buttons and "z z z" with it. The strip is moved back just far enough for the picture to be on
-- the screen, and it walks to and fro only on the part of the strip that's on it. Worked out where it's placed,
-- not as it walks.
function Pet.KeepOnScreen()
    local walk = ui.walk
    if not (ui.window and ui.window.out and walk and walk.strip and UIParent) then return end
    local left, bottom = ui.window:GetLeft(), ui.window:GetBottom()
    local wide = UIParent.GetWidth and UIParent:GetWidth()
    local high = UIParent.GetHeight and UIParent:GetHeight()
    if not (left and bottom and wide and high and wide > 0 and high > 0) then return end
    local size = walk.size
    local x = left + walk.x
    local dx = (x < 0 and -x) or (x + size > wide and wide - (x + size)) or 0
    local dy = (bottom < 0 and -bottom) or (bottom + size > high and high - (bottom + size)) or 0
    if dx ~= 0 or dy ~= 0 then
        left, bottom = left + dx, bottom + dy
        ui.window:ClearAllPoints()
        ui.window:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
    end
    walk.lo = math.max(0, math.ceil(-left))
    walk.hi = math.max(walk.lo, math.floor(math.min(walk.strip, wide - left) - size))
    walk.tx = math.max(walk.lo, math.min(walk.hi, walk.tx))
end

-- Where you dragged it to is kept.
local function Dropped()
    ui.window:StopMovingOrSizing()
    Pet.KeepOnScreen()
    local point, _, relative, x, y = ui.window:GetPoint(1)
    -- The window and the creature out with you each have a place of their own.
    if point then ns.db[ui.window.out and "petOutAt" or "petAt"] = { point, relative, x, y } end
end

-- Puts the window where it was last left in the way it's showing now: as a
-- window, or out with you (the first time, low in the middle of the screen).
local function Place()
    local at = ui.window.out and ns.db.petOutAt or not ui.window.out and ns.db.petAt
    ui.window:ClearAllPoints()
    if type(at) == "table" and at[1] then
        ui.window:SetPoint(at[1], UIParent, at[2] or at[1], at[3] or 0, at[4] or 0)
    elseif ui.window.out then
        -- The first time: at the very foot of the screen, a little right of the
        -- middle, clear of where the action bars usually are. Dragged, it stays put.
        local wide = UIParent and UIParent.GetWidth and UIParent:GetWidth() or 1366
        ui.window:SetPoint("BOTTOM", UIParent, "BOTTOM", math.floor(wide * 0.23), 0)
    else
        ui.window:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    end
    Pet.KeepOnScreen()
end

-- Out with you, it's one of the pieces Unlock Mode moves (/jsal unlock):
-- named, sized as its strip, and kept in the same spot it's dragged to.
local function Movable()
    if not (ns.Unlock and ns.Unlock.Add) or Pet.movable then return end
    Pet.movable = true
    ns.Unlock.Add({
        key = "Companion", label = "your pal",
        frame = function() return ui.window and ui.window.out and ui.window or nil end,
        size = function() return ui.stripW, ui.stripH end,
        load = function() return ns.db.petOutAt end,
        save = function(point, relative, x, y)
            ns.db.petOutAt = point and { point, relative, x, y } or nil
            if ui.window and ui.window.out then Place() end
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
    if ui.mute.file ~= file then
        ui.mute.file = file
        ui.mute.icon:SetTexture(file, "CLAMP", "CLAMP", "NEAREST")
    end
end

-- Its sounds off, or on again: the button in the pen's corner, and the same
-- switch as Sounds under Companion in Settings. Turned on, it chirps to say so.
function Pet.Mute()
    ns.SetOption("pet", "sound", not ns.OptionOn("pet", "sound"))
    if ui.mute then PaintMute() end
    Pet.Sound("pat")
end

-- For the pet's other files.
inner.Refresh, inner.Do, inner.Tend, inner.Dropped, inner.Place = Refresh, Do, Tend, Dropped, Place
inner.Escapes, inner.PaintMute = Escapes, PaintMute
