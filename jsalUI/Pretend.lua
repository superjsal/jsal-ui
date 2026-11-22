-- Pretend to be level 60, in a beta only (a version that says "beta"; a release has no such
-- command): /jsal pretend 60 and /jsal pretend off. While it's on, the pages that show what's
-- built for level 60 (Endgame, Home's top card, the Journal's Characters tab) draw made-up answers
-- in the game's own fonts and layout: this character at 60 with 9 of 16 slots of its set, two
-- made-up alts with raids saved and cooldowns ready and running, some raid consumables held.
--
-- This is the one place those pages ask: their level, the characters, what's in the bags for raid
-- night, where the set stands, raid night's own choices, and whether the shopping list may be
-- changed. Off, each answer is the game's or the saved one, unchanged. On, nothing is saved:
-- the made-up answers are kept in memory, raid night's choices too, the shopping list is left
-- alone, and none of it goes to the guild (nothing here is ever sent). It's off again after a
-- /reload, and the dashboard's title bar says "pretend 60" while it's on.
local _, ns = ...
local Compat = ns.Compat

local Pretend = { on = false }
ns.Pretend = Pretend

local LEVEL = 60
-- What's in the bags while pretending: a night's flasks and Greater Mageblood, four of a night's
-- steaks, a stack of Major Mana Potions.
local HELD = { [274274] = 2, [250341] = 6, [250072] = 4, [13444] = 5 }
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

-- Every character the Journal has seen, to show. Off: this character's line saved afresh first,
-- as the Characters tab always has. On: copies, this one at 60 with a cooldown running, and two
-- made-up 60s with a raid each and cooldowns; nothing saved is read into or written.
local made
function Pretend.Characters()
    local J = ns.Journal
    if not Pretend.on then
        if J and J.SaveCharacter then J.SaveCharacter() end
        return J and J.Characters() or {}
    end
    if made then return made end
    local now = Compat.ServerTime()
    made = {}
    for name, c in pairs(J and J.Characters() or {}) do
        local copy = {}
        for k, v in pairs(c) do copy[k] = v end
        copy.lockouts, copy.cooldowns = nil, nil
        made[name] = copy
    end
    local me = Compat.MyName() or "Tamsin"
    local _, classFile = UnitClass("player")
    local mine = made[me] or { name = me, class = UnitClass("player"), classFile = classFile, updated = now }
    mine.level = LEVEL
    mine.lockouts = { { "Molten Core", now + 2 * 86400 + 15 * 3600, 4, 10 } }
    mine.cooldowns = { ["Salt Shaker"] = now + 14 * 3600 }
    made[me] = mine
    made.Corwen = { name = "Corwen", class = "Mage", classFile = "MAGE", level = LEVEL, zone = "Undercity", money = 882000,
                    professions = { { name = "Alchemy", skill = 300, cap = 300 }, { name = "Herbalism", skill = 300, cap = 300 } },
                    cooldowns = { ["Transmute"] = now + 33 * 3600 }, updated = now - 86400 }
    made.Liesl = { name = "Liesl", class = "Priest", classFile = "PRIEST", level = LEVEL, zone = "Blackrock Mountain", money = 412000,
                   professions = { { name = "Tailoring", skill = 300, cap = 300 }, { name = "Alchemy", skill = 285, cap = 300 } },
                   lockouts = { { "Blackwing Lair", now + 2 * 86400 + 15 * 3600, 3, 8 }, { "Onyxia's Lair", now + 86400 + 15 * 3600, 1, 1 } },
                   cooldowns = { ["Transmute"] = 0, ["Mooncloth"] = 0 }, updated = now - 3 * 86400 }
    return made
end

-- Where your pre-raid set stands (GearGoal.Summary's shape), nil without one. On: 9 of 16 slots
-- of your own set, the next run with three of its pieces, one in 12% of runs.
function Pretend.GoalSummary()
    local Goal = ns.GearGoal
    if not Pretend.on then
        return Goal and Goal.running and Goal.Summary and Goal.Summary() or nil
    end
    local ids, name
    if Goal and Goal.ChosenSet then ids, name = Goal.ChosenSet() end
    local pieces = {}
    for i, id in ipairs(ids or {}) do
        if id > 0 and #pieces < 3 then pieces[#pieces + 1] = { row = { label = SLOTS[i], goal = { id = id } } } end
    end
    return { at = 9, of = 16, name = name or "Pre-raid", rows = {}, other = {}, unknown = 0,
             runs = { { name = "Stratholme", any = 0.12, pieces = pieces } } }
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

-- The title bar's word while pretending, else nil.
function Pretend.Words()
    return Pretend.on and "pretend 60" or nil
end

function Pretend.Set(on)
    Pretend.on = on and true or false
    made, night = nil, {}
    if ns.Window and ns.Window.Refresh then ns.Window.Refresh() end
end

if ns.IsBeta(ns.version) then
    ns.Command("pretend 60", function()
        Pretend.Set(true)
        ns.Print("Pretending to be level 60 until /jsal pretend off or a /reload. Nothing is saved meanwhile.")
    end)
    ns.Command("pretend off", function()
        Pretend.Set(false)
        ns.Print("Pretending no more.")
    end)
end
