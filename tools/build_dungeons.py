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

Run: python -I tools/build_dungeons.py
"""

import csv
import json
import pathlib

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

# Wings that share a map: the encounter IDs in each.
WINGS = {
    31: {267, 268, 269, 270, 271, 272, 274, 273, 275},
    43: {3062, 3063, 3068, 3069, 3070},
    33: {343, 344, 345, 2792, 346},
    35: {350, 347, 348, 349, 361, 2793, 2794},
    37: {362, 363, 364, 365, 366, 367, 368},
}

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
        "-- Each: its name, the level it's tuned to, where its entrance is, the faction it's for",
        "-- (none: both), whether it's a raid, and its bosses as { encounter ID, name }.",
        "ns.DungeonData = {",
    ]
    for raid, level, name, lfg_id, map_id, zone, faction, bosses in rows:
        boss_text = ", ".join(f"{{ {i}, {lua_string(n)} }}" for _, i, n in bosses)
        extra = (f", faction = {lua_string(faction)}" if faction else "") + (", raid = true" if raid else "")
        lines.append(f"    {{ id = {lfg_id}, map = {map_id}, name = {lua_string(name)}, level = {level}, "
                     f"zone = {lua_string(zone)}{extra},")
        lines.append(f"      bosses = {{ {boss_text} }} }},")
    lines.append("}")
    OUT.parent.mkdir(exist_ok=True)
    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    print(f"{len(rows)} dungeons and raids, {sum(len(r[7]) for r in rows)} bosses -> {OUT.relative_to(ROOT)}")
    build_loot(rows)


def build_loot(rows):
    path = SRC / "wowhead.json"
    if not path.exists():
        print("No data/dungeons/wowhead.json: DungeonLoot.lua left as it is")
        return
    wowhead = json.loads(path.read_text(encoding="utf-8"))
    zones = wowhead["zones"]
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
            if q[1].startswith("<") or (q[1], side) in seen or q[2] > level + 20:
                continue
            seen.add((q[1], side))
            qs.append([q[0], q[1], q[2], q[3], side])
        if qs:
            text = ",\n".join(f"        {{ {q[0]}, {lua_string(q[1])}, {q[2]}, {q[3] or q[2]}, {q[4] or 3} }}" for q in qs)
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
    ]
    LOOT_OUT.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    print(f"{items} drops and {quests} quests -> {LOOT_OUT.relative_to(ROOT)}")
    if unmatched:
        print("Bosses Wowhead has no page for: " + "; ".join(unmatched))
    if unread:
        print("Not read from Wowhead yet: " + ", ".join(unread))


if __name__ == "__main__":
    main()
