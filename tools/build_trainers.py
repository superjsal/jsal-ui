"""Builds jsalUI/TrainerData.lua: where each class, pet, portal and profession trainer stands.

From Wowhead Forever (data/trainers.txt): each class's and profession's trainers (from its page's
Trainers tab) and each trainer's first spot on the game's own maps (uiMapID and x, y, from its NPC
page). The Trainers tabs also list quest givers and innkeepers, so a trainer only counts for a kind
when the title over its head says so: "Hunter Trainer" for hunters, a tailoring word for tailoring;
one with no title, for a profession players saw it teach (EG Link). The class pages list only the
capitals' trainers, so the class trainers players opened elsewhere are added from EG Link, and
the starting areas' and towns' that nobody opened from each one's own Wowhead NPC page
(data/trainers/wowhead-starters.txt).
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
# (EG Link: data from Efficient Games, https://efficient.games, CC BY 4.0) and from the saved
# visits (data/prices/trainers.json, by tools/bake_prices.py). A weapon master shows a class only
# the weapons it can learn and hasn't, so each sighting is part of the list: they're joined.
EGLINK = ROOT / "data" / "trainers" / "eglink-trainers.json"
VISITS = ROOT / "data" / "prices" / "trainers.json"
# And what Wowhead Forever's NPC pages say a weapon master teaches, where no player was seen buying it.
WOWHEAD_WEAPONS = ROOT / "data" / "trainers" / "wowhead-weapons.txt"
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
    if WOWHEAD_WEAPONS.exists():
        for line in WOWHEAD_WEAPONS.read_text(encoding="utf-8").splitlines():
            if line and not line.startswith("#"):
                _, name, spells = line.split("|")
                if name in masters:
                    masters[name]["teaches"] |= {int(sp) for sp in spells.split(",")} & weapon_ids
    # Where one stands and who it trains, for the ones seen only in the saved visits.
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
# Who a trainer on a map with no side trains (a shared zone, Moonglade, Ashenvale), from Wowhead
# Forever's NPC pages.
SIDES = ROOT / "data" / "trainers" / "wowhead-sides.txt"
# Class trainers in the starting areas and their towns that neither Wowhead's class lists nor
# players' openings have, from each one's own Wowhead Forever page, with the highest level its
# Trainer tab lists as `top`.
STARTERS = ROOT / "data" / "trainers" / "wowhead-starters.txt"
# A trainer's class: the class whose spells are over this share of what it was seen to teach.
CLASS_SHARE = 0.5


def class_spells():
    """Each class's trainer spells from SpellData, by ID: {class: set(spell)}."""
    import re
    out = {}
    parts = re.split(r"\n    \[(\d+)\] = \{", SPELLS.read_text(encoding="utf-8"))
    for i in range(1, len(parts), 2):
        block = re.search(r"\n        spells = \{(.*?)\n        \}", parts[i + 1], re.S)
        if block:
            out[int(parts[i])] = {int(s) for s in re.findall(r"\{ (\d+), \d+,", block.group(1))}
    return out


def wowhead_sides():
    """{npc: (alliance, horde)} from data/trainers/wowhead-sides.txt."""
    out = {}
    if SIDES.exists():
        for line in SIDES.read_text(encoding="utf-8").splitlines():
            if line and not line.startswith("#"):
                npc, _, alliance, horde = line.split("|")
                out[int(npc)] = (friendly(alliance), friendly(horde))
    return out


