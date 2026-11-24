"""Builds jsalUI/Professions/FishingData.lua: Fishing on the Professions page. Three small tables:

- zones: each water's skill where no fish get away, and the skill it can be fished from at all, by the
  game's map ID (uiMap). These are the ORIGINAL GAME'S numbers, not yet Forever's: no table in Forever's
  client and no game function gives a zone's fishing skill (it's the server's), so the page says so. The
  numbers are from the public record of players' testing, El's Extreme Anglin', "Zone Base Fishing Skill"
  (old.elsanglinreborn.com/zone_base_fishing_skill.html, archived 2019-04-29 at
  web.archive.org/web/20190429214235/..., kept at oatcookies.neocities.org/archives/zone-base-fishing-skill;
  read 2026-11-23). Each zone below says which of its tables it's from. Forever's own zones (Zephras Isle
  2521, Riverglades 2548, Mount Hyjal 2482, Shen'dralas 2652) have no number anywhere and are left out
  until they're measured.
- catches: what players caught in each zone in Forever, from EG Link output: World of Warcraft: Forever
  (https://github.com/JIVESCORP/eg-link-output-wowf, data from Efficient Games, https://efficient.games,
  CC BY 4.0): every live build's loot.json, its `fishing:<uiMap>` sources, summed. Kept: how many catches,
  the spot players fished from most, and the four most caught things that aren't junk or a trunk (the
  game's item class 15, Miscellaneous), each with its share of every catch there.
- gear: poles, lures and what's worn for fishing, with each one's bonus, what it needs and where it comes
  from. Each row below says where its numbers are from.

Run: python -I tools/build_fishing.py [--fetch]
--fetch first reads EG Link's loot.json files and its newest quests.enUS.json at the revision
data/trainers/eglink-trainers.json was built from, and keeps what's needed in data/fishing/eglink-fishing.json.
"""

import csv
import json
import pathlib
import sys
import tempfile
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "jsalUI" / "Professions" / "FishingData.lua"
KEPT = ROOT / "data" / "fishing" / "eglink-fishing.json"
TRAINERS = ROOT / "data" / "trainers" / "eglink-trainers.json"
VENDORS = ROOT / "data" / "vendors" / "eglink-vendors.json"
ITEMS = ROOT / "data" / "professions" / "Item.csv"
SPARSE = ROOT / "data" / "professions" / "ItemSparse.csv"
REPO = "JIVESCORP/eg-link-output-wowf"
FISHING = 356
JUNK = "15"     # the game's item class Miscellaneous: trunks, chests, junk
TOP = 4         # most caught things kept for each zone

# The source's tables: "tested" is its "Zone Fishing Skills - Results" table (a zone fished at a skill five
# points at a time, by the author); "summary" its "Theoretical Zone Fishing Skill Summary" and "Zone Fishing
# Skill" tables (zones placed with the tested ones by what's caught there). Where fish get away is the base
# plus 95, as the source says. A base below 1 is written 0: the source gives "<1 (-70?)" and "<1 (-20?)",
# guesses it can't confirm. Instances, the Burning Crusade's zones and the source's parts of a zone (Jaguero
# Isle, Jademir Lake, Azshara's Bay of Storms) are left out: the page picks zones by map.
#   uiMap: (name, base, no get-aways, side, table)
# `side` is a town whose guards are the other side's: a capital or a starting zone, "a" Alliance's and "h"
# the Horde's; everywhere else either side may fish.
ZONES = {
    1426: ("Dun Morogh", 0, 25, "a", "tested"),
    1411: ("Durotar", 0, 25, "h", "summary"),
    1429: ("Elwynn Forest", 0, 25, "a", "tested"),
    1412: ("Mulgore", 0, 25, "h", "summary"),
    1438: ("Teldrassil", 0, 25, "a", "tested"),
    1420: ("Tirisfal Glades", 0, 25, "h", "summary"),
    1413: ("The Barrens", 0, 75, None, "tested"),
    1439: ("Darkshore", 0, 75, None, "tested"),
    1457: ("Darnassus", 0, 75, "a", "tested"),
    1455: ("Ironforge", 0, 75, "a", "summary"),     # the source: "Ironforge was added by patch 2.3"
    1432: ("Loch Modan", 0, 75, None, "tested"),
    1454: ("Orgrimmar", 0, 75, "h", "summary"),
    1421: ("Silverpine Forest", 0, 75, None, "summary"),
    1453: ("Stormwind City", 0, 75, "a", "tested"),
    1456: ("Thunder Bluff", 0, 75, "h", "summary"),
    1458: ("Undercity", 0, 75, "h", "summary"),
    1436: ("Westfall", 0, 75, None, "tested"),
    1440: ("Ashenvale", 55, 150, None, "tested"),
    1431: ("Duskwood", 55, 150, None, "tested"),
    1424: ("Hillsbrad Foothills", 55, 150, None, "tested"),
    1433: ("Redridge Mountains", 55, 150, None, "tested"),
    1442: ("Stonetalon Mountains", 55, 150, None, "tested"),
    1437: ("Wetlands", 55, 150, None, "tested"),
    1416: ("Alterac Mountains", 130, 225, None, "summary"),
    1417: ("Arathi Highlands", 130, 225, None, "tested"),
    1443: ("Desolace", 130, 225, None, "tested"),
    1445: ("Dustwallow Marsh", 130, 225, None, "tested"),
    1434: ("Stranglethorn Vale", 130, 225, None, "tested"),
    1435: ("Swamp of Sorrows", 130, 225, None, "summary"),
    1441: ("Thousand Needles", 130, 225, None, "summary"),
    1447: ("Azshara", 205, 300, None, "summary"),
    1448: ("Felwood", 205, 300, None, "summary"),
    1444: ("Feralas", 205, 300, None, "tested"),
    1425: ("The Hinterlands", 205, 300, None, "tested"),
    1450: ("Moonglade", 205, 300, None, "summary"),
    1446: ("Tanaris", 205, 300, None, "tested"),
    1449: ("Un'Goro Crater", 205, 300, None, "summary"),
    1422: ("Western Plaguelands", 205, 300, None, "tested"),
    1428: ("Burning Steppes", 330, 425, None, "summary"),
    1430: ("Deadwind Pass", 330, 425, None, "tested"),
    1423: ("Eastern Plaguelands", 330, 425, None, "tested"),
    1451: ("Silithus", 330, 425, None, "summary"),
    1452: ("Winterspring", 330, 425, None, "tested"),
}

