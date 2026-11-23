"""Folds one batch of tools/wowhead/places.js into data/gear/wowhead-places.json: per item ID, the
creatures that drop it ({name, npc, zones, classification, count, outof}, the numbers as Wowhead
gave them) and the date read. Items not in the batch keep what earlier reads gave; an item the
batch has replaces its old entry. The batch's "stopped" note, if any, is kept so the next batch
knows where it ended. Then it says how many items place_items.py still lists.

Run: python -I tools/wowhead/merge_places.py <the batch file receive.py wrote> [--out <file>]
"""
import json
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent.parent
sys.path.insert(0, str(HERE))
import place_items  # noqa: E402


def entry(read, fetched):
    """One item's entry from what places.js read for it."""
    if read.get("missing"):
        return {"fetched": fetched, "missing": True}
    npcs = [{"name": n["name"], "npc": n["id"], "zones": n.get("zones") or [],
             "classification": n.get("classification") or 0,
             "count": n.get("count"), "outof": n.get("outof")} for n in read.get("npcs") or []]
    return {"fetched": fetched, "npcs": npcs}


def merge(data, batch):
    """Adds the batch's items to data (a {"items": {...}} table) and returns how many were new."""
    before = len(data["items"])
    for item_id, read in batch["items"].items():
        data["items"][str(item_id)] = entry(read, batch["fetched"])
    data["fetched"] = batch["fetched"]
    if batch.get("stopped"):
        data["stopped"] = batch["stopped"]
    else:
        data.pop("stopped", None)
    return len(data["items"]) - before


def main():
    args = sys.argv[1:]
    out = place_items.PLACES
    if "--out" in args:
        i = args.index("--out")
        out = pathlib.Path(args[i + 1])
        del args[i:i + 2]
    batch = json.loads(pathlib.Path(args[0]).read_text(encoding="utf-8"))
    data = json.loads(out.read_text(encoding="utf-8")) if out.exists() else {"items": {}}
    new = merge(data, batch)
    out.write_text(json.dumps(data, indent=1, sort_keys=True) + "\n", encoding="utf-8", newline="\n")
    items = json.loads(place_items.ITEMS.read_text(encoding="utf-8"))["items"]
    left = place_items.wanted(items, data["items"], 50, 3)
    print(f"{new} new, {len(data['items'])} in all; stopped: {data.get('stopped')}")
    print(f"still to read at level 50, rare or better: {len(left)}" + (f" ({left[0]} first)" if left else ""))


if __name__ == "__main__":
    main()