def class_trainers(listed, portal_npcs):
    """Class trainers players opened (EG Link) that Wowhead's class lists leave out: the starting
    areas' and the towns'. Its class is the one whose SpellData spells are over CLASS_SHARE of what
    it was seen to teach (by ID); its side its map's, or Wowhead's word for a map with no side; and
    `top` the highest level of anything it was seen to teach, as a starting area's trainer teaches
    only the first few levels' spells. A trainer's window lists all it teaches, learned or not, so
    one opening is its whole list. Returns ({"class<n>": [row]}, [left out, with why])."""
    import json
    if not EGLINK.exists():
        return {}, []
    spells, sides = class_spells(), wowhead_sides()
    out, left = {}, []
    for npc, t in json.loads(EGLINK.read_text(encoding="utf-8"))["trainers"].items():
        npc, services = int(npc), t.get("services") or {}
        if npc in listed or npc in portal_npcs or t.get("tradeskill") or not services:
            continue
        ids = {int(s) for s in services}
        best, share = None, 0
        for class_id, own in spells.items():
            if len(ids & own) / len(ids) > share:
                best, share = class_id, len(ids & own) / len(ids)
        if not best:
            continue
        if share <= CLASS_SHARE:
            left.append(f"{t['name']} ({npc}): no class has over half its {len(ids)} spells")
            continue
        spot = (t.get("positions") or [{}])[0]
        if not spot.get("uiMap"):
            left.append(f"{t['name']} ({npc}): no spot")
            continue
        map_id = int(spot["uiMap"])
        a, h = map_id in ALLIANCE_MAPS, map_id in HORDE_MAPS
        if not (a or h) and npc in sides:
            a, h = sides[npc]
        if not (a or h):
            left.append(f"{t['name']} ({npc}): map {map_id} has no side, and Wowhead's word isn't in {SIDES.name}")
            continue
        top = max(int(s.get("level") or 0) for s in services.values())
        out.setdefault(f"class{best}", []).append(
            (npc, t["name"], map_id, round(spot["mapX"], 4), round(spot["mapY"], 4), a, h, top))
    # Wowhead's starting-area and town trainers, after players' own: one players opened stays
    # theirs, and one with no spells on its Trainer tab has no `top` to go by, so it's left out.
    placed = {row[0] for rows in out.values() for row in rows}
    if STARTERS.exists():
        for line in STARTERS.read_text(encoding="utf-8").splitlines():
            if not line or line.startswith("#"):
                continue
            npc, name, _, alliance, horde, kind, map_id, x, y, top = line.split("|")
            npc, map_id = int(npc), int(map_id)
            if npc in listed or npc in placed:
                continue
            if not top:
                left.append(f"{name} ({npc}): its Wowhead page lists nothing it teaches")
                continue
            # An NPC page's map names the uiMap its spot is on, and the spot is that map's as
            # Forever draws it (Lanka Farshot's Mulgore spot is players' own within a fifth of a
            # point), so unlike the class lists' spots it isn't moved.
            out.setdefault("class" + kind[1:], []).append(
                (npc, name, map_id, round(float(x) / 100, 4), round(float(y) / 100, 4),
                 friendly(alliance), friendly(horde), int(top)))
    return out, left


