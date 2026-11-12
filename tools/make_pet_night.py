"""Makes the pen's night-time picture out of its daytime one.

    python -I tools/make_pet_night.py meadow [preview folder]

Reads jsalUI/Media/Pet/<name>.png (written by tools/make_pet_scene.py: the
220 by 100 scene in the top left of a 256 by 128 picture) and writes
<name>_night.png the same way, which the pen shows while the companion is
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
    im = Image.open(MEDIA / (name + ".png")).convert("RGBA").crop((0, 0, W, H))
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
    save(im, name, "_night")
    save(dusk(name), name, "_dusk")


# The sky at sunset, from the top of the picture down to the horizon.
SUNSET = [(0.0, (62, 48, 112)), (0.4, (150, 74, 124)), (0.72, (236, 122, 86)), (1.0, (255, 200, 116))]
BLUES, HILLS = {(132, 216, 242), (161, 226, 243)}, {(111, 180, 184), (80, 156, 159)}
SUN, SUN_R = (99, 21), 7
GLOW, DISC = (255, 214, 130, 255), (255, 240, 190, 255)
WARM, DIM_BY = (1.0, 0.80, 0.66), 0.86


def sunset(t):
    for (t0, a), (t1, b) in zip(SUNSET, SUNSET[1:]):
        if t <= t1:
            f = (t - t0) / (t1 - t0)
            return tuple(int(a[i] + (b[i] - a[i]) * f) for i in range(3)) + (255,)
    return SUNSET[-1][1] + (255,)


def dusk(name):
    """The same meadow at sunset, shown for a moment between day and night:
    the sky runs from violet down to gold, its clouds catch the light, the far
    hills are a violet outline with the sun going down behind them, and the
    land is warmed and a little dimmed."""
    im = Image.open(MEDIA / (name + ".png")).convert("RGBA").crop((0, 0, W, H))
    px = im.load()
    sky = set()
    for y in range(H):
        for x in range(W):
            r, g, b, _ = px[x, y]
            if y < SKY and (r, g, b) in BLUES:
                sky.add((x, y))
                px[x, y] = sunset(y / SKY)
            elif y < SKY and r > 200 and g > 200 and b > 200:
                # A cloud, lit from below: rosy on top, gold underneath.
                t = y / SKY
                px[x, y] = (255, int(150 + 70 * t), int(150 - 20 * t), 255)
            elif y < SKY and (r, g, b) in HILLS:
                px[x, y] = (120, 78, 128, 255) if (r, g, b) == (111, 180, 184) else (96, 66, 112, 255)
            else:
                px[x, y] = tuple(min(255, int(c * WARM[i] * DIM_BY)) for i, c in enumerate((r, g, b))) + (255,)
    sx, sy = SUN
    for dy in range(-SUN_R - 2, SUN_R + 3):
        for dx in range(-SUN_R - 2, SUN_R + 3):
            far = dx * dx + dy * dy
            if (sx + dx, sy + dy) in sky and far <= (SUN_R + 2) ** 2:
                px[sx + dx, sy + dy] = DISC if far <= SUN_R * SUN_R else GLOW
    return im


def save(im, name, suffix):
    sheet = Image.new("RGBA", (256, 128), (0, 0, 0, 255))
    sheet.paste(im, (0, 0))
    sheet.save(MEDIA / (name + suffix + ".png"), optimize=True)
    print(im.size, "->", MEDIA / (name + suffix + ".png"))
    if len(sys.argv) > 2:
        im.resize((W * 2, H * 2), Image.NEAREST).save(Path(sys.argv[2]) / (name + suffix + ".png"))


if __name__ == "__main__":
    main()
