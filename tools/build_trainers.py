"""Builds jsalUI/TrainerData.lua: where each class, pet and profession trainer stands.

From Wowhead Forever (data/trainers.txt): each class's and profession's trainers (from its page's
Trainers tab) and each trainer's first spot on the game's own maps (uiMapID and x, y, from its NPC
page). The Trainers tabs also list quest givers and innkeepers, so a trainer only counts for a kind
when the title over its head says so: "Hunter Trainer" for hunters, a tailoring word for tailoring.
Wowhead's spots are on Classic's maps; tools/maps.py puts them on Forever's, which draws Stormwind
and three other zones differently.

Run: python -I tools/build_trainers.py
"""

import json
import pathlib
import sys

# python -I leaves this folder off the path, so it's put there for maps.py.
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from maps import forever_spot  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "data" / "trainers.txt"
# Trainers Wowhead's lists left out, seen in the game: their spots are Forever's already.
SEEN = ROOT / "data" / "trainers-seen.txt"
# Weapon masters: who teaches which weapon skill. From every trainer players opened on Forever
# (EG Link: data from Efficient Games, https://efficient.games, CC BY 4.0) and from John's own
# visits (data/prices/trainers.json, by tools/bake_prices.py). A weapon master shows a class only
# the weapons it can learn and hasn't, so each sighting is part of the list: they're joined.
EGLINK = ROOT / "data" / "trainers" / "eglink-trainers.json"
VISITS = ROOT / "data" / "prices" / "trainers.json"
SPELLS = ROOT / "jsalUI" / "Training" / "SpellData.lua"
# Whose a city is, for a weapon master with no word of who it trains: its map.
ALLIANCE_MAPS = {1453, 1455, 1457, 1429, 1426, 1438, 1439, 1432, 1436, 1433}
HORDE_MAPS = {1454, 1456, 1458, 1411, 1412, 1420, 1421, 1413}


def ranks_seen():
    """Writes data/trainers/ranks-seen.txt: for each profession trainer in Efficient Games' data,
    the highest profession rank it was seen to sell (1 Apprentice to 4 Artisan). A trainer shows a
    player only the rank that player can learn next, so this is the least it teaches, not the
    most. The tests hold jsal.ui's reading of trainers' titles against it."""
    import json
    order = ["Apprentice", "Journeyman", "Expert", "Artisan"]
    out = ["# npc|name|highest profession rank seen for sale (1 Apprentice to 4 Artisan)|its name",
           "# From data/trainers/eglink-trainers.json (Efficient Games, CC BY 4.0), by tools/build_trainers.py."]
    if EGLINK.exists():
        rows = []
        for npc, t in json.loads(EGLINK.read_text(encoding="utf-8"))["trainers"].items():
            best = None
            for s in (t.get("services") or {}).values():
                first = (s.get("name") or "").split(" ", 1)
                if (s.get("step") or s.get("profession")) and first[0] in order and len(first) == 2:
                    rank = order.index(first[0]) + 1
                    if not best or rank > best[0]:
                        best = (rank, s["name"])
            if best:
                rows.append((int(npc), t["name"], best[0], best[1]))
        out += [f"{npc}|{name}|{rank}|{what}" for npc, name, rank, what in sorted(rows)]
    (ROOT / "data" / "trainers" / "ranks-seen.txt").write_text("\n".join(out) + "\n", encoding="utf-8", newline="\n")