# What helps. The bonus of each: a lure's from Forever's own tables, build 1.60.1.71037 (wago.tools: the
# item's ItemEffect spell, its SpellItemEnchantment, whose spell gives Fishing by that much; the minutes are
# the enchantment's Duration); a pole's and a worn thing's from its tooltip on Wowhead Forever
# (nether.wowhead.com/forever/tooltip/item/<id>, "Equip: Increased Fishing + N", read 2026-11-23), as
# Forever's tables give a pole's bonus as a scaled stat, not a number. The skill and level each needs are
# read from Forever's ItemSparse (data/professions/ItemSparse.csv) where it has the item, else from the
# same tooltip. Where each comes from:
#   vendor: who sells it and for how much, from EG Link's vendors (data/vendors/eglink-vendors.json);
#   quest: its title and the level it's offered from, from EG Link's quests.enUS.json (kept in
#          data/fishing/eglink-fishing.json); who gives it, and so which side, as said on each row;
#   drop, object, made: Wowhead Forever's item page (its "Dropped by", "Contained in", "Created by" tabs),
#          read 2026-11-23 for fishing-research.md.
# A thing whose source isn't known (the Worn Fishing Hat, the Wide-Brimmed Fishing Hat, Camper's Lure, the
# Arcanite Fishing Pole's prize pick, the Master Angler's Fishing Hat) isn't listed: the page names nothing it
# can't say where to get.
GEAR = [
    # item, kind, bonus, minutes (a lure), how, details
    (6256, "pole", 0, None, "vendor", {}),
    # Gubber Blump in Auberdine; the quest's reward reputation is Ironforge's (EG Link), so the Alliance's.
    (12225, "pole", 3, None, "quest", {"quest": 1141, "side": "a"}),
    # Two sellers, one at a time: Katoom the Angler (Revantusk Village, the Hinterlands) and Martine
    # Tramblay (Brill, Tirisfal Glades), both the Horde's (Wowhead Forever's React lines).
    (6365, "pole", 5, None, "vendor", {"side": "h"}),
    # Not yet in Forever's 1.60.1.71037 tables: its skill and level are from its Wowhead Forever tooltip.
    (285094, "pole", 15, None, "drop", {"npc": "Lord Angler", "skill": 50, "level": 20}),
    (6367, "pole", 20, None, "object", {"object": "Shellfish Trap", "map": 1443}),
    # Katoom the Angler gives it, in Revantusk Village: Horde (Wowhead Forever's React, as on his trainer row).
    (19022, "pole", 25, None, "quest", {"quest": 7815, "side": "h"}),
    (6529, "lure", 25, 10, "vendor", {}),
    (6530, "lure", 50, 10, "vendor", {}),
    (6811, "lure", 50, 10, "made", {"profession": 202}),
    (6532, "lure", 75, 10, "vendor", {}),
    (7307, "lure", 75, 10, "drop", {"npc": "Rotted One"}),
    (6533, "lure", 100, 5, "vendor", {}),
    # The Stranglethorn Fishing Extravaganza's rare fish, handed in at Booty Bay, for both sides (Wowhead
    # Forever). The titles here are its own, used only if EG Link's quests ever lack them.
    (19972, "wear", 5, None, "quest", {"quest": 8221, "title": "Rare Fish - Keefer's Angelfish"}),
    (19969, "wear", 5, None, "quest", {"quest": 8225, "title": "Rare Fish - Brownell's Blue Striped Racer"}),
]


