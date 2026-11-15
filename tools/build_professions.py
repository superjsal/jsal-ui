"""Builds jsalUI/Professions/ProfessionData.lua: every profession's recipes, for the profession panel.

From the game's files for the Forever build, as CSV from wago.tools (data/spells and
data/professions):
  SkillLineAbility   each profession's recipes, and the skill where each turns yellow and grey
  SpellReagents      what each recipe uses
  SpellEffect        the item each recipe makes (effect 24, "create item")
  ItemSparse         item names (patterns and vendor reagents) and prices
  SpellCooldowns     how long before a recipe can be made again (Mooncloth, the transmutes)
and from Wowhead Forever (data/professions/wowhead-learned.txt), the skill each recipe is
learned at and how: the game's files have 1 there for nearly every recipe. And from the same
lists (data/professions/wowhead-specializations.txt), the specialisation a recipe needs.

It also writes what each material is worth (`value`, in copper), so the road can weigh a
Righteous Orb against a piece of leather: the price the game's item table gives it, a
guess from its item level where the table has none (dusts and essences), and five times
that for a hide, which comes from only a few skinnings in a hundred.

Run: python -I tools/build_professions.py 1.60.1.70790
"""

import csv
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SPELLS = ROOT / "data" / "spells"
PROF = ROOT / "data" / "professions"
OUT = ROOT / "jsalUI" / "Professions" / "ProfessionData.lua"
# Who sells the vendor reagents: every vendor players opened on Forever, from EG Link (data from
# Efficient Games, https://efficient.games, CC BY 4.0; tools/refresh_eglink.py keeps it), with
# where the player stood, on Forever's own maps. It records no faction, so a vendor's side comes
# from Wowhead's word on the same NPC where the recipe sources have it, else from whose land its
# map is, else it's taken to sell to both.
VENDORS = ROOT / "data" / "vendors" / "eglink-vendors.json"
WOWHEAD = PROF / "wowhead-sources.json"
ALLIANCE_MAPS = {1453, 1455, 1457, 1429, 1426, 1438, 1439, 1432, 1436, 1433, 1437}
HORDE_MAPS = {1454, 1456, 1458, 1411, 1412, 1420, 1421, 1413}


def sellers_of(items):
    """For the vendor reagents in `items`: {item: [npc, ...]} and {npc: (name, map, x, y, side)},
    side 1 Alliance, 2 Horde, 0 both or not known."""
    if not VENDORS.exists():
        return {}, {}
    known = json.loads(WOWHEAD.read_text(encoding="utf-8")).get("npcs", {}) if WOWHEAD.exists() else {}
    sellers, shops = {}, {}
    for npc, v in json.loads(VENDORS.read_text(encoding="utf-8"))["vendors"].items():
        sold = sorted(int(i) for i in (v.get("sells") or {}) if int(i) in items)
        spot = (v.get("positions") or [{}])[0]
        if not sold or not spot.get("uiMap"):
            continue
        side = 0
        react = (known.get(npc) or {}).get("react")
        if react:
            a = react[0] is not None and react[0] >= 0
            h = react[1] is not None and react[1] >= 0
            side = 1 if a and not h else 2 if h and not a else 0
        elif spot["uiMap"] in ALLIANCE_MAPS:
            side = 1
        elif spot["uiMap"] in HORDE_MAPS:
            side = 2
        shops[int(npc)] = (v["name"], int(spot["uiMap"]), round(spot["mapX"], 3), round(spot["mapY"], 3), side)
        for item in sold:
            sellers.setdefault(item, []).append(int(npc))
    return sellers, shops

# Skill line, name, and its key in wowhead-learned.txt.
PROFESSIONS = [
    (171, "Alchemy", "alchemy"), (164, "Blacksmithing", "blacksmithing"), (333, "Enchanting", "enchanting"),
    (202, "Engineering", "engineering"), (165, "Leatherworking", "leatherworking"), (197, "Tailoring", "tailoring"),
    (186, "Mining", "mining"), (185, "Cooking", "cooking"), (129, "First Aid", "first-aid"),
]
# How a recipe is learned, from Wowhead's source codes.
SOURCES = {6: "trainer", 5: "vendor", 2: "drop", 4: "quest", 1: "crafted"}
PATTERN = re.compile(r"^(Pattern|Recipe|Plans|Schematic|Formula|Manual|Design): (.+)$")
# Reagents any trade goods vendor sells, by name: thread, dyes, flux, vials,
# spices and the like. They count for little when picking the cheapest recipe.
VENDOR_NAMES = {
    "Coarse Thread", "Fine Thread", "Silken Thread", "Heavy Silken Thread", "Rune Thread",
    "Red Dye", "Blue Dye", "Gray Dye", "Bleach", "Pink Dye", "Orange Dye", "Green Dye", "Purple Dye",
    "Black Dye", "Yellow Dye", "Salt", "Weak Flux", "Strong Flux", "Elemental Flux", "Empty Vial",
    "Leaded Vial", "Crystal Vial", "Imbued Vial", "Simple Wood", "Copper Rod", "Coal", "Flask of Oil",
    "Fused Wiring", "Mild Spices", "Hot Spices", "Soothing Spices", "Refreshing Spring Water",
    "Ice Cold Milk", "Simple Flour", "Holy Spices", "Silver Rod", "Golden Rod", "Truesilver Rod",
    "Arcanite Rod", "Wooden Stock", "Heavy Stock", "Fishing Line",
}


