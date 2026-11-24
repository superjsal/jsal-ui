"""Builds jsalUI/Gear/GearData.lua: the gear the gear plan chooses from, and each spec's stat weights.

Items come from Wowhead Forever's gear lists (data/gear/wowhead-items.json: every uncommon and
better armor piece, jewel, cloak and weapon it lists, read slot by slot), with where each one comes
from: a drop (and from whom, and where), a quest, a vendor or a recipe. Zone names are the game's own
(data/gear/zones.json, from its AreaTable). Item names aren't kept: the game gives them, along with
each item's stats, while you play.

Stat weights are WoWSims': what one point of each stat is worth to a spec. Where WoWSims Forever
(github.com/wowsims/forever, MIT licence, built for Forever's own game) has a preset for a tree,
it's that (data/gear/wowsims-forever/, LICENSE and the commit beside them; FOREVER below names
each). Forever's sims weigh crit, hit, dodge, parry and block per point of rating; the editor's are
per 1%, so they're multiplied by Forever's ratings for 1% (RATING_PER_PERCENT). Where it has none
(mage, warlock, and the paladin, shaman and druid healers; hunter until 15 Nov 2026), it's WoWSims Classic's
(data/gear/wowsims/*.sim.ts, github.com/wowsims/classic, MIT). Both are tuned for level 60, where
Stamina counts for little; for leveling, every spec's Stamina is at least STAMINA_SHARE of its top
main stat, so a piece with more of it ranks a little higher.

Checked against what the game makes of each stat (14 Nov 2026, WoWSims' latest, unchanged since
March 2025), two are put right in checked():
- A hunter's Agility is 2 ranged attack power a point, and 1% crit for 53 of it at 60, so it's worth
  at least 2 RAP plus that much crit, by WoWSims' own RAP and crit weights. Theirs, 0.64, is under a
  third of that, and made 14 Stamina with 6 Strength beat 6 Agility for a hunter.
- The healing sims weigh spell power, which in WoWSims is damage and healing. An item of "+Healing"
  (healing only) is its own stat in the game, and they gave it nothing: it gets spell power's weight.

One rule for Stamina, every class alike: damage and healing trees keep WoWSims' small figure (at
least STAMINA_SHARE of the top main stat), and a tank tree takes a WoWSims tank set that weighs
Stamina as a tank does. Neither WoWSims has a Protection paladin set that does (Classic's weighs it
at 0, tuned for raid avoidance; Forever's has none), so a Protection paladin takes the warrior
tank's, the other plate tank's.

A drop Wowhead names no one place for (an empty sourcemore: it drops from ordinary creatures in
more than one place) takes its dungeons from data/gear/wowhead-places.json when that file is there
(tools/wowhead/places.js reads each item's "Dropped by" list): the dungeon alone where any of the
dungeon's ordinary creatures drops it, or "boss · dungeon" where only one of its bosses does, as a
zone drop or a boss drop is written. A piece of an item set (the game's ItemSet table,
data/gear/ItemSet.csv) takes every dungeon it drops in; any other piece only when nearly all of it drops in
dungeons, and then only the dungeons with a real share of its drops (MOSTLY_IN_DUNGEONS and
DUNGEON_SHARE below), so a world drop that a few dungeon creatures also drop stays a world drop. Its place in the lists is the dungeon where it drops most; the
others, where there are any, go in GearData's `more`, read only by the Dungeon guide's Trash card.
Outdoors, or nowhere read, it keeps no place.

A shield's own block ("3 Block" on its tooltip) is left out of the game's item stats and its tables,
so it comes from Wowhead too: data/gear/wowhead-shields.json, read by tools/wowhead/shields.py for
every shield in the game's Item table, white ones as well. GearData's `block` keeps the ones with
block, and Gear.lua adds it to a shield's stats as Block Value.

Run: python -I tools/build_gear.py [--places <file>] [--out <file>]
"""

import csv
import ast
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "data" / "gear"
OUT = ROOT / "jsalUI" / "Gear" / "GearData.lua"
PLACES = SRC / "wowhead-places.json"
SHIELDS = SRC / "wowhead-shields.json"

STAMINA_SHARE = 0.1
MAIN_STATS = ("ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_AGILITY_SHORT", "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT",
              "ITEM_MOD_SPELL_HEALING_DONE_SHORT")

HEALERS = ("holy_paladin", "healing_priest", "restoration_shaman", "restoration_druid")
HUNTER_AGILITY_PER_CRIT = 53  # Agility for 1% crit, a hunter at 60

# Each class's talent trees, in the game's order, to the WoWSims spec that fits.
SPECS = {
    "WARRIOR": ["warrior", "warrior", "tank_warrior"],
    "PALADIN": ["holy_paladin", "tank_warrior", "retribution_paladin"],
    "HUNTER": ["hunter", "hunter", "hunter"],
    "ROGUE": ["rogue", "rogue", "rogue"],
    "PRIEST": ["healing_priest", "healing_priest", "shadow_priest"],
    "SHAMAN": ["elemental_shaman", "enhancement_shaman", "restoration_shaman"],
    "MAGE": ["mage", "mage", "mage"],
    "WARLOCK": ["warlock", "warlock", "warlock"],
    "DRUID": ["balance_druid", "feral_druid", "restoration_druid"],
}

