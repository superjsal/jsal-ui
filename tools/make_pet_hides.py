"""Packs the pen's hiding places into the picture the game loads.

    python -I tools/make_pet_hides.py [preview folder]

Reads data/pals/hides/<scene>.png (PixelLab objects, data/pals/hides/fetch.py) and writes
jsalUI/Media/Pet/hides.png, 512 by 64: one 48-pixel cell a scene, in the order of SCENES in
jsalUI/Pet/Play.lua, each thing cut to its own size and standing on its cell's bottom edge, centred.
Prints each thing's width and height, for Pet.HIDES.size.
"""
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SCENES = ("meadow", "snow", "desert", "swamp", "coast", "darkwood", "savanna", "volcanic", "jungle")
CELL = 48


def main():
    sheet = Image.new("RGBA", (512, 64), (0, 0, 0, 0))
    sizes = []
    for i, scene in enumerate(SCENES):
        im = Image.open(ROOT / "data" / "pals" / "hides" / (scene + ".png")).convert("RGBA")
        thing = im.crop(im.getbbox())
        assert thing.width <= CELL and thing.height <= CELL, (scene, thing.size)
        sheet.alpha_composite(thing, (i * CELL + (CELL - thing.width) // 2, CELL - thing.height))
        sizes.append("%s = { %d, %d }" % (scene, thing.width, thing.height))
    sheet.save(ROOT / "jsalUI" / "Media" / "Pet" / "hides.png", optimize=True)
    print(", ".join(sizes))
    if len(sys.argv) > 1:
        look = Image.new("RGBA", sheet.size, (70, 110, 70, 255))
        look.alpha_composite(sheet)
        look.resize((512 * 3, 64 * 3), Image.NEAREST).save(Path(sys.argv[1]) / "hides.png")


if __name__ == "__main__":
    main()
