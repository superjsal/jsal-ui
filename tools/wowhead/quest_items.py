"""Prints the window.__itemIds line for tools/wowhead/items.js: every item that starts a quest
data/dungeons/quest-starts.json has no starter for (the game's ItemSparse table, StartQuestID),
leaving out the ones data/dungeons/quest-items.json already has.

Run: python -I tools/wowhead/quest_items.py
"""
import csv
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
STARTS = ROOT / "data" / "dungeons" / "quest-starts.json"
ITEMS = ROOT / "data" / "dungeons" / "quest-items.json"

quests = json.loads(STARTS.read_text(encoding="utf-8"))["quests"]
have = json.loads(ITEMS.read_text(encoding="utf-8"))["items"] if ITEMS.exists() else {}
ids = set()
with open(ROOT / "data" / "professions" / "ItemSparse.csv", newline="", encoding="utf-8") as f:
    for r in csv.DictReader(f):
        q = quests.get(r["StartQuestID"])
        if q is not None and not q.get("s") and r["ID"] not in have:
            ids.add(int(r["ID"]))
print(f"window.__itemIds = {json.dumps(sorted(ids))};")
