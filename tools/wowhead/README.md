# Refreshing the Wowhead data (monthly)

The gear plan's items (`data/gear/wowhead-items.json`) and the dungeon guide's loot and quests
(`data/dungeons/wowhead.json`) are read from Wowhead Forever in the browser pane, since Wowhead
turns away scripted downloads. New Forever items and drop chances only reach jsal.ui when these
are read again. A reminder lands on John's to-do list on the 7th of each month.

Wowhead asks for a Human Verification after about 70 pages close together. The scripts stop
there and keep what they've read; John clears the check in the browser pane, and running the
same script again carries on. Never try to get past the check another way.

## Steps (for a Claude Code session in this repo, on the `beta` branch)

1. **Gear (53 pages, about 11 minutes):**
   - Start the receiver in the background:
     `python -I tools/wowhead/receive.py data/gear/wowhead-items.json`
   - Open `https://www.wowhead.com/forever` in the browser pane. With javascript_tool, run
     `localStorage.removeItem('jsalGear')`, then the whole of `gear.js`.
   - Check `window.__gear` now and then (`log`, `err`, `done`). On `err: "blocked at ..."`, ask
     John to clear the check in the pane, then run `gear.js` again (it carries on).
   - When every list is in, the tab goes to the receiver and the file is written.
   - Then: `python -I tools/build_gear.py` (writes `jsalUI/Gear/GearData.lua`; compare its item
     count with the last commit's).
2. **Dungeons (about 100 pages with `--thin`; a full read is about 190):**
   - `python -I tools/wowhead/bosses.py --thin` prints a `window.__bosses = ...;` line: the
     bosses whose loot is still filling in. Leave out `--thin` for a full read (every few months).
   - Start the receiver writing to a scratch file:
     `python -I tools/wowhead/receive.py <scratchpad>/dungeons-fresh.json`
   - In the pane on a wowhead.com/forever page: `localStorage.removeItem('jsalDungeons')`, the
     `window.__bosses` line, then the whole of `dungeons.js`. Watch `window.__dungeons`; on a
     block, John clears it and you run `dungeons.js` again (with `window.__bosses` still set).
   - `python -I tools/wowhead/merge_dungeons.py <scratchpad>/dungeons-fresh.json` folds it into
     `data/dungeons/wowhead.json` (bosses not reached keep their old loot), then
     `python -I tools/build_dungeons.py` (writes `DungeonLoot.lua`). `__dungeons.unmatched`
     names bosses Wowhead lists under another name: add them to `ALIAS` in `bosses.py`.
   - **Where each dungeon quest starts (about 500 pages at one every 10 seconds, in batches):**
     after `build_dungeons.py`, for each batch: start the receiver writing to a scratch file
     (`python -I tools/wowhead/receive.py <scratchpad>/batch.json`), then in the pane on a
     wowhead.com/forever page run the two lines `python -I tools/wowhead/quest_ids.py --missing`
     prints, then the whole of `quests.js`. Keep the pane showing: hidden, it slows to a page a
     minute. Wowhead challenges it about every 25 pages; the batch then sends what it read to the
     receiver. `python -I tools/wowhead/merge_quests.py <scratchpad>/batch.json` folds it into
     `data/dungeons/quest-starts.json` and says where it stopped; John clears the check in the
     pane, and the next batch carries on. When a batch ends with nothing missing, run
     `build_dungeons.py` again (it writes the starts into `DungeonLoot.lua`).
   - **Who drops the items that start quests (about 40 pages):** after the quest starts, for a
     quest Wowhead names no starter for, the game's item table may say which item starts it. Start
     the receiver writing to `<scratchpad>/items.json`, run the line
     `python -I tools/wowhead/quest_items.py` prints and the whole of `items.js` in the pane, then
     `python -I tools/wowhead/merge_quests.py <scratchpad>/items.json --items` (it writes
     `data/dungeons/quest-items.json`). Repeat after a check until the list is empty, then run
     `build_dungeons.py` again.
3. **Pet abilities (one page, from Petopia, not Wowhead; when a patch changes pets or beasts):**
   - Start the receiver: `python -I tools/wowhead/receive.py data/pets/petopia.json`
   - Open `https://www.wow-petopia.com/forever/abilities.php` in the pane and run the whole of
     `tools/petopia.js` there.
   - Then: `python -I tools/build_pets.py` (writes `jsalUI/Training/TameData.lua`; compare its
     beast count with the last commit's). Wowhead's own "Used by NPC" lists were tried first and
     dropped: they name every rank for most beasts, so the rank a beast really has can't be told.
   - **How often quest items drop, for the quest tags (about 770 pages below level 60, 1150 with
     `--all`):** the items asked for by quests new to Forever (in `data/quests/eglink.json`, not in
     pfQuest). For each batch: start the receiver writing to `<scratchpad>/drops_batch.json`, run
     the `window.__dropIds` line `python -I tools/wowhead/drop_items.py` prints and the whole of
     `drops.js` in the pane, then `python -I tools/wowhead/merge_quests.py <scratchpad>/drops_batch.json --drops`
     (it writes `data/quests/wowhead-drops.json`). After a check, the next batch carries on with
     what's left. When the list is empty, run `python -I tools/build_quest_scores.py`.
4. **Recipe sources (8 lists, then a few hundred vendor and recipe pages; one to two hours):**
   - Start the receiver: `python -I tools/wowhead/receive.py data/professions/wowhead-sources.json`
   - In the pane on a wowhead.com/forever page: `localStorage.removeItem('jsalRecipes')`, then the
     whole of `recipes.js`. Watch `window.__recipes` (`pages`, `left`, `err`); on a block, John
     clears it and you run `recipes.js` again (it carries on).
   - Then: `python -I tools/build_recipe_sources.py` (writes `jsalUI/Professions/RecipeSources.lua`;
     compare its recipe and vendor counts with the last commit's).
5. **Check and commit:** run the tests (`private/jsal-ui/tests`, in the jsal.io folder), look at
   the gear plan and a dungeon in game if John can, and commit on `beta` as
   "Data: Wowhead refresh (date)" with no Claude co-author line. It goes out with the next
   release; tick the to-do on John's list.

## What's in each file

- `receive.py`: a one-shot local receiver; the pane can't download files, so the data travels in
  the address of a page on 127.0.0.1:8799, which posts it back to the receiver.
- `gear.js`: every uncommon-or-better armor list (by type and slot), jewelry, cloaks, off-hand
  items, shields and each weapon type. Robes come with the chest lists.
- `recipes.js`: each profession's recipe list (a recipe's quest, single vendor or single mob), then
  every vendor's page: their side, zone, map spot and each recipe they sell with its price and
  stock. A vendor recipe no vendor read so far sells has its own page read for its "Sold by" list.
- `bosses.py`, `dungeons.js`, `merge_dungeons.py`: each dungeon's zone page (quests, NPCs, and the
  Drops tab naming bosses) and each boss's NPC page (drops with Wowhead's kill counts). A drop is
  kept when it's uncommon or better and dropped in at least 2% of 10 or more kills, or when the
  zone's Drops tab names the boss.
