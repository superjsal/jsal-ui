# What in jsal.ui isn't jsal's

jsal.ui's own code is under the MIT License in `LICENSE`. The things below were made by other people and are
**not** covered by it. Each keeps its own owner and its own terms.

## Dungeon maps: Santiago Reyes

The maps of Forever's own dungeons in the Dungeon guide (`jsalUI/Media/Maps/`) are Santiago Reyes's, from
*Atlas de Azeroth: Forever* ([sreyesmaps.com](https://sreyesmaps.com)). They are in jsal.ui with his written permission
and are credited under each map. All rights are his. They are not covered by jsal.ui's licence, and nobody may
reuse them from here: ask him.

## Fonts: Outfit and Inter

- **Outfit** (`jsalUI/Media/Fonts/Outfit-Regular.ttf`, `Outfit-SemiBold.ttf`): Copyright 2021 The Outfit Project
  Authors ([github.com/Outfitio/Outfit-Fonts](https://github.com/Outfitio/Outfit-Fonts)).
- **Inter** (`jsalUI/Media/Fonts/Inter-Bold.ttf`): Copyright 2016 The Inter Project Authors
  ([github.com/rsms/inter](https://github.com/rsms/inter)).

Both are under the SIL Open Font License, Version 1.1. The full licence text is beside each font, in
`Outfit-OFL.txt` and `Inter-OFL.txt`.

## Stat weights, gear sets and consumables: WoWSims

The Gear plan's stat weights, the level 60 sets and the raid night consumables come from WoWSims
([wowsims/forever](https://github.com/wowsims/forever) and [wowsims/classic](https://github.com/wowsims/classic)).
Their files are in `data/gear/wowsims-forever/`, `data/gear/wowsims/` and `data/talents/wowsims_raid.json`, and
what jsal.ui uses of them is built into `jsalUI/Gear/GearData.lua` and `jsalUI/Endgame/ConsumablesData.lua`.

> Copyright (c) 2022 wowsims team (wowsims/forever)
> Copyright (c) 2024 wowsims team (wowsims/classic)

MIT License. The licence text is at the end of this file, and in each folder's `LICENSE`.

## Quest data: pfQuest

Each quest's earlier quests and races, and how often quest items drop, come partly from
[pfQuest](https://github.com/shagu/pfQuest)'s database (`data/quests/pfquest.json`), built into
`jsalUI/Quests/QuestScoreData.lua`.

> Copyright (c) 2017-2021 Eric Mauser (Shagu)

MIT License. The licence text is at the end of this file, and in `data/quests/pfquest/LICENSE`.

## Quests, trainers and vendors: EG Link

Quests new to Forever, quest item drop counts, trainer prices and vendors come partly from
[EG Link output: World of Warcraft: Forever](https://github.com/JIVESCORP/eg-link-output-wowf): data from
[Efficient Games](https://efficient.games), licensed under
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). jsal.ui keeps only what it needs (each quest's level,
next quest, races and items; each trainer's name, spot, services, levels and costs; each vendor's wares), in
`data/quests/eglink.json`, `data/quests/eglink-drops.json`, `data/trainers/eglink-trainers.json` and
`data/vendors/eglink-vendors.json`, built into `jsalUI/Quests/QuestScoreData.lua`, `jsalUI/TrainerData.lua`,
`jsalUI/Training/SpellData.lua` and `jsalUI/Professions/ProfessionData.lua`.

## Word lists: ENABLE

Daily Word's answers and accepted guesses (`data/daily-word-*.txt`, `data/long-word-guesses.txt`, built into
`jsalUI/Games/DailyWordData.lua`) are from the ENABLE word list, which is in the public domain.

## Game data: Blizzard Entertainment

World of Warcraft, its names, items, spells, quests, maps and game tables are Blizzard Entertainment's.
The game's tables in `data/` (the `.csv` files) and the facts jsal.ui builds from them (dungeons, talents,
spells, flights, cooldowns, professions) are **not jsal's to license**, and jsal.ui's licence does not cover them.
jsal.ui is a fan-made addon, not made or endorsed by Blizzard.

## Data read from websites: Wowhead and Petopia

Item lists, drop chances, quest links, recipe sources, trainer spots and the suggested leveling builds were read
from [Wowhead](https://www.wowhead.com/forever) Forever's pages and leveling guides (`data/**/wowhead*.json`,
`data/dungeons/quest-*.json`, `data/dungeons/class-quests.json`, `data/talents/suggested.json`,
`data/trainers.txt`); hunter pet abilities from [Petopia](https://www.wow-petopia.com/forever/)
(`data/pets/petopia.json`, built into `jsalUI/Training/TameData.lua`). These are facts about the game as those
sites record them. They are **not jsal's to license**, and jsal.ui's licence does not cover them.

---

## The MIT License text (for WoWSims and pfQuest above)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