# Where WoWSims Forever has a preset for a tree: its file in data/gear/wowsims-forever and the preset.
# None: WoWSims Classic's, from SPECS. Pre-raid sets where there's a choice, nearer leveling gear.
# A plate tank takes the Protection warrior's Balanced weights: WoWSims' own default for that tree, and
# the set that tree starts on (PREBIS below).
PLATE_TANK = ("warrior_protection", "PreBiSBalancedEpWeights")
# WoWSims Forever simulates no healer (every one is a "Gear Planner"), so there's nothing to work out;
# its healing priest's preset is the one healer set made for Forever, and the other healers take it.
HEALER = ("priest_healer", "HolySingleTargetEpWeights")
FOREVER = {
    "WARRIOR": [("warrior_dps", "PreBiSArmsEpWeights"), ("warrior_dps", "PreBiSFuryEpWeights"), PLATE_TANK],
    # Retribution: WoWSims' own Stat Weights tool on its Unsealed Wrath build, not that preset's weights,
    # whose haste and hit were far from what the tool measures (computed/paladin_retribution.json says how).
    "PALADIN": [HEALER, PLATE_TANK, ("computed", "paladin_retribution")],
    # WoWSims Forever ships hunter weights since 15 Nov 2026 (its Weave, Turret and Melee sets); its BM,
    # MM and SV builds all use the Turret gear, so all three trees take Turret.
    "HUNTER": [("hunter_dps", "TurretEpWeights"), ("hunter_dps", "TurretEpWeights"), ("hunter_dps", "TurretEpWeights")],
    "ROGUE": [("rogue_dps", "EP_PRESET_ASSASSINATION"), ("rogue_dps", "EP_PRESET_COMBAT_SINISTER"),
              ("rogue_dps", "EP_PRESET_SUBTLETY")],
    "PRIEST": [("priest_healer", "DiscSingleTargetEpWeights"), ("priest_healer", "HolySingleTargetEpWeights"),
               ("priest_dps", "ShadowEpWeights")],
    "SHAMAN": [("shaman_elemental", "DefaultEpWeights"), ("shaman_enhancement", "PreBiSEpWeights"), HEALER],
    "MAGE": [("computed", "mage_arcane"), ("computed", "mage_fire"), ("computed", "mage_frost")],
    "WARLOCK": [("computed", "warlock_affliction"), ("computed", "warlock_demonology"), ("computed", "warlock_destruction")],
    "DRUID": [("druid_balance", "PreBiSEpWeights"), ("druid_feral_ep", "CatEp"), HEALER],
}
# One school's spell damage, like an "of Frozen Wrath" green's: the game names it
# ITEM_MOD_FROST_DAMAGE_DONE_SHORT (seen in game, 16 Nov 2026, /dump of C_Item.GetItemStats on one),
# and the other schools by the same pattern. WoWSims weighs each school on its own.
def school(name):
    return ["ITEM_MOD_" + name.upper() + "_DAMAGE_DONE_SHORT"]
SCHOOLS = ("Arcane", "Fire", "Frost", "Holy", "Nature", "Shadow")
# Trees WoWSims Forever ships no weights for, worked out with its own Stat Weights tool on its own
# preset talents and gear (data/gear/wowsims-forever/computed/*.json, each saying how). Rows are per 1%
# for crit and hit, as the tool shows them.
COMPUTED_KEYS = {
    "Strength": ["ITEM_MOD_STRENGTH_SHORT"],
    "Agility": ["ITEM_MOD_AGILITY_SHORT"],
    "Stamina": ["ITEM_MOD_STAMINA_SHORT"],
    "Intellect": ["ITEM_MOD_INTELLECT_SHORT"],
    "Spirit": ["ITEM_MOD_SPIRIT_SHORT"],
    "Attack Power": ["ITEM_MOD_ATTACK_POWER_SHORT"],
    "Ranged Attack Power": ["ITEM_MOD_RANGED_ATTACK_POWER_SHORT"],
    "Spell Damage": ["ITEM_MOD_SPELL_DAMAGE_DONE_SHORT"],
    "Healing Power": ["ITEM_MOD_SPELL_HEALING_DONE_SHORT"],
    "1% Hit": ["ITEM_MOD_HIT_RATING_SHORT", "ITEM_MOD_HIT_MELEE_RATING_SHORT", "ITEM_MOD_HIT_SPELL_RATING_SHORT"],
    "1% Crit": ["ITEM_MOD_CRIT_RATING_SHORT", "ITEM_MOD_CRIT_MELEE_RATING_SHORT", "ITEM_MOD_CRIT_SPELL_RATING_SHORT"],
    "MP5": ["ITEM_MOD_POWER_REGEN0_SHORT", "ITEM_MOD_MANA_REGENERATION_SHORT"],
    "Defense": ["ITEM_MOD_DEFENSE_SKILL_RATING_SHORT"],
    "1% Dodge": ["ITEM_MOD_DODGE_RATING_SHORT"],
    "1% Parry": ["ITEM_MOD_PARRY_RATING_SHORT"],
    "1% Block": ["ITEM_MOD_BLOCK_RATING_SHORT"],
    "Block Value": ["ITEM_MOD_BLOCK_VALUE_SHORT"],
    "Armor": ["RESISTANCE0_NAME"],
    "Bonus Armor": ["ITEM_MOD_EXTRA_ARMOR_SHORT"],
    # Every stat WoWSims weighs is kept, so each can be changed in the game's Weights editor, even
    # where few items have it (haste is on Forever's test items only, spell penetration on 23).
    "Spell Piercing": ["ITEM_MOD_SPELL_PENETRATION_SHORT"],
    "1% Haste": ["ITEM_MOD_HASTE_RATING_SHORT"],
    "1% Expertise": ["ITEM_MOD_EXPERTISE_RATING_SHORT"],
    "Armor Penetration": ["ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT"],
    "Mana": ["ITEM_MOD_MANA_SHORT"],
    **{s + " Spell Damage": school(s) for s in SCHOOLS},
}
COMPUTED_DPS = {"Main Hand DPS": "mh", "Off Hand DPS": "oh", "Ranged DPS": "ranged"}

