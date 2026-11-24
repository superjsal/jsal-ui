"""Folds a fresh read of Wowhead's dungeon pages (from tools/wowhead/dungeons.js) into
data/dungeons/wowhead.json: each boss's loot and each zone's quests are replaced by the fresh
ones; a boss or zone the fresh read didn't reach keeps what it had. Then run
tools/build_dungeons.py.

The read has every uncommon-or-better drop each boss's NPC pages list, with Wowhead's counts;
which of them the boss's card shows is decided here (`loot`), so the rule can change without
reading the pages again:
- Counted in 10 or more kills: a rare or better item dropped in at least 2% of them, or one the
  zone's Drops tab names the boss for (seen in under 1% of kills, it's written as 1, never 0); an
  uncommon item from 5%. Under 5%, an uncommon drop is one of the pool of random greens every
  level-60 boss has: Wowhead shows Classic Era's kill counts for the old bosses, and by them
  Gahz'ranka "drops" 52 such greens at 2 to 4% each, Nefarian 50. A piece of a set (the game's
  ItemSet table) counts from 1%: Scholomance's lesser bosses each drop the four Scholomance sets'
  pieces at 1 to 2% apiece, most of them under the 2% line.
- Listed on an NPC page with no counts at all: Wowhead knows the boss drops it but has counted no
  kills (Balnazzar's and the Avatar of Hakkar's whole lists). An uncounted item on a page that
  counts the rest is left out: Onyxia's lists a world epic that way.
- Seen in fewer than 10 kills (King Op's two pieces in 8): a rare or better item, or one the Drops
  tab names; an uncommon one may still be a random green.
The last two are written without a drop chance. A boss read with nothing to keep is written as an
empty list, so the build can tell it from one that was never read; one that had loot before keeps
it (a page that came back empty is more likely a bad read than loot taken away).

Run: python -I tools/wowhead/merge_dungeons.py <fresh.json>
"""
import csv
import json
import math
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
PATH = ROOT / "data" / "dungeons" / "wowhead.json"

COUNTED = 10      # kills before a drop's chance is counted
RARE_PCT = 2      # rare and better, counted
SET_PCT = 1       # a rare or better piece of a set, counted
UNCOMMON_PCT = 5  # uncommon, counted


def set_pieces():
    """Every item in one of the game's item sets (data/gear/ItemSet.csv)."""
    with open(ROOT / "data" / "gear" / "ItemSet.csv", newline="", encoding="utf-8") as f:
        return {int(v) for r in csv.DictReader(f) for k, v in r.items() if k.startswith("ItemID_") and v not in ("", "0")}


SET_PIECES = set_pieces()


def loot(read, named):
    """A boss's loot as [[item, percent or None], ...], from each of its NPC pages' drops
    ([npc, [[item, quality, count, kills], ...]], count -1 where Wowhead hasn't counted it) and the
    items its zone's Drops tab names it for. An encounter of several NPCs adds their counts
    together; each item is listed once."""
    named = set(named)
    items = {}
    for _npc, drops in read:
        # On a page with counts, an uncounted drop is a stray (Onyxia's page counts 100 drops and
        # lists a world epic with none); only a page with no counts at all is the boss's own list.
        counted = any(count >= 0 and kills > 0 for _, _, count, kills in drops)
        for item, quality, count, kills in drops:
            o = items.setdefault(item, [0, 0, quality, False])
            if count >= 0:
                o[0] += count
                o[1] += kills
            elif not counted:
                o[3] = True
    out = []
    for item, (count, kills, quality, uncounted) in items.items():
        if kills >= COUNTED:
            share = count / kills * 100
            # Rounded half up, as the browser rounds.
            pct = max(1 if count > 0 else 0, math.floor(share + 0.5))
            if quality > 2:
                keep = pct >= RARE_PCT or (item in SET_PIECES and share >= SET_PCT) or item in named
            else:
                keep = pct >= UNCOMMON_PCT
        elif kills > 0:
            pct = None
            keep = quality > 2 or item in named
        else:
            pct = None
            keep = uncounted or item in named
        if keep:
            out.append([item, pct])
    return out


def main():
    old = json.loads(PATH.read_text(encoding="utf-8"))
    new = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
    changed, emptied, kept_old, unmatched = 0, [], [], []
    for z, fresh in new["zones"].items():
        zone = old["zones"].setdefault(z, {"loot": {}, "quests": []})
        for boss, read in fresh.get("drops", {}).items():
            drops = loot(read, fresh.get("named", {}).get(boss, []))
            have = zone["loot"].get(boss)
            if not drops and have:
                kept_old.append(f"{z}: {boss}")
                continue
            if not drops:
                emptied.append(f"{z}: {boss}")
            if have != drops:
                zone["loot"][boss] = drops
                changed += 1
        unmatched += [f"{z}: {boss}" for boss in fresh.get("unmatched", [])]
        if fresh.get("quests"):
            zone["quests"] = fresh["quests"]
    old["fetched"] = new.get("fetched", old.get("fetched"))
    # The file's own layout: one zone to a line.
    lines = [f"{json.dumps(z)}: {json.dumps(v, ensure_ascii=False, separators=(',', ':'))}" for z, v in old["zones"].items()]
    text = "{\n" + f'"fetched": {json.dumps(old["fetched"])},\n' + '"zones": {\n' + ",\n".join(lines) + "\n}\n}\n"
    PATH.write_text(text, encoding="utf-8")
    print(f"{changed} bosses' loot changed; read on {old['fetched']}")
    if emptied:
        print("Read, with nothing to keep: " + "; ".join(emptied))
    if kept_old:
        print("Read empty, old loot kept: " + "; ".join(kept_old))
    if unmatched:
        print("No NPC found on the zone's page (add to ALIAS or NPC_ID in bosses.py): " + "; ".join(unmatched))


if __name__ == "__main__":
    main()
