-- WoWSims Forever's consumables for each spec (github.com/wowsims/forever, MIT), for the
-- Endgame page's RAID NIGHT card; how long each lasts from the game's own tables. Regenerated
-- by tools/build_consumables.py, not by hand.
local _, ns = ...

-- `lists`: by WoWSims' spec, each consumable as { item, kind, seconds it lasts (0: used in the
-- moment) }. `trees`: by class, the spec of each talent tree; `sets`: of each At 60 set, a
-- list of its own where its sims have one. A spec with no list here has none from WoWSims.
ns.ConsumablesData = {
    lists = {
        ["druid/balance"] = {
            { 13512, "flask", 7200 },   -- Flask of Supreme Power
            { 13454, "elixir", 3600 },   -- Greater Arcane Elixir
            { 250343, "elixir", 1800 },   -- Elixir of Nature Power
            { 250337, "elixir", 1800 },   -- Elixir of the Owl
            { 250341, "elixir", 1800 },   -- Greater Mageblood Elixir
            { 13933, "food", 900 },   -- Lobster Stew
            { 20749, "weapon", 1800 },   -- Brilliant Wizard Oil
            { 13444, "potion", 0 },   -- Major Mana Potion
            { 250937, "potion", 0 },   -- Major Spellblasting Potion
            { 12662, "rune", 0 },   -- Demonic Rune
            { 260814, "explosive", 0 },   -- SAF-T Clever Dynamite
        },
        ["druid/feralcat"] = {
            { 274274, "flask", 7200 },   -- Flask of Natural Aggression
            { 250072, "food", 900 },   -- Swiftstrike Steak
            { 12643, "weapon", 1800 },   -- Dense Weightstone
            { 13444, "potion", 0 },   -- Major Mana Potion
            { 13442, "potion", 0 },   -- Mighty Rage Potion
            { 12662, "rune", 0 },   -- Demonic Rune
            { 260817, "explosive", 0 },   -- EZ-Thro Dark Bomb
            { 12460, "extra", 600 },   -- Juju Might
            { 8412, "extra", 3600 },   -- Ground Scorpok Assay
            { 10646, "extra", 0 },   -- Goblin Sapper Charge
        },
        ["druid/restoration"] = {
            { 250066, "food", 900 },   -- Soaring Pamplona
            { 13444, "potion", 0 },   -- Major Mana Potion
        },
        ["hunter/dps"] = {
            { 274274, "flask", 7200 },   -- Flask of Natural Aggression
            { 13452, "elixir", 1800 },   -- Elixir of the Mongoose
            { 250341, "elixir", 1800 },   -- Greater Mageblood Elixir
            { 9179, "elixir", 3600 },   -- Elixir of Greater Intellect
            { 250072, "food", 900 },   -- Swiftstrike Steak
            { 18262, "weapon", 1800 },   -- Elemental Sharpening Stone
            { 13444, "potion", 0 },   -- Major Mana Potion
            { 250943, "potion", 0 },   -- Major Frenzy Potion
            { 12662, "rune", 0 },   -- Demonic Rune
            { 18588, "explosive", 0 },   -- Ez-Thro Dynamite II
            { 10646, "extra", 0 },   -- Goblin Sapper Charge
            { 10310, "extra", 1800 },   -- Scroll of Strength IV
            { 12460, "extra", 600 },   -- Juju Might
            { 12217, "extra", 600 },   -- Dragonbreath Chili
            { 8412, "extra", 3600 },   -- Ground Scorpok Assay
        },
        ["mage/dps"] = {
            { 13512, "flask", 7200 },   -- Flask of Supreme Power
            { 13454, "elixir", 3600 },   -- Greater Arcane Elixir
            { 13447, "elixir", 3600 },   -- Elixir of the Sages
            { 250348, "elixir", 1800 },   -- Elixir of the Whale
            { 20007, "elixir", 3600 },   -- Mageblood Elixir
            { 13931, "food", 900 },   -- Nightfin Soup
            { 20749, "weapon", 1800 },   -- Brilliant Wizard Oil
            { 277502, "weapon", 0 },   -- Scroll of Imbue Precision
            { 13444, "potion", 0 },   -- Major Mana Potion
        },
        ["paladin/holy"] = {
            { 250066, "food", 900 },   -- Soaring Pamplona
            { 13444, "potion", 0 },   -- Major Mana Potion
        },
        ["paladin/protection"] = {
            { 13512, "flask", 7200 },   -- Flask of Supreme Power
            { 21546, "elixir", 1800 },   -- Elixir of Holy Power
            { 13454, "elixir", 3600 },   -- Greater Arcane Elixir
            { 250337, "elixir", 1800 },   -- Elixir of the Owl
            { 250338, "elixir", 1800 },   -- Elixir of Sages
            { 250335, "elixir", 1800 },   -- Elixir of Greater Fortitude
            { 250341, "elixir", 1800 },   -- Greater Mageblood Elixir
            { 13445, "elixir", 3600 },   -- Elixir of Greater Defense
            { 250350, "elixir", 1800 },   -- Elixir of Ferocity
            { 13452, "elixir", 1800 },   -- Elixir of the Mongoose
            { 13935, "food", 900 },   -- Baked Salmon
            { 20749, "weapon", 1800 },   -- Brilliant Wizard Oil
            { 13455, "potion", 0 },   -- Greater Stoneshield Potion
            { 12662, "rune", 0 },   -- Demonic Rune
            { 18588, "explosive", 0 },   -- Ez-Thro Dynamite II
            { 10646, "extra", 0 },   -- Goblin Sapper Charge
            { 12460, "extra", 600 },   -- Juju Might
            { 10307, "extra", 1800 },   -- Scroll of Stamina IV
        },
        ["priest/dps"] = {
            { 13512, "flask", 7200 },   -- Flask of Supreme Power
            { 13931, "food", 900 },   -- Nightfin Soup
            { 20749, "weapon", 1800 },   -- Brilliant Wizard Oil
            { 13444, "potion", 0 },   -- Major Mana Potion
            { 250937, "potion", 0 },   -- Major Spellblasting Potion
            { 12662, "rune", 0 },   -- Demonic Rune
        },
        ["priest/healer"] = {
            { 249869, "food", 900 },   -- Sunny Tea
            { 20748, "weapon", 1800 },   -- Brilliant Mana Oil
            { 13444, "potion", 0 },   -- Major Mana Potion
            { 12662, "rune", 0 },   -- Demonic Rune
        },
        ["rogue/dps"] = {
            { 13452, "elixir", 1800 },   -- Elixir of the Mongoose
            { 250335, "elixir", 1800 },   -- Elixir of Greater Fortitude
            { 250350, "elixir", 1800 },   -- Elixir of Ferocity
            { 12460, "elixir", 600 },   -- Juju Might
            { 250072, "food", 900 },   -- Swiftstrike Steak
            { 12643, "weapon", 1800 },   -- Dense Weightstone
            { 12404, "weapon", 1800 },   -- Dense Sharpening Stone
            { 8928, "weapon", 0 },   -- Instant Poison VI
            { 8985, "weapon", 0 },   -- Deadly Poison IV
            { 250943, "potion", 0 },   -- Major Frenzy Potion
            { 7676, "rune", 0 },   -- Thistle Tea
        },
        ["shaman/enhancement"] = {
            { 13512, "flask", 7200 },   -- Flask of Supreme Power
            { 20452, "food", 900 },   -- Smoked Desert Dumplings
            { 18262, "weapon", 1800 },   -- Elemental Sharpening Stone
            { 13444, "potion", 0 },   -- Major Mana Potion
            { 12662, "rune", 0 },   -- Demonic Rune
            { 260817, "explosive", 0 },   -- EZ-Thro Dark Bomb
            { 10646, "extra", 0 },   -- Goblin Sapper Charge
        },
        ["shaman/restoration"] = {
            { 250066, "food", 900 },   -- Soaring Pamplona
            { 13444, "potion", 0 },   -- Major Mana Potion
        },
        ["warlock/dps"] = {
            { 13512, "flask", 7200 },   -- Flask of Supreme Power
            { 13931, "food", 900 },   -- Nightfin Soup
            { 20749, "weapon", 1800 },   -- Brilliant Wizard Oil
            { 250937, "potion", 0 },   -- Major Spellblasting Potion
            { 12662, "rune", 0 },   -- Demonic Rune
            { 18588, "explosive", 0 },   -- Ez-Thro Dynamite II
        },
        ["warrior/dps"] = {
            { 250350, "elixir", 1800 },   -- Elixir of Ferocity
            { 13452, "elixir", 1800 },   -- Elixir of the Mongoose
            { 12820, "elixir", 1200 },   -- Winterfall Firewater
            { 20452, "food", 900 },   -- Smoked Desert Dumplings
            { 12643, "weapon", 1800 },   -- Dense Weightstone
            { 12404, "weapon", 1800 },   -- Dense Sharpening Stone
            { 13442, "potion", 0 },   -- Mighty Rage Potion
            { 260817, "explosive", 0 },   -- EZ-Thro Dark Bomb
            { 10646, "extra", 0 },   -- Goblin Sapper Charge
        },
        ["warrior/dps:arms"] = {
            { 250350, "elixir", 1800 },   -- Elixir of Ferocity
            { 13452, "elixir", 1800 },   -- Elixir of the Mongoose
            { 12820, "elixir", 1200 },   -- Winterfall Firewater
            { 20452, "food", 900 },   -- Smoked Desert Dumplings
            { 12404, "weapon", 1800 },   -- Dense Sharpening Stone
            { 13442, "potion", 0 },   -- Mighty Rage Potion
            { 260817, "explosive", 0 },   -- EZ-Thro Dark Bomb
            { 10646, "extra", 0 },   -- Goblin Sapper Charge
        },
        ["warrior/protection"] = {
            { 20452, "food", 900 },   -- Smoked Desert Dumplings
            { 12404, "weapon", 1800 },   -- Dense Sharpening Stone
            { 250943, "potion", 0 },   -- Major Frenzy Potion
            { 9421, "rune", 0 },   -- Major Healthstone
            { 260814, "explosive", 0 },   -- SAF-T Clever Dynamite
            { 10646, "extra", 0 },   -- Goblin Sapper Charge
            { 17048, "extra", 900 },   -- Rumsey Rum
        },
    },
    trees = {
        WARRIOR = { "warrior/dps", "warrior/dps", "warrior/protection" },
        PALADIN = { "paladin/holy", "paladin/protection", "paladin/retribution" },
        HUNTER = { "hunter/dps", "hunter/dps", "hunter/dps" },
        ROGUE = { "rogue/dps", "rogue/dps", "rogue/dps" },
        PRIEST = { "priest/healer", "priest/healer", "priest/dps" },
        SHAMAN = { "shaman/elemental", "shaman/enhancement", "shaman/restoration" },
        MAGE = { "mage/dps", "mage/dps", "mage/dps" },
        WARLOCK = { "warlock/dps", "warlock/dps", "warlock/dps" },
        DRUID = { "druid/balance", "druid/feralcat", "druid/restoration" },
    },
    sets = {
        HUNTER = { weave = "hunter/dps", turret = "hunter/dps", melee = "hunter/dps" },
        MAGE = { arcane = "mage/dps", fire = "mage/dps", frost = "mage/dps" },
        WARLOCK = { preraid = "warlock/dps" },
        WARRIOR = { arms = "warrior/dps:arms", fury = "warrior/dps", offensive = "warrior/protection", balanced = "warrior/protection" },
        DRUID = { balance = "druid/balance", feral = "druid/feralcat" },
        PRIEST = { healer = "priest/healer" },
    },
}
