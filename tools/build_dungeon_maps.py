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

A dungeon of Forever's own has no such picture and no journal entry. Its map is Santiago Reyes's, from Atlas
de Azeroth: Forever (sreyesmaps.com), a picture a floor in jsalUI/Media/Maps (tools/build_map_art.py makes
them). ART below is by hand: each floor's picture and its name, from the names on his maps. Such a map has
no boss placed on it.

A boss's picture, for its tooltip, is the journal's too: JournalEncounterCreature (JournalEncounterID,
CreatureDisplayInfoID, OrderIndex, Name_lang; from the same place) gives each journal boss's models, the
first being the boss. Only the rows whose model Forever's own CreatureDisplayInfo has are kept there: a boss
remodelled since has none. Those, and the bosses the journal doesn't have, take their model from their NPC's
page on Wowhead Forever (its "View in 3D" displayId): FACES below.

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
    429: ("DireMaul", 6), 329: ("Stratholme", 2), 289: ("ScholomanceOLD", 4), 409: ("MoltenCore", 1),
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
# A dungeon of Forever's own, by map ID: each floor's picture in jsalUI/Media/Maps and its name. Blackmaw
# Hold's six are named short, so their tabs fit over the map. A dungeon entered from below has that floor
# first, as the tab it opens on: Dalaran's sewers.
ART = {
    3065: [("hallofthanes", "Hall of Thanes")],
    2999: [("lordaeron", "Ruins of Lordaeron")],
    2998: [("excavation", "Excavation Site")],
    2959: [("dalaran2", "Sewers"), ("dalaran1", "City of Dalaran")],
    2970: [("drowned1", "The Drowned City"), ("drowned2", "Atal'Byzal")],
    3039: [("kroldok", "Krol'dok Stronghold")],
    2994: [("alcaz1", "Main Unit"), ("alcaz2", "Maximum Security Unit")],
    2974: [("blackmaw1", "Blackmaw Grove"), ("blackmaw2", "Festering Grotto"), ("blackmaw3", "Fallen Grove"),
           ("blackmaw4", "Elders"), ("blackmaw5", "Burrow"), ("blackmaw6", "Forbidden Magic")],
    3001: [("shaper1", "The Shaper's Terrace"), ("shaper2", "Prismatic Talus")],
}
# A boss's model where the journal has none for it, by its name: from its NPC's page on Wowhead Forever
# (wowhead.com/forever/npc=<id>, the displayId of "View in 3D"), NPC ID in the comment.
FACES = {
    "Ghamoo-ra": 5027,                   # 4887
    "Charlga Razorflank": 4642,          # 4421
    "Viscous Fallout": 5497,             # 7079
    "Electrocutioner 6000": 6915,        # 6235
    "Crowd Pummeler 9-60": 6774,         # 6229
    "Mekgineer Thermaplugg": 6980,       # 7800
    "Glutton": 7864,                     # 8567
    "Amnennar the Coldbringer": 7971,    # 7358
    "War Master Voone": 9733,            # 9237
    "Lethtendris": 14378,                # 14327
    "Malor the Zealous": 10458,          # 11032
    "Cannon Master Willey": 10674,       # 10997
    "Archivist Galford": 10544,          # 10811
    "Balnazzar": 10691,                  # 10813
    "Baron Rivendare": 10729,            # 10440
    "High Inquisitor Whitemane":          2043,    # 3977
    "Shade of Eranikus":                  7806,    # 5709
    "Hazzas":                             9584,    # 5722
    "Kirtonos":                           143673,  # 10506
    "Razorclaw the Butcher":              524,     # 3886
    "Darkmaster Gandling":                11070,   # 1853
    "Rethilgore":                         524,     # 3914
    "Targorr the Dread":                  517,     # 1696
    "Herod":                              2041,    # 3975
    "Interrogator Vishas":                2044,    # 3983
    "Bloodmage Thalnos":                  11396,   # 4543
    "Odo the Blindwatcher":               522,     # 4279
    "Baron Silverlaine":                  3222,    # 3887
    "Fenrus the Devourer":                2352,    # 4274
    "Lady Illucia Barov":                 11835,   # 10502
    "Rattlegore":                         12073,   # 11622
    "Lorekeeper Polkelt":                 11492,   # 10901
    "Jammal'an the Prophet":              6708,    # 5710
    "Weaver":                             6375,    # 5720
    "Bazil Thredd":                       1621,    # 1716
    "Jandice Barov":                      11073,   # 10503
    "Hamhock":                            3250,    # 1717
    "Instructor Malicia":                 11069,   # 10505
    "High Inquisitor Fairbanks":          2605,    # 4542
    "Ras Frostwhisperer":                 7919,    # 10508
    "Arcanist Doan":                      5266,    # 6487
    "Houndmaster Loksey":                 2040,    # 3974
    "Commander Springvale":               3223,    # 4278
    "Wolf Master Nandos":                 11179,   # 3927
    "Morphaz":                            7975,    # 5719
    "Doctor Theolen Krastinov":           10901,   # 11261
    "Marduk Blackpool":                   10248,   # 10433
    "Dreamscythe":                        7553,    # 5721
    "The Ravenian":                       10433,   # 10507
    "Atal'alarion":                       7873,    # 8580
    "Avatar of Hakkar":                   8053,    # 8443
    "Lord Alexei Barov":                  11072,   # 10504
    "Kam Deepfury":                       825,     # 1666
    "Dextren Ward":                       2149,    # 1663
    "Vectus":                             2606,    # 10432
    "Archmage Arugal":                    2353,    # 4275
}
# The dungeons rebuilt before the journal came, by map ID: each boss's floor and place on the classic pictures,
# by hand. The place is where the boss stands, from AzerothCore's spawns (data/sql/base/db_world/creature.sql,
# world X, Y and Z) inside the floor's bounds in a Wrath-era build's UiMapAssignment (wago.tools, build
# 3.80.2.70522; a picture's across is the bounds' Y from its top, its down the bounds' X); the floor is
# chosen by hand where several pictures take the spot, by the skull and the room's name on the picture and by
# height. A boss called up rather than standing there is placed at its room's skull. Zul'Gurub has no
# picture of the classic city (its pictures are the rebuilt one's), and Kormok no place.
HAND = {
    33: {    # Shadowfang Keep
        "Rethilgore": (1, 0.661, 0.711),
        "Razorclaw the Butcher": (2, 0.480, 0.290),
        "Baron Silverlaine": (2, 0.295, 0.803),
        "Commander Springvale": (1, 0.275, 0.586),
        "Odo the Blindwatcher": (7, 0.551, 0.771),
        "Fenrus the Devourer": (4, 0.574, 0.433),
        "Wolf Master Nandos": (6, 0.590, 0.533),
        "Archmage Arugal": (6, 0.639, 0.200),
    },
    34: {    # The Stockade
        "Targorr the Dread": (1, 0.499, 0.242),
        "Kam Deepfury": (1, 0.692, 0.309),
        "Hamhock": (1, 0.782, 0.457),
        "Dextren Ward": (1, 0.146, 0.214),
        "Bazil Thredd": (1, 0.864, 0.520),
    },
    189: {    # Scarlet Monastery
        "Interrogator Vishas": (1, 0.715, 0.589),
        "Bloodmage Thalnos": (1, 0.244, 0.508),
        "Houndmaster Loksey": (2, 0.308, 0.878),
        "Arcanist Doan": (2, 0.832, 0.745),
        "Herod": (3, 0.786, 0.108),
        "High Inquisitor Fairbanks": (4, 0.554, 0.261),
        "High Inquisitor Whitemane": (4, 0.490, 0.169),
    },
    109: {    # Sunken Temple
        "Atal'alarion": (1, 0.498, 0.486),
        "Shade of Eranikus": (1, 0.688, 0.870),
        "Hazzas": (1, 0.521, 0.890),
        "Morphaz": (1, 0.489, 0.890),
        "Weaver": (1, 0.453, 0.440),
        "Dreamscythe": (1, 0.440, 0.428),
        "Jammal'an the Prophet": (1, 0.761, 0.368),
        "Avatar of Hakkar": (1, 0.240, 0.452),
    },
    289: {    # Scholomance
        "Jandice Barov": (3, 0.543, 0.144),
        "Rattlegore": (3, 0.304, 0.624),
        "Marduk Blackpool": (2, 0.444, 0.639),
        "Vectus": (2, 0.482, 0.662),
        "Ras Frostwhisperer": (4, 0.406, 0.884),
        "Instructor Malicia": (3, 0.728, 0.809),
        "Doctor Theolen Krastinov": (3, 0.956, 0.459),
        "Lorekeeper Polkelt": (3, 0.720, 0.120),
        "The Ravenian": (4, 0.675, 0.521),
        "Lord Alexei Barov": (4, 0.844, 0.308),
        "Lady Illucia Barov": (4, 0.670, 0.061),
        "Darkmaster Gandling": (4, 0.682, 0.302),
        "Kirtonos": (2, 0.492, 0.108),
    },
}
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
        bosses.setdefault(m, []).append({"enc": int(r["DungeonEncounterID"] or 0), "name": r["Name_lang"], "jid": r["ID"],
                                         "ui": int(r["UiMapID"]), "x": x, "y": y, "instance": instance})
    return {m: {"floors": sorted(f), "names": {i: names[str(i)]["Name_lang"] for i in f}, "bosses": bosses.get(m, [])}
            for m, f in floors.items()}


