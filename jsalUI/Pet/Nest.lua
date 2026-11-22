-- Eggs and the nest: a new player's pick of three eggs, an egg hatching in
-- the pen, an egg kept warm in the nest, the companion that tended it
-- coming to visit, and the farewell when one settles in the paddock.
local _, ns = ...
local Style, Compat, Rules, Pet = ns.Style, ns.Compat, ns.PetRules, ns.Pet
local inner = Pet.inner
local ui = inner.ui
local Art, PEN_H, PEN_W, SIZE, SIZES = inner.Art, inner.PEN_H, inner.PEN_W, inner.SIZE, inner.SIZES
local SHEETS, Now, Offer, FormName, Eggs = inner.SHEETS, inner.Now, inner.Offer, inner.FormName, inner.Eggs
local Settled, Sheet, PaintRoamer, Refresh = inner.Settled, inner.Sheet, inner.PaintRoamer, inner.Refresh
local IsOpen = inner.IsOpen

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
        ui.said = ("The %s. %s Click it again to make it yours."):format(kind.name, kind.hint)
        return Refresh()
    end
    Pet.armed = nil
    local young = Rules.New(Now(), nil, kind.species)
    for supply, count in pairs(s.supplies) do
        young.supplies[supply] = math.max(young.supplies[supply] or 0, count)
    end
    young.unnamed = true
    ns.db.pet = young
    ui.looking, ui.walk = nil, nil
    ui.said = ("It's hatching! Name your %s: type a name and press Enter."):format(FormName(young, 1))
    if ui.window then Refresh() end
end

-- A right-click on one of your eggs lets it go: it's off your list, and one
-- kept aside moves up into its place. That can't be undone, so the first
-- right-click only says what will happen and the second, on the same egg,
-- does it.
function Pet.LetEggGo(index)
    local eggs = Eggs()
    local egg = eggs[index]
    local kind = egg and Rules.EGGS[egg.kind]
    if not kind then return end
    Pet.armed, Pet.lifting = nil, nil
    if Pet.letting ~= index then
        Pet.letting = index
        ui.said = ("Right-click again: the %s is let go for good."):format(kind.name)
    else
        Pet.letting = nil
        table.remove(eggs, index)
        ui.said = ("You let the %s go."):format(kind.name)
    end
    if IsOpen() then Refresh() end
end

-- A click on one of your eggs. A fully grown companion takes it into a nest
-- in the pen and looks after it until it's ready to hatch (Rules.Tend); an
-- egg already there goes back with the others, and the warming starts
-- again. So the first click only says what will happen and the second does
-- it.
function Pet.HatchEgg(index)
    if ui.pen and ui.pen.hatching then return end
    local s, eggs = Pet.State(), Eggs()
    local egg = eggs[index]
    local kind = egg and Rules.EGGS[egg.kind]
    if not kind then return end
    Pet.letting, Pet.lifting = nil, nil
    local ok, why = Rules.CanTend(s)
    local nested = Rules.Tending(s)
    if not ok then
        Pet.armed = nil
        ui.said = ("%s Once %s is fully grown it can look after this egg in a nest until it hatches."):format(why, s.name)
    elseif Pet.armed ~= index then
        Pet.armed = index
        ui.said = nested and ("Click again: the %s takes the %s's place in the nest, and the warming starts again."):format(kind.name, nested.name)
            or ("Click again: %s takes the %s into a nest, and looks after it until it hatches."):format(s.name, kind.name)
    else
        Pet.armed = nil
        local done, whyNot = Rules.Tend(s, eggs, index, Now())
        if not done then
            ui.said = whyNot
        else
            -- In a trial there's no waiting: it's ready at once.
            if ns.db.petAside then s.nest.warm = Rules.TEND end
            ui.said = ("%s settles down beside the %s."):format(s.name, kind.name)
        end
    end
    if IsOpen() then Refresh() end
end

