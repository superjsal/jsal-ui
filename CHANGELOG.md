# jsal.ui 0.3.52

- **Quest reward star.** When a quest lets you choose a reward, a gold star marks the one the Gear plan scores the biggest upgrade for your spec, in the quest window, the quest log and the map. Point at a reward for how much better it is for you ("Best of these for you: +4%"). Nothing is starred when no reward is better than what you wear. Turn it on in Settings, Leveling: Quest reward star.
- **Pet feeding, for hunters.** While your pet is out and not happy, a glowing tile shows beside the food reminder: click it to feed your pet, or point at it for the food in your bags your pet eats and click one. It hides in a fight and once your pet is happy, and drags anywhere. Turn it on in Settings, Around the UI: Pet feeding.

## In 0.3.51

- **Jsal's Pals: more to do together.** Move the pointer to and fro over your pal to stroke it: it leans into your hand with its eyes shut, and after a few strokes does a happy dance of its own. Now and then it hides in its pen behind a bush or a rock: click where it is to find it. While you quest it sometimes finds a little something, a few things in every zone, and keeps them on a new shelf on its page. And it perks up when mail comes (it brings you a letter) or someone whispers you. Catching a tossed treat is easier to time: the treat sparkles and your pal gets ready to leap for the moment it can be caught, and that moment is about twice as long. All of it comes with Jsal's Pals, with nothing to turn on.
- **Gear plan: "of Frozen Wrath" and other one-school greens count.** Spell damage of one school, like a Frost, Fire or Shadow Wrath green's, now counts for the trees that cast it, by WoWSims' own weights: fully for a Frost mage's Frost or a Shadow priest's Shadow, in part where a tree casts two schools, and not at all for anyone else.
- **Flight bar: the game's own land-early button stays out of the way.** While the flight bar shows, the game's vehicle exit button (which Edit Mode can't move or hide) is hidden, since the bar's "Land at ..." does the same. It's back once you land.

## In 0.3.50

- **Gear plan: stat weights from WoWSims Forever's latest.** Hunters now use the weights WoWSims Forever ships for them (its own until now were worked out by hand from its tool); mages' are worked out again on its new pre-raid gear; warriors take its re-tuned Arms, Fury and Protection sets. The changes are small: crit and hit count a little less for hunters and mages, and Agility a little less for Fury.
- **Fresher data from the latest Forever build and from players.** Spells and talents are read from the game's newest build (a rogue's Shank Rank 2 now shows on the Training planner), and quest tags, trainer prices and vendors are refreshed from what players have seen since: some quest items drop less often than the old numbers said, so a few quests read longer.
- **Gear plan: "checking..." no longer needs a /reload.** While it waits on items, the Gear plan now looks again by itself every couple of seconds, and gives up on one the game still hasn't sent after about ten seconds, so the page settles.
- **Shopping list: supply vendors in every town.** The list only knew the vendors other players had opened, so it could send you to another city for thread, dye or vials. It now knows every seller Wowhead lists for them: Ironforge and Darnassus go from a handful of supplies to nearly all of them.

## In 0.3.49

- **Gear plan: a piece that isn't better says so.** A piece you added or carry comes first in its slot whatever it scores, and was tagged "best for you" with only what it adds ("+12 AP"). The tag is now the best real upgrade's, and such a piece reads "worse than yours" with what you'd gain and lose ("+12 AP, -5 Agi"), as does its star line on tooltips.
- **Gear plan: an item you add always shows.** An item you added by its ID or link could be added and starred but not appear in the list when it's also one the plan knows and no better than what you wear. It now shows, starred at the top, however it compares, so you can weigh it yourself. And an upgrade that was slow to load could stay "checking..." in 0.3.48: the plan now asks again after a couple of seconds.

## In 0.3.48

