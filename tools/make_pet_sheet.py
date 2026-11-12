"""Packs a companion's animation frames into the one picture the game loads.

    python -I tools/make_pet_sheet.py briarboar <frames folder> [preview folder]
    python -I tools/make_pet_sheet.py thornhog <frames folder> [preview folder]
    python -I tools/make_pet_sheet.py brambletusk <frames folder> [preview folder]

The frames folder holds one folder per animation (Walk, Idle_Long, Eating, Jump,
Idle_Sitting, Going_to_Sleep, Waking_Getting_Up), each with a south-west folder
of frame_000.png, frame_001.png and so on, 64 pixels square or larger, the creature
facing down and to the left. The game flips the picture when it walks to the right.

Writes jsalUI/Media/Pet/<name>_sheet.tga: the animations one after another in
the order below, which is the order jsalUI/Pet/Pet.lua counts them in. Most
are 512 pixels square, eight 64-pixel cells to a row; a creature too large
for that has its own layout in LAYOUT. Also writes <name>.tga, its first
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
# How a sheet is laid out: the size of a cell, how many to a row, the picture's
# size (powers of two), how many walking frames, and `shift`. Of a frame larger
# than a cell, the cell kept starts `shift` short of the middle: for a frame 80
# square and a 64 cell that is (6, 6) to (70, 70), the same for every frame so
# its feet stay put, and where a cell-sized animation has the creature standing.
PLAIN = {"cell": 64, "cols": 8, "sheet": (512, 512), "walk": 4, "shift": 2}
# The Brambletusk fills the 64 square it stands in, so its cell has eight
# pixels more on every side for it to move in, and it walks in eight frames.
# The ghost monkey's last form, the juggler, needs the same room for its orbs.
LAYOUT = {
    # The usual cells, but an eight-frame walk makes 68 frames, four more than
    # the usual sheet holds: sixteen to a row in a wider picture.
    "thornhog": {"cell": 64, "cols": 16, "sheet": (1024, 512), "walk": 8, "shift": 2},
    "brambletusk": {"cell": 80, "cols": 12, "sheet": (1024, 512), "walk": 8, "shift": 0},
    # The dragon's middle form sprawls wider than a 64 cell when it lies down.
    "jabdrake": {"cell": 80, "cols": 12, "sheet": (1024, 512), "walk": 8, "shift": 0},
    "thundermane": {"cell": 80, "cols": 12, "sheet": (1024, 512), "walk": 8, "shift": 0},
    "tempestmane": {"cell": 80, "cols": 12, "sheet": (1024, 512), "walk": 8, "shift": 0},
    "bloomsage": {"cell": 80, "cols": 12, "sheet": (1024, 512), "walk": 8, "shift": 0},
    "lanternshell": {"cell": 64, "cols": 16, "sheet": (1024, 512), "walk": 8, "shift": 2},
    "capling": {"cell": 64, "cols": 16, "sheet": (1024, 512), "walk": 8, "shift": 2},
    "stormcub": {"cell": 64, "cols": 16, "sheet": (1024, 512), "walk": 8, "shift": 2},
    "flarechamp": {"cell": 80, "cols": 12, "sheet": (1024, 512), "walk": 8, "shift": 0},
    "wispjester": {"cell": 80, "cols": 12, "sheet": (1024, 512), "walk": 4, "shift": 0},
}

# A creature whose animations came out standing at different heights names the
# row of its cell its feet belong on: each animation is moved down as a whole
# until the lowest its feet reach is that row, so it doesn't hop when it
# changes what it's doing. 58 is where the Briarboar's feet are.
GROUND = {"thornhog": 58}


def order(lay):
    return (("Walk", lay["walk"]),) + ORDER[1:]


def frames(folder, lay, ground=None):
    side, cells = lay["cell"], []
    for name, count in order(lay):
        files = sorted((folder / name / "south-west").glob("frame_*.png"))
        assert len(files) == count, (name, len(files), count)
        ims = [Image.open(file).convert("RGBA") for file in files]
        size = ims[0].size
        assert all(im.size == size for im in ims), (name, [im.size for im in ims])
        # An animation comes either a cell in size, or larger with the same room
        # added on every side for the creature to move in.
        left = top = 0
        if size != (side, side):
            left, top = (size[0] - side) // 2 - lay["shift"], (size[1] - side) // 2 - lay["shift"]
        drop = 0
        if ground is not None:
            drop = ground - (max(im.getbbox()[3] for im in ims) - top)
        for file, im in zip(files, ims):
            box = im.getbbox()
            assert (box[0] - left >= 0 and box[2] - left <= side
                    and box[1] - top + drop >= 0 and box[3] - top + drop <= side), (file, box, left, top, drop)
            cell = Image.new("RGBA", (side, side), (0, 0, 0, 0))
            cell.paste(im, (-left, drop - top))
            cells.append(cell)
    return cells


# A creature may also have a Special folder: one more animation, nine frames,
# that shows off what kind of creature it is (a fiery punch, a burst of
# leaves). Its effects reach well outside the creature, so it gets a picture
# of its own, <name>_special.tga, 1024 by 128 with nine 96-pixel cells in a
# row, the creature standing in each where it stands in the middle of a cell
# of its sheet. What doesn't fit in a cell is cut off.
SPECIAL = ("Special", 9, 96, (1024, 128))


def special(folder, lay, ground=None):
    name, count, side, size = SPECIAL
    files = sorted((folder / name / "south-west").glob("frame_*.png"))
    if not files:
        return None
    assert len(files) == count, (name, len(files), count)
    ims = [Image.open(file).convert("RGBA") for file in files]
    strip = Image.new("RGBA", size, (0, 0, 0, 0))
    room = (side - 64) // 2 + lay["shift"]
    drop = 0
    if ground is not None:
        # Its first frame is the creature standing: its feet go where they are on the sheet.
        first = ims[0]
        drop = ground - (first.getbbox()[3] - (first.height - 64) // 2 + lay["shift"])
    for i, im in enumerate(ims):
        cell = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        cell.paste(im, (room - (im.width - 64) // 2, room - (im.height - 64) // 2 + drop))
        strip.paste(cell, (i * side, 0))
    return strip


def main():
    name, folder = sys.argv[1], Path(sys.argv[2])
    lay = LAYOUT.get(name, PLAIN)
    side, cols = lay["cell"], lay["cols"]
    cells = frames(folder, lay, GROUND.get(name))
    assert cols * side <= lay["sheet"][0] and ((len(cells) - 1) // cols + 1) * side <= lay["sheet"][1], len(cells)
    sheet = Image.new("RGBA", lay["sheet"], (0, 0, 0, 0))
    for i, cell in enumerate(cells):
        sheet.paste(cell, (i % cols * side, i // cols * side))
    out = Path(__file__).resolve().parent.parent / "jsalUI" / "Media" / "Pet"
    sheet.save(out / (name + "_sheet.tga"))
    still = cells[lay["walk"]]          # the first resting frame
    still.save(out / (name + ".tga"))
    print(len(cells), "frames ->", out / (name + "_sheet.tga"))
    extra = special(folder, lay, GROUND.get(name))
    if extra:
        extra.save(out / (name + "_special.tga"))
        print("special ->", out / (name + "_special.tga"))
        if len(sys.argv) > 3:
            look = Image.new("RGBA", extra.size, (42, 47, 58, 255))
            look.alpha_composite(extra)
            look.crop((0, 0, 9 * 96, 96)).resize((9 * 96 * 2, 192), Image.NEAREST).save(Path(sys.argv[3]) / (name + "_special.png"))
    if len(sys.argv) > 3:
        look = Image.new("RGBA", sheet.size, (42, 47, 58, 255))
        look.alpha_composite(sheet)
        look = look.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST)
        look.save(Path(sys.argv[3]) / (name + "_sheet.png"))


if __name__ == "__main__":
    main()
