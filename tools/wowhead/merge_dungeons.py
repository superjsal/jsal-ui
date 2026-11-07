"""Folds a fresh read of Wowhead's dungeon pages (from tools/wowhead/dungeons.js) into
data/dungeons/wowhead.json: each boss's loot and each zone's quests are replaced by the fresh
ones; a boss or zone the fresh read didn't reach keeps what it had. Then run
tools/build_dungeons.py.

Run: python -I tools/wowhead/merge_dungeons.py <fresh.json>
"""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
PATH = ROOT / "data" / "dungeons" / "wowhead.json"

old = json.loads(PATH.read_text(encoding="utf-8"))
new = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
changed = 0
for z, fresh in new["zones"].items():
    zone = old["zones"].setdefault(z, {"loot": {}, "quests": []})
    for boss, drops in fresh.get("loot", {}).items():
        if drops and zone["loot"].get(boss) != drops:
            zone["loot"][boss] = drops
            changed += 1
    if fresh.get("quests"):
        zone["quests"] = fresh["quests"]
old["fetched"] = new.get("fetched", old.get("fetched"))
# The file's own layout: one zone to a line.
lines = [f"{json.dumps(z)}: {json.dumps(v, ensure_ascii=False, separators=(',', ':'))}" for z, v in old["zones"].items()]
text = "{\n" + f'"fetched": {json.dumps(old["fetched"])},\n' + '"zones": {\n' + ",\n".join(lines) + "\n}\n}\n"
PATH.write_text(text, encoding="utf-8")
print(f"{changed} bosses' loot changed; read on {old['fetched']}")
