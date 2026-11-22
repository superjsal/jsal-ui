# Building jsal.ui's data

How the addon's code is laid out, and how each table it ships is rebuilt from the game's files, Wowhead and
the other sources. None of this is needed to use jsal.ui. `wowhead\README.md` beside this has the monthly steps.

## How the code is laid out

- `Compat.lua`: every Blizzard call that has moved between versions, in one place.
- `Core.lua`: settings, the module guard (a module that errors turns itself off), `/jsal`.
- `Comms.lua`: addon messages between jsal.ui players, rate-limited, held in combat.
- `Style.lua`, `Window.lua`: the shared look and the dashboard. `Home.lua`, `Settings.lua`: its first page and its switches. `Onboarding.lua`: the welcome.
- `Profile.lua`, `Installer.lua`: for a look to install. No version ships one yet, so nothing offers it.
- `Games\`: Daily Word, Icon Guess, Pal run, the flight bar, and chess (put away for now). `Guild.lua`: the Guild tab. `Pet\`: Jsal's Pals.
- `Talents\`, `Training\`, `Professions\`: the Build Planner and talent helper, the Training Planner and its panel, the profession roads, the shopping list, Crafting profit and Guild Crafts. `Trainers.lua`: where trainers stand.
- `Gear\`, `Dungeons\`, `Quests\`: the gear plan, the dungeon guide, and the quest tags with the drop log.
- `Journal\`: the Journal's counting, its page and the session recap.
- `Helpers\`: vendor, level-up, warnings, the minimap button, the quick buttons, Unlock Mode, the waypoint label, the bag button, the menu bar look, the food and pet-feeding tiles, the range check and Report a problem.

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

Prices no visit has, the weapon masters and what each teaches, and one pet trainer come from every
trainer players opened on Forever, in
[EG Link output: World of Warcraft: Forever](https://github.com/JIVESCORP/eg-link-output-wowf): data from
[Efficient Games](https://efficient.games), licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/),
reduced here to each trainer's name, spots, services, levels and costs (`data\trainers\eglink-trainers.json`,
kept by `tools\refresh_eglink.py`). `tools\build_spells.py` and `tools\build_trainers.py` read it; the second
also writes `data\trainers\ranks-seen.txt`, the highest profession rank each trainer was seen to sell.

## Raid night consumables

The Endgame page's RAID NIGHT card lists WoWSims Forever's consumables for your spec
(`jsalUI\Endgame\ConsumablesData.lua`), built by `python -I tools\build_consumables.py`. Its sources are in
`data\gear\wowsims-forever\consumables\`, fetched at the commit in its `COMMIT`: each spec's `defaults.siml`
(`consumables:`) where it has one, else its `presets.ts` (`DefaultConsumables`, and a set's own such as
`ArmsConsumables`), named `<class>_<spec>_...` as under `ui/specs/`, and `consumables_auto_gen.ts` for the item IDs.
How long each lasts is the game's: the item's use spell (`ItemXItemEffect`, `ItemEffect`), the aura it or a spell
it sets off puts on you (`data\spells\SpellMisc.csv`, cut to ID, DifficultyID, DurationIndex and SpellID and to the
rows with a duration, and `SpellDuration.csv`), or a weapon stone's or oil's seconds (`SpellEffect` 54). Potions,
runes, explosives and anything under two minutes are used in the moment. Which spec each talent tree and each At 60
set is sits at the top of the tool. A spec WoWSims gives no list for has none (Retribution paladins' are per build
file; Elemental shamans have none). `tools\what_changed.py` says when files that name consumables change upstream.

## Long profession cooldowns

The Endgame page lists each character's long cooldowns (`jsalUI\Journal\CooldownData.lua`), built by
`python -I tools\build_cooldowns.py <version>` from `data\spells\` and `data\professions\` (SpellCooldowns,
SpellCategories cut to the rows with a category and to ID, DifficultyID, Category and SpellID, SpellEffect,
SpellReagents, ItemEffect, ItemXItemEffect and ItemSparse). A cooldown counts at 20 hours or more (the game's
"daily" ones are 23); recipes that share a category are one line, named by what their names share before the
colon ("Transmute"); an item counts when its own spell has such a cooldown and makes a profession's reagent (the
Salt Shaker). After a patch, fetch SpellCategories and ItemXItemEffect again with the others and run it.

## Dungeons

`data\dungeons\` holds LFGDungeons, DungeonEncounter, ContentTuning (cut to ID and MinLevelSquish) and
Map (cut to ID, MapName_lang and InstanceType) as CSV from wago.tools for the build in
`DungeonData.lua`'s header. After a patch, fetch them again and run `python -I tools\build_dungeons.py`;
it stops if the game offers a dungeon it doesn't know yet, since where an entrance is isn't in the
files. A dungeon's level is the one it's tuned to; Season of Discovery's versions of some dungeons are
in the files under their own difficulties and are left out.

The Map tab's `DungeonMaps.lua` is built by `python -I tools\build_dungeon_maps.py` (`--report` says
what matched). Forever's files have each dungeon's map pictures but no table of where a boss stands;
later versions of the game have, for the same pictures, in the dungeon journal. `data\dungeons\journal\`
holds JournalEncounter, JournalEncounterCreature (a boss's model, for its picture; only the rows whose
model Forever has), JournalInstance, UiMap and UiMapAssignment from two such builds, cut to the
columns the tool reads. A dungeon is left out when fewer than half its bosses are found there: the
ones rebuilt before the journal came (Scarlet Monastery, Scholomance, The Stockade, Shadowfang Keep,
Sunken Temple, Zul'Gurub). Forever's own dungeons have no map picture: theirs are Santiago Reyes's,
from Atlas de Azeroth: Forever (sreyesmaps.com), with his leave and his credit under each, a picture a
floor in `jsalUI\Media\Maps\` made by `python -I tools\build_map_art.py <folder>` from his full-size
maps (not kept here); the tool's `ART` names each floor. No boss is placed on them.

Loot and quests come from Wowhead Forever, in `data\dungeons\wowhead.json`: each dungeon's zone page
(its Quests tab, and its NPCs to find each boss) and each boss's NPC page (its Drops tab, with how
many kills Wowhead has seen and how often each item dropped). It's read in a browser, one page every
few seconds, since Wowhead turns away scripted downloads. A drop is kept when it's uncommon or better
and has dropped in at least 2% of 10 or more kills, or when the zone's own Drops tab names the boss.
The same build writes `DungeonLoot.lua` from it. Wowhead's numbers grow as more people play, so the
higher dungeons' lists fill in over time; read them again now and then (`tools\wowhead\README.md` has the monthly steps).

## Gear plan

`data\gear\wowhead-items.json` holds every uncommon and better armor piece, jewel, cloak and weapon on
Wowhead Forever's gear lists, read slot by slot in a browser (Wowhead turns away scripted downloads), with
where each comes from. `data\gear\zones.json` names the zones (the game's AreaTable).
The stat weights, what a point of each stat is worth to a spec, are WoWSims': its Forever
simulator's presets where it has one for a talent tree (`data\gear\wowsims-forever\`, from
[wowsims/forever](https://github.com/wowsims/forever), MIT, with `LICENSE` and the commit beside them);
for the hunter, mage and warlock, which it ships none for, what its own Stat Weights tool works out on
its own preset talents and gear (`data\gear\wowsims-forever\computed\`, each saying how); for the
paladin, shaman and druid healers, its healing priest's set, since it simulates no healer. Every tree
is on Forever's now; its Classic simulator's files (`data\gear\wowsims\`, from
[wowsims/classic](https://github.com/wowsims/classic), MIT) are kept for `tools\build_gear.py` to fall
back on. `python -I tools\build_gear.py` writes
`jsalUI\Gear\GearData.lua`: the items as one line of text per slot, so they cost little memory until the
gear plan opens, and the weights, crit and hit per 1%, with Stamina at least a tenth of a spec's main
stat for leveling. Item names and stats come from the game while you play. `tools\wowhead\` reads the lists again; its README has the monthly steps.

## Quest tags

`data\quests\pfquest.json` holds what the tags need from [pfQuest](https://github.com/shagu/pfQuest)
(MIT licence, `data\quests\pfquest\LICENSE`), whose database has Classic's numbers from VMaNGOS: each
quest's earlier quests and races, and how often each item a quest asks for drops from each creature.
`python -I tools\build_quest_scores.py --from <pfQuest checkout>` reads pfQuest's files again (as data, never
run), and `python -I tools\build_quest_scores.py` writes `jsalUI\Quests\QuestScoreData.lua` from it: each
quest's place in its chain, counting only quests one character can do, and the best drop chance of each
item, one line of text per quest. What's left of a quest comes from your quest log while you play.

Quests new to Forever, and Forever's own next-quest links, come from
[EG Link output: World of Warcraft: Forever](https://github.com/JIVESCORP/eg-link-output-wowf): data from
[Efficient Games](https://efficient.games), licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/),
reduced here to each quest's level, next quest, races and the items it asks for (`data\quests\eglink.json`;
`build_quest_scores.py --eglink <folder of its quests.enUS.json files>` reads them again). How often those items
drop comes first from EG Link's players who had the quest when they looted (`data\quests\eglink-drops.json`,
`build_quest_scores.py --egloot <folder of its loot.json files>`; a creature needs 10 such kills), which
is the only fair count: a quest item drops only for someone on the quest. Failing that, Classic's quests
keep pfQuest's chance, and new ones take Wowhead Forever's from its item pages (`data\quests\wowhead-drops.json`,
read in a browser by `tools\wowhead\drops.js`; the steps are in `tools\wowhead\README.md`), but only where
it can be trusted: Wowhead counts every kill, with the quest or without, so Ghoul Fang shows 14-25% there
against 80% on the quest. A creature's rate is used only when at least half its kills dropped the item (a
named target everyone kills for the quest); an object's rate per opening is used as it is. In game, the
Drop log's own counts win once an item has 10 loots.
EG Link's counts grow every day: `python -I tools\refresh_eglink.py` reads its latest quests and loot and
rebuilds the data in one go (monthly).
The Drop log's own counts ship too: `python -I tools\bake_drops.py <a copy of jsalUI.lua>` reads them from a copy
of the saved file into `data\quests\own-drops.json`, and the build pools them with EG Link's (both count only loot
while the quest needs it) or, where EG Link has none, uses them alone once an item has 10 loots.

## Daily Word's words

`data\daily-word-answers.txt` holds the answers and `data\daily-word-guesses.txt` the extra
words accepted as guesses: the five-letter words of the ENABLE word list, which is public domain. `python -I tools\build_words.py` writes
`jsalUI\Games\DailyWordData.lua`. The play order lives in `data\daily-word-order.txt` and is
only ever added to: reordering it would change every future day's word.
