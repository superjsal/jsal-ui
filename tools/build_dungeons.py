"""Builds jsalUI/Dungeons/DungeonData.lua: Forever's dungeons and raids, and their bosses in order.

From the game's own files (data/dungeons/, CSV from wago.tools for the build named below):
LFGDungeons is the list of dungeons the game offers, with the level each is tuned to in
ContentTuning (MinLevelSquish) and its faction (0 Horde, 1 Alliance, -1 both); Map says which
map each one is and whether it's a raid; DungeonEncounter has each map's bosses, with the ID the
game's ENCOUNTER_END event reports and their order. Season of Discovery's versions of some
dungeons are in the files too, under their own difficulties (198, 201, 215); Forever uses 0 and 1.

Where each entrance is isn't in the files, so it's below (Forever's new dungeons from Blizzard's
own announcement). Blackrock Spire and Dire Maul are one map each in the files but separate
dungeons in the list, so their bosses are split by wing below.

It also builds jsalUI/Dungeons/DungeonLoot.lua from Wowhead Forever (data/dungeons/wowhead.json,
read from each dungeon's zone page and each boss's NPC page; see the README): each boss's loot,
uncommon and better, with the drop chance Wowhead has seen, and each dungeon's quests. Wowhead's
lists are by zone and NPC name; a boss here is matched by name (an encounter of several NPCs, like
The Lost Dwarves, by theirs), and Blackrock Spire's and Dire Maul's quests go to each of its wings.

Where each quest starts, and the quest before it, comes from data/dungeons/quest-starts.json
(tools/wowhead/quests.js) and the game's UiMapAssignment table in data/maps/, from
https://wago.tools/db2/UiMapAssignment/csv?build=<the build below>.

Run: python -I tools/build_dungeons.py
"""

import csv
import json
import pathlib
import sys

# python -I leaves this folder off the path, so it's put there for maps.py.
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from maps import forever_spot  # noqa: E402

BUILD = "1.60.1.70790"
ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "data" / "dungeons"
OUT = ROOT / "jsalUI" / "Dungeons" / "DungeonData.lua"
LOOT_OUT = ROOT / "jsalUI" / "Dungeons" / "DungeonLoot.lua"

# LFGDungeons ID: Wowhead Forever's zone for it.
WOWHEAD_ZONE = {
    3: 2437, 3273: 16919, 3272: 16611, 5: 1581, 1: 718, 7: 209, 9: 719, 11: 717, 15: 491, 13: 721,
    3274: 16732, 3271: 16544, 17: 796, 19: 722, 21: 1337, 23: 1176, 25: 2100, 27: 1477, 29: 1584,
    31: 1583, 43: 1583, 33: 2557, 35: 2557, 37: 2557, 39: 2017, 2: 2057, 41: 1977, 45: 2159,
    47: 2717, 49: 2677,
}

# LFGDungeons ID: (map ID, display name, where the entrance is).
DUNGEONS = {
    3: (389, "Ragefire Chasm", "Orgrimmar"),
    3273: (3065, "Hall of Thanes", "Dun Morogh"),
    3272: (2999, "Ruins of Lordaeron", "Tirisfal Glades"),
    5: (36, "The Deadmines", "Westfall"),
    1: (43, "Wailing Caverns", "The Barrens"),
    7: (33, "Shadowfang Keep", "Silverpine Forest"),
    9: (48, "Blackfathom Deeps", "Ashenvale"),
    11: (34, "The Stockade", "Stormwind City"),
    15: (47, "Razorfen Kraul", "The Barrens"),
    13: (90, "Gnomeregan", "Dun Morogh"),
    3274: (2998, "Excavation Site: Wetlands", "Wetlands"),
    3271: (2959, "City of Dalaran", "Alterac Mountains"),
    17: (189, "Scarlet Monastery", "Tirisfal Glades"),
    19: (129, "Razorfen Downs", "The Barrens"),
    21: (70, "Uldaman", "Badlands"),
    23: (209, "Zul'Farrak", "Tanaris"),
    25: (349, "Maraudon", "Desolace"),
    27: (109, "Sunken Temple", "Swamp of Sorrows"),
    29: (230, "Blackrock Depths", "Blackrock Mountain"),
    31: (229, "Lower Blackrock Spire", "Blackrock Mountain"),
    43: (229, "Upper Blackrock Spire", "Blackrock Mountain"),
    33: (429, "Dire Maul: East", "Feralas"),
    35: (429, "Dire Maul: West", "Feralas"),
    37: (429, "Dire Maul: North", "Feralas"),
    39: (329, "Stratholme", "Eastern Plaguelands"),
    2: (289, "Scholomance", "Western Plaguelands"),
    41: (309, "Zul'Gurub", "Stranglethorn Vale"),
    45: (249, "Onyxia's Lair", "Dustwallow Marsh"),
    47: (409, "Molten Core", "Blackrock Mountain"),
    49: (469, "Blackwing Lair", "Blackrock Mountain"),
}

