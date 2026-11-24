"""Prints the line to run in the browser before tools/wowhead/dungeons.js: each Wowhead
Forever zone with the bosses to read there, by the names data/dungeons/wowhead.json keeps their
loot under, and the names Wowhead may list them by instead.

The bosses are every one the game's own tables have (tools/build_dungeons.py's dungeon_rows), not
the ones wowhead.json already holds: a boss Wowhead had nothing for on the first read was never in
that file, so it was never asked for again (Zul'Farrak, Maraudon, Sunken Temple and Blackrock
Depths stayed nearly empty from 7 to 15 Nov 2026).

With --thin, only the bosses whose loot is still thin (none read, under 3 drops, or a drop without
Wowhead's drop chance yet), which is what changes month to month.
With --zones 16550,1176 only those Wowhead zones.

Run: python -I tools/wowhead/bosses.py [--thin] [--zones <zone>,<zone>...]
"""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
# python -I leaves the tools folder off the path.
sys.path.insert(0, str(ROOT / "tools"))
from build_dungeons import WOWHEAD_ZONE, dungeon_rows  # noqa: E402

# Bosses Wowhead lists under other names, or as several NPCs (an encounter of a group).
ALIAS = {
    "The Lost Dwarves": ["Baelog", 'Eric "The Swift"', "Olaf"],
    "Edge of Madness": ["Gri'lek", "Hazza'rah", "Renataki", "Wushoolay"],
    "Ring of Law": ["Anub'shiah", "Eviscerator", "Gorosh the Dervish", "Grizzle", "Hedrum the Creeper", "Ok'thor the Breaker"],
    "The Seven": ["Doom'rel", "Dope'rel", "Gloom'rel", "Haterel", "Seeth'rel", "Vile'rel", "Anger'rel"],
    "Geilhast": ["Gelihast"],
    "Gelihast": ["Gelihast", "Geilhast"],
    "The Vault": ["Watchman Doomgrip"],
    "The Butcher": ["The Butcher", "The Baron"],
    "The Baron": ["The Baron", "The Butcher"],
    "Infurnus": ["Infurnus", "Magmatus"],
    "Magmatus": ["Magmatus", "Infurnus"],
    "Sneed": ["Sneed", "Sneed's Shredder"],
    "Mana Elemental": ["Mana Elemental", "Arcanic Enigma"],
    "Arcanic Enigma": ["Arcanic Enigma", "Mana Elemental"],
    # The Drowned City: the fight is Deathless Marrow, with waves of Deathless Guardians.
    "Deathless Guardians": ["Deathless Marrow"],
    "Handler Ashka": ["War Handler Ashka"],
    "Overseer Mugg": ["Overlord Mugg"],
    # Scholomance: the game's encounters shorten or misspell two of Wowhead's NPC names.
    "Kirtonos": ["Kirtonos", "Kirtonos the Herald"],
    "Ras Frostwhisperer": ["Ras Frostwhisperer", "Ras Frostwhisper"],
}

# Bosses their zone's page doesn't list among its NPCs (Krol'dok Stronghold's page has three
# NPCs, The Shaper's Terrace's none): their NPC pages, found by name on
# /forever/npcs/name:<name> on 15 Nov 2026. dungeons.js reads a number as an NPC's ID.
# Not here: The Shaper's Terrace's "Ravasaur Hunters". The two Ravasaur Hunter NPCs (253214,
# 262688) list only world drops (random greens at 3 to 8%), so the fight's own loot is on
# something else; it's left without loot until Wowhead's zone page names it.
NPC_ID = {
    "Slavecrusher Grox": [258966], "Twilight Commander Zarmok": [258972], "Handler Ashka": [259281],
    "Nar'gurk": [258964], "Overseer Mugg": [258968],
    "Blackmaw Behemoth": [247207],
    "Titanosaur": [253201], "Thunderhoof": [261812],
    "Venomridge": [261813], "Direhorn Matriarch": [262127], "Cinder": [261974], "King Op": [261993],
    "Snowtalon": [262297], "Bolt": [262081], "Vitrix": [272561], "Nanaya": [261809],
    # Onyxia's Lair's zone page (2159) lists no NPCs, quests or drops on Wowhead Forever.
    "Onyxia": [10184],
    # City of Dalaran's zone page (16544) lists only its quests, no NPCs or drops: its bosses' NPC
    # pages, found by name on /forever/npcs/name:<name> (each the one in Alterac Mountains).
    "Arcane Anomaly": [245999], "Fel Ancient": [246003], "Mana Devourer": [246008],
    "Mana Elemental": [246016], "Unstable Sentinel": [246017], "Lyn the Ignored": [247032],
    "Atrexis the Grave Knight": [247126], "Mana Wraith": [246931], "Shade of the Archmage": [246020],
}

data = json.loads((ROOT / "data" / "dungeons" / "wowhead.json").read_text(encoding="utf-8"))
thin = "--thin" in sys.argv
only = set(sys.argv[sys.argv.index("--zones") + 1].split(",")) if "--zones" in sys.argv else None


def wanted(drops):
    return not thin or drops is None or len(drops) < 3 or any(pct is None for _, pct in drops)


bosses = {}
for _raid, _level, _name, lfg_id, _map, _zone, _faction, encounters in dungeon_rows():
    z = str(WOWHEAD_ZONE[lfg_id])
    if only and z not in only:
        continue
    have = data["zones"].get(z, {}).get("loot", {})
    for _order, _encounter, boss in encounters:
        if wanted(have.get(boss)):
            bosses.setdefault(z, {})[boss] = NPC_ID.get(boss, []) + ALIAS.get(boss, [boss])
print(f"// {sum(len(b) for b in bosses.values())} bosses in {len(bosses)} zones", file=sys.stderr)
print("window.__bosses = " + json.dumps(bosses, ensure_ascii=False) + ";")
