"""Prints the window.__dropIds line for tools/wowhead/drops.js: the items asked for by quests new to
Forever (in data/quests/eglink.json but not pfQuest's data/quests/pfquest.json), below level 60
unless --all, leaving out the ones data/quests/wowhead-drops.json already has.

Run: python -I tools/wowhead/drop_items.py [--all]
"""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
eg = json.loads((ROOT / "data" / "quests" / "eglink.json").read_text(encoding="utf-8"))["quests"]
pf = json.loads((ROOT / "data" / "quests" / "pfquest.json").read_text(encoding="utf-8"))["quests"]
have_file = ROOT / "data" / "quests" / "wowhead-drops.json"
have = json.loads(have_file.read_text(encoding="utf-8"))["items"] if have_file.exists() else {}
everything = "--all" in sys.argv
ids = set()
for qid, q in eg.items():
    if qid in pf or not q.get("items"):
        continue
    if not everything and (q.get("level") or 0) >= 60:
        continue
    ids.update(i for i in q["items"] if str(i) not in have)
print(f"// {len(ids)} items")
print(f"window.__dropIds = {json.dumps(sorted(ids))};")
