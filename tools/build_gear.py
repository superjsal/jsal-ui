"""Builds jsalUI/Gear/GearData.lua: the gear the gear plan chooses from, and each spec's stat weights.

Items come from Wowhead Forever's gear lists (data/gear/wowhead-items.json: every uncommon and
better armor piece, jewel, cloak and weapon it lists, read slot by slot), with where each one comes
from: a drop (and from whom, and where), a quest, a vendor or a recipe. Zone names are the game's own
(data/gear/zones.json, from its AreaTable). Item names aren't kept: the game gives them, along with
each item's stats, while you play.

Stat weights are WoWSims' (data/gear/wowsims/*.sim.ts, from github.com/wowsims/classic, MIT licence,
LICENSE beside them): each spec's "epWeights", what one point of each stat is worth. They're tuned
for level 60, where Stamina counts for little; for leveling, every spec's Stamina is raised to at
least STAMINA_FLOOR, so a piece with more of it ranks a little higher.

Run: python -I tools/build_gear.py
"""

import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "data" / "gear"
OUT = ROOT / "jsalUI" / "Gear" / "GearData.lua"

STAMINA_FLOOR = 0.2

# Each class's talent trees, in the game's order, to the WoWSims spec that fits.
SPECS = {
    "WARRIOR": ["warrior", "warrior", "tank_warrior"],
    "PALADIN": ["holy_paladin", "protection_paladin", "retribution_paladin"],
    "HUNTER": ["hunter", "hunter", "hunter"],
    "ROGUE": ["rogue", "rogue", "rogue"],
    "PRIEST": ["healing_priest", "healing_priest", "shadow_priest"],
    "SHAMAN": ["elemental_shaman", "enhancement_shaman", "restoration_shaman"],
    "MAGE": ["mage", "mage", "mage"],
    "WARLOCK": ["warlock", "warlock", "warlock"],
    "DRUID": ["balance_druid", "feral_druid", "restoration_druid"],
}

# WoWSims' stat names to the game's own item stat keys.
STAT_KEYS = {
    "StatStrength": ["ITEM_MOD_STRENGTH_SHORT"],
    "StatAgility": ["ITEM_MOD_AGILITY_SHORT"],
    "StatStamina": ["ITEM_MOD_STAMINA_SHORT"],
    "StatIntellect": ["ITEM_MOD_INTELLECT_SHORT"],
    "StatSpirit": ["ITEM_MOD_SPIRIT_SHORT"],
    "StatAttackPower": ["ITEM_MOD_ATTACK_POWER_SHORT"],
    "StatRangedAttackPower": ["ITEM_MOD_RANGED_ATTACK_POWER_SHORT"],
    "StatFeralAttackPower": ["ITEM_MOD_FERAL_ATTACK_POWER_SHORT"],
    "StatMeleeHit": ["ITEM_MOD_HIT_RATING_SHORT", "ITEM_MOD_HIT_MELEE_RATING_SHORT"],
    "StatMeleeCrit": ["ITEM_MOD_CRIT_RATING_SHORT", "ITEM_MOD_CRIT_MELEE_RATING_SHORT"],
    "StatSpellHit": ["ITEM_MOD_HIT_SPELL_RATING_SHORT"],
    "StatSpellCrit": ["ITEM_MOD_CRIT_SPELL_RATING_SHORT"],
    "StatSpellPower": ["ITEM_MOD_SPELL_POWER_SHORT", "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT"],
    "StatHealingPower": ["ITEM_MOD_SPELL_HEALING_DONE_SHORT"],
    "StatMP5": ["ITEM_MOD_POWER_REGEN0_SHORT", "ITEM_MOD_MANA_REGENERATION_SHORT"],
    "StatArmor": ["RESISTANCE0_NAME"],
    "StatBonusArmor": ["ITEM_MOD_EXTRA_ARMOR_SHORT"],
    "StatDefense": ["ITEM_MOD_DEFENSE_SKILL_RATING_SHORT"],
    "StatDodge": ["ITEM_MOD_DODGE_RATING_SHORT"],
    "StatParry": ["ITEM_MOD_PARRY_RATING_SHORT"],
    "StatBlock": ["ITEM_MOD_BLOCK_RATING_SHORT"],
    "StatBlockValue": ["ITEM_MOD_BLOCK_VALUE_SHORT"],
}
# Weapon damage per second, by where the weapon goes.
DPS_KEYS = {"PseudoStatMainHandDps": "mh", "PseudoStatOffHandDps": "oh", "PseudoStatRangedDps": "ranged"}

SOURCE = {1: "Crafted", 2: "Drop", 4: "Quest", 5: "Vendor"}


