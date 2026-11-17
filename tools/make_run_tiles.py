"""Packs Pal run's ground and its finish flag into the picture the game loads.

    python -I tools/make_run_tiles.py [preview folder]

Reads data/pals/run/<land>.png and <land>.json (PixelLab tilesets, data/pals/run/fetch.py) and
flag.png, and writes jsalUI/Media/Pet/run.png, 256 by 256: a 64-pixel cell a country, four to a row,
in the order of LANDS in jsalUI/Games/PalRunRules.lua, and the flag in the cell after the last.

A country's cell holds its 16 tiles, 16 pixels each, four to a row. A tile is drawn where four squares
of the course meet, and which one is drawn says which of those four are ground: 8 for the square
up and left of the meeting point, 4 up and right, 2 down and left, 1 down and right, added up. So
tile 0 is open air and tile 15 is ground all round.

And each country's scenery, data/pals/run/back_<land>.png (256 by 100), as
jsalUI/Media/Pet/run_back_<land>.png: the same picture at the top of a 256 by 128 one, the size the
game wants, with the rows under it left clear.
"""
import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "data" / "pals" / "run"
LANDS = ("meadow", "snow", "desert", "swamp", "coast", "darkwood", "savanna", "volcanic", "jungle")
BIT = {"NW": 8, "NE": 4, "SW": 2, "SE": 1}


def cell(land):
    sheet = Image.open(SOURCE / (land + ".png")).convert("RGBA")
    out = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    seen = set()
    for tile in json.loads((SOURCE / (land + ".json")).read_text(encoding="utf-8"))["tileset_data"]["tiles"]:
        # The tileset calls ground "lower" and open air "upper".
        index = sum(bit for corner, bit in BIT.items() if tile["corners"][corner] == "lower")
        box = tile["bounding_box"]
        assert box["width"] == 16 and box["height"] == 16 and index not in seen, (land, tile["name"])
        seen.add(index)
        out.paste(sheet.crop((box["x"], box["y"], box["x"] + 16, box["y"] + 16)), ((index % 4) * 16, (index // 4) * 16))
    assert len(seen) == 16, (land, sorted(seen))
    return out


def main():
    sheet = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    for i, land in enumerate(LANDS):
        sheet.paste(cell(land), ((i % 4) * 64, (i // 4) * 64))
    flag = Image.open(SOURCE / "flag.png").convert("RGBA")
    flag = flag.crop(flag.getbbox())
    assert flag.width <= 64 and flag.height <= 64, flag.size
    at = len(LANDS)
    # Standing on its cell's bottom edge, centred.
    sheet.alpha_composite(flag, ((at % 4) * 64 + (64 - flag.width) // 2, (at // 4) * 64 + 64 - flag.height))
    sheet.save(ROOT / "jsalUI" / "Media" / "Pet" / "run.png", optimize=True)
    print("flag = { %d, %d }" % flag.size)
    for land in LANDS:
        back = Image.open(SOURCE / ("back_" + land + ".png")).convert("RGBA")
        assert back.size == (256, 100), (land, back.size)
        whole = Image.new("RGBA", (256, 128), (0, 0, 0, 0))
        whole.paste(back, (0, 0))
        # Most come with a stray pale line as their last row: it's the row above again.
        whole.paste(back.crop((0, 98, 256, 99)), (0, 99))
        whole.save(ROOT / "jsalUI" / "Media" / "Pet" / ("run_back_" + land + ".png"), optimize=True)
    if len(sys.argv) > 1:
        look = Image.new("RGBA", sheet.size, (120, 170, 230, 255))
        look.alpha_composite(sheet)
        look.resize((256 * 4, 256 * 4), Image.NEAREST).save(Path(sys.argv[1]) / "run_tiles.png")


if __name__ == "__main__":
    main()
