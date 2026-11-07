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

Run: python -I tools/build_dungeons.py
"""

import csv
import pathlib

BUILD = "1.60.1.70790"
ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "data" / "dungeons"
OUT = ROOT / "jsalUI" / "Dungeons" / "DungeonData.lua"

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


if __name__ == "__main__":
    main()
