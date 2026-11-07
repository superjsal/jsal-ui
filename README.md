# jsal.ui

A free UI pack, daily games and easy helpers for WoW Forever, from [jsal.io](https://jsal.io).
Made for casual players: every part is small, has one switch, and is on by default (except Quests on autopilot, which you switch on in Settings).

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
| Journal | Your character's story from the day you install it, in four tabs. Summary: your character, favourite move and totals (foes, quests, deaths, gold and where it came from, distance, damage, healing, duels, jumps), with kills, quests, deaths and gold from the game's own statistics so they cover the whole life of the character. Story: levels, first kills of rares, dungeon bosses, blue and epic loot, deaths and their cause, profession ranks. By level: time, XP, XP per hour, gold in and out, kills, quests and deaths for each level. Characters: every character on the account with level, zone, gold, professions and rested XP. A screenshot at each level-up, and a recap of your session as you log out. |
| Dungeons | Every dungeon and raid on Forever, from the game's own files, in a picker grouped by level (10-20 up to 50-60, and raids), the ones right for your level in green, with where each entrance is and which side that is (Horde side, Alliance side, or neither when contested). The chosen one shows its bosses in order, ticked once you've killed them (with the game's own Boss Kills statistics, so it covers kills from before jsal.ui), and under each boss its loot: Wowhead Forever's list with drop chances, plus anything you've seen it drop (from the bosses you loot and the rolls after a boss dies, kept for every character on the account), and what guildmates with jsal.ui have seen it drop, with how often in the guild's kills ("guild 3 of 8"; a switch in Settings turns sharing off). A Quests tab lists the dungeon's quests for your faction, ticked once done. |
| Guild crafters | On the Professions page, search for what you need and see which guildmates can make it, online first, with a button to whisper them. Item tooltips name the guild's crafters too. Each jsal.ui shares the recipes its character knows. |
| Report a problem | At the bottom of the dashboard menu: say what went wrong and send it to John in game; your version, class, level, zone and any jsal.ui error are added for you. Outside John's guild, copy it to email instead. |
| Quick buttons | A small bar you drag anywhere: the dashboard, Daily Word, Icon Guess, chess, the shopping list, the Build Planner, the Training Planner and the layer you're in, with a gold dot when something's waiting. Choose its buttons in Settings or by right-clicking its grip, which also stands it up or locks it. |
| Layers | Reads which copy of a zone you're in from the creatures around you, and changes it through your guild: the quick bar's Layer button lists guildmates in your zone on another layer to join, asks in General, or tells your guild. You keep a layer while you're in that guildmate's group. Inviting guildmates who ask has a switch in Settings. |
| Minimap button | Opens the dashboard; right-click it for the same places as the quick buttons. Sits in EllesmereUI's Addon Buttons, or on the minimap without it. |
| Talent helper | When a point comes in, names the next talent in your build, with a Learn it button. |
| Quests on autopilot | Accepts and turns in quests. Hold Shift to do it yourself; reward choices stay yours. |
| Vendor run | Repairs and sells grey items at any vendor, and says what it spent and earned. |
| Level-up helper | Talent points and trainer ranks on each level, and what a trainer has for you. |
| Bags and gear warnings | A heads-up when bags are nearly full or gear is close to breaking. |
| The look | One-click install of the jsal.ui EllesmereUI profile (once it's added). |

## Install

1. Copy the `jsalUI` folder into `World of Warcraft\_forever_\Interface\AddOns`, or install it from CurseForge or Wago.
2. Log in, or restart the game if it was running, then type `/jsal`.

jsal.ui works on its own. [EllesmereUI](https://www.curseforge.com/wow/addons/ellesmereui), which is free, is only needed for the jsal.ui look.

## Betas

New parts that need longer testing come out as betas first (versions like `0.3.14-beta.1`), on the `beta` branch. To get them, set jsal.ui's release type to **Beta** in the CurseForge app or WowUp; everyone else only ever gets stable versions. A beta shows its version on the dashboard and in `/jsal version`, and Report a problem sends it with your report.

## Commands

| Command | What it does |
| --- | --- |
| `/jsal` | Opens or closes the dashboard |
| `/jsal word` | Today's Daily Word |
| `/jsal icons` | Today's Icon Guess round |
| `/jsal chess` | Your chess games |
| `/jsal shop` | Opens or closes the shopping list |
| `/jsal journal` | Your Journal |
| `/jsal recap` | This session's recap |
| `/jsal dungeons` | The dungeon guide |
| `/jsal bug` | Report a problem |
| `/jsal layer` | Which layer you're in |
| `/jsal waypoint` | Why the waypoint label is or isn't showing; `/jsal waypoint clear` removes the map's pin |
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
- `Talents\`, `Training\`, `Professions\`: the Build Planner and talent helper, the Training Planner and its panel, the profession roads and Guild crafters. `Trainers.lua`: where trainers stand.
- `Journal\`: the Journal's counting, its page and the session recap.
- `Helpers\`: quests, vendor, level-up, warnings, the minimap button, the quick buttons, layers and Report a problem.

Nothing heavy runs during combat. The Journal counts only your own damage, healing and kills, so busy fights stay light.

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

## Dungeons

`data\dungeons\` holds LFGDungeons, DungeonEncounter, ContentTuning (cut to ID and MinLevelSquish) and
Map (cut to ID, MapName_lang and InstanceType) as CSV from wago.tools for the build in
`DungeonData.lua`'s header. After a patch, fetch them again and run `python -I tools\build_dungeons.py`;
it stops if the game offers a dungeon it doesn't know yet, since where an entrance is isn't in the
files. A dungeon's level is the one it's tuned to; Season of Discovery's versions of some dungeons are
in the files under their own difficulties and are left out.

Loot and quests come from Wowhead Forever, in `data\dungeons\wowhead.json`: each dungeon's zone page
(its Quests tab, and its NPCs to find each boss) and each boss's NPC page (its Drops tab, with how
many kills Wowhead has seen and how often each item dropped). It's read in a browser, one page every
few seconds, since Wowhead turns away scripted downloads. A drop is kept when it's uncommon or better
and has dropped in at least 2% of 10 or more kills, or when the zone's own Drops tab names the boss.
The same build writes `DungeonLoot.lua` from it. Wowhead's numbers grow as more people play, so the
higher dungeons' lists fill in over time; read them again now and then.

## Daily Word's words

`data\daily-word-answers.txt` holds the answers and `data\daily-word-guesses.txt` the extra
words accepted as guesses: the five-letter words of the ENABLE word list, which is public domain. `python -I tools\build_words.py` writes
`jsalUI\Games\DailyWordData.lua`. The play order lives in `data\daily-word-order.txt` and is
only ever added to: reordering it would change every future day's word.
