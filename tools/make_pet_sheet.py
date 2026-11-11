"""Packs a companion's animation frames into the one picture the game loads.

    python -I tools/make_pet_sheet.py briarboar <frames folder> [preview folder]

The frames folder holds one folder per animation (Walk, Idle_Long, Eating, Jump,
Idle_Sitting, Going_to_Sleep, Waking_Getting_Up), each with a south-west folder
of frame_000.png, frame_001.png and so on, 80 pixels square, the creature facing
down and to the left. The game flips the picture when it walks to the right.

Writes jsalUI/Media/Pet/<name>_sheet.tga: 512 pixels square, eight 64-pixel
cells to a row, the animations one after another in the order below, which is
the order jsalUI/Pet/Pet.lua counts them in. Also writes <name>.tga, its first
resting frame on its own, for menus and Today.
"""
import sys
from pathlib import Path

from PIL import Image

# (folder, how many frames it must have): keep in step with SHEETS in Pet.lua.
ORDER = (
    ("Walk", 4), ("Idle_Long", 15), ("Eating", 11), ("Jump", 7),
    ("Idle_Sitting", 10), ("Going_to_Sleep", 8), ("Waking_Getting_Up", 9),
)
CELL, COLS = 64, 8
# The frames are 80 square with the creature near the middle: this is the 64
# square of each one that's kept, the same for all so its feet stay put.
CROP = (6, 6, 70, 70)


def frames(folder):
    cells = []
    for name, count in ORDER:
        files = sorted((folder / name / "south-west").glob("frame_*.png"))
        assert len(files) == count, (name, len(files), count)
        for file in files:
            im = Image.open(file).convert("RGBA")
            assert im.size == (80, 80), (file, im.size)
            box = im.getbbox()
            assert box[0] >= CROP[0] and box[1] >= CROP[1] and box[2] <= CROP[2] and box[3] <= CROP[3], (file, box)
            cells.append(im.crop(CROP))
    return cells


def main():
    name, folder = sys.argv[1], Path(sys.argv[2])
    cells = frames(folder)
    assert len(cells) <= COLS * COLS, len(cells)
    sheet = Image.new("RGBA", (CELL * COLS, CELL * COLS), (0, 0, 0, 0))
    for i, cell in enumerate(cells):
        sheet.paste(cell, (i % COLS * CELL, i // COLS * CELL))
    out = Path(__file__).resolve().parent.parent / "jsalUI" / "Media" / "Pet"
    sheet.save(out / (name + "_sheet.tga"))
    still = cells[ORDER[0][1]]          # the first resting frame
    still.save(out / (name + ".tga"))
    print(len(cells), "frames ->", out / (name + "_sheet.tga"))
    if len(sys.argv) > 3:
        look = Image.new("RGBA", sheet.size, (42, 47, 58, 255))
        look.alpha_composite(sheet)
        look = look.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST)
        look.save(Path(sys.argv[3]) / (name + "_sheet.png"))


if __name__ == "__main__":
    main()