-- A right-click on the nest takes its egg out, back with your others. Its
-- warming is lost, so the first right-click only says so.
function Pet.NestOut()
    if ui.pen and ui.pen.hatching then return end
    local s = Pet.State()
    local kind = Rules.Tending(s)
    if not kind then return end
    Pet.armed, Pet.letting = nil, nil
    if not Pet.lifting then
        Pet.lifting = true
        ui.said = ("Right-click again: the %s comes out of the nest, back with your other eggs. Its warming is lost."):format(kind.name)
    else
        Pet.lifting = nil
        local ok, why = Rules.Untend(s, Eggs())
        ui.said = ok and ("The %s is back with your other eggs."):format(kind.name) or why
    end
    if IsOpen() then Refresh() end
end

-- The Hatch button, in the pen once the egg in the nest is ready: the egg
-- hatches, and the companion that looked after it settles in the paddock.
-- A card says what the paddock keeps of it, and the hatchling is named.
function Pet.HatchNest()
    local s = Pet.State()
    local ok = Rules.CanTend(s)
    local kind, _, ready = Rules.Tending(s)
    -- In its pen and awake, it's a scene (Pet.Hatching): the companion
    -- hurries to the nest, watches the egg hatch there, dotes on the
    -- hatchling, and then walks away to the paddock. Anywhere else, or
    -- asleep, the egg hatches at once.
    if ok and kind and ready and IsOpen() and ui.walk and ui.nest and not ui.window.out and not ui.window.yard and not s.asleep
        and not ui.pen.hatching then
        ui.pen.hatching = { phase = "gather", clock = 0, kind = kind }
        Pet.Busy(true)
        ui.walk.act, ui.walk.errand, ui.walk.nap, ui.walk.beside, ui.walk.doting = nil, nil, nil, nil, nil
        ui.walk.tx, ui.walk.ty = math.max(0, ui.walk.keep or 0), PEN_H - ui.walk.size
        ui.walk.wait, ui.walk.clock, ui.walk.running = 0, 0, true
        if ui.walk.tx ~= ui.walk.x then ui.walk.facing = ui.walk.tx > ui.walk.x and "right" or "left" end
        ui.hatchButton:Hide()
        ui.said = ("%s hurries over to the %s: it's hatching!"):format(s.name, kind.name)
        ui.message:SetText(ui.said)
        return
    end
    Pet.FinishHatch()
end

-- While an egg is hatching nothing else can be done: a cover over the pen
-- and all under it takes every click, so no care is given, nothing is
-- thrown, no egg is clicked and the pen isn't left for the paddock or sent
-- out. The window can still be closed.
function Pet.Busy(on)
    if on and not ui.busy then
        ui.busy = CreateFrame("Button", nil, ui.window)
        ui.busy:SetPoint("TOPLEFT", ui.pen, "TOPLEFT")
        ui.busy:SetPoint("BOTTOMRIGHT", ui.window, "BOTTOMRIGHT")
        ui.busy:SetFrameLevel(90)
        ui.busy:EnableMouse(true)
        ui.busy:RegisterForClicks("AnyUp")
    end
    if ui.busy then ui.busy:SetShown(on and true or false) end
    ui.pen.busy = on and true or false
    Pet.Grey(ui.pen.busy)
end

