-- The companion's window: how it's laid out (whole, the pen alone, or out
-- with you), every part of it built the first time it opens, and /jsal pet
-- that opens and closes it.
local _, ns = ...
local Style, Compat, Rules, Pet = ns.Style, ns.Compat, ns.PetRules, ns.Pet
local inner = Pet.inner
local ui = inner.ui
local Art, PAD, PEN_H, PEN_W, SIZE = inner.Art, inner.PAD, inner.PEN_H, inner.PEN_W, inner.SIZE
local EGG_W, YARD_MAX, BOOK_ROWS, BOOK_PAGE = inner.EGG_W, inner.YARD_MAX, inner.BOOK_ROWS, inner.BOOK_PAGE
local WIN_H, WIN_W, HEAP_W, DUSK = inner.WIN_H, inner.WIN_W, inner.HEAP_W, inner.DUSK
local STRIP_TOP, FRAME, NEED_NAME, SHEETS = inner.STRIP_TOP, inner.FRAME, inner.NEED_NAME, inner.SHEETS
local NameBox, TakeName, HEAP_AT, Sheet = inner.NameBox, inner.TakeName, inner.HEAP_AT, inner.Sheet
local Sky, PaintWalk, PaintRoamer, Refresh = inner.Sky, inner.PaintWalk, inner.PaintRoamer, inner.Refresh
local Do, Tend, Dropped, Place, Escapes = inner.Do, inner.Tend, inner.Dropped, inner.Place, inner.Escapes
local Asleep = inner.Asleep
local PaintMute = inner.PaintMute

-- The whole window, or just the pen with its creature: the small button in
-- the pen's corner swaps between them, and which you chose is kept.
function Pet.Layout()
    -- Choosing an egg, it's the whole pen and one line under it, never just the pen.
    local picking = ui.window.picking == true
    -- Out with you: not while there's an egg to choose or a hatchling to name.
    local out = ns.db.petOut == true and not picking and not Pet.State().unnamed
    local small = ns.db.petCompact == true and not picking and not out
    local moved = ui.window.out ~= out
    ui.window.out = out
    ui.window.bar:SetShown(not small and not out)
    ui.parts:SetShown(not small and not out and not picking and not ui.window.yard)
    ui.yardParts:SetShown(ui.window.yard == true and not small and not out and not picking)
    ui.bookToggle:SetShown(ui.window.yard == true and not small and not out and not picking)
    ui.pickLine:SetShown(picking)
    -- Out with you, its buttons are only there while the pointer is over it.
    ui.pen.over = nil
    ui.fold:SetShown(not picking and not out)
    ui.mute:SetShown(not picking and not out)
    ui.outButton:SetShown(not picking and not out and not ui.window.yard)
    -- No weather out with you, or while an egg is chosen.
    if ui.weather and (picking or out) then ui.weather:Hide() end
    -- Ready to grow: the button for it, until it's pressed.
    ui.growButton:SetShown(Pet.State().grewFrom ~= nil and not picking and not out and not ui.window.yard and not ui.looking
        and not (ui.walk and ui.walk.act and ui.walk.act.name == "grow"))
    ui.sizeButton:Hide()
    ui.sizeButton:SetLabel(("%dx"):format(Pet.OutScale()))
    PaintMute()
    -- Nothing of a window is left then: no fill, no edges, no meadow, and
    -- nothing that would catch a click meant for the game but the creature.
    for _, piece in ipairs(ui.chrome) do piece:SetShown(not out) end
    ui.ground:SetShown(out)
    ui.pen:SetClipsChildren(not out)
    ui.pen:EnableMouse(not out)
    ui.window:EnableMouse(not out)
    ui.window:SetFrameStrata(out and "LOW" or "HIGH")
    ui.pen:ClearAllPoints()
    -- As large as suits this screen, with a strip and a shadow to match.
    local times = Pet.OutScale()
    ui.outSize, ui.stripW, ui.stripH = 64 * times, 130 + 130 * times, STRIP_TOP + 64 * times
    ui.ground:SetSize(40 * times, 10 * times)
    ui.pen:SetSize(out and ui.stripW or PEN_W, out and ui.stripH or PEN_H)
    if out then
        ui.pen:SetPoint("TOPLEFT", 0, 0)
        ui.window:SetSize(ui.stripW, ui.stripH)
    elseif small then
        ui.pen:SetPoint("TOPLEFT", 1, -1)
        ui.window:SetSize(PEN_W + 2, PEN_H + 2)
    elseif picking then
        ui.pen:SetPoint("TOPLEFT", PAD, -(32 + PAD))
        ui.window:SetSize(WIN_W, 32 + PAD + PEN_H + 50)
    else
        ui.pen:SetPoint("TOPLEFT", PAD, -(32 + PAD))
        ui.window:SetSize(WIN_W, WIN_H)
    end
    -- Droppings: on the grass of the pen, or in a row along the strip.
    for i, heap in ipairs(ui.heaps) do
        heap:ClearAllPoints()
        if out then
            heap:SetPoint("BOTTOMLEFT", 8 + (i - 1) * 62, 0)
        else
            heap:SetPoint("TOPLEFT", HEAP_AT[i], -(PEN_H - 40 - (i % 2) * 26))
        end
    end
    if moved then
        Place()
        if ui.window.SetAlpha then ui.window:SetAlpha(1) end
        ui.pen.quiet = nil
    end
    ui.fold:SetLabel((small or out) and "+" or "-")
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
    if ui.window then
        Pet.Layout()
        Refresh()
    end
