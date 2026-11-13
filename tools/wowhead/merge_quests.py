"""Folds one batch of tools/wowhead/quests.js into data/dungeons/quest-starts.json (or, with
--items, of items.js into data/dungeons/quest-items.json): the batch's entries are added to (or
replace) the file's, and the batch's "stopped" note, if any, is kept so the next batch knows
where it ended.

Run: python -I tools/wowhead/merge_quests.py <the batch file receive.py wrote> [--items]
"""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
ITEMS = "--items" in sys.argv
STARTS = ROOT / "data" / "dungeons" / ("quest-items.json" if ITEMS else "quest-starts.json")
KEY = "items" if ITEMS else "quests"

batch = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
data = json.loads(STARTS.read_text(encoding="utf-8")) if STARTS.exists() else {KEY: {}}
before = len(data[KEY])
data[KEY].update(batch[KEY])
data["fetched"] = batch["fetched"]
if batch.get("stopped"):
    data["stopped"] = batch["stopped"]
else:
    data.pop("stopped", None)
STARTS.write_text(json.dumps(data, indent=1, sort_keys=True) + "\n", encoding="utf-8", newline="\n")
print(f"{len(data[KEY]) - before} new, {len(data[KEY])} in all; stopped: {data.get('stopped')}")
