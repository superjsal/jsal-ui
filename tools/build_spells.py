"""Builds jsalUI/Training/SpellData.lua: every class's trainer spells by level.

The tables come from the game's files for the Forever build jsal.ui targets,
as CSV (https://wago.tools/db2/<Table>/csv?build=<version>), in data/spells/:
  SkillLine, SkillRaceClassInfo   which spell schools and weapon skills each
                                  class has
  SkillLineAbility                each school's spells, and how they're
                                  learned (0 = from a trainer)
  SpellLevels                     the level each spell (each rank) needs
  SpellName                       names, only to leave out unnamed spells
and data/talents/ for the talent spells, which come from talents instead.
Prices aren't in the files: the game's trainers give them, and the addon
saves them when a trainer opens. tools/bake_prices.py copies those visits to
data/prices/trainers.json, and they ship in SpellData.lua from there.

Run: python -I tools/build_spells.py 1.60.1.70790
"""

import csv
import json
import pathlib
import re
import sys
from collections import defaultdict

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "data" / "spells"
TALENTS = ROOT / "data" / "talents"
OUT = ROOT / "jsalUI" / "Training" / "SpellData.lua"
PRICES = ROOT / "data" / "prices" / "trainers.json"   # from tools/bake_prices.py

CLASS_SCHOOLS = "7"       # SkillLine category: a class's spell schools
WEAPONS = "6"             # SkillLine category: weapon skills
FROM_TRAINER = "0"        # SkillLineAbility.AcquireMethod: taught by a trainer
PET_TRAINING = 261        # a hunter's pet abilities, taught by pet trainers
NOT_WEAPONS = {95, 118, 162}   # Defense, Dual Wield, Unarmed: not weapons to learn


DEMONS_FOR, DEMON_LINES = {9}, [188, 204, 205, 189, 2887]   # Imp, Voidwalker, Succubus, Felhunter, Felguard
BEAST_FOR = {3}


def Trainable(abilities, names, ranks, levels):
    """A skill line's spells taught at a trainer, one per name and rank (the
    lowest ID), as (level, spell) pairs in level order."""
    chosen = {}
    for r in sorted(abilities, key=lambda r: int(r["Spell"])):
        spell = int(r["Spell"])
        if r["AcquireMethod"] != FROM_TRAINER or not names.get(spell) or levels.get(spell, 0) < 1:
            continue
        key = (names[spell], ranks.get(spell, ""))
        if key not in chosen:
            chosen[key] = (levels[spell], spell)
    return sorted(chosen.values())


SAVED = json.loads(PRICES.read_text(encoding="utf-8")) if PRICES.exists() else {"trainers": [], "grimoires": []}


def ShippedPrices(lines, class_id, spell_ids, weapon_ids, pet_to_beast):
    """Writes the prices seen at this class's trainers in game (from
    data/prices/trainers.json): class spells by spell ID, anything else a
    class trainer teaches (Parry, Plate Mail...), weapon skills, a hunter's
    pet trainer (which lists the pet's spells; kept under the Beast Training
    spell that teaches each) and a warlock's Grimoires. Returns how many of
    the class's spells have a price."""
    spells, extra, weapons, pet = {}, {}, {}, {}
    # Weapon skills cost the same at every weapon master, for every class,
    # so any class's visit prices them.
    for trainer in SAVED["trainers"]:
        for r in trainer["rows"]:
            if r.get("spell") in weapon_ids:
                weapons[r["spell"]] = r["cost"]
    for trainer in SAVED["trainers"]:
        if trainer["class"] != class_id:
            continue
        rows = [r for r in trainer["rows"] if r.get("spell")]
        if any(r["spell"] in spell_ids for r in rows):
            for r in rows:
                spells[r["spell"]] = r["cost"]
                if r["spell"] not in spell_ids:
                    extra[r["spell"]] = r.get("level") or 1
        else:
            for r in rows:
                if r["spell"] in pet_to_beast:
                    pet[pet_to_beast[r["spell"]]] = (r["cost"], r.get("level") or 1)
    if extra:
        lines.append("        extra = { " + ", ".join(f"{{ {s}, {l} }}" for s, l in sorted(extra.items(), key=lambda kv: (kv[1], kv[0]))) + " },")
    grimoires = {}
    for shop in SAVED["grimoires"]:
        if shop["class"] == class_id:
            for r in shop["rows"]:
                m = re.match(r"^Grimoire of (.+?)(?: \(Rank (\d+)\))?$", r.get("name") or "")
                if m:
                    grimoires[f"{m.group(1)}|{m.group(2) or ''}"] = r["cost"]
    if spells:
        lines.append("        prices = { " + ", ".join(f"[{s}] = {c}" for s, c in sorted(spells.items())) + " },")
    if weapons:
        lines.append("        weaponPrices = { " + ", ".join(f"[{s}] = {c}" for s, c in sorted(weapons.items())) + " },")
    if pet:
        lines.append("        petTrainer = { " + ", ".join(f"[{s}] = {{ {c}, {l} }}" for s, (c, l) in sorted(pet.items())) + " },")
    if grimoires:
        lines.append("        grimoires = { " + ", ".join(f'["{k}"] = {c}' for k, c in sorted(grimoires.items())) + " },")
    return len(spell_ids & set(spells))


