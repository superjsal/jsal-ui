"""Copies the Drop log's counts from a COPY of the saved file into data/quests/own-drops.json, so the
quest tags ship them for guildmates. The Drop log counts a quest item only while a quest still needs
it, the fair measure (as EG Link's players-on-the-quest counts are). Never point this at the game's
own file: copy WTF\\Account\\...\\SavedVariables\\jsalUI.lua somewhere first. The saved file is read
as data, never run. Nothing else in it is copied.

Counts only ever grow, so a bake keeps, for each item, the larger of the old and new tries (a new
character's log starting at zero doesn't wipe what an older bake had).

Run: python -I tools/bake_drops.py "<a copy of jsalUI.lua>"   then   python -I tools/build_quest_scores.py
"""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
from luadata import table_after  # noqa: E402

OUT = ROOT / "data" / "quests" / "own-drops.json"


def main(path):
    saved = pathlib.Path(path)
    if "WTF" in saved.parts and "SavedVariables" in saved.parts:
        sys.exit("That's the game's own saved file: copy it somewhere and bake from the copy.")
    log = table_after(saved.read_text(encoding="utf-8"), '["lootLog"] =')
    counts = {}
    for creature in (log.get("creatures") or {}).values():
        tries = creature.get("tries") or {}
        for item, finds in (creature.get("finds") or {}).items():
            if finds > 0:
                row = counts.setdefault(item, [0, 0])
                row[0] += finds
                row[1] += tries.get(item, 0)
    ids = log.get("ids") or {}
    old = json.loads(OUT.read_text(encoding="utf-8"))["items"] if OUT.exists() else {}
    items = dict(old)
    for name, (finds, tries) in counts.items():
        key = str(ids.get(name) or name)
        if tries > old.get(key, {}).get("tries", 0):
            items[key] = {"name": name, "finds": finds, "tries": tries}
    OUT.write_text(json.dumps({"about": "How often quest items dropped for jsal.ui's Drop log while the quest "
                                        "still needed them, baked by tools/bake_drops.py from a copy of the saved file.",
                               "items": items}, indent=1, sort_keys=True) + "\n", encoding="utf-8")
    print(f"kept {len(items)} items in {OUT.relative_to(ROOT)}: " +
          ", ".join(f"{v['name']} {v['finds']} in {v['tries']}" for v in items.values()))


if __name__ == "__main__":
    main(sys.argv[1])