def weapon_masters(seen_lines):
    import json
    import re
    weapon_ids = set()
    for inner in re.findall(r"\n        weapons = \{ ([^}]*) \}", SPELLS.read_text(encoding="utf-8")):
        weapon_ids.update(int(x) for x in re.findall(r"\d+", inner))
    masters = {}   # name -> { npc, map, x, y, a, h, teaches }

    def master(name):
        return masters.setdefault(name, {"npc": 0, "map": 0, "x": 0, "y": 0, "a": False, "h": False, "teaches": set()})

    if EGLINK.exists():
        for npc, t in json.loads(EGLINK.read_text(encoding="utf-8"))["trainers"].items():
            teaches = {int(s) for s in (t.get("services") or {}) if int(s) in weapon_ids}
            # A weapon master teaches weapons and nothing else; a class trainer isn't one.
            if not teaches or len(teaches) * 2 <= len(t.get("services") or {}):
                continue
            m = master(t["name"])
            m["teaches"] |= teaches
            m["npc"] = int(npc)
            spot = (t.get("positions") or [{}])[0]
            if spot.get("uiMap"):
                m["map"], m["x"], m["y"] = int(spot["uiMap"]), round(spot["mapX"], 4), round(spot["mapY"], 4)
    if VISITS.exists():
        for t in json.loads(VISITS.read_text(encoding="utf-8"))["trainers"]:
            rows = [r for r in t["rows"] if r.get("spell")]
            teaches = {r["spell"] for r in rows if r["spell"] in weapon_ids}
            # A weapon master's rows are weapon skills; a class trainer's mostly aren't.
            if teaches and len(teaches) * 2 > len(rows):
                master(t["npc"])["teaches"] |= teaches
    # Where one stands and who it trains, for the ones seen only in his visits.
    for line in seen_lines:
        if not line or line.startswith("#"):
            continue
        npc, name, tag, alliance, horde, kinds, map_id, x, y = line.split("|")
        if "w" in kinds.split(",") and name in masters:
            m = masters[name]
            m["npc"] = m["npc"] or int(npc)
            if not m["map"]:
                m["map"], m["x"], m["y"] = int(map_id), round(float(x) / 100, 4), round(float(y) / 100, 4)
            m["a"], m["h"] = m["a"] or friendly(alliance), m["h"] or friendly(horde)
    out = []
    for name, m in sorted(masters.items()):
        if not m["map"]:
            continue
        m["a"] = m["a"] or m["map"] in ALLIANCE_MAPS
        m["h"] = m["h"] or m["map"] in HORDE_MAPS
        if m["a"] or m["h"]:
            out.append((name, m))
    return out
OUT = ROOT / "jsalUI" / "TrainerData.lua"

# The words a profession trainer's title has.
PROFESSION_WORDS = {
    171: ("Alchem",), 164: ("Blacksmith", "Armor Crafter", "Weaponsmith"), 333: ("Enchant",),
    202: ("Engineer",), 165: ("Leather",), 197: ("Tailor",), 186: ("Mining", "Miner"),
    185: ("Cook", "Butcher"), 129: ("First Aid", "Physician", "Medic"),
}


# A profession's name as EG Link gives a trainer's services.
PROFESSION_NAMES = {
    171: "Alchemy", 164: "Blacksmithing", 333: "Enchanting", 202: "Engineering", 165: "Leatherworking",
    197: "Tailoring", 186: "Mining", 185: "Cooking", 129: "First Aid",
}


def taught():
    """What players were seen to be taught by each profession trainer they opened, by trainer and
    skill line: {npc: {skill: set(spell)}}. A trainer's window lists what it teaches, and what one
    player had already learned is filled in by the others."""
    if not EGLINK.exists():
        return {}
    by_name = {name: skill for skill, name in PROFESSION_NAMES.items()}
    out = {}
    for npc, t in json.loads(EGLINK.read_text(encoding="utf-8"))["trainers"].items():
        for spell, service in (t.get("services") or {}).items():
            skill = by_name.get(service.get("skill"))
            if skill:
                out.setdefault(int(npc), {}).setdefault(skill, set()).add(int(spell))
    return out