def worth(item):
    """What a material is worth, in copper, for weighing one road against another."""
    price = int(item.get("BuyPrice") or 0)
    level = int(item.get("ItemLevel") or 0)
    # The table prices plain leather at about 0.7 of its item level squared, and
    # prices some things (dusts, essences, the newer scraps) at next to nothing.
    guess = round(0.7 * level * level * (3 if int(item.get("OverallQualityID") or 1) >= 2 else 1))
    value = max(price, guess, 1)
    if SCARCE.search(item["Display_lang"]):
        value *= 5
    return value


def rows(folder, name):
    with open(folder / f"{name}.csv", newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


# Hides: a few skinnings in a hundred give one, so each is worth several leathers
# whatever the item table prices it at.
SCARCE = re.compile(r"\bHide$")
# Leather is skinned as it is, though a recipe also makes each kind from the one
# below: a road that needs Heavy Leather asks for that, not for the Medium to make it.
GATHERED = re.compile(r"^(Light|Medium|Heavy|Thick|Rugged) Leather$")
# Recipes Wowhead names no source for that a trainer teaches: First Aid's last three
# bandages, from the doctors of the Triage quest (Wowhead's First Aid guide, read
# 13 Nov 2026, which calls it unconfirmed on a live realm).
TAUGHT = {(129, "Heavy Mageweave Bandage"), (129, "Runecloth Bandage"), (129, "Heavy Runecloth Bandage")}


def learned():
    out = {}
    for line in (PROF / "wowhead-learned.txt").read_text(encoding="utf-8").splitlines():
        if not line or line.startswith("#"):
            continue
        prof, entries = line.split(" ", 1)
        for entry in entries.split(","):
            spell, skill, source = (int(x) for x in entry.split(":"))
            out[spell] = (skill, source)
    return out


def main():
    build = sys.argv[1] if len(sys.argv) > 1 else "unknown"
    names = {int(r["ID"]): r["Name_lang"] for r in rows(SPELLS, "SpellName")}
    abilities = rows(SPELLS, "SkillLineAbility")
    reagents = {}
    for r in rows(PROF, "SpellReagents"):
        pairs = [(int(r[f"Reagent_{i}"]), int(r[f"ReagentCount_{i}"])) for i in range(8)]
        reagents[int(r["SpellID"])] = [(item, count) for item, count in pairs if item > 0 and count > 0]
    makes = {}
    for r in rows(PROF, "SpellEffect"):
        if r["Effect"] == "24" and r["DifficultyID"] == "0" and int(r["EffectItemType"] or 0) > 0:
            points = float(r.get("EffectBasePointsF") or 0)
            makes[int(r["SpellID"])] = (int(r["EffectItemType"]), max(1, int(round(points)) or 1))
    items = {int(r["ID"]): r for r in rows(PROF, "ItemSparse")}
    patterns = {}
    for item_id, item in items.items():
        m = PATTERN.match(item["Display_lang"])
        if m and int(item.get("BuyPrice") or 0) > 0:
            patterns.setdefault(m.group(2), (item_id, int(item["BuyPrice"]), int(item.get("RequiredSkillRank") or 0)))
    vendor = {item_id: int(item.get("BuyPrice") or 0) for item_id, item in items.items()
              if item["Display_lang"] in VENDOR_NAMES and int(item.get("BuyPrice") or 0) > 0}
    known = learned()
    # A recipe's wait before it can be made again, in seconds: its own or its
    # category's (the transmutes share one), whichever is longer.
    waits = {}
    for r in rows(PROF, "SpellCooldowns"):
        if r["DifficultyID"] == "0":
            wait = max(int(r["CategoryRecoveryTime"] or 0), int(r["RecoveryTime"] or 0)) // 1000
            if wait > 0:
                waits[int(r["SpellID"])] = wait
    slow = {}
    # The specialisation a recipe needs (Goblin Engineer, Armorsmith, Tribal Leatherworking).
    special, needs = {}, {}
    for line in (PROF / "wowhead-specializations.txt").read_text(encoding="utf-8").splitlines():
        if line and not line.startswith("#"):
            for entry in line.split(" ", 1)[1].split(","):
                spell, spec = (int(x) for x in entry.split(":"))
                special[spell] = spec

    # tools/refresh_eglink.py reads the build back from the words "own tables (build X)" in the
    # header below, to rebuild this file on the same build after a refresh: keep that phrase.
    lines = [
        "-- Every profession's recipes, for the profession panel: what each needs and",
        "-- makes, the skill it's learned at, and where it turns yellow and grey. From",
        f"-- the game's own tables (build {build}) and Wowhead Forever for the learn",
        "-- skill; regenerated by the build, not by hand.",
        "local _, ns = ...",
        "",
        "-- A recipe: { spell, learnedAt, yellow, grey, how (1 trainer, 2 pattern from",
        "-- a vendor, 3 drop, 4 quest, 0 other), item made, how many, then each reagent",
        "-- and its count }.",
        "ns.ProfessionData = {",
    ]
    how_code = {"trainer": 1, "vendor": 2, "drop": 3, "quest": 4}
    report = []
    used_vendor = set()
    used = set()
    for line_id, title, key in PROFESSIONS:
        recipes, seen = [], set()
        for r in abilities:
            if r["SkillLine"] != str(line_id):
                continue
            spell = int(r["Spell"])
            if spell in seen or spell not in reagents or not reagents[spell]:
                continue
            yellow, grey = int(r["TrivialSkillLineRankLow"] or 0), int(r["TrivialSkillLineRankHigh"] or 0)
            skill, source = known.get(spell, (0, 0))
            if skill >= 9999 or grey <= 0:
                continue
            name = names.get(spell, "")
            pattern = patterns.get(name)
            if skill <= 0:
                # Not on Wowhead: a pattern's required skill, else where it turns yellow.
                skill = pattern[2] if pattern else 0
                if skill <= 0:
                    continue
            how = how_code.get(SOURCES.get(source, ""), 0)
            if how == 0 and pattern:
                how = 2
            if how == 0 and (line_id, name) in TAUGHT:
                how = 1
            item, count = makes.get(spell, (0, 0))
            seen.add(spell)
            if spell in waits:
                slow[spell] = waits[spell]
            if spell in special:
                needs[spell] = special[spell]
            flat = [spell, skill, max(yellow, skill), grey, how, item, count]
            for reagent, n in reagents[spell]:
                flat += [reagent, n]
                used.add(reagent)
                if reagent in vendor:
                    used_vendor.add(reagent)
            recipes.append(flat)
        recipes.sort(key=lambda x: (x[1], x[0]))
        lines.append(f'    [{line_id}] = {{ name = "{title}", recipes = {{')
        for flat in recipes:
            lines.append("        { " + ", ".join(str(x) for x in flat) + " },")
        lines.append("    } },")
        report.append(f"{title}: {len(recipes)} recipes")
    lines.append("    -- Reagents any trade goods vendor sells, and their price in copper.")
    lines.append("    vendor = { " + ", ".join(f"[{i}] = {vendor[i]}" for i in sorted(used_vendor)) + " },")
    valued = sorted(i for i in used if i not in used_vendor and i in items)
    lines.append("    -- What every other reagent is worth, in copper: the game's own price for it, a")
    lines.append("    -- guess from its level where it has none, and more for a hide. For weighing")
    lines.append("    -- one road against another, not for telling anyone a price.")
    lines.append("    value = { " + ", ".join(f"[{i}] = {worth(items[i])}" for i in valued) + " },")
    gathered = sorted(i for i in used if i in items and GATHERED.match(items[i]["Display_lang"]))
    lines.append("    -- Reagents a recipe makes that are also gathered as they are (leather): the")
    lines.append("    -- road asks for these themselves, not for what they could be made from.")
    lines.append("    gathered = { " + ", ".join(f"[{i}] = true" for i in gathered) + " },")
    sellers, shops = sellers_of(used_vendor)
    lines.append("    -- Who sells each of those reagents, as vendors' numbers; and each vendor: its name,")
    lines.append("    -- map, the spot on it (0 to 1) and its side (1 Alliance, 2 Horde, 0 both or not known).")
    lines.append("    -- From every vendor players opened on Forever (Efficient Games, CC BY 4.0).")
    lines.append("    sellers = { " + ", ".join(f'[{i}] = "{",".join(str(n) for n in sorted(sellers[i]))}"' for i in sorted(sellers)) + " },")
    lines.append("    shops = {")
    for npc in sorted(shops):
        name, map_id, x, y, side = shops[npc]
        escaped = name.replace(chr(92), chr(92) * 2).replace('"', chr(92) + '"')
        lines.append(f'        [{npc}] = {{ "{escaped}", {map_id}, {x}, {y}, {side} }},')
    lines.append("    },")
    lines.append("    -- Recipes that can't be made again for a while, and how long in seconds: the")
    lines.append("    -- road takes one only when nothing else gives a point.")
    lines.append("    cooldown = { " + ", ".join(f"[{i}] = {slow[i]}" for i in sorted(slow)) + " },")
    lines.append("    -- Recipes only someone with a specialisation can learn, and the specialisation's")
    lines.append("    -- spell: on the road only once you know the recipe.")
    lines.append("    needs = { " + ", ".join(f"[{i}] = {needs[i]}" for i in sorted(needs)) + " },")
    lines += ["}", ""]
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(lines), encoding="utf-8", newline="\n")
    print(f"-> {OUT.relative_to(ROOT)} ({OUT.stat().st_size // 1024} KB)")
    for line in report:
        print("  " + line)
    print(f"  {len(used_vendor)} vendor reagents, {len(valued)} others valued, {len(slow)} recipes with a wait, {len(needs)} for a specialisation, "
          f"{len(shops)} vendors selling {len(sellers)} of the vendor reagents")


if __name__ == "__main__":
    main()
