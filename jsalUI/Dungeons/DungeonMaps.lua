-- Dungeon maps for the Dungeon guide's Map tab: which of the game's own map pictures show a
-- dungeon, floor by floor, and where on them each boss stands. Kept by hand.
local _, ns = ...

-- The game has no map of its own for a dungeon and no place for a boss, but its files hold a
-- picture of each floor, in twelve pieces: Interface\WorldMap\<folder>\<folder><floor>_1 to
-- _12, four across, 1002 by 668 in all. The pictures have a skull where a boss stands; a boss's
-- place here is its skull's, as parts of the picture's width and height.
-- By dungeon: `folder`, each floor's name, and each boss by the game's encounter ID as
-- { floor, across, down }.
ns.DungeonMaps = {
    [25] = { folder = "Maraudon", floors = { "Caverns of Maraudon", "Zaetar's Grave" },
        bosses = {
            [422] = { 1, 0.359, 0.102 },    -- Noxxion
            [423] = { 1, 0.163, 0.340 },    -- Razorlash
            [427] = { 1, 0.503, 0.524 },    -- Tinkerer Gizlock
            [424] = { 1, 0.377, 0.707 },    -- Lord Vyletongue
            [425] = { 2, 0.247, 0.138 },    -- Celebras the Cursed
            [426] = { 2, 0.410, 0.490 },    -- Landslide
            [428] = { 2, 0.412, 0.814 },    -- Rotgrip
            [429] = { 2, 0.257, 0.781 },    -- Princess Theradras
        } },
}
