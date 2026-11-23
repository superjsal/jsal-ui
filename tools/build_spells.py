"""Builds jsalUI/Training/SpellData.lua: every class's trainer spells by level.

The tables come from the game's files for the Forever build jsal.ui targets,
as CSV (https://wago.tools/db2/<Table>/csv?build=<version>), in data/spells/:
  SkillLine, SkillRaceClassInfo   which spell schools and weapon skills each
                                  class has
  SkillLineAbility                each school's spells, and how they're
                                  learned (0 = from a trainer)
  SpellLevels                     the level each spell (each rank) needs
  SpellName                       names, only to leave out unnamed spells
  CreatureFamily                  each hunter pet family's ID, its name and
                                  skill line: the game names a pet's family
                                  in the client's language, and gives its ID
  ItemXItemEffect, ItemEffect,    which book teaches a warlock's demon which
  SpellEffect                     ability: the item's spell, and the spell
                                  that one teaches (SpellEffect is kept to
                                  the effects that teach a spell)
and data/talents/ for the talent spells, which come from talents instead.
A talent ability's later ranks are sold by trainers, but only to someone who
has the talent: each class's `talent` table names those, with the talent's
own spells.
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
# Every trainer players opened on Forever, from EG Link (data from Efficient Games,
# https://efficient.games, CC BY 4.0; tools/refresh_eglink.py keeps it): each service's spell and
# its cost at each standing seen. It prices what the saved visits don't reach.
EGLINK = ROOT / "data" / "trainers" / "eglink-trainers.json"
SEEN_BY_OTHERS = json.loads(EGLINK.read_text(encoding="utf-8"))["trainers"] if EGLINK.exists() else {}


# Every spell seen for sale at a trainer, in the saved visits or other players'.
SOLD = {r["spell"] for t in SAVED["trainers"] for r in t["rows"] if r.get("spell")}
SOLD |= {int(spell) for t in SEEN_BY_OTHERS.values() for spell in (t.get("services") or {})}


def others_price(service):
    """A service's full price in EG Link's data. Costs are kept by the standing they were seen at
    (4 Neutral to 8 Exalted). Neutral and Friendly pay the full price (442 services seen at both:
    the same to the copper) and Honored pays nine tenths of it (884 seen at both: 0.9, bar three).
    So: the cost at Neutral or Friendly; else the Honored cost over 0.9; else None, as what
    Revered and Exalted pay hasn't been seen beside a full price."""
    costs = {int(k): c for k, c in (service.get("costs") or {}).items() if isinstance(c, (int, float)) and c > 0}
    full = [c for standing, c in costs.items() if standing <= 5]
    if full:
        return int(max(full))
    if 6 in costs:
        return int(round(costs[6] / 0.9))
    return None


def GrimoireItems(demon_spells):
    """{item: demon spell} for every book whose use teaches a demon one of its abilities: the item's
    spell (ItemXItemEffect, ItemEffect), and the spell that one teaches (SpellEffect, effect 36). A
    vendor's Grimoire is known by its item this way, whatever language the client names it in."""
    item_spell = {int(r["ID"]): int(r["SpellID"]) for r in rows(SRC, "ItemEffect")}
    teaches = {int(r["SpellID"]): int(r["EffectTriggerSpell"]) for r in rows(SRC, "SpellEffect")}
    out = {}
    for r in rows(SRC, "ItemXItemEffect"):
        spell = teaches.get(item_spell.get(int(r["ItemEffectID"])))
        if spell in demon_spells:
            out[int(r["ItemID"])] = spell
    return out