def lua_string(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def weights(spec):
    text = (SRC / "wowsims" / f"{spec}.sim.ts").read_text(encoding="utf-8")
    start = text.index("epWeights")
    depth, end = 0, None
    for i in range(text.index("(", start), len(text)):
        if text[i] == "(":
            depth += 1
        elif text[i] == ")":
            depth -= 1
            if depth == 0:
                end = i
                break
    block = text[start:end]
    out, dps = {}, {}
    for name, value in re.findall(r"\[(?:Pseudo)?Stat\.(\w+)\]\s*:\s*(-?[\d.]+)", block):
        v = float(value)
        if name in STAT_KEYS:
            for key in STAT_KEYS[name]:
                out[key] = v
        elif name in DPS_KEYS:
            dps[DPS_KEYS[name]] = v
    out["ITEM_MOD_STAMINA_SHORT"] = max(out.get("ITEM_MOD_STAMINA_SHORT", 0), STAMINA_FLOOR)
    return out, dps


def where(item, zones):
    sources = item[10] or []
    more = (item[11] or [[]])[0] if item[11] else None
    kind = SOURCE.get(sources[0], "") if sources else ""
    place = ""
    if more:
        name, mtype, _mid, zone, _c = more
        zone_name = zones.get(str(zone), "") if zone else ""
        if kind == "Crafted":
            place = ""
        elif mtype == 5:
            place = name
        else:
            place = " · ".join(b for b in (name, zone_name) if b)
    return kind, place


def main():
    data = json.loads((SRC / "wowhead-items.json").read_text(encoding="utf-8"))
    zones = json.loads((SRC / "zones.json").read_text(encoding="utf-8"))
    places, place_index = [], {}
    by_slot = {}
    kinds = {"": 0, "Drop": 1, "Quest": 2, "Vendor": 3, "Crafted": 4}
    for item in sorted(data["items"], key=lambda i: i[0]):
        item_id, _name, quality, req, ilvl, slot, cls, sub, side, reqclass = item[:10]
        kind, place = where(item, zones)
        if place not in place_index:
            place_index[place] = len(places)
            places.append(place)
        by_slot.setdefault(slot, []).append(
            f"{item_id},{req},{ilvl},{cls},{sub},{side},{reqclass},{quality},{kinds[kind]},{place_index[place] + 1}")
    rows = [f"[{slot}] = {lua_string(';'.join(entries))}" for slot, entries in sorted(by_slot.items())]
    spec_lines = []
    for class_file, trees in SPECS.items():
        parts = []
        for spec in trees:
            stats, dps = weights(spec)
            stat_text = ", ".join(f"{k} = {v:g}" for k, v in sorted(stats.items()) if v)
            dps_text = ", ".join(f"{k} = {v:g}" for k, v in sorted(dps.items()) if v)
            parts.append(f"        {{ sim = {lua_string(spec)}, stats = {{ {stat_text} }}, dps = {{ {dps_text} }} }},")
        spec_lines.append(f"    {class_file} = {{\n" + "\n".join(parts) + "\n    },")
    lines = [
        "-- The gear the gear plan chooses from, from Wowhead Forever's gear lists (read "
        f"{data['fetched']}), and each",
        "-- spec's stat weights, from WoWSims (github.com/wowsims/classic, MIT licence). Generated by",
        "-- tools/build_gear.py; don't edit by hand.",
        "local _, ns = ...",
        "",
        "ns.GearData = {",
        "    -- Where each item comes from: 0 not known, 1 drop, 2 quest, 3 vendor, 4 crafted.",
        "    kinds = { [0] = \"\", \"Drop\", \"Quest\", \"Vendor\", \"Crafted\" },",
        "    -- The places named in sources (a mob and its zone, a quest, a vendor), by number.",
        "    places = { " + ", ".join(lua_string(p) for p in places) + " },",
        "    -- By the game's slot (inventory type): one line of items, each \"item ID, required level,",
        "    -- item level, class, subclass, side (1 Alliance, 2 Horde, 0 both), classes that may use it",
        "    -- (0 all), quality, source kind, place\" and separated by \";\". Kept as text, so the gear",
        "    -- costs little memory until the gear plan is opened and reads the slots it needs.",
        "    items = {",
        "        " + ",\n        ".join(rows),
        "    },",
        "    -- Each class's talent trees, in order: what one point of each stat is worth.",
        "    specs = {",
        *spec_lines,
        "    },",
        "}",
    ]
    OUT.parent.mkdir(exist_ok=True)
    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    print(f"{sum(len(v) for v in by_slot.values())} items in {len(rows)} slots, {len(places)} places -> {OUT.relative_to(ROOT)} ({OUT.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
