"""Builds jsalUI/Dungeons/DungeonMaps.lua: for the Dungeon guide's Map tab, which of the game's own map
pictures show each dungeon, floor by floor, and where on them each boss stands.

Forever's files hold the pictures (Interface/WorldMap/<folder>/<folder><floor>_1 to _12) but no table saying
where a boss is. Later versions of the game do, for the same dungeons and the same pictures: the dungeon
journal's JournalEncounter has each boss's place on its floor's picture as parts of its width and height
(Map_0, Map_1), the floor as a UiMapID, and the DungeonEncounterID that Forever's own ENCOUNTER_END reports.
So a boss is matched by that ID, or failing that by name within the same map, first in the build that still
has the classic dungeons as they were (5.5.4, whose table has no encounter IDs: by name), then in the current
one, which has the classic raids. A floor is a dungeon's UiMaps in order of ID. A boss neither build knows (Forever's own, and those of dungeons that
were rebuilt before the journal came) has no place: the Map tab lists it as not on the map yet.

data/dungeons/journal/<build>/: JournalEncounter (ID, Name_lang, Map_0, Map_1, JournalInstanceID,
DungeonEncounterID, UiMapID), JournalInstance (ID, Name_lang, MapID), UiMap (ID, Name_lang, Type) and
UiMapAssignment (UiMapID, MapID), from https://wago.tools/db2/<Table>/csv?build=<build>, those columns kept.

FOLDERS below is by hand: the picture folder for each of the game's maps, found by asking the game's files
for them, and how many floors of pictures it has.

python tools/build_dungeon_maps.py           writes the file
python tools/build_dungeon_maps.py --report  says what matched and what didn't
"""
import csv
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
BUILDS = ["5.5.4.70960", "12.1.5.70961"]
# The game's map ID: the folder its pictures are in, and how many floors of them there are (0: the pieces
# carry no floor number).
FOLDERS = {
    36: ("TheDeadmines", 2), 43: ("WailingCaverns", 1), 33: ("ShadowfangKeep", 7), 48: ("BlackfathomDeeps", 3),
    34: ("TheStockade", 1), 47: ("RazorfenKraul", 1), 90: ("Gnomeregan", 4), 189: ("ScarletMonastery", 4),
    129: ("RazorfenDowns", 1), 70: ("Uldaman", 2), 349: ("Maraudon", 2), 209: ("ZulFarrak", 0),
    109: ("TheTempleOfAtalHakkar", 1), 230: ("BlackrockDepths", 2), 229: ("BlackrockSpire", 7),
    429: ("DireMaul", 6), 329: ("Stratholme", 2), 289: ("Scholomance", 4), 409: ("MoltenCore", 1),
    469: ("BlackwingLair", 4), 249: ("OnyxiasLair", 1), 309: ("ZulGurub", 0),
}
# A boss the journal has no floor for, by map: the floor it's on (Upper Blackrock Spire's last rooms).
NO_FLOOR = {229: 7}
# A boss the journal puts on the wrong floor. Blackrock Spire has seven pictures and six UiMaps: the upper
# spire's first boss is given the sixth, with the lower spire's last, where its place is no room of his; on
# the seventh, with the upper spire's others, it's the room before the Hall of Blackhand.
ON_FLOOR = {(229, "pyroguardemberseer"): 7}
# A boss the journal keeps under another name: Zul'Farrak's Nekrum and Sezz'ziz are one entry there.
SAME = {598: "nekrumsezzziz", 599: "nekrumsezzziz"}
BS = chr(92)


def rows(build, table):
    with open(os.path.join(ROOT, "data", "dungeons", "journal", build, table + ".csv"), encoding="utf-8") as f:
        return list(csv.DictReader(f))


def journal(build):
    """By map ID: its floors (UiMap IDs in order, with names) and its bosses."""
    names = {r["ID"]: r for r in rows(build, "UiMap")}
    # A dungeon's floors are its UiMaps of type 4; one with a single picture and no floor number has
    # one of type 6 instead.
    floors, lone = {}, {}
    for r in rows(build, "UiMapAssignment"):
        u = names.get(r["UiMapID"])
        if u and u["Type"] in ("4", "6"):
            (floors if u["Type"] == "4" else lone).setdefault(int(r["MapID"]), set()).add(int(r["UiMapID"]))
    for m, f in lone.items():
        floors.setdefault(m, f)
    maps = {r["ID"]: (int(r["MapID"]), r["Name_lang"]) for r in rows(build, "JournalInstance")}
    bosses = {}
    for r in rows(build, "JournalEncounter"):
        m, instance = maps.get(r["JournalInstanceID"], (None, None))
        if m is None:
            continue
        x, y = float(r["Map_0"]), float(r["Map_1"])
        if not (0 < x < 1 and 0 < y < 1):
            continue
        bosses.setdefault(m, []).append({"enc": int(r["DungeonEncounterID"] or 0), "name": r["Name_lang"],
                                         "ui": int(r["UiMapID"]), "x": x, "y": y, "instance": instance})
    return {m: {"floors": sorted(f), "names": {i: names[str(i)]["Name_lang"] for i in f}, "bosses": bosses.get(m, [])}
            for m, f in floors.items()}


