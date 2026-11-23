"""Builds jsalUI/Endgame/ConsumablesData.lua: WoWSims Forever's consumables for each spec, for the
Endgame page's RAID NIGHT card.

From WoWSims Forever (github.com/wowsims/forever, MIT) at the commit in
data/gear/wowsims-forever/consumables/COMMIT: each spec's `consumables:` in its defaults.siml, else
its presets.ts's DefaultConsumables (with what it spreads in from another preset), else the
`player.consumables` of its builds/default.build.json, and the item IDs in consumables_auto_gen.ts. A set of the At 60 view whose presets have their own list (the Arms
warrior's ArmsConsumables) gets that one.

How long each lasts is the game's own (data/spells and data/professions, as CSV from wago.tools):
the item's use spell (ItemXItemEffect, ItemEffect) and the aura it puts on you (SpellMisc's
DurationIndex, SpellDuration), or the aura a spell it sets off puts on you (a food's Well Fed,
through SpellEffect's EffectTriggerSpell), or a weapon stone's or oil's (SpellEffect 54, its
seconds in EffectBasePointsF). A potion, a rune and an explosive, and anything lasting under two
minutes, are used in the moment: 0.

Run: python -I tools/build_consumables.py
"""

import csv
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "data" / "gear" / "wowsims-forever" / "consumables"
SPELLS = ROOT / "data" / "spells"
PROF = ROOT / "data" / "professions"
OUT = ROOT / "jsalUI" / "Endgame" / "ConsumablesData.lua"

# WoWSims' spec folder for each class's talent trees, in the game's order (None: it has none).
TREES = {
    "WARRIOR": ["warrior/dps", "warrior/dps", "warrior/protection"],
    "PALADIN": ["paladin/holy", "paladin/protection", "paladin/retribution"],
    "HUNTER": ["hunter/dps", "hunter/dps", "hunter/dps"],
    "ROGUE": ["rogue/dps", "rogue/dps", "rogue/dps"],
    "PRIEST": ["priest/healer", "priest/healer", "priest/dps"],
    "SHAMAN": ["shaman/elemental", "shaman/enhancement", "shaman/restoration"],
    "MAGE": ["mage/dps", "mage/dps", "mage/dps"],
    "WARLOCK": ["warlock/dps", "warlock/dps", "warlock/dps"],
    "DRUID": ["druid/balance", "druid/feralcat", "druid/restoration"],
}
# And for each At 60 set (GearData.prebis), the spec folder its sims are in.
SETS = {
    "HUNTER": {"weave": "hunter/dps", "turret": "hunter/dps", "melee": "hunter/dps"},
    "MAGE": {"arcane": "mage/dps", "fire": "mage/dps", "frost": "mage/dps"},
    "WARLOCK": {"preraid": "warlock/dps"},
    "WARRIOR": {"arms": "warrior/dps", "fury": "warrior/dps", "offensive": "warrior/protection", "balanced": "warrior/protection"},
    "DRUID": {"balance": "druid/balance", "feral": "druid/feralcat"},
    "PRIEST": {"healer": "priest/healer"},
}
# The kinds, in the order a list is shown, from WoWSims' fields.
KINDS = [("flask", "flask"), ("elixir", "elixir"), ("food", "food"), ("mh_imbue", "weapon"), ("oh_imbue", "weapon"),
         ("mh_weapon_imbue", "weapon"), ("oh_weapon_imbue", "weapon"), ("swap_mh_imbue", "weapon"),
         ("resource_pot", "potion"), ("offensive_pot", "potion"), ("defensive_pot", "potion"),
         ("conjured", "rune"), ("explosive", "explosive"), ("extra", "extra")]
MOMENT = {"potion", "rune", "explosive"}
SHORT = 120


