"""Prints the line tools/wowhead/supplies.js needs first: the vendor reagents (from the shipped
ProfessionData.lua) and the vendors whose spot is known already (EG Link's, and those the recipe
read took from Wowhead), so their pages aren't read again.

Run: python -I tools/wowhead/supplies.py
"""
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
lua = (ROOT / "jsalUI" / "Professions" / "ProfessionData.lua").read_text(encoding="utf-8")
vendor = re.search(r"^\s*vendor = \{(.*)\},\s*$", lua, re.M).group(1)
items = sorted(int(i) for i in re.findall(r"\[(\d+)\] =", vendor))
known = set(int(n) for n in json.loads((ROOT / "data" / "vendors" / "eglink-vendors.json").read_text(encoding="utf-8"))["vendors"])
sources = ROOT / "data" / "professions" / "wowhead-sources.json"
for npc, v in json.loads(sources.read_text(encoding="utf-8")).get("npcs", {}).items():
    if v.get("spot"):
        known.add(int(npc))
print("window.__supplies = " + json.dumps({"items": items, "known": sorted(known)}, separators=(",", ":")) + ";")
