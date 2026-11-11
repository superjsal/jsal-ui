-- The companion: a small creature of your own that lives in a pen. It
-- wanders, gets hungry, tired, bored and dirty, sleeps, leaves droppings to
-- scoop, and can feel a little poorly. You look after it with supplies your
-- play brings in: a quest handed in is a meal, a flight is a toy, a new
-- level is treats, soap and medicine. Its life is in PetRules.lua; this is
-- the window, the wandering and the supplies. Nothing here runs unless its
-- window is open, apart from noticing what you earn.
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
local PEN_W, PEN_H, SIZE = 440, 150, 64
local SPEED = 28          -- pixels a second
local STEP_TIME = 0.28    -- seconds each walking frame shows
Pet.PEN_W, Pet.PEN_H, Pet.SIZE = PEN_W, PEN_H, SIZE
local FORMS = { "Briarboar", "Thornhog", "Brambletusk" }
local NEED_NAME = { hunger = "Fed", energy = "Rested", fun = "Happy", clean = "Clean" }

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

---------------------------------------------------------------------------
-- The window.
---------------------------------------------------------------------------
local frame, pen, body, sprite, snore, line, message, walk
local bars, care, heaps = {}, {}, {}
local FILE = { stand = MEDIA .. "briarboar", step = MEDIA .. "briarboar_step" }
local HEAP_AT = { 70, 180, 290, 370 }
local said

local function PaintWalk()
    -- The sprite is drawn facing left; turned round, its picture is flipped.
    if walk.facing == "right" then
        sprite:SetTexCoord(1, 0, 0, 1)
    else
        sprite:SetTexCoord(0, 1, 0, 1)
    end
    if sprite.file ~= walk.frame then
        sprite.file = walk.frame
        -- NEAREST keeps each of its 32 pixels a sharp square when drawn larger.
        sprite:SetTexture(FILE[walk.frame], "CLAMP", "CLAMP", "NEAREST")
    end
    body:ClearAllPoints()
    body:SetPoint("TOPLEFT", pen, "TOPLEFT", math.floor(walk.x + 0.5), -math.floor(walk.y + 0.5))
end

-- Everything that depends on how it is: the line under the title, the four
-- bars, the droppings, the buttons and what they'd use.
local function Refresh()
    local s = Rules.Advance(Pet.State(), Now())
    local _, mood = Rules.Mood(s)
    line:SetText(("%s the %s · %s"):format(s.name, FORMS[s.form] or FORMS[1], mood))
    if s.grew then
        s.grew = nil
        said = ("%s has grown into a %s!"):format(s.name, FORMS[s.form] or "")
    end
    message:SetText(said or "")
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
end
Pet.Refresh = Refresh

-- One piece of care: do it, say what happened, and show how it is now.
local function Do(act)
    local _, what = act(Pet.State(), Now())
    said = what
    Refresh()
end

