-- Pal run's rules, with no drawing in them: how a course is laid out, and how
-- the pal moves over it. Everything is measured in tiles, a tile being one
-- block of ground, and worked out in steps of a sixtieth of a second, so a
-- run comes out the same at any frame rate.
local _, ns = ...

local Rules = {}
ns.PalRunRules = Rules

Rules.ROWS = 8            -- rows of tiles in a course, counted down from 0 at the top
Rules.STEP = 1 / 60       -- seconds in one step
-- The pal's box, in tiles: the same for every kind, so none has the easier run. It's as wide as
-- a pal's feet (John, 19 Nov 2026, of his pal standing with its body over a gap: "how precise
-- can you make the hitboxes?", then "A, one narrower box"): it was 1.2, and a pal stood on the
-- last fifth of a tile with its feet drawn over the pit. Every piece is proven passable with it.
Rules.W, Rules.H = 0.6, 1.6
Rules.TREAT = 30          -- steps a treat takes off your time (half a second)
Rules.FALLS = 3           -- falls into a pit that end a run

local ROWS, W, H = Rules.ROWS, Rules.W, Rules.H
local RUN = 7             -- tiles a second at a run
local ACCEL, AIR = 70, 40 -- how fast it gets up to speed: on the ground, in the air
local STOP = 90           -- how fast it stops on the ground once you let go
local GRAVITY = 60
local JUMP = 20.2         -- the speed it leaves the ground at: a held jump is about 3.2 tiles high
local CUT = 0.45          -- letting go of jump on the way up keeps this much of its speed
local FALL = 24           -- the fastest it falls
local COYOTE = 6          -- steps after running off an edge in which a jump still counts
local BUFFER = 6          -- steps before landing in which a jump pressed early still counts
local GROUND = 6          -- the row every piece's ground is at where it joins the next