# Which side of the world an entrance's zone is on; any zone not here is contested.
ZONE_SIDE = {
    "Orgrimmar": "Horde", "The Barrens": "Horde", "Silverpine Forest": "Horde", "Tirisfal Glades": "Horde",
    "Westfall": "Alliance", "Stormwind City": "Alliance", "Dun Morogh": "Alliance", "Wetlands": "Alliance",
}

# Wings that share a map: the encounter IDs in each.
WINGS = {
    31: {267, 268, 269, 270, 271, 272, 274, 273, 275},
    43: {3062, 3063, 3068, 3069, 3070},
    33: {343, 344, 345, 2792, 346},
    35: {350, 347, 348, 349, 361, 2793, 2794},
    37: {362, 363, 364, 365, 366, 367, 368},
}

# Bosses whose encounter is named differently from the boss you see in the game (and on
# Wowhead): Ruins of Lordaeron's "The Butcher" is The Baron, Hall of Thanes's "Infurnus" is
# Magmatus, City of Dalaran's "Mana Elemental" is Arcanic Enigma. The card shows the boss's
# own name; loot is learned under either.
NPC_NAME = {3355: "The Baron", 3495: "Magmatus", 3301: "Arcanic Enigma"}

# Rows that aren't a boss to kill.
NOT_BOSSES = {3018}  # "The Molten Core": the raid's own completion

FOREVER_DIFFICULTIES = {"0", "1"}