local function Build()
    frame = Style.Panel("jsalUIPet", PEN_W + 40, 392, "Companion")
    line = Style.Text(frame, 13, "text", nil, true)
    line:SetPoint("TOPLEFT", 20, -46)

    pen = CreateFrame("Frame", nil, frame)
    pen:SetSize(PEN_W, PEN_H)
    pen:SetPoint("TOPLEFT", 20, -72)
    pen:SetClipsChildren(true)
    Style.Border(pen, "cardLine")
    local ground = pen:CreateTexture(nil, "BACKGROUND")
    ground:SetAllPoints()
    ground:SetColorTexture(0.12, 0.165, 0.133)
    local sky = pen:CreateTexture(nil, "BORDER")
    sky:SetPoint("TOPLEFT")
    sky:SetPoint("TOPRIGHT")
    sky:SetHeight(44)
    sky:SetColorTexture(0.137, 0.165, 0.212)

    -- Droppings: click one to scoop it.
    for i, x in ipairs(HEAP_AT) do
        local heap = CreateFrame("Button", nil, pen)
        heap:SetSize(16, 12)
        heap:SetPoint("TOPLEFT", x, -(PEN_H - 22 - (i % 2) * 18))
        local low = heap:CreateTexture(nil, "ARTWORK")
        low:SetPoint("BOTTOMLEFT")
        low:SetSize(16, 6)
        low:SetColorTexture(0.36, 0.24, 0.14)
        local top = heap:CreateTexture(nil, "ARTWORK")
        top:SetPoint("BOTTOM", 0, 6)
        top:SetSize(10, 6)
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
    snore = Style.Text(body, 13, "secondary", nil, true)
    snore:SetPoint("BOTTOMLEFT", body, "TOPRIGHT", -18, -14)
    snore:SetText("z z z")

    -- Only while the window is open: a hidden frame gets no updates.
    local since = 0
    pen:SetScript("OnUpdate", ns.Safe(Pet, function(_, elapsed)
        local s = Pet.State()
        if s.asleep then
            -- Asleep, it stays put.
            walk.frame, walk.wait = "stand", math.max(walk.wait, 0.5)
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

    -- The four needs, two to a row.
    for i, need in ipairs(Rules.NEEDS) do
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        local label = Style.Text(frame, 12, "secondary")
        label:SetPoint("TOPLEFT", 20 + col * 226, -(236 + row * 22))
        label:SetText(NEED_NAME[need])
        local track = frame:CreateTexture(nil, "ARTWORK")
        track:SetPoint("TOPLEFT", 78 + col * 226, -(240 + row * 22))
        track:SetSize(136, 6)
        track:SetColorTexture(Style.Color("titleBar"))
        local fill = frame:CreateTexture(nil, "OVERLAY")
        fill:SetPoint("TOPLEFT", track, "TOPLEFT")
        fill:SetHeight(6)
        bars[need] = { fill = fill, width = 136 }
    end

    message = Style.Text(frame, 12, "gold")
    message:SetPoint("TOPLEFT", 20, -288)
    message:SetWidth(PEN_W)
    message:SetWordWrap(false)

    -- Care, each button with how many it has left.
    local function Care(key, x, y, act)
        local b = Style.Button(frame, "", "plain", 104)
        b:SetPoint("TOPLEFT", x, y)
        b:SetScript("OnClick", function() Do(act) end)
        care[key] = b
    end
    Care("meal", 20, -312, Rules.Feed)
    Care("treat", 132, -312, Rules.Treat)
    Care("toy", 244, -312, Rules.Play)
    Care("soap", 356, -312, Rules.Bath)
    Care("lights", 20, -348, Rules.Lights)
    Care("medicine", 132, -348, Rules.Medicine)
    local hint = Style.Text(frame, 11, "muted")
    hint:SetPoint("TOPLEFT", 244, -350)
    hint:SetWidth(216)
    hint:SetText("Quests bring meals, flights bring toys, a new level brings the rest.")
end

function Pet.Open()
    if not Pet.running then
        return ns.Print("The companion is turned off. /jsal settings turns it on.")
    end
    if Compat.InCombat() then
        return ns.Print("The companion's window opens once combat ends.")
    end
    if not frame then Build() end
    walk = walk or Pet.NewWalk(math.random)
    said = nil
    PaintWalk()
    Refresh()
    frame:Show()
end

---------------------------------------------------------------------------
-- Supplies from your play.
---------------------------------------------------------------------------
function Pet.Earn(supply, count)
    Rules.Earn(Pet.State(), supply, count)
    if frame and frame:IsShown() then Refresh() end
end

function Pet:OnEnable()
    -- A hatchling from the moment the part is switched on, so what you earn
    -- before first opening the window isn't lost.
    Pet.State()
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterEvent("QUEST_TURNED_IN")
    events:RegisterEvent("PLAYER_LEVEL_UP")
    events:RegisterEvent("PLAYER_CONTROL_LOST")
    events:SetScript("OnEvent", ns.Safe(self, function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            if frame then frame:Hide() end
        elseif event == "QUEST_TURNED_IN" then
            Pet.Earn("meal", 1)
        elseif event == "PLAYER_LEVEL_UP" then
            Pet.Earn("treat", 2)
            Pet.Earn("soap", 1)
            Pet.Earn("medicine", 1)
        elseif event == "PLAYER_CONTROL_LOST" then
            -- The game takes the controls away as a flight starts (and for
            -- other things): a moment later, see whether you're flying.
            Compat.After(1, ns.Safe(self, function()
                if Compat.OnTaxi() then Pet.Earn("toy", 1) end
            end))
        end
    end))
end

ns.Command("pet", function() Pet.Open() end)