# Class spells no trainer sells, and where they come from instead. Quests are
# the class quests players know from Classic, kept only where Forever's
# trainers don't sell the spell either; books are the Dire Maul books. Any
# other level 60 rank no trainer sells, of a spell trainers do sell, is a
# book too. A mage's teleports and portals come from a portal trainer.
QUESTS = {
    1: ["Defensive Stance", "Taunt", "Sunder Armor|Rank 1", "Berserker Stance", "Intercept|Rank 1"],
    2: ["Redemption|Rank 1"],
    3: ["Tame Beast", "Call Pet", "Dismiss Pet", "Feed Pet", "Revive Pet"],
    7: ["Stoneskin Totem|Rank 1", "Searing Totem|Rank 1", "Healing Stream Totem|Rank 1"],
    9: ["Summon Voidwalker", "Summon Succubus", "Summon Felhunter", "Inferno"],
    11: ["Bear Form", "Growl", "Maul|Rank 1", "Cure Poison", "Aquatic Form"],
}
BOOKS = {
    5: ["Prayer of Shadow Protection"],
    8: ["Arcane Brilliance"],
    11: ["Gift of the Wild|Rank 1"],
}


def Elsewhere(class_id, spells, names, ranks, taught_by_trainer):
    """{spell: "quest" | "book" | "portal"} for this class's spells that
    come from somewhere other than its class trainer."""
    out = {}
    if not taught_by_trainer:
        return out
    sold_names = {names.get(s) for s in taught_by_trainer}

    def Key(spell):
        return names.get(spell, ""), ranks.get(spell, "")

    def Listed(entries, spell):
        name, rank = Key(spell)
        return name in entries or f"{name}|{rank}" in entries

    for level, spell, _, _ in spells:
        if spell in taught_by_trainer:
            continue
        name, rank = Key(spell)
        if Listed(QUESTS.get(class_id, []), spell):
            out[spell] = "quest"
        elif Listed(BOOKS.get(class_id, []), spell):
            out[spell] = "book"
        elif level >= 60 and name in sold_names and "Passive" not in rank:
            out[spell] = "book"
        elif class_id == 8 and (name.startswith("Teleport: ") or name.startswith("Portal: ")) and "Dalaran" not in name:
            out[spell] = "portal"
    return out


def RankNumber(ranks, spell):
    """3 for a spell whose rank reads "Rank 3"; 0 for one with no rank."""
    text = ranks.get(spell, "").replace("Rank ", "")
    return int(text) if text.isdigit() else 0