def ShippedPrices(lines, class_id, spell_ids, weapon_ids, pet_to_beast, by_key=None, demon_by_key=None):
    """Writes the prices seen at this class's trainers in game (from
    data/prices/trainers.json): class spells by spell ID, anything else a
    class trainer teaches (Parry, Plate Mail...), weapon skills, a hunter's
    pet trainer (which lists the pet's spells; kept under the Beast Training
    spell (kept under the Beast Training
    spell that teaches each) and a warlock's Grimoires, by the demon's spell
    each teaches. Returns how many of the class's spells have a price."""
    spells, extra, weapons, pet = {}, {}, {}, {}
    # A trainer charges less the better your standing with its faction, so
    # the same spell is saved at several prices. The highest seen is the
    # full price, and that's the one shipped. Levels come from the newest
    # visit that gives one: a row for a rank already bought ("used") comes
    # with level 0, and must not replace a level another visit saw.
    def full(prices, spell, cost):
        prices[spell] = max(cost, prices.get(spell, 0))
    trainers = sorted(SAVED["trainers"], key=lambda t: t.get("seen") or 0)
    # Weapon skills cost the same at every weapon master, for every class,
    # so any class's visit prices them.
    for trainer in trainers:
        for r in trainer["rows"]:
            if r.get("spell") in weapon_ids:
                full(weapons, r["spell"], r["cost"])
    for trainer in trainers:
        if trainer["class"] != class_id:
            continue
        rows = [r for r in trainer["rows"] if r.get("spell")]
        if any(r["spell"] in spell_ids for r in rows):
            for r in rows:
                full(spells, r["spell"], r["cost"])
                if r["spell"] not in spell_ids:
                    extra[r["spell"]] = r.get("level") or extra.get(r["spell"], 1)
        else:
            for r in rows:
                if r["spell"] in pet_to_beast:
                    beast = pet_to_beast[r["spell"]]
                    cost, level = pet.get(beast, (0, 1))
                    pet[beast] = (max(r["cost"], cost), r.get("level") or level)
    # What other players' trainers charged, ONLY for what the visits above didn't price. Where
    # both have a spell the visits win: of 1,090 spells in both, 1,007 agree to the copper, and
    # the rest differ by no steady share (0.69 to 0.87, where a standing's discount is exactly
    # 0.9), which reads as prices changed between builds; the saved visits are the game as it is now.
    # Among other players' own sightings the highest is the full price, as above. A class trainer
    # there isn't marked with its class, so a service counts for this class when its spell is one
    # of the class's.
    own_spells, own_weapons, own_pet = set(spells), set(weapons), set(pet)
    spells_seen, weapons_seen, pet_seen = {}, {}, {}
    # A trainer can teach a spell under another ID than the one the class's list has (a hunter's
    # traps, a priest's Touch of Weakness): at a trainer of THIS class, one that teaches several of
    # its spells by ID, such a service prices the class's spell of the same name and rank. Only
    # there: another class's spell can share a name (Cure Poison is a druid's and a shaman's).
    by_key = by_key or {}
    for trainer in SEEN_BY_OTHERS.values():
        services = trainer.get("services") or {}
        ours = sum(1 for spell in services if int(spell) in spell_ids) >= 3
        for spell, service in services.items():
            spell, cost = int(spell), others_price(service)
            if cost is None:
                continue
            if spell in weapon_ids:
                full(weapons_seen, spell, cost)
            elif spell in spell_ids:
                full(spells_seen, spell, cost)
            elif spell in pet_to_beast:
                beast = pet_to_beast[spell]
                was, level = pet_seen.get(beast, (0, 1))
                pet_seen[beast] = (max(cost, was), service.get("level") or level)
            elif ours:
                same = by_key.get((service.get("name"), service.get("rankText") or ""))
                if same:
                    full(spells_seen, same, cost)
    for spell, cost in spells_seen.items():
        if spell not in own_spells:
            spells[spell] = cost
    for spell, cost in weapons_seen.items():
        if spell not in own_weapons:
            weapons[spell] = cost
    for beast, seen in pet_seen.items():
        if beast not in own_pet:
            pet[beast] = seen
    if extra:
        lines.append("        extra = { " + ", ".join(f"{{ {s}, {l} }}" for s, l in sorted(extra.items(), key=lambda kv: (kv[1], kv[0]))) + " },")
    # The Grimoire visits baked here were saved on an English client: each book's name says the
    # ability and rank it teaches, and that's every demon spell of that name and rank.
    grimoires, unknown = {}, []
    for shop in SAVED["grimoires"]:
        if shop["class"] == class_id:
            for r in shop["rows"]:
                m = re.match(r"^Grimoire of (.+?)(?: \(Rank (\d+)\))?$", r.get("name") or "")
                if m:
                    found = (demon_by_key or {}).get((m.group(1), int(m.group(2) or 0)), [])
                    for spell in found:
                        grimoires[spell] = r["cost"]
                    if not found:
                        unknown.append(r["name"])
    if unknown:
        print(f"  class {class_id}: no demon spell for {len(unknown)} Grimoires: " + "; ".join(unknown))
    if spells:
        lines.append("        prices = { " + ", ".join(f"[{s}] = {c}" for s, c in sorted(spells.items())) + " },")
    if weapons:
        lines.append("        weaponPrices = { " + ", ".join(f"[{s}] = {c}" for s, c in sorted(weapons.items())) + " },")
    if pet:
        lines.append("        petTrainer = { " + ", ".join(f"[{s}] = {{ {c}, {l} }}" for s, (c, l) in sorted(pet.items())) + " },")
    if grimoires:
        lines.append("        grimoires = { " + ", ".join(f"[{s}] = {c}" for s, c in sorted(grimoires.items())) + " },")
    return len(spell_ids & set(spells))