def read(name):
    with open(SRC / name, encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


def lua_string(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    tuning = {r["ID"]: int(r["MinLevelSquish"]) for r in read("ContentTuning.csv")}
    maps = {int(r["ID"]): r for r in read("Map.csv")}
    lfg = {int(r["ID"]): r for r in read("LFGDungeons.csv")}
    encounters = {}
    for r in read("DungeonEncounter.csv"):
        if r["DifficultyID"] not in FOREVER_DIFFICULTIES or int(r["ID"]) in NOT_BOSSES:
            continue
        encounters.setdefault(int(r["MapID"]), []).append((int(r["OrderIndex"]), int(r["ID"]), r["Name_lang"]))

    offered = {i for i, r in lfg.items() if r["TypeID"] == "0"}
    missing = offered - set(DUNGEONS)
    if missing:
        raise SystemExit("New dungeons in LFGDungeons, add them to DUNGEONS: "
                         + ", ".join(f"{i} {lfg[i]['Name_lang']}" for i in sorted(missing)))

    rows = []
    for lfg_id, (map_id, name, zone) in DUNGEONS.items():
        r = lfg[lfg_id]
        level = tuning[r["ContentTuningID"]]
        faction = {"0": "Horde", "1": "Alliance"}.get(r["Faction"])
        raid = maps[map_id]["InstanceType"] == "2"
        bosses = sorted(encounters.get(map_id, []))
        if lfg_id in WINGS:
            bosses = [b for b in bosses if b[1] in WINGS[lfg_id]]
            if len(bosses) != len(WINGS[lfg_id]):
                raise SystemExit(f"{name}: a wing's boss is missing from the files")
        if not bosses:
            raise SystemExit(f"{name}: no bosses in the files")
        rows.append((raid, level, name, lfg_id, map_id, zone, faction, bosses))
    rows.sort(key=lambda t: (t[0], t[1], t[2]))

    lines = [
        "-- Forever's dungeons and raids and their bosses in order, from the game's own files",
        f"-- (build {BUILD}). Generated by tools/build_dungeons.py; don't edit by hand.",
        "local _, ns = ...",
        "",
        "-- Each: its name, the level it's tuned to, where its entrance is, the side of the world",
        "-- that is (none: contested), the faction it's for (none: both), whether it's a raid, and",
        "-- its bosses as { encounter ID, name, and the boss's own name when it isn't the same }.",
        "ns.DungeonData = {",
    ]
    for raid, level, name, lfg_id, map_id, zone, faction, bosses in rows:
        boss_text = ", ".join(
            f"{{ {i}, {lua_string(n)}, {lua_string(NPC_NAME[i])} }}" if i in NPC_NAME else f"{{ {i}, {lua_string(n)} }}"
            for _, i, n in bosses)
        side = ZONE_SIDE.get(zone)
        extra = (f", side = {lua_string(side)}" if side else "") + \
            (f", faction = {lua_string(faction)}" if faction else "") + (", raid = true" if raid else "")
        lines.append(f"    {{ id = {lfg_id}, map = {map_id}, name = {lua_string(name)}, level = {level}, "
                     f"zone = {lua_string(zone)}{extra},")
        lines.append(f"      bosses = {{ {boss_text} }} }},")
    lines.append("}")
    OUT.parent.mkdir(exist_ok=True)
    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    print(f"{len(rows)} dungeons and raids, {sum(len(r[7]) for r in rows)} bosses -> {OUT.relative_to(ROOT)}")
    build_loot(rows)


# Which classes each class-only quest is for, by quest ID, from three places
# in one file, which says how each was read: the quests list on each dungeon's
# Wowhead page (its reqclass: "classes"), pfQuest's database ("pfquest"), and,
# for quests neither marks whose only reward is a one-class item, that reward
# ("rewards"). Wowhead's is Forever's own, so it wins where two differ.
# Missing, every quest is anyone's.
_classes = ROOT / "data" / "dungeons" / "quest-classes.json"
_read = json.loads(_classes.read_text(encoding="utf-8")) if _classes.exists() else {}
QUEST_CLASSES = {**_read.get("rewards", {}), **_read.get("pfquest", {}), **_read.get("classes", {})}


def build_starts():
    """Where each dungeon quest starts, and the quest before it in its chain, from
    data/dungeons/quest-starts.json (tools/wowhead/quests.js). The zone's map for the
    map pin comes from the game's UiMapAssignment table (data/maps/, same build). A start
    inside a dungeon or raid gets no map: the game can't pin a spot in one.

    A quest Wowhead names no starter for may start from an item: the game's ItemSparse table
    (data/professions/, StartQuestID) says which, and data/dungeons/quest-items.json
    (tools/wowhead/items.js) who drops it and in which zone, when it's been read."""
    path = SRC / "quest-starts.json"
    if not path.exists():
        print("No data/dungeons/quest-starts.json: no quest starts written")
        return []
    starts = json.loads(path.read_text(encoding="utf-8"))
    ui_map = {}
    with open(ROOT / "data" / "maps" / "UiMapAssignment.csv", newline="", encoding="utf-8") as f:
        for r in csv.DictReader(f):
            area, m = int(r["AreaID"]), int(r["UiMapID"])
            if area and (area not in ui_map or int(r["OrderIndex"]) == 0):
                ui_map[area] = m
    inside = set(WOWHEAD_ZONE.values())
    items = {}
    with open(ROOT / "data" / "professions" / "ItemSparse.csv", newline="", encoding="utf-8") as f:
        for r in csv.DictReader(f):
            if r["StartQuestID"] not in ("0", ""):
                items[r["StartQuestID"]] = (int(r["ID"]), r["Display_lang"])
    drops_path = SRC / "quest-items.json"
    drops = json.loads(drops_path.read_text(encoding="utf-8"))["items"] if drops_path.exists() else {}
    lines, spots, from_items = [], 0, 0
    for qid in sorted(starts["quests"], key=int):
        q = starts["quests"][qid]
        parts = [lua_string(q.get("n") or "")]
        s, z, dropper, found = q.get("s"), q.get("z"), None, False
        if not s and qid in items:
            # Started by an item: its name, and where it drops (the first dropper Wowhead lists).
            item_id, item_name = items[qid]
            s = ["item", item_id, item_name]
            drop = drops.get(str(item_id))
            z = [drop[1], "", 0, 0] if drop and drop[1] else None
            dropper = drop[0] if drop else None
            found = bool(drop and len(drop) > 2 and drop[2] == 2)
            if found and dropper == item_name:
                dropper = None  # the item lies about as itself: just where
            from_items += 1
        if s:
            kind = {"npc": 1, "object": 2, "item": 3}[s[0]]
            parts += [lua_string(s[2]), str(kind)]
        else:
            parts += ["nil", "nil"]
        if z and z[0]:
            area = z[0]
            m = 0 if area in inside or (s and s[0] == "item") else ui_map.get(area, 0)
            # Wowhead's spot is on Classic's map; Forever draws a few zones differently.
            spot_x, spot_y = forever_spot(m, z[2], z[3]) if m else (z[2], z[3])
            parts += [str(area), str(m), f"{spot_x:g}", f"{spot_y:g}"]
            spots += 1 if m and z[2] else 0
        else:
            parts += ["nil", "nil", "nil", "nil"]
        parts.append(str(q["prev"]) if q.get("prev") else "nil")
        parts.append(lua_string(dropper) if dropper else "nil")
        parts.append("true" if found else "nil")
        while parts and parts[-1] == "nil":
            parts.pop()
        lines.append(f"    [{qid}] = {{ {', '.join(parts)} }},")
    print(f"{len(lines)} quest starts ({spots} with a map spot; {from_items} from an item, "
          f"{sum(1 for i in items.values() if str(i[0]) in drops)} drop places known)")
    return [
        "",
        "-- By quest ID: { name, who or what starts it, kind (1 NPC, 2 object, 3 item), the area it's in,",
        "-- the map for a pin (0 inside a dungeon), x, y (0 to 100), the quest before it in its chain,",
        "-- and for an item, who drops it (in that area), and true when that's an object it's found in }.",
        f"-- Read from Wowhead Forever's quest pages on {starts['fetched']}.",
        "ns.DungeonQuestStarts = {",
        *lines,
        "}",
    ]


def build_loot(rows):
    path = SRC / "wowhead.json"
    if not path.exists():
        print("No data/dungeons/wowhead.json: DungeonLoot.lua left as it is")
        return
    wowhead = json.loads(path.read_text(encoding="utf-8"))
    zones = wowhead["zones"]
    # Class quests Wowhead files under the class, not the dungeon, so its zone
    # pages don't list them: each joins the dungeons its own page's map names
    # (data/dungeons/class-quests.json, which says how they were read).
    extra = SRC / "class-quests.json"
    if extra.exists():
        for q in json.loads(extra.read_text(encoding="utf-8"))["quests"].values():
            for zone in q["zones"]:
                listed = zones.get(str(zone), {}).get("quests")
                if listed is not None and not any(row[0] == q["row"][0] for row in listed):
                    listed.append(q["row"])
    loot_lines, quest_lines = [], []
    items = quests = 0
    unmatched, unread = [], []
    for raid, level, name, lfg_id, map_id, zone, faction, bosses in rows:
        z = zones.get(str(WOWHEAD_ZONE[lfg_id]))
        if z is None:
            unread.append(name)
            continue
        for _, encounter, boss in bosses:
            drops = z["loot"].get(boss)
            if drops is None:
                unmatched.append(f"{name}: {boss}")
                continue
            if not drops:
                continue
            drops = sorted(drops, key=lambda d: (-(d[1] or 0), d[0]))
            text = ", ".join(f"{{ {i} }}" if pct is None else f"{{ {i}, {pct} }}" for i, pct in drops)
            loot_lines.append(f"    [{encounter}] = {{ {text} }}, -- {boss}")
            items += len(drops)
        # Quests: not Wowhead's unused placeholders, one of each name per side (some
        # are listed once per starting point), and not ones far above the dungeon
        # that only share its category (the Darkmoon Faire's level 60 fortune card).
        seen, qs = set(), []
        for q in sorted(z["quests"], key=lambda q: (q[2], q[1], q[0])):
            side = q[4] or 3
            # The classes it's for (Wowhead's reqclass: a bit for each of the
            # game's class numbers), 0 for a quest anyone can take.
            # A zone read with tools/wowhead/dungeons.js since 14 Nov 2026
            # carries reqclass as a sixth value of its own.
            classes = QUEST_CLASSES.get(str(q[0]), 0) or (q[5] if len(q) > 5 and q[5] else 0)
            if q[1].startswith("<") or (q[1], side, classes) in seen or q[2] > level + 20:
                continue
            seen.add((q[1], side, classes))
            qs.append([q[0], q[1], q[2], q[3], side, classes])
        if qs:
            text = ",\n".join(
                f"        {{ {q[0]}, {lua_string(q[1])}, {q[2]}, {q[3] or q[2]}, {q[4] or 3}" + (f", {q[5]}" if q[5] else "") + " }"
                for q in qs)
            quest_lines.append(f"    [{lfg_id}] = {{ -- {name}\n{text},\n    }},")
            quests += len(qs)
    lines = [
        "-- Each boss's loot and each dungeon's quests, from Wowhead Forever (read on "
        f"{wowhead['fetched']}).",
        "-- Generated by tools/build_dungeons.py; don't edit by hand.",
        "local _, ns = ...",
        "",
        "-- By encounter ID: { item ID, drop chance in percent (none when Wowhead hasn't counted it) }.",
        "ns.DungeonLoot = {",
        *loot_lines,
        "}",
        "",
        "-- By dungeon: { quest ID, name, level, the level it's offered from, side (1 Alliance, 2 Horde, 3 both) }.",
        "ns.DungeonQuests = {",
        *quest_lines,
        "}",
        *build_starts(),
    ]
    LOOT_OUT.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    print(f"{items} drops and {quests} quests -> {LOOT_OUT.relative_to(ROOT)}")
    if unmatched:
        print("Bosses Wowhead has no page for: " + "; ".join(unmatched))
    if unread:
        print("Not read from Wowhead yet: " + ", ".join(unread))


if __name__ == "__main__":
    main()