def get(url):
    request = urllib.request.Request(url, headers={"User-Agent": "jsal-ui-data-refresh"})
    with urllib.request.urlopen(request, timeout=120) as response:
        return response.read()


def fetch():
    """Every live build's catches by zone, and the fishing quests' titles and levels, from EG Link at the
    revision the trainers file was built from, into data/fishing/eglink-fishing.json."""
    revision = json.loads(TRAINERS.read_text(encoding="utf-8"))["revision"]
    tree = json.loads(get(f"https://api.github.com/repos/{REPO}/git/trees/{revision}?recursive=1"))["tree"]
    builds = sorted({e["path"].split("/")[2] for e in tree
                     if e["type"] == "blob" and e["path"].startswith("data/wowf/") and e["path"].endswith("/loot.json")},
                    key=lambda b: [int(x) for x in b.split(".")])
    catches, spots = {}, {}
    quests = {}
    wanted = {str(d["quest"]) for *_, d in GEAR if d.get("quest")}
    with tempfile.TemporaryDirectory() as scratch:
        for build in builds:
            path = pathlib.Path(scratch, build + ".json")
            path.write_bytes(get(f"https://raw.githubusercontent.com/{REPO}/{revision}/data/wowf/{build}/loot.json"))
            data = json.loads(path.read_text(encoding="utf-8"))
            for key, source in data.get("sources", {}).items():
                if not key.startswith("fishing:"):
                    continue
                zone = key.split("|")[0][len("fishing:"):]
                got = catches.setdefault(zone, {})
                for item, it in (source.get("items") or {}).items():
                    got[item] = got.get(item, 0) + (it.get("drops") or 0)
                for p in source.get("positions") or []:
                    if str(p.get("uiMap")) == zone:
                        cell = f"{round(p['mapX'], 3)},{round(p['mapY'], 3)}"
                        spots.setdefault(zone, {})[cell] = spots.get(zone, {}).get(cell, 0) + 1
        # The quests: the newest build that has each.
        for build in reversed(builds):
            if not (wanted - set(quests)):
                break
            if not any(e["path"] == f"data/wowf/{build}/quests.enUS.json" for e in tree):
                continue
            data = json.loads(get(f"https://raw.githubusercontent.com/{REPO}/{revision}/data/wowf/{build}/quests.enUS.json"))
            for q in wanted - set(quests):
                found = data.get("quests", {}).get(q)
                if found:
                    quests[q] = {"title": found.get("title"), "minLevel": found.get("minLevel")}
    KEPT.parent.mkdir(parents=True, exist_ok=True)
    KEPT.write_text(json.dumps({
        "about": "What players caught while fishing in WoW Forever, by zone (the game's uiMap), and the fishing "
                 "quests' titles and levels: from EG Link output: World of Warcraft: Forever "
                 "(https://github.com/JIVESCORP/eg-link-output-wowf), data from Efficient Games "
                 "(https://efficient.games), licensed under CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/); "
                 "every live build's loot.json summed, reduced by tools/build_fishing.py.",
        "revision": revision, "builds": builds, "catches": catches, "spots": spots, "quests": quests},
        indent=0, sort_keys=True), encoding="utf-8")
    print(f"kept {sum(sum(c.values()) for c in catches.values())} catches in {len(catches)} zones, "
          f"{len(quests)} quests, from {len(builds)} builds, in {KEPT.relative_to(ROOT)}")


def rows(path):
    with open(path, newline="", encoding="utf-8") as f:
        return {int(r["ID"]): r for r in csv.DictReader(f)}


def best_spot(cells):
    """The spot players fished from most: of every spot, the one with the most others within a
    hundredth of the map, and the middle of those."""
    points = [(tuple(float(v) for v in cell.split(",")), n) for cell, n in cells.items()]
    best, best_count = None, -1
    for (x, y), _ in points:
        near = [((px, py), n) for (px, py), n in points if abs(px - x) <= 0.01 and abs(py - y) <= 0.01]
        count = sum(n for _, n in near)
        if count > best_count:
            total = sum(n for _, n in near)
            best = (sum(px * n for (px, _), n in near) / total, sum(py * n for (_, py), n in near) / total)
            best_count = count
    return best