end

-- Its window is built in four parts, each a function of its own, and not
-- for tidiness: the game's Lua lets one function use at most 60 variables
-- from outside itself, and one function building everything used 74, so the
-- game refused the whole file. Keep each part well under.
local function BuildPen()
    ui.window = Style.Panel("jsalUIPetWindow", WIN_W, WIN_H, "Jsal's Pals")
    ui.title = ui.window.title
    ui.window.bar:SetScript("OnDragStop", Dropped)
    -- Shown or not is kept too, so the pen you left out is there next time.
    -- (Hidden along with the whole interface, it still counts as shown.)
    ui.window:SetScript("OnShow", function() ns.db.petShown = true end)
    ui.window:SetScript("OnHide", function() ns.db.petShown = ui.window:IsShown() and true or nil end)

    ui.pen = CreateFrame("Frame", nil, ui.window)
    ui.pen:SetSize(PEN_W, PEN_H)
    ui.pen:SetPoint("TOPLEFT", PAD, -(32 + PAD))
    ui.pen:SetClipsChildren(true)
    ui.pen.edges = Style.Border(ui.pen, "cardLine")
    -- The meadow: pixel art at half the pen's size, so its pixels match the
    -- creature's. It sits in the top left 170 by 100 of a 256 by 128 picture.
    local scene = ui.pen:CreateTexture(nil, "BACKGROUND")
    ui.pen.scene = scene
    scene:SetAllPoints()
    scene:SetTexture(Art("meadow"), "CLAMP", "CLAMP", "NEAREST")
    scene:SetTexCoord(0, 220 / 256, 0, 100 / 128)
    Compat.Crisp(scene)
    local night = ui.pen:CreateTexture(nil, "BACKGROUND", nil, 2)
    ui.pen.night = night
    night:SetAllPoints()
    night:SetTexture(Art("meadow_night"), "CLAMP", "CLAMP", "NEAREST")
    night:SetTexCoord(0, 220 / 256, 0, 100 / 128)
    night:SetAlpha(0)
    Compat.Crisp(night)
    -- Between the two, the meadow at sunset: dusk and dawn pass through it.
    local dusk = ui.pen:CreateTexture(nil, "BACKGROUND", nil, 1)
    ui.pen.dusk = dusk
    dusk:SetAllPoints()
    dusk:SetTexture(Art("meadow_dusk"), "CLAMP", "CLAMP", "NEAREST")
    dusk:SetTexCoord(0, 220 / 256, 0, 100 / 128)
    dusk:SetAlpha(0)
    Compat.Crisp(dusk)
    -- The pen can be dragged too: with only the pen showing, it's all there is to hold.
    ui.pen:EnableMouse(true)
    ui.pen:RegisterForDrag("LeftButton")
    ui.pen:SetScript("OnDragStart", function()
        ui.pen.dragged = true
        ui.window:StartMoving()
    end)
    ui.pen:SetScript("OnDragStop", Dropped)
    -- A click on the grass (not the end of a drag) is for the creature.
    ui.pen:SetScript("OnMouseUp", ns.Safe(Pet, function(_, button)
        if ui.pen.dragged then
            ui.pen.dragged = nil
        elseif button == nil or button == "LeftButton" then
            Pet.Clicked()
        end
    end))

    -- Droppings: click one to scoop it.
    for i, x in ipairs(HEAP_AT) do
        local heap = CreateFrame("Button", nil, ui.pen)
        heap:SetSize(HEAP_W, HEAP_W)
        local pile = heap:CreateTexture(nil, "ARTWORK")
        pile:SetAllPoints()
        pile:SetTexture(Art("dropping"), "CLAMP", "CLAMP", "NEAREST")
        Compat.Crisp(pile)
        heap.pile = pile
        heap:SetScript("OnClick", function() Do(Rules.Scoop, nil, nil, nil, "scoop") end)
        heap:Hide()
        ui.heaps[i] = heap
    end

    -- The creature: click it for a pat.
    ui.body = CreateFrame("Button", nil, ui.pen)
    ui.body:SetSize(SIZE, SIZE)
    -- A few levels over the pen, so a visitor behind it has a level of its own under it (Pet.Layer).
    ui.body:SetFrameLevel((ui.pen:GetFrameLevel() or 1) + 3)
    ui.sprite = ui.body:CreateTexture(nil, "ARTWORK")
    ui.sprite:SetAllPoints()
    Compat.Crisp(ui.sprite)
    ui.body:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    ui.body:SetScript("OnClick", function(_, button) Pet.Petted(button) end)
    -- Out with you, the creature is all there is to hold: drag it to move it.
    ui.body:RegisterForDrag("LeftButton")
    ui.body:SetScript("OnDragStart", function() if ui.window.out then ui.window:StartMoving() end end)
    ui.body:SetScript("OnDragStop", function() if ui.window.out then Dropped() end end)
    -- And it has a small shadow under its feet, so it stands on something.
    ui.ground = ui.pen:CreateTexture(nil, "BACKGROUND")
    ui.ground:SetSize(40, 10)
    ui.ground:SetPoint("BOTTOM", ui.body, "BOTTOM", 0, 0)
    ui.ground:SetTexture(Art("shadow"), "CLAMP", "CLAMP", "NEAREST")
    ui.ground:SetTexCoord(0, 40 / 64, 0, 10 / 16)     -- the oval is in the corner of a 64 by 16 picture
    Compat.Crisp(ui.ground)
    ui.ground:Hide()
    ui.chrome = { ui.pen.scene, ui.pen.dusk, ui.pen.night }
    ui.chrome[#ui.chrome + 1] = ui.window.fill
    for _, pieces in ipairs({ ui.window.edges or {}, ui.window.shadow or {}, ui.pen.edges or {} }) do
        for _, piece in ipairs(pieces) do ui.chrome[#ui.chrome + 1] = piece end
    end
    ui.prop = ui.pen:CreateTexture(nil, "ARTWORK")
    ui.prop:SetSize(HEAP_W, HEAP_W)
    Compat.Crisp(ui.prop)
    ui.prop:Hide()
    -- And what's in your hand, on a layer of its own above the creature.
    local above = CreateFrame("Frame", nil, ui.pen)
    above:SetAllPoints()
    above:SetFrameLevel(40)
    ui.pen.hand = above:CreateTexture(nil, "OVERLAY")
    ui.pen.hand:SetSize(HEAP_W, HEAP_W)
    Compat.Crisp(ui.pen.hand)
    ui.pen.hand:Hide()
    ui.bubble = ui.body:CreateTexture(nil, "OVERLAY", nil, 2)
    ui.bubble:SetSize(32, 32)
    ui.bubble:SetTexture(Art("bubble"), "CLAMP", "CLAMP", "NEAREST")
    Compat.Crisp(ui.bubble)
    ui.bubble:Hide()
    ui.effect = ui.body:CreateTexture(nil, "OVERLAY")
    ui.effect:SetAllPoints()
    Compat.Crisp(ui.effect)
    ui.effect:Hide()
    ui.snore = Style.Text(ui.body, 15, "secondary", nil, true)
    ui.snore:SetPoint("BOTTOMLEFT", ui.body, "TOPRIGHT", -26, -20)
    ui.snore:SetText("z z z")

    -- Only while the page is showing: a hidden frame gets no updates.
    local since, pace, bob = 0, 0, 0
    ui.pen:SetScript("OnUpdate", ns.Safe(Pet, function(_, elapsed)
        -- However fast the game draws, it's only looked at thirty times a second.
        pace = pace + elapsed
        if pace < FRAME then return end
        elapsed, pace = pace, 0
        bob = bob + elapsed
        Pet.BobCare(bob)
        if ui.window.out then
            ui.pen.held, ui.pen.toss = nil, nil
            -- Out with you, it keeps out of a fight: faint and still until it's over.
            local quiet = Compat.InCombat() and true or false
            if quiet ~= ui.pen.quiet then
                local won = ui.pen.quiet == true and not Compat.Dead()
                ui.pen.quiet = quiet
                ui.window:SetAlpha(quiet and 0.25 or 1)
                -- A fight you came through: one time in three, it's glad of it.
                if won and math.random(1, 3) == 1 then Pet.React("won") end
            end
            if quiet then return end
            -- And its two buttons are there only while the pointer is over it.
            local over = ui.pen:IsMouseOver() and true or false
            if over ~= ui.pen.over then
                ui.pen.over = over
                ui.fold:SetShown(over)
                ui.mute:SetShown(over)
                ui.sizeButton:SetShown(over)
            end
            -- Standing about, it turns to look at the pointer when that comes near;
            -- not while it's being stroked, when it keeps facing your hand, nor asleep.
            if over and ui.walk and ui.walk.wait > 0 and not ui.walk.act and not Asleep()
                and not (ui.play.rub and ui.play.rub.facing) then
                local x = Compat.Cursor(ui.pen)
                if x then ui.walk.facing = x < ui.walk.x + ui.walk.size / 2 and "left" or "right" end
            end
        end
        Pet.tick = (Pet.tick or 0) + elapsed
        Pet.SlideWeather(Pet.tick)
        Pet.RockEgg(Pet.tick)
        -- The paddock: its settled companions go about their day, and nothing else moves.
        if ui.yard then
            local dt = math.min(elapsed, 0.1)
            for _, r in ipairs(ui.roamers) do
                if r.record then
                    Pet.Roam(r, dt, math.random)
                    PaintRoamer(r)
                end
            end
            Pet.Layer()
            return
        end
        -- Dusk and dawn: the day goes, or comes back, a little each frame.
        if ui.pen.shade and ui.pen.shade ~= ui.pen.dark then
            local by = math.min(elapsed, 0.1) / DUSK
            ui.pen.shade = ui.pen.dark > ui.pen.shade and math.min(ui.pen.dark, ui.pen.shade + by) or math.max(ui.pen.dark, ui.pen.shade - by)
            Sky()
        end
        if not ui.walk then return end
        -- A long hitch (a loading screen) shouldn't fling it across the pen.
        local dt = math.min(elapsed, 0.1)
        if Pet.State().asleep then
            -- Asleep, it stays put, eyes shut, once it has settled down: in
            -- its nest, if it has one, which it goes to first.
            ui.walk.errand, ui.pen.held, ui.pen.toss = nil, nil, nil
            if not Pet.ToBed(dt) then
                if ui.walk.act then Pet.Step(ui.walk, dt, math.random) end
                if not ui.walk.act then ui.walk.frame = "sleep" end
                ui.walk.wait = math.max(ui.walk.wait, 0.5)
            end
        else
            local sheet = Sheet()
            -- Out with you, it goes by how you're getting about.
            local going = ui.window.out and sheet and Pet.How(elapsed) or nil
            if going and Pet.Pace(ui.walk, sheet, going, dt) then Pet.React("hello") end
            if ui.walk.nap then
                -- Napping while you're away: as when it's asleep, till you're back.
                if not Pet.ToBed(dt) then
                    if ui.walk.act then Pet.Step(ui.walk, dt, math.random) end
                    if not ui.walk.act then ui.walk.frame = "sleep" end
                    ui.walk.wait = math.max(ui.walk.wait, 0.5)
                end
            else
                Pet.Stroking(sheet, dt)
                if not ui.window.out then Tend(sheet, dt) end
                local walking = ui.walk.wait <= 0
                Pet.Step(ui.walk, dt, math.random)
                -- By its nest, it dotes on the egg, and hearts rise from it.
                if Pet.Dote(ui.walk, sheet, dt) == "hearts" and ui.nest then Pet.Hearts(ui.nest) end
                if Pet.Growing(ui.walk, Pet.State()) then Refresh() end
                -- Just arrived somewhere, and not hurrying after you: now and then it does something.
                local moving = going and going.moving
                if not moving then ui.walk.whim = nil end
                if sheet and not ui.walk.act and not ui.walk.errand and not ui.walk.chase and not ui.play.hide then
                    -- At rest, as it arrives somewhere; on the move with you, wherever it
                    -- is on its strip when the whim takes it. It stops, does it, and goes on.
                    local due
                    if moving then
                        due = Pet.Whim(ui.walk, dt, math.random)
                    else
                        due = walking and ui.walk.wait > 0
                    end
                    local pick = due and Pet.Idle(math.random, moving, Pet.State().sick)
                    if pick then Pet.Play(ui.walk, sheet, pick) end
                end
            end
        end
        PaintWalk()
        Pet.PlayStep(dt)
        Pet.RoamVisitor(dt)
        Pet.Layer()
        Pet.Hatching(dt)
        -- Its needs move slowly: look again twice a minute.
        since = since + elapsed
        if since >= 30 then
            since = 0
            Refresh()
        end
    end))

    -- In the pen's corner: show only the pen, or everything again.
    ui.fold = Style.Button(ui.pen, "-", "plain", 20)
    ui.fold:SetHeight(20)
    ui.fold:SetPoint("TOPRIGHT", -4, -4)
    ui.fold:SetFrameLevel(50)
    ui.fold:SetAlpha(0.75)
    ui.fold:SetScript("OnClick", function() Pet.Fold() end)

    -- Beside it: the companion's sounds off, or on again.
    ui.mute = Style.Button(ui.pen, "", "plain", 20)
    ui.mute:SetHeight(20)
    ui.mute:SetPoint("TOPRIGHT", -28, -4)
    ui.mute:SetFrameLevel(50)
    ui.mute:SetAlpha(0.75)
    ui.mute.icon = ui.mute:CreateTexture(nil, "OVERLAY")
    ui.mute.icon:SetSize(16, 16)
    ui.mute.icon:SetPoint("CENTER")
    Compat.Crisp(ui.mute.icon)
    ui.mute:SetScript("OnClick", function() Pet.Mute() end)

    -- In the middle of the pen, only while it's ready to grow: it waits for this.
    ui.growButton = Style.Button(ui.pen, "Grow", "primary", 96)
    ui.growButton:SetPoint("TOP", 0, -30)
    ui.growButton:SetFrameLevel(50)
    ui.growButton:SetScript("OnClick", function() Pet.GrowNow() end)
    ui.growButton:Hide()

    -- And beside that: out of its window, to walk about with you as you play.
    ui.outButton = Style.Button(ui.pen, "Out", "plain", 36)
    ui.outButton:SetHeight(20)
    ui.outButton:SetPoint("TOPRIGHT", -52, -4)
    ui.outButton:SetFrameLevel(50)
    ui.outButton:SetAlpha(0.75)
    ui.outButton:SetScript("OnClick", function() Pet.Out() end)

    -- Out with you, in that button's place while the pointer is over it: how
    -- large it's drawn, once, twice or three times its art. A click goes round them.
    ui.sizeButton = Style.Button(ui.pen, "1x", "plain", 28)
    ui.sizeButton:SetHeight(20)
    ui.sizeButton:SetPoint("TOPRIGHT", -52, -4)
    ui.sizeButton:SetFrameLevel(50)
    ui.sizeButton:SetAlpha(0.75)
    ui.sizeButton:SetScript("OnClick", function() Pet.Resize() end)
    ui.sizeButton:Hide()

    -- In the pen's other corner: over to the paddock, and back.
    ui.yardToggle = Style.Button(ui.pen, "Paddock", "plain", 92)
    ui.yardToggle:SetHeight(20)
    ui.yardToggle:SetPoint("TOPLEFT", 4, -4)
    ui.yardToggle:SetFrameLevel(50)
    ui.yardToggle:SetAlpha(0.85)
    ui.yardToggle:SetScript("OnClick", function() Pet.Paddock() end)

end

local function BuildYard()
    -- Under the pen while the paddock shows: who has settled, then the album.
    ui.yardParts = CreateFrame("Frame", nil, ui.window)
    ui.yardParts:SetPoint("TOPLEFT", ui.pen, "BOTTOMLEFT", 0, 0)
    ui.yardParts:SetSize(PEN_W, WIN_H - PEN_H - 32 - PAD)
    ui.yardParts:Hide()
    ui.yardList = CreateFrame("Frame", nil, ui.yardParts)
    ui.yardList:SetAllPoints()
    ui.yardHead = Style.Text(ui.yardList, 12, "text")
    ui.yardHead:SetPoint("TOPLEFT", 0, -10)
    ui.yardHead:SetWidth(PEN_W)
    for i = 1, YARD_MAX do
        local row = Style.Text(ui.yardList, 12, "secondary")
        row:SetPoint("TOPLEFT", 0, -(34 + (i - 1) * 20))
        row:SetWidth(PEN_W)
        row:SetWordWrap(false)
        ui.yardRows[i] = row
    end
    ui.albumLine = Style.Text(ui.yardList, 12, "text")
    ui.albumLine:SetPoint("TOPLEFT", 0, -(44 + YARD_MAX * 20))
    for i = 1, #Rules.KINDS do
        local picture = ui.yardList:CreateTexture(nil, "ARTWORK")
        picture:SetSize(64, 64)
        -- Side by side across the pen, however many kinds there are.
        picture:SetPoint("TOPLEFT", (i - 1) * math.floor((PEN_W - 64) / (#Rules.KINDS - 1)), -(64 + YARD_MAX * 20))
        Compat.Crisp(picture)
        ui.album[i] = picture
    end

    -- The album, in the list's place when its button is pressed: a column
    -- for each kind, its three forms down it at the art's own size (a still
    -- is as large as a cell of its sheet), each with its name under it.
    ui.bookToggle = Style.Button(ui.pen, "Album", "plain", 64)
    ui.bookToggle:SetHeight(20)
    ui.bookToggle:SetPoint("TOPLEFT", 100, -4)
    ui.bookToggle:SetFrameLevel(50)
    ui.bookToggle:SetAlpha(0.85)
    ui.bookToggle:SetScript("OnClick", function() Pet.Album() end)
    ui.bookToggle:Hide()
    ui.yardBook = CreateFrame("Frame", nil, ui.yardParts)
    ui.yardBook:SetAllPoints()
    ui.yardBook:Hide()
    ui.bookHead = Style.Text(ui.yardBook, 12, "text")
    ui.bookHead:SetPoint("TOPLEFT", 0, -10)
    -- Four kinds to a page, each in a column a quarter of the pen wide, and
    -- arrows at the top right to turn the page.
    local wide = math.floor(PEN_W / BOOK_PAGE)
    ui.bookTurn.on = Style.Button(ui.yardBook, ">", "plain", 24)
    ui.bookTurn.on:SetHeight(20)
    ui.bookTurn.on:SetPoint("TOPRIGHT", 0, -6)
    ui.bookTurn.on:SetScript("OnClick", function() Pet.AlbumPage(1) end)
    ui.bookTurn.count = Style.Text(ui.yardBook, 12, "secondary")
    ui.bookTurn.count:SetPoint("RIGHT", ui.bookTurn.on, "LEFT", -6, 0)
    ui.bookTurn.back = Style.Button(ui.yardBook, "<", "plain", 24)
    ui.bookTurn.back:SetHeight(20)
    ui.bookTurn.back:SetPoint("RIGHT", ui.bookTurn.count, "LEFT", -6, 0)
    ui.bookTurn.back:SetScript("OnClick", function() Pet.AlbumPage(-1) end)
    for i, kind in ipairs(Rules.KINDS) do
        local slot = (i - 1) % BOOK_PAGE
        ui.book[i] = { page = math.floor((i - 1) / BOOK_PAGE) + 1 }
        for form, foot in ipairs(BOOK_ROWS) do
            local size = SHEETS[Rules.SPECIES[kind].sprites[form]].cell
            local picture = ui.yardBook:CreateTexture(nil, "ARTWORK")
            picture:SetSize(size, size)
            -- A cell larger than 80 has that much more empty round the creature:
            -- lowered by half of it, its feet stand where the others' do.
            picture:SetPoint("BOTTOM", ui.yardBook, "TOPLEFT", slot * wide + wide / 2, -foot - math.max(0, size - 80) / 2)
            Compat.Crisp(picture)
            local name = Style.Text(ui.yardBook, 11, "secondary")
            name:SetPoint("TOP", ui.yardBook, "TOPLEFT", slot * wide + wide / 2, -(foot + 2))
            name:SetWidth(wide)
            name:SetJustifyH("CENTER")
            name:SetWordWrap(false)
            ui.book[i][form] = { picture = picture, name = name }
        end
    end

end

local function BuildPicks()
    -- For a new player: three eggs on the grass, each with its name over it,
    -- and a line under the pen that says what to do and what a click found.
    ui.pickLine = Style.Text(ui.window, 12, "text")
    ui.pickLine:SetPoint("TOPLEFT", ui.pen, "BOTTOMLEFT", 0, -12)
    ui.pickLine:SetWidth(PEN_W)
    ui.pickLine:Hide()
    for i = 1, Rules.OFFERED do
        local pick = CreateFrame("Button", nil, ui.pen)
        pick:SetSize(64, 84)
        pick:SetPoint("BOTTOM", ui.pen, "BOTTOMLEFT", math.floor(PEN_W * i / 4), 24)
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
        ui.picks[i] = pick
    end

end

local function BuildParts()
    -- Everything under the pen hangs from this, PEN_H down from the pen's top.
    ui.parts = CreateFrame("Frame", nil, ui.window)
    ui.parts:SetPoint("TOPLEFT", ui.pen, "BOTTOMLEFT", 0, 0)
    ui.parts:SetSize(PEN_W, WIN_H - PEN_H - 32 - PAD)

    -- How it is, in a line you'd say out loud; under it, its age and when
    -- it grows. At the right, today's company as marks.
    ui.headline = Style.Text(ui.parts, 15, "text", nil, true)
    ui.headline:SetPoint("TOPLEFT", 0, -8)
    ui.headline:SetWidth(PEN_W - 190)
    ui.headline:SetWordWrap(false)
    ui.sub = Style.Text(ui.parts, 12, "secondary")
    ui.sub:SetPoint("TOPLEFT", 0, -31)
    ui.sub:SetWidth(PEN_W)
    ui.sub:SetWordWrap(false)
    ui.marks = {}
    for i = 1, 5 do
        local mark = ui.parts:CreateTexture(nil, "ARTWORK")
        mark:SetSize(9, 9)
        mark:SetPoint("TOPRIGHT", -(5 - i) * 13, -12)
        ui.marks[i] = mark
    end
    ui.company = Style.Text(ui.parts, 11, "muted")
    ui.company:SetPoint("TOPRIGHT", -(5 * 13 + 4), -10)
    ui.company:SetJustifyH("RIGHT")

    -- The four needs, two to a row: five pips each, in a colour of its own.
    local half = math.floor(PEN_W / 2)
    for i, need in ipairs(Rules.NEEDS) do
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        local label = Style.Text(ui.parts, 12, "secondary")
        label:SetPoint("TOPLEFT", col * half, -(55 + row * 22))
        label:SetText(NEED_NAME[need])
        local pips = {}
        for n = 1, 5 do
            local pip = ui.parts:CreateTexture(nil, "ARTWORK")
            pip:SetSize(16, 11)
            pip:SetPoint("TOPLEFT", col * half + 56 + (n - 1) * 19, -(56 + row * 22))
            pips[n] = pip
        end
        local low = Style.Text(ui.parts, 11, "red", nil, true)
        low:SetPoint("TOPLEFT", col * half + 56 + 5 * 19 + 4, -(55 + row * 22))
        ui.bars[need] = { pips = pips, label = label, low = low, tint = Pet.NEED_TINT[need] }
    end

    -- The bond: a heart a level, and how far the next is.
    ui.hearts = {}
    for i = 1, #Rules.BONDS do
        local heart = ui.parts:CreateTexture(nil, "ARTWORK")
        -- At half its picture's size, so each of its dots is one dot.
        heart:SetSize(16, 16)
        heart:SetPoint("TOPLEFT", (i - 1) * 19, -103)
        heart:SetTexture(Art("heart"), "CLAMP", "CLAMP", "NEAREST")
        Compat.Crisp(heart)
        ui.hearts[i] = heart
    end
    ui.bondLine = Style.Text(ui.parts, 13, "text", nil, true)
    ui.bondLine:SetPoint("TOPLEFT", #Rules.BONDS * 19 + 8, -104)

    -- Today's wish, as a card, with whether it's granted.
    local wish = CreateFrame("Frame", nil, ui.parts)
    wish:SetPoint("TOPLEFT", 0, -130)
    wish:SetSize(PEN_W, 28)
    local wishFill = wish:CreateTexture(nil, "BACKGROUND")
    wishFill:SetAllPoints()
    wishFill:SetColorTexture(Style.Color("well"))
    local wishEdge = wish:CreateTexture(nil, "ARTWORK")
    wishEdge:SetColorTexture(Style.Color("gold"))
    wishEdge:SetPoint("TOPLEFT")
    wishEdge:SetPoint("BOTTOMLEFT")
    wishEdge:SetWidth(3)
    ui.wishLine = Style.Text(wish, 12, "text")
    ui.wishLine:SetPoint("LEFT", 14, 0)
    ui.wishLine:SetWidth(PEN_W - 14 - 70)
    ui.wishLine:SetWordWrap(false)
    ui.wishTag = Style.Text(wish, 11, "muted")
    ui.wishTag:SetPoint("RIGHT", -12, 0)
    ui.wishTag:SetJustifyH("RIGHT")
    -- What just happened.
    ui.message = Style.Text(ui.parts, 12, "gold")
    ui.message:SetPoint("TOPLEFT", 0, -166)
    ui.message:SetWidth(PEN_W)
    ui.message:SetWordWrap(false)

    -- Care: a picture button for each kind, in a row, with how many it has
    -- left in its corner. The one it needs now is framed in gold and bobs;
    -- one with none left is greyed; pointing at one says what it does and
    -- how more are earned.
    local count = 0
    local CARE_W, CARE_H, CARE_GAP, CARE_Y = 68, 70, 6.4, 188
    local function Care(key, name, tint, tip, act, show, thing, over, sound)
        local b = Style.Button(ui.parts, "", "plain", CARE_W)
        b:SetHeight(CARE_H)
        b:SetPoint("TOPLEFT", count * (CARE_W + CARE_GAP), -CARE_Y)
        b:SetScript("OnClick", function()
            if Do(act, show, thing, over, sound) then Pet.Hearts(b) end
        end)
        b.name = name
        -- Its own words ("Feed · 3") would sit across its middle: they stay
        -- for anything that reads them, out of sight, and the word and the
        -- count are drawn in their own places.
        if type(b.label) == "table" and b.label.SetAlpha then b.label:SetAlpha(0) end
        local bar = b:CreateTexture(nil, "ARTWORK")
        bar:SetColorTexture(tint[1], tint[2], tint[3])
        bar:SetPoint("TOPLEFT", 1, -1)
        bar:SetPoint("TOPRIGHT", -1, -1)
        bar:SetHeight(3)
        b.art = b:CreateTexture(nil, "ARTWORK")
        b.art:SetSize(32, 32)
        b.art:SetPoint("TOP", 0, -11)
        b.art:SetTexture(Art("care_" .. key), "CLAMP", "CLAMP", "NEAREST")
        Compat.Crisp(b.art)
        b.word = Style.Text(b, 12, "text")
        b.word:SetPoint("BOTTOM", 0, 6)
        b.badge = b:CreateTexture(nil, "OVERLAY")
        b.badge:SetSize(18, 15)
        b.badge:SetPoint("TOPRIGHT", -3, -6)
        b.count = Style.Text(b, 10, "onGold", nil, true)
        b.count:SetPoint("CENTER", b.badge, "CENTER", 0, 0)
        -- A gold frame, shown while it's the one that's needed.
        b.frame = {}
        for i, at in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" }, { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
            local edge = b:CreateTexture(nil, "OVERLAY")
            edge:SetColorTexture(Style.Color("gold"))
            edge:SetPoint(at[1])
            edge:SetPoint(at[2])
            if i <= 2 then edge:SetHeight(2) else edge:SetWidth(2) end
            edge:Hide()
            b.frame[i] = edge
        end
        -- And a little bob of its picture, up and back, for as long as it's needed (Pet.BobCare).
        -- Only the picture moves, set in its place each time: sliding the whole button with the
        -- game's own animation sent it up out of the window and out of sight.
        b.bobbing = false
        -- Pressed, its picture dips, like a key going down.
        b:HookScript("OnMouseDown", function(self) self.pressed = true; self.art:SetPoint("TOP", 0, -14) end)
        b:HookScript("OnMouseUp", function(self) self.pressed = nil; self.art:SetPoint("TOP", 0, -11) end)
        b:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(self.word:GetText() or name)
            GameTooltip:AddLine(tip, 1, 1, 1, true)
            -- Why it's greyed just now, when that isn't for want of supplies.
            if self.why then GameTooltip:AddLine(self.why, 0.89, 0.69, 0.29, true) end
            GameTooltip:Show()
        end)
        b:HookScript("OnLeave", function() GameTooltip:Hide() end)
        ui.care[key] = b
        count = count + 1
    end
    Care("meal", "Feed", Pet.NEED_TINT.hunger, "Fills it up. A quest handed in brings a meal, and a new level a few.", Rules.Feed, "eat", "bowl", nil, "eat")
    Care("treat", "Treat", Pet.NEED_TINT.fun, "A bite it loves. Fishing and Cooking bring treats, and so does a new level.", Rules.Treat, "eat", "treat", nil, "eat")
    Care("toy", "Play", { 0.38, 0.7, 0.35 }, "A game with its ball. A flight brings a toy.", Rules.Play, "jump", "ball", nil, "play")
    Care("soap", "Bath", Pet.NEED_TINT.clean, "Scrubs it clean. A new level brings soap.", Rules.Bath, "idle", nil, "bath", "bath")
    Care("lights", "Lights out", { 0.54, 0.48, 0.82 }, "Puts it to bed, which is how it rests. Press it again to wake it.", Rules.Lights, "lights", nil, nil, "lights")
    Care("medicine", "Medicine", { 0.94, 0.48, 0.4 }, "Makes it well at once when it's poorly. First Aid brings medicine, and so does a new level.", Rules.Medicine, "idle", nil, "well", "well")
    local hint = Style.Text(ui.parts, 11, "muted")
    hint:SetPoint("TOPLEFT", 0, -(CARE_Y + CARE_H + 8))
    hint:SetWidth(PEN_W)
    hint:SetText("Point at a button for what it does and how you earn more. Click your pal for a pat or stroke it, right-click for a trick, the grass to call it over, a dropping to scoop it.")
    -- The eggs you hold: what they are, then one picture each to click.
    ui.eggLine = Style.Text(ui.parts, 12, "secondary")
    ui.eggLine:SetPoint("TOPLEFT", 0, -366)
    ui.eggLine:SetWidth(PEN_W)
    ui.eggLine:SetWordWrap(false)
    for i = 1, Rules.MAX_EGGS do
        local slot = CreateFrame("Button", nil, ui.parts)
        slot:SetSize(EGG_W + 8, EGG_W + 4)
        slot:SetPoint("TOPLEFT", (i - 1) * (EGG_W + 12), -384)
        slot.picture = slot:CreateTexture(nil, "ARTWORK")
        slot.picture:SetSize(EGG_W, EGG_W)
        slot.picture:SetPoint("BOTTOM", 0, 0)
        slot.picture:SetTexCoord(0.25, 0.75, 0.5, 1)
        Compat.Crisp(slot.picture)
        -- A click hatches it; a right-click lets it go.
        slot:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        slot:SetScript("OnClick", function(_, button)
            if button == "RightButton" then Pet.LetEggGo(i) else Pet.HatchEgg(i) end
        end)
        slot:SetScript("OnEnter", function(self)
            if not self.egg then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(self.egg)
            GameTooltip:AddLine("Click: your pal looks after it in a nest, once it's fully grown. When it hatches, your pal settles in the paddock.", 1, 1, 1, true)
            GameTooltip:AddLine("Right-click: let it go.", 0.6, 0.59, 0.53, true)
            GameTooltip:Show()
        end)
        slot:SetScript("OnLeave", function() GameTooltip:Hide() end)
        slot:Hide()
        ui.eggSlots[i] = slot
    end
    -- Beside the eggs, only while a new hatchling is being named: a box for
    -- its name and a button to confirm it. Enter does the same; Escape, or
    -- confirming the name offered, keeps that name.
    ui.renameButton = Style.Button(ui.parts, "Confirm", "plain", 141)
    ui.renameButton:SetHeight(28)
    ui.renameButton:SetPoint("TOPLEFT", 298, -388)
    ui.nameBox = Style.Field(ui.parts, 141)
    ui.nameBox.well:SetPoint("TOPLEFT", 149, -389)
    ui.nameBox.well:Hide()
    ui.nameBox:SetMaxLetters(16)
    ui.nameBox:SetScript("OnEnterPressed", TakeName)
    ui.nameBox:SetScript("OnEscapePressed", function()
        -- Escape keeps the name it has, and that settles it for a new hatchling too.
        Pet.State().unnamed = nil
        NameBox(false)
    end)
    ui.renameButton:SetScript("OnClick", TakeName)
    ui.renameButton:Hide()
end

local function Build()
    BuildPen()
    BuildYard()
    BuildPicks()
    BuildParts()
    Pet.BuildPlay()
    Pet.Layout()
    Place()
end

local function IsOpen()
    return ui.window ~= nil and ui.window:IsShown() == true
end

-- /jsal pet, the dashboard's menu and Today all come here: its window opens,
-- or closes if it was open.
function Pet.Open()
    if not Pet.running then
        return ns.Print("Jsal's Pals is turned off. /jsal settings turns it on.")
    end
    if not ui.window then Build() end
    if IsOpen() then return ui.window:Hide() end
    ui.said, Pet.armed, ui.yard, ui.albumOpen = nil, nil, false, false
    ui.play.hide, ui.play.nextHide = nil, nil
    Pet.letting, Pet.lifting = nil, nil
    ui.pen.shade = nil     -- opened, it's day or night at once, with no fade
    Pet.Layout()            -- as it was left: a window, the pen alone, or out with you
    ui.opening = true       -- what it's doing now is drawn as already done (asleep: in bed)
    Refresh()
    ui.window:Show()
end

-- For the pet's other files.
inner.IsOpen = IsOpen