-- The pieces a course is made of, drawn as they stand: # is ground, o a
-- treat. Each starts and ends on two tiles of ground at the same height, so
-- any two join, and each can be got through from a standing start. They come
-- in three lots by how hard they are. The easy ones can be run by jumping
-- at each edge and wall; the treats are off that road, and worth the detour
-- or not.
local EASY = {
    { "              ", "              ", "              ", "       o      ", "              ", "              ",
      "#####   ######", "#####   ######" },
    { "                  ", "                  ", "                  ", "    o        o    ", "                  ", "                  ",
      "###  ###  ###  ###", "###  ###  ###  ###" },
    { "                ", "                ", "           o    ", "         ###    ", "      ######    ", "   #########    ",
      "################", "################" },
    { "              ", "              ", "       o      ", "              ", "      ##      ", "      ##      ",
      "##############", "##############" },
    { "               ", "       o       ", "               ", "      ##       ", "      ##       ", "      ##       ",
      "###############", "###############" },
    { "                 ", "                 ", "      o    o     ", "                 ", "   ####  ####    ", "   ####  ####    ",
      "#######  ########", "#######  ########" },
    { "                  ", "                  ", "     o o o        ", "    #####         ", "                  ", "                  ",
      "############  ####", "############  ####" },
    { "                 ", "                 ", "                 ", "     o     o     ", "                 ", "                 ",
      "####   ###   ####", "####   ###   ####" },
    { "               ", "               ", "      oo       ", "               ", "     ####      ", "   ########    ",
      "###############", "###############" },
    { "                ", "                ", "       oo       ", "                ", "       ##       ", "       ##       ",
      "#####  ##  #####", "#####  ##  #####" },
    { "                  ", "       o          ", "                  ", "    ##    ##      ", "    ##    ##      ", "    ##    ##      ",
      "##################", "##################" },
    { "                      ", "                      ", "                      ", "       o      o       ", "                      ",
      "                      ", "######   ####   ######", "######   ####   ######" },
    { "                   ", "                   ", "                   ", "    o    o     o   ", "                   ",
      "   ##   ###   ##   ", "###################", "###################" },
    { "                  ", "          o       ", "                  ", "         ###      ", "                  ", "    ###           ",
      "########  ########", "########  ########" },
}
-- Wider gaps, pillars a tile wide and climbs over pits: a jump has to be
-- judged, not only made.
local MEDIUM = {
    {
      "              ",
      "              ",
      "              ",
      "      oo      ",
      "              ",
      "              ",
      "#####    #####",
      "#####    #####",
    },
    {
      "                ",
      "                ",
      "                ",
      "      o  o      ",
      "                ",
      "                ",
      "####  #  #  ####",
      "####  #  #  ####",
    },
    {
      "                   ",
      "             o     ",
      "                   ",
      "             ##    ",
      "         ##  ##    ",
      "     ##  ##  ##    ",
      "###  ##  ##  ##  ##",
      "###  ##  ##  ##  ##",
    },
    {
      "                ",
      "      o         ",
      "                ",
      "    ##          ",
      "    ##          ",
      "    ##          ",
      "######    ######",
      "######    ######",
    },
    {
      "                    ",
      "            o       ",
      "                    ",
      "         ##         ",
      "         ##         ",
      "     ##  ##         ",
      "###  ##  ##   ######",
      "###  ##  ##   ######",
    },
    {
      "                    ",
      "                    ",
      "          oo        ",
      "                    ",
      "          ##        ",
      "      ##     ##     ",
      "####            ####",
      "####            ####",
    },
    {
      "                ",
      "                ",
      "       o        ",
      "                ",
      "    ##   ##     ",
      "    ##   ##     ",
      "######   #######",
      "######   #######",
    },
}
-- The widest gaps and the smallest landings.
local HARD = {
    {
      "               ",
      "               ",
      "      ooo      ",
      "               ",
      "               ",
      "               ",
      "#####     #####",
      "#####     #####",
    },
    {
      "                   ",
      "                   ",
      "                   ",
      "       o   o       ",
      "                   ",
      "                   ",
      "####   #   #   ####",
      "####   #   #   ####",
    },
    -- Up a wall, over a wide pit to a tower a tile wide, and down over another.
    {
      "                     ",
      "             o       ",
      "          #          ",
      "    ##    #          ",
      "    ##    #          ",
      "    ##    #          ",
      "######    #    ######",
      "######    #    ######",
    },
    {
      "                  ",
      "           o      ",
      "                  ",
      "           #      ",
      "        #  #      ",
      "     #  #  #      ",
      "###  #  #  #   ###",
      "###  #  #  #   ###",
    },
    {
      "                 ",
      "                 ",
      "         oo      ",
      "                 ",
      "         ##      ",
      "         ##      ",
      "#####    ########",
      "#####    ########",
    },
    {
      "                      ",
      "                      ",
      "         o     o      ",
      "                      ",
      "         #     #      ",
      "      #     #         ",
      "####              ####",
      "####              ####",
    },
    -- A gap under a low roof: a full jump hits it and drops short.
    {
      "             ",
      "             ",
      "   #######   ",
      "             ",
      "             ",
      "      o      ",
      "#####   #####",
      "#####   #####",
    },
    -- A lone pillar two tiles high, four tiles off and three from the far side.
    {
      "               ",
      "               ",
      "       o       ",
      "               ",
      "       #       ",
      "       #       ",
      "###    #   ####",
      "###    #   ####",
    },
    -- A gap of five up onto a ledge.
    {
      "                ",
      "                ",
      "       oo       ",
      "                ",
      "                ",
      "          ###   ",
      "#####     ######",
      "#####     ######",
    },
    -- Three single tiles rising over a pit, and a long drop from the last.
    {
      "                     ",
      "           o         ",
      "                     ",
      "           #         ",
      "        #            ",
      "     #               ",
      "###              ####",
      "###              ####",
    },
    -- Two gaps under one low roof.
    {
      "                   ",
      "                   ",
      "   #############   ",
      "                   ",
      "                   ",
      "      o     o      ",
      "#####   ###   #####",
      "#####   ###   #####",
    },
    -- A lone tile with a gap of five before it and four after.
    {
      "                  ",
      "                  ",
      "                  ",
      "         o        ",
      "                  ",
      "                  ",
      "####     #    ####",
      "####     #    ####",
    },
    -- Over a wall and down two single tiles hung over a long pit.
    {
      "                      ",
      "        o             ",
      "                      ",
      "   ##                 ",
      "   ##   #             ",
      "   ##       #         ",
      "#####             ####",
      "#####             ####",
    },
    -- Two towers a tile wide over pits, each two tiles higher.
    {
      "                   ",
      "              o    ",
      "           #       ",
      "           #       ",
      "      #    #       ",
      "      #    #       ",
      "###   #    #    ###",
      "###   #    #    ###",
    },
}
local PIECES = { EASY, MEDIUM, HARD }
Rules.PIECES = PIECES
local FLAT = { "        ", "        ", "        ", "        ", "        ", "        ", "########", "########" }
-- How many of each lot a course has, in the order it meets them. The day's
-- course is hard pieces only; a practice course starts easy and ends hard.
Rules.MIX = { 0, 0, 8 }
Rules.PRACTICE = { 2, 3, 4 }
Rules.LANDS = { "meadow", "snow", "desert", "swamp", "coast", "darkwood", "savanna", "volcanic", "jungle" }

