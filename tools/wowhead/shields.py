"""Reads each shield's block from Wowhead Forever, for data/gear/wowhead-shields.json.

The game's item stats leave a shield's own block out (C_Item.GetItemStats gives a buckler only its
armor), and Forever's tables don't hold it either: ItemSparse has no block column, and shield armor
comes from ItemArmorShield by item level and quality, with nothing alike for block. Wowhead's
tooltip for the item has it ("3 Block"), apart from any "+N Block Value" an item adds on top, which
the game's stats do give. tools/build_gear.py ships it as GearData's `block`.

The shields are every item the game's Item table (data/professions/Item.csv) has as armor, subclass
shield: more than its ItemSparse holds. Each is one tooltip from nether.wowhead.com, a request every
PAUSE seconds. What it has read is written as it goes, so a run stopped part way carries on where it
stopped; --all reads every shield again. An item Wowhead doesn't know, or whose tooltip has no block
line, is kept as 0 and left out of GearData.

Run: python -I tools/wowhead/shields.py [--all]
Then: python -I tools/build_gear.py
"""

import csv
import datetime
import json
import pathlib
import re
import sys
import time
import urllib.error
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
ITEMS = ROOT / "data" / "professions" / "Item.csv"
OUT = ROOT / "data" / "gear" / "wowhead-shields.json"
AGENT = "jsal-ui data refresh"
URL = "https://nether.wowhead.com/forever/tooltip/item/{}?dataEnv=&locale=0"
PAUSE = 1.5
# The tooltip's block line: "<br>3 Block" and then the next tag. "+25 Block Value" (an item's
# extra, which the game's stats give) has a word after it, so it isn't this.
BLOCK = re.compile(r"<br>(\d+) Block(?=<)")


def shields():
    with open(ITEMS, newline="", encoding="utf-8") as f:
        return sorted(int(r["ID"]) for r in csv.DictReader(f) if r["ClassID"] == "4" and r["SubclassID"] == "6")


def block_of(item_id):
    """The shield's block from its Wowhead tooltip; 0 when Wowhead has no such item or no block line."""
    request = urllib.request.Request(URL.format(item_id), headers={"User-Agent": AGENT})
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            data = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return 0
        raise
    found = BLOCK.search(data.get("tooltip") or "")
    return int(found.group(1)) if found else 0


def save(block):
    text = json.dumps({"fetched": datetime.date.today().isoformat(),
                       "block": {str(i): v for i, v in sorted(block.items())}}, indent=0)
    OUT.write_text(text + "\n", encoding="utf-8")


def main():
    block = {}
    if OUT.exists() and "--all" not in sys.argv[1:]:
        block = {int(i): v for i, v in json.loads(OUT.read_text(encoding="utf-8"))["block"].items()}
    todo = [i for i in shields() if i not in block]
    print(f"{len(todo)} shields to read")
    for n, item_id in enumerate(todo, 1):
        block[item_id] = block_of(item_id)
        if n % 25 == 0 or n == len(todo):
            save(block)
            print(f"{n}/{len(todo)}")
        time.sleep(PAUSE)
    save(block)
    print(f"{sum(1 for v in block.values() if v)} shields with block, {sum(1 for v in block.values() if not v)} without -> {OUT.name}")


if __name__ == "__main__":
    main()