def rows(path):
    with open(path, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def norm(name):
    return re.sub(r"[^a-z0-9]", "", name.lower())


def snake(field):
    """flaskId -> flask, elixirIds -> elixir, mhWeaponImbueId -> mh_weapon_imbue."""
    field = re.sub(r"Ids?$", "", field)
    return re.sub(r"([A-Z])", lambda m: "_" + m.group(1).lower(), field)


def auto_gen():
    ids = {}
    for name, item in re.findall(r"export const (\w+) = \{ id: (\d+) \}", (SRC / "consumables_auto_gen.ts").read_text(encoding="utf-8")):
        ids[name] = int(item)
        ids[norm(name)] = int(item)
    return ids


def siml_list(path, ids):
    text = path.read_text(encoding="utf-8")
    m = re.search(r"^consumables:\n((?:[ \t]+.*\n?)+)", text, re.M)
    if not m:
        return None
    out, kind = [], None
    for line in m.group(1).splitlines():
        if not line.strip():
            continue
        words = line.strip()
        head = re.match(r"^([a-z_]+)\s+(.*)$", words) if not line.startswith("      ") else None
        if head and head.group(1) in dict(KINDS):
            kind, words = head.group(1), head.group(2)
        for name in words.split(","):
            name = name.strip()
            if name:
                out.append((kind, ids[norm(name)]))
    order = [k for k, _ in KINDS]
    return sorted(out, key=lambda pair: order.index(pair[0]))


def ts_objects(path, ids, files):
    """Every `export const X = ConsumesSpec.create({...})` in a presets.ts, as {X: [(kind, item)]}."""
    text = path.read_text(encoding="utf-8")
    aliases = {a: b for a, b in re.findall(r"import \* as (\w+) from '\.\./(\w+)/presets'", text)}
    spec = path.name.split("_")[0]
    objects = {}
    for name, body in re.findall(r"export const (\w+) = ConsumesSpec\.create\(\{(.*?)\}\);", text, re.S):
        fields = {}
        # A list WoWSims writes across lines (`elixirIds: [` with one item a line) is read as one line,
        # or its items would be missed.
        body = re.sub(r"\[[^\]]*\]", lambda m: " ".join(m.group(0).split()), body)
        for line in body.splitlines():
            line = line.strip().rstrip(",")
            spread = re.match(r"^\.\.\.(?:(\w+)\.)?(\w+)$", line)
            if spread:
                alias, other = spread.groups()
                source = objects if not alias else ts_objects(files[f"{spec}/{aliases[alias]}"], ids, files)
                for kind, items in source[other]["fields"].items():
                    fields[kind] = list(items)
                continue
            field = re.match(r"^(\w+):\s*(.*)$", line)
            if not field:
                continue
            kind = snake(field.group(1))
            found = [ids[n] for n in re.findall(r"Consumables\.(\w+)\.id", field.group(2))]
            fields[kind] = found
        objects[name] = {"fields": fields}
    for o in objects.values():
        o["list"] = [(kind, item) for kind, _ in KINDS for item in o["fields"].get(kind, [])]
    return objects


def build_list(path):
    """A build file's `player.consumables` (flaskId, elixirIds...), as [(kind, item)] in KINDS' order. Its
    `potions` and `conjuredItems` are what the sim can choose from, not what the build uses: they're no kind."""
    chosen = json.loads(path.read_text(encoding="utf-8")).get("player", {}).get("consumables") or {}
    fields = {}
    for field, value in chosen.items():
        items = value if isinstance(value, list) else [value]
        fields[snake(field)] = [int(i) for i in items if isinstance(i, int) and i > 0]
    return [(kind, item) for kind, _ in KINDS for item in fields.get(kind, [])]


def durations():
    seconds = {int(r["ID"]): int(r["Duration"]) // 1000 for r in rows(SPELLS / "SpellDuration.csv")}
    aura = {int(r["SpellID"]): seconds.get(int(r["DurationIndex"]), 0) for r in rows(SPELLS / "SpellMisc.csv") if r["DifficultyID"] == "0"}
    effects = {}
    for r in rows(PROF / "SpellEffect.csv"):
        if r["DifficultyID"] == "0":
            effects.setdefault(int(r["SpellID"]), []).append(r)
    effect_item = {int(r["ItemEffectID"]): int(r["ItemID"]) for r in rows(PROF / "ItemXItemEffect.csv")}
    item_spells = {}
    for r in rows(PROF / "ItemEffect.csv"):
        item = effect_item.get(int(r["ID"]))
        if item:
            item_spells.setdefault(item, []).append(int(r["SpellID"]))

    def spell_lasts(spell, depth=0):
        best = aura.get(spell, 0) if any(e["Effect"] == "6" for e in effects.get(spell, [])) else 0
        for e in effects.get(spell, []):
            if e["Effect"] == "54":
                best = max(best, int(float(e["EffectBasePointsF"] or 0)))
            trigger = int(e["EffectTriggerSpell"] or 0)
            if trigger and depth < 2:
                best = max(best, spell_lasts(trigger, depth + 1))
        return best

    def lasts(item):
        spells = item_spells.get(item)
        if not spells:
            return None
        return max(spell_lasts(s) for s in spells)
    return lasts


def main():
    ids = auto_gen()
    names = {int(r["ID"]): r["Display_lang"] for r in rows(PROF / "ItemSparse.csv")}
    lasts = durations()
    files = {}
    for path in SRC.glob("*_presets.ts"):
        cls, spec = path.name.split("_")[:2]
        files[f"{cls}/{spec}"] = path
    lists, problems = {}, []

    def ship(key, items):
        out, seen = [], set()
        for kind, item in items:
            if item in seen:
                continue
            seen.add(item)
            group = dict(KINDS)[kind]
            seconds = lasts(item)
            if seconds is None:
                problems.append(f"{key}: no use spell for {item} {names.get(item)}")
                seconds = 0
            if group in MOMENT or seconds < SHORT:
                seconds = 0
            out.append((item, group, seconds))
        lists[key] = out

    specs = sorted({s for trees in TREES.values() for s in trees})
    for spec in specs:
        cls, name = spec.split("/")
        siml = SRC / f"{cls}_{name}_defaults.siml"
        found = siml_list(siml, ids) if siml.exists() else None
        objects = ts_objects(files[spec], ids, files) if spec in files else {}
        if found:
            ship(spec, found)
        elif "DefaultConsumables" in objects:
            ship(spec, objects["DefaultConsumables"]["list"])
        elif (SRC / f"{cls}_{name}_default.build.json").exists():
            ship(spec, build_list(SRC / f"{cls}_{name}_default.build.json"))
        for cls_file, sets in SETS.items():
            for set_key, set_spec in sets.items():
                own = objects.get(set_key.capitalize() + "Consumables")
                if set_spec == spec and own:
                    ship(f"{spec}:{set_key}", own["list"])
    for p in problems:
        print("  !", p)

    lines = [
        "-- WoWSims Forever's consumables for each spec (github.com/wowsims/forever, MIT), for the",
        "-- Endgame page's RAID NIGHT card; how long each lasts from the game's own tables. Regenerated",
        "-- by tools/build_consumables.py, not by hand.",
        "local _, ns = ...",
        "",
        "-- `lists`: by WoWSims' spec, each consumable as { item, kind, seconds it lasts (0: used in the",
        "-- moment) }. `trees`: by class, the spec of each talent tree; `sets`: of each At 60 set, a",
        "-- list of its own where its sims have one. A spec with no list here has none from WoWSims.",
        "ns.ConsumablesData = {",
        "    lists = {",
    ]
    for key in sorted(lists):
        lines.append(f'        ["{key}"] = {{')
        for item, group, seconds in lists[key]:
            lines.append(f'            {{ {item}, "{group}", {seconds} }},   -- {names.get(item, "?")}')
        lines.append("        },")
    lines.append("    },")
    lines.append("    trees = {")
    for cls in TREES:
        lines.append(f"        {cls} = {{ " + ", ".join(f'"{s}"' for s in TREES[cls]) + " },")
    lines.append("    },")
    lines.append("    sets = {")
    for cls, sets in SETS.items():
        parts = []
        for set_key, spec in sets.items():
            parts.append(f'{set_key} = "{spec}:{set_key}"' if f"{spec}:{set_key}" in lists else f'{set_key} = "{spec}"')
        lines.append(f"        {cls} = {{ " + ", ".join(parts) + " },")
    lines += ["    },", "}", ""]
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(lines), encoding="utf-8", newline="\n")
    print(f"-> {OUT.relative_to(ROOT)}: {len(lists)} lists")
    for key in sorted(lists):
        print(f"  {key}: {len(lists[key])}")
    print("  no list: " + ", ".join(s for s in specs if s not in lists))


if __name__ == "__main__":
    main()
