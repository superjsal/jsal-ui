-- The companion: a small creature of your own that lives in a pen. It
-- wanders, gets hungry, tired, bored and dirty, sleeps, leaves droppings to
-- scoop, and can feel a little poorly. You look after it with supplies your
-- play brings in: a quest handed in is a meal, a flight is a toy, a new
-- level is treats, soap and medicine. Its life is in PetRules.lua; this is
-- its page in the dashboard, the wandering and the supplies. Nothing here
-- runs unless its page is open, apart from noticing what you earn.
local _, ns = ...
local Style, Compat, Rules, Window = ns.Style, ns.Compat, ns.PetRules, ns.Window

local Pet = ns.NewModule("pet", {
    title = "Companion",
    -- A new part, so it starts off.
    defaultOn = false,
    note = "A small creature of your own to look after, with supplies your play earns. /jsal pet",
})
ns.Pet = Pet

local MEDIA = "Interface\\AddOns\\jsalUI\\Media\\Pet\\"
-- The pen is as wide as the page; the creature is drawn at three times its
-- 32 pixels, so each of them is a sharp 3 by 3 square.
local PEN_W, PEN_H, SIZE = Window.contentWidth, 240, 96
local HEAP_W = 24
local SPEED = 40          -- pixels a second
local STEP_TIME = 0.28    -- seconds each walking frame shows
Pet.PEN_W, Pet.PEN_H, Pet.SIZE, Pet.HEAP_W = PEN_W, PEN_H, SIZE, HEAP_W
local FORMS = { "Briarboar", "Thornhog", "Brambletusk" }
local NEED_NAME = { hunger = "Fed", energy = "Rested", fun = "Happy", clean = "Clean" }
-- Each form's pictures: standing, mid-step and asleep.
local SPRITE = { "briarboar", "thornhog", "brambletusk" }
local SUFFIX = { stand = "", step = "_step", sleep = "_sleep" }

---------------------------------------------------------------------------
-- Wandering, with no drawing in it. A walk is where the creature is (its
-- top left corner in the pen), where it's heading, which way it faces,
-- which frame shows, and how long it still stands before the next stroll.
---------------------------------------------------------------------------
local function Spot(random)
    return random(0, PEN_W - SIZE), random(0, PEN_H - SIZE)
end

function Pet.NewWalk(random)
    local x, y = Spot(random)
    return { x = x, y = y, tx = x, ty = y, wait = 1, facing = "left", frame = "stand", clock = 0 }
end

-- Moves the walk on by `dt` seconds.
function Pet.Step(walk, dt, random)
    if walk.wait > 0 then
        walk.wait = walk.wait - dt
        walk.frame = "stand"
        if walk.wait <= 0 then
            walk.tx, walk.ty = Spot(random)
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
local pen, body, sprite, snore, title, sub, message, wishLine, bondLine, walk, parts
local bars, care, heaps = {}, {}, {}
local HEAP_AT = { 110, 290, 470, 610 }
local said

local function PaintWalk()
    -- The sprite is drawn facing left; turned round, its picture is flipped.
    if walk.facing == "right" then
        sprite:SetTexCoord(1, 0, 0, 1)
    else
        sprite:SetTexCoord(0, 1, 0, 1)
    end
    local file = MEDIA .. (SPRITE[Pet.State().form] or SPRITE[1]) .. SUFFIX[walk.frame]
    if sprite.file ~= file then
        sprite.file = file
        -- NEAREST keeps each of its 32 pixels a sharp square when drawn larger.
        sprite:SetTexture(file, "CLAMP", "CLAMP", "NEAREST")
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
    if not Pet.running then
        title:SetText("Companion")
        sub:SetText("Turned off. Switch it on in Settings, under Games.")
        parts:Hide()
        return
    end
    parts:Show()
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
    walk = walk or Pet.NewWalk(math.random)
    PaintWalk()
end
Pet.Refresh = Refresh

-- One piece of care: do it, say what happened, and show how it is now. The
-- menu's badge and Today hear about it too.
local function Do(act)
    local _, what = act(Pet.State(), Now())
    said = what
    Refresh()
end

