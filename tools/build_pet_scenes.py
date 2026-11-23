"""Writes the map IDs the pal's pen goes by into jsalUI/Pet/Pet.lua, from the game's own tables, so its country
(and its cold shiver in the snow) is found on any client language, not only where the game names places in English.

The pen's scenes are kept by English zone name in Pet.lua's ZONE_SCENE. For each name there this finds:
- the zone's map ID, by its name in UiMap (data/maps/UiMap.csv: ID, Name_lang, ParentUiMapID and Type, from
  https://wago.tools/db2/UiMap/csv?build=1.60.1.71037, Forever's);
- an instance's map ID, by its name in Map (data/dungeons/Map.csv), where an English client may say "The"
  before it ("The Deadmines" is Map's "Deadmines").
It writes them between the "build_pet_scenes" lines in Pet.lua. A name it can't place is printed, and stays found
by its English name only.

Run: python -I tools/build_pet_scenes.py          (writes Pet.lua)
     python -I tools/build_pet_scenes.py --check  (says whether Pet.lua is what it would write; exits 1 if not)
"""
import csv
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
PET = ROOT / "jsalUI" / "Pet" / "Pet.lua"
START = "-- From here to the line after it: tools/build_pet_scenes.py writes it, from the game's tables.\n"
END = "-- (End of what tools/build_pet_scenes.py writes.)\n"


def scene_names(text):
    """Every zone name in ZONE_SCENE, with its scene."""
    block = text[text.index("for scene, zones in pairs({"):text.index("}) do\n    for _, zone in ipairs(zones)")]
    names = {}
    for scene, body in re.findall(r"(\w+) = \{(.*?)\}", block, re.S):
        for name in re.findall(r'"((?:[^"\\]|\\.)*)"', body):
            names[name] = scene
    return names


def tables():
    zones = {}
    with open(ROOT / "data" / "maps" / "UiMap.csv", encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            if row["Type"] == "3":
                zones.setdefault(row["Name_lang"], set()).add(int(row["ID"]))
    instances = {}
    with open(ROOT / "data" / "dungeons" / "Map.csv", encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            if row["InstanceType"] != "0":
                instances.setdefault(row["MapName_lang"], set()).add(int(row["ID"]))
    return zones, instances


def build(text):
    names = scene_names(text)
    zones, instances = tables()
    maps, inst, unplaced = {}, {}, []
    for name in sorted(names):
        found = False
        for ui in zones.get(name, ()):
            maps[ui] = name
            found = True
        bare = name[4:] if name.startswith("The ") else None
        for map_id in instances.get(name, set()) | instances.get(bare, set()):
            inst[map_id] = name
            found = True
        if not found:
            unplaced.append(name)

    def lua(table):
        rows, line = [], "   "
        for key in sorted(table):
            item = ' [%d] = "%s",' % (key, table[key].replace('"', '\\"'))
            if len(line) + len(item) > 116:
                rows.append(line)
                line = "   "
            line += item
        rows.append(line)
        return "\n".join(rows) + "\n"

    block = (START
             + "-- Each zone's map IDs and each instance's map ID, with the zone's English name above: where you are,\n"
             + "-- found by ID on any client language (Pet.SceneHere).\n"
             + "local SCENE_MAPS = {\n" + lua(maps) + "}\n"
             + "local SCENE_INSTANCES = {\n" + lua(inst) + "}\n"
             + END)
    return block, unplaced


def main():
    raw = PET.read_bytes().decode("utf-8")
    crlf = "\r\n" in raw
    text = raw.replace("\r\n", "\n")
    block, unplaced = build(text)
    if START not in text or END not in text:
        sys.exit("Pet.lua has no build_pet_scenes lines to write between")
    a, b = text.index(START), text.index(END) + len(END)
    new = text[:a] + block + text[b:]
    for name in unplaced:
        print("not in the game's tables, found by its English name only:", name)
    if "--check" in sys.argv:
        same = new == text
        print("Pet.lua's scene map IDs are what the game's tables give" if same else "Pet.lua's scene map IDs are out of date")
        sys.exit(0 if same else 1)
    PET.write_bytes((new.replace("\n", "\r\n") if crlf else new).encode("utf-8"))
    print("wrote", PET.relative_to(ROOT))


if __name__ == "__main__":
    main()
