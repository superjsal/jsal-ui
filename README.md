# jsal.ui

A free UI pack, daily games and easy helpers for WoW Forever, from [jsal.io](https://jsal.io).
Made for casual players: every part is small, on by default, and has one switch.

## What's in it

| Part | What it does |
| --- | --- |
| Daily Word | One five-letter word a day, the same for everyone, six tries. Share your grid to guild chat. |
| Icon Guess | Name the spell from its icon. A daily round of ten, the same for everyone, plus practice rounds. |
| Flight bar | While you fly, at the top of the screen: the route, the time left, and buttons for Daily Word, Icon Guess and chess with a gold dot when one's waiting. Times come from the game's own flight tables. |
| Chess | Play guildmates who have jsal.ui, a few games at once, with a win-loss record against each. Moves wait for whoever's turn it is, even across logouts. Guildmates' games show under Watching, to follow as they're played. No computer opponent, to keep jsal.ui light. |
| Guild tab | Guildmates who run jsal.ui, their version and today's scores, and the Guild Word the guild master sets. |
| Build Planner | Any class's three Forever trees in the dashboard, with a ready-made leveling build for each class (Rogue to come) from Wowhead's Forever leveling guides, to follow or copy. A build shows level by level, with what's taken and what's next; Learn next points spends waiting points in its order; Edit opens the trees. Builds are saved for the whole account and shared as Wowhead talent calculator links or short codes. |
| Training Planner | Your next trainer visit and its cost, your road to 60, and every spell: ready now, coming soon, later, skipped, plus weapon skills. Spells come from the game's files; prices from class trainers you've opened. A panel beside the spellbook and trainers shows what's ready, with the nearest trainer and a map pin. |
| Professions | Each profession's road to the next rank: what to craft, what it needs and the nearest trainer, in the dashboard and beside the profession window. In the game's profession window: where each recipe turns yellow, green and grey, reagents in bags and bank, a timer while you craft several, recipes you haven't learned (star the ones you want, and a profession trainer offers them), and a heads-up when you can train the next rank. |
| Shopping list | What you mean to craft and other items you want, and what's left to buy once your bags and bank are counted, with vendor prices and auction prices from your own searches. A vendor who sells something on it offers to buy it for you. |
| Quick buttons | A small bar you drag anywhere: the dashboard, Daily Word, Icon Guess, chess, the shopping list and the Build Planner, with a gold dot when something's waiting. Right-click its grip to choose the buttons, stand it up, or lock it. |
| Minimap button | Opens the dashboard; right-click it for the same places as the quick buttons. Sits in EllesmereUI's Addon Buttons, or on the minimap without it. |
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
| `/jsal chess` | Your chess games |
| `/jsal shop` | Opens or closes the shopping list |
| `/jsal games`, `/jsal guild`, `/jsal settings`, `/jsal install` | Opens that page |
| `/jsal version` | Prints the version |
| `/jsal perf` | How long jsal.ui took to load |

## How it's built

- `Compat.lua`: every Blizzard call that has moved between versions, in one place.
- `Core.lua`: settings, the module guard (a module that errors turns itself off), `/jsal`.
- `Comms.lua`: addon messages between jsal.ui players, rate-limited, held in combat.
- `Style.lua`, `Window.lua`: the shared look and the dashboard.
- `Profile.lua`, `Installer.lua`: the EllesmereUI profile and its one-click install.
- `Games\`: Daily Word, Icon Guess, the flight offer and chess (its rules, games and page). `Guild.lua`: the Guild tab.
- `Talents\`, `Training\`, `Professions\`: the Build Planner and talent helper, the Training Planner and its panel, the profession roads. `Trainers.lua`: where trainers stand.
- `Helpers\`: quests, vendor, level-up, warnings and the minimap button.

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

## Leveling builds

`data\talents\suggested.json` holds one Wowhead Forever talent calculator link per class, copied
from Wowhead's Forever leveling guides. `python -I tools\build_suggested.py` turns them into
`jsalUI\Talents\SuggestedBuilds.lua`, checking every point against `TalentData.lua` with the
game's rules; a link that doesn't fit Forever's trees stops it. A link's order is one character
per point for the talent's place in its tree (in TalentData's order), from two tables in Wowhead's
calculator code: `abcdefghjkmnpqrstvwzxyilou468-~!` for one point and
`ABCDEFGHJKMNPQRSTVWZXYILOU579_^.` for "to full rank". Export and Import use the same tables.

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
