"""Prints the window.__placeIds line for tools/wowhead/places.js: the items in
data/gear/wowhead-items.json that Wowhead lists as a drop (source exactly [2]) with no place of
their own (an empty sourcemore), rare or better and needing level 50 or more, leaving out the ones
data/gear/wowhead-places.json already has. These drop from ordinary creatures in more than one
place, so the item's summary names none; its own page's "Dropped by" list says who and where.

Run: python -I tools/wowhead/place_items.py [--min-level N] [--quality N] [--all]
  --min-level N  the lowest required level asked for (default 50)
  --quality N    the lowest quality asked for: 2 uncommon, 3 rare, 4 epic (default 3)
  --all          list them again even when wowhead-places.json has them
"""
import argparse
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
ITEMS = ROOT / "data" / "gear" / "wowhead-items.json"
PLACES = ROOT / "data" / "gear" / "wowhead-places.json"


def wanted(items, have, min_level, quality):
    """The item IDs to read, in order: a drop with no place, at that quality and level or above."""
    ids = set()
    for item in items:
        item_id, _name, q, req = item[:4]
        source, more = item[10], item[11]
        if source != [2] or more:
            continue
        if (q or 0) < quality or (req or 0) < min_level:
            continue
        if str(item_id) in have:
            continue
        ids.add(item_id)
    return sorted(ids)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--min-level", type=int, default=50)
    p.add_argument("--quality", type=int, default=3)
    p.add_argument("--all", action="store_true")
    a = p.parse_args()
    items = json.loads(ITEMS.read_text(encoding="utf-8"))["items"]
    have = {}
    if PLACES.exists() and not a.all:
        have = json.loads(PLACES.read_text(encoding="utf-8"))["items"]
    ids = wanted(items, have, a.min_level, a.quality)
    print(f"// {len(ids)} items")
    print(f"window.__placeIds = {json.dumps(ids)};")


if __name__ == "__main__":
    main()
