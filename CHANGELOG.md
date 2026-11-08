# jsal.ui 0.3.16

After updating, restart the game: this version adds new files, so a /reload isn't enough.

- **Gear plan (new):** your gear slots in a window of their own (`/jsal gear`, the quick buttons, or the shield button beside your character pane). Each slot shows what you wear and, in green, the best upgrade near your level for your spec.
  - Click a slot for its list: where each piece comes from (a boss and dungeon, a quest, a vendor, a crafter), what it adds over what you wear, and its level, in red when it's above yours.
  - Lighter armor shows when its stats are better for you. Profession gear, like an engineer's goggles, shows marked with the skill it needs.
  - Quest rewards drop out of the list once you've done the quest.
  - **Weights:** change how much each stat counts for your spec, or paste a Pawn scale. They're kept per character and spec; Reset puts the defaults back.
  - **Add:** type an item ID, shift-click an item link or paste a Wowhead address to add something the list doesn't have.
- **Stars (new):** star an item in the gear plan to be told when you can get it: a gold line on its tooltip, a gold banner and a sound when it's in a loot window or a roll, a chat line when you enter a dungeon that drops it, and a gold star in the dungeon guide. The star clears itself once you wear it or something as good.
- **Bag button (new):** one button with your free bag space in place of the game's bag bar, in red at five or fewer; drag it anywhere. Click opens your bags; right-click shows the bag slots, to swap a bag. Point at it for your cheapest items, junk first, with what each sells for; click one to pick it up.
- **Hunter range check (new):** a small box that shows, by its colour, where you stand from your target: white in melee, red in the dead zone, green in shooting range, dim grey too far. Drag it anywhere and resize it from its corner, from a square to a bar. An option plays a sound when you step into the dead zone.
- **Menu bar (new):** the game's menu bar (character, spellbook, quest log and the rest) now matches the quick buttons: gold icons on dark tiles. The buttons work as before. To match the quick buttons' size, set the menu bar's Size to 135% in Edit Mode.
- **Quick buttons:** laid side by side, the time sits in the middle; hover it for local and realm time. Right-click the j to lock or unlock the bar; locked, its grip goes. Daily Word, Icon Guess and Chess share one Games button, making room for the gear plan and the dungeon guide.
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
