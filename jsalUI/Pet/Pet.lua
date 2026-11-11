-- The companion: a small creature of your own that lives in a pen. This
-- first piece is the pen and the creature wandering in it: it picks a spot,
-- walks there, stands a moment, and picks another. Nothing here runs unless
-- its window is open.
local _, ns = ...
local Style, Compat = ns.Style, ns.Compat

local Pet = ns.NewModule("pet", {
    title = "Companion",
    -- A new part, so it starts off.
    defaultOn = false,
    note = "A small creature of your own, wandering its pen. /jsal pet",
})
ns.Pet = Pet

local MEDIA = "Interface\\AddOns\\jsalUI\\Media\\Pet\\"
local PEN_W, PEN_H, SIZE = 440, 150, 64
local SPEED = 28          -- pixels a second
local STEP_TIME = 0.28    -- seconds each walking frame shows
Pet.PEN_W, Pet.PEN_H, Pet.SIZE = PEN_W, PEN_H, SIZE

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
-- The window.
---------------------------------------------------------------------------
local frame, pen, sprite, walk
local FILE = { stand = MEDIA .. "briarboar", step = MEDIA .. "briarboar_step" }

local function Paint()
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
    sprite:ClearAllPoints()
    sprite:SetPoint("TOPLEFT", pen, "TOPLEFT", math.floor(walk.x + 0.5), -math.floor(walk.y + 0.5))
end

local function Build()
    frame = Style.Panel("jsalUIPet", PEN_W + 40, PEN_H + 100, "Companion")
    local line = Style.Text(frame, 12, "muted")
    line:SetPoint("TOPLEFT", 20, -46)
    line:SetText("A Briarboar, out for a wander. Its needs and care come next.")

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

    sprite = pen:CreateTexture(nil, "ARTWORK")
    sprite:SetSize(SIZE, SIZE)
    Compat.Crisp(sprite)

    -- Only while the window is open: a hidden frame gets no updates.
    pen:SetScript("OnUpdate", ns.Safe(Pet, function(_, elapsed)
        -- A long hitch (a loading screen) shouldn't fling it across the pen.
        Pet.Step(walk, math.min(elapsed, 0.1), math.random)
        Paint()
    end))
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
    Paint()
    frame:Show()
end

function Pet:OnEnable()
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:SetScript("OnEvent", ns.Safe(self, function()
        if frame then frame:Hide() end
    end))
end

ns.Command("pet", function() Pet.Open() end)