# Forever's ratings for 1% (its sim/core/base_stats_auto_gen.go); defense is 1 rating a point.
RATING_PER_PERCENT = {"StatHitRating": 10, "StatCritRating": 14, "StatDodgeRating": 12, "StatParryRating": 15,
                      "StatBlockRating": 5, "StatDefenseRating": 1, "StatHasteRating": 10, "StatExpertiseRating": 10}
FOREVER_KEYS = {
    "StatStrength": ["ITEM_MOD_STRENGTH_SHORT"],
    "StatAgility": ["ITEM_MOD_AGILITY_SHORT"],
    "StatStamina": ["ITEM_MOD_STAMINA_SHORT"],
    "StatIntellect": ["ITEM_MOD_INTELLECT_SHORT"],
    "StatSpirit": ["ITEM_MOD_SPIRIT_SHORT"],
    "StatAttackPower": ["ITEM_MOD_ATTACK_POWER_SHORT"],
    "StatRangedAttackPower": ["ITEM_MOD_RANGED_ATTACK_POWER_SHORT"],
    "StatFeralAttackPower": ["ITEM_MOD_FERAL_ATTACK_POWER_SHORT"],
    "StatHitRating": ["ITEM_MOD_HIT_RATING_SHORT", "ITEM_MOD_HIT_MELEE_RATING_SHORT", "ITEM_MOD_HIT_SPELL_RATING_SHORT"],
    "StatCritRating": ["ITEM_MOD_CRIT_RATING_SHORT", "ITEM_MOD_CRIT_MELEE_RATING_SHORT", "ITEM_MOD_CRIT_SPELL_RATING_SHORT"],
    "StatSpellDamage": ["ITEM_MOD_SPELL_DAMAGE_DONE_SHORT"],
    "StatHealingPower": ["ITEM_MOD_SPELL_HEALING_DONE_SHORT"],
    "StatMP5": ["ITEM_MOD_POWER_REGEN0_SHORT", "ITEM_MOD_MANA_REGENERATION_SHORT"],
    "StatArmor": ["RESISTANCE0_NAME"],
    "StatBonusArmor": ["ITEM_MOD_EXTRA_ARMOR_SHORT"],
    "StatDefenseRating": ["ITEM_MOD_DEFENSE_SKILL_RATING_SHORT"],
    "StatDodgeRating": ["ITEM_MOD_DODGE_RATING_SHORT"],
    "StatParryRating": ["ITEM_MOD_PARRY_RATING_SHORT"],
    "StatBlockRating": ["ITEM_MOD_BLOCK_RATING_SHORT"],
    "StatBlockValue": ["ITEM_MOD_BLOCK_VALUE_SHORT"],
    "StatHasteRating": ["ITEM_MOD_HASTE_RATING_SHORT"],
    "StatExpertiseRating": ["ITEM_MOD_EXPERTISE_RATING_SHORT"],
    "StatArmorPenetration": ["ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT"],
    "StatSpellPiercing": ["ITEM_MOD_SPELL_PENETRATION_SHORT"],
    "StatMP": ["ITEM_MOD_MANA_SHORT"],
    "StatHealth": ["ITEM_MOD_HEALTH_SHORT"],
    **{"Stat" + s + "Damage": school(s) for s in SCHOOLS},
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
    **{"Stat" + s + "Power": school(s) for s in SCHOOLS},
}
# Weapon damage per second, by where the weapon goes.
DPS_KEYS = {"PseudoStatMainHandDps": "mh", "PseudoStatOffHandDps": "oh", "PseudoStatRangedDps": "ranged"}

SOURCE = {1: "Crafted", 2: "Drop", 3: "PvP", 4: "Quest", 5: "Vendor"}
# What only a raid gives, for the gear goal's stages: a piece got by another road (a quest, a
# vendor, a craft) that needs a raid first waits for the raids. Raids' zones, by Wowhead's zone
# ID (a quest's or a vendor's); what a craft takes that only drops in a raid; and the rest by
# hand, as nothing in the lists says it (Onyxia's and Nefarian's heads, the Ahn'Qiraj signets,
# the Zandalar Tribe's trader).
RAID_ZONES = {1977, 2717, 2677, 2159, 3428, 3429, 3456}
RAID_REAGENTS = {
    17010, 17011, 17012, 17203,                    # Fiery Core, Lava Core, Core Leather, Sulfuron Ingot
    19767, 19768, 19726, 19774, 19943,             # Primal Bat and Tiger Leather, Bloodvine, Souldarite, Massive Mojo
    19698, 19699, 19700, 19701, 19702, 19703, 19704, 19705, 19706,   # Zul'Gurub's coins
    18562, 17771, 15410,                           # Elementium Ore and Bar, Scale of Onyxia
    22202, 22203, 22682, 22373, 22374, 22375, 22376,   # Obsidian Shards, Frozen Rune, Wartorn Scraps
}
RAID_ITEMS = {18404, 18403, 18406, 19383, 19384, 19366}
RAID_NAMES = {"Signet Ring of the Bronze Dragonflight"}
RAID_VENDORS = {"Rin'wosho the Trader"}


