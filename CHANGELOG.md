# jsal.ui 0.3.25

Coming from 0.3.19 or earlier, restart the game after updating: 0.3.20 added a new file. From 0.3.20, a /reload is enough.

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
