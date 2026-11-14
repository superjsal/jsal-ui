"""Draws the small pictures the pals' window uses under the pen: a heart for
the bond, and one picture for each care button.

    python -I tools/make_pet_icons.py

The care buttons' pictures have names of their own (care_meal and the rest, after what each uses up)
though four of them are the things set down in the pen (the bowl, the treat,
the ball, the scrubber): the window finds what's set down by its picture's
name, and a button's picture must not be taken for it. The moon, the
medicine and the heart are drawn here, a dot at a time, at half size and
doubled, so they sit with the rest of the art.

Run tools/shrink_pet_pngs.py after it.
"""
from pathlib import Path

from PIL import Image

MEDIA = Path(__file__).resolve().parent.parent / "jsalUI" / "Media" / "Pet"

INK = {
    ".": (0, 0, 0, 0),
    "o": (38, 30, 42, 255),      # the outline
    "r": (232, 86, 122, 255),    # the heart
    "l": (255, 170, 190, 255),   # its shine
    "d": (190, 58, 96, 255),     # its shade
    "y": (240, 222, 150, 255),   # the moon
    "s": (206, 184, 110, 255),   # its shade
    "b": (120, 170, 214, 255),   # the bottle
    "c": (86, 130, 180, 255),    # its shade
    "w": (240, 236, 224, 255),   # its label, and its stopper
    "x": (226, 74, 70, 255),     # the cross on it
}

HEART = [
    ".ooo...ooo.",
    "orrro.orrro",
    "orlrrorrrro",
    "orlrrrrrrro",
    "orrrrrrrrdo",
    ".orrrrrrdo.",
    "..orrrrdo..",
    "...orrdo...",
    "....odo....",
    ".....o.....",
]
MOON = [
    "....oooo....",
    "..ooyyyyo...",
    ".oyyyyoo....",
    ".oyyyo......",
    "oyyyyo......",
    "oyyyyo......",
    "oyyyyyo...o.",
    "oyyyyyyoooyo",
    ".oyyyyyyyyso",
    ".osyyyyyyso.",
    "..oosssoo...",
    "....ooo.....",
]
MEDICINE = [
    "...ooooo...",
    "...owwwo...",
    "...ooooo...",
    "..obbbbbo..",
    ".obbbbbbbo.",
    "obwwwwwwwbo",
    "obwwwxwwwbo",
    "obwwxxxwwbo",
    "obwwwxwwwbo",
    "obwwwwwwwbo",
    "obbbbbbbbco",
    "obbbbbbccco",
    ".ooooooooo.",
]


def drawn(rows):
    """A 32 by 32 picture of the rows, each dot doubled, in the middle."""
    w, h = len(rows[0]), len(rows)
    assert all(len(r) == w for r in rows), "rows of one length"
    small = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    x0, y0 = (16 - w) // 2, (16 - h) // 2
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            small.putpixel((x0 + x, y0 + y), INK[ch])
    return small.resize((32, 32), Image.NEAREST)


def main():
    for name, rows in (("heart", HEART), ("care_lights", MOON), ("care_medicine", MEDICINE)):
        drawn(rows).save(MEDIA / (name + ".png"))
    for name, source in (("care_meal", "bowl"), ("care_treat", "treat"), ("care_toy", "ball"), ("care_soap", "scrubber")):
        Image.open(MEDIA / (source + ".png")).convert("RGBA").save(MEDIA / (name + ".png"))
    print("7 pictures written to", MEDIA)


if __name__ == "__main__":
    main()