# WoWSims Forever's pre-raid sets, from its batch sims (data/gear/wowsims-forever/sets, its COMMIT beside them;
# MIT, as its weights are): by class, each build's set and its cheap one where there is one, the talent trees it
# goes with (the Gear plan's sets menu offers a tree only its own), and the build each talent tree starts on (None:
# WoWSims has no pre-raid set for it, and the goal is the weights' own). A hunter's builds are ways to play, not
# trees, so each goes with all three; a warrior's two Protection builds go with Protection.
PREBIS = {
    "HUNTER": ([("weave", "Weave", "hunter_dps_prebis_weave", (1, 2, 3)),
                ("turret", "Turret", "hunter_dps_prebis_turret", (1, 2, 3)),
                ("melee", "Melee", "hunter_dps_prebis_melee", (1, 2, 3))], ["turret", "turret", "weave"]),
    "MAGE": ([("arcane", "Arcane", "mage_dps_preraid", (1,)), ("fire", "Fire", "mage_dps_preraidFire", (2,)),
              ("frost", "Frost", "mage_dps_preraidFrost", (3,))], ["arcane", "fire", "frost"]),
    "WARLOCK": ([("preraid", "Pre-raid", "warlock_dps_preraid", (1, 2, 3))], ["preraid", "preraid", "preraid"]),
    "WARRIOR": ([("arms", "Arms", "warrior_dps_prebis_arms", (1,)), ("fury", "Fury", "warrior_dps_prebis_fury", (2,)),
                 ("offensive", "Prot offensive", "warrior_protection_prebis_offensive", (3,)),
                 ("balanced", "Prot balanced", "warrior_protection_prebis_balanced", (3,))], ["arms", "fury", "balanced"]),
    "DRUID": ([("balance", "Balance", "druid_balance_prebis", (1,)), ("feral", "Feral", "druid_feralcat_pre_raid", (2,))],
              ["balance", "feral", None]),
    "PRIEST": ([("healer", "Healer", "priest_healer_preraid", (1, 2))], ["healer", "healer", None]),
}
SET_SLOTS = ["head", "neck", "shoulder", "back", "chest", "wrist", "hands", "waist", "legs", "feet",
             "finger1", "finger2", "trinket1", "trinket2", "main_hand", "off_hand", "ranged"]


def slug(name):
    return re.sub(r"[^a-z0-9]+", "_", name.lower().replace("'", "")).strip("_")


def read_set(name, items):
    """A set's 17 item IDs in WoWSims' slot order (0 for an empty place), from its .gear.json or .gear.siml.
    A .siml names its items: by the name, with "_ilvlN" where two share one; of several, the newest ID."""
    folder = SRC / "wowsims-forever" / "sets"
    path = folder / (name + ".gear.json")
    if path.exists():
        ids = [int(it.get("id", 0)) for it in json.loads(path.read_text(encoding="utf-8"))["items"]]
        return (ids + [0] * 17)[:17]
    path = folder / (name + ".gear.siml")
    if not path.exists():
        return None
    by = {}
    for x in items:
        by.setdefault(slug(x[1]), []).append(x)
    ids = [0] * 17
    for line in path.read_text(encoding="utf-8").splitlines():
        parts = line.split()
        if len(parts) < 2 or parts[0] not in SET_SLOTS:
            continue
        key, level = parts[1], None
        m = re.match(r"(.*)_ilvl(\d+)$", key)
        if m:
            key, level = m.group(1), int(m.group(2))
        found = [x for x in by.get(key, []) if level is None or x[4] == level]
        if not found:
            raise SystemExit("no item for %s in %s" % (parts[1], name))
        ids[SET_SLOTS.index(parts[0])] = max(found, key=lambda x: (x[4], x[0]))[0]
    return ids


def prebis_lines(items):
    out = []
    for class_file, (builds, default) in PREBIS.items():
        # Each tree's own build goes with it: a list that left one out would offer a tree a set it can't pick.
        for tree, start in enumerate(default, 1):
            if start and not any(key == start and tree in trees for key, _, _, trees in builds):
                raise SystemExit("%s: tree %d starts on %s, which isn't listed for it" % (class_file, tree, start))
        parts = ["        default = { %s }," % ", ".join(lua_string(d) if d else "false" for d in default)]
        for key, label, name, trees in builds:
            full, cheap = read_set(name, items), read_set(name + "_cheap", items)
            parts.append("        { key = %s, name = %s, specs = { %s }, full = %s%s }," % (
                lua_string(key), lua_string(label), ", ".join(map(str, trees)), lua_string(",".join(map(str, full))),
                (", cheap = " + lua_string(",".join(map(str, cheap)))) if cheap else ""))
        out.append("    %s = {\n%s\n    }," % (class_file, "\n".join(parts)))
    return out


