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
-- drawn at its own size, so a hatchling is small and has growing to do; the
-- largest is 128 pixels, twice the size of its 64-pixel art.
local PAD = 10
local PEN_W, PEN_H, SIZE = 440, 200, 128
local SIZES = { 64, 96, 128 }
-- How far down the pen the grass starts: its feet stay below this.
local GRASS = 110
local WIN_W, WIN_H = PEN_W + PAD * 2, 512
local HEAP_W = 24
local SPEED = 40          -- pixels a second
local STEP_TIME = 0.28    -- seconds each walking frame shows
Pet.PEN_W, Pet.PEN_H, Pet.SIZE, Pet.SIZES, Pet.HEAP_W = PEN_W, PEN_H, SIZE, SIZES, HEAP_W
local FORMS = { "Briarboar", "Thornhog", "Brambletusk" }
local NEED_NAME = { hunger = "Fed", energy = "Rested", fun = "Happy", clean = "Clean" }
-- Each form's pictures: standing, mid-step and asleep.
local SPRITE = { "briarboar", "thornhog", "brambletusk" }
local SUFFIX = { stand = "", step = "_step", sleep = "_sleep" }
-- A form with a sheet is animated instead: one picture of 64 cells, eight
-- to a row, its animations one after another. Each is the cell it starts
-- at (counted from 0), how many frames it has and how long each one shows.
local SHEETS = {
    briarboar = {
        file = "briarboar_sheet", cols = 8,
        walk = { first = 0, count = 4, time = 0.14 },
        idle = { first = 4, count = 15, time = 0.14 },
        eat  = { first = 19, count = 11, time = 0.12 },
        jump = { first = 30, count = 7, time = 0.1 },
        sit  = { first = 37, count = 10, time = 0.16 },
        doze = { first = 47, count = 8, time = 0.16 },
        wake = { first = 55, count = 9, time = 0.12 },
        stand = 4, sleep = 54,    -- the cells held while it stands and while it sleeps
    },
}
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
    walk.act = { name = name, clock = 0, length = anim.count * anim.time }
    return true
end

-- The cell of its sheet to show right now.
function Pet.Cell(walk, sheet)
    local act = walk.act
    local anim = act and sheet[act.name]
    if anim then
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

-- The saved companion; a new hatchling the first time, or when what's
-- saved isn't one.
function Pet.State()
    local s = ns.db.pet
    if type(s) ~= "table" or type(s.supplies) ~= "table" or type(s.stamp) ~= "number" or type(s.due) ~= "table" then
        s = Rules.New(Now())
        ns.db.pet = s
    end
    return s
end

-- What it wants from you right now, for Today: a title, a line under it and
-- its picture; nil when it's fine, asleep, or the part is off.
function Pet.Wants()
    if not Pet.running then return nil end
    local s = Rules.Advance(Pet.State(), Now())
    local key, title, sub = Rules.Wants(s)
    if not key then return nil end
    return { key = key, title = title, sub = sub, texture = MEDIA .. (SPRITE[s.form] or SPRITE[1]) }
end

---------------------------------------------------------------------------
-- Its page.
---------------------------------------------------------------------------
local window, pen, body, sprite, snore, title, sub, message, wishLine, bondLine, walk, parts, fold
local bars, care, heaps = {}, {}, {}
local HEAP_AT = { 30, 140, 260, 380 }
local said

-- The sheet of the form it's in now, if that form has one.
local function Sheet()
    return SHEETS[SPRITE[Pet.State().form] or SPRITE[1]]
end

local function PaintWalk()
    local sheet = Sheet()
    local file, left, right, top, bottom
    if sheet then
        local cell = Pet.Cell(walk, sheet)
        local col, row = cell % sheet.cols, math.floor(cell / sheet.cols)
        file = MEDIA .. sheet.file
        left, right, top, bottom = col / sheet.cols, (col + 1) / sheet.cols, row / sheet.cols, (row + 1) / sheet.cols
    else
        file = MEDIA .. (SPRITE[Pet.State().form] or SPRITE[1]) .. SUFFIX[walk.frame]
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
    body:ClearAllPoints()
    body:SetPoint("TOPLEFT", pen, "TOPLEFT", math.floor(walk.x + 0.5), -math.floor(walk.y + 0.5))
end

