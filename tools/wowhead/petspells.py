"""Prints the window.__petSpells line for tools/wowhead/pets.js: every pet ability rank a
hunter's pet family can learn (the pet's own spell IDs), from jsalUI/Training/SpellData.lua's
`families`. The abilities every family shares ("*": Growl, the resistances...) come from pet
trainers, not from taming, so they're left out.

Run: python -I tools/wowhead/petspells.py
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def family_spells():
    """{pet spell: Beast Training spell} for every family's own abilities."""
    text = (ROOT / "jsalUI" / "Training" / "SpellData.lua").read_text(encoding="utf-8")
    start = text.index("        families = {")
    block = text[start:text.index("\n        },", start)]
    spells = {}
    for line in block.splitlines()[1:]:
        family = re.match(r'\s*\["(.+?)"\]', line).group(1)
        if family == "*":
            continue
        for pet, beast in re.findall(r"\{ (\d+), (\d+), \d+, \d+ \}", line):
            spells[int(pet)] = int(beast)
    return spells


if __name__ == "__main__":
    print("window.__petSpells = " + str(sorted(family_spells())) + ";")