-- A course of these pieces, one after another between a flat start and a
-- flat end: its solid tiles by row and column, its treats, the column each
-- piece starts at (where a fall puts the pal back), the column the flag
-- stands at, and the country it's drawn in.
function Rules.Lay(pieces, land)
    local list = { FLAT }
    for _, piece in ipairs(pieces) do list[#list + 1] = piece end
    list[#list + 1] = FLAT
    local course = { solid = {}, treats = {}, starts = {}, land = land }
    for row = 0, ROWS - 1 do course.solid[row] = {} end
    local at = 0
    for _, piece in ipairs(list) do
        course.starts[#course.starts + 1] = at
        local wide = #piece[1]
        for row = 0, ROWS - 1 do
            local line = piece[row + 1]
            for col = 0, wide - 1 do
                local c = line:sub(col + 1, col + 1)
                if c == "#" then
                    course.solid[row][at + col] = true
                elseif c == "o" then
                    course.treats[#course.treats + 1] = { col = at + col, row = row }
                end
            end
        end
        at = at + wide
    end
    course.cols = at
    course.flag = at - 3
    return course
end

-- A course from `random` (random(n) gives 1 to n): the same numbers give
-- the same course. `mix` is how many pieces of each lot it has (the day's,
-- unless told).
function Rules.Course(random, mix)
    mix = mix or Rules.MIX
    local pieces = {}
    for level, lot in ipairs(PIECES) do
        local order = {}
        for i = 1, #lot do order[i] = i end
        for i = #order, 2, -1 do
            local j = random(i)
            order[i], order[j] = order[j], order[i]
        end
        for i = 1, math.min(mix[level], #order) do pieces[#pieces + 1] = lot[order[i]] end
    end
    return Rules.Lay(pieces, Rules.LANDS[random(#Rules.LANDS)])
end

local function Solid(course, col, row)
    local line = course.solid[row]
    return line ~= nil and line[col] == true
end
Rules.Solid = Solid

-- A run on a course: where the pal is (its top left corner), how fast it's
-- going, and what it has done so far. The clock starts with the first key.
function Rules.New(course)
    return { course = course, x = 2, y = GROUND - H, vx = 0, vy = 0, grounded = true, facing = 1,
             steps = 0, got = 0, falls = 0, taken = {}, safe = 0, coyote = 0, buffer = 0 }
end

local function Toward(value, target, by)
    if value < target then return math.min(target, value + by) end
    return math.max(target, value - by)
end

-- Whether the pal's box, with its corner at x, y, is in any solid tile.
local function Blocked(course, x, y)
    for row = math.floor(y), math.floor(y + H - 0.0001) do
        for col = math.floor(x), math.floor(x + W - 0.0001) do
            if Solid(course, col, row) then return true end
        end
    end
    return false
end

-- One step of a run, with the keys as they're held: left, right, jump.
function Rules.Step(run, left, right, jump)
    if run.done or run.failed then return run end
    local course, dt = run.course, Rules.STEP
    if not run.started then
        if not (left or right or jump) then return run end
        run.started = true
    end
    run.steps = run.steps + 1

    local want = (right and 1 or 0) - (left and 1 or 0)
    if want ~= 0 then
        run.vx = Toward(run.vx, want * RUN, (run.grounded and ACCEL or AIR) * dt)
        run.facing = want
    elseif run.grounded then
        run.vx = Toward(run.vx, 0, STOP * dt)
    end

    -- A jump counts if it was pressed a moment before landing, or a moment
    -- after running off an edge.
    if jump and not run.held then run.buffer = BUFFER end
    run.held = jump
    run.coyote = run.grounded and COYOTE or math.max(0, run.coyote - 1)
    if run.buffer > 0 and run.coyote > 0 then
        run.vy, run.buffer, run.coyote, run.rising = -JUMP, 0, 0, true
    end
    run.buffer = math.max(0, run.buffer - 1)
    if run.rising and not jump and run.vy < 0 then run.vy = run.vy * CUT end
    if not jump or run.vy >= 0 then run.rising = false end
    run.vy = math.min(FALL, run.vy + GRAVITY * dt)

    -- Sideways first, stopping at a wall; then up or down, landing on ground
    -- or bumping its head.
    local x = math.max(0, run.x + run.vx * dt)
    if Blocked(course, x, run.y) then
        x = run.vx > 0 and (math.floor(x + W) - W) or (math.floor(x) + 1)
        run.vx = 0
    end
    run.x = x
    local y = run.y + run.vy * dt
    run.grounded = false
    if Blocked(course, run.x, y) then
        if run.vy > 0 then
            y = math.floor(y + H) - H
            run.grounded = true
        else
            y = math.floor(y) + 1
        end
        run.vy = 0
    end
    run.y = y

    -- Standing somewhere, it's safe as far as the start of that piece.
    if run.grounded then
        for _, col in ipairs(course.starts) do
            if col <= run.x then run.safe = col end
        end
    end
    -- Down a pit: back to the start of the piece, the clock still running. The
    -- last fall it's allowed ends the run where it fell.
    if run.y > ROWS + 2 then
        run.falls = run.falls + 1
        if run.falls >= Rules.FALLS then
            run.failed = true
            return run
        end
        run.x, run.y, run.vx, run.vy, run.grounded = run.safe + 0.5, GROUND - H, 0, 0, true
    end
    for i, treat in ipairs(course.treats) do
        if not run.taken[i] and run.x < treat.col + 0.85 and run.x + W > treat.col + 0.15
            and run.y < treat.row + 0.85 and run.y + H > treat.row + 0.15 then
            run.taken[i] = true
            run.got = run.got + 1
            run.fresh = i
        end
    end
    if run.x + W / 2 >= course.flag + 0.5 then run.done = true end
    return run
end

-- A run's time in steps: the clock, less half a second a treat.
function Rules.Ticks(run)
    return math.max(1, run.steps - run.got * Rules.TREAT)
end

-- Steps as a time: "0:41.20".
function Rules.Clock(ticks)
    local hundredths = math.floor(ticks * 100 / 60 + 0.5)
    return ("%d:%02d.%02d"):format(math.floor(hundredths / 6000), math.floor(hundredths / 100) % 60, hundredths % 100)
end
