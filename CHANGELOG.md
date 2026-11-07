# jsal.ui 0.3.15

After updating, restart the game: this version adds new files, so a /reload isn't enough.

- **Dungeon guide (new):** a Dungeons page in the dashboard (`/jsal dungeons`). Pick a dungeon or raid from the list at the top, grouped by level, with the ones right for your level in green and whether each is on the Horde or Alliance side.
  - Every boss gets a card with its loot and how often each item drops, ticked once you've killed it (kills from before jsal.ui count too).
  - Loot your class can't use, or armor that isn't your type, is dimmed, and a level above yours shows in red.
  - A Quests tab lists the dungeon's quests for your side, ticked once done.
- **Guild loot (new):** guildmates with jsal.ui share the bosses they kill and what drops, so every boss's card fills in from the whole guild's runs ("guild 3 of 8"). Turn it off in Settings under Dungeon guide.
- **Waypoint label (new):** a gold label and marker over the game's navigation arrow, naming where it leads and how far. It follows your RestedXP guide's arrow, says "Arrived" when you get there, and clears itself; click it to clear it sooner. `/jsal waypoint` says why it isn't showing; `/jsal waypoint clear` removes a stray map pin.
- **Setup (new):** a short guided setup to choose which parts of jsal.ui you want. It opens once after this update; close it to keep everything as it is, or open it any time with `/jsal setup` or from Settings.
- **Fixed:** the session recap no longer covers the logout box's Exit Now button.
- **Fixed:** with EllesmereUI, the trainer window could be left with thick gray boxes over its Train button.
