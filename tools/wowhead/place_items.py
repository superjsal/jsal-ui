"""Prints the window.__placeIds line for tools/wowhead/places.js: the items in
data/gear/wowhead-items.json that Wowhead lists as a drop (source exactly [2]) with no place of
their own (an empty sourcemore), rare or better and needing level 50 or more, leaving out the ones
data/gear/wowhead-places.json already has. These drop from ordinary creatures in more than one
place, so the item's summary names none; its own page's "Dropped by" list says who and where.

Run: python -I tools/wowhead/place_items.py [--min-level N] [--quality N] [--all]
     python -I tools/wowhead/place_items.py --why [<places file>]
  --min-level N  the lowest required level asked for (default 50)
  --quality N    the lowest quality asked for: 2 uncommon, 3 rare, 4 epic (default 3)
  --all          list them again even when wowhead-places.json has them
  --why          for each item read (in wowhead-places.json, or the file given), the rule that placed it
                 in its dungeons or left it out (tools/build_gear.py's), with its shares
"""
import argparse
import json
import pathlib
import sys

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


def why(path):
    """Prints, for each item read, which of build_gear.py's rules placed it or left it out, and its numbers."""
    sys.path.insert(0, str(ROOT / "tools"))
    import build_gear
    zones = json.loads((ROOT / "data" / "gear" / "zones.json").read_text(encoding="utf-8"))
    names = {i[0]: i[1] for i in json.loads(ITEMS.read_text(encoding="utf-8"))["items"]}
    inside, bosses, levels, sets = build_gear.place_context(zones)
    read = json.loads(pathlib.Path(path).read_text(encoding="utf-8"))["items"]
    rules = {}
    for item_id in sorted(read, key=int):
        entry = read[item_id]
        name = names.get(int(item_id)) or entry.get("name") or "?"
        if entry.get("missing"):
            print(f"{item_id} {name}: no page on Wowhead")
            rules["no page"] = rules.get("no page", 0) + 1
            continue
        places, w = build_gear.placed(entry, zones, inside, bosses, levels, int(item_id) in sets)
        rules[w["rule"]] = rules.get(w["rule"], 0) + 1
        each = ", ".join(f"{z} {s:.0%}" for z, s in sorted(w["dungeons"].items(), key=lambda d: -d[1]))
        print(f"{item_id} {name}: {w['rule']}{' (a set piece)' if w['set'] and w['rule'] != 'set piece' else ''}"
              f" -> {', '.join(places) or 'no place'}"
              f"  [dungeons {w['share']:.0%} by {w['by']}, of {len(entry.get('npcs') or [])} creatures"
              f"{': ' + each if each else ''}]")
    print(f"// {len(read)} read: " + ", ".join(f"{n} {r}" for r, n in sorted(rules.items())))
    print(f"// a non-set piece needs more than {build_gear.MOSTLY_IN_DUNGEONS:.0%} in dungeons, "
          f"and {build_gear.DUNGEON_SHARE:.0%} in a dungeon for its place there")


def main():
    if "--why" in sys.argv[1:]:
        i = sys.argv.index("--why")
        rest = sys.argv[i + 1:]
        return why(rest[0] if rest and not rest[0].startswith("--") else PLACES)
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
