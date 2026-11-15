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
(hunter, mage, warlock, and the paladin, shaman and druid healers), it's WoWSims Classic's
(data/gear/wowsims/*.sim.ts, github.com/wowsims/classic, MIT). (John, 14 Nov 2026, after the three
were set side by side with GearQuest's: "Yes, use Forever's".) Both are tuned for level 60, where
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
tank's, the other plate tank's. (John, 14 Nov 2026:
"if someone does value stamina like a tank will it show it properly, but also not overvalue stamina
for dps classes"; "lets keep it as universal as possible".)

Run: python -I tools/build_gear.py
"""

import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "data" / "gear"
OUT = ROOT / "jsalUI" / "Gear" / "GearData.lua"

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
PLATE_TANK = ("warrior_protection", "PreBiSEpWeights")
FOREVER = {
    "WARRIOR": [("warrior_dps", "PreBiSArmsEpWeights"), ("warrior_dps", "PreBiSFuryEpWeights"), PLATE_TANK],
    "PALADIN": [None, PLATE_TANK, ("paladin_retribution", "UnsealedWrathEpWeights")],
    "HUNTER": [("computed", "hunter"), ("computed", "hunter"), ("computed", "hunter")],
    "ROGUE": [("rogue_dps", "EP_PRESET_ASSASSINATION"), ("rogue_dps", "EP_PRESET_COMBAT_SINISTER"),
              ("rogue_dps", "EP_PRESET_SUBTLETY")],
    "PRIEST": [("priest_healer", "DiscSingleTargetEpWeights"), ("priest_healer", "HolySingleTargetEpWeights"),
               ("priest_dps", "ShadowEpWeights")],
    "SHAMAN": [("shaman_elemental", "DefaultEpWeights"), ("shaman_enhancement", "PreBiSEpWeights"), None],
    "MAGE": [("computed", "mage_arcane"), ("computed", "mage_fire"), ("computed", "mage_frost")],
    "WARLOCK": [("computed", "warlock_affliction"), ("computed", "warlock_demonology"), ("computed", "warlock_destruction")],
    "DRUID": [("druid_balance", "PreBiSEpWeights"), ("druid_feral_ep", "CatEp"), None],
}
# Trees WoWSims Forever ships no weights for, worked out with its own Stat Weights tool on its own
# preset talents and gear (data/gear/wowsims-forever/computed/*.json, each saying how). Rows are per 1%
# for crit and hit, as the tool shows them. (John, 14 Nov 2026: "i feel we should be accurate as this
# dictates what a player will want to roll for".)
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
}
COMPUTED_DPS = {"Main Hand DPS": "mh", "Off Hand DPS": "oh", "Ranged DPS": "ranged"}

# Forever's ratings for 1% (its sim/core/base_stats_auto_gen.go); defense is 1 rating a point.
RATING_PER_PERCENT = {"StatHitRating": 10, "StatCritRating": 14, "StatDodgeRating": 12, "StatParryRating": 15,
                      "StatBlockRating": 5, "StatDefenseRating": 1}
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


def only_quest(item):
    """The quest ID when an item's one source is a single known quest, else None."""
    sources, more = item[10] or [], item[11] or []
    if sources == [4] and len(more) == 1 and more[0][1] == 5 and more[0][2]:
        return int(more[0][2])
    return None


def main():
    data = json.loads((SRC / "wowhead-items.json").read_text(encoding="utf-8"))
    zones = json.loads((SRC / "zones.json").read_text(encoding="utf-8"))
    places, place_index = [], {}
    by_slot, quests = {}, {}
    kinds = {"": 0, "Drop": 1, "Quest": 2, "Vendor": 3, "Crafted": 4}
    for item in sorted(data["items"], key=lambda i: i[0]):
        item_id, _name, quality, req, ilvl, slot, cls, sub, side, reqclass = item[:10]
        kind, place = where(item, zones)
        quest = only_quest(item)
        if quest:
            quests[item_id] = quest
        if place not in place_index:
            place_index[place] = len(places)
            places.append(place)
        by_slot.setdefault(slot, []).append(
            f"{item_id},{req},{ilvl},{cls},{sub},{side},{reqclass},{quality},{kinds[kind]},{place_index[place] + 1}")
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
        "    -- Items whose one source is a quest, \"item ID:quest ID\" separated by \";\": once the quest",
        "    -- is done, its reward can't be had again.",
        "    quests = " + lua_string(";".join(f"{i}:{q}" for i, q in sorted(quests.items()))) + ",",
        "    -- Each class's talent trees, in order: what one point of each stat is worth.",
        "    specs = {",
        *spec_lines,
        "    },",
        "}",
    ]
    OUT.parent.mkdir(exist_ok=True)
    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    print(f"{sum(len(v) for v in by_slot.values())} items in {len(rows)} slots, {len(places)} places, {len(quests)} quest rewards ->{OUT.relative_to(ROOT)} ({OUT.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
