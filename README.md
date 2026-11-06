# jsal.ui

A free UI pack, daily games and easy helpers for WoW Forever, from [jsal.io](https://jsal.io).
Made for casual players: every part is small, on by default, and has one switch.

## What's in it

| Part | What it does |
| --- | --- |
| Daily Word | One five-letter word a day, the same for everyone, six tries. Share your grid to guild chat. |
| Icon Guess | Name the spell from its icon. A daily round of ten, the same for everyone, plus practice rounds. |
| Flight bar | While you fly: the route, the time left and today's games. Times come from the game's own flight tables. |
| Guild tab | Guildmates who run jsal.ui, their version and today's scores. |
| Build Planner | Any class's three Forever trees in the dashboard. A build shows level by level, with what's taken and what's next; Learn next points spends waiting points in its order; Edit opens the trees. Builds are saved for the whole account and shared as Wowhead talent calculator links or short codes. |
| Training Planner | Your next trainer visit and its cost, your road to 60, and every spell: ready now, coming soon, later, skipped, plus weapon skills. Spells come from the game's files; prices from class trainers you've opened. |
| Talent helper | When a point comes in, names the next talent in your build, with a Learn it button. |
| Quests on autopilot | Accepts and turns in quests. Hold Shift to do it yourself; reward choices stay yours. |
| Vendor run | Repairs and sells grey items at any vendor, and says what it spent and earned. |
| Level-up helper | Talent points and trainer ranks on each level, and what a trainer has for you. |
| Bags and gear warnings | A heads-up when bags are nearly full or gear is close to breaking. |
| The look | One-click install of the jsal.ui EllesmereUI profile (once it's added). |

## Install

1. Install [EllesmereUI](https://www.curseforge.com/wow/addons/ellesmereui), which is free.
2. Copy the `jsalUI` folder into `World of Warcraft\_forever_\Interface\AddOns`.
3. Log in, or type `/reload`, then type `/jsal`.

## Commands

| Command | What it does |
| --- | --- |
| `/jsal` | Opens or closes the dashboard |
| `/jsal word` | Today's Daily Word |
| `/jsal icons` | Today's Icon Guess round |
| `/jsal games`, `/jsal guild`, `/jsal settings`, `/jsal install` | Opens that page |
| `/jsal version` | Prints the version |

## How it's built

- `Compat.lua`: every Blizzard call that has moved between versions, in one place.
- `Core.lua`: settings, the module guard (a module that errors turns itself off), `/jsal`.
- `Comms.lua`: addon messages between jsal.ui players, rate-limited, held in combat.
- `Style.lua`, `Window.lua`: the shared look and the dashboard.
- `Profile.lua`, `Installer.lua`: the EllesmereUI profile and its one-click install.
- `Games\`: Daily Word, Icon Guess and the flight offer. `Guild.lua`: the Guild tab.
- `Helpers\`: quests, vendor, level-up and warnings.

Nothing runs during combat, and jsal.ui reads no combat data.

## Flight times

`data\taxi\` holds the game's `TaxiPath` and `TaxiPathNode` tables as CSV, for the build in
`FlightData.lua`'s header (wago.tools serves each build's tables:
`https://wago.tools/db2/TaxiPathNode/csv?build=<version>`). After a patch, fetch both again and
run `python -I tools\build_taxi.py <version>` to rewrite `jsalUI\Games\FlightData.lua`. A flight's
time is its legs' yards over about 29.9 yards a second (measured on Forever) (20% faster with Frequent Flier), plus any
stops; each normal landing fine-tunes the speed.

## Talent trees

`data\talents\` holds the game's talent tables as CSV for the build in `TalentData.lua`'s header
(TraitNode, TraitNodeEntry, TraitNodeXTraitNodeEntry, TraitDefinition, TraitEdge,
TraitNodeGroup, TraitNodeGroupXTraitNode, SkillLineXTraitTree, Talent, TalentTab). After a
patch, fetch them again from wago.tools and run `python -I tools\build_talents.py <version>`.
Forever runs on the TraitNode tables, which are the source; the classic Talent tables only
name and order the trees. Talents parked far off the 7-by-4 grid are hidden ones and are left out.

## Trainer spells

`data\spells\` holds SkillLine, SkillRaceClassInfo, SkillLineAbility, SpellLevels, SpellName and
Spell (cut to its ID and NameSubtext_lang columns) as CSV for the build in `SpellData.lua`'s header. After a patch, fetch them again and run
`python -I tools\build_spells.py <version>`. A spell's level is SpellLevel (BaseLevel when that's
empty). Prices aren't in the files; the addon saves each class trainer's list when it opens, and
once a class has one, only spells a trainer lists are shown.

## Daily Word's words

`data\daily-word-answers.txt` holds the answers and `data\daily-word-guesses.txt` the extra
words accepted as guesses: the five-letter words of the ENABLE word list, which is public domain. `python -I tools\build_words.py` writes
`jsalUI\Games\DailyWordData.lua`. The play order lives in `data\daily-word-order.txt` and is
only ever added to: reordering it would change every future day's word.
