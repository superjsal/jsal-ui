"""Builds the picture for a pal growing into its next form.

    python -I tools/make_pet_grow.py [preview folder]

Writes jsalUI/Media/Pet/grow.png, 1024 by 256: sixteen 128-pixel cells, eight
to a row, drawn over the creature and centred on the 64 pixels it stands in
(twice as wide and tall as those, so there is room round it). The same picture
does for every kind, so nothing here knows a creature's shape.

  0-6    light gathers: motes of gold drift in from all round and a ball of
         light grows over the creature until it is hidden.
  7      the ball at its fullest and brightest. The pen shows 7 and 6 in turn
         while the creature changes underneath.
  8-15   the ball bursts: a flash, a ring of light going outward, and
         twinkles flying off and fading, with the grown creature there.

Drawn here, a few colours, the same every run. Run
tools/shrink_pet_pngs.py afterwards.
"""
import math
import sys
from pathlib import Path

from PIL import Image

CELL, COLS = 128, 8
MIDDLE = (64, 68)       # the middle of the ball: a little under the middle of the creature
MEDIA = Path(__file__).resolve().parent.parent / "jsalUI" / "Media" / "Pet"
WHITE, PALE, LIGHT, GOLD = (255, 255, 255), (255, 247, 205), (255, 228, 130), (240, 186, 70)
GROWS = (3, 7, 12, 18, 25, 33, 44, 46)                  # how big the ball is in each of the first eight cells
FADE = (255, 255, 255, 255, 220, 170, 120, 70)          # how solid the twinkles are in each of the last eight


def blank():
    return Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))


def dot(im, x, y, colour, alpha=255):
    x, y = int(round(x)), int(round(y))
    if 0 <= x < CELL and 0 <= y < CELL:
        im.putpixel((x, y), colour + (alpha,))


def twinkle(im, x, y, arm, alpha=255):
    """A four-pointed twinkle, `arm` pixels each way; with no arm, a dot."""
    for d in range(1, arm + 1):
        shade = LIGHT if d < arm else GOLD
        for dx, dy in ((d, 0), (-d, 0), (0, d), (0, -d)):
            dot(im, x + dx, y + dy, shade, alpha)
    dot(im, x, y, WHITE if arm else PALE, alpha)


def ball(im, r, bright):
    """The ball of light: white at its heart, gold at its rim, and a thin
    haze round it. Solid all through, so what is under it is hidden."""
    cx, cy = MIDDLE
    heart = 0.75 if bright else 0.45
    for y in range(CELL):
        for x in range(CELL):
            far = math.hypot(x - cx, y - cy)
            if far <= r * heart:
                dot(im, x, y, WHITE)
            elif far <= r * (0.9 if bright else 0.75):
                dot(im, x, y, PALE)
            elif far <= r - 1.5:
                dot(im, x, y, LIGHT)
            elif far <= r:
                dot(im, x, y, GOLD)
            elif far <= r + 2 and (x + y) % 2 == 0:
                dot(im, x, y, LIGHT, 140)
            elif far <= r + 4 and x % 2 == 0 and y % 2 == 0:
                dot(im, x, y, LIGHT, 90)


def gather(i):
    im = blank()
    r = GROWS[i]
    cx, cy = MIDDLE
    # Ten motes going round and inward; each is gone once the ball reaches it.
    for k in range(10):
        turn = math.radians(k * 36 + i * 26)
        far = 60 - i * 7 + (k % 3) * 5
        if far > r + 5:
            twinkle(im, cx + math.cos(turn) * far, cy + math.sin(turn) * far * 0.9, 2 if k % 2 == 0 else 0)
    ball(im, r, i == 7)
    return im


def burst(j):
    im = blank()
    cx, cy = MIDDLE
    if j == 0:
        ball(im, 48, True)
        return im
    # What is left of the ball: a veil thinning over the creature, and a ring going outward.
    ring = ((52, 9, 255, 150), (56, 6, 255, 70), (60, 4, 200, 0), (63, 2, 140, 0))
    if j <= len(ring):
        r, thick, solid, veil = ring[j - 1]
        for y in range(CELL):
            for x in range(CELL):
                far = math.hypot(x - cx, y - cy)
                if r - thick <= far <= r:
                    sparse = j >= 3 and (x + y) % 2 == 1
                    if not sparse:
                        dot(im, x, y, PALE if far < r - thick / 2 else LIGHT, solid)
                elif far < r - thick and veil:
                    dot(im, x, y, WHITE, veil)
    # Twelve twinkles flying off, smaller and fainter as they go, and six more rising.
    arm = 3 if j < 3 else 2 if j < 5 else 1 if j < 7 else 0
    for k in range(12):
        turn = math.radians(k * 30 + 15)
        far = min(61, 26 + j * 5 + (k % 2) * 4)
        twinkle(im, cx + math.cos(turn) * far, cy + math.sin(turn) * far * 0.92, arm, FADE[j])
    for k in range(6):
        x = cx - 40 + k * 16 + (j % 2) * 2
        twinkle(im, x, cy + 10 - j * 6 - (k % 3) * 7, 1 if j < 6 else 0, FADE[j])
    return im


def main():
    cells = [gather(i) for i in range(8)] + [burst(j) for j in range(8)]
    sheet = Image.new("RGBA", (COLS * CELL, 2 * CELL), (0, 0, 0, 0))
    for n, cell in enumerate(cells):
        sheet.paste(cell, (n % COLS * CELL, n // COLS * CELL))
    sheet.save(MEDIA / "grow.png", optimize=True)
    print(len(cells), "cells ->", MEDIA / "grow.png")
    if len(sys.argv) > 1:
        look = Image.new("RGBA", sheet.size, (42, 47, 58, 255))
        look.alpha_composite(sheet)
        look.resize((look.width * 2, look.height * 2), Image.NEAREST).save(Path(sys.argv[1]) / "grow.png")


if __name__ == "__main__":
    main()
