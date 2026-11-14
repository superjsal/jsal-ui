"""Writes the small pictures the pals' window uses under the pen: a heart for
the bond, and one picture for each care button.

    python -I tools/make_pet_icons.py

The heart, the moon (Lights out), the sun (Wake it) and the medicine bottle were made with
PixelLab, in the style of the treat, and are kept as they came in
data/pals/icons. The heart is cut down to the 16 dots it fills, so the
window draws it dot for dot; the others go in as they are.

The care buttons' pictures have names of their own (care_meal and the rest,
after what each uses up) though four of them are the things set down in the
pen (the bowl, the treat, the ball, the scrubber): the window finds what's
set down by its picture's name, and a button's picture must not be taken
for it.

Run tools/shrink_pet_pngs.py after it.
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
MEDIA = ROOT / "jsalUI" / "Media" / "Pet"
SOURCE = ROOT / "data" / "pals" / "icons"


def main():
    heart = Image.open(SOURCE / "heart.png").convert("RGBA")
    left, top, right, bottom = heart.getbbox()
    assert right - left <= 16 and bottom - top <= 16, "the heart fits in 16 dots"
    # The 16 by 16 around it, with the heart in the middle.
    x0 = left - (16 - (right - left)) // 2
    y0 = top - (16 - (bottom - top)) // 2
    heart.crop((x0, y0, x0 + 16, y0 + 16)).save(MEDIA / "heart.png")
    for name, source in (("care_lights", "moon"), ("care_wake", "sun"), ("care_medicine", "medicine")):
        picture = Image.open(SOURCE / (source + ".png")).convert("RGBA")
        assert picture.size == (32, 32), source
        picture.save(MEDIA / (name + ".png"))
    for name, source in (("care_meal", "bowl"), ("care_treat", "treat"), ("care_toy", "ball"), ("care_soap", "scrubber")):
        Image.open(MEDIA / (source + ".png")).convert("RGBA").save(MEDIA / (name + ".png"))
    print("8 pictures written to", MEDIA)


if __name__ == "__main__":
    main()