def dungeons():
    text = open(os.path.join(ROOT, "jsalUI", "Dungeons", "DungeonData.lua"), encoding="utf-8").read()
    out = []
    for m in re.finditer(r'\{ id = (\d+), map = (\d+), name = "([^"]+)"(.*?)bosses = \{(.*?)\} \},?\s*$', text, re.S | re.M):
        bosses = [(int(b[0]), b[1], b[2] or None) for b in re.findall(r'\{ (\d+), "([^"]+)"(?:, "([^"]+)")? \}', m.group(5))]
        out.append({"id": int(m.group(1)), "map": int(m.group(2)), "name": m.group(3), "bosses": bosses})
    return out


def plain(name):
    return re.sub(r"[^a-z]", "", name.lower())


def build():
    books = [(b, journal(b)) for b in BUILDS]
    out, report = [], []
    for d in dungeons():
        if d["map"] not in FOLDERS:
            report.append("%s: no pictures" % d["name"])
            continue
        folder, count = FOLDERS[d["map"]]
        placed, missing, floor_names = {}, [], {}
        for enc, name, own in d["bosses"]:
            found = None
            for build_name, book in books:
                here = book.get(d["map"])
                for b in (here and here["bosses"] or []):
                    if b["enc"] == enc or plain(b["name"]) in (plain(name), plain(own or name), SAME.get(enc)):
                        found = (build_name, here, b)
                        break
                if found:
                    break
            if not found:
                missing.append(name)
                continue
            build_name, here, b = found
            if (d["map"], plain(b["name"])) in ON_FLOOR:
                floor = ON_FLOOR[(d["map"], plain(b["name"]))]
            elif b["ui"] in here["floors"]:
                floor = here["floors"].index(b["ui"]) + 1
            elif d["map"] in NO_FLOOR:
                floor = NO_FLOOR[d["map"]]
            else:
                missing.append("%s (no floor)" % name)
                continue
            if floor > max(count, 1):
                missing.append("%s (floor %d of %d)" % (name, floor, count))
                continue
            floor_names[floor] = True
            placed[enc] = (floor, b["x"], b["y"], name, build_name, b["name"], b["instance"])
        report.append("%s: %d of %d placed%s" % (d["name"], len(placed), len(d["bosses"]),
                                                 missing and ("; not: " + ", ".join(missing)) or ""))
        if len(placed) * 2 >= len(d["bosses"]):
            out.append((d, folder, count, placed, floor_names))
    return out, report


HEAD = """-- Dungeon maps for the Dungeon guide's Map tab: which of the game's own map pictures show a
-- dungeon, floor by floor, and where on them each boss stands.
-- Generated by tools/build_dungeon_maps.py; don't edit by hand.
local _, ns = ...

-- Forever keeps no map for a dungeon and no place for a boss, but its files hold a picture of
-- each floor, in twelve pieces: Interface@WorldMap@<folder>@<folder><floor>_1 to _12, four
-- across, 1002 by 668 in all (`plain`: the pieces carry no floor number, <folder>1 to 12). Where
-- a boss stands on its floor's picture is the dungeon journal's, from later versions of the game
-- that have the same dungeons and pictures, as parts of the picture's width and height.
-- By dungeon: `folder`, each floor of the folder's pictures (true: one of this dungeon's, with
-- a boss on it; false: another wing's, or one with no boss placed), and each boss by the game's
-- encounter ID as { floor, across, down }. A boss not here has no place known. A dungeon with
-- fewer than half its bosses placed is left out.
ns.DungeonMaps = {
""".replace("@", BS)


def write(out):
    lines = [HEAD]
    for d, folder, count, placed, names in out:
        floors = max(f for f, *_ in placed.values())
        said = ", ".join("true" if f in names else "false" for f in range(1, floors + 1))
        lines.append('    [%d] = { folder = "%s",%s floors = { %s },\n        bosses = {\n' % (
            d["id"], folder, count == 0 and " plain = true," or "", said))
        for enc, name, _ in d["bosses"]:
            if enc in placed:
                f, x, y = placed[enc][:3]
                lines.append("            [%d] = { %d, %.3f, %.3f },    -- %s\n" % (enc, f, x, y, name))
        lines.append("        } },\n")
    lines.append("}\n")
    path = os.path.join(ROOT, "jsalUI", "Dungeons", "DungeonMaps.lua")
    with open(path, "w", encoding="utf-8", newline="\r\n") as f:
        f.write("".join(lines))


if __name__ == "__main__":
    out, report = build()
    if "--report" in sys.argv:
        print("\n".join(report))
        for d, folder, count, placed, names in out:
            print(d["name"], folder, count, sorted(names.items()))
            for enc, p in placed.items():
                if plain(p[3]) != plain(p[5]) or p[4] != BUILDS[0]:
                    print("    %s <- %s (%s, %s)" % (p[3], p[5], p[6], p[4]))
    else:
        write(out)
        print("wrote DungeonMaps.lua: %d dungeons" % len(out))
