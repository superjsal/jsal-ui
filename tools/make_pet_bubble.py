"""Draws the companion's thought bubbles.

    python -I tools/make_pet_bubble.py [preview folder]

Writes jsalUI/Media/Pet/bubble.png, 256 by 32: eight 32-pixel cells in a
row, each a small white bubble with a tail and one sign in it for what's on
its mind, in the order BUBBLES in jsalUI/Pet/Pet.lua counts them:

  0 hungry (a bowl)   1 scoop (a dropping)   2 dirty (a drop of water)
  3 bored (a ball)    4 poorly (a cross)     5 a wish (a star)
  6 your bags are nearly full (a bag)        7 spare

All drawn here, a pixel at a time.
"""
import sys
from pathlib import Path

from PIL import Image

MEDIA = Path(__file__).resolve().parent.parent / "jsalUI" / "Media" / "Pet"
INK, PAPER, SHADE = (46, 40, 52, 255), (250, 246, 236, 255), (214, 206, 196, 255)
COLOURS = {
    "#": INK, "b": (150, 96, 52, 255), "y": (236, 190, 70, 255), "r": (214, 72, 66, 255),
    "g": (96, 168, 88, 255), "w": (96, 160, 226, 255), "p": (226, 120, 170, 255), "o": (232, 140, 60, 255),
}
# Each sign is ten rows of ten.
SIGNS = [
    # a bowl with food in it
    ["..........", "..........", "...oyo....", "..oyoyoy..", ".########.", ".#bbbbbb#.", ".#bbbbbb#.", "..#bbbb#..", "...####...", ".........."],
    # a dropping
    ["..........", "....##....", "...#bb#...", "...#bb#...", "..#bbbb#..", "..#bbbb#..", ".#bbbbbb#.", ".#bbbbbb#.", ".########.", ".........."],
    # a drop of water
    ["....#.....", "...#w#....", "...#w#....", "..#www#...", "..#www#...", ".#wwwww#..", ".#wwwww#..", ".#wwwww#..", "..#www#...", "...###...."],
    # a ball
    ["..........", "...####...", "..#rryy#..", ".#rrryyy#.", ".#rrryyy#.", ".#yyyrrr#.", ".#yyyrrr#.", "..#yyrr#..", "...####...", ".........."],
    # a cross, for medicine
    ["..........", "...####...", "...#gg#...", ".###gg###.", ".#gggggg#.", ".#gggggg#.", ".###gg###.", "...#gg#...", "...####...", ".........."],
    # a star, for a wish
    ["....##....", "....#y#...", "...#yy#...", "####yy####", "#yyyyyyyy#", ".#yyyyyy#.", "..#yyyy#..", ".#yy##yy#.", ".#y#..#y#.", ".##....##."],
    # a bag
    ["..........", "...####...", "..#....#..", ".########.", ".#bbbbbb#.", ".#bb##bb#.", ".#bbbbbb#.", ".#bbbbbb#.", ".########.", ".........."],
    # spare: three dots
    ["..........", "..........", "..........", "..........", ".##.##.##.", ".##.##.##.", "..........", "..........", "..........", ".........."],
]
# The bubble itself, 26 wide and 22 tall, its tail at the lower left.
LEFT, TOP, WIDE, TALL = 3, 2, 26, 18


def bubble():
    im = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    for y in range(TALL):
        for x in range(WIDE):
            corner = (x in (0, WIDE - 1) and y in (0, TALL - 1)) or (x in (0, WIDE - 1) and y in (1, TALL - 2) and False)
            if corner:
                continue
            edge = x in (0, WIDE - 1) or y in (0, TALL - 1) or (x in (1, WIDE - 2) and y in (1, TALL - 2))
            inner_corner = x in (1, WIDE - 2) and y in (1, TALL - 2)
            im.putpixel((LEFT + x, TOP + y), INK if edge and not (inner_corner and False) else (SHADE if y >= TALL - 3 else PAPER))
    # The tail: three small steps down to the left, toward the creature's head.
    for i, (x, y) in enumerate(((7, 18), (6, 19), (5, 20), (4, 21))):
        im.putpixel((LEFT + x, TOP + y), INK)
        if i < 3:
            im.putpixel((LEFT + x + 1, TOP + y), PAPER if i == 0 else INK)
    im.putpixel((LEFT + 8, TOP + 17), PAPER)
    im.putpixel((LEFT + 9, TOP + 17), PAPER)
    return im


def main():
    sheet = Image.new("RGBA", (256, 32), (0, 0, 0, 0))
    for i, sign in enumerate(SIGNS):
        cell = bubble()
        for y, row in enumerate(sign):
            assert len(row) == 10, (i, y, row)
            for x, c in enumerate(row):
                if c != ".":
                    cell.putpixel((LEFT + 8 + x, TOP + 4 + y), COLOURS[c])
        sheet.paste(cell, (i * 32, 0))
    sheet.save(MEDIA / "bubble.png", optimize=True)
    print("bubble.png", len(SIGNS))
    if len(sys.argv) > 1:
        look = Image.new("RGBA", sheet.size, (70, 110, 70, 255))
        look.alpha_composite(sheet)
        look.resize((256 * 4, 32 * 4), Image.NEAREST).save(Path(sys.argv[1]) / "bubble.png")


if __name__ == "__main__":
    main()