def lua_string(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    if "--fetch" in sys.argv:
        fetch()
    kept = json.loads(KEPT.read_text(encoding="utf-8"))
    items, sparse = rows(ITEMS), rows(SPARSE)
    vendors = json.loads(VENDORS.read_text(encoding="utf-8"))["vendors"]
    lines = [
        "-- Fishing on the Professions page, built by tools/build_fishing.py: not by hand.",
        "-- zones: [uiMap] = { skill where no fish get away, skill it can be fished from, side whose town it is }.",
        "--   The ORIGINAL GAME'S numbers, not yet Forever's (no table or function in Forever gives them),",
        "--   from players' testing kept as El's Extreme Anglin', \"Zone Base Fishing Skill\". Forever's own",
        "--   zones aren't here until they're measured.",
        "-- catches: [uiMap] = { catches seen, x, y of the spot fished from most, then each of the most caught",
        "--   things that aren't junk, item and percent of every catch }. What players caught in Forever: EG Link",
        "--   output (Efficient Games, https://efficient.games, CC BY 4.0), revision " + kept["revision"][:7] + ".",
        "-- gear: poles, lures and what's worn, with each one's bonus, what it needs and where it comes from.",
        "local _, ns = ...",
        "",
        "ns.FishingData = {",
        "    zones = {",
    ]
    for zone, (name, base, clear, side, _) in sorted(ZONES.items()):
        side_text = f", {lua_string(side)}" if side else ""
        lines.append(f"        [{zone}] = {{ {clear}, {base}{side_text} }},   -- {name}")
    lines += ["    },", "    catches = {"]
    seen_zones = 0
    for zone, got in sorted(kept["catches"].items(), key=lambda kv: int(kv[0])):
        total = sum(got.values())
        if total == 0:
            continue
        seen_zones += 1
        top = sorted(((n, int(item)) for item, n in got.items()
                      if items.get(int(item), {}).get("ClassID") != JUNK), key=lambda r: (-r[0], r[1]))[:TOP]
        spot = best_spot(kept["spots"].get(zone, {}))
        parts = [str(total), f"{spot[0]:.3f}" if spot else "0", f"{spot[1]:.3f}" if spot else "0"]
        for n, item in top:
            parts += [str(item), str(max(1, round(100 * n / total)))]
        lines.append(f"        [{zone}] = {{ {', '.join(parts)} }},")
    lines += ["    },", "    gear = {"]
    for item, kind, bonus, minutes, how, details in GEAR:
        row = sparse.get(item, {})
        skill = int(row["RequiredSkillRank"]) if row.get("RequiredSkill") == str(FISHING) else details.get("skill", 0)
        level = int(row["RequiredLevel"]) if row else details.get("level", 0)
        fields = [f"item = {item}", f"kind = {lua_string(kind)}", f"bonus = {bonus}"]
        if skill:
            fields.append(f"skill = {skill}")
        if level:
            fields.append(f"level = {level}")
        if minutes:
            fields.append(f"minutes = {minutes}")
        fields.append(f"how = {lua_string(how)}")
        if how == "vendor":
            # Its full price (at the lowest standing seen), the most anyone asks; how many sell it, and
            # whether only a few are held at a time.
            sellers = [(npc, v) for npc, v in vendors.items() if str(item) in (v.get("sells") or {})]
            if not sellers:
                raise SystemExit(f"no vendor seen selling {item}")
            prices = [s["sells"][str(item)]["costs"][min(s["sells"][str(item)]["costs"], key=int)] for _, s in sellers]
            limited = all(s["sells"][str(item)].get("limited") for _, s in sellers)
            fields.append(f"copper = {max(prices)}")
            fields.append(f"sellers = {len(sellers)}")
            if len(sellers) <= 2:
                fields.append(f"seller = {lua_string(sorted(s['name'] for _, s in sellers)[0])}")
            if limited:
                fields.append("limited = true")
        elif how == "quest":
            quest = kept["quests"].get(str(details["quest"]), {})
            title = quest.get("title") or details.get("title")
            fields.append(f"quest = {details['quest']}")
            fields.append(f"title = {lua_string(title)}")
            if quest.get("minLevel"):
                fields.append(f"from = {quest['minLevel']}")
        elif how == "drop":
            fields.append(f"npc = {lua_string(details['npc'])}")
        elif how == "object":
            fields.append(f"object = {lua_string(details['object'])}, map = {details['map']}")
        elif how == "made":
            fields.append(f"profession = {details['profession']}")
        if details.get("side"):
            fields.append(f"side = {lua_string(details['side'])}")
        lines.append(f"        {{ {', '.join(fields)} }},")
    lines += ["    },", "}", ""]
    OUT.write_bytes("\r\n".join(lines).encode("utf-8"))
    print(f"-> {OUT.relative_to(ROOT)}: {len(ZONES)} zones, catches in {seen_zones}, {len(GEAR)} things that help, "
          f"{OUT.stat().st_size} bytes")


if __name__ == "__main__":
    main()