# Class spells no trainer sells, and where they come from instead, as
# Wowhead's Forever database gives them (each spell's "Reward from" quests
# and "Taught by" items), kept only where Forever's trainers don't sell the
# spell either. Spells that come with a quest's (Growl and Maul with Bear
# Form, a cat's abilities with Cat Form) count as that quest's. Any other
# level 60 rank no trainer sells, of a spell trainers do sell, is a book too.
# A mage's teleports and portals come from a portal trainer.
QUESTS = {
    1: ["Defensive Stance", "Taunt", "Sunder Armor|Rank 1", "Berserker Stance", "Intercept|Rank 1"],
    2: ["Holy Light|Rank 1", "Redemption|Rank 1"],
    3: ["Tame Beast", "Call Pet", "Dismiss Pet", "Feed Pet", "Revive Pet"],
    # A priest's racial spells: the first rank from a quest at 10 or 20.
    5: ["Touch of Weakness|Rank 1", "Hex of Weakness|Rank 1", "Starshards|Rank 1", "Desperate Prayer|Rank 1",
        "Elune's Grace", "Feedback|Rank 1", "Shadowguard|Rank 1", "Dark Sacrifice|Rank 1", "Chastise|Rank 1",
        "Contingency Plan|Rank 1", "Divine Grace|Rank 1", "Confounding Flash"],
    7: ["Stoneskin Totem|Rank 1", "Searing Totem|Rank 1", "Healing Stream Totem|Rank 1"],
    8: ["Conjure Water|Rank 7"],
    9: ["Summon Voidwalker", "Summon Succubus", "Summon Incubus", "Summon Felhunter", "Inferno", "Ritual of Doom"],
    11: ["Bear Form", "Growl", "Maul|Rank 1", "Cure Poison", "Aquatic Form",
         "Cat Form", "Claw|Rank 1", "Rip|Rank 1", "Prowl|Rank 1"],
}
BOOKS = {
    3: ["Tranquilizing Shot", "Enchanted Flare"],
    5: ["Prayer of Shadow Protection", "Prayer of Fortitude"],
    8: ["Arcane Brilliance", "Arcane Missiles|Rank 8", "Polymorph: Cow"],
    11: ["Gift of the Wild"],
}
# A priest's racial spells past the first rank are sold by trainers, to
# that race only; one priest's trainer visit shows only its own race's.
RACIAL_TRAINER = {5}