def rows(folder, name):
    with open(folder / f"{name}.csv", newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def main():
    build = sys.argv[1] if len(sys.argv) > 1 else "unknown"
    skills = {int(r["ID"]): r for r in rows(SRC, "SkillLine")}
    names = {int(r["ID"]): r["Name_lang"] for r in rows(SRC, "SpellName")}
    # The level a spell is learned at is SpellLevel; some spells only have
    # BaseLevel filled in.
    levels = {int(r["SpellID"]): int(r["SpellLevel"]) or int(r["BaseLevel"])
              for r in rows(SRC, "SpellLevels") if r["DifficultyID"] == "0"}
    ranks = {int(r["ID"]): r["NameSubtext_lang"] for r in rows(SRC, "Spell")}

    # Spells that come from talents, not trainers (a talent's first rank).
    talent_spells = {int(r["SpellID"]) for r in rows(TALENTS, "TraitDefinition")}

    # Which school and weapon skill lines belong to which class: a school
    # counts only when it's that class's alone.
    schools, weapons = defaultdict(list), defaultdict(list)
    for r in rows(SRC, "SkillRaceClassInfo"):
        skill = int(r["SkillID"])
        mask = int(r["ClassMask"])
        line = skills.get(skill)
        if not line or mask <= 0:
            continue
        if line["CategoryID"] == CLASS_SCHOOLS and mask & (mask - 1) == 0 and skill != PET_TRAINING:
            schools[mask.bit_length()].append(skill)
        elif line["CategoryID"] == WEAPONS and skill not in NOT_WEAPONS:
            for class_id in range(1, 13):
                if mask & (1 << (class_id - 1)):
                    weapons[class_id].append(skill)

    abilities = rows(SRC, "SkillLineAbility")
    by_line = defaultdict(list)
    for r in abilities:
        by_line[int(r["SkillLine"])].append(r)

    lines = [
        "-- Every class's trainer spells, rank by rank, with the level each needs, its",
        "-- spell school and, for a race-only spell, the races' bits (0 for all);",
        f"-- and the weapon skills each class can learn. From the game's",
        f"-- own spell tables (build {build}); regenerated by the build, not by hand.",
        "-- Prices aren't in the game's files: the ones here were seen at trainers in",
        "-- game, and the addon adds any trainer it opens.",
        "local _, ns = ...",
        "",
        "ns.SpellData = {",
    ]
    report = []
    for class_id in sorted(schools):
        school_ids = sorted(set(schools[class_id]))
        class_bit = 1 << (class_id - 1)
        # One spell per name and rank: where two share both (a trap and its
        # effect, say), the lower ID is the one taught.
        chosen = {}
        for index, school in enumerate(school_ids, start=1):
            for r in sorted(by_line[school], key=lambda r: int(r["Spell"])):
                spell = int(r["Spell"])
                mask = int(r["ClassMask"])
                if (r["AcquireMethod"] != FROM_TRAINER or spell in talent_spells
                        or not names.get(spell) or levels.get(spell, 0) < 1 or (mask and not mask & class_bit)):
                    continue
                key = (names[spell], ranks.get(spell, ""))
                # Race-only spells (Starshards, Touch of Weakness...) carry a
                # race mask; 0 or -1 means every race.
                race = int(r["RaceMasks_0"])
                race = 0 if race <= 0 else race
                if key not in chosen or spell < chosen[key][1]:
                    chosen[key] = (levels[spell], spell, index, race)
        spells = list(chosen.values())
        spells.sort()
        weapon_spells = []
        for skill in sorted(set(weapons[class_id])):
            teach = [int(r["Spell"]) for r in by_line[skill] if names.get(int(r["Spell"])) and r["AcquireMethod"] == "2"]
            if teach:
                weapon_spells.append(teach[0])
        school_names = ", ".join(f'"{skills[s]["DisplayName_lang"]}"' for s in school_ids)
        lines.append(f"    [{class_id}] = {{")
        lines.append(f"        schools = {{ {school_names} }},")
        lines.append("        spells = {")
        for level, spell, school, race in spells:
            lines.append(f"            {{ {spell}, {level}, {school}, {race} }},")
        lines.append("        },")
        lines.append(f"        weapons = {{ {', '.join(str(w) for w in weapon_spells)} }},")
        pet_to_beast = {}
        # A warlock's demons: each one's trainable abilities, rank by rank,
        # taught by Grimoires from a demon trainer.
        if class_id in DEMONS_FOR:
            lines.append("        demons = {")
            for line_id in DEMON_LINES:
                taught = Trainable(by_line[line_id], names, ranks, levels)
                if taught:
                    demon = skills[line_id]["DisplayName_lang"].replace("Pet - ", "")
                    lines.append(f'            {{ name = "{demon}", spells = {{ ' +
                                 ", ".join(f"{{ {s}, {l} }}" for l, s in taught) + " } },")
            lines.append("        },")
        # A hunter's Beast Training: every pet ability and rank. Most come from
        # taming, so only those a pet trainer lists are shown; this names them.
        if class_id in BEAST_FOR:
            taught = Trainable(by_line[PET_TRAINING], names, ranks, levels)
            lines.append("        beast = { " + ", ".join(f"{{ {s}, {l} }}" for l, s in taught) + " },")
            # What each pet family can learn: the pet's own spell, the Beast
            # Training spell that teaches it, the pet level it needs and its rank.
            # "*" is what every family can learn.
            beast_by_key = {(names[s], ranks.get(s, "")): s for _, s in taught}
            # Some families have more than one skill line, so they're merged.
            families = defaultdict(dict)
            for line_id, line in skills.items():
                label = line["DisplayName_lang"]
                if line["CategoryID"] != CLASS_SCHOOLS or not label.startswith("Pet - ") or line_id in DEMON_LINES:
                    continue
                family = "*" if label == "Pet - Generic" else label.replace("Pet - ", "")
                for level, spell in Trainable(by_line[line_id], names, ranks, levels):
                    beast = beast_by_key.get((names[spell], ranks.get(spell, "")))
                    if beast:
                        families[family][spell] = (level, beast)
                        pet_to_beast[spell] = beast
            lines.append("        families = {")
            for family in sorted(families):
                learn = sorted((level, spell, beast) for spell, (level, beast) in families[family].items())
                lines.append(f'            ["{family}"] = {{ ' +
                             ", ".join(f"{{ {s}, {b}, {l}, {RankNumber(ranks, s)} }}" for l, s, b in learn) + " },")
            lines.append("        },")
        priced = ShippedPrices(lines, class_id, {s for _, s, _, _ in spells}, set(weapon_spells), pet_to_beast)
        spell_ids = {s for _, s, _, _ in spells}
        taught = set()
        for trainer in SAVED["trainers"]:
            ids = {r["spell"] for r in trainer["rows"] if r.get("spell")}
            if trainer["class"] == class_id and ids & spell_ids:
                taught |= ids
        elsewhere = Elsewhere(class_id, spells, names, ranks, taught)
        if elsewhere:
            lines.append("        elsewhere = { " + ", ".join(f'[{s}] = "{k}"' for s, k in sorted(elsewhere.items())) + " },")
        lines.append("    },")
        report.append(f"class {class_id}: {len(spells)} spells ({priced} priced), {len(weapon_spells)} weapon skills, schools {school_names}")
    lines += ["}", ""]
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(lines), encoding="utf-8", newline="\n")
    print(f"-> {OUT.relative_to(ROOT)}")
    for line in report:
        print("  " + line)


if __name__ == "__main__":
    main()