- **Dungeon guide: loot for every boss from 50 to 60, and the raids.** Blackrock Spire, Dire Maul, Stratholme, Scholomance, Zul'Gurub, Molten Core, Blackwing Lair and Onyxia's Lair now list their bosses' loot with drop chances, and the new dungeons' quests say where they start. Loot for other classes (a "Classes:" line that doesn't name yours) folds away at the foot of the boss.
- **Gear plan and dungeon guide: much lighter.** A redraw could take 60 ms, a hitch you could feel; it now does most of its work once and keeps it.
- **/jsal perf names jsal.ui's slow moments,** if you ever want to see what takes time.

## In 0.3.47

- **Dungeon guide: five more dungeons, and much more loot.** The Drowned City (35), Krol'dok Stronghold (40), Alcaz Prison (48), Blackmaw Hold (55) and The Shaper's Terrace (60) are in, with their bosses, loot and quests. Zul'Farrak, Maraudon, Sunken Temple and Blackrock Depths now list loot for their bosses, where most had none.
- **Gear plan: filter by source, and how much better each upgrade is.** Chips over a slot's upgrades show only the kinds you pick (Dungeon, Quest, Vendor, Crafted, World drop...), and each card leads with its gain, "+3%". The first column is headed "Currently equipped".
- **Training planner fixes.** Explosive and Immolation Trap are listed once, at their full price; rank-ups no longer go missing right after you log in; and where trainers charged you differently, the full price is shown.

## In 0.3.46

- **Gear plan: hunters, mages and warlocks weigh stats by Forever's own simulator.** WoWSims' Forever simulator ships no weights for them, so they used its Classic ones, and a hunter's 1% crit counted as about two Agility where it's worth about twelve. They're now what its own Stat Weights tool works out on its own talents and gear, one set for each mage and warlock tree, where the three trees shared one. A hunter's crit and hit now count like every other class's, and an item's Attack Power counts as ranged attack power for a hunter.
- **Gear plan: Holy paladins, Restoration shamans and Restoration druids weigh stats like Forever's healers.** WoWSims' Forever simulator can't simulate a healer, and the Classic numbers they used were placeholders that gave mana every 5 seconds nothing. They now use its one healer set made for Forever, the healing priest's: healing first, then Intellect and Spirit, with mana every 5 seconds counting.

- **Gear plan and dungeon guide: a word on stat weights.** The Gear plan's footnote says its stat weights are estimates from WoWSims' Forever sims at level 60, a guide and not the last word, and that you can change them under Weights. Under a dungeon's loot, a line says "for you" is by those weights: roll by what you know of your spec.
- **Gear plan: one Crit and one Hit under Weights.** Forever's items have one crit and one hit for spells and weapons alike, and Weights listed Spell Crit and Spell Hit as well, always the same numbers. They're gone; Crit and Hit stand for both, and a Pawn scale's spell crit and spell hit are read as Crit and Hit.
- **Dungeon guide: "+N% for you" is against all you wear.** It was a share of the one piece an upgrade replaces, so a slot whose piece counts for little (a hunter's two-hander, which is worn for its stats) made a polearm "+474% for you". It's now a share of everything you wear, so the same polearm reads about "+16%".
- **Gear plan: Attack Power counts for a hunter again.** Crit and hit, which are weighed per 1%, set the bar for what counts as one of your spec's main stats, and a hunter's Attack Power fell under it: a belt with more of it was "nothing here is better". Only stats weighed by the point set it now.
- **Gear plan: before your first talent point, the tree your class levels in.** With no talents, the Gear plan and the dungeon guide used your class's first tree, so a new paladin was told healing gear was best (Holy), a new priest the same (Discipline), and a new druid got Balance's. They now get Retribution, Shadow and Feral; a shaman Enhancement, a rogue Combat, a mage Frost.

## In 0.3.45

- **Gear plan: crit and hit are counted right.** Forever gives an item's crit and hit as rating (14 for 1% crit, 10 for 1% hit), and the Gear plan, the dungeon guide and the stars read 14 as 14%, so a piece with crit or hit looked like a far bigger upgrade than it is. They're now read as the 1% they are, and what an upgrade adds says "+1% Crit". Dodge, parry and block too. A mage's, warlock's or healer's crit and hit now count as well: Forever's items give one crit for spells and weapons alike.
- **Quest tags: "XP/min in combat".** The card's "Pays 2,450 XP: about 2,450 XP a minute" counted only the fights, not getting there, so a quest with one kill far away read as a great deal. It now reads "2,450 XP · 2,450 XP/min in combat".

## In 0.3.44

- **Quest tags: truer drop chances.** A quest item drops only for someone on the quest, and Wowhead counts every kill, so its numbers made quests from busy creatures look several times longer than they are. Now a chance comes first from players who had the quest when they looted (EG Link), then, for Classic's quests, from Classic's own numbers. Wowhead's is used only for a named target nearly everyone kills for the quest, or a chest or plant. Where none of those is known the tag says "?" rather than a number that's far too high.
  - **Your own loot counts.** With the Drop log on, the card blends your own loot into the chance from your first find, so a lucky or unlucky start doesn't swing it, and says how many of your loots it's from.
- **Quest tags: what a quest pays.** The card now says what a quest pays and how much that comes to a minute ("Pays 2,550 XP: about 213 XP a minute"). For a quest in your log it's the game's own figure for you; for one you haven't taken, the quest's XP less what Forever takes off when you're well above it: 80% at 6 levels over, 60% at 7, and half from 8 on.
- **Quest tags: minutes for a quest you haven't taken.** On RestedXP's "Accept" steps the tag showed only the quest's place in its chain, since the game tells nothing of a quest's objectives until it's in your log. It now counts the minutes from the quest's full objectives, and the card says so.
- **Quest tags: the Drop log's counts come with the addon.** How often quest items dropped for the Drop log, counted only while the quest still needed them, is shipped with the addon and pooled with players who had the quest, so everyone's tags start from it.
  - **Your guild's counts on the card.** With the Drop log's guild sharing on, the card blends in your guild's loots too and says so ("from your own 10 loots and your guild's 30 loots").

- **Drop log: each corpse counts by itself.** The game says which corpse each thing in a loot window came from, so a window opened for several corpses counts each of them, with what that one had. It counted the creature you had targeted, once, for the whole window. You no longer need the corpse targeted for a loot to count, and what's in a chest or lying on the ground is never counted as the loot of a creature you still have targeted.

- **Training planner: the weapon masters ship with the addon.** Pointing at a weapon skill names who teaches it, on your own side, without your having opened a weapon master first: Woo Ping, Buliwyf Stonehand and Ilyenia Moonfire for the Alliance; Sayoc, Hanashi, Ansekhwa, Archibald and Gabbi Goodwhistle for the Horde. A few skills haven't been seen for sale yet, and those still say so.
- **Training planner: Two-Handed Maces is on the list.** It was missing for warriors, paladins, shamans and druids, who learn it from a weapon master.
- **Training planner: a few more prices.** A hunter's traps, a priest's Touch of Weakness and a mage's teleports and portals had none. They come from what other players' trainers charged; where you've opened a trainer yourself, its prices are still the ones used.

- **Shopping list: it says which vendor to go to.** Under what a vendor sells, a line names the vendor of your side that sells the most of what you still need, the nearest of those ("All three at Edna Mullby, Stormwind City"), and a click on it puts a map pin on them. When one vendor doesn't have it all, a second line says where to get the rest. The vendors are the ones players have opened on Forever; a few vendor goods have no known seller yet. The next heading is shorter too: it ran under its own total.
- **Drop log: share your counts with your guild (new, off to start).** A switch under Drop log in /jsal settings. With it on, your addon tells guildmates who have it on how often each quest item has dropped for you, and adds their counts to yours, so everyone's quest tags learn faster. Only the item's name and two numbers are sent, over the game's hidden addon channel, and each guildmate's newest word replaces their last.
- **Professions: Artisan Enchanting names its trainer.** It's taught inside Uldaman, by Annora, a Master Enchanter; the panel said it didn't know a trainer for it.
- **Professions: First Aid's Artisan is at 225.** The quest that leads to Triage is given at First Aid 225; the panel said 200.

- **Dungeon guide and Gear plan: any real upgrade counts, and says how much.** A piece better than what you wear was left out when a far bigger upgrade for that slot could be had somewhere else: a feral druid in Razorfen Downs was told nothing there was better while Swine Fists beat his gloves by about a fifth. Now any gain counts, and a dungeon's loot says how much ("Hands · Leather · +24% for you"). A piece that wins only on Stamina, or on a stat your spec barely uses, still isn't called better.
- **Gear plan: stat weights made for Forever.** Where WoWSims' Forever simulator has weights for your talent tree (warriors, rogues, priests, Retribution, Protection, Elemental, Enhancement, Balance and Feral), the plan and the dungeon guide use them. Hunters, mages, warlocks and the paladin, shaman and druid healers keep WoWSims Classic's. Weights you've changed yourself, or a Pawn scale you pasted, stay as you set them.
  - **A hunter's Agility counts for what it gives:** 2 ranged attack power a point and some crit. It counted for under a third of that, so a piece with lots of Stamina and a little Strength could be called better than one with Agility.
  - **Healers count items that add healing.** An item with only "+Healing" counted for nothing.
  - **Stamina, the same rule for every class:** a tank's tree weighs it as a tank does (a Protection paladin now takes the warrior tank's weights), and every other tree counts it a little, a tenth of its main stat.
- **Flight bar: flight paths from Forever's latest build.** Checked against 67 routes players timed: nine in ten of its times are within half a percent.

- **Settings: the two new parts' cards say what they do.** Quest tags on RestedXP and the Drop log showed the start of a long sentence, cut off. Each now has a short line and a picture like the other cards.

## In 0.3.43

Coming from 0.3.42 or earlier, restart the game after updating (exit and start it again): 0.3.43 added new files, and a /reload doesn't load them.

- **Quest tags on RestedXP (new, off to start).** For when you follow RestedXP's guide window and keep the quest tracker hidden. Left of the window, beside each step that has you take or do a quest, the same tag Quest tags puts by the tracker: the quest's place in a chain, and about how many minutes it will take. The tags follow the window when you move it, and hovering one shows the reasons. Turn on **Quest tags on RestedXP** under Leveling in /jsal settings; it works with Quest tags on or off, and on both of RestedXP's guide windows. /jsal guidetags says what it sees if a tag looks wrong. For now a quest you haven't taken yet may show only its place in a chain.
- **Drop log (new, off to start).** Counts how often the creatures you loot have the quest items you're after, so the addon can learn Forever's own drop chances where few players have been yet. It counts quest items only, while a quest in your log still needs them, and what it counts stays on your computer. Turn on **Drop log** under Leveling in /jsal settings; /jsal drops shows what it has so far. Nothing uses the counts yet: the plan is for quest tags to take your own numbers once an item has ten loots behind it. (In 0.3.44 they do, blended with the addon's own chance from your first find.)
- **Training planner: a pet ability's cost no longer runs under "Teach now".** The cost in training points now stands at the right of the row, and the heading says it's ready.
- **Training planner: an ability your pet can't afford isn't called ready.** It goes under "Not enough training points", and pointing at it says how many your pet has and how many it's short. The planner never knew how many training points your pet had free; it does now, and says so beside your pet's name.

## In 0.3.42

- **Professions: your road leaves out recipes you'd have to wait on.** Mooncloth can be made once in four days and a transmute once an hour, and the road took them like any other: Tailoring's ran through 63 Mooncloth, Alchemy's through 45 transmutes. One is now on the road only when nothing else gives a point.
- **Professions: your road leaves out recipes that need a specialisation you may not have.** A Goblin or Gnomish Engineer's, an Armorsmith's or Weaponsmith's, a Dragonscale, Elemental or Tribal Leatherworker's: these are on the road only once you know them.
- **Professions: a specialisation's trainer isn't named for Artisan.** A Master Goblin Engineer teaches goblin recipes and no rank, but the panel could send you to one for Artisan Engineering. The same goes for the gnomish, dragonscale and shadoweave trainers.
- **Professions: Mining and Cooking name a trainer who teaches the rank.** A Junior Mining Trainer teaches Apprentice only and is no longer named for more. Cooking trainers teach up to Journeyman, and the panel named any cook for the ranks past it: it now says Expert comes from The Expert Cookbook, sold by Shandrina in Ashenvale or Wulan in Desolace, and Artisan from the quest Clamlette Surprise, given by Dirge Quikcleave in Gadgetzan. First Aid names its own too: Deneb Walker in Arathi Highlands or Balai Lok'Wein in Dustwallow Marsh for the book, and the doctor who gives Triage, Gustaf VanHowzen in Dustwallow Marsh or Gregory Victor in Arathi Highlands. A click puts a map pin on whoever it names. The alert when a rank is ready says the same, where it said to train it.
- **Training planner: a weapon skill names the weapon masters who teach it.** It said any weapon master would do, and each teaches only some weapons. Once you've opened a weapon master, pointing at a weapon skill says who teaches it; until then it says to visit one.
- **Training panel: seven more pet trainers are known by name.** The list had two. Karrina Mekenda, Belia Thundergranite, Silvaria and four others are on it now, so the panel knows it's standing in for a pet trainer even when you've bought everything they sell.

## In 0.3.41

- **Professions: the trainer named for your next rank is one who teaches it.** A trainer's title is one step above what they teach: an Expert Leatherworker teaches Journeyman, and Expert is learned from an Artisan. The panel read the title as the rank, so it sent you to the wrong trainer for Expert and Artisan. Where no trainer for a rank is known, none is named.

## In 0.3.40

- **Professions: your road keeps to orange and yellow recipes.** A green recipe is now a last resort, taken only when there's nothing else you can make. The road used to pick one whenever it would use up leftovers in your bags or bank, and a green recipe can take ten crafts to give a point.
- **Professions: a material in your bank is said to be there.** The step in hand read "you have enough" for things that were in the bank; it now says how many to fetch from it.

## In 0.3.39

Coming from 0.3.38 or earlier, restart the game after updating: 0.3.39 added new files.

- **Quest tags (new, off to start).** For when you're ahead of your guide and want to drop the slow quests. Left of each quest in your tracker, a small tag with two things:
  - **Its place in a chain.** "1/4" is the first of four, so skipping it loses the three after it. No tag means it stands alone.
  - **About how many minutes it will take**, green to red: the kills still needed, from how often its items drop, times how long your own fights last. It counts on a slightly unlucky run, not a lucky one, and drops as you make progress. "?" means how often an item drops isn't known; "-" means there's nothing to fight.
  - **Hover them** to see why: what skipping it costs, and each item's count, drop chance and likely kills.
  - It works on EllesmereUI's quest tracker and on the game's own. Turn on **Quest tags** under Leveling in /jsal settings.
  - Drop chances for quests new to Forever come from what Wowhead Forever has seen drop on Forever (an item found in chests, crates or plants counts each one you open like a fight); for Classic's quests, from pfQuest, which has Classic's numbers, so a few may be off where Forever changed a drop. The card says which. Chains come from pfQuest and Forever's own quest data. Your fight length is an average of your own fights, solo and outside dungeons, and is a guess of 20 seconds until you've had a few.

- **Map pins in Stormwind point at the right spot.** Forever draws Stormwind over a bigger stretch of the world than Classic does, and the pins for its trainers, recipe vendors and dungeon quest givers were still on Classic's map, so "Arrived" came up streets away. The same is fixed for Mulgore, Redridge and Eastern Plaguelands.

- **Professions: a better road, and a panel that's easier to read.**
  - **The road weighs what materials are worth, not how many there are.** It used to count a hide, an elixir or a Righteous Orb the same as one piece of leather, so it sent leatherworkers through dozens of hides. It now stays on plain materials and trainer recipes where it can.
  - **It only has you buy patterns a vendor sells for coin.** Patterns that need a reputation or a special currency are on the road only once you have them.
  - **It says how many to make to be safe**, beside the average, for steps that don't give a point every craft.
  - **Leather is asked for as itself.** A road that needs Heavy Leather no longer also lists the Medium and Light it could be made from.
  - **First Aid's road reaches 300**, through the bandages the Triage doctors teach; and it says its Expert rank is a book and its Artisan rank a quest.
  - **The panel and the shopping list sit above other addons' bars**, which could draw over them.
  - **Recipes to learn are in groups** (with "Where recipes come from" on): what your trainer teaches now, what a vendor sells for gold under each vendor's name, what's coming up, and everything harder to get behind one block you can open. Recipes only the other side can get are left out.
  - **The shopping list shows an item's name once the game has loaded it**, instead of leaving a row of dots.
  - **Cooking and First Aid are counted as professions** even when you have no Fishing; the Professions page left out whatever came after a profession you don't have.
  - **The panel reads top to bottom:** one bar for where you stand with the next rank marked on it, the step to do now as a card with each material as have / need, the steps after it one line each, when to train the next rank as a row of its own, then everything you need to the rank's cap.

- **Easier to read: the Professions page, the shopping list, the Dungeons window and training.**
  - **The Professions page** reads as the profession panel does: your skill on one bar, your professions in a row, the step to do now as a card, the steps after it, and everything you need at the right.
  - **The shopping list** groups what's still to get: from a vendor (with its cost), from the auction house or the world, and what you already have enough of. Each row says how many more you need.
  - **Dungeon bosses are a list down the window,** numbered in the order you meet them, each with its loot under it two across. They were cards two to a row, and a short card left a hole beside a tall one.
  - **Dungeon loot puts what's for you first, and says why:** a piece on your gear plan, then one that's better than what you wear (by your gear plan's weights), then the rest by how often it drops. The top says how many pieces in the dungeon are better than what you wear. A recipe for a profession of yours is tagged; recipes for other professions fold into one line with what you can't equip.
  - **Your guild's kills are said once,** on the boss's bar ("killed 2× · 8 guild kills"); an item says only how often it dropped in them.
  - **Dungeon quests** read at a glance. A line at the top says how many there are to pick up, and in red how many are above your level. Under headings (quest, who gives it and where, level), each place lists what starts there. A quest that stands alone is one line. A chain is a card of numbered steps in order: what leads up to the dungeon's quest, the quest itself (tagged "this dungeon's quest"), and what follows. Finished steps are ticked, the step to do next says "start here" (or "in your quest log"), and a run of steps with one name is a single line with the places it takes you through.
  - **Dungeon quests show only what's yours:** a class's own quests (Zul'Gurub's Paragons of Power, class necklaces, trinkets and Zanza's enchants; the pieces of Lord Valthalak's amulet; Anthion's Parting Words) go to that class, and a quest that only the other side's quests lead up to isn't shown.
  - **Class quests that send you into a dungeon are on its list:** the level 52 class quests in Sunken Temple, the warlock's Orb of Soran'ruk, the mage's Power in Uldaman, the paladin's Test of Righteousness, the shaman's Darkreaver Menace, the hunter's A Proper String in Onyxia's Lair and more, 28 in all, each shown to its class.
  - **A place's "show on map" goes round its stops**, a click at a time, since the game holds one map pin. Quest givers standing together count as one stop.
  - **The Training Planner** says at the top what's ready and what it costs, then in green or red whether your gold covers it ("You have 4g 12s: enough, with 2g 26s left"). What to train now is a list under headings, with "new" on an ability you don't have in any rank yet. The road to 60 spells out the next trainer visit, each spell with its price; every visit after it is a mark on a line down the page with its spells as their symbols, a gold frame round an ability new to you and a higher rank's number in its corner. Point at one for its name, right-click to skip it.
  - **The Training Planner's sums sit right under the list,** where they were at the foot of the page. A hunter's pet is under them, an ability a line, with what it waits on said once in a heading ("Waiting on pet level 30"). The road to 60 has the whole height of the page, shows at each stop what your pet can learn by then, and ends with the weapon skills.
  - **The panel at a trainer** opens with the same two lines ("3 spells to train", and whether your gold covers it), lists the spells under headings with "skip" under each name, says the next level once in its heading ("AT LEVEL 32"), and has one gold button that says what it buys: "Train all 3 · 1g 86s".
  - **The Build Planner's plan** has column headings, with the level said once in its heading where every row began "Level", and one line of where the build stands: "12 of 51 points taken · next at level 22", in gold when you have points to spend.
  - **The Build Planner's plan starts at what's next.** The points you've taken fold into one line that opens ("21 points taken, levels 10–30"). A talent you're partway through says which rank is next, where it said "ranks 1–2 of 2" with the first learned. Where a build moves to another tree there's a heading with that tree's points and levels. "Learn next points" is there, in gold, only when you have points to spend, and "Follow this build" only when you aren't following it.
  - **The Gear plan is wider, and a table.** Each slot names its best upgrade and where it's from, where it showed only what the upgrade adds. A slot's upgrades are in columns: the upgrade, where it's from (how it's got, over where), its level (red while it's above yours), what it adds and its star. The first is tagged "best for you".
  - **The Gear plan knows a two-hander takes both hands.** With one in your main hand, the off hand says so and offers nothing; it used to list every off-hand piece as an upgrade for an empty hand.
  - **A piece in your bags is on its slot's list,** as "In your bags", right under the starred ones: something you took off, or a quest's reward from long ago, was nowhere in the plan.
  - **An upgrade with no known source says so,** and comes after the ones you can go and get, so a slot's best upgrade is one the plan can send you to. One great item nobody can find no longer pushes real upgrades off the list.
  - **The Journal's Characters tab is a table,** one row a character: level, where it is, its gold, its professions and its rested XP, with when you last played it under its name. The cards' words ran past their edges.
  - **The Journal's Summary is livelier.** A bar shows how far it is to your next level, with how long that is at your pace. Three cards name your favourite move, where you've spent most time, and your nemesis: what you were fighting when you died, most often (counted from this version on). Your levels are a chart, a bar a level for the time it took, with a dot over the ones you died on; point at a bar for what that level took. Each number has a picture and a rate beside it ("45 an hour"), your favourites are bars, and your pal stands in the corner beside you.
  - **The Journal's Story is by day:** a heading for today, yesterday and each date before, the time on every moment, and a coloured square for its kind that the filter buttons share. The same thing several times in a day is one row ("Died ×4"). The place is said only when the words don't name it. Your pals' moments have a filter of their own.
  - **The Journal's By level table reads across,** and folds by tens: each ten of levels is one line with its own sums that a click opens, the ten you're in open to start. Banded rows, the level you're on marked "now", a bar beside XP an hour, gold and silver each in their own place so a column lines up, the net in green or red with its sign, and deaths in red. What "+" and "*" meant is said in words under it.
  - **Settings is cards, not paragraphs.** Each part is a card with its name, one short line and its switch, two across, under small headings ("Planning ahead", "As you play"). Each has a small picture, gold while the part is on. Point at a part for everything it does. A part's options open under its card, and the top says how many parts are on.
  - **Jsal's Pals has a livelier window.** Under the pen, a line says how your pal is ("Bramble is happy, but hungry"). Its needs are rows of pips in a colour each, its bond a row of hearts, today's wish a card. Each kind of care is a picture button with how many you have left; the one your pal needs now is framed in gold and bobs, and pointing at a button says what it does and how you earn more. Hearts rise from a button toward your pal when you look after it, and the Lights out button shows a sun to wake it while it sleeps. The Grow button is only in its pen: out with you, a pal that's ready to grow waits until it's home.
  - **Daily Word's record** under a finished board is a row of numbers with a word under each (played, won, average, streak, best), where it was one sentence of five numbers.
  - **The Guild table** says when someone offline was last seen beside their name, where it sat under the Daily Word heading as if it were a score.
  - **Home's Today** shows the date beside the title, what the next level brings as a card with a row for each thing, and your pal's need under your name when it has one.

- **Guild crafters lists who shares, with their professions.** Before you type anything, the page lists the guildmates who share their recipes, online first, each with their professions and skill and a whisper button. Click a profession to see what they make with it. Gathering professions are listed too, for guildmates on this version.
- **Jsal's Pals: a fully grown pal looks after an egg.** Click an egg and your pal takes it into a nest in the pen. Your pal keeps to the nest's side and dotes on the egg there, with a hop, hearts and sparkles. The egg warms while your pal is well looked after, faster the closer you are, and the page says how long it has to go: about a day of good care. When it's ready the egg rocks and a Hatch button appears; there's no hurry. Press it and your pal hurries to the nest and watches the egg rock and hatch, fusses over the hatchling, then walks away to the paddock. A card says who it was, how long you had it and how close you were. The hatchling keeps the cupboard and a little of the old bond, and the nest stays in the pen as its bed: it sleeps and naps there until it grows out of it. (A second click on an egg used to hatch it on the spot.)
- **Jsal's Pals: the pal that looked after the egg comes to visit.** Once or twice on a day you play it comes by the pen for a few minutes, with its name over it, and the young one cheers up a little.
- **Jsal's Pals: the paddock has scenery of its own.** A wide view of a big field, with a shelter, a trough and hay, drawn for each kind of country the pen has, by day, at sunset and by night. It follows the realm's clock, and it rains, snows or blows sand there when it does where you are.
- **Jsal's Pals: right-click an egg to let it go.** The first right-click says what will happen; a second on the same egg does it. Hatching one was the only way an egg ever left, so three you didn't want kept new ones from turning up. Pointing at an egg says what a click and a right-click do.
- **The Journal's "at your pace" is your pace over three levels.** It went by the level you're on alone, so a level begun with hours of standing about put the next one days away.
- **"Better for you" on a dungeon's loot is the Gear plan's answer.** A piece is tagged when the Gear plan would list it for that slot. Any higher score used to do, so leggings with Strength and a lot of Stamina were tagged over a hunter's Agility ones while the plan left them out.
- **The Journal's Characters tab keeps each character's gold, rested XP and professions.** Logging out saved them as nothing, so every character but the one you were on read "none" and "not known yet". Log in to each character once and its line fills in, and stays.
- **An option in Settings is its name and its switch.** What it does is in its tooltip, where there was a line under the name that was cut short, and a long name no longer runs under the switch.
- **The craft timer no longer stays up when a run ends early.** Ask for seven with materials for one and the game makes one and stops without a word; the timer sat there counting nothing. It now goes a few seconds after the last craft.
- **The shopping list no longer jumps when you drag it.** It also keeps its title bar where you put it when the list gets longer or shorter.

## In 0.3.38

Coming from 0.3.37 or earlier, restart the game after updating: 0.3.38 added new pictures.

- **Jsal's Pals: weather in the pen (new, off to start).** When it rains or snows where you are, or a sandstorm blows, it does in your pal's pen too, and heavy snow falls thicker. Turn on **Weather in its pen** under Jsal's Pals in /jsal settings.
  - It isn't drawn while your pal is out with you: the real thing is all round you.

- **Training: a talent's later ranks are only for those who have the talent.** Counterattack Rank 2, Mortal Strike Rank 2, Pyroblast Rank 2 and the like were listed as ready to train for everyone, and the trainer wouldn't teach them. Now they show only once you've taken the talent, for every class: in the trainer panel, the Training Planner and the Today card.
- **Training: a pet trainer is no longer taken for a hunter trainer.** With everything bought from a pet trainer, the panel was headed "Hunter trainer" and listed your own spells.

## In 0.3.37

Coming from 0.3.36 or earlier, restart the game after updating: 0.3.37 added a new picture.

- **Jsal's Pals: watch your pal grow.** When it has had enough good days it's ready to grow, and it waits for you so you never miss it. Its pen and Today say so. Press **Grow** in its pen: a light gathers over it, and out it comes in its next form.
  - Until you press it, it stays just as it was, and what it will become isn't told.
- **Jsal's Pals: a rare egg is never lost for want of room.** With three eggs in hand, a rare one used to be left behind without a word. Now it's kept safe, and takes the place of the next egg you hatch.
  - **And it can turn up while your pal is still growing.** Everyday eggs still wait until your pal is fully grown.

- **A smaller download.** The pals' pictures take about a third less room, with not a pixel changed.

## In 0.3.36

Coming from 0.3.35 or earlier, restart the game after updating: 0.3.36 added new pictures.

- **Jsal's Pals: four new pals to discover, ten kinds in all.** What they are, how they grow up and what they can do is for you to find out.
  - **Four new eggs** are out there for a fully grown pal to turn up as you play. Two of them can be among the three a new player chooses from. The other two are rare, and you'll have to earn them.
  - **Smoother walks** for two pals whose step had a hitch in it.
- **The album turns its pages.** Four kinds to a page, with arrows at its top right, so every name fits.
- **Dungeon guide: where each quest starts.** On a dungeon's Quests tab, every quest now says who gives it and where, with the spot on the map ("Gerrig Bonegrip, Ironforge (50, 6)"), or that the giver is inside the dungeon. A quest that starts from an item names it and who drops it ("from An Unsent Letter, dropped by Edwin VanCleef in The Deadmines").
  - **What to do first.** A quest that needs another one before it says so in gold, with where that one starts, or that it's on the same list or already done.
  - **Click to pin.** Clicking a quest puts the map pin on its start; for one that starts inside the dungeon, on the start of the quest before it.
- **Map pins stay put.** A pin from a quest or a trainer is no longer swapped for your RestedXP guide's next step while the waypoint label follows the guide, and one in another zone no longer clears itself as if you'd arrived.

## In 0.3.35

Coming from 0.3.34, a /reload is enough. From 0.3.33 or earlier, restart the game after updating.

- **Unlock Mode, jsal.ui's own** (`/jsal unlock`, Unlock Mode in the minimap button's right-click menu, or Move pieces at the top of Settings). Every jsal.ui piece is outlined and named, even one that's hidden just now: the quick buttons, the bag button, the food reminder, the range check and your pal out with you. Drag one and it snaps to a grid, the middle of the screen and the other pieces; hold Shift to place it freely. Pick one to type its exact X and Y, and for the range check its exact width and height too. Right-click a piece, or Undo all, to put things back where they were; Done or Escape to finish. It needs nothing else installed, and a fight starting closes it. With EllesmereUI on, the pieces are in its Unlock Mode as well, as before.
- **Hunter range check: lock it.** Right-click the box to lock it, so a stray drag can't move or resize it; right-click again to unlock. Locked or not, Unlock Mode moves it and sets its exact size.
- **The Companion has a name of its own: Jsal's Pals.** It's in the menu, Settings and its window under that name, and the creature you raise is your pal. Nothing about it has changed, and `/jsal pet` still opens it.
- **Setup no longer offers the jsal.ui look,** which isn't ready yet. Its step, the "Your addons" step and the "Just the look" starting set are gone until it is, and so is the Install page at the bottom of the menu. Setup is now five steps, and the parts page is the switches on their own. jsal.ui never needed EllesmereUI: everything else is as it was.

## In 0.3.34

Coming from 0.3.33 or earlier, restart the game after updating: 0.3.34 added a new picture.

- **Companion: more to do together.**
  - **It copies your emotes.** `/dance` and it dances, `/wave` and it hops, `/roar` and it shows off, `/cry` and it droops, `/yawn` and it yawns. In its pen or out with you.
  - **Tricks, which come with your bond.** Right-click it and it does one it knows: sit first, then a hop, a dig, a dance, and at the last its own special. A new one comes with each level of the bond.
  - **A bath you scrub.** Bath puts a brush in your hand: rub it over your companion and the suds come up until it's clean. Click it, or wait a moment, for a quick wash.
  - **Chase the pointer.** Wiggle the pointer in its pen and it runs after it and pounces, a little fun the first few times a day.
  - **Wishes for the new games.** Today's wish may be a proper game of fetch, or a treat to catch out of the air.
  - **It notices more.** A rare in your sights and it perks up; something blue or better in your bags and it dances. Out with you, it sits down when you sit to eat or drink, and shivers in the snow.
  - **Livelier on the move.** Out with you while you walk or run, it stops every few seconds, wherever it is, for one of its short animations, then goes on.
  - **What's in your hand is drawn over your companion,** not behind it.

## In 0.3.33

Coming from 0.3.32 or earlier, restart the game after updating: 0.3.33 added new files.

- **Companion** (new, off until you turn it on: Settings, Games, "Companion"; then Companion in the dashboard, or `/jsal pet`). A small creature of your own to look after, in a window you can leave open while you play.
  - **Choose an egg.** Three are waiting, drawn from the six kinds, so yours may not be your guildmate's three. Click one to hear about it, click it again to make it yours. It hatches there and then, and you name it, once.
  - **Six kinds, three forms each.** A briar boar, a ghost monkey, a boxing dragon, a lightning lion, a fairy turtle and a steel elephant. Each grows up twice, about two well-kept days and then a well-kept week, and each form has something of its own to show off.
  - **Four needs:** fed, rested, happy and clean. Feed it, give it a treat, play, bathe it, turn the lights out, click it for a pat, and scoop the dropping that turns up a while after a meal.
  - **Food and play go where you say.** Feed, Treat and Play put the bowl, the biscuit or the ball in your hand. Click the grass and it's set down or thrown there, and your companion runs over. Leave it a few seconds and it's set down beside it for you.
  - **Fetch.** A thrown ball is run after, carried back and laid at its feet. Click the grass again to throw it again, up to three throws for one toy.
  - **Catch a treat.** With a treat in your hand, click your companion and the biscuit goes up over its head. Click it again as the biscuit comes down and it leaps and catches it, which it likes a little more. Miss, and it eats it off the grass: a treat is never wasted.
  - **Call it over.** With nothing in your hand, click the grass and it walks to where you clicked.
  - **Supplies come from your play:** a quest handed in is a meal, a flight is a toy, a new level brings treats, soap and medicine. A fish caught or a point of Cooking is a treat, and a point of First Aid is medicine, a few a day.
  - **It's forgiving.** Look in twice a day and it stays cheerful. However long you're away, only half a day passes for it, and at worst it feels poorly for a few hours.
  - **How it is shows on it:** mud and flies when it's dirty, a tub and a sparkle for its bath, a droop and dizzy stars when it's poorly. Now and then a small bubble by its head says what's on its mind.
  - **Its pen is the country you're in:** snow, desert, swamp, coast, dark woods, savanna, a volcanic waste, jungle, or a meadow. Evening brings a sunset and then night, by the realm's clock, and Lights out does the same.
  - **A wish each day and a bond that keeps growing,** from Wary to Inseparable. Neither is ever lost, and its milestones go into your Journal.
  - **Eggs from your play.** Once yours is fully grown, a quest, a flight, a new level, a new zone, a fight won or coming back from the dead can turn up another egg. Hatch it and the grown one settles in the paddock for good.
  - **The paddock and its album.** The Paddock button shows the companions that have settled, going about their day, and an album of every form you've raised.
  - **Out with you.** The Out button (or `/jsal pet out`) takes it out of its window to walk a short strip of your screen while you play. Drag it where you like. It keeps pace with you, runs when you ride, naps when you're away, goes faint in a fight, and does something about what you do: a quest handed in, a new level, a flight. Point at it for buttons to bring its window back, mute it, or change its size.
  - **Its company counts.** The fifth quest, flight, new zone or level of a day with it on your screen brings you a little closer, and now and then it digs up a treat or a toy. Nothing is lost by leaving it in.
  - **Sounds,** small ones, with a mute button in the pen's corner and a switch in Settings.
  - **On Today:** when it wants something it's listed under Ready now, and its menu entry shows a gold 1.
- **Gear plan: the slot list names its two columns,** "You wear" and "Best upgrade adds". The green numbers beside a slot are what its best upgrade would add, which on an empty slot had read as the slot's own stats.

## In 0.3.32

Coming from 0.3.27 or earlier, restart the game after updating: 0.3.28 added new files. From 0.3.28, a /reload is enough.

- **Gear plan: a row for each ring and each trinket.** The list had one "Finger" row and one "Trinket" row standing for two slots each, so with both trinket slots empty it looked as if one was missing. Each slot now has its own row (Finger 1, Finger 2, Trinket 1, Trinket 2), showing what's in it and its own best upgrade. The rows are a little shorter so all seventeen fit, and the count at the top now counts each of those slots on its own.

## In 0.3.31

Coming from 0.3.27 or earlier, restart the game after updating: 0.3.28 added new files. From 0.3.28, a /reload is enough.

- **Next level on Today** (new, off until you turn it on: Settings, Leveling, "Next level on Today"). Three short lines at the right of Today's title say what your next level brings: the talent your plan takes with that level's point, the trainer visit with its cost, and whether the gold you have covers it ("enough", or how much you're short). A dungeon that becomes right for you and a profession rank you can train are named when they land on that level. When the next level has nothing to buy, it names the next trainer visit instead. A price no trainer has shown you yet makes the total read "from".

## In 0.3.30

Coming from 0.3.27 or earlier, restart the game after updating: 0.3.28 added new files. From 0.3.28, a /reload is enough.

- **Where recipes come from: the other side's quests.** A recipe that comes from a quest only the other faction can take no longer sends you to it. It reads "From a Horde quest only" (or Alliance), and a way you can get it, such as a world drop, is named first. Before, an Alliance character was shown Kodo Hide Bag's quest in Thunder Bluff.

## In 0.3.29

Every page has been reworked to be easier to read: larger text, clearer headings, and each page now opens with what matters most. Nothing was taken away.

- **Home is now Today.** A "Ready now" list of what's waiting for you: a trainer visit with its cost and a map pin, talent points to spend, a chess move, today's Daily Word and Icon Guess. Under it, a card each for your build, your gear, your professions and the dungeon for your level, each a click into its page. What's new is one line at the bottom.
- **The menu shows what's waiting.** A gold number sits beside Training Planner, Build Planner, Games and Chess when there's something to do there. Gear plan and Dungeons have a small arrow, because they open in a window of their own. Install has moved to the bottom, with Report a problem and Settings.
- **Settings.** One group to a tab, with what each part does written under its name instead of in a tooltip. A part's options open under it. A box at the top finds any part or option. When you flip a part's switch, a bar at the bottom lists what's waiting for a reload, with Undo and a Reload button.
- **Training Planner.** The top says what's ready and what it costs, with the map pin beside it. Spells you've skipped fold into one line under your visit. A hunter's pet abilities are grouped by how you get them, and one your pet is already high enough for says "Any time" instead of a level it passed long ago.
- **Gear plan.** The top counts the slots that can be better. Each slot shows what its best upgrade adds ("+16 AP") in place of the upgrade's name, which is in the slot's tooltip and beside the slots once you click one. Empty slots stand out, and each upgrade is a card with a clearer star.
- **Profession panel.** Two tabs, "Your road" and "Recipes to learn", so the panel no longer runs off the bottom of the screen, and recipes get room for twelve at a time. A step's "needs" line is no longer cut short, and the have and need numbers line up.
- **Profession road, where to buy a pattern.** With "Where recipes come from" switched on, a step of the road that needs a bought pattern names who sells it to you, where, and for how much, instead of only "Buy the pattern from a vendor".
- **Every other page opens with a title that says where things stand:** "Leatherworking 51 of 150", "2 puzzles to play today", "Your move against Yari". Games has a card for each game with your record on it. Dungeons names the dungeon once, and ticks a boss only once you've killed it.
- **Easier to read everywhere.** No text is smaller than 12px in the dashboard, the Gear plan or the Dungeons window, and text is a size up in the panels beside the game's windows. Rare and epic item names are a lighter blue and purple that read on the dark background. The chosen tab has a gold line under it, and a gold button is kept for a page's one main action. Every list that scrolls shows a bar.

## In 0.3.28

- **Where recipes come from** (new, off until you turn it on: Settings, Profession window, "Where recipes come from"). In the profession panel's "Not learned yet" list, the recipes your skill is high enough for now come first, under "Ready to learn", with the rest under "Later". Each one says where to get it: the vendor, their zone and the price; the quest; or the mob that drops it. Vendors are the ones that sell to your side, and limited stock is marked. Point at a recipe for every source, and click it for a map pin on the vendor. A recipe that drops from many mobs just says "World drop". 1,362 recipes and 193 vendors, from Wowhead's WoW Forever lists.

## In 0.3.27

- **Pet abilities on beasts:** the "Tame to learn" line now names the exact rank a beast has. In 0.3.26 it could be one rank too high on beasts whose level sits right where a rank begins. The beast list now comes from Petopia's WoW Forever lists: 375 beasts, including the new abilities (Mine!, Web, Pinch, Swipe, Dismember, Dust Cloud, Savage Rend, Tendon Rip, Trickster's Dance) and Cower. The line also shows on beasts far above your level. It's for hunters and off until you turn it on: Settings, Leveling, "Pet abilities on beasts".

## In 0.3.26

- **Pet abilities on beasts (new, for hunters, off until you turn it on):** in Settings, under Leveling, switch on "Pet abilities on beasts". A beast's tooltip then gets a gold line, "Tame to learn: Bite (Rank 3)", when taming it would teach your pets an ability rank that isn't in your Beast Training yet, and a grey "Tameable at level 24" when the beast is still above your level. A beast with nothing new for you gets no line. Open Beast Training once so jsal.ui knows what you already have. Which beasts carry which ability comes from Wowhead, which has it for about half the beasts you can tame, so no line doesn't always mean nothing to learn; and there's no line inside dungeons, where the game hides which creature you're pointing at.
- **Quick buttons:** the bar no longer changes width, and its buttons no longer shift, each minute as the time changes. The time now has room for its widest digits and sits in the middle of it.
- **Hardening:** the food reminder and the crafting timer step around buff and cast details the game can hide, instead of risking an error.

## In 0.3.25

- **Fixed:** an error in a dungeon ("a secret string value", from the Journal) that switched the Journal off until the next reload, so loot, levels and deaths after it went unrecorded. Inside a dungeon the game hides chat lines and names from addons; every part of jsal.ui that listens to the game now steps around hidden ones.
- **Fixed:** a quick button, usually the j, sometimes went invisible until a reload. The bar now notices within a second and puts it back, rebuilding the button if it has to. If one ever stays gone, `/jsal bar` repairs it and saves what it saw for a bug report.
- **Fixed:** the Journal's story no longer shows "Died" twice for one death.

## In 0.3.24

- **Flight bar, land early (new):** on a flight with stops, the flight bar has a button named for the next flight point, "Land at Stormwind". Click it and you land there instead of flying on; the bar then counts down to that landing. The button goes once the last stop is behind you, and a direct flight has none. It's part of the flight bar, so there's nothing to turn on.
- **Flight bar:** landing early from another addon's button retargets the bar's route and countdown the same way.

## In 0.3.23

- **Shopping list, craft with its mats (new, off until turned on):** add something one of your professions makes, a Camp Tent for a leatherworker, and the list adds the craft instead, with what it takes under To buy. A note says whose craft it is, and Buy it instead puts the item itself back. Turn it on in jsal.ui's Settings, under Shopping list.
- **Fixed:** shift-clicking an item into the shopping list's box, or the gear plan's Add box, now works: from your bags, or the item's icon in a profession window's recipe details.
- **Fixed:** the shopping list no longer jumps across the screen when you drag it after closing the profession window it opened beside.
- **Fixed:** the shopping list's last line says "1 to buy, no price known yet" instead of "Nothing to buy" when nothing on it has a price yet.
- **Fixed:** "No player named ... is currently playing" no longer shows when the game prints a guildmate's realm after a space, as it can after opening the Guild tab.
- **Fixed:** in Report a problem, a few long errors no longer run out of their box and under the Send to John button.

## In 0.3.22

- **Fixed:** no more errors in a dungeon from pointing at, targeting or looting creatures and bosses. Inside a dungeon the game keeps their names hidden from addons, and jsal.ui now steps around them. (The layer reader reads nothing in a dungeon, where there are no layers anyway.)
- **Training Planner:** bows, guns, crossbows and thrown weapons now have a price, a pet's first ranks of Great Stamina and Natural Armor show the pet level they need (10 and 12), and prices are always the full price, not one a faction discount lowered.
- **Fixed:** the first time you open a trainer, jsal.ui's panel fills in by itself, without closing and opening it again.
- **Fixed:** with two hunters, a pet ability one of them bought at a pet trainer no longer shows as known for the other.
- **Smaller settings file:** saved trainer visits take about a third of the space. Your first login after updating converts them; nothing to do.
- **Steadier:** jsal.ui leaves the trainer's own list filters as you set them, and if one of its additions to the game's windows (item links, the shopping list, the menu bar) ever hits an error, that part switches itself off instead of erroring again and again.

## In 0.3.21

- **Fixed:** Add to shopping list in a profession window no longer opens the shopping list over the profession tabs on the window's right edge; it opens just past them.

## In 0.3.20

- **Food reminder (new, off until turned on):** a small glowing tile while you aren't Well Fed. Point at it for the food in your bags in a row under it, buff food first; point at one for its tooltip, click one to eat it. It hides in a fight and once you're Well Fed, and drags anywhere (or moves in EllesmereUI's Unlock Mode). Turn it on in jsal.ui's Settings, under Around the UI.
- **Fixed:** the hunter range check no longer turns grey ("too far") when an enemy you shot at comes up close in a fight. Before Wing Clip it now reads melee; from Wing Clip on, the dead zone and melee as before.

## In 0.3.19

- **Fixed:** the hunter range check no longer sets off a "tried to call the protected function" error in a fight before you learn Wing Clip (taming a pet on the level 10 quest, for one). In a fight it goes by Auto Shot and its last reading.

## In 0.3.18

- **Fixed:** "No player named ... is currently playing" no longer shows up in chat when jsal.ui's hidden messages reach a guildmate who has just logged off. A mistyped name in your own whisper still shows it.

## In 0.3.17

- **New parts start off:** the bag button, the hunter range check, the menu bar look and the time on the quick buttons now start switched off, so updating doesn't change your screen. Turn on the ones you want in jsal.ui's Settings, under Around the UI (the time is under Quick buttons), then /reload. If you already turned one on yourself, it stays on.

## Also new since 0.3.15 (in 0.3.16)

- **Gear plan (new):** your gear slots in a window of their own (`/jsal gear`, the quick buttons, or the shield button beside your character pane). Each slot shows what you wear and, in green, the best upgrade near your level for your spec.
  - Click a slot for its list: where each piece comes from (a boss and dungeon, a quest, a vendor, a crafter), what it adds over what you wear, and its level, in red when it's above yours.
  - Lighter armor shows when its stats are better for you. Profession gear, like an engineer's goggles, shows marked with the skill it needs.
  - Quest rewards drop out of the list once you've done the quest.
  - **Weights:** change how much each stat counts for your spec, or paste a Pawn scale. They're kept per character and spec; Reset puts the defaults back.
  - **Add:** type an item ID, shift-click an item link or paste a Wowhead address to add something the list doesn't have.
- **Stars (new):** star an item in the gear plan to be told when you can get it: a gold line on its tooltip, a gold banner and a sound when it's in a loot window or a roll, a chat line when you enter a dungeon that drops it, and a gold star in the dungeon guide. The star clears itself once you wear it or something as good.
- **Bag button (new, off until turned on):** one button with your free bag space in place of the game's bag bar, in red at five or fewer; drag it anywhere. Click opens your bags; right-click shows the bag slots, to swap a bag. Point at it for your cheapest items, junk first, with what each sells for; click one to pick it up.
- **Hunter range check (new, off until turned on):** a small box that shows, by its colour, where you stand from your target: white in melee, red in the dead zone, green in shooting range, dim grey too far. Drag it anywhere and resize it from its corner, from a square to a bar. An option plays a sound when you step into the dead zone.
- **Menu bar (new, off until turned on):** the game's menu bar (character, spellbook, quest log and the rest) now matches the quick buttons: gold icons on dark tiles. The buttons work as before. To match the quick buttons' size, set the menu bar's Size to 135% in Edit Mode.
- **Quick buttons:** laid side by side, the time can sit in the middle (switch it on under Quick buttons); hover it for local and realm time. Right-click the j to lock or unlock the bar; locked, its grip goes. Daily Word, Icon Guess and Chess share one Games button, making room for the gear plan and the dungeon guide.
- **With EllesmereUI:** the quick buttons, the bag button and the range check move in its Unlock Mode, with its grid and snapping. jsal.ui's font, Outfit, appears in its font menus, and a switch in Settings puts your RestedXP guide in Outfit too.
- **A softer look:** jsal.ui's windows have a soft shadow, so they stand out over bright ground, and fade in as they open; buttons and rows light up under your pointer.
- **Dungeon guide:** a quest you've picked up but not handed in says "in your quest log". The guide and the gear plan each open in a window of their own.
- **Waypoint label:** your RestedXP guide's pin now stays until the guide moves on, so a spot upstairs or on a tower isn't lost from below.
- **Report a problem:** reports now carry jsal.ui's last few errors, with where each happened, even after a /reload, and without BugSack.
- **Removed:** Quests on autopilot. It could take quests you meant to skip. Setup now offers two starting sets, Everything and Just the look.
- **Fixed:** standing in for the trainer, Train all takes every click, and the trainer's hidden list no longer shows tooltips through it.
- **Fixed:** "No player named ... is currently playing" in chat when a guildmate who takes reports had just switched characters.
- **Fixed:** pet abilities a pet trainer sells (Great Stamina, Natural Armor, Growl, the resistances) say "from a pet trainer" in the Training Planner.
- **Fixed:** a recipe's line in the dungeon guide no longer shows an empty part.