-- Its milestones, each told once: hatching, growing up, a closer bond.
-- They go into your Journal's story, and the newest comes back as a line
-- for whoever is showing the pet.
local function Milestones(s)
    local told = {}
    local form = FORMS[s.form] or FORMS[1]
    if not s.told then
        s.told = true
        told[#told + 1] = ("%s the %s hatched"):format(s.name, FORMS[1])
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
local function Refresh()
    local s = Rules.Advance(Pet.State(), Now())
    local _, mood = Rules.Mood(s)
    title:SetText(("%s the %s"):format(s.name, FORMS[s.form] or FORMS[1]))
    local day = math.floor(math.max(0, Now() - s.born) / 86400) + 1
    local growing = Growing(s)
    sub:SetText(("%s · day %d%s"):format(mood, day, growing and (" · " .. growing) or " · fully grown"))
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
    if s.sick then sprite:SetVertexColor(0.78, 1, 0.78) else sprite:SetVertexColor(1, 1, 1) end
    care.meal:SetLabel(("Feed · %d"):format(s.supplies.meal))
    care.treat:SetLabel(("Treat · %d"):format(s.supplies.treat))
    care.toy:SetLabel(("Play · %d"):format(s.supplies.toy))
    care.soap:SetLabel(("Bath · %d"):format(s.supplies.soap))
    care.medicine:SetLabel(("Medicine · %d"):format(s.supplies.medicine))
    care.medicine:SetEnabled(s.sick)
    care.lights:SetLabel(s.asleep and "Wake it" or "Lights out")
    -- A form that has grown is drawn larger, and starts from a spot that fits it.
    local size = SIZES[s.form] or SIZE
    if not walk or walk.size ~= size then walk = Pet.NewWalk(math.random, size) end
    PaintWalk()
end
Pet.Refresh = Refresh

-- One piece of care: do it, say what happened, and show how it is now. The
-- menu's badge and Today hear about it too.
-- `show` is the animation that goes with it, played when the care was
-- given and the creature is awake to react ("lights" picks its own: settling
-- down or getting up).
local function Do(act, show)
    local s = Pet.State()
    local ok, what = act(s, Now())
    said = what
    if ok and walk and show then
        if show == "lights" then
            Pet.Play(walk, Sheet(), s.asleep and "doze" or "wake")
        elseif not s.asleep then
            Pet.Play(walk, Sheet(), show)
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
local function Layout()
    local small = ns.db.petCompact == true
    window.bar:SetShown(not small)
    parts:SetShown(not small)
    pen:ClearAllPoints()
    if small then
        pen:SetPoint("TOPLEFT", 1, -1)
        window:SetSize(PEN_W + 2, PEN_H + 2)
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
    scene:SetAllPoints()
    scene:SetTexture(MEDIA .. "meadow", "CLAMP", "CLAMP", "NEAREST")
    scene:SetTexCoord(0, 220 / 256, 0, 100 / 128)
    Compat.Crisp(scene)
    -- The pen can be dragged too: with only the pen showing, it's all there is to hold.
    pen:EnableMouse(true)
    pen:RegisterForDrag("LeftButton")
    pen:SetScript("OnDragStart", function() window:StartMoving() end)
    pen:SetScript("OnDragStop", Dropped)

    -- Droppings: click one to scoop it.
    for i, x in ipairs(HEAP_AT) do
        local heap = CreateFrame("Button", nil, pen)
        heap:SetSize(HEAP_W, 18)
        heap:SetPoint("TOPLEFT", x, -(PEN_H - 34 - (i % 2) * 26))
        local low = heap:CreateTexture(nil, "ARTWORK")
        low:SetPoint("BOTTOMLEFT")
        low:SetSize(HEAP_W, 9)
        low:SetColorTexture(0.36, 0.24, 0.14)
        local top = heap:CreateTexture(nil, "ARTWORK")
        top:SetPoint("BOTTOM", 0, 9)
        top:SetSize(15, 9)
        top:SetColorTexture(0.44, 0.3, 0.18)
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
    snore = Style.Text(body, 15, "secondary", nil, true)
    snore:SetPoint("BOTTOMLEFT", body, "TOPRIGHT", -26, -20)
    snore:SetText("z z z")

    -- Only while the page is showing: a hidden frame gets no updates.
    local since = 0
    pen:SetScript("OnUpdate", ns.Safe(Pet, function(_, elapsed)
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
                local pick = math.random(1, 4)
                if pick <= 2 then Pet.Play(walk, sheet, pick == 1 and "sit" or "idle") end
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
    local function Care(key, act, show)
        local b = Style.Button(parts, "", "plain", 141)
        b:SetHeight(28)
        b:SetPoint("TOPLEFT", (count % 3) * 149, -(146 + math.floor(count / 3) * 34))
        b:SetScript("OnClick", function() Do(act, show) end)
        care[key] = b
        count = count + 1
    end
    Care("meal", Rules.Feed, "eat")
    Care("treat", Rules.Treat, "eat")
    Care("toy", Rules.Play, "jump")
    Care("soap", Rules.Bath)
    Care("lights", Rules.Lights, "lights")
    Care("medicine", Rules.Medicine)
    local hint = Style.Text(parts, 11, "muted")
    hint:SetPoint("TOPLEFT", 0, -220)
    hint:SetWidth(PEN_W)
    hint:SetText("Quests bring meals, flights bring toys, a new level brings the rest. Click it for a pat, and a dropping to scoop it.")
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
    said = nil
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
    events:SetScript("OnEvent", ns.Safe(self, function(_, event)
        if event == "ZONE_CHANGED_NEW_AREA" then
            -- The game also says this as you log in; that isn't a trip.
            local now = ZoneName()
            if now and zone and now ~= zone then Pet.Did("zone") end
            zone = now or zone
        elseif event == "QUEST_TURNED_IN" then
            Pet.Earn("meal", 1)
            Pet.Did("quest")
        elseif event == "PLAYER_LEVEL_UP" then
            Pet.Earn("treat", 2)
            Pet.Earn("soap", 1)
            Pet.Earn("medicine", 1)
        elseif event == "PLAYER_CONTROL_LOST" then
            -- The game takes the controls away as a flight starts (and for
            -- other things): a moment later, see whether you're flying.
            Compat.After(1, ns.Safe(self, function()
                if Compat.OnTaxi() then
                    Pet.Earn("toy", 1)
                    Pet.Did("flight")
                end
            end))
        end
    end))
end

ns.Command("pet", function() Pet.Open() end)