def craft_reagents():
    """By a craft's spell ID: the items it takes."""
    out = {}
    with open(ROOT / "data" / "professions" / "SpellReagents.csv", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            out[int(row["SpellID"])] = {int(row["Reagent_%d" % i]) for i in range(8) if row["Reagent_%d" % i] != "0"}
    return out


def raid_only(item, reagents):
    """Whether a piece got by another road than a boss's drop needs a raid first."""
    item_id, name = item[0], item[1]
    if item_id in RAID_ITEMS or name in RAID_NAMES:
        return True
    sources = item[10] or []
    for more in item[11] or []:
        if not more:
            continue
        mname, mtype, mid, zone, cat = more
        kind = SOURCE.get(sources[0], "") if sources else ""
        if kind == "Quest" and (cat in RAID_ZONES or zone in RAID_ZONES):
            return True
        if kind == "Vendor" and (zone in RAID_ZONES or mname in RAID_VENDORS):
            return True
        if kind == "Crafted" and mtype == 6 and reagents.get(mid, set()) & RAID_REAGENTS:
            return True
    return False


def lua_string(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def bracketed(text, start):
    """The text from start to the bracket that closes the first one after it."""
    depth = 0
    for i in range(text.index("(", start), len(text)):
        if text[i] == "(":
            depth += 1
        elif text[i] == ")":
            depth -= 1
            if depth == 0:
                return text[start:i]
    raise ValueError("unclosed")


def stamina(out):
    top = max((out.get(k, 0) for k in MAIN_STATS), default=0)
    out["ITEM_MOD_STAMINA_SHORT"] = max(out.get("ITEM_MOD_STAMINA_SHORT", 0), round(STAMINA_SHARE * top, 3))


def forever_weights(file, preset):
    text = (SRC / "wowsims-forever" / f"{file}.ts").read_text(encoding="utf-8")
    found = re.search(r"const " + preset + r"\s*=", text)
    block = bracketed(text, found.end())
    out, dps = {}, {}
    for name, value in re.findall(r"\[(?:Pseudo)?Stat\.(\w+)\]\s*:\s*(-?[\d.]+)", block):
        v = round(float(value) * RATING_PER_PERCENT.get(name, 1), 3)
        if name in FOREVER_KEYS:
            for key in FOREVER_KEYS[name]:
                out[key] = v
        elif name in DPS_KEYS:
            dps[DPS_KEYS[name]] = round(float(value), 3)
    # An item's "+Attack Power" is ranged attack power too: a hunter's counts as that (a set that
    # weighs only ranged attack power, like the hunter's Turret, gave it nothing).
    if out.get("ITEM_MOD_RANGED_ATTACK_POWER_SHORT", 0) > out.get("ITEM_MOD_ATTACK_POWER_SHORT", 0):
        out["ITEM_MOD_ATTACK_POWER_SHORT"] = out["ITEM_MOD_RANGED_ATTACK_POWER_SHORT"]
    # An item of spell damage and healing is both.
    both = out.get("ITEM_MOD_SPELL_DAMAGE_DONE_SHORT", 0) + out.get("ITEM_MOD_SPELL_HEALING_DONE_SHORT", 0)
    if both:
        out["ITEM_MOD_SPELL_POWER_SHORT"] = round(both, 3)
    stamina(out)
    return out, dps


def computed_weights(name):
    data = json.loads((SRC / "wowsims-forever" / "computed" / f"{name}.json").read_text(encoding="utf-8"))
    out, dps = {}, {}
    for stat, value in data["ep"].items():
        if stat in COMPUTED_KEYS and value > 0:
            for key in COMPUTED_KEYS[stat]:
                out[key] = round(value, 3)
        elif stat in COMPUTED_DPS and value > 0:
            dps[COMPUTED_DPS[stat]] = round(value, 3)
    # An item's "+Attack Power" is ranged attack power too: a hunter's counts as that.
    if out.get("ITEM_MOD_RANGED_ATTACK_POWER_SHORT", 0) > out.get("ITEM_MOD_ATTACK_POWER_SHORT", 0):
        out["ITEM_MOD_ATTACK_POWER_SHORT"] = out["ITEM_MOD_RANGED_ATTACK_POWER_SHORT"]
    both = out.get("ITEM_MOD_SPELL_DAMAGE_DONE_SHORT", 0) + out.get("ITEM_MOD_SPELL_HEALING_DONE_SHORT", 0)
    if both:
        out["ITEM_MOD_SPELL_POWER_SHORT"] = round(both, 3)
    stamina(out)
    return out, dps


def weights(spec):
    text = (SRC / "wowsims" / f"{spec}.sim.ts").read_text(encoding="utf-8")
    block = bracketed(text, text.index("epWeights"))
    out, dps = {}, {}
    for name, value in re.findall(r"\[(?:Pseudo)?Stat\.(\w+)\]\s*:\s*(-?[\d.]+)", block):
        v = float(value)
        if name in STAT_KEYS:
            for key in STAT_KEYS[name]:
                out[key] = v
        elif name in DPS_KEYS:
            dps[DPS_KEYS[name]] = v
    unified(out)
    checked(spec, out)
    stamina(out)
    return out, dps


def unified(out):
    """Forever's items give one crit and one hit, spell or melee alike (the Illusionary Rod's 1% spell
    crit is ITEM_MOD_CRIT_RATING_SHORT = 14), where Classic's sims weigh melee and spell apart. Each
    takes the larger of the two, so a mage's crit counts."""
    for stat in ("CRIT", "HIT"):
        keys = [f"ITEM_MOD_{stat}_RATING_SHORT", f"ITEM_MOD_{stat}_MELEE_RATING_SHORT", f"ITEM_MOD_{stat}_SPELL_RATING_SHORT"]
        best = max(out.get(k, 0) for k in keys)
        if best:
            for k in keys:
                out[k] = best


def checked(spec, out):
    """Puts right what WoWSims' weights get wrong by the game's own stat rules (see the top)."""
    if spec == "hunter":
        agility = 2 * out["ITEM_MOD_RANGED_ATTACK_POWER_SHORT"] + out["ITEM_MOD_CRIT_RATING_SHORT"] / HUNTER_AGILITY_PER_CRIT
        out["ITEM_MOD_AGILITY_SHORT"] = max(out["ITEM_MOD_AGILITY_SHORT"], round(agility, 2))
    if spec in HEALERS:
        out.setdefault("ITEM_MOD_SPELL_HEALING_DONE_SHORT", out["ITEM_MOD_SPELL_POWER_SHORT"])


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


# A piece that isn't a set's takes dungeon places only when dungeon creatures drop at least this share of
# it. The full read of 22 Nov 2026 set it: a true dungeon drop comes from a handful of creatures, all of
# them in dungeons (99% and up), while a world drop comes from 50 to 150 creatures of which most of the
# highest are in dungeons anyway (30% to 87%), and at half, 24 world drops stood on Trash cards.
MOSTLY_IN_DUNGEONS = 0.9
# And then only in a dungeon whose creatures drop at least this share of all of it, so one stray dungeon
# creature among a world drop's many doesn't put it on that dungeon's Trash card. Tune after the full read
# (place_items.py --why shows every read item's shares).
DUNGEON_SHARE = 0.15


def set_pieces():
    """The item IDs that belong to an item set, from the game's ItemSet table (data/gear/ItemSet.csv)."""
    path = SRC / "ItemSet.csv"
    out = set()
    if not path.exists():
        return out
    with open(path, newline="", encoding="utf-8") as f:
        for r in csv.DictReader(f):
            for k, v in r.items():
                if k.startswith("ItemID_") and v and int(v):
                    out.add(int(v))
    return out


def dungeon_bosses():
    """Each dungeon's bosses by Wowhead's zone ID: the names its loot was read under
    (data/dungeons/wowhead.json) and the NPC names tools/wowhead/bosses.py's ALIAS gives them."""
    tree = ast.parse((ROOT / "tools" / "wowhead" / "bosses.py").read_text(encoding="utf-8"))
    alias = next(ast.literal_eval(n.value) for n in tree.body
                 if isinstance(n, ast.Assign) and getattr(n.targets[0], "id", "") == "ALIAS")
    zones = json.loads((ROOT / "data" / "dungeons" / "wowhead.json").read_text(encoding="utf-8"))["zones"]
    out = {}
    for z, zone in zones.items():
        names = set()
        for boss in zone.get("loot", {}):
            names.add(boss)
            names.update(alias.get(boss, []))
        out[int(z)] = names
    return out


def is_boss(name, bosses):
    """A boss by name, or by a name of five letters or more that begins the other (as the guide
    finds one: Dungeons.lua's IsBoss)."""
    for n in bosses:
        if n == name or (len(n) >= 5 and len(name) >= 5 and (name.startswith(n) or n.startswith(name))):
            return True
    return False


def dungeon_places(read, zones, inside, bosses, levels=None):
    """An item's places from what places.js read of it: one for each of the guide's dungeons where
    a creature drops it, the dungeon's name where any ordinary creature does, "boss · dungeon"
    where only bosses do (the one that drops it most often); [] when no creature in a dungeon was
    read. The dungeon where it drops most comes first: by the best count / outof of a creature there
    that Wowhead gives both numbers for, and on a tie, or where the numbers are missing, the
    lowest-level dungeon (`levels`, by zone ID), then the name, so the order is the same each build."""
    levels = levels or {}
    best = {}
    for npc in (read or {}).get("npcs") or []:
        count, outof = npc.get("count") or 0, npc.get("outof") or 0
        rate = count / outof if count > 0 and outof > 0 else 0
        for z in npc.get("zones") or []:
            if z not in inside or not zones.get(str(z)):
                continue
            boss = is_boss(npc["name"], bosses.get(z, ()))
            here = best.setdefault(z, {"trash": None, "boss": None})
            key = "boss" if boss else "trash"
            if here[key] is None or rate > here[key][0]:
                here[key] = (rate, npc["name"])
    places = []
    for z, here in best.items():
        level = levels.get(z, 999)
        if here["trash"]:
            places.append((here["trash"][0], level, zones[str(z)]))
        else:
            places.append((here["boss"][0], level, here["boss"][1] + " · " + zones[str(z)]))
    places.sort(key=lambda p: (-p[0], p[1], p[2]))
    return [p for _rate, _level, p in places]


def shares(read, zones, inside):
    """How much of an item each dungeon's creatures drop, as shares of all its droppers: by Wowhead's
    drop counts where the page gives any (a creature without one counts 0), else by how many creatures.
    ({zone ID: share}, the dungeons' share together, "count" or "creatures")."""
    npcs = (read or {}).get("npcs") or []
    by_count = any((n.get("count") or 0) > 0 for n in npcs)
    total, at = 0, {}
    for n in npcs:
        weight = max(n.get("count") or 0, 0) if by_count else 1
        total += weight
        z = next((z for z in n.get("zones") or [] if z in inside and zones.get(str(z))), None)
        if z is not None:
            at[z] = at.get(z, 0) + weight
    if not total:
        return {}, 0, "creatures"
    each = {z: w / total for z, w in at.items()}
    return each, sum(each.values()), "count" if by_count else "creatures"


def placed(read, zones, inside, bosses, levels, set_piece):
    """An item's dungeon places by the rule (see the top), and why: a set piece takes every dungeon it
    drops in; any other piece, when its dungeons' share passes MOSTLY_IN_DUNGEONS, the dungeons with at
    least DUNGEON_SHARE; otherwise none. (places, why)."""
    every = dungeon_places(read, zones, inside, bosses, levels)
    each, inside_share, by = shares(read, zones, inside)
    why = {"set": set_piece, "share": inside_share, "by": by,
           "dungeons": {zones[str(z)]: s for z, s in each.items()}}
    if not every:
        why["rule"] = "no dungeon creature"
        return [], why
    if set_piece:
        why["rule"] = "set piece"
        return every, why
    if inside_share < MOSTLY_IN_DUNGEONS:
        why["rule"] = "mostly elsewhere"
        return [], why
    keep = {zones[str(z)] for z, s in each.items() if s >= DUNGEON_SHARE}
    places = [p for p in every if p.split(" · ")[-1] in keep]
    why["rule"] = "mostly in dungeons" if places else "no dungeon with a real share"
    return places, why


def place_context(zones):
    """What placed() needs besides an item's read: the guide's dungeons by Wowhead zone, their bosses,
    their levels, and the set pieces."""
    from build_dungeons import WOWHEAD_ZONE, dungeon_rows  # noqa: E402
    inside = set(WOWHEAD_ZONE.values())
    levels = {}
    for row in dungeon_rows():
        z = WOWHEAD_ZONE[row[3]]
        levels[z] = min(levels.get(z, row[1]), row[1])
    return inside, dungeon_bosses(), levels, set_pieces()


def read_places(path, zones):
    """Each placeless drop's dungeon places by item ID, from wowhead-places.json; {} without it."""
    if not path.exists():
        return {}
    inside, bosses, levels, sets = place_context(zones)
    read = json.loads(path.read_text(encoding="utf-8"))["items"]
    out = {}
    for item_id, entry in read.items():
        places, _why = placed(entry, zones, inside, bosses, levels, int(item_id) in sets)
        if places:
            out[int(item_id)] = places
    return out


def only_quest(item):
    """The quest ID when an item's one source is a single known quest, else None."""
    sources, more = item[10] or [], item[11] or []
    if sources == [4] and len(more) == 1 and more[0][1] == 5 and more[0][2]:
        return int(more[0][2])
    return None


# The Barrens' two reputation quartermasters, whose pieces Wowhead lists for both sides: the
# Theramore Expeditionary Force's sells to the Alliance, the Darkspear Raiders' to the Horde.
QUARTERMASTERS = {"Bryanna Embreeze": 1, "Creeg Bothunk": 2}


def quartermaster_side(item):
    """The side whose Barrens quartermaster alone sells `item`, else 0."""
    return sold_by(item, QUARTERMASTERS)


# Warsong Gulch's two quartermasters, each selling to one side only (Wowhead gives their pieces a side
# already): the Silverwing Sentinels' to the Alliance, the Warsong Outriders' to the Horde. Their pieces
# are paired as the Barrens' are, so a WoWSims set's piece from one is the other side's from the other.
GULCH_QUARTERMASTERS = {"Illiyana Moonblaze": 1, "Kelm Hargunth": 2}


def sold_by(item, quartermasters):
    """The side whose quartermaster in `quartermasters` alone sells `item`, else 0."""
    sides = {quartermasters.get(s[0], 0) for s in item[11]} if item[11] else {0}
    return sides.pop() if len(sides) == 1 else 0


def twins(items):
    """Each Horde quartermaster piece and its Alliance twin, "horde:alliance", for the Barrens' pair
    and Warsong Gulch's: the one piece of the other quartermaster of the pair with the same slot,
    kind, quality, levels and classes (by name, past the side's word, where several are alike), and
    only where each is the other's one match: a piece with two or more alike and no name to tell them
    apart, or whose other side's piece isn't in the lists, has no twin."""
    key = lambda x: (x[5], x[6], x[7], x[2], x[4], x[3], str(x[9]))
    words = ("Darkspear ", "Theramore ", "Raider ", "Outrider's ", "Sentinel's ")
    def bare(n):
        for w in words:
            n = n.replace(w, "")
        return n
    def match(x, pool):
        same = [y for y in pool if key(y) == key(x)]
        if len(same) > 1:
            same = [y for y in same if bare(y[1]) == bare(x[1])]
        return same[0] if len(same) == 1 else None
    out = []
    for quartermasters in (QUARTERMASTERS, GULCH_QUARTERMASTERS):
        by = {1: [], 2: []}
        for x in items:
            side = sold_by(x, quartermasters)
            if side:
                by[side].append(x)
        for h in by[2]:
            a = match(h, by[1])
            if a is not None and match(a, by[2]) is h:
                out.append(f"{h[0]}:{a[0]}")
    return ";".join(sorted(out))


def percents(pct):
    """An item's crit and hit given as a percent by an "Equip:" line, which the game's item stats
    leave out, in GearData's short form: "c" a weapon's crit (melee or ranged, the larger), "sc" a
    spell's, "h" and "sh" the same for hit. A percent for both counts for each. "" for none."""
    if not pct:
        return ""
    def larger(*keys):
        return max((pct.get(k, 0) for k in keys), default=0)
    parts = {
        "c": larger("mlecritstrkpct", "rgdcritstrkpct", "critstrkpct"),
        "sc": larger("splcritstrkpct", "critstrkpct"),
        "h": larger("mlehitpct", "rgdhitpct", "hitpct"),
        "sh": larger("splhitpct", "hitpct"),
    }
    return ",".join(f"{k}{v:g}" for k, v in parts.items() if v)


def main():
    global OUT
    args = sys.argv[1:]
    places_file = PLACES
    if "--places" in args:
        places_file = pathlib.Path(args[args.index("--places") + 1])
    if "--out" in args:
        OUT = pathlib.Path(args[args.index("--out") + 1])
    sys.path.insert(0, str(ROOT / "tools"))
    data = json.loads((SRC / "wowhead-items.json").read_text(encoding="utf-8"))
    zones = json.loads((SRC / "zones.json").read_text(encoding="utf-8"))
    dungeons_of = read_places(places_file, zones)
    placed, to_boss, more = 0, 0, {}
    places, place_index = [], {}
    by_slot, quests = {}, {}
    kinds = {"": 0, "Drop": 1, "Quest": 2, "Vendor": 3, "Crafted": 4, "PvP": 5}
    reagents, raid = craft_reagents(), []
    pct, unique = {}, []
    block = {}
    if SHIELDS.exists():
        block = {int(i): v for i, v in json.loads(SHIELDS.read_text(encoding="utf-8"))["block"].items() if v}
    for item in sorted(data["items"], key=lambda i: i[0]):
        item_id, _name, quality, req, ilvl, slot, cls, sub, side, reqclass = item[:10]
        side = side or quartermaster_side(item)
        short = percents(item[12] if len(item) > 12 else None)
        if short:
            pct[item_id] = short
        if len(item) > 13 and item[13]:
            unique.append(item_id)
        kind, place = where(item, zones)
        if kind == "Drop" and place == "" and item_id in dungeons_of:
            place, *others = dungeons_of[item_id]
            placed += 1
            if " · " in place:
                to_boss += 1
            if others:
                more[item_id] = others
        quest = only_quest(item)
        if kind != "Drop" and raid_only(item, reagents):
            raid.append(item_id)
        if quest:
            quests[item_id] = quest
        if place not in place_index:
            place_index[place] = len(places)
            places.append(place)
        by_slot.setdefault(slot, []).append(
            f"{item_id},{req},{ilvl},{cls},{sub},{side},{reqclass},{quality},{kinds[kind]},{place_index[place] + 1}")
    # The other dungeons' places by number; one not already named goes at the end, so no line's moves.
    for item_id, others in more.items():
        for other in others:
            if other not in place_index:
                place_index[other] = len(places)
                places.append(other)
        more[item_id] = [place_index[o] + 1 for o in others]
    rows = [f"[{slot}] = {lua_string(';'.join(entries))}" for slot, entries in sorted(by_slot.items())]
    spec_lines = []
    for class_file, trees in SPECS.items():
        parts = []
        for spec, forever in zip(trees, FOREVER[class_file]):
            if forever and forever[0] == "computed":
                stats, dps = computed_weights(forever[1])
                spec = "forever-computed:" + forever[1]
            elif forever:
                stats, dps = forever_weights(*forever)
                spec = "forever:" + "/".join(forever)
            else:
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
        "    -- Where each item comes from: 0 not known, 1 drop, 2 quest, 3 vendor, 4 crafted, 5 PvP.",
        "    kinds = { [0] = \"\", \"Drop\", \"Quest\", \"Vendor\", \"Crafted\", \"PvP\" },",
        "    -- The places named in sources (a mob and its zone, a quest, a vendor), by number.",
        "    places = { " + ", ".join(lua_string(p) for p in places) + " },",
        "    -- By the game's slot (inventory type): one line of items, each \"item ID, required level,",
        "    -- item level, class, subclass, side (1 Alliance, 2 Horde, 0 both), classes that may use it",
        "    -- (0 all), quality, source kind, place\" and separated by \";\". Kept as text, so the gear",
        "    -- costs little memory until the gear plan is opened and reads the slots it needs.",
        "    items = {",
        "        " + ",\n        ".join(rows),
        "    },",
        "    -- Items whose one source is a quest, \"item ID:quest ID\" separated by \";\": once the quest",
        "    -- is done, its reward can't be had again.",
        "    quests = " + lua_string(";".join(f"{i}:{q}" for i, q in sorted(quests.items()))) + ",",
        "    -- Items got by a quest, a vendor or a craft that need a raid first, separated by \";\".",
        "    raid = " + lua_string(";".join(str(i) for i in sorted(raid))) + ",",
        "    -- The Barrens' and Warsong Gulch's quartermasters' twin pieces, \"Horde:Alliance\", separated by",
        "    -- \";\": a set's piece from the other side's is its twin from yours.",
        "    twins = " + lua_string(twins(data["items"])) + ",",
        "    -- WoWSims Forever's pre-raid sets (its batch sims, MIT): by class, the build each talent tree",
        "    -- starts on (false: none), and each build: the trees it goes with (specs), its set, and its cheap",
        "    -- one, as 17 item IDs in the order head, neck, shoulder, back, chest, wrist, hands, waist, legs,",
        "    -- feet, two fingers, two trinkets, main hand, off hand, ranged (0 for an empty place).",
        "    prebis = {",
        *prebis_lines(data["items"]),
        "    },",
        "    -- Crit and hit an \"Equip:\" line gives as a percent, which the game's item stats leave out:",
        "    -- \"item ID:\" then c (a weapon's crit), sc (a spell's), h and sh (hit) with the percent.",
        "    pct = " + lua_string(";".join(f"{i}:{v}" for i, v in sorted(pct.items()))) + ",",
        "    -- Rings and trinkets that can be worn only once (Unique, or Unique-Equipped), by item ID,",
        "    -- separated by \";\": one is the upgrade of only one place of the pair.",
        "    unique = " + lua_string(";".join(str(i) for i in unique)) + ",",
        "    -- Each shield's own block (\"3 Block\" on its tooltip), which the game's item stats leave out,",
        "    -- \"item ID:block\" separated by \";\": every shield the game has, white ones too, from Wowhead.",
        "    block = " + lua_string(";".join(f"{i}:{v}" for i, v in sorted(block.items()))) + ",",
        *([
            "    -- A drop's other dungeons, past the one place in its line (the dungeon where it drops most):",
            "    -- \"item ID:\" then places by number, separated by \",\"; items by \";\". For the Dungeon guide's Trash card.",
            "    more = " + lua_string(";".join(f"{i}:" + ",".join(str(n) for n in ns) for i, ns in sorted(more.items()))) + ",",
        ] if more else []),
        "    -- Each class's talent trees, in order: what one point of each stat is worth.",
        "    specs = {",
        *spec_lines,
        "    },",
        "}",
    ]
    OUT.parent.mkdir(exist_ok=True)
    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    print(f"{sum(len(v) for v in by_slot.values())} items in {len(rows)} slots, {len(places)} places, {len(quests)} quest rewards, {len(pct)} with a percent, {len(unique)} unique, {len(block)} shields' block ->{OUT.name} ({OUT.stat().st_size // 1024} KB)")
    if dungeons_of:
        print(f"{placed} drops placed in a dungeon from {places_file.name} ({to_boss} on a boss), {len(more)} in more than one")


if __name__ == "__main__":
    main()
