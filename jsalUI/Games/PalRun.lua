-- Pal run: a platformer for your pal. One course a day, the same for
-- everyone, against the clock: three runs at it a day, the best of them
-- stands, and the guild's times are listed beside the course. Three falls
-- end a run. Practice courses are random and count for nothing. The rules are in PalRunRules.lua; this is the
-- window, the keys and what's kept.
local _, ns = ...
local Style, Compat, Games, Rules = ns.Style, ns.Compat, ns.Games, ns.PalRunRules

local PalRun = ns.NewModule("palrun", {
    title = "Pal run",
    note = "A platformer for your pal: one course a day, the same for everyone, against the clock, with your guild's times beside it. /jsal run",
})
ns.PalRun = PalRun

-- Its pictures are the pals' own and PNG, which the game must be told: a path with
-- no ending is looked for as a BLP or a TGA only.
local function Art(name) return "Interface\\AddOns\\jsalUI\\Media\\Pet\\" .. name .. ".png" end
local TILE = 48                       -- a tile of the course, in pixels: its 16-pixel picture three times over
local FIELD_W, FIELD_H = 880, 400
local PAD, BOARD_W, ROW_H, ROWS_SHOWN = 16, 240, 30, 6
local SCALE = 2                       -- the pal is drawn at twice its picture's size
local FLAG_W, FLAG_H = 16, 35         -- the flag's size in run.png (tools/make_run_tiles.py prints it)
-- A country's scenery (run_back_<land>.png): how wide and high its picture is, and how much of
-- its width shows at once, four times over. The rest is room for it to slide.
local BACK_W, BACK_H, BACK_SHOWN = 256, 100, 220

-- Where each kind's feet are in the 64 pixels it stands in, counted down
-- from the top, so each stands on the ground and not in or over it.
local FEET = {
    briarboar = 57, thornhog = 58, brambletusk = 64, wispkin = 56, gloamtail = 62, wispjester = 61,
    scrapwing = 57, jabdrake = 59, flarechamp = 61, stormcub = 57, thundermane = 59, tempestmane = 63,
    capling = 56, lanternshell = 57, bloomsage = 60, boltusk = 58, rumbletrunk = 61, warmammoth = 65,
    gemlet = 57, miragehoof = 59, sandseer = 65, pebblebill = 53, cobbleback = 54, rockwarden = 63,
    snowlet = 57, frostmantle = 62, auroracrown = 64, starwhelp = 55, moondrake = 60, eclipselord = 69,
    glumbill = 57, broodstork = 61, dreadmire = 62,
}
PalRun.FEET = FEET
-- And where its feet are across the picture: how many of its pixels right of the middle they sit
-- (the pictures face left), standing and then on the move, so they're drawn over the box and not
-- beside it. Measured from each kind's standing frame and the average of its ten running ones.
local FEETX = {
    briarboar = { 3, 4 }, thornhog = { 2, 2 }, brambletusk = { -2, 0 }, wispkin = { 1, -1 }, gloamtail = { 0, -1 },
    wispjester = { -3, -3 }, scrapwing = { -4, -1 }, jabdrake = { -4, 1 }, flarechamp = { 4, 2 },
    stormcub = { 0, -2 }, thundermane = { -10, -7 }, tempestmane = { -11, -10 }, capling = { 2, 5 },
    lanternshell = { 6, 4 }, bloomsage = { 1, -1 }, boltusk = { 4, 6 }, rumbletrunk = { 4, -1 },
    warmammoth = { -3, -2 }, gemlet = { 0, 1 }, miragehoof = { -1, -1 }, sandseer = { 2, 2 },
    pebblebill = { -2, -2 }, cobbleback = { 0, -2 }, rockwarden = { 8, 1 }, snowlet = { -1, 0 },
    frostmantle = { 4, 3 }, auroracrown = { 2, 5 }, starwhelp = { -3, -3 }, moondrake = { -6, -5 },
    eclipselord = { -3, 2 }, glumbill = { -1, -3 }, broodstork = { -1, -4 }, dreadmire = { -1, -4 },
}
PalRun.FEETX = FEETX

---------------------------------------------------------------------------
-- What's kept, for the whole account: today's best time, how many runs at
-- the day's course have been started, and the fastest daily course ever.
-- Times are in steps, sixty to the second.
---------------------------------------------------------------------------
PalRun.RUNS = 3   -- runs at the day's course: one, and two retries

