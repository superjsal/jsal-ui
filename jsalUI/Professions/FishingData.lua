-- Fishing on the Professions page, built by tools/build_fishing.py: not by hand.
-- zones: [uiMap] = { skill where no fish get away, skill it can be fished from, side whose town it is }.
--   The ORIGINAL GAME'S numbers, not yet Forever's (no table or function in Forever gives them),
--   from players' testing kept as El's Extreme Anglin', "Zone Base Fishing Skill". Forever's own
--   zones aren't here until they're measured.
-- catches: [uiMap] = { catches seen, x, y of the spot fished from most, then each of the most caught
--   things that aren't junk, item and percent of every catch }. What players caught in Forever: EG Link
--   output (Efficient Games, https://efficient.games, CC BY 4.0), revision 423d6c9.
-- gear: poles, lures and what's worn, with each one's bonus, what it needs and where it comes from.
local _, ns = ...

ns.FishingData = {
    zones = {
        [1411] = { 25, 0, "h" },   -- Durotar
        [1412] = { 25, 0, "h" },   -- Mulgore
        [1413] = { 75, 0 },   -- The Barrens
        [1416] = { 225, 130 },   -- Alterac Mountains
        [1417] = { 225, 130 },   -- Arathi Highlands
        [1420] = { 25, 0, "h" },   -- Tirisfal Glades
        [1421] = { 75, 0 },   -- Silverpine Forest
        [1422] = { 300, 205 },   -- Western Plaguelands
        [1423] = { 425, 330 },   -- Eastern Plaguelands
        [1424] = { 150, 55 },   -- Hillsbrad Foothills
        [1425] = { 300, 205 },   -- The Hinterlands
        [1426] = { 25, 0, "a" },   -- Dun Morogh
        [1428] = { 425, 330 },   -- Burning Steppes
        [1429] = { 25, 0, "a" },   -- Elwynn Forest
        [1430] = { 425, 330 },   -- Deadwind Pass
        [1431] = { 150, 55 },   -- Duskwood
        [1432] = { 75, 0 },   -- Loch Modan
        [1433] = { 150, 55 },   -- Redridge Mountains
        [1434] = { 225, 130 },   -- Stranglethorn Vale
        [1435] = { 225, 130 },   -- Swamp of Sorrows
        [1436] = { 75, 0 },   -- Westfall
        [1437] = { 150, 55 },   -- Wetlands
        [1438] = { 25, 0, "a" },   -- Teldrassil
        [1439] = { 75, 0 },   -- Darkshore
        [1440] = { 150, 55 },   -- Ashenvale
        [1441] = { 225, 130 },   -- Thousand Needles
        [1442] = { 150, 55 },   -- Stonetalon Mountains
        [1443] = { 225, 130 },   -- Desolace
        [1444] = { 300, 205 },   -- Feralas
        [1445] = { 225, 130 },   -- Dustwallow Marsh
        [1446] = { 300, 205 },   -- Tanaris
        [1447] = { 300, 205 },   -- Azshara
        [1448] = { 300, 205 },   -- Felwood
        [1449] = { 300, 205 },   -- Un'Goro Crater
        [1450] = { 300, 205 },   -- Moonglade
        [1451] = { 425, 330 },   -- Silithus
        [1452] = { 425, 330 },   -- Winterspring
        [1453] = { 75, 0, "a" },   -- Stormwind City
        [1454] = { 75, 0, "h" },   -- Orgrimmar
        [1455] = { 75, 0, "a" },   -- Ironforge
        [1456] = { 75, 0, "h" },   -- Thunder Bluff
        [1457] = { 75, 0, "a" },   -- Darnassus
        [1458] = { 75, 0, "h" },   -- Undercity
    },
    catches = {
        [1411] = { 49, 0.587, 0.164, 6303, 94 },
        [1412] = { 69, 0.476, 0.572, 6291, 54, 6289, 43 },
        [1413] = { 211, 0.634, 0.385, 6361, 27, 6358, 22, 6303, 17, 6522, 14 },
        [1421] = { 9, 0.327, 0.159, 6358, 67, 6289, 11, 6299, 11 },
        [1424] = { 16, 0.607, 0.298, 21071, 69, 6308, 19, 3820, 6, 21114, 6 },
        [1434] = { 298, 0.354, 0.100, 6358, 26, 6359, 15, 6362, 13, 3820, 10 },
        [1442] = { 296, 0.502, 0.411, 6308, 53, 6289, 32, 21071, 11, 6359, 1 },
        [1443] = { 2, 0.218, 0.735, 3820, 50, 6308, 50 },
        [1456] = { 252, 0.404, 0.619, 6289, 63, 6308, 20, 6291, 16, 3385, 1 },
        [2521] = { 24, 0.468, 0.489, 6291, 58, 6289, 38 },
        [2548] = { 68, 0.799, 0.542, 6362, 51, 4603, 16, 6358, 16, 6359, 16 },
    },
    gear = {
        { item = 6256, kind = "pole", bonus = 0, how = "vendor", copper = 23, sellers = 44 },
        { item = 12225, kind = "pole", bonus = 3, skill = 1, how = "quest", quest = 1141, title = "The Family and the Fishing Pole", from = 10, side = "a" },
        { item = 6365, kind = "pole", bonus = 5, skill = 10, level = 5, how = "vendor", copper = 901, sellers = 2, seller = "Katoom the Angler", limited = true, side = "h" },
        { item = 285094, kind = "pole", bonus = 15, skill = 50, level = 20, how = "drop", npc = "Lord Angler" },
        { item = 6367, kind = "pole", bonus = 20, skill = 100, level = 25, how = "object", object = "Shellfish Trap", map = 1443 },
        { item = 19022, kind = "pole", bonus = 25, skill = 100, how = "quest", quest = 7815, title = "Snapjaws, Mon!", from = 44, side = "h" },
        { item = 6529, kind = "lure", bonus = 25, minutes = 10, how = "vendor", copper = 50, sellers = 36 },
        { item = 6530, kind = "lure", bonus = 50, skill = 50, minutes = 10, how = "vendor", copper = 100, sellers = 43 },
        { item = 6811, kind = "lure", bonus = 50, skill = 50, minutes = 10, how = "made", profession = 202 },
        { item = 6532, kind = "lure", bonus = 75, skill = 100, minutes = 10, how = "vendor", copper = 250, sellers = 35 },
        { item = 7307, kind = "lure", bonus = 75, skill = 100, minutes = 10, how = "drop", npc = "Rotted One" },
        { item = 6533, kind = "lure", bonus = 100, skill = 100, minutes = 5, how = "vendor", copper = 250, sellers = 9, limited = true },
        { item = 19972, kind = "wear", bonus = 5, skill = 1, how = "quest", quest = 8221, title = "Rare Fish - Keefer's Angelfish", from = 1 },
        { item = 19969, kind = "wear", bonus = 5, skill = 1, how = "quest", quest = 8225, title = "Rare Fish - Brownell's Blue Striped Racer", from = 1 },
    },
}