def faces(build):
    """By journal encounter: the model of its first creature, where Forever has it."""
    out = {}
    for r in sorted(rows(build, "JournalEncounterCreature"), key=lambda r: int(r["OrderIndex"]), reverse=True):
        out[r["JournalEncounterID"]] = int(r["CreatureDisplayInfoID"])
    return out


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
    models = {b: faces(b) for b in BUILDS}
    out, report = [], []
    for d in dungeons():
        if d["map"] in ART:
            report.append("%s: its own maps, %d floors" % (d["name"], len(ART[d["map"]])))
            out.append((d, None, ART[d["map"]], {}, {}))
            continue
        if d["map"] not in FOLDERS:
            report.append("%s: no pictures" % d["name"])
            continue
        folder, count = FOLDERS[d["map"]]
        placed, missing, floor_names = {}, [], {}
        if d["map"] in HAND:
            for enc, name, own in d["bosses"]:
                if name in HAND[d["map"]]:
                    floor, x, y = HAND[d["map"]][name]
                    floor_names[floor] = True
                    placed[enc] = (floor, x, y, name, "hand", name, None, FACES.get(name))
                else:
                    missing.append(name)
            report.append("%s: %d of %d placed by hand%s" % (d["name"], len(placed), len(d["bosses"]),
                                                            missing and ("; not: " + ", ".join(missing)) or ""))
            out.append((d, folder, count, placed, floor_names))
            continue
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
            placed[enc] = (floor, b["x"], b["y"], name, build_name, b["name"], b["instance"], models[build_name].get(b["jid"]) or FACES.get(name))
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
-- encounter ID as { floor, across, down, and its model where one is known, for its picture in
-- its tooltip }. A boss not here has no place known. A dungeon with
-- fewer than half its bosses placed is left out.
-- A dungeon of Forever's own has no such picture. Its map is Santiago Reyes's (Atlas de Azeroth:
-- Forever, sreyesmaps.com), shown with his credit: `art`, each floor's picture in Media\\Maps,
-- and `names`, each floor's name. No boss is placed on one.
ns.DungeonMaps = {
""".replace("@", BS)


def write(out):
    lines = [HEAD]
    for d, folder, count, placed, names in out:
        if folder is None:
            lines.append("    [%d] = { floors = { %s }, bosses = {},    -- %s\n" % (
                d["id"], ", ".join("true" for _ in count), d["name"]))
            lines.append("        art = { %s },\n" % ", ".join('"%s"' % a for a, _ in count))
            lines.append("        names = { %s } },\n" % ", ".join('"%s"' % n for _, n in count))
            continue
        floors = max(f for f, *_ in placed.values())
        said = ", ".join("true" if f in names else "false" for f in range(1, floors + 1))
        lines.append('    [%d] = { folder = "%s",%s floors = { %s },\n        bosses = {\n' % (
            d["id"], folder, count == 0 and " plain = true," or "", said))
        for enc, name, _ in d["bosses"]:
            if enc in placed:
                f, x, y = placed[enc][:3]
                face = placed[enc][7]
                lines.append("            [%d] = { %d, %.3f, %.3f%s },    -- %s\n" % (enc, f, x, y, face and (", %d" % face) or "", name))
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
            if folder is None:
                continue
            print(d["name"], folder, count, sorted(names.items()))
            for enc, p in placed.items():
                if plain(p[3]) != plain(p[5]) or p[4] != BUILDS[0]:
                    print("    %s <- %s (%s, %s)" % (p[3], p[5], p[6], p[4]))
    else:
        write(out)
        print("wrote DungeonMaps.lua: %d dungeons" % len(out))
