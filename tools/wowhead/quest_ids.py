"""Prints the window.__questIds line for tools/wowhead/quests.js: every quest the dungeon guide
lists (from jsalUI/Dungeons/DungeonLoot.lua). With --missing, only the ones
data/dungeons/quest-starts.json doesn't have yet, and a window.__questSeen line with the ones it
has (earlier steps of chains included), so quests.js doesn't read them again.

Run: python -I tools/wowhead/quest_ids.py [--missing]
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
LOOT = ROOT / "jsalUI" / "Dungeons" / "DungeonLoot.lua"
STARTS = ROOT / "data" / "dungeons" / "quest-starts.json"

text = LOOT.read_text(encoding="utf-8")
quests = text[text.index("ns.DungeonQuests"):]
ids = sorted({int(m) for m in re.findall(r"^\s+\{ (\d+), ", quests, re.M)})
seen = []
if "--missing" in sys.argv and STARTS.exists():
    have = json.loads(STARTS.read_text(encoding="utf-8"))["quests"]
    ids = [i for i in ids if str(i) not in have]
    seen = sorted(int(k) for k in have)
print(f"window.__questIds = {json.dumps(ids)};")
print(f"window.__questSeen = {json.dumps(seen)};")
