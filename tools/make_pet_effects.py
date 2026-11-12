"""Builds the pictures drawn over any companion: dirty, poorly, and having a bath.

    python -I tools/make_pet_effects.py <washtub.png> [preview folder]

Writes jsalUI/Media/Pet/effects.png, 512 by 512: 64-pixel cells, eight to a
row, each drawn over the 64 pixels a creature stands in (so at its size).
The same pictures do for every kind, so nothing here knows a creature's
shape: everything sits round it or in front of its lower half.

  row 0      dirty, eight frames round and round: three flies circling it and
             two wavy lines of smell rising off it. (The creature itself is
             tinted muddy by the pen.)
  row 1      poorly, eight frames round and round: three dizzy stars circling
             over its head and a bead of sweat running down.
  rows 2-3   a bath, sixteen frames played once: a washtub of suds comes up
             in front of it (0-2), bubbles rise and foam scrubs about (3-10),
             the tub goes down again (11-12), and it's left sparkling (12-15).

  rows 4-5   getting well, sixteen frames played once: green crosses float
             up round it (0-7), a ring of light sweeps up it from its feet
             (4-10), and two hearts pop over its head among twinkles (10-15).

Also writes mud_mask.png, 64 square: where the mud is on a dirty creature.
And shadow.png, 64 by 16 with a 40 by 10 oval in its corner: what the creature
stands on when it is out of its window.
The pen draws the creature a second time, dark and brown, and shows that
only where this picture is solid: so the splotches are always on the
creature and never beside it, whatever its shape or pose. White where
there's mud, clear elsewhere: a couple of dozen blobs, thicker low down,
some with a drip, the same every run.

<washtub.png> is the one drawn thing (a Pro Flash object); it is never
scaled, only slid up from the ground line and cut off there. The rest is a
few pixels each, drawn here.
"""
import math
import random
import sys
from pathlib import Path

from PIL import Image

CELL, COLS = 64, 8
GROUND = 61             # the row a creature's feet stand on, about
MEDIA = Path(__file__).resolve().parent.parent / "jsalUI" / "Media" / "Pet"
FLY, WING = (38, 34, 40, 255), (200, 205, 215, 255)
SMELL = ((122, 140, 58, 255), (150, 166, 84, 200), (150, 166, 84, 110))
STAR, STAR_PALE = (255, 220, 90, 255), (255, 246, 190, 255)
SWEAT, SWEAT_PALE = (110, 190, 245, 255), (215, 240, 255, 255)
SUD, SUD_SHADE, BUBBLE = (255, 255, 255, 255), (198, 222, 240, 255), (150, 205, 240, 255)
SHINE, SHINE_PALE = (255, 255, 255, 255), (255, 240, 170, 255)


def blank():
    return Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))


def dot(px, x, y, colour):
    x, y = int(round(x)), int(round(y))
    if 0 <= x < CELL and 0 <= y < CELL:
        px[x, y] = colour


