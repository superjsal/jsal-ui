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

A piece listed under three or more bosses of one 5-man dungeon is dungeon-wide, not any boss's own:
it goes on the dungeon's Trash card once (the zone's "trash", by the dungeon's LFG ID) and comes off
those bosses' cards (`wide`). A boss keeps it when the zone's Drops tab names it for that boss, or when
the boss drops it at 4% or more. Only a rare-or-better piece counts, or an uncommon one that belongs to
a set or is one of Forever's own dungeon-wide pieces (items 251000 to 254999): the rest are random
greens. A piece listed under bosses of three or more different zones is a world drop and is left out
altogether, Forever's own pieces included. Raids are left as they are.

Run: python -I tools/wowhead/merge_dungeons.py <fresh.json>
"""
import csv
import json
import math
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
PATH = ROOT / "data" / "dungeons" / "wowhead.json"

COUNTED = 10      # kills before a drop's chance is counted
RARE_PCT = 2      # rare and better, counted
SET_PCT = 1       # a rare or better piece of a set, counted
UNCOMMON_PCT = 5  # uncommon, counted
LISTED_PCT = 0.1  # a boss lists an item for the dungeon-wide test from this share of kills
WIDE_BOSSES = 3   # bosses of one dungeon that list a piece before it is dungeon-wide
WORLD_ZONES = 3   # zones whose bosses list a piece before it is a world drop
OWN_PCT = 4       # a boss that drops a dungeon-wide piece at this share (twice the rare line) keeps it
FOREVER_WIDE = range(251000, 255000)  # Forever's own dungeon-wide pieces


def set_pieces():
    """Every item in one of the game's item sets (data/gear/ItemSet.csv)."""
    with open(ROOT / "data" / "gear" / "ItemSet.csv", newline="", encoding="utf-8") as f:
        return {int(v) for r in csv.DictReader(f) for k, v in r.items() if k.startswith("ItemID_") and v not in ("", "0")}


SET_PIECES = set_pieces()


def tally(read):
    """A boss's NPC pages' drops added together: { item: [count, kills, quality, uncounted] }, where
    uncounted is true for an item on a page with no counts at all."""
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
    return items


def loot(read, named):
    """A boss's loot as [[item, percent or None], ...], from each of its NPC pages' drops
    ([npc, [[item, quality, count, kills], ...]], count -1 where Wowhead hasn't counted it) and the
    items its zone's Drops tab names it for. An encounter of several NPCs adds their counts
    together; each item is listed once."""
    named = set(named)
    items = tally(read)
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


def listed(read):
    """What a boss's pages list for the dungeon-wide test: { item: (percent of kills, quality) } for
    the items counted in enough kills and seen in at least LISTED_PCT of them, so a stray sighting
    in thousands of kills isn't a listing."""
    return {item: (count / kills * 100, quality) for item, (count, kills, quality, _) in tally(read).items()
            if kills >= COUNTED and count / kills * 100 >= LISTED_PCT}


def world_drops(zones):
    """The items that drop all over the world: those any boss of WORLD_ZONES or more different zones
    lists at all. `zones` is { zone: { boss: read } }."""
    seen = {}
    for zone, bosses in zones.items():
        for read in bosses.values():
            for item, (count, _, _, _) in tally(read).items():
                if count > 0:
                    seen.setdefault(item, set()).add(zone)
    return {item for item, where in seen.items() if len(where) >= WORLD_ZONES}


def wide(reads, named, world):
    """The dungeon-wide pieces of one dungeon: { item: the bosses that keep it on their card }, from
    its bosses' reads ({ boss: read }) and what the zone's Drops tab names each for ({ boss: [item] }).
    An item is dungeon-wide when WIDE_BOSSES or more bosses list it, it isn't a world drop, and it is
    rare or better, a piece of a set, or one of Forever's own. Forever's own pieces are no
    exception: one listed under bosses of three or more zones is out. A boss keeps one it is named for or drops at OWN_PCT or more."""
    lists = {boss: listed(read) for boss, read in reads.items()}
    out = {}
    for item in {i for items in lists.values() for i in items}:
        where = [boss for boss, items in lists.items() if item in items]
        quality = lists[where[0]][item][1]
        if len(where) < WIDE_BOSSES or item in world:
            continue
        if quality > 2 or item in SET_PIECES or item in FOREVER_WIDE:
            out[item] = {boss for boss in reads
                         if item in named.get(boss, []) or lists[boss].get(item, (0,))[0] >= OWN_PCT}
    return out


def split(reads, named, world):
    """One dungeon's loot, from its bosses' reads ({ boss: read }), what the zone's Drops tab names
    each for ({ boss: [item] }) and the world drops: ({ boss: [[item, percent or None], ...] },
    the dungeon-wide pieces for its Trash card). A dungeon-wide piece is on its Trash card once, and
    off the bosses' cards, except where a boss keeps it (`wide`); then it stays on that boss's card
    alone and is not on the Trash card."""
    pieces = wide(reads, named, world)
    kept = {}
    for boss, read in reads.items():
        kept[boss] = [d for d in loot(read, named.get(boss, [])) if d[0] not in pieces or boss in pieces[d[0]]]
    return kept, sorted(item for item, keepers in pieces.items() if not keepers)


def dungeons():
    """The 5-man dungeons by Wowhead zone: { zone: [(LFG ID, [its bosses' names])] }. A zone can hold
    several (Blackrock Spire's two, Dire Maul's three wings). Raids aren't here."""
    import build_dungeons
    out = {}
    for raid, _level, _name, lfg_id, _map, _zone, _faction, bosses in build_dungeons.dungeon_rows():
        if not raid:
            out.setdefault(str(build_dungeons.WOWHEAD_ZONE[lfg_id]), []).append((lfg_id, [b[2] for b in bosses]))
    return out


def main():
    old = json.loads(PATH.read_text(encoding="utf-8"))
    new = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
    changed, emptied, kept_old, unmatched = 0, [], [], []
    world = world_drops({z: fresh.get("drops", {}) for z, fresh in new["zones"].items()})
    where = dungeons()
    for z, fresh in new["zones"].items():
        zone = old["zones"].setdefault(z, {"loot": {}, "quests": []})
        named = fresh.get("named", {})
        read_all = fresh.get("drops", {})
        # A dungeon's wide pieces are worked out only from a read of every one of its bosses; a
        # dungeon read in part keeps its trash list and its bosses' loot by the plain rule.
        trash = zone.setdefault("trash", {})
        split_loot = {}
        for lfg_id, names in where.get(z, []):
            if not all(n in read_all or n in fresh.get("unmatched", []) for n in names):
                continue
            kept, trash[str(lfg_id)] = split({n: read_all[n] for n in names if n in read_all}, named, world)
            split_loot.update(kept)
        if not trash:
            del zone["trash"]
        for boss, read in read_all.items():
            drops = split_loot[boss] if boss in split_loot else loot(read, named.get(boss, []))
            have = zone["loot"].get(boss)
            # A boss whose every piece moved to the Trash card is read, and empty.
            moved_all = not drops and boss in split_loot and loot(read, named.get(boss, []))
            if not drops and have and not moved_all:
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
