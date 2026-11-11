# jsal.ui 0.3.31

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