def dirty(i):
    cell = blank()
    px = cell.load()
    # Smell: two wavy lines that climb and thin out, one a half turn behind the other.
    for x0, lag in ((17, 0), (47, 4)):
        climb = (i + lag) % 8
        for k in range(7):
            y = 26 - climb * 2 - k
            x = x0 + (1 if (k + climb) % 4 < 2 else 0)
            dot(px, x, y, SMELL[min(2, (climb + k) // 5)])
            dot(px, x + 1, y, SMELL[min(2, (climb + k) // 5)])
    # Flies: a dark body and a wing that beats, each on its own loop round the creature.
    for n, (rx, ry, cy) in enumerate(((24, 9, 24), (19, 13, 34), (27, 6, 40))):
        turn = (i / 8 + n / 3) * 2 * math.pi * (1 if n % 2 == 0 else -1)
        x, y = 32 + rx * math.cos(turn), cy + ry * math.sin(turn)
        for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1), (2, 0)):
            dot(px, x + dx, y + dy, FLY)
        # Wings up on one frame, out to the sides on the next.
        if (i + n) % 2 == 0:
            dot(px, x, y - 1, WING)
            dot(px, x + 1, y - 1, WING)
            dot(px, x + 1, y - 2, WING)
        else:
            dot(px, x - 1, y - 1, WING)
            dot(px, x + 2, y - 1, WING)
    return cell


def star(px, x, y, big):
    dot(px, x, y, STAR_PALE)
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        dot(px, x + dx, y + dy, STAR)
    if big:
        for dx, dy in ((2, 0), (-2, 0), (0, 2), (0, -2)):
            dot(px, x + dx, y + dy, STAR)


def poorly(i):
    cell = blank()
    px = cell.load()
    # Stars going round over its head: the ones at the front of the ring are larger.
    for n in range(3):
        turn = (i / 8 + n / 3) * 2 * math.pi
        star(px, 32 + 15 * math.cos(turn), 12 + 4 * math.sin(turn), math.sin(turn) > 0)
    # A bead of sweat that runs down beside its face and drops away.
    y = 22 + i * 2
    if i < 7:
        dot(px, 49, y - 1, SWEAT_PALE)
        dot(px, 49, y, SWEAT)
        dot(px, 49, y + 1, SWEAT)
        dot(px, 48, y + 1, SWEAT)
        dot(px, 50, y + 1, SWEAT)
    return cell


def bubble(px, x, y, r):
    for a in range(16):
        dot(px, x + r * math.cos(a * math.pi / 8), y + r * math.sin(a * math.pi / 8), BUBBLE)
    dot(px, x - r * 0.4, y - r * 0.4, SUD)


def puff(px, x, y):
    for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, -1), (2, 0), (1, -1), (-1, -1), (0, -2), (1, 1), (0, 1)):
        dot(px, x + dx, y + dy, SUD)
    dot(px, x + 2, y + 1, SUD_SHADE)
    dot(px, x - 1, y + 1, SUD_SHADE)


def twinkle(px, x, y, size):
    dot(px, x, y, SHINE)
    for d in range(1, size + 1):
        for dx, dy in ((d, 0), (-d, 0), (0, d), (0, -d)):
            dot(px, x + dx, y + dy, SHINE if d < size else SHINE_PALE)
    if size >= 3:
        for dx, dy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
            dot(px, x + dx, y + dy, SHINE_PALE)


UP = (0.34, 0.67, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0.67, 0.34, 0, 0, 0)
TWINKLES = ((14, 20, 12), (50, 16, 12), (32, 8, 13), (10, 40, 13), (54, 38, 13), (22, 30, 14), (44, 28, 14), (32, 46, 14))


def bath(i, tub):
    cell = blank()
    px = cell.load()
    rng = random.Random(7)
    if 3 <= i <= 10:
        # Foam scrubbing about its middle, in two places by turns.
        for x, y in (((20, 30), (42, 24), (31, 20)), ((26, 22), (45, 32), (17, 26)))[i % 2]:
            puff(px, x, y)
        # Bubbles on their way up, each from its own place and a little out of step.
        for _ in range(7):
            x0, start, r = rng.randrange(10, 54), rng.randrange(0, 8), rng.choice((2, 2, 3))
            age = (i - 3 - start) % 8
            bubble(px, x0 + (1 if age % 4 < 2 else -1), 40 - age * 5, r)
    shown = int(round(tub.height * UP[i]))
    if shown:
        cell.alpha_composite(tub.crop((0, 0, tub.width, shown)), ((CELL - tub.width) // 2, GROUND - shown))
    for x, y, first in TWINKLES:
        if i - first in (0, 1) or (i == 15 and first == 14):
            twinkle(px, x, y, 3 if i - first == 1 else 2)
    return cell


CROSS, CROSS_PALE = (96, 210, 120, 255), (214, 250, 220, 255)
RING, RING_PALE = (190, 250, 200, 255), (255, 255, 255, 255)
HEART, HEART_PALE, HEART_DARK = (245, 110, 150, 255), (255, 200, 215, 255), (150, 50, 90, 255)
CROSSES = ((14, 0), (48, 1), (30, 2), (20, 3), (44, 4))    # where each starts, and on which frame
HEART_SHAPE = (" ## ## ", "#######", "#######", " ##### ", "  ###  ", "   #   ")


def cross(px, x, y, faint):
    """A plump green cross with a dark edge, so it shows against the grass."""
    shape = [(dx, dy) for dx in range(-3, 4) for dy in range(-3, 4) if abs(dx) <= 1 or abs(dy) <= 1]
    edge = (24, 92, 52, 130 if faint else 255)
    fill = (CROSS[0], CROSS[1], CROSS[2], 150 if faint else 255)
    for dx, dy in shape:
        for ex, ey in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            dot(px, x + dx + ex, y + dy + ey, edge)
    for dx, dy in shape:
        dot(px, x + dx, y + dy, fill)
    if not faint:
        dot(px, x, y, CROSS_PALE)
        dot(px, x - 1, y - 1, CROSS_PALE)


def heart(px, x, y):
    for row, line in enumerate(HEART_SHAPE):
        for col, mark in enumerate(line):
            if mark == "#":
                dot(px, x - 3 + col, y - 2 + row, HEART)
    dot(px, x - 2, y - 1, HEART_PALE)
    dot(px, x - 1, y - 1, HEART_PALE)
    dot(px, x, y + 4, HEART_DARK)


def well(i):
    cell = blank()
    px = cell.load()
    for x, first in CROSSES:
        age = i - first
        if 0 <= age <= 4:
            cross(px, x + (1 if age % 2 else 0), 46 - age * 7, age == 4)
    if 4 <= i <= 10:
        # The ring: the front half of a flat hoop, climbing from its feet to over its head.
        y = 56 - (i - 4) * 8
        for a in range(0, 33):
            turn = a / 32 * math.pi
            x = 32 - 24 * math.cos(turn)
            dot(px, x, y + 4 * math.sin(turn) + 1, RING)
            dot(px, x, y + 4 * math.sin(turn), RING_PALE)
    if i >= 10:
        rise = (i - 10) // 2
        heart(px, 22, 14 - rise)
        if i >= 12:
            heart(px, 42, 10 - (i - 12) // 2)
    for x, y, first in ((12, 26, 11), (52, 22, 12), (32, 34, 13), (16, 44, 14), (50, 42, 14)):
        if i - first in (0, 1) or (i == 15 and first == 14):
            twinkle(px, x, y, 3 if i - first == 1 else 2)
    return cell


def mud_mask():
    mask = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    px = mask.load()
    rng = random.Random(11)
    made = 0
    while made < 26:
        x, y = rng.randrange(4, 60), rng.randrange(8, 62)
        # More of it low down, where mud would be.
        if rng.random() > 0.35 + 0.65 * y / 62:
            continue
        made += 1
        r = rng.choice((1, 2, 2, 3))
        for dy in range(-r, r + 1):
            for dx in range(-r - 1, r + 2):
                if dx * dx * 0.7 + dy * dy <= r * r + rng.random():
                    dot(px, x + dx, y + dy, (255, 255, 255, 255))
        if rng.random() < 0.4:
            for d in range(1, rng.randrange(2, 5)):
                dot(px, x, y + r + d, (255, 255, 255, 255))
    return mask


def shadow():
    """The shadow under the creature when it is out of its window: a flat
    oval, 40 by 10, darker in the middle, so it stands on something."""
    im = Image.new("RGBA", (64, 16), (0, 0, 0, 0))
    for y in range(10):
        for x in range(40):
            far = ((x - 19.5) / 20) ** 2 + ((y - 4.5) / 5) ** 2
            if far <= 1:
                im.putpixel((x, y), (0, 0, 0, 110 if far < 0.45 else 60))
    return im


def main():
    tub = Image.open(sys.argv[1]).convert("RGBA")
    tub = tub.crop(tub.getbbox())
    sheet = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    cells = ([dirty(i) for i in range(8)] + [poorly(i) for i in range(8)] + [bath(i, tub) for i in range(16)]
             + [well(i) for i in range(16)])
    for n, cell in enumerate(cells):
        sheet.paste(cell, (n % COLS * CELL, n // COLS * CELL))
    sheet.save(MEDIA / "effects.png", optimize=True)
    mud_mask().save(MEDIA / "mud_mask.png", optimize=True)
    shadow().save(MEDIA / "shadow.png", optimize=True)
    print(len(cells), "cells ->", MEDIA / "effects.png")
    if len(sys.argv) > 2:
        look = Image.new("RGBA", sheet.size, (42, 47, 58, 255))
        look.alpha_composite(sheet)
        look = look.crop((0, 0, 512, 384))
        look.resize((look.width * 3, look.height * 3), Image.NEAREST).save(Path(sys.argv[2]) / "effects.png")


if __name__ == "__main__":
    main()
