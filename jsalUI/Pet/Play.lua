-- Play with the companion: stroking it, hide and seek in its pen, the
-- little things it finds while you quest (kept on a shelf in its window),
-- and noticing your mail and your whispers. All of it is part of Jsal's
-- Pals, with no switch of its own. What it's in the middle of is kept in
-- `ui.play`.
local _, ns = ...
local Style, Compat, Rules, Pet = ns.Style, ns.Compat, ns.PetRules, ns.Pet
local inner = Pet.inner
local ui = inner.ui
local Art, PEN_H, PEN_W, BUBBLES, SCENES = inner.Art, inner.PEN_H, inner.PEN_W, inner.BUBBLES, inner.SCENES
local Now, Sheet, Refresh, IsOpen = inner.Now, inner.Sheet, inner.Refresh, inner.IsOpen
local ZoneName = inner.ZoneName

-- `stroke`: how far the pointer goes one way before turning back, in
-- pixels, for that to be a stroke; `strokes`, how many make a proper fuss
-- (it's pleased, and the bond hears of it: Rules.Stroke); `rest`, seconds
-- the pointer can be off it or still before a fuss starts over. `hide`:
-- seconds it stays hidden before it gives up and pops out; `quiet`, seconds
-- since you last did anything with it before it will hide; `every`, how
-- long it waits between hides (seconds its pen is showing and it's free),
-- and `wished`, the same when hide and seek is today's wish. `flash`:
-- seconds a bubble about mail, a whisper or a find stays up; `gaps`, the
-- least seconds between two of each, so a busy inbox or chat doesn't keep
-- it at it.
Pet.PLAY = { stroke = 8, strokes = 3, rest = 1.2, hide = 30, quiet = 20, every = { 150, 330 }, wished = { 15, 35 },
    flash = 4, gaps = { mail = 60, whisper = 20 } }
Pet.Dice = math.random
-- What it does of its own accord (IDLE, ON_THE_GO, poorly), and its lean:
-- a stroke breaks off any of these, and it leans into your hand. (Mid-sit
-- or mid-yawn, it took the strokes and the hearts rose, but it didn't lean.)
Pet.FIDGETS = { lean = true, sit = true, idle = true, special = true, yawn = true, dig = true, poorly = true }
-- The hiding places, one for each scene in the order of SCENES, in
-- hides.png (tools/make_pet_hides.py): 48-pixel cells, each thing standing
-- on its cell's bottom edge, drawn twice its size in the pen's bottom left
-- corner (`at`), its foot a little under the edge. `size` is each thing's
-- own width and height in its cell.
Pet.HIDES = { at = { x = -8, y = -12 }, cell = 48, picture = { 512, 64 }, size = {
    meadow = { 34, 32 }, snow = { 35, 38 }, desert = { 38, 34 }, swamp = { 44, 45 }, coast = { 38, 39 },
    darkwood = { 45, 43 }, savanna = { 38, 32 }, volcanic = { 36, 31 }, jungle = { 48, 48 },
} }

-- Where the hiding place for a scene is in the pen (from its top left, as
-- the walk counts): the thing itself, not its cell; and its cell's number.
function Pet.HideSpot(scene)
    local H, cell = Pet.HIDES, 0
    for i, name in ipairs(SCENES) do
        if name == scene then cell = i - 1 end
    end
    local size = H.size[scene] or H.size.meadow
    local top = PEN_H - H.at.y - size[2] * 2
    return { x = H.at.x + math.floor((H.cell - size[1]) / 2) * 2, y = top, w = size[1] * 2, h = PEN_H - top, cell = cell }
end

-- A bubble over it about something it's telling you: mail, a whisper, a
-- find. It's up at once, whatever it's doing, for a few seconds.
function Pet.Flash(cell)
    ui.play.flash = { cell = cell, left = Pet.PLAY.flash }
end

-- The pointer going to and fro: `rub` keeps where it was and which way it
-- went. True when it has just turned back after going far enough one way.
function Pet.Rub(rub, x)
    local dx = x - (rub.x or x)
    rub.x = x
    if dx == 0 then return false end
    local way = dx > 0 and 1 or -1
    if way ~= rub.way then
        local stroke = rub.way ~= nil and (rub.run or 0) >= Pet.PLAY.stroke
        rub.way, rub.run = way, math.abs(dx)
        return stroke
    end
    rub.run = (rub.run or 0) + math.abs(dx)
    return false
end

-- A small heart rising from its head and fading, one a stroke.
function Pet.Heart()
    local play = ui.play
    play.hearts = play.hearts or {}
    local heart
    for _, one in ipairs(play.hearts) do
        if not one.age then heart = one end
    end
    if not heart then
        if #play.hearts >= 4 then return end
        heart = { picture = ui.body:CreateTexture(nil, "OVERLAY", nil, 3) }
        heart.picture:SetTexture(Art("heart"), "CLAMP", "CLAMP", "NEAREST")
        Compat.Crisp(heart.picture)
        play.hearts[#play.hearts + 1] = heart
    end
    -- The heart's own 16 dots, twice over on a large pal out with you.
    local side = 16 * math.max(1, math.floor(ui.walk.size / 96))
    heart.age, heart.dx = 0, (Pet.Dice(0, 2) - 1) * math.floor(ui.walk.size * 0.12)
    heart.picture:SetSize(side, side)
    heart.picture:SetAlpha(1)
    heart.picture:Show()
end

-- Stroked: the pointer moved to and fro over it, in its pen or out with
-- you. Each stroke it stops, faces your hand and leans into it, eyes
-- shut, and a heart rises; a few strokes and it's pleased: its own happy
-- dance, and the bond hears of it (Rules.Stroke, once a day). Called each
-- frame it's awake; true on a stroke.
function Pet.Stroking(sheet, dt)
    local play, s = ui.play, Pet.State()
    local x, y
    if not (ui.pen.held or ui.pen.toss or ui.walk.errand or play.hide or ui.pen.hatching or ui.yard or s.unchosen or s.asleep or ui.walk.nap)
        and ui.pen:IsMouseOver() then
        x, y = Compat.CursorAt(ui.pen)
    end
    local size = ui.walk.size
    local on = x ~= nil and x >= ui.walk.x + size * 0.15 and x <= ui.walk.x + size * 0.85 and y >= ui.walk.y + size * 0.2 and y <= ui.walk.y + size
    play.over = on or nil
    local rub = play.rub
    if not on then
        if rub then
            -- A stroke turns back on it: where the pointer went off it is forgotten.
            rub.x, rub.way, rub.run = nil, nil, nil
            rub.idle = rub.idle + dt
            if rub.idle >= Pet.PLAY.rest then play.rub = nil end
        end
        return false
    end
    if not rub then
        rub = { idle = 0, strokes = 0 }
        play.rub = rub
    end
    local before = rub.x
    if not Pet.Rub(rub, x) then
        -- Resting on it is not stroking it: a while of that and the fuss starts over.
        rub.idle = before == x and rub.idle + dt or 0
        if rub.idle >= Pet.PLAY.rest then rub.strokes, rub.facing = 0, nil end
        return false
    end
    rub.idle, rub.strokes = 0, rub.strokes + 1
    play.touched = Pet.tick or 0
    ui.walk.chase, ui.walk.running, ui.walk.whim = nil, nil, nil
    ui.walk.tx, ui.walk.ty, ui.walk.wait = ui.walk.x, ui.walk.y, math.max(ui.walk.wait, 1.5)
    -- It turns to your hand once, on the first stroke, and stays that way:
    -- turning with every pass of the pointer had it flip to and fro.
    rub.facing = rub.facing or (x < ui.walk.x + size / 2 and "left" or "right")
    ui.walk.facing = rub.facing
    -- Something it was doing of its own accord, it leaves off for your hand.
    if not ui.walk.act or Pet.FIDGETS[ui.walk.act.name] then Pet.Play(ui.walk, sheet, "lean") end
    Pet.Heart()
    if rub.strokes == Pet.PLAY.strokes then
        local _, what = Rules.Stroke(s, Now())
        if Pet.Play(ui.walk, sheet, "cheer") or Pet.Play(ui.walk, sheet, "jump") then Pet.Sound("pat") end
        ui.said = what
        Refresh()
    end
    return true
end

-- Whether it's free to hide: in its pen (not out with you, nor the
-- paddock), awake and well, not eating, bathing or playing, not hatching or
-- ready to grow, and not just now with you doing something with it.
function Pet.CanHide(s)
    if not ui.walk or ui.window.out or ui.yard or ui.looking or ui.pen.hatching or ui.pen.busy or not Sheet() then return false end
    if not Rules.CanHide(s) or s.grewFrom or ui.walk.nap then return false end
    if ui.pen.held or ui.pen.toss or ui.walk.errand or ui.walk.chase or ui.walk.act or ui.walk.doting or ui.play.rub then return false end
    return (Pet.tick or 0) - (ui.play.touched or -1e9) >= Pet.PLAY.quiet
end

-- How long until it next hides: sooner when hide and seek is today's wish.
function Pet.NextHide(s)
    local wish = Rules.Wish(s, Now())
    local range = (wish.kind == "seek" and not wish.done) and Pet.PLAY.wished or Pet.PLAY.every
    ui.play.nextHide = Pet.Dice(range[1], range[2])
end

-- Off it goes, at a run, to crouch behind the hiding place: the top of its
-- head over it, its tail out at the side.
function Pet.Hide()
    local spot = Pet.HideSpot(Pet.Scene(Pet.where))
    local size = ui.walk.size
    local x = math.floor(spot.x + spot.w / 2 - size / 2 + size * 0.1)
    local y = math.floor(spot.y - size * 0.4)
    ui.play.hide = { phase = "going", x = x, y = y, walk = ui.walk }
    ui.walk.tx, ui.walk.ty, ui.walk.wait, ui.walk.clock, ui.walk.running = x, y, 0, 0, true
    ui.walk.facing = x > ui.walk.x and "right" or "left"
    ui.walk.whim = nil
end

-- Hide and seek, moved on by `dt`: on its way, hidden, or waiting for the
-- next time. Anything else it's called away to (care, a click, the pen
-- closed or folded out) ends a hide quietly.
function Pet.HideStep(dt)
    local play = ui.play
    local hide, s = play.hide, Pet.State()
    if hide then
        if hide.walk ~= ui.walk or ui.window.out or ui.yard or s.asleep or s.sick then
            play.hide = nil
            return
        end
        local act = ui.walk.act
        if hide.phase == "going" then
            if ui.walk.errand or ui.walk.chase or ui.pen.held or ui.pen.toss or act then
                play.hide = nil
            elseif ui.walk.wait > 0 then
                if math.abs(ui.walk.x - hide.x) >= 1 or math.abs(ui.walk.y - hide.y) >= 1 then
                    play.hide = nil
                    return
                end
                hide.phase, hide.left = "hidden", Pet.PLAY.hide
                ui.walk.facing, ui.walk.wait, ui.walk.running = "left", Pet.PLAY.hide + 1, nil
                if Pet.Play(ui.walk, Sheet(), "crouch") then ui.walk.act.length = Pet.PLAY.hide + 1 end
                ui.said = nil
                Refresh()
            end
            return
        end
        if not (act and act.name == "crouch") then
            play.hide = nil
            return Refresh()
        end
        hide.left = hide.left - dt
        if hide.left > 0 then return end
        -- Nobody found it: out it pops by itself.
        play.hide, ui.walk.act = nil, nil
        Pet.Play(ui.walk, Sheet(), "jump")
        ui.walk.wait = 1.5
        ui.said = ("%s pops out by itself. It was there all along!"):format(s.name)
        Pet.NextHide(s)
        return Refresh()
    end
    if not Pet.CanHide(s) then return end
    if not play.nextHide then Pet.NextHide(s) end
    play.nextHide = play.nextHide - dt
    if play.nextHide > 0 then return end
    play.nextHide = nil
    Pet.Hide()
end

-- A click while it hides: on it, or on what it's behind, and it's found.
-- (`onBody`: it was the creature that was clicked.) True when the click was
-- part of the game, so nothing else takes it.
function Pet.Seek(x, y, onBody)
    local hide = ui.play.hide
    if not (hide and ui.walk) then return false end
    if hide.phase ~= "hidden" then
        -- On its way to hide, and you've something else in mind: never mind.
        ui.play.hide = nil
        return false
    end
    local s = Pet.State()
    local spot = Pet.HideSpot(Pet.Scene(Pet.where))
    local there = x ~= nil and x >= spot.x and x <= spot.x + spot.w and y >= spot.y
    if not (onBody or there) then
        ui.said = ("Not there. Where could %s be?"):format(s.name)
        Refresh()
        return true
    end
    ui.play.hide, ui.walk.act = nil, nil
    Rules.Seek(s, Now())
    if not Pet.Play(ui.walk, Sheet(), "cheer") then Pet.Play(ui.walk, Sheet(), "jump") end
    ui.walk.wait = math.max(ui.walk.wait, 2)
    Pet.Sound("pat")
    ui.said = ("Found you! %s pops out, pleased as anything."):format(s.name)
    Pet.NextHide(s)
    Refresh()
    return true
end

-- Every frame, after it's drawn: news bubbles and hearts fade, and hide and
-- seek goes on.
function Pet.PlayStep(dt)
    local play = ui.play
    local flash = play.flash
    if flash then
        flash.left = flash.left - dt
        if flash.left <= 0 then play.flash = nil end
    end
    for _, heart in ipairs(play.hearts or {}) do
        if heart.age then
            heart.age = heart.age + dt
            if heart.age >= 1 or not ui.walk then
                heart.age = nil
                heart.picture:Hide()
            else
                heart.picture:ClearAllPoints()
                heart.picture:SetPoint("BOTTOM", ui.body, "TOP", heart.dx, math.floor(ui.walk.size * (heart.age * 0.35 - 0.3)))
                heart.picture:SetAlpha(math.max(0, 1 - heart.age * heart.age))
            end
        end
    end
    if ui.walk then Pet.HideStep(dt) end
end

-- Mail has come, or someone has whispered you, while it's on your screen
-- or in its open pen: it perks up. Mail, and it fetches you a letter (held
-- up, with a letter in a bubble); a whisper, and it looks round at your
-- chat, with "..." over it. Not in a fight, not asleep, not while it's busy
-- with you, and not more than once in a while (Pet.PLAY.gaps). True when it
-- did.
function Pet.Notice(kind)
    local gap = Pet.PLAY.gaps[kind]
    if not (gap and Pet.running and IsOpen() and ui.walk) or ui.yard or Compat.InCombat() then return false end
    local s, play = Pet.State(), ui.play
    if s.unchosen or s.asleep or ui.walk.nap or ui.pen.hatching or ui.pen.held or ui.pen.toss or ui.walk.errand or play.hide then return false end
    local now = Now()
    if now - (play.notice[kind] or -1e9) < gap then return false end
    play.notice[kind] = now
    ui.walk.chase = nil
    if kind == "mail" then
        if Pet.Play(ui.walk, Sheet(), "cheer") or Pet.Play(ui.walk, Sheet(), "jump") then ui.walk.act.prop, ui.walk.act.carry = "letter", true end
        Pet.Flash(BUBBLES.letter)
        Pet.Sound("sparkle")
    else
        ui.walk.facing = Pet.ChatSide() or ui.walk.facing
        ui.walk.tx, ui.walk.ty, ui.walk.wait, ui.walk.running = ui.walk.x, ui.walk.y, math.max(ui.walk.wait, 3), nil
        Pet.Flash(BUBBLES.whisper)
    end
    return true
end

-- Which way your chat is from it, "left" or "right"; nil when the game
-- can't say where either is.
function Pet.ChatSide()
    local chat = DEFAULT_CHAT_FRAME
    local cx = chat and chat.GetCenter and chat:GetCenter()
    local bx = ui.body and ui.body:GetCenter()
    if not (cx and bx) then return nil end
    return cx < bx and "left" or "right"
end

-- A quest handed in while it's with you: now and then it has found a
-- little something in this zone, and brings it to you (Rules.Gift says
-- what, and keeps it on the shelf). `roll` is the luck of it, 0 up to 1;
-- left out, it's rolled here. The key of what it found, or nil.
function Pet.Gift(roll)
    if not (Pet.running and IsOpen() and ui.walk) then return nil end
    local s = Pet.State()
    if s.unchosen then return nil end
    local zone = ZoneName()
    local shelf = Rules.Shelf(ns.db.petShelf)
    ns.db.petShelf = shelf
    local key = Rules.Gift(shelf, zone, Now(), roll or Pet.Luck())
    if not key then return nil end
    local name, cell = Rules.Trinket(key)
    Pet.Flash(BUBBLES.gift + cell)
    ns.Print(("%s found %s in %s and brings it to you. It's on the shelf on its page."):format(s.name, name, zone))
    local J = ns.Journal
    if J and J.running then J.Note("pet", ("%s found %s in %s"):format(s.name, name, zone)) end
    ui.said = ("%s brings you %s!"):format(s.name, name)
    Refresh()
    return key
end

-- A tossed treat sparkles while it can be caught: `t`, how far through its
-- toss it is (nil: no treat in the air). The sparkle is the last three
-- frames of a bath's (effects.png), round and round, over the treat.
Pet.GLINT = { cells = { 29, 30, 31 }, time = 0.1, side = 64 }
function Pet.Glint(t)
    local glint = ui.play.glint
    if not glint then return end
    local _, good = Pet.Tossed(t or 0)
    if not (t and good) then return glint:Hide() end
    local G = Pet.GLINT
    local cell = G.cells[1 + math.floor(t * Pet.TOSS / G.time) % #G.cells]
    local col, row = cell % 8, math.floor(cell / 8)
    glint:SetTexCoord(col / 8, (col + 1) / 8, row / 8, (row + 1) / 8)
    glint:ClearAllPoints()
    glint:SetPoint("CENTER", ui.prop, "CENTER")
    glint:Show()
end

-- The hiding place in the pen, and the shelf under the care buttons.
Pet.SHELF = { y = 306, slots = 13, side = 32 }
function Pet.BuildPlay()
    -- The sparkle on a treat that can be caught, over the creature (Pet.Glint).
    local over = CreateFrame("Frame", nil, ui.pen)
    over:SetAllPoints()
    over:SetFrameLevel(41)
    ui.play.glint = over:CreateTexture(nil, "OVERLAY")
    ui.play.glint:SetSize(Pet.GLINT.side, Pet.GLINT.side)
    ui.play.glint:SetTexture(Art("effects"), "CLAMP", "CLAMP", "NEAREST")
    Compat.Crisp(ui.play.glint)
    ui.play.glint:Hide()
    -- The hiding place: over the creature, at the pen's front edge, so that
    -- whatever is behind it is behind it.
    local spot = CreateFrame("Frame", nil, ui.pen)
    spot:SetSize(Pet.HIDES.cell * 2, Pet.HIDES.cell * 2)
    spot:SetPoint("BOTTOMLEFT", ui.pen, "BOTTOMLEFT", Pet.HIDES.at.x, Pet.HIDES.at.y)
    spot:SetFrameLevel((ui.body:GetFrameLevel() or 1) + 2)
    spot.picture = spot:CreateTexture(nil, "ARTWORK")
    spot.picture:SetAllPoints()
    spot.picture:SetTexture(Art("hides"), "CLAMP", "CLAMP", "NEAREST")
    Compat.Crisp(spot.picture)
    spot:Hide()
    ui.hideSpot = spot
    -- The shelf: a line saying how many, then this zone's three things (the
    -- ones not found yet in shadow), a gap, and others found elsewhere,
    -- standing on a plank.
    local S, shelf = Pet.SHELF, { slots = {} }
    ui.shelf = shelf
    local head = Style.Text(ui.parts, 11, "muted", nil, true)
    head:SetPoint("TOPLEFT", 0, -S.y)
    head:SetText("SHELF")
    shelf.line = Style.Text(ui.parts, 12, "secondary")
    shelf.line:SetPoint("TOPLEFT", 50, -(S.y - 1))
    shelf.line:SetWidth(PEN_W - 50)
    shelf.line:SetWordWrap(false)
    for i, part in ipairs({ { 0.42, 0.29, 0.17, 4 }, { 0.23, 0.16, 0.09, 2 } }) do
        local plank = ui.parts:CreateTexture(nil, "ARTWORK")
        plank:SetColorTexture(part[1], part[2], part[3])
        plank:SetPoint("TOPLEFT", 0, -(S.y + 18 + S.side + (i - 1) * 4))
        plank:SetSize(PEN_W, part[4])
    end
    local here = Rules.SHELF.here
    for i = 1, S.slots do
        local slot = CreateFrame("Button", nil, ui.parts)
        slot:SetSize(S.side, S.side)
        slot:SetPoint("TOPLEFT", (i - 1) * (S.side + 1) + (i > here and 10 or 0), -(S.y + 18))
        slot.picture = slot:CreateTexture(nil, "ARTWORK")
        slot.picture:SetAllPoints()
        slot.picture:SetTexture(Art("trinkets"), "CLAMP", "CLAMP", "NEAREST")
        Compat.Crisp(slot.picture)
        slot:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(self.name or "")
            GameTooltip:AddLine(self.where or "", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        slot:SetScript("OnLeave", function() GameTooltip:Hide() end)
        slot:Hide()
        shelf.slots[i] = slot
    end
    local gap = ui.parts:CreateTexture(nil, "ARTWORK")
    gap:SetColorTexture(Style.Color("line"))
    gap:SetPoint("TOPLEFT", here * (S.side + 1) + 4, -(S.y + 20))
    gap:SetSize(1, S.side - 4)
end

-- One place on the shelf: the thing, or its shadow if it isn't found yet.
function Pet.DressSlot(slot, key, where)
    local name, cell = Rules.Trinket(key)
    slot.picture:SetTexCoord(cell * 16 / 256, (cell + 1) * 16 / 256, 0, 1)
    if where then
        slot.picture:SetVertexColor(1, 1, 1)
        slot.name, slot.where = name:gsub("^%l", string.upper), "Found in " .. where
    else
        slot.picture:SetVertexColor(0.12, 0.12, 0.14)
        slot.name, slot.where = "Something to find here", "It turns things up as you hand in quests with it along."
    end
    slot:Show()
end

function Pet.PaintShelf()
    local shelf = ui.shelf
    if not shelf then return end
    local kept = Rules.Shelf(ns.db.petShelf)
    ns.db.petShelf = kept
    local zone = Pet.where
    local all = Rules.ShelfCount(kept)
    local slots, here = shelf.slots, Rules.SHELF.here
    local got = {}
    for _, key in ipairs(zone and kept.found[zone] or {}) do got[key] = true end
    local found = 0
    for i = 1, here do
        local key = zone and Rules.ZoneTrinkets(zone)[i]
        if key then
            Pet.DressSlot(slots[i], key, got[key] and zone or nil)
            if got[key] then found = found + 1 end
        else
            slots[i]:Hide()
        end
    end
    -- Then what it found elsewhere, by zone.
    local others = {}
    for where, keys in pairs(kept.found) do
        if where ~= zone then
            for _, key in ipairs(keys) do others[#others + 1] = { where, key } end
        end
    end
    table.sort(others, function(a, b) return a[1] < b[1] or (a[1] == b[1] and a[2] < b[2]) end)
    for i = here + 1, #slots do
        local other = others[i - here]
        if other then Pet.DressSlot(slots[i], other[2], other[1]) else slots[i]:Hide() end
    end
    shelf.line:SetText(zone and ("%s  ·  %d of %d found here  ·  %d in all"):format(zone, found, here, all)
        or ("%d found in all"):format(all))
end

-- Everything of play that's drawn on its page: the hiding place (in its
-- pen only), the headline while it hides, and the shelf.
function Pet.PaintPlay(s)
    local spot = ui.hideSpot
    if spot then
        local show = not ui.window.out and not ui.yard and not ui.window.picking and not ui.looking
        spot:SetShown(show)
        local scene = Pet.Scene(Pet.where)
        -- Where it's not to stop when it strolls about (Spot).
        if ui.walk then
            local hs = show and Pet.HideSpot(scene)
            ui.walk.corner = hs and { x = hs.x + hs.w, y = hs.y } or nil
        end
        if show and spot.scene ~= scene then
            spot.scene = scene
            local H, cell = Pet.HIDES, Pet.HideSpot(scene).cell
            spot.picture:SetTexCoord(cell * H.cell / H.picture[1], (cell + 1) * H.cell / H.picture[1], 0, H.cell / H.picture[2])
        end
    end
    local hide = ui.play.hide
    if hide and hide.phase == "hidden" and ui.headline and not ui.window.picking then
        ui.headline:SetText(("Where's %s?"):format(s.name))
        ui.sub:SetText("Hiding somewhere in the pen. Click where it is.")
    end
    Pet.PaintShelf()
end
