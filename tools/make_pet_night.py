"""Makes the pen's night-time picture out of its daytime one.

    python -I tools/make_pet_night.py meadow [preview folder]

Reads jsalUI/Media/Pet/<name>.tga (written by tools/make_pet_scene.py: the
220 by 100 scene in the top left of a 256 by 128 picture) and writes
<name>_night.tga the same way, which the pen shows while the companion is
asleep. Nothing is redrawn by hand, so a changed meadow only needs this run
again:

  the sky      (the pale blue and the white clouds in the top 26 rows) becomes
               a deep blue, darker at the top, with a crescent moon and stars
  the rest     every colour is pulled a quarter of the way to grey and tinted
               blue, so the grass, fence and flowers sit in moonlight

The stars fall in the same places every run.
"""
import random
import sys
from pathlib import Path

from PIL import Image

W, H, SKY = 220, 100, 26
TINT, GREY = (0.42, 0.52, 0.86), 0.25
TOP, LOW = (14, 18, 48), (44, 58, 104)
STARS, MOON = 34, (40, 9)
BRIGHT, DIM, MOONLIGHT = (255, 250, 220, 255), (170, 185, 230, 255), (250, 244, 205, 255)
MEDIA = Path(__file__).resolve().parent.parent / "jsalUI" / "Media" / "Pet"


def is_sky(p, y):
    r, g, b, _ = p
    return y < SKY and ((b > 170 and b > r + 25) or (r > 200 and g > 200 and b > 200))


def main():
    name = sys.argv[1]
    im = Image.open(MEDIA / (name + ".tga")).convert("RGBA").crop((0, 0, W, H))
    px = im.load()
    sky = set()
    for y in range(H):
        for x in range(W):
            if is_sky(px[x, y], y):
                sky.add((x, y))
                t = y / SKY
                px[x, y] = tuple(int(TOP[i] + (LOW[i] - TOP[i]) * t) for i in range(3)) + (255,)
            else:
                r, g, b, _ = px[x, y]
                grey = (r + g + b) // 3
                px[x, y] = tuple(min(255, int((c * (1 - GREY) + grey * GREY) * TINT[i])) for i, c in enumerate((r, g, b))) + (255,)
    rng = random.Random(1)
    placed = 0
    while placed < STARS:
        x, y = rng.randrange(W), rng.randrange(20)
        if (x, y) in sky:
            px[x, y] = BRIGHT if rng.random() < 0.4 else DIM
            placed += 1
    mx, my = MOON
    for dy in range(-5, 6):
        for dx in range(-5, 6):
            # A disc with a smaller disc bitten out of its upper right: a crescent.
            if dx * dx + dy * dy <= 26 and (dx - 3) ** 2 + (dy + 1) ** 2 > 20 and (mx + dx, my + dy) in sky:
                px[mx + dx, my + dy] = MOONLIGHT
    sheet = Image.new("RGBA", (256, 128), (0, 0, 0, 255))
    sheet.paste(im, (0, 0))
    sheet.save(MEDIA / (name + "_night.tga"), compression="tga_rle")
    print(im.size, "->", MEDIA / (name + "_night.tga"))
    if len(sys.argv) > 2:
        im.resize((W * 2, H * 2), Image.NEAREST).save(Path(sys.argv[2]) / (name + "_night.png"))


if __name__ == "__main__":
    main()
