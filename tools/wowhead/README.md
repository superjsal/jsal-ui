# Refreshing the Wowhead data (monthly)

The gear plan's items (`data/gear/wowhead-items.json`) and the dungeon guide's loot and quests
(`data/dungeons/wowhead.json`) are read from Wowhead Forever's public pages in an ordinary
signed-in browser, a page every few seconds, by scripts started by hand from its console. New
Forever items and drop chances only reach jsal.ui when these are read again, once a month (on
the 7th).

If the site asks the person at the browser to confirm something, the script stops there and
keeps what it has read; they confirm it, and running the same script again carries on.

## Steps (in this repo, on the `beta` branch)

1. **Gear (57 pages, about 12 minutes):**
   - Start the receiver in the background:
     `python -I tools/wowhead/receive.py data/gear/wowhead-items.json`
   - Open `https://www.wowhead.com/forever` in the browser. In its console, run
     `localStorage.removeItem('jsalGear')`, then the whole of `gear.js`.
   - Check `window.__gear` now and then (`log`, `err`, `done`). If it stops with `err: "blocked at
     ..."`, confirm what the site asks, then run `gear.js` again (it carries on).
   - When every list is in, the tab goes to the receiver and the file is written.
   - Then: `python -I tools/build_gear.py` (writes `jsalUI/Gear/GearData.lua`; compare its item
     count with the last commit's).
2. **Where the placeless set pieces drop (91 item pages at level 50, about 15 minutes):**
   - A drop Wowhead names no one place for (the dungeon set bracers and belts drop from ordinary
     creatures in several dungeons) takes its dungeons from its own page's "Dropped by" list, for
     the Dungeon guide's Trash card.
   - Start the receiver writing to a scratch file:
     `python -I tools/wowhead/receive.py <scratchpad>/places-fresh.json`
   - In the browser on a wowhead.com/forever page: the `window.__placeIds` line
     `python -I tools/wowhead/place_items.py` prints, then the whole of `places.js`. Watch
     `window.__places` (`read`, `left`, `err`). On a block it sends what it read to the receiver:
     merge it (below), confirm what the site asks, and the receiver, a new
     `place_items.py` line and `places.js` again carry on with what's left. `--min-level 40` or
     `30` reaches lower, `--quality 2` takes greens too, `--all` reads them all again.
   - `python -I tools/wowhead/merge_places.py <scratchpad>/places-fresh.json` folds it into
     `data/gear/wowhead-places.json` (items not in the batch keep their old read) and says how
     many are still to read.
   - Everything on the list is read; which pieces get a dungeon place is the build's rule, so it
     can change without reading again. A set piece (the game's ItemSet table,
     `data/gear/ItemSet.csv`) takes every dungeon it drops in. Any other piece takes one only when
     dungeon creatures drop at least 90% of it (`MOSTLY_IN_DUNGEONS`; by Wowhead's counts, else by how many
     creatures),
     and then only the dungeons with at least `DUNGEON_SHARE` (15%) of its drops, so a world drop
     a few dungeon creatures also drop stays a world drop. `python -I tools/wowhead/place_items.py --why`
     prints each read item's rule and shares: look it over before it ships.
   - Then `python -I tools/build_gear.py`, which says how many drops it placed in a dungeon.
3. **Dungeons (about 100 pages with `--thin`; a full read is about 190):**
   - `python -I tools/wowhead/bosses.py --thin` prints a `window.__bosses = ...;` line: the
     bosses whose loot is still filling in, or was never read. Leave out `--thin` for a full read
     (every few months); `--zones 16550,1176` reads only those Wowhead zones. The bosses come from
     the game's own tables, so a dungeon new to `tools/build_dungeons.py` is asked for at once.
   - Start the receiver writing to a scratch file:
     `python -I tools/wowhead/receive.py <scratchpad>/dungeons-fresh.json`
   - In the browser on a wowhead.com/forever page: `localStorage.removeItem('jsalDungeons')`, the
     `window.__bosses` line, then the whole of `dungeons.js`. Watch `window.__dungeons`; if it
     stops, confirm what the site asks and run `dungeons.js` again (with `window.__bosses` still set).
   - `python -I tools/wowhead/merge_dungeons.py <scratchpad>/dungeons-fresh.json` folds it into
     `data/dungeons/wowhead.json` (bosses not reached keep their old loot), then
     `python -I tools/build_dungeons.py` (writes `DungeonLoot.lua`). `__dungeons.unmatched`
     names bosses Wowhead lists under another name: add them to `ALIAS` in `bosses.py`. A boss
     the zone's page doesn't list at all (Krol'dok Stronghold's, The Shaper's Terrace's) is found
     by name on `/forever/npcs/name:<name>` and its NPC ID goes in `NPC_ID` there.
   - **After a game patch adds dungeons** (`build_dungeons.py` stops and names them): fetch the
     four tables for the new build as its docstring says, add each dungeon to `DUNGEONS` and
     `WOWHEAD_ZONE` (its zone from `/forever/zones`, its entrance from Wowhead's dungeon list,
     `/forever/guide/dungeons-overview-locations-details`), then read them as above.
   - **Where each dungeon quest starts (about 500 pages at one every 10 seconds, in batches):**
     after `build_dungeons.py`, for each batch: start the receiver writing to a scratch file
     (`python -I tools/wowhead/receive.py <scratchpad>/batch.json`), then in the browser on a
     wowhead.com/forever page run the two lines `python -I tools/wowhead/quest_ids.py --missing`
     prints, then the whole of `quests.js`. Keep its tab in front: in the background it slows to a page
     a minute. The site asks for a confirmation about every 25 pages; the batch then sends what it read to the
     receiver. `python -I tools/wowhead/merge_quests.py <scratchpad>/batch.json` folds it into
     `data/dungeons/quest-starts.json` and says where it stopped; confirm what the site asks,
     and the next batch carries on. When a batch ends with nothing missing, run
     `build_dungeons.py` again (it writes the starts into `DungeonLoot.lua`).
   - **Who drops the items that start quests (about 40 pages):** after the quest starts, for a
     quest Wowhead names no starter for, the game's item table may say which item starts it. Start
     the receiver writing to `<scratchpad>/items.json`, run the line
     `python -I tools/wowhead/quest_items.py` prints and the whole of `items.js` in the browser, then
     `python -I tools/wowhead/merge_quests.py <scratchpad>/items.json --items` (it writes
     `data/dungeons/quest-items.json`). Repeat until the list is empty, then run
     `build_dungeons.py` again.
4. **Pet abilities (one page, from Petopia, not Wowhead; when a patch changes pets or beasts):**
   - Start the receiver: `python -I tools/wowhead/receive.py data/pets/petopia.json`
   - Open `https://www.wow-petopia.com/forever/abilities.php` in the browser and run the whole of
     `tools/petopia.js` there.
   - Then: `python -I tools/build_pets.py` (writes `jsalUI/Training/TameData.lua`; compare its
     beast count with the last commit's). Wowhead's own "Used by NPC" lists were tried first and
     dropped: they name every rank for most beasts, so the rank a beast really has can't be told.
   - **How often quest items drop, for the quest tags (about 770 pages below level 60, 1150 with
     `--all`):** the items asked for by quests new to Forever (in `data/quests/eglink.json`, not in
     pfQuest). For each batch: start the receiver writing to `<scratchpad>/drops_batch.json`, run
     the `window.__dropIds` line `python -I tools/wowhead/drop_items.py` prints and the whole of
     `drops.js` in the browser, then `python -I tools/wowhead/merge_quests.py <scratchpad>/drops_batch.json --drops`
     (it writes `data/quests/wowhead-drops.json`). The next batch carries on with
     what's left. When the list is empty, run `python -I tools/build_quest_scores.py`.
     `--classic` lists Classic's quest items instead; reading them showed Wowhead's counts are no use for
     quest items from busy creatures (it counts kills by players without the quest), so the build only takes
     a creature's rate there when at least half its kills dropped the item. EG Link's quest-only counts
     (`build_quest_scores.py --egloot`) are the better source; refresh them with each of its builds.
5. **Recipe sources (8 lists, then a few hundred vendor and recipe pages; one to two hours):**
   - Start the receiver: `python -I tools/wowhead/receive.py data/professions/wowhead-sources.json`
   - In the browser on a wowhead.com/forever page: `localStorage.removeItem('jsalRecipes')`, then the
     whole of `recipes.js`. Watch `window.__recipes` (`pages`, `left`, `err`); if it stops,
     confirm what the site asks and run `recipes.js` again (it carries on).
   - Then: `python -I tools/build_recipe_sources.py` (writes `jsalUI/Professions/RecipeSources.lua`;
     compare its recipe and vendor counts with the last commit's).
   - **Who sells the vendor reagents (39 item pages, then one page per new seller; about an hour):**
     EG Link only has the vendors its players opened, so the shopping list's "At <vendor>" line
     also takes each reagent's "Sold by" list from Wowhead. Start the receiver
     (`python -I tools/wowhead/receive.py data/vendors/wowhead-supplies.json`), then in the browser on
     a wowhead.com/forever page `localStorage.removeItem('jsalSupplies')`, the
     `window.__supplies = ...;` line `python -I tools/wowhead/supplies.py` prints, and the whole of
     `supplies.js`. Watch `window.__supply` (`left`, `wanted`, `supplies`, `err`); if it stops,
     confirm what the site asks and run the line and `supplies.js` again (it carries on). Sellers of trade
     supplies are read first; those with only water, milk or wood come last, and
     `window.__supplyStop = true` sends what's read without them. Then
     `python -I tools/build_professions.py <build>` (the build in ProfessionData.lua's header).
6. **Check and commit:** run the tests (`private/jsal-ui/tests`, in the jsal.io folder), look at
   the gear plan and a dungeon in game if you can, and commit on `beta` as
   "Data: Wowhead refresh (date)". It goes out with the next
   release.

## What's in each file

- `receive.py`: a one-shot local receiver; the browser page can't save files, so the data travels in
  the address of a page on 127.0.0.1:8799, which posts it back to the receiver.
- `gear.js`: every uncommon-or-better armor list (by type and slot), jewelry, cloaks, off-hand
  items, shields and each weapon type. Robes come with the chest lists.
- `recipes.js`: each profession's recipe list (a recipe's quest, single vendor or single mob), then
  every vendor's page: their side, zone, map spot and each recipe they sell with its price and
  stock. A vendor recipe no vendor read so far sells has its own page read for its "Sold by" list.
- `supplies.py`, `supplies.js`: each vendor reagent's "Sold by" list (seller, side, zones, price),
  then the page of each seller whose spot EG Link and the recipe read don't have.
- `bosses.py`, `dungeons.js`, `merge_dungeons.py`: each dungeon's zone page (quests, NPCs, and the
  Drops tab naming bosses) and each boss's NPC page (drops with Wowhead's kill counts). A drop is
  kept when it's uncommon or better and dropped in at least 2% of 10 or more kills, or when the
  zone's Drops tab names the boss.
- `place_items.py`, `places.js`, `merge_places.py`: each placeless drop's item page, the creatures
  under "Dropped by" with their NPC IDs, zones and Wowhead's counts (`count` drops in `outof`
  kills, kept as read). `build_gear.py` gives such an item a place in each dungeon the rule above
  allows: the dungeon alone, or "boss · dungeon" where only a boss drops it there.