def Elsewhere(class_id, spells, names, ranks, taught_by_trainer):
    """{spell: "quest" | "book" | "portal" | "trainer"} for this class's
    spells that come from somewhere other than the class trainer seen, or
    ("trainer") from another race's."""
    out = {}
    if not taught_by_trainer:
        return out
    sold_names = {names.get(s) for s in taught_by_trainer}

    def Key(spell):
        return names.get(spell, ""), ranks.get(spell, "")

    def Listed(entries, spell):
        name, rank = Key(spell)
        return name in entries or f"{name}|{rank}" in entries

    for level, spell, _, race in spells:
        name, rank = Key(spell)
        # First, as a visit to a portal trainer is saved like a class trainer's and would
        # otherwise count its two spells as a class trainer's.
        if class_id == 8 and (name.startswith("Teleport: ") or name.startswith("Portal: ")) and "Dalaran" not in name:
            out[spell] = "portal"
            continue
        if spell in taught_by_trainer:
            continue
        if Listed(QUESTS.get(class_id, []), spell):
            out[spell] = "quest"
        elif Listed(BOOKS.get(class_id, []), spell):
            out[spell] = "book"
        elif level >= 60 and name in sold_names and "Passive" not in rank:
            out[spell] = "book"
        elif class_id in RACIAL_TRAINER and race and rank.startswith("Rank ") and rank != "Rank 1":
            out[spell] = "trainer"
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
    # Each pet family's skill line, by the family's English name and its ID: UnitCreatureFamily
    # gives both, the name in the client's own language and the ID the same in every one. The
    # family's own name is the key, as the game's skill lines spell one differently ("Pet -
    # Crocilisk" for the Crocolisk family).
    family_of_line, family_ids = {}, {}
    for r in rows(SRC, "CreatureFamily"):
        family_of_line.setdefault(int(r["SkillLine_0"]), r["Name_lang"])
        family_ids[int(r["ID"])] = r["Name_lang"]

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
        "-- spell school, for a race-only spell the races' bits (0 for all), and its",
        "-- rank (0 for none: the game's rank text is empty until it loads a spell);",
        "-- the later ranks of a talent's ability (`talent`: the rank's spell, then",
        "-- the talent's own), which a trainer sells only to someone with the talent;",
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
        # effect), the one a trainer was seen selling, else the lower ID. The
        # lower ID alone kept Explosive Trap's effect (13812; trainers sell
        # 13813), and the planner listed the trap twice (15 Nov 2026).
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
                # race mask; 0 or -1 means every race. The file keeps the mask
                # as a signed number, so one with its top bit (race 32) set reads
                # below zero: the Alliance's teleports and portals. That bit is no
                # race Forever has, so the other 31 are kept.
                race = int(r["RaceMasks_0"])
                race = 0 if race in (0, -1) else race & 0x7FFFFFFF
                if key not in chosen or (spell in SOLD, -spell) > (chosen[key][1] in SOLD, -chosen[key][1]):
                    chosen[key] = (levels[spell], spell, index, race)
        spells = list(chosen.values())
        spells.sort()
        # Later ranks of a talent's ability (Counterattack Rank 2): named as
        # a talent's spell is, with no first rank among the trainer's. Each
        # goes with the talent's own spells, so the addon can tell who has it.
        by_name = defaultdict(list)
        for _, spell, _, _ in spells:
            by_name[names[spell]].append(spell)
        talent_ranks = {}
        for name, ids in by_name.items():
            firsts = sorted(s for s in talent_spells if names.get(s) == name)
            if firsts and min(RankNumber(ranks, s) for s in ids) >= 2:
                for spell in ids:
                    talent_ranks[spell] = firsts
        weapon_spells = []
        for skill in sorted(set(weapons[class_id])):
            teach = [int(r["Spell"]) for r in by_line[skill] if names.get(int(r["Spell"])) and r["AcquireMethod"] == "2"]
            # The files don't mark every weapon skill as a trainer's: Two-Handed Maces isn't,
            # and weapon masters sell it (Buliwyf Stonehand listed it for a shaman, and
            # Ansekhwa for others). A skill seen for sale at a trainer counts as one.
            if not teach:
                teach = [int(r["Spell"]) for r in by_line[skill] if names.get(int(r["Spell"])) and int(r["Spell"]) in SOLD]
            if teach:
                weapon_spells.append(teach[0])
        school_names = ", ".join(f'"{skills[s]["DisplayName_lang"]}"' for s in school_ids)
        lines.append(f"    [{class_id}] = {{")
        lines.append(f"        schools = {{ {school_names} }},")
        lines.append("        spells = {")
        for level, spell, school, race in spells:
            lines.append(f"            {{ {spell}, {level}, {school}, {race}, {RankNumber(ranks, spell)} }},")
        lines.append("        },")
        lines.append(f"        weapons = {{ {', '.join(str(w) for w in weapon_spells)} }},")
        if talent_ranks:
            lines.append("        talent = { " + ", ".join(
                f"[{s}] = {{ {', '.join(str(t) for t in talent_ranks[s])} }}" for s in sorted(talent_ranks)) + " },")
        pet_to_beast = {}
        demon_by_key = defaultdict(list)
        # A warlock's demons: each one's trainable abilities, rank by rank,
        # taught by Grimoires from a demon trainer.
        if class_id in DEMONS_FOR:
            lines.append("        demons = {")
            for line_id in DEMON_LINES:
                taught = Trainable(by_line[line_id], names, ranks, levels)
                if taught:
                    demon = skills[line_id]["DisplayName_lang"].replace("Pet - ", "")
                    lines.append(f'            {{ name = "{demon}", spells = {{ ' +
                                 ", ".join(f"{{ {s}, {l}, {RankNumber(ranks, s)} }}" for l, s in taught) + " } },")
                    for _, s in taught:
                        demon_by_key[(names[s], RankNumber(ranks, s))].append(s)
            lines.append("        },")
            # Each Grimoire a demon trainer sells, by its item: the demon spell it teaches.
            books = GrimoireItems({s for found in demon_by_key.values() for s in found})
            lines.append("        grimoireItems = { " + ", ".join(f"[{i}] = {s}" for i, s in sorted(books.items())) + " },")
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
                family = "*" if label == "Pet - Generic" else family_of_line.get(line_id, label.replace("Pet - ", ""))
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
            # Each family's ID to its key above, for a client that names the family in its own language.
            ids = {i: name for i, name in family_ids.items() if name in families}
            lines.append("        familyIDs = { " + ", ".join(f'[{i}] = "{n}"' for i, n in sorted(ids.items())) + " },")
        priced = ShippedPrices(lines, class_id, {s for _, s, _, _ in spells}, set(weapon_spells), pet_to_beast,
                               {(names[s], ranks.get(s, "")): s for _, s, _, _ in spells}, demon_by_key)
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
