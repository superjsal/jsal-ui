"""Prints the line to run in the browser pane before tools/wowhead/dungeons.js: each Wowhead
Forever zone with the bosses to read there, by the names data/dungeons/wowhead.json keeps their
loot under, and the names Wowhead may list them by instead.

With --thin, only the bosses whose loot is still thin (under 3 drops, or a drop without
Wowhead's drop chance yet), which is what changes month to month: about half the pages.

Run: python -I tools/wowhead/bosses.py [--thin]
"""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]

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
}

data = json.loads((ROOT / "data" / "dungeons" / "wowhead.json").read_text(encoding="utf-8"))
thin = "--thin" in sys.argv


def wanted(drops):
    return not thin or len(drops) < 3 or any(pct is None for _, pct in drops)


bosses = {}
for z, v in data["zones"].items():
    picked = {name: ALIAS.get(name, [name]) for name, drops in v["loot"].items() if wanted(drops)}
    if picked:
        bosses[z] = picked
print(f"// {sum(len(b) for b in bosses.values())} bosses in {len(bosses)} zones", file=sys.stderr)
print("window.__bosses = " + json.dumps(bosses, ensure_ascii=False) + ";")
