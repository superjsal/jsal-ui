-- Pretend to be level 60, in a beta only (a version that says "beta"; a release has no such
-- command): /jsal pretend 60 and /jsal pretend off. While it's on, the pages that show what's
-- built for level 60 (Endgame, Home's top card, the Journal's Summary and Characters tabs) draw made-up answers
-- in the game's own fonts and layout: this character at 60 with 9 of 16 slots of its set, two
-- made-up alts with raids saved and cooldowns ready and running, some raid consumables held.
--
-- This is the one place those pages ask: their level, the characters, what's in the bags for raid
-- night, where the set stands, raid night's own choices, and whether the shopping list may be
-- changed. Off, each answer is the game's or the saved one, unchanged. On, nothing is saved:
-- the made-up answers are kept in memory, raid night's choices too, the shopping list is left
-- alone, and none of it goes to the guild (nothing here is ever sent). It's off again after a
-- /reload, and the dashboard's title bar says "pretend 60" while it's on.
--
-- /jsal pretend horde (or alliance) makes Compat.Faction give the pages that side: the dungeon
-- guide's order, the gear plan's sets, recipe labels and the profession road, the nearest trainer.
-- What is kept or sent asks the game (Compat.Faction(true)): the flight bar's times and what it
-- shares or hears. The profession road's passed steps and step in hand, and the shopping list, are
-- kept in memory while it's on. It goes with pretend 60, and /jsal pretend off or a /reload ends both.
--
-- /jsal pretend skill <profession> <skill> ("cooking 190", or the skill line's number, "185 190")
-- makes Professions.Mine give that one profession at that skill, its rank's cap the next above it,
-- knowing what its trainers teach up to there and nothing else; what's in your bags is your own. The
-- Professions page, the road and the shopping list draw from it; what's kept (the Journal's
-- characters and ranks, crafting profit's recipes, rank reminders) asks the game's list, and the
-- road's steps and the shopping list are kept in memory as for a side. Off as the others are.
local _, ns = ...
local Compat = ns.Compat

-- on: pretending to be level 60. faction: the side pretended ("Horde" or "Alliance"), else nil.
-- skill: the profession pretended, { line, skill, cap }, else nil.
local Pretend = { on = false, faction = nil, skill = nil }
ns.Pretend = Pretend

local LEVEL = 60
-- What's in the bags while pretending: a night's flasks and Greater Mageblood, four of a night's
-- steaks, a stack of Major Mana Potions.
local HELD = { [274274] = 2, [250341] = 6, [250072] = 4, [13444] = 5 }
-- Three pre-raid pieces for the made-up next run when your set gives none: a back, a neck and a ring.
local FALLBACK = { { 13340, "Back" }, { 15411, "Neck" }, { 18500, "Finger 1" } }
-- The slots of a set, in its order, for the made-up next run's pieces.
local SLOTS = { "Head", "Neck", "Shoulder", "Back", "Chest", "Wrist", "Hands", "Waist", "Legs", "Feet", "Finger 1", "Finger 2",
                "Trinket 1", "Trinket 2", "Main hand", "Off hand", "Ranged" }

-- This character's level.
function Pretend.Level()
    if Pretend.on then return LEVEL end
    return UnitLevel("player") or 1
end

-- How many of an item you have, in your bags (and bank).
function Pretend.ItemCount(item, bank)
    if Pretend.on then return HELD[item] or 0 end
    return Compat.ItemCount(item, bank)
end

local made

-- The pretended characters, made once until pretend is turned off.
local function MakeCharacters(J, me)
    local now = Compat.ServerTime()
    made = {}
    for name, c in pairs(J and J.Characters() or {}) do
        local copy = {}
        for k, v in pairs(c) do copy[k] = v end
        copy.lockouts, copy.cooldowns = nil, nil
        made[name] = copy
    end
    local _, classFile = UnitClass("player")
    local mine = made[me] or { name = me, class = UnitClass("player"), classFile = classFile, updated = now }
    mine.level = LEVEL
    mine.lockouts = { { "Molten Core", now + 2 * 86400 + 15 * 3600, 4, 10 } }
    mine.cooldowns = { ["Salt Shaker"] = now + 14 * 3600 }
    made[me] = mine
    made.Corwen = { name = "Corwen", class = "Mage", classFile = "MAGE", level = LEVEL, zone = "Undercity", money = 882000,
                    professions = { { name = "Alchemy", skill = 300, cap = 300 }, { name = "Herbalism", skill = 300, cap = 300 } },
                    rep = { id = 529, name = "Argent Dawn", reaction = 6, have = 4200, need = 12000 },
                    cooldowns = { ["Transmute"] = now + 33 * 3600 }, updated = now - 86400 }
    made.Liesl = { name = "Liesl", class = "Priest", classFile = "PRIEST", level = LEVEL, zone = "Blackrock Mountain", money = 412000,
                   professions = { { name = "Tailoring", skill = 300, cap = 300 }, { name = "Alchemy", skill = 285, cap = 300 } },
                   lockouts = { { "Blackwing Lair", now + 2 * 86400 + 15 * 3600, 3, 8 }, { "Onyxia's Lair", now + 86400 + 15 * 3600, 1, 1 } },
                   cooldowns = { ["Transmute"] = 0, ["Mooncloth"] = 0 }, updated = now - 3 * 86400 }
end

-- Every character the Journal has seen, to show. Off: this character's line saved afresh first,
-- as the Characters tab always has. On: copies, this one at 60 with a cooldown running, and two
-- made-up 60s with a raid each and cooldowns; nothing saved is read into or written. The copies
-- are made once, but this character's reputation is the game's own each time it's asked, so one
-- picked in the Reputation window shows on its card while pretending.
function Pretend.Characters()
    local J = ns.Journal
    if not Pretend.on then
        if J and J.SaveCharacter then J.SaveCharacter() end
        return J and J.Characters() or {}
    end
    local me = Compat.MyName() or "Tamsin"
    if not made then MakeCharacters(J, me) end
    local rep = J and J.MyRep and J.MyRep()
    if rep ~= nil then made[me].rep = rep end
    return made
end

-- Where your pre-raid set stands (GearGoal.Summary's shape), nil without one. On: 9 of 16 slots
-- of your own set, the next run with three of its pieces, one in 12% of runs.
function Pretend.GoalSummary()
    local Goal = ns.GearGoal
    if not Pretend.on then
        return Goal and Goal.running and Goal.Summary and Goal.Summary() or nil
    end
    -- Your own set as it is (its name, whether it's one of yours, the pieces you don't wear yet), at 60 with
    -- about nine in sixteen worn, and the next run made of three of the pieces still to get.
    local real
    if Goal and Goal.Summary then
        local ok, s = pcall(Goal.Summary)
        if ok then real = s end
    end
    local pieces = {}
    for _, row in ipairs(real and real.rows or {}) do
        if #pieces < 3 and row.goal and tonumber(row.goal.id) then pieces[#pieces + 1] = { row = { label = row.label, goal = { id = row.goal.id } } } end
    end
    if #pieces == 0 and Goal and Goal.ChosenSet then
        local ids = Goal.ChosenSet()
        for i, id in ipairs(ids or {}) do
            id = tonumber(id)
            if id and id > 0 and #pieces < 3 then pieces[#pieces + 1] = { row = { label = SLOTS[i], goal = { id = id } } } end
        end
    end
    for i, id in ipairs(#pieces == 0 and FALLBACK or {}) do pieces[i] = { row = { label = id[2], goal = { id = id[1] } } } end
    local of = real and (real.of or 0) > 0 and real.of or 16
    return { at = math.max(0, math.min(of - #pieces, math.floor(of * 9 / 16 + 0.5))), of = of,
             name = real and real.name or "Pre-raid", own = real and real.own or nil, rows = {}, other = {}, unknown = 0,
             runs = { { name = "Stratholme", any = 0.12, pieces = pieces } } }
end

-- The Journal's nights and bosses (Journal\Nights.lua's shape): the saved ones; while pretending,
-- three weeks at 60 made up, a dungeon night every day or two with made-up groupmates.
local madeJournal
local GROUP = { "Odrin", "Maelis", "Fenwick", "Sorrel", "Brannoc", "Ysolde", "Wren" }
local RUNS = { { "Stratholme", 9 }, { "Lower Blackrock Spire", 7 }, { "Scholomance", 8 }, { "Upper Blackrock Spire", 5 } }
function Pretend.JournalData()
    local N = ns.Journal and ns.Journal.Nights
    if not Pretend.on then return N and N.Data() or { nights = {}, bosses = {} } end
    if madeJournal then return madeJournal end
    local now = Compat.ServerTime()
    local byName = {}
    for _, d in ipairs(ns.DungeonData or {}) do byName[d.name] = d end
    local since = now - 21 * 86400
    local nights, bosses = {}, {}
    for day = 20, 0, -1 do
        if day % 2 == 0 or day == 0 or day == 1 then
            local run = RUNS[(day % #RUNS) + 1]
            local d = byName[run[1]]
            local at = now - day * 86400 - 2 * 3600
            local n = { at = at, place = run[1], map = d and d.map, secs = 3600 + (day * 397) % 4000, kills = 0, bosses = {},
                        wipes = (day * 7) % 4, deaths = day % 5 == 0 and 1 or 0, gold = 180000 + day * 3100, items = {}, left = at + 5000,
                        lv = LEVEL, with = { GROUP[(day % 7) + 1], GROUP[((day + 2) % 7) + 1], GROUP[((day + 4) % 7) + 1],
                                             GROUP[((day + 5) % 7) + 1], others = 4, guild = 2, hidden = 0 } }
            for k, b in ipairs(d and d.bosses or {}) do
                if k <= run[2] - (day % 3) then
                    n.kills = n.kills + 1
                    n.bosses[#n.bosses + 1] = b[1]
                    local rec = bosses[b[1]] or { kills = 0, wipes = 0, first = at + k * 600, fight = 50 + (k * 37) % 140, lv = LEVEL,
                                                    with = { n.with[1], n.with[2], n.with[3], n.with[4], others = 4, guild = 2, hidden = 0 } }
                    rec.kills, rec.last = rec.kills + 1, at + k * 600
                    if k == 3 and n.wipes > 0 then rec.wipes = rec.wipes + 1 end
                    bosses[b[1]] = rec
                end
            end
            nights[#nights + 1] = n
        end
    end
    madeJournal = { nights = nights, bosses = bosses, since60 = since }
    return madeJournal
end

-- Raid night's own choices: the saved ones, or while pretending, ones kept in memory.
local night = {}
function Pretend.RaidNight()
    if Pretend.on then return night end
    if type(ns.char.raidNight) ~= "table" then ns.char.raidNight = {} end
    return ns.char.raidNight
end

-- Whether the shopping list may be changed from a page: not while pretending.
function Pretend.Listable()
    return not Pretend.on
end

-- What's kept in memory while pretending a side or a skill: the profession road's passed steps and the
-- step in hand, and the shopping list, so nothing worked out for what's pretended is saved.
local kept = {}
local function Aside() return Pretend.faction ~= nil or Pretend.skill ~= nil end

-- A table kept in memory in place of the saved one of that name (ns.char.profRoad, ns.char.roadHand)
-- while pretending a side or a skill; nil otherwise, and the saved one is used.
function Pretend.Kept(name)
    if not Aside() then return nil end
    kept[name] = kept[name] or {}
    return kept[name]
end

local function Copy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = Copy(v) end
    return out
end

-- The shopping list: nil (the saved one is used) unless pretending a side or a skill, then a copy of
-- the saved one made the first time it's asked for, changed in memory only.
function Pretend.ShoppingList()
    if not Aside() then return nil end
    if not kept.shopping then
        kept.shopping = Copy(ns.char and type(ns.char.shopping) == "table" and ns.char.shopping or {})
    end
    return kept.shopping
end

-- The skill line a profession's name or number is ("cooking", "first aid", "185"), else nil.
local function LineOf(word)
    local data = ns.ProfessionData or {}
    local n = tonumber(word)
    if n and type(data[n]) == "table" then return n end
    for line, p in pairs(data) do
        if type(p) == "table" and type(p.name) == "string" and p.name:lower() == word then return line end
    end
end

-- Each profession's name as the command takes it, in order.
local function Names()
    local out = {}
    for _, p in pairs(ns.ProfessionData or {}) do
        if type(p) == "table" and type(p.name) == "string" then out[#out + 1] = p.name:lower() end
    end
    table.sort(out)
    return out
end

-- A spell of each profession that has its picture, for the made-up one's tile.
local PICTURE = { [171] = 2259, [164] = 2018, [333] = 7411, [202] = 4036, [165] = 2108, [197] = 3908,
                  [186] = 2575, [185] = 2550, [129] = 3273 }

-- The professions to show while pretending a skill: the one pretended, else nil (the game's).
function Pretend.Professions()
    local s = Pretend.skill
    if not s then return nil end
    local data = ns.ProfessionData and ns.ProfessionData[s.line]
    local icon
    for _, p in ipairs(ns.Professions and ns.Professions.Mine and ns.Professions.Mine(true) or {}) do
        if p.line == s.line then icon = p.icon end
    end
    if not icon and PICTURE[s.line] and Compat.SpellInfo then
        local _, picture = Compat.SpellInfo(PICTURE[s.line])
        icon = picture
    end
    local name = data and data.name or tostring(s.line)
    return { { line = s.line, name = name, game = name, icon = icon, skill = s.skill, cap = s.cap, pretend = true } }
end

-- The title bar's words while pretending, else nil: "pretend 60", "pretend Horde", "pretend 60, Horde",
-- "pretend Cooking 190".
function Pretend.Words()
    local parts = {}
    if Pretend.on then parts[#parts + 1] = "60" end
    if Pretend.faction then parts[#parts + 1] = Pretend.faction end
    if Pretend.skill then
        local data = ns.ProfessionData and ns.ProfessionData[Pretend.skill.line]
        parts[#parts + 1] = (data and data.name or tostring(Pretend.skill.line)) .. " " .. Pretend.skill.skill
    end
    if #parts == 0 then return nil end
    return "pretend " .. table.concat(parts, ", ")
end

-- Every open page and window drawn again, once, with what's worked out for the old answers let go.
local function Repaint()
    if ns.Gear and ns.Gear.PlansChanged then ns.Gear.PlansChanged() end
    -- The Training Planner's reading names your side's weapon masters.
    if ns.Training and ns.Training.Forget then ns.Training.Forget() end
    local panel = ns.modules and ns.modules.professionpanel
    if panel and panel.Forget then panel.Forget() end
    if panel and panel.Refresh then panel.Refresh() end
    if ns.Shopping and ns.Shopping.Refresh then ns.Shopping.Refresh() end
    if ns.Window and ns.Window.Refresh then ns.Window.Refresh() end
end

function Pretend.Set(on)
    Pretend.on = on and true or false
    made, night, madeJournal = nil, {}, nil
    Repaint()
end

-- A side to pretend ("Horde" or "Alliance"), or nil for the game's own.
function Pretend.SetFaction(faction)
    if faction ~= Pretend.faction then kept = {} end
    Pretend.faction = faction
    Repaint()
end

-- A profession to pretend at a skill (1 to 300), its rank's cap the next one above the skill (300 at
-- 300), or nil for the game's own. Returns false for a line the data hasn't or a skill out of reach.
function Pretend.SetSkill(line, skill)
    if line == nil then
        if Pretend.skill then kept = {} end
        Pretend.skill = nil
        Repaint()
        return true
    end
    skill = tonumber(skill)
    if not (ns.ProfessionData and type(ns.ProfessionData[line]) == "table") or not skill or skill < 1 or skill > 300
        or skill ~= math.floor(skill) then
        return false
    end
    local cap = 300
    for _, rank in ipairs(ns.Professions and ns.Professions.RANKS or {}) do
        if rank.cap > skill then cap = rank.cap break end
    end
    local was = Pretend.skill
    if not (was and was.line == line and was.skill == skill) then kept = {} end
    Pretend.skill = { line = line, skill = skill, cap = cap }
    Repaint()
    return true
end

-- Everything pretended let go: pretend off.
function Pretend.Off()
    Pretend.on, Pretend.faction, Pretend.skill, kept = false, nil, nil, {}
    made, night, madeJournal = nil, {}, nil
    Repaint()
end

if ns.IsBeta(ns.version) then
    ns.Command("pretend 60", function()
        Pretend.Set(true)
        ns.Print("Pretending to be level 60 until /jsal pretend off or a /reload. Nothing is saved meanwhile.")
    end)
    for word, side in pairs({ horde = "Horde", alliance = "Alliance" }) do
        ns.Command("pretend " .. word, function()
            Pretend.SetFaction(side)
            ns.Print(("Pretending to be %s until /jsal pretend off or a /reload. Pages show what a %s character sees; what's saved and what your guild hears stay your own side's.")
                :format(side, side))
        end)
    end
    local function SkillHelp()
        ns.Print("Pretend which profession, at what skill? /jsal pretend skill <profession> <skill>, e.g. /jsal pretend skill cooking 190. Professions: "
            .. table.concat(Names(), ", ") .. " (or its skill line number).")
    end
    -- (Core.lua's /jsal gives a command the words after it; a copy loaded on its own may lack it.)
    local WithWords = ns.CommandWithWords or function() end
    WithWords("pretend skill", function(rest)
        local word, skill = (rest or ""):match("^(.-)%s+(%d+)$")
        local line = word and LineOf(word)
        if not line or not Pretend.SetSkill(line, tonumber(skill)) then return SkillHelp() end
        local s = Pretend.skill
        ns.Print(("Pretending to have %s at %d of %d until /jsal pretend off or a /reload, knowing what its trainers teach up to there. Nothing is saved meanwhile.")
            :format(ns.ProfessionData[line].name, s.skill, s.cap))
    end)
    ns.Command("pretend off", function()
        Pretend.Off()
        ns.Print("Pretending no more.")
    end)
end