-- And what can't be clicked then is greyed, so it's plain that it can't:
-- the care buttons, the eggs, and the buttons in the pen's corners. Each
-- goes back to how it was.
function Pet.Grey(on)
    local list = { ui.yardToggle, ui.outButton, ui.fold, ui.mute }
    for _, button in pairs(ui.care or {}) do list[#list + 1] = button end
    for _, slot in ipairs(ui.eggSlots) do list[#list + 1] = slot end
    for _, piece in ipairs(list) do
        if on then
            if not piece.greyWas then piece.greyWas = piece.GetAlpha and piece:GetAlpha() or 1 end
            piece:SetAlpha(0.3)
        elseif piece.greyWas then
            piece:SetAlpha(type(piece.greyWas) == "number" and piece.greyWas > 0 and piece.greyWas or 1)
            piece.greyWas = nil
        end
    end
end

-- The hatchling as it hatches in the nest, before it's the pen's own
-- companion: drawn as the paddock's are, at a hatchling's size in the pen.
function Pet.Chick(kind)
    local c = ui.chick
    if not c then
        c = { body = CreateFrame("Frame", nil, ui.pen) }
        ui.chick = c
        c.sprite = c.body:CreateTexture(nil, "ARTWORK")
        c.sprite:SetPoint("CENTER")
        Compat.Crisp(c.sprite)
        c.snore = Style.Text(c.body, 11, "secondary", nil, true)
        c.snore:Hide()
    end
    local sprites = Rules.SPECIES[kind.species].sprites
    c.sheet, c.size = SHEETS[sprites[1]], SIZES[1] or 64
    c.body:SetSize(c.size, c.size)
    c.walk, c.nap, c.file, c.drawn = Pet.NewWalk(math.random, c.size), nil, nil, nil
    -- In the nest's hollow, facing the one that looked after its egg.
    local w = c.walk
    w.x, w.y = Pet.BedSpot(c.size)
    w.tx, w.ty, w.wait, w.facing = w.x, w.y, 99, "left"
    c.body:Show()
    return c
end

-- Where a creature of that size stands to be in the nest's hollow.
function Pet.BedSpot(size)
    local N = Pet.NEST
    return N.x + 64 - size / 2, PEN_H - N.y - 42 - size
end

-- Already asleep as it's drawn: lying in its nest's hollow if that's its bed, else where it stands, with
-- no walk there. ToBed's walk and lying down are for falling asleep while you watch.
function Pet.Abed(walk)
    if ui.nestBack and ui.nestBack:IsShown() and Rules.Bed(Pet.State()) then
        walk.x, walk.y = Pet.BedSpot(walk.size)
        walk.facing = "left"
    end
    walk.tx, walk.ty, walk.act, walk.errand, walk.doting = walk.x, walk.y, nil, nil, nil
    walk.frame, walk.wait = "sleep", math.max(walk.wait or 0, 0.5)
end

-- Bedtime, each frame it's asleep or napping: with a nest for a bed, it
-- goes there first, and settles down in it. True while it's on its way.
function Pet.ToBed(dt)
    if not (ui.walk and ui.nestBack and ui.nestBack:IsShown() and Rules.Bed(Pet.State())) then return false end
    local bx, by = Pet.BedSpot(ui.walk.size)
    if ui.walk.x == bx and ui.walk.y == by then return false end
    ui.walk.act, ui.walk.tx, ui.walk.ty, ui.walk.wait = nil, bx, by, 0
    ui.walk.facing = bx > ui.walk.x and "right" or "left"
    Pet.Step(ui.walk, dt, math.random)
    if ui.walk.x == bx and ui.walk.y == by then
        ui.walk.facing = "left"
        Pet.Play(ui.walk, Sheet(), "doze")
    end
    return true
end

-- Each frame of the hatching, a step at a time:
--   gather  the companion hurries to the nest's side
--   stir    it watches; the egg rocks hard
--   hatch   the egg is gone and the hatchling is in the nest
--   dote    the companion fusses over it
--   leave   and walks away to the paddock, out of the pen's left side
-- Then the hatchling is yours (Pet.FinishHatch).
Pet.HATCH = { gather = 5, stir = 1.6, hatch = 1.2, dote = 5.5, leave = 12 }
function Pet.Hatching(dt)
    local h = ui.pen.hatching
    if not h then return end
    if not ui.walk then return Pet.FinishHatch() end
    h.clock = h.clock + dt
    local s = Pet.State()
    local function Next(phase, words)
        h.phase, h.clock = phase, 0
        if words then
            ui.said = words
            ui.message:SetText(ui.said)
        end
    end
    if h.phase == "gather" then
        if (ui.walk.x == ui.walk.tx and ui.walk.y == ui.walk.ty) or h.clock >= Pet.HATCH.gather then
            ui.walk.x, ui.walk.y, ui.walk.running, ui.walk.act = ui.walk.tx, ui.walk.ty, nil, nil
            ui.walk.wait, ui.walk.facing = 99, "right"
            Next("stir")
        end
    elseif h.phase == "stir" then
        ui.walk.wait, ui.walk.facing = 99, "right"
        if h.clock >= Pet.HATCH.stir then
            -- The egg goes, and the hatchling is there in its place: at its
            -- own size, from the end of its hatching (its start is the egg
            -- again, drawn small).
            h.popped = true
            ui.pen.rocking = false
            ui.nestEgg:Hide()
            h.chick = Pet.Chick(h.kind)
            local sheet = h.chick.sheet
            if sheet and sheet.hatch and Pet.Play(h.chick.walk, sheet, "hatch") then
                h.chick.walk.act.clock = math.min(h.chick.walk.act.length - 0.4, 8 * sheet.hatch.time)
            end
            Pet.Sound("hatch")
            Pet.Hearts(ui.nest)
            Next("hatch", ("The %s hatches!"):format(h.kind.name))
        end
    elseif h.phase == "hatch" then
        ui.walk.wait, ui.walk.facing = 99, "right"
        if h.clock >= Pet.HATCH.hatch then
            ui.walk.doting = { clock = 0, step = 0 }
            Next("dote", ("%s fusses over the new %s."):format(s.name, Rules.SPECIES[h.kind.species].forms[1]))
        end
    elseif h.phase == "dote" then
        if ui.walk.wait < 50 then ui.walk.wait = 99 end
        if h.clock >= Pet.HATCH.dote and not ui.walk.act then
            ui.walk.doting, ui.walk.act = nil, nil
            ui.walk.tx, ui.walk.ty, ui.walk.wait, ui.walk.clock, ui.walk.facing, ui.walk.brisk = -ui.walk.size - 8, ui.walk.y, 0, 0, "left", 1.5
            Pet.Hearts(ui.body)
            Pet.Sound("fanfare")
            Next("leave", ("%s heads for the paddock."):format(s.name))
        end
    elseif h.phase == "leave" then
        if ui.walk.x <= -ui.walk.size or h.clock >= Pet.HATCH.leave then return Pet.FinishHatch() end
    end
    if h.chick then
        Pet.Step(h.chick.walk, dt, math.random)
        h.chick.walk.wait = 99
        PaintRoamer(h.chick)
    end
end

-- The hatchling that hatched in the nest is put where it hatched, when it
-- becomes the pen's own companion. True when that's just been done: it has
-- hatched already, and doesn't again.
function Pet.PlaceHatchling()
    local at = ui.pen.hatchedAt
    if not (at and ui.walk) then return false end
    ui.pen.hatchedAt = nil
    ui.walk.x, ui.walk.y, ui.walk.tx, ui.walk.ty, ui.walk.wait, ui.walk.facing = at.x, at.y, at.x, at.y, 2, "left"
    return true
end

-- The egg in the nest hatches and the companion that looked after it is
-- settled in the paddock: the record, the hatchling, the card and the name.
function Pet.FinishHatch()
    -- After the scene, the hatchling goes on from where it hatched.
    local h = ui.pen.hatching
    ui.pen.hatching = nil
    Pet.Busy(false)
    if h and h.chick then
        ui.pen.hatchedAt = { x = h.chick.walk.x, y = h.chick.walk.y }
        h.chick.body:Hide()
    end
    local s = Pet.State()
    local old, form = s.name, FormName(s)
    local record, young = Rules.HatchNest(s, Now())
    if not record then
        ui.said = young
    else
        local settled = Settled()
        settled[#settled + 1] = record
        ns.db.pet = young
        ui.looking, ui.walk = nil, nil
        local J = ns.Journal
        if J and J.running then
            J.Note("pet", ("%s the %s settled in the paddock after %d day%s"):format(old, form, record.days, record.days == 1 and "" or "s"))
        end
        young.unnamed = true
        local level, bond = Rules.Bond(young)
        Pet.farewell = { record = record, form = form, young = FormName(young, 1), kept = level > 1 and bond or nil }
        ui.said = ("%s has settled in the paddock. Name your new %s: type a name and press Enter."):format(old, FormName(young, 1))
    end
    Pet.armed, Pet.letting, Pet.lifting = nil, nil, nil
    if IsOpen() then Refresh() end
end

-- What's said of the egg in the nest: how long it has to go, or that it's
-- ready. Nil with no egg there.
function Pet.TendLine(s)
    local kind, left, ready = Rules.Tending(s)
    if not kind then return nil end
    if ready then
        return ("The %s is ready to hatch. No hurry: %s settles in the paddock when it does."):format(kind.name, s.name)
    end
    local hours = math.max(1, math.ceil(left))
    return ("%s is looking after the %s: about %d hour%s of good care to go."):format(s.name, kind.name, hours, hours == 1 and "" or "s")
end

-- The same, short, for the line under how it is: after its age.
function Pet.TendWords(s, eggs)
    local kind, left, ready = Rules.Tending(s)
    if kind then
        if ready then return ("the %s is ready to hatch"):format(kind.name) end
        local hours = math.max(1, math.ceil(left))
        return ("tending the %s, about %dh of good care to go"):format(kind.name, hours)
    end
    if Rules.CanTend(s) and #eggs > 0 then return "fully grown: click an egg for it to look after" end
    return nil
end

-- The pen's pictures for a scene, by day, at sunset and by night: the pen's
-- own for the country you're in, or the paddock's for it.
function Pet.Backdrop(scene)
    if ui.pen.where == scene then return end
    ui.pen.where = scene
    ui.pen.scene:SetTexture(Art(scene), "CLAMP", "CLAMP", "NEAREST")
    ui.pen.dusk:SetTexture(Art(scene .. "_dusk"), "CLAMP", "CLAMP", "NEAREST")
    ui.pen.night:SetTexture(Art(scene .. "_night"), "CLAMP", "CLAMP", "NEAREST")
end

-- The nest, on the grass at the pen's right while a fully grown companion
-- has an egg to look after: the nest, the egg in it, and the nest's front
-- rim over the egg's foot. Pointing at it says how the egg is doing; a
-- right-click takes the egg out. Ready, the egg rocks, and the Hatch button
-- is there. Not in the paddock, out with you, or while an egg is chosen.
Pet.NEST = { x = PEN_W - 152, y = 4, lift = 36 }
function Pet.PaintNest(s)
    local kind, _, ready = Rules.Tending(s)
    -- The nest it hatched in stays as a hatchling's bed, until it grows.
    local home = kind == nil and Rules.Bed(s)
    local show = (kind ~= nil or home) and not ui.window.out and not ui.window.yard and not ui.window.picking and not ui.looking
    if not ui.nest then
        if not show then return end
        local N = Pet.NEST
        local function Layer(file, level, lift)
            local t = ui.pen:CreateTexture(nil, "ARTWORK", nil, level)
            t:SetSize(128, 128)
            t:SetPoint("BOTTOMLEFT", N.x, N.y + lift)
            if file then t:SetTexture(Art(file), "CLAMP", "CLAMP", "NEAREST") end
            Compat.Crisp(t)
            return t
        end
        ui.nestBack, ui.nestEgg, ui.nestFront = Layer("nest", 1, 0), Layer(nil, 2, N.lift), Layer("nest_front", 3, 0)
        local n = CreateFrame("Button", nil, ui.pen)
        ui.nest = n
        n:SetSize(84, 88)
        n:SetPoint("BOTTOMLEFT", N.x + 22, N.y)
        n:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        n:SetScript("OnClick", function(_, button)
            if button == "RightButton" then return Pet.NestOut() end
            Pet.lifting = nil
            ui.said = Pet.TendLine(Pet.State())
            Refresh()
        end)
        n:SetScript("OnEnter", function(self)
            if not self.egg then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(self.egg)
            GameTooltip:AddLine(Pet.TendLine(Pet.State()) or "", 1, 1, 1, true)
            GameTooltip:AddLine("Right-click: take it out of the nest.", 0.6, 0.59, 0.53, true)
            GameTooltip:Show()
        end)
        n:SetScript("OnLeave", function() GameTooltip:Hide() end)
        -- The front rim again, over whoever is in the nest (the hatchling
        -- as it hatches, or asleep in its bed): the companion is a frame, so
        -- it's drawn over everything the pen itself draws.
        ui.nestRim = CreateFrame("Frame", nil, ui.pen)
        ui.nestRim:SetSize(128, 128)
        ui.nestRim:SetPoint("BOTTOMLEFT", N.x, N.y)
        ui.nestRim:SetFrameLevel((ui.body:GetFrameLevel() or 1) + 1)
        ui.nestRim.picture = ui.nestRim:CreateTexture(nil, "ARTWORK")
        ui.nestRim.picture:SetAllPoints()
        ui.nestRim.picture:SetTexture(Art("nest_front"), "CLAMP", "CLAMP", "NEAREST")
        Compat.Crisp(ui.nestRim.picture)
        ui.nestRim.picture:Hide()
        ui.hatchButton = Style.Button(ui.pen, "Hatch", "primary", 96)
        ui.hatchButton:SetPoint("TOP", 0, -30)
        ui.hatchButton:SetFrameLevel(50)
        ui.hatchButton:SetScript("OnClick", function() Pet.HatchNest() end)
    end
    -- While it's hatching (Pet.Hatching), there's no button, and once the
    -- egg has gone it stays gone.
    local busy = ui.pen.hatching
    local egg = show and kind ~= nil and not (busy and busy.popped)
    for _, piece in ipairs({ ui.nestBack, ui.nestFront }) do piece:SetShown(show) end
    ui.nestEgg:SetShown(egg)
    ui.nest:SetShown(show and kind ~= nil)
    ui.hatchButton:SetShown(show and ready == true and not busy)
    ui.pen.rocking = egg and ready == true
    if not (show and kind) then return end
    local file = Art(kind.species .. "_egg")
    if ui.nest.file ~= file then
        ui.nest.file = file
        ui.nestEgg:SetTexture(file, "CLAMP", "CLAMP", "NEAREST")
    end
    ui.nest.egg = kind.name
    if not ui.pen.rocking then ui.nestEgg:SetTexCoord(0, 1, 0, 1) end
end

-- While there's a nest in the pen, the companion strolls only as far as
-- its side: `walk.keep` is the furthest right its picture's left edge goes.
function Pet.KeepOffNest()
    if not ui.walk then return end
    local nested = ui.nest and ui.nest:IsShown()
    ui.walk.keep = nested and math.floor(Pet.NEST.x + 22 - ui.walk.size * 0.8) or nil
end

-- Each frame the pen is drawn: the nest takes the light of the hour, as
-- what lies on the grass does, and an egg that's ready rocks.
function Pet.RockEgg(clock)
    if not (ui.nestBack and ui.nestBack:IsShown()) then
        if ui.nestRim then ui.nestRim.picture:Hide() end
        ui.pen.inBed = false
        return
    end
    local r, g, b = Pet.Light(ui.pen.shade or 0)
    for _, piece in ipairs({ ui.nestBack, ui.nestEgg, ui.nestFront, ui.nestRim.picture }) do piece:SetVertexColor(r, g, b) end
    -- In its bed, or hatching there: the rim is drawn over its feet.
    local bx, by = Pet.BedSpot(ui.walk and ui.walk.size or 64)
    ui.pen.inBed = ui.walk ~= nil and not ui.nestEgg:IsShown() and ui.walk.x == bx and ui.walk.y == by
    ui.nestRim.picture:SetShown(ui.pen.inBed or (ui.pen.hatching ~= nil and ui.pen.hatching.chick ~= nil))
    -- An egg that's ready rocks; one being doted on stirs a little too.
    local doted = ui.walk ~= nil and ui.walk.doting ~= nil
    if not ui.pen.rocking and not doted then
        if ui.nestEgg.swayed then
            ui.nestEgg.swayed = nil
            ui.nestEgg:SetTexCoord(0, 1, 0, 1)
        end
        return
    end
    ui.nestEgg.swayed = true
    -- It rocks about its foot, which stays in the nest: the picture is
    -- turned about a point just above its lower edge, where the egg's foot
    -- is, by giving each corner the place in the picture that lands there.
    --
    -- About to hatch, it rocks hard and fast.
    local stirring = ui.pen.hatching ~= nil and ui.pen.hatching.phase == "stir"
    local a = stirring and math.sin(clock * 16) * 0.2 or math.sin(clock * 5) * (ui.pen.rocking and 0.1 or 0.05)
    local cos, sin = math.cos(a), math.sin(a)
    local px, py = 0.492, 0.95
    local function At(x, y)
        local dx, dy = x - px, y - py
        return px + dx * cos + dy * sin, py - dx * sin + dy * cos
    end
    local ulx, uly = At(0, 0)
    local llx, lly = At(0, 1)
    local urx, ury = At(1, 0)
    local lrx, lry = At(1, 1)
    ui.nestEgg:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry)
end

-- Who looked after this companion's egg. One hatched before eggs were
-- tended has the last to settle in the paddock, if anyone has.
function Pet.Caretaker(s)
    if s.caretaker or s.unchosen then return s.caretaker end
    local settled = Settled()
    local last = settled[#settled]
    if last then s.caretaker = { name = last.name, species = last.species or "briarboar", form = last.form or 3 } end
    return s.caretaker
end

-- The one that looked after its egg, come by the pen for a few minutes
-- (Rules.Visit): it wanders about as it does in the paddock, with its name
-- over it. Not in the paddock, out with you, or while an egg is chosen.
function Pet.PaintVisitor(s)
    local visiting, began = false, false
    if not ui.window.out and not ui.window.yard and not ui.window.picking and not ui.looking and not s.unchosen
        and not Pet.farewell and not ui.pen.hatching and not s.unnamed and Pet.Caretaker(s) then
        visiting, began = Rules.Visit(s, Now())
    end
    Pet.visiting = visiting
    local v = ui.visitor
    if not visiting then
        if v then
            v.on = nil
            v.body:Hide()
        end
        return
    end
    if not v then
        v = { body = CreateFrame("Frame", nil, ui.pen) }
        ui.visitor = v
        v.body:SetSize(64, 64)
        v.sprite = v.body:CreateTexture(nil, "ARTWORK")
        v.sprite:SetPoint("CENTER")
        Compat.Crisp(v.sprite)
        v.snore = Style.Text(v.body, 11, "secondary", nil, true)
        v.snore:SetPoint("BOTTOMLEFT", v.body, "TOPRIGHT", -22, -14)
        v.snore:SetText("z z")
        v.tag = CreateFrame("Frame", nil, v.body)
        v.tag:SetPoint("BOTTOM", v.body, "TOP", 0, 0)
        v.tag.fill = v.tag:CreateTexture(nil, "BACKGROUND")
        v.tag.fill:SetAllPoints()
        v.tag.fill:SetColorTexture(Style.Color("titleBar"))
        v.tagText = Style.Text(v.tag, 10, "text", nil, false, true)
        v.tagText:SetPoint("CENTER")
    end
    local who = s.caretaker
    if began or v.who ~= who then
        v.who = who
        local sprites = Rules.Species(who).sprites
        v.sheet = SHEETS[sprites[who.form] or sprites[1]]
        v.size = SIZES[who.form] or SIZE
        v.body:SetSize(v.size, v.size)
        v.walk, v.nap, v.file = Pet.NewWalk(math.random, v.size), nil, nil
        -- It comes in from the left, the paddock's side, and walks over to
        -- the young one; after that it potters about the pen.
        if ui.walk then
            local w = v.walk
            w.tx = math.max(0, math.min(PEN_W - v.size, ui.walk.x - v.size * 0.7))
            w.ty = math.max(0, math.min(PEN_H - v.size, ui.walk.y + ui.walk.size - v.size))
            w.x, w.y, w.wait, w.facing = -v.size, w.ty, 0, "right"
        end
        local words = who.name .. ", visiting"
        v.tagText:SetText(words)
        local wide = v.tagText.GetStringWidth and v.tagText:GetStringWidth()
        v.tag:SetSize(((type(wide) == "number" and wide > 0) and wide or #words * 5.5) + 12, 15)
    end
    v.on = true
    v.body:Show()
    PaintRoamer(v)
    if began then ui.said = ("%s has come to visit %s."):format(who.name, s.name) end
end

-- Each frame, the visitor goes about as the paddock's companions do.
function Pet.RoamVisitor(dt)
    local v = ui.visitor
    if not (v and v.on) then return end
    Pet.Roam(v, dt, math.random)
    PaintRoamer(v)
end

-- After a companion settles: a card over the top of the page with what the
-- paddock keeps of it (who it was, how long you had it, how close you were),
-- that it will visit, and what the hatchling keeps. It stays until
-- Continue; the box to name the hatchling is under it.
function Pet.PaintFarewell()
    local it, f = Pet.farewell, ui.farewell
    if not it then
        if f then f:Hide() end
        return
    end
    if not f then
        f = CreateFrame("Frame", nil, ui.parts)
        ui.farewell = f
        f:SetPoint("TOPLEFT", 0, 0)
        f:SetSize(PEN_W, 292)
        f:SetFrameLevel((ui.parts:GetFrameLevel() or 1) + 20)
        f:EnableMouse(true)
        f.fill = f:CreateTexture(nil, "BACKGROUND")
        f.fill:SetAllPoints()
        f.fill:SetColorTexture(Style.Color("well"))
        f.edge = f:CreateTexture(nil, "BORDER")
        f.edge:SetColorTexture(Style.Color("gold"))
        f.edge:SetPoint("TOPLEFT")
        f.edge:SetPoint("TOPRIGHT")
        f.edge:SetHeight(2)
        f.head = Style.Text(f, 11, "gold", nil, true)
        f.head:SetPoint("TOP", 0, -16)
        f.picture = f:CreateTexture(nil, "ARTWORK")
        f.picture:SetSize(96, 96)
        f.picture:SetPoint("TOPLEFT", 20, -46)
        Compat.Crisp(f.picture)
        f.name = Style.Text(f, 17, "text", nil, true)
        f.name:SetPoint("TOPLEFT", 136, -50)
        f.days = Style.Text(f, 13, "secondary")
        f.days:SetPoint("TOPLEFT", 136, -78)
        f.hearts = {}
        for i = 1, #Rules.BONDS do
            local h = f:CreateTexture(nil, "ARTWORK")
            h:SetSize(14, 14)
            h:SetPoint("TOPLEFT", 136 + (i - 1) * 18, -104)
            h:SetTexture(Art("heart"), "CLAMP", "CLAMP", "NEAREST")
            Compat.Crisp(h)
            f.hearts[i] = h
        end
        f.bond = Style.Text(f, 13, "text", nil, true)
        f.bond:SetPoint("TOPLEFT", 136 + #Rules.BONDS * 18 + 8, -103)
        f.note = Style.Text(f, 12, "muted")
        f.note:SetPoint("TOPLEFT", 136, -130)
        f.note:SetWidth(PEN_W - 156)
        f.note:SetJustifyH("LEFT")
        f.keep = Style.Text(f, 12, "secondary")
        f.keep:SetPoint("TOPLEFT", 20, -200)
        f.keep:SetWidth(PEN_W - 40)
        f.keep:SetJustifyH("LEFT")
        f.go = Style.Button(f, "Continue", "primary", 110)
        f.go:SetPoint("BOTTOMRIGHT", -16, 14)
        f.go:SetScript("OnClick", function()
            Pet.farewell = nil
            Refresh()
        end)
    end
    local record = it.record
    f.head:SetText((record.name .. " has settled in the paddock"):upper())
    local sprites = Rules.Species(record).sprites
    f.picture:SetTexture(Art(sprites[record.form] or sprites[1]), "CLAMP", "CLAMP", "NEAREST")
    f.name:SetText(("%s the %s"):format(record.name, it.form))
    f.days:SetText(("%d day%s with you"):format(record.days or 1, (record.days or 1) == 1 and "" or "s"))
    local level = 1
    for i, step in ipairs(Rules.BONDS) do
        if step[2] == record.bond then level = i end
    end
    for i, h in ipairs(f.hearts) do
        if i <= level then h:SetVertexColor(1, 1, 1) else h:SetVertexColor(0.3, 0.3, 0.34) end
        h:SetAlpha(i <= level and 1 or 0.6)
    end
    f.bond:SetText(record.bond or "Wary")
    f.note:SetText("It looked after its egg until it hatched, and it will come by the pen to visit.")
    f.keep:SetText(("Your %s keeps the cupboard%s. Give it a name below, or keep the one it has."):format(it.young,
        it.kept and (", and starts %s, with a little of %s's bond"):format(it.kept, record.name) or ""))
    f:Show()
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