def lua_string(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def friendly(value):
    # Wowhead's reaction: 1 friendly, 0 neutral (both factions), -1 hostile, blank none.
    return value != "" and int(value) >= 0


def main():
    by_key = {}
    sources = [(line, True) for line in SRC.read_text(encoding="utf-8").splitlines()]
    sources += [(line, False) for line in SEEN.read_text(encoding="utf-8").splitlines()]
    listed = set()
    for line, wowhead in sources:
        if not line or line.startswith("#"):
            continue
        npc, name, tag, alliance, horde, kinds, map_id, x, y = line.split("|")
        if not tag:
            continue
        a, h = friendly(alliance), friendly(horde)
        if not (a or h):
            continue
        # One seen in the game that Wowhead lists too stays Wowhead's.
        if not wowhead and int(npc) in listed:
            continue
        listed.add(int(npc))
        for kind in kinds.split(","):
            if kind == "w":
                continue    # a weapon master: weapon_masters() places it
            if kind.startswith("c"):
                if tag == "Pet Trainer":
                    key = "pet"
                elif tag.endswith(" Trainer"):
                    key = "class" + kind[1:]
                else:
                    continue
            else:
                skill = int(kind[1:])
                if not any(word in tag for word in PROFESSION_WORDS.get(skill, ())):
                    continue
                key = "skill" + str(skill)
            spot_x, spot_y = forever_spot(int(map_id), float(x), float(y)) if wowhead else (float(x), float(y))
            by_key.setdefault(key, []).append(
                (int(npc), name, tag, int(map_id), round(spot_x / 100, 4), round(spot_y / 100, 4), a, h))
    lines = [
        "-- Where each class, pet and profession trainer stands, from Wowhead Forever",
        "-- and, for the pet trainers its lists left out, from visits in the game:",
        "-- the game's map ID, the spot on it, and which factions they'll train; for a",
        "-- profession trainer players opened, the spells it was seen to teach (EG Link,",
        "-- Efficient Games, CC BY 4.0).",
        "-- Regenerated by the build, not by hand.",
        "local _, ns = ...",
        "",
        "ns.TrainerData = {",
    ]
    # A profession trainer players opened has `teaches`: the spells it was seen to teach.
    seen = taught()
    for key in sorted(by_key):
        lines.append(f"    {key} = {{")
        skill = int(key[5:]) if key.startswith("skill") else None
        for npc, name, tag, map_id, x, y, a, h in sorted(by_key[key]):
            spells = seen.get(npc, {}).get(skill) if skill else None
            teaches = f", teaches = {{ {', '.join(str(sp) for sp in sorted(spells))} }}" if spells else ""
            lines.append(f"        {{ npc = {npc}, name = {lua_string(name)}, tag = {lua_string(tag)}, "
                         f"map = {map_id}, x = {x}, y = {y}, a = {str(a).lower()}, h = {str(h).lower()}{teaches} }},")
        lines.append("    },")
    # The weapon masters, each with the weapon skills it's been seen to teach.
    masters = weapon_masters(SEEN.read_text(encoding="utf-8").splitlines())
    lines.append("    -- Weapon masters, and the weapon skills each has been seen to teach (spell IDs): from")
    lines.append("    -- Efficient Games' data (CC BY 4.0) and visits in the game. A weapon master lists only")
    lines.append("    -- what the class in front of it can still learn, so a list here may yet grow.")
    lines.append("    weapons = {")
    for name, m in masters:
        lines.append(f"        {{ npc = {m['npc']}, name = {lua_string(name)}, tag = \"Weapon Master\", map = {m['map']}, "
                     f"x = {m['x']}, y = {m['y']}, a = {str(m['a']).lower()}, h = {str(m['h']).lower()}, "
                     f"teaches = {{ {', '.join(str(s) for s in sorted(m['teaches']))} }} }},")
    lines.append("    },")
    lines += ["}", ""]
    OUT.write_text("\n".join(lines), encoding="utf-8", newline="\n")
    counts = ", ".join(f"{k} {len(v)}" for k, v in sorted(by_key.items())) + f", weapons {len(masters)}"
    ranks_seen()
    print(f"-> {OUT.relative_to(ROOT)}: {counts}")


if __name__ == "__main__":
    main()