def portal_trainers():
    """A mage's portal trainers players opened (EG Link): the ones whose services are the
    teleports and portals SpellData marks as a portal trainer's, each with its first spot and
    the spells it was seen to teach. Its side is its city's. Sorted by NPC."""
    import json
    import re
    portal = set()
    for inner in re.findall(r"\n        elsewhere = \{ ([^}]*) \}", SPELLS.read_text(encoding="utf-8")):
        portal.update(int(x) for x in re.findall(r"\[(\d+)\] = \"portal\"", inner))
    out = []
    if not EGLINK.exists():
        return out
    for npc, t in json.loads(EGLINK.read_text(encoding="utf-8"))["trainers"].items():
        services = t.get("services") or {}
        teaches = sorted(int(s) for s in services if int(s) in portal)
        spot = (t.get("positions") or [{}])[0]
        if not teaches or len(teaches) < len(services) or not spot.get("uiMap"):
            continue
        map_id = int(spot["uiMap"])
        a, h = map_id in ALLIANCE_MAPS, map_id in HORDE_MAPS
        if a or h:
            out.append((int(npc), t["name"], map_id, round(spot["mapX"], 4), round(spot["mapY"], 4), a, h, teaches))
    return sorted(out)


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
    seen = taught()
    for line, wowhead in sources:
        if not line or line.startswith("#"):
            continue
        npc, name, tag, alliance, horde, kinds, map_id, x, y = line.split("|")
        # One with no title over its head counts for a profession players saw it teach.
        if not tag and not any(k.startswith("s") and int(k[1:]) in seen.get(int(npc), {}) for k in kinds.split(",")):
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
                if not (any(word in tag for word in PROFESSION_WORDS.get(skill, ()))
                        or (not tag and skill in seen.get(int(npc), {}))):
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
        "-- Efficient Games, CC BY 4.0). A class trainer with `top` is one players opened",
        "-- that Wowhead's lists leave out (EG Link), mostly in the starting areas and",
        "-- their towns: `top` is the highest level of anything it was seen to teach.",
        "-- Regenerated by the build, not by hand.",
        "local _, ns = ...",
        "",
        "ns.TrainerData = {",
    ]
    # A profession trainer players opened has `teaches`: the spells it was seen to teach.
    portals = portal_trainers()
    # The class trainers players opened that Wowhead's lists leave out, each with `top`.
    others, left = class_trainers(listed, {p[0] for p in portals})
    for key in set(by_key) | set(others):
        by_key.setdefault(key, [])
    for key in sorted(by_key):
        lines.append(f"    {key} = {{")
        skill = int(key[5:]) if key.startswith("skill") else None
        for npc, name, tag, map_id, x, y, a, h in sorted(by_key[key]):
            spells = seen.get(npc, {}).get(skill) if skill else None
            teaches = f", teaches = {{ {', '.join(str(sp) for sp in sorted(spells))} }}" if spells else ""
            lines.append(f"        {{ npc = {npc}, name = {lua_string(name)}, tag = {lua_string(tag)}, "
                         f"map = {map_id}, x = {x}, y = {y}, a = {str(a).lower()}, h = {str(h).lower()}{teaches} }},")
        for npc, name, map_id, x, y, a, h, top in sorted(others.get(key, [])):
            lines.append(f"        {{ npc = {npc}, name = {lua_string(name)}, map = {map_id}, x = {x}, y = {y}, "
                         f"a = {str(a).lower()}, h = {str(h).lower()}, top = {top} }},")
        lines.append("    },")
    # A mage's portal trainers, each with the teleports and portals it's been seen to teach.
    lines.append("    -- A mage's portal trainers players opened (Efficient Games' data, CC BY 4.0), and the")
    lines.append("    -- teleports and portals each was seen to teach (spell IDs): its own city's.")
    lines.append("    portal = {")
    for npc, name, map_id, x, y, a, h, teaches in portals:
        lines.append(f"        {{ npc = {npc}, name = {lua_string(name)}, tag = \"Portal Trainer\", map = {map_id}, "
                     f"x = {x}, y = {y}, a = {str(a).lower()}, h = {str(h).lower()}, "
                     f"teaches = {{ {', '.join(str(sp) for sp in teaches)} }} }},")
    lines.append("    },")
    # The weapon masters, each with the weapon skills it's been seen to teach.
    masters = weapon_masters(SEEN.read_text(encoding="utf-8").splitlines())
    lines.append("    -- Weapon masters, and the weapon skills each has been seen to teach (spell IDs): from")
    lines.append("    -- Efficient Games' data (CC BY 4.0), visits in the game and Wowhead Forever's NPC pages.")
    lines.append("    -- A weapon master lists only what the class in front of it can still learn, so a list")
    lines.append("    -- here may yet grow.")
    lines.append("    weapons = {")
    for name, m in masters:
        lines.append(f"        {{ npc = {m['npc']}, name = {lua_string(name)}, tag = \"Weapon Master\", map = {m['map']}, "
                     f"x = {m['x']}, y = {m['y']}, a = {str(m['a']).lower()}, h = {str(m['h']).lower()}, "
                     f"teaches = {{ {', '.join(str(s) for s in sorted(m['teaches']))} }} }},")
    lines.append("    },")
    lines += ["}", ""]
    OUT.write_text("\n".join(lines), encoding="utf-8", newline="\n")
    counts = ", ".join(f"{k} {len(v) + len(others.get(k, []))}" for k, v in sorted(by_key.items()))
    counts += f", portal {len(portals)}, weapons {len(masters)}"
    ranks_seen()
    print(f"-> {OUT.relative_to(ROOT)}: {counts}")
    for why in left:
        print(f"  class trainer left out: {why}")


if __name__ == "__main__":
    main()
