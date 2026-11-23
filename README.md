# jsal.ui

**From level 1 to raid night in WoW Forever, planned.** One dashboard for the things you'd normally alt-tab for: when to visit the trainer, where your talent points go, what gear to chase, which dungeons are worth the run, and how to level your professions without going broke. Free, from [jsal.io](https://jsal.io/jsal-ui/).

![jsal.ui's dashboard](https://jsal.io/img/jsal-ui/store/cards-0362/01-home.jpg)

## Get it

1. Install it from [CurseForge](https://www.curseforge.com/wow/addons/jsal-ui) or [Wago](https://addons.wago.io/addons/jsal-ui). Or download the zip from [Releases](https://github.com/superjsal/jsal-ui/releases) and put the `jsalUI` folder in `World of Warcraft\_forever_\Interface\AddOns`.
2. Log in and type `/jsal`, or click the minimap button.
3. The first time, a short welcome shows you round and lets you switch off anything you don't want.

It needs WoW Forever (1.60.1) and no other addon.

## What's in it

### Plan

| Page | What it does |
| --- | --- |
| Training Planner | Which spells are ready at the trainer and what they cost, a pin on the nearest trainer, and every visit from here to 60. Pet and weapon training too. |
| Build Planner | Follow a ready-made leveling build for your class, or make your own and share it as a line of text. A card shows your next point and what it does. |
| Gear plan | The best upgrade for every slot, ranked for your spec, with where each piece comes from. Star what you're after. An "At 60" view shows your pre-raid set slot by slot. |
| Dungeon guide | Every dungeon by level. Each boss has a card with its best drops for you and their drop chances, the quests to pick up first, and a map. |
| Endgame | Your page for 60: how far along your pre-raid set is, what to bring to raid night and what it costs, your raid lockouts and long cooldowns. |

### Craft

| Page | What it does |
| --- | --- |
| Professions | The cheapest way to your next rank: what to craft and how many, where to learn or buy each recipe, and one click to make a shopping list. |
| Guild Crafts | See who in your guild can make what, and place orders with each other. |
| Crafting profit | What each recipe costs to make against what it sells for. |

### Play

| Page | What it does |
| --- | --- |
| Journal | Your character's story as you play: levels, deaths, loot, time and gold, and all your characters at a glance. At 60 it turns to boss kills and raid nights. |
| Daily games | Daily Word, Icon Guess and Pal run: one of each a day, the same for everyone, with your guild's results side by side. |
| Jsal's Pals | Hatch an egg, name what comes out and look after it. It grows up and wanders along your screen while you play. |

### And the little things

Quick buttons, a flight bar that times your flights, a waypoint label, a vendor run that repairs and sells your greys, warnings before your bags fill or your gear breaks, quest tags, an arrow on quest rewards that are upgrades, a food reminder, and for hunters pet feeding, a range check and what a beast would teach your pet. Each one is described on the [store page](https://www.curseforge.com/wow/addons/jsal-ui).

## Commands

`/jsal` opens the dashboard. Add a word to go straight somewhere:

| Command | Opens |
| --- | --- |
| `/jsal journal` | The Journal |
| `/jsal gear` | The Gear plan |
| `/jsal dungeons` | The Dungeon guide |
| `/jsal crafts` | Guild Crafts |
| `/jsal profit` | Crafting profit |
| `/jsal shop` | Your shopping list |
| `/jsal word`, `icons`, `run` | The daily games |
| `/jsal pet` | Your pal |
| `/jsal recap` | A recap of your session |
| `/jsal welcome` | The welcome, again |
| `/jsal unlock` | Move jsal.ui's pieces around the screen |
| `/jsal bug` | Report a problem |

## Good to know

- **Almost everything is on to start.** The talent helper and the gear goal for 60 are the two you switch on yourself. Every part has its own switch in Settings.
- **It stays out of the way in a fight.** Nothing heavy runs in combat, and jsal.ui never reads the combat log.
- **What guildmates share stays between guildmates.** Scores, recipes, orders and boss loot go over hidden addon messages, never in chat.
- **It works alongside** [EllesmereUI](https://www.curseforge.com/wow/addons/ellesmereui) and RestedXP Guides, and uses Auctionator's prices for Crafting profit when you have it. None of them is needed.
- **Its own text is in English.**

## Where the data comes from

- Stat weights, level 60 sets and raid consumables: [WoWSims Forever](https://github.com/wowsims/forever).
- Items, drop chances, recipe sources and leveling builds: [Wowhead](https://www.wowhead.com/forever)'s Forever pages.
- Quests, trainers and vendors: [pfQuest](https://github.com/shagu/pfQuest) and [EG Link](https://github.com/JIVESCORP/eg-link-output-wowf) (data from [Efficient Games](https://efficient.games)).
- The maps of Forever's own dungeons: Santiago Reyes, from his *Atlas de Azeroth: Forever*, used with his permission. See more at [sreyesmaps.com](https://sreyesmaps.com).
- Everything else: the game's own tables.

How each table is rebuilt is in [`tools/README.md`](tools/README.md). Who made what, and on what terms, is in [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).

## Say hello

Found a bug or have an idea? Come to [jsal.ui's Discord](https://discord.gg/BfUKeCjNeZ), use **Report a problem** in the dashboard (`/jsal bug`), or email [dev@jsal.io](mailto:dev@jsal.io).

What changed in each version is on [jsal.io/jsal-ui/updates](https://jsal.io/jsal-ui/updates/).

## Licence

jsal.ui's code is free to use under the [MIT License](LICENSE): read it, learn from it, fork it.

Its pictures, sounds and name are jsal's and stay with jsal.ui: the pals, the icons, the logo and the name
"jsal.ui". A fork needs its own.

Some parts are other people's and keep their own terms: Santiago Reyes's dungeon maps (used with his permission),
the Outfit and Inter fonts, data from WoWSims, pfQuest and EG Link, and the game's own data. Who made what is in
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).