local function Saved()
    local s = ns.db.palrun
    if type(s) ~= "table" then
        s = {}
        ns.db.palrun = s
    end
    if s.day ~= Games.Today() then s.day, s.best, s.tries = Games.Today(), nil, 0 end
    return s
end

-- Runs still to be had at today's course.
function PalRun.Left()
    return math.max(0, PalRun.RUNS - (Saved().tries or 0))
end

-- Today's course is done with: it has a time, or its runs are used up.
function PalRun.DailyDone()
    local s = ns.db.palrun
    if type(s) ~= "table" or s.day ~= Games.Today() then return false end
    return s.best ~= nil or (s.tries or 0) >= PalRun.RUNS
end

-- Today's day and best time, once there is one.
function PalRun.Result()
    local s = ns.db.palrun
    if type(s) ~= "table" or s.day ~= Games.Today() or not s.best then return nil end
    return s.day, s.best
end

-- A pal's name as the guild is told it and as the board shows it: at most
-- 16 letters, and none of the marks a message is split on or the game reads
-- as the start of a colour or a link. Nil when nothing is left of it.
function PalRun.Clean(name)
    if type(name) ~= "string" then return nil end
    name = (name:gsub("[;:|%c]", ""))
    name = (name:gsub("^%s+", ""):gsub("%s+$", ""))
    local letters = {}
    for letter in name:gmatch("[\1-\127\194-\244][\128-\191]*") do
        if #letters == 16 then break end
        letters[#letters + 1] = letter
    end
    name = table.concat(letters)
    return name ~= "" and name or nil
end

-- Your pal's name, when you have one.
function PalRun.PalName()
    local Pet, s = ns.Pet, ns.db.pet
    if Pet and Pet.running and type(s) == "table" and not s.unchosen then return PalRun.Clean(s.name) end
    return nil
end

-- What the guild is told: "day:steps:your pal's name", or nothing while the
-- part is off or today's course hasn't been run.
function PalRun.Signature()
    local day, best = PalRun.Result()
    if not (PalRun.running and day) then return "" end
    return ("%d:%d:%s"):format(day, best, PalRun.PalName() or "")
end

-- The line under the game's name on the Games page, beside its icon: a few
-- words, as it has room for no more. Today's time is on the board under it.
function PalRun.Status()
    if not PalRun.running then return "Off in Settings" end
    local s, left = Saved(), PalRun.Left()
    if left > 0 and (s.tries or 0) > 0 then return left == 1 and "1 run left" or ("%d runs left"):format(left) end
    if s.best then return "Done for today" end
    if left == 0 then return "No time today" end
    return "Ready to play"
end

-- Steps as a time, for a page that shows the board.
function PalRun.Clock(steps)
    return Rules.Clock(steps)
end

-- Your record as numbers, for the Games page's card: your fastest course
-- ever and the day it was, once there's one.
function PalRun.Numbers()
    local s = ns.db.palrun
    if type(s) ~= "table" or not s.ever then return {} end
    return { { Rules.Clock(s.ever), "fastest ever, " .. Compat.DaysAgo(Games.Today() - (s.everDay or Games.Today())) } }
end

function PalRun.Record()
    local s = ns.db.palrun
    if type(s) ~= "table" or not s.ever then return "Pal run: no course finished yet." end
    return ("Pal run: fastest ever %s, %s."):format(Rules.Clock(s.ever), Compat.DaysAgo(Games.Today() - (s.everDay or Games.Today())))
end

-- A run has started. One at the day's course is counted there and then, so
-- starting again, or leaving, doesn't give it back.
function PalRun.Started(mode)
    if mode ~= "daily" then return end
    local s = Saved()
    s.tries = (s.tries or 0) + 1
end

-- A run is over, in `steps`. Today's course: "first" for the day's first
-- time, "best" for one that beats it (and by how many steps), "slower"
-- otherwise. A practice course is only ever "practice".
function PalRun.Finished(mode, steps)
    if mode ~= "daily" then return "practice" end
    local s = Saved()
    local was = s.best
    if was and steps >= was then return "slower" end
    s.best = steps
    if not s.ever or steps < s.ever then s.ever, s.everDay = steps, s.day end
    if ns.Guild then ns.Guild.Announce() end
    if ns.Flight then ns.Flight.Refresh() end
    return was and "best" or "first", was and (was - steps) or nil
end

-- Today's times, fastest first: yours, and those of guildmates heard this
-- session. Each has whose it is, and their pal's name where they have one.
function PalRun.Board()
    local today, me, list = Games.Today(), Compat.MyName(), {}
    local day, best = PalRun.Result()
    if day then list[#list + 1] = { name = me, pal = PalRun.PalName(), steps = best, mine = true } end
    for name, m in pairs(ns.Guild and ns.Guild.Members and ns.Guild.Members() or {}) do
        if name ~= me and m.runDay == today and m.runSteps then
            list[#list + 1] = { name = name, pal = m.runPal, steps = m.runSteps }
        end
    end
    table.sort(list, function(a, b)
        if a.steps ~= b.steps then return a.steps < b.steps end
        return a.name < b.name
    end)
    return list
end

-- The pal that runs: your pal's kind in its first form, whatever it has grown
-- into, so every runner is near enough one size; a Briarboar while you have
-- none.
function PalRun.Runner()
    local Pet, PetRules, s = ns.Pet, ns.PetRules, ns.db.pet
    if Pet and Pet.running and PetRules and type(s) == "table" and not s.unchosen then
        local sprites = PetRules.Species(s).sprites
        local sprite = sprites[1]
        if Pet.SHEETS[sprite] then return sprite end
    end
    return "briarboar"
end

-- Which of the 16 ground tiles is drawn where four squares meet, from which
-- of them are ground (tools/make_run_tiles.py packs them in this order).
-- Past the course's ends and under it, the ground is as its nearest square.
local function Ground(course, col, row)
    col = math.max(0, math.min(course.cols - 1, col))
    return Rules.Solid(course, col, math.min(Rules.ROWS - 1, row))
end
function PalRun.Tile(course, col, row)
    return (Ground(course, col - 1, row - 1) and 8 or 0) + (Ground(course, col, row - 1) and 4 or 0)
        + (Ground(course, col - 1, row) and 2 or 0) + (Ground(course, col, row) and 1 or 0)
end

-- The cell of its sheet the pal shows: cheering at the flag, mid-jump in
-- the air, running, or standing. Returns the cell and what it's a cell of.
function PalRun.Cell(sheet, run, clock)
    local anim, cell
    if run.done and sheet.cheer then
        anim = sheet.cheer
        cell = anim.first + math.floor(clock / anim.time) % anim.count
    elseif not run.grounded then
        anim = sheet.jump
        cell = anim.first + math.min(anim.count - 1, run.vy < 0 and 3 or 4)
    elseif math.abs(run.vx) > 0.5 then
        anim = sheet.run or sheet.walk
        cell = anim.first + math.floor(clock / anim.time) % anim.count
    else
        return sheet.stand, sheet
    end
    return cell, anim.file and anim or sheet
end

---------------------------------------------------------------------------
-- The window.
---------------------------------------------------------------------------
local ui = {}
local mode, seed, course, run
local courseDay   -- the day the day's course in the window was laid for
local shared      -- the day and time last said in guild chat, so one time is said once
local held = {}
local behind, clock, flash, boardAge = 0, 0, 0, 0

-- A guildmate's class, for their name's colour.
local function Classes()
    local class = {}
    for i = 1, (GetNumGuildMembers and GetNumGuildMembers() or 0) do
        local full, _, _, _, _, _, _, _, _, _, file = GetGuildRosterInfo(i)
        if full then class[Ambiguate(full, "none")] = file end
    end
    return class
end

local function PaintBoard()
    local list, online = PalRun.Board(), Compat.GuildOnline()
    local class, me = Classes(), Compat.MyName()
    ui.day:SetText("new in " .. Games.Until())
    ui.empty:SetShown(#list == 0)
    for i, row in ipairs(ui.rows) do
        local entry = list[i]
        row:SetShown(entry ~= nil)
        if entry then
            local colour = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class[entry.name] or (entry.mine and select(2, UnitClass("player"))) or ""]
            -- The pal's name, in its owner's class colour; pointed at, the row says whose it is.
            row.rank:SetText(tostring(i))
            row.name:SetText(entry.pal or entry.name)
            row.owner, row.pal = entry.name, entry.pal
            if colour then row.r, row.g, row.b = colour.r, colour.g, colour.b else row.r, row.g, row.b = Style.Color("text") end
            row.name:SetTextColor(row.r, row.g, row.b)
            row.time:SetText(Rules.Clock(entry.steps))
            row.dot:SetColorTexture(Style.Color((entry.name == me or online[entry.name]) and "green" or "lineStrong"))
            row.fill:SetShown(entry.mine == true)
            row.edge:SetShown(entry.mine == true)
            row.rule:SetShown(not entry.mine)
        end
    end
    if #list > #ui.rows then
        ui.more:SetText(("and %d more"):format(#list - #ui.rows))
        ui.more:Show()
    else
        ui.more:Hide()
    end
    local s = Saved()
    ui.today:SetText(s.best and Rules.Clock(s.best) or "-")
    ui.left:SetText(tostring(PalRun.Left()))
    ui.ever:SetText(s.ever and Rules.Clock(s.ever) or "-")
end

-- The course's ground, treats and flag, laid once in a strip that slides
-- under the window as the pal runs.
local function Lay()
    local world = ui.world
    world:SetSize(course.cols * TILE, Rules.ROWS * TILE)
    ui.backdrop:SetTexture(Art("run_back_" .. course.land), "CLAMP", "CLAMP", "NEAREST")
    local land = 0
    for i, name in ipairs(Rules.LANDS) do
        if name == course.land then land = i - 1 end
    end
    local ox, oy = (land % 4) * 64, math.floor(land / 4) * 64
    local used = 0
    for row = 0, Rules.ROWS do
        for col = 0, course.cols do
            local tile = PalRun.Tile(course, col, row)
            if tile > 0 then
                used = used + 1
                local t = ui.tiles[used]
                if not t then
                    t = world:CreateTexture(nil, "ARTWORK")
                    t:SetSize(TILE, TILE)
                    t:SetTexture(Art("run"), "CLAMP", "CLAMP", "NEAREST")
                    ui.tiles[used] = t
                end
                local x, y = ox + (tile % 4) * 16, oy + math.floor(tile / 4) * 16
                t:SetTexCoord(x / 256, (x + 16) / 256, y / 256, (y + 16) / 256)
                t:ClearAllPoints()
                t:SetPoint("TOPLEFT", world, "TOPLEFT", (col - 0.5) * TILE, -(row - 0.5) * TILE)
                t:Show()
            end
        end
    end
    for i = used + 1, #ui.tiles do ui.tiles[i]:Hide() end
    for i, treat in ipairs(course.treats) do
        local t = ui.treats[i]
        if not t then
            t = world:CreateTexture(nil, "OVERLAY")
            t:SetSize(32, 32)
            t:SetTexture(Art("treat"), "CLAMP", "CLAMP", "NEAREST")
            ui.treats[i] = t
        end
        t:ClearAllPoints()
        t:SetPoint("CENTER", world, "TOPLEFT", (treat.col + 0.5) * TILE, -(treat.row + 0.5) * TILE)
        t:Show()
    end
    for i = #course.treats + 1, #ui.treats do ui.treats[i]:Hide() end
    ui.flag:ClearAllPoints()
    ui.flag:SetPoint("BOTTOM", world, "TOPLEFT", (course.flag + 0.5) * TILE, -6 * TILE)
end

-- Where everything is this frame: the strip under the pal, the pal on it,
-- the clock.
local function Paint()
    local cam = math.floor(math.max(0, math.min(course.cols * TILE - FIELD_W, run.x * TILE - FIELD_W * 0.35)))
    ui.world:SetPoint("TOPLEFT", ui.field, "TOPLEFT", -cam, -(FIELD_H - Rules.ROWS * TILE))
    -- The scenery slides from its left end to its right as the course goes by, a pixel of
    -- the screen at a time.
    local span = course.cols * TILE - FIELD_W
    local slide = span > 0 and math.floor((BACK_W - BACK_SHOWN) * cam / span * 4 + 0.5) / 4 or 0
    ui.backdrop:SetTexCoord(slide / BACK_W, (slide + BACK_SHOWN) / BACK_W, 0, BACK_H / 128)

    local sprite = ui.runner
    local sheet = ns.Pet.SHEETS[sprite]
    local cell, from = PalRun.Cell(sheet, run, clock)
    local cols = from.cols or math.floor(from.w / from.cell)
    local col, row = cell % cols, math.floor(cell / cols)
    local left, right = col * from.cell / from.w, (col + 1) * from.cell / from.w
    -- The pictures face left.
    if run.facing > 0 then left, right = right, left end
    ui.pal:SetTexCoord(left, right, row * from.cell / from.h, (row + 1) * from.cell / from.h)
    local file = Art(from.file)
    if ui.pal.file ~= file then
        ui.pal.file = file
        ui.pal:SetTexture(file, "CLAMP", "CLAMP", "NEAREST")
    end
    -- Its picture is centred on the 64 pixels it stands in, whose feet line
    -- sits on the bottom of the pal's box; across, its feet are over the box's middle.
    local size = from.cell * SCALE
    local middle = (run.y + Rules.H) * TILE - (FEET[sprite] or 57) * SCALE + 32 * SCALE
    local feetx = FEETX[sprite] and FEETX[sprite][(from == sheet and cell == sheet.stand) and 1 or 2] or 0
    local across = (run.x + Rules.W / 2) * TILE + (run.facing > 0 and feetx or -feetx) * SCALE
    ui.pal:SetSize(size, size)
    ui.pal:SetPoint("CENTER", ui.world, "TOPLEFT", math.floor(across), -math.floor(middle))

    -- A heart for each fall the run has left; one that's gone is greyed, from the right.
    if ui.fallen ~= run.falls then
        ui.fallen = run.falls
        for i, heart in ipairs(ui.hearts) do
            local gone = i > Rules.FALLS - run.falls
            heart:SetDesaturated(gone)
            heart:SetAlpha(gone and 0.4 or 1)
        end
    end

    ui.clock:SetText(run.started and Rules.Clock(Rules.Ticks(run)) or "0:00.00")
    if flash > 0 then
        ui.clock:SetTextColor(Style.Color("green"))
        ui.bonus:SetAlpha(math.min(1, flash * 2))
    else
        ui.clock:SetTextColor(Style.Color("text"))
        ui.bonus:SetAlpha(0)
    end
end

-- How many runs at the day's course are left, as the card says it.
local function LeftLine()
    if mode ~= "daily" then return "Practice runs aren't counted." end
    local left = PalRun.Left()
    if left == 0 then return "No runs left today." end
    return left == 1 and "1 run left today." or (left .. " runs left today.")
end

local function ShowCard(title, sub, detail)
    local over = run.done == true or run.failed == true
    -- The day's course with its runs used up: nothing more to run today.
    local spent = mode == "daily" and PalRun.Left() == 0
    ui.card:Show()
    ui.cardTitle:SetText(title)
    ui.cardSub:SetText(sub)
    ui.cardDetail:SetText(detail or "")
    ui.again:SetLabel(mode == "daily" and "Retry" or "Run again")
    ui.share:SetLabel(mode == "daily" and "Share to guild" or "New course")
    local day, best = PalRun.Result()
    ui.share:SetEnabled(mode ~= "daily" or (best ~= nil and shared ~= day .. ":" .. best))
    ui.other:SetLabel(mode == "daily" and "Practice course" or "Today's course")
    -- The buttons there are stand in a row, centred.
    local row = {}
    for _, entry in ipairs({ { ui.again, over and not spent }, { ui.share, over or spent }, { ui.other, true } }) do
        entry[1]:SetShown(entry[2])
        if entry[2] then row[#row + 1] = entry[1] end
    end
    local left = -(#row * 134 + (#row - 1) * 12) / 2
    for i, button in ipairs(row) do
        button:ClearAllPoints()
        button:SetPoint("BOTTOMLEFT", ui.card, "BOTTOM", left + (i - 1) * 146, 16)
    end
end

-- A fresh run on the course there is, or on a new one: today's, or a
-- practice course from `newSeed`.
-- The day's course in the window was laid before the daily reset: it's yesterday's.
local function Stale()
    return mode == "daily" and courseDay ~= Games.Today()
end

local function Begin(newMode, newSeed)
    -- A fresh run at the day's course is always at today's.
    if not newMode and Stale() then newMode = "daily" end
    if newMode then
        mode = newMode
        courseDay = Games.Today()
        seed = mode == "daily" and (Games.Today() * 7919 + 211) or newSeed
        course = Rules.Course(Games.Random(seed), mode ~= "daily" and Rules.PRACTICE or nil)
        Lay()
    end
    run = Rules.New(course)
    behind, clock, flash = 0, 0, 0
    for i in ipairs(course.treats) do ui.treats[i]:Show() end
    ui.runner = PalRun.Runner()
    if mode == "daily" and PalRun.Left() == 0 then
        -- Its runs are used up: the course is shown, and stays still.
        run.locked = true
        local _, best = PalRun.Result()
        ShowCard(best and ("Today's best   " .. Rules.Clock(best)) or "No time today",
            "No runs left today. A new course comes with the daily reset.", "Practice courses are never counted.")
    else
        ShowCard(mode == "daily" and "Today's course" or "Practice course",
            "The clock starts when you move. Each treat takes half a second off.",
            ("%d falls end a run.   %s"):format(Rules.FALLS, LeftLine()))
    end
    Paint()
    PaintBoard()
end

local function Finish()
    local steps = Rules.Ticks(run)
    -- A run the daily reset overtook was on yesterday's course: it isn't today's time.
    local how, by = "stale", nil
    if not Stale() then how, by = PalRun.Finished(mode, steps) end
    local sub
    if how == "stale" then
        sub = "The daily reset came during that run: it isn't kept."
    elseif how == "first" then
        sub = PalRun.Left() > 0 and "Your first time today. Retry to beat it." or "Your time for today."
    elseif how == "best" then
        sub = ("A new best today, by %s."):format(Rules.Clock(by))
    elseif how == "slower" then
        sub = ("Your best today is still %s."):format(Rules.Clock(Saved().best))
    else
        sub = "A practice course: it isn't kept."
    end
    ShowCard(Rules.Clock(steps), sub, ("%d of %d treats   ·   %s   ·   %s"):format(run.got, #course.treats,
        run.falls == 0 and "no falls" or (run.falls == 1 and "1 fall" or (run.falls .. " falls")), LeftLine()))
    PaintBoard()
    ns.Window.Refresh()
end

-- The last fall a run is allowed: it's over, with no time.
local function Fail()
    ShowCard(("%d falls"):format(Rules.FALLS), "That run is over, with no time.", LeftLine())
    PaintBoard()
    ns.Window.Refresh()
end

local function Tick(_, elapsed)
    -- A long pause between frames isn't made up for: the pal doesn't leap ahead.
    behind = math.min(behind + elapsed, 0.25)
    clock = clock + elapsed
    flash = math.max(0, flash - elapsed)
    while behind >= Rules.STEP do
        behind = behind - Rules.STEP
        if run.done or run.failed or run.locked then break end
        local started = run.started
        Rules.Step(run, held.left, held.right, held.jump)
        if run.started and not started then
            ui.card:Hide()
            if not Stale() then PalRun.Started(mode) end
            PaintBoard()
        end
        if run.fresh then
            ui.treats[run.fresh]:Hide()
            run.fresh = nil
            flash = 0.6
        end
        if run.done then
            clock = 0
            Finish()
        elseif run.failed then
            Fail()
        end
    end
    Paint()
    boardAge = boardAge + elapsed
    if boardAge > 2 then
        boardAge = 0
        -- Left open over the daily reset with no run under way: today's course takes its place.
        if Stale() and not run.started then Begin("daily") end
        PaintBoard()
    end
end

-- The keys the game takes while its window is open; every other key goes
-- on to the game as usual.
local KEYS = { A = "left", LEFT = "left", D = "right", RIGHT = "right", SPACE = "jump", W = "jump", UP = "jump" }
local function Key(self, key, down)
    local what = KEYS[key]
    -- The game won't have this changed in a fight, when the window shuts anyway.
    if not Compat.InCombat() then self:SetPropagateKeyboardInput(not (what or key == "R" or key == "ESCAPE")) end
    if what then
        held[what] = down
    elseif down and key == "R" then
        -- On the day's last run, R would throw it away: it's left running.
        local live = run.started and not (run.done or run.failed)
        if not (mode == "daily" and live and PalRun.Left() == 0) then Begin() end
    elseif down and key == "ESCAPE" then
        ui.frame:Hide()
    end
end

-- The run in the window: where the pal is and how it's going.
function PalRun.Now() return run end

local function ShareLine()
    local name = PalRun.PalName()
    return ("Pal run: %s%s"):format(name and (name .. ", ") or "", Rules.Clock(Saved().best or 0))
end
PalRun.ShareLine = ShareLine

local function Build()
    local frame = Style.Panel("jsalUIPalRun", PAD * 3 + FIELD_W + BOARD_W, 32 + PAD * 2 + FIELD_H, "Pal run")
    ui.frame = frame
    frame:EnableKeyboard(true)
    frame:SetScript("OnKeyDown", function(self, key) Key(self, key, true) end)
    frame:SetScript("OnKeyUp", function(self, key) Key(self, key, false) end)
    frame:SetScript("OnUpdate", ns.Safe(PalRun, Tick))
    frame:SetScript("OnHide", function() held = {} end)

    local field = CreateFrame("Frame", nil, frame)
    ui.field = field
    field:SetSize(FIELD_W, FIELD_H)
    field:SetPoint("TOPLEFT", PAD, -(32 + PAD))
    field:SetClipsChildren(true)
    -- The country's scenery, behind everything.
    ui.backdrop = field:CreateTexture(nil, "BACKGROUND")
    ui.backdrop:SetAllPoints()
    ui.backdrop:SetTexCoord(0, BACK_SHOWN / BACK_W, 0, BACK_H / 128)
    local edge = CreateFrame("Frame", nil, frame)
    edge:SetAllPoints(field)
    edge:SetFrameLevel(field:GetFrameLevel() + 5)
    Style.Border(edge, "lineStrong")

    ui.world = CreateFrame("Frame", nil, field)
    ui.tiles, ui.treats = {}, {}
    ui.flag = ui.world:CreateTexture(nil, "ARTWORK", nil, 2)
    ui.flag:SetSize(FLAG_W * 3, FLAG_H * 3)
    ui.flag:SetTexture(Art("run"), "CLAMP", "CLAMP", "NEAREST")
    -- The flag stands on the bottom edge of the cell after the last country's, centred.
    local fx, fy = 64 + (64 - FLAG_W) / 2, 128 + 64 - FLAG_H
    ui.flag:SetTexCoord(fx / 256, (fx + FLAG_W) / 256, fy / 256, (fy + FLAG_H) / 256)
    ui.pal = ui.world:CreateTexture(nil, "OVERLAY", nil, 2)

    local hud = CreateFrame("Frame", nil, field)
    hud:SetAllPoints()
    hud:SetFrameLevel(field:GetFrameLevel() + 3)
    ui.clock = Style.Text(hud, 30, "text", nil, true)
    ui.clock:SetPoint("TOP", 0, -14)
    ui.clock:SetShadowColor(0.08, 0.06, 0.1, 1)
    ui.clock:SetShadowOffset(2, -2)
    ui.bonus = Style.Text(hud, 15, "green", nil, true)
    ui.bonus:SetPoint("LEFT", ui.clock, "RIGHT", 10, 0)
    ui.bonus:SetShadowColor(0.08, 0.06, 0.1, 1)
    ui.bonus:SetShadowOffset(1, -1)
    ui.bonus:SetText("-0.50")
    -- The falls a run has left, in the corner: the pals' heart, twice its size.
    ui.hearts = {}
    for i = 1, Rules.FALLS do
        local heart = hud:CreateTexture(nil, "ARTWORK")
        heart:SetSize(32, 32)
        heart:SetPoint("TOPLEFT", 14 + (i - 1) * 38, -14)
        heart:SetTexture(Art("heart"), "CLAMP", "CLAMP", "NEAREST")
        ui.hearts[i] = heart
    end

    -- The card over the course: how to play before a run, and how it went after.
    local card = CreateFrame("Frame", nil, hud)
    ui.card = card
    card:SetSize(460, 176)
    card:SetPoint("CENTER", 0, 10)
    card:SetFrameLevel(hud:GetFrameLevel() + 2)
    Style.Fill(card, "titleBar"):SetAlpha(0.92)
    Style.Border(card, "lineStrong")
    ui.cardTitle = Style.Text(card, 24, "text", nil, true)
    ui.cardTitle:SetPoint("TOP", 0, -22)
    ui.cardSub = Style.Text(card, 13, "secondary")
    ui.cardSub:SetPoint("TOP", ui.cardTitle, "BOTTOM", 0, -10)
    ui.cardDetail = Style.Text(card, 12, "muted")
    ui.cardDetail:SetPoint("TOP", ui.cardSub, "BOTTOM", 0, -6)
    ui.again = Style.Button(card, "Run again", "primary", 134)
    ui.again:SetPoint("BOTTOMRIGHT", card, "BOTTOM", -73, 16)
    ui.again:SetScript("OnClick", function() Begin() end)
    ui.share = Style.Button(card, "Share to guild", "plain", 134)
    ui.share:SetPoint("BOTTOM", card, "BOTTOM", 0, 16)
    ui.share:SetScript("OnClick", function()
        if mode ~= "daily" then return Begin("practice", math.random(1, 2000000000)) end
        if not IsInGuild() then return ns.Print("Join a guild to share.") end
        Compat.SendChat(ShareLine(), "GUILD")
        local day, best = PalRun.Result()
        shared = day .. ":" .. best
        ui.share:SetEnabled(false)
    end)
    ui.other = Style.Button(card, "Practice course", "plain", 134)
    ui.other:SetScript("OnClick", function()
        if mode == "daily" then Begin("practice", math.random(1, 2000000000)) else Begin("daily") end
    end)

    -- Beside the course: today's times in the guild, then your own.
    local x = PAD * 2 + FIELD_W
    local head = Style.Section(frame, BOARD_W)
    head:SetPoint("TOPLEFT", x, -(32 + PAD))
    head.title:SetText("TODAY IN THE GUILD")
    ui.day = head.note
    ui.rows = {}
    for i = 1, ROWS_SHOWN do
        local row = CreateFrame("Frame", nil, frame)
        row:SetSize(BOARD_W, ROW_H)
        row:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -(6 + (i - 1) * ROW_H))
        row.fill = Style.Fill(row, "well")
        row.edge = row:CreateTexture(nil, "BORDER")
        row.edge:SetColorTexture(Style.Color("gold"))
        row.edge:SetPoint("TOPLEFT")
        row.edge:SetPoint("BOTTOMLEFT")
        row.edge:SetWidth(2)
        row.rule = Style.Rule(row, "BOTTOM", "line")
        row.rank = Style.Text(row, 13, "muted")
        row.rank:SetPoint("LEFT", 12, 0)
        row.dot = row:CreateTexture(nil, "ARTWORK")
        row.dot:SetSize(6, 6)
        row.dot:SetPoint("LEFT", 30, 0)
        row.time = Style.Text(row, 14, "text", nil, true)
        row.time:SetPoint("RIGHT", -10, 0)
        row.name = Style.Text(row, 13, "text", nil, true)
        row.name:SetPoint("LEFT", 44, 0)
        row.name:SetPoint("RIGHT", row.time, "LEFT", -8, 0)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)
        row:EnableMouse(true)
        row:SetScript("OnEnter", function(self)
            if not self.owner then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if self.pal then
                GameTooltip:SetText(self.pal)
                GameTooltip:AddLine(self.owner .. "'s pal", self.r, self.g, self.b)
            else
                GameTooltip:SetText(self.owner, self.r, self.g, self.b)
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        -- The light under the pointer adds itself to the two scripts above, so it comes after them.
        Style.Hover(row)
        ui.rows[i] = row
    end
    ui.empty = Style.Text(frame, 12, "muted")
    ui.empty:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -12)
    ui.empty:SetWidth(BOARD_W)
    ui.empty:SetJustifyH("LEFT")
    ui.empty:SetText("No times yet today. Yours could be the first.")
    ui.more = Style.Text(frame, 12, "muted")
    ui.more:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -(10 + ROWS_SHOWN * ROW_H))

    local mine = Style.Section(frame, BOARD_W)
    mine:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -(40 + ROWS_SHOWN * ROW_H))
    mine.title:SetText("YOUR BEST")
    for i, label in ipairs({ "Today", "Fastest ever", "Runs left today" }) do
        local name = Style.Text(frame, 13, "secondary")
        name:SetPoint("TOPLEFT", mine, "BOTTOMLEFT", 0, -(10 + (i - 1) * 26))
        name:SetText(label)
        local value = Style.Text(frame, 14, "text", nil, true)
        value:SetPoint("TOPRIGHT", mine, "BOTTOMRIGHT", -10, -(9 + (i - 1) * 26))
        ui[({ "today", "ever", "left" })[i]] = value
    end
    local hint = Style.Text(frame, 12, "muted")
    hint:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", x, PAD)
    hint:SetWidth(BOARD_W)
    hint:SetJustifyH("LEFT")
    hint:SetSpacing(4)
    hint:SetText("A and D to run, Space to jump.\nR starts again, and uses a run.")
end

local function Start(newMode)
    if not PalRun.running then
        return ns.Print("Pal run is turned off. /jsal settings turns it on.")
    end
    if Compat.InCombat() then
        return ns.Print("Pal run opens once combat ends.")
    end
    if not ui.frame then Build() end
    Begin(newMode, math.random(1, 2000000000))
    ui.frame:Show()
end

function PalRun.Open() Start("daily") end
function PalRun.Practice() Start("practice") end

function PalRun:OnEnable()
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:SetScript("OnEvent", ns.Safe(self, function()
        if ui.frame then ui.frame:Hide() end
    end))
end

ns.Command("run", function() PalRun.Open() end)

-- For trying it out while it's being made, in a beta build only (one whose
-- version says so; a release has no such command): /jsal run reset wipes
-- today's runs and today's time, as if the day were new.
if ns.IsBeta(ns.version) then
    ns.Command("run reset", function()
        local s = Saved()
        s.best, s.tries = nil, 0
        ns.Print("Pal run: today's time is gone and its three runs are back.")
        if ui.frame and ui.frame:IsShown() then Begin("daily") end
    end)
end