Window.Page("pet", function(page)
    local width = PEN_W
    title, sub = Window.Header(page, width)
    -- Everything under the two lines, to hide as one when the part is off.
    parts = CreateFrame("Frame", nil, page)
    parts:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -16)
    parts:SetSize(width, PEN_H + 176)

    pen = CreateFrame("Frame", nil, parts)
    pen:SetSize(PEN_W, PEN_H)
    pen:SetPoint("TOPLEFT")
    pen:SetClipsChildren(true)
    Style.Border(pen, "cardLine")
    local ground = pen:CreateTexture(nil, "BACKGROUND")
    ground:SetAllPoints()
    ground:SetColorTexture(0.12, 0.165, 0.133)
    local sky = pen:CreateTexture(nil, "BORDER")
    sky:SetPoint("TOPLEFT")
    sky:SetPoint("TOPRIGHT")
    sky:SetHeight(70)
    sky:SetColorTexture(0.137, 0.165, 0.212)

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
    body:SetScript("OnClick", function() Do(Rules.Pat) end)
    snore = Style.Text(body, 15, "secondary", nil, true)
    snore:SetPoint("BOTTOMLEFT", body, "TOPRIGHT", -26, -20)
    snore:SetText("z z z")

    -- Only while the page is showing: a hidden frame gets no updates.
    local since = 0
    pen:SetScript("OnUpdate", ns.Safe(Pet, function(_, elapsed)
        if not walk then return end
        if Pet.State().asleep then
            -- Asleep, it stays put, eyes shut.
            walk.frame, walk.wait = "sleep", math.max(walk.wait, 0.5)
        else
            -- A long hitch (a loading screen) shouldn't fling it across the pen.
            Pet.Step(walk, math.min(elapsed, 0.1), math.random)
        end
        PaintWalk()
        -- Its needs move slowly: look again twice a minute.
        since = since + elapsed
        if since >= 30 then
            since = 0
            Refresh()
        end
    end))

    -- The four needs, two to a row, under the pen.
    local half = math.floor(width / 2)
    for i, need in ipairs(Rules.NEEDS) do
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        local label = Style.Text(parts, 13, "secondary")
        label:SetPoint("TOPLEFT", col * half, -(PEN_H + 16 + row * 24))
        label:SetText(NEED_NAME[need])
        local track = parts:CreateTexture(nil, "ARTWORK")
        track:SetPoint("TOPLEFT", col * half + 64, -(PEN_H + 21 + row * 24))
        track:SetSize(half - 88, 6)
        track:SetColorTexture(Style.Color("titleBar"))
        local fill = parts:CreateTexture(nil, "OVERLAY")
        fill:SetPoint("TOPLEFT", track, "TOPLEFT")
        fill:SetHeight(6)
        bars[need] = { fill = fill, width = half - 88 }
    end

    -- Today's wish at the left, the bond at the right.
    wishLine = Style.Text(parts, 13, "text")
    wishLine:SetPoint("TOPLEFT", 0, -(PEN_H + 68))
    wishLine:SetWidth(width - 230)
    wishLine:SetWordWrap(false)
    bondLine = Style.Text(parts, 13, "secondary")
    bondLine:SetPoint("TOPRIGHT", 0, -(PEN_H + 68))
    bondLine:SetJustifyH("RIGHT")

    message = Style.Text(parts, 13, "gold")
    message:SetPoint("TOPLEFT", 0, -(PEN_H + 94))
    message:SetWidth(width)
    message:SetWordWrap(false)

    -- Care, each button with how many it has left.
    local x = 0
    local function Care(key, act)
        local b = Style.Button(parts, "", "plain", 115)
        b:SetHeight(30)
        b:SetPoint("TOPLEFT", x, -(PEN_H + 120))
        b:SetScript("OnClick", function() Do(act) end)
        care[key] = b
        x = x + 123
    end
    Care("meal", Rules.Feed)
    Care("treat", Rules.Treat)
    Care("toy", Rules.Play)
    Care("soap", Rules.Bath)
    Care("lights", Rules.Lights)
    Care("medicine", Rules.Medicine)
    local hint = Style.Text(parts, 12, "muted")
    hint:SetPoint("TOPLEFT", 0, -(PEN_H + 162))
    hint:SetWidth(width)
    hint:SetText("Quests you hand in bring meals, flights bring toys, and a new level brings treats, soap and medicine. Click a dropping to scoop it, and the creature itself for a pat. Each day it has one wish; granting it, and looking after it day by day, deepens your bond.")

    page.Refresh = function()
        said = nil
        Refresh()
    end
end)

function Pet.Open()
    if not Pet.running then
        return ns.Print("The companion is turned off. /jsal settings turns it on.")
    end
    Window.Open("pet")
end

---------------------------------------------------------------------------
-- Supplies from your play.
---------------------------------------------------------------------------
function Pet.Earn(supply, count)
    Rules.Earn(Pet.State(), supply, count)
    if Window.IsOpen("pet") then Refresh() end
end

-- Something you did that it may have wished for today. Granted with its
-- page shut, it says so in chat, once.
function Pet.Did(kind)
    local s = Pet.State()
    if not Rules.Did(s, kind, Now()) then return end
    if Window.IsOpen("pet") then
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
