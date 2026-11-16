"""Draws the companion's thought bubbles, the little things it finds, and the letter it carries.

    python -I tools/make_pet_bubble.py [preview folder]

Writes jsalUI/Media/Pet/bubble.png, 256 by 128: 32-pixel cells, eight to a
row, each a small white bubble with a tail and one sign in it for what's on
its mind, in the order BUBBLES in jsalUI/Pet/Pet.lua counts them:

  0 hungry (a bowl)   1 scoop (a dropping)   2 dirty (a drop of water)
  3 bored (a ball)    4 poorly (a cross)     5 a wish (a star)
  6 your bags are nearly full (a bag)        7 three dots (someone whispered you)
  8 a letter (mail has come)
  9 on: each thing it can find and bring you, in the order of Rules.TRINKETS
    in jsalUI/Pet/PetRules.lua (TRINKETS below)

Also jsalUI/Media/Pet/trinkets.png, 256 by 16: the same things on their own,
16-pixel cells in the same order, for the shelf on its page; and letter.png,
32 by 32, the letter it carries when mail comes (a prop, like its bowl).

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
    "G": (150, 152, 164, 255), "L": (205, 208, 216, 255), "W": (255, 255, 255, 255), "c": (198, 118, 64, 255),
    "B": (182, 216, 242, 255), "P": (248, 204, 216, 255), "d": (106, 70, 42, 255), "Y": (255, 236, 160, 255),
    "D": (58, 124, 62, 255),
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
    # three dots: someone has whispered you
    ["..........", "..........", "..........", "..........", ".##.##.##.", ".##.##.##.", "..........", "..........", "..........", ".........."],
    # a letter: mail has come
    ["..........", "..........", "##########", "#WWWWWWWW#", "##WWWWWW##", "#W##WW##W#", "#WWW##WWW#", "#WWWWWWWW#", "##########", ".........."],
]
# The things it can find, in the order of Rules.TRINKETS.
TRINKETS = [
    ("pebble", ["..........", "...####...", "..#WLGG#..", ".#WLGGGG#.", ".#LGGGGG#.", ".#GGGGGG#.", ".#GGGGGG#.", "..#GGGG#..", "...####...", ".........."]),
    ("feather", ["........##", ".......#B#", "......#Bw#", ".....#Bw#.", "....#Bw#..", "...#Bw#...", "..#Bw#....", "..###.....", ".#........", "#........."]),
    ("coin", ["..........", "...####...", "..#cccc#..", ".#cYcccb#.", ".#cYcccb#.", ".#ccccbb#.", ".#ccccbb#.", "..#bbbb#..", "...####...", ".........."]),
    ("acorn", ["....#.....", "...#d#....", "..######..", ".#dbbbbd#.", ".#dddddd#.", "..#oooo#..", "..#oYoo#..", "..#oooo#..", "...#oo#...", "....##...."]),
    ("shell", ["..........", "....##....", "...#PP#...", "..#PpPp#..", ".#PpPpPp#.", ".#PpPpPp#.", "..#PpPp#..", "...#pp#...", "..######..", ".........."]),
    ("ribbon", ["..........", ".##....##.", ".#r#..#r#.", ".#rr##rr#.", ".#rrrrrr#.", ".#rr##rr#.", ".#r#rr#r#.", "..#r##r#..", "..##..##..", ".........."]),
    ("button", ["..........", "...####...", "..#yyyy#..", ".#yYyyyy#.", ".#y#yy#y#.", ".#yyyyyy#.", ".#y#yy#y#.", "..#yyyy#..", "...####...", ".........."]),
    ("marble", ["..........", "...####...", "..#BBww#..", ".#BWBwww#.", ".#BBwwgw#.", ".#wwwggw#.", ".#wwggww#.", "..#wwww#..", "...####...", ".........."]),
    ("key", ["..........", ".###......", "#yYy#.....", "#y#y######", "#yYyyyyyy#", "#yyy##y#y#", ".###.#.#.#", "..........", "..........", ".........."]),
    ("leaf", ["........#.", ".....####.", "...##yyy#.", "..#yyYy#..", ".#yyYyy#..", ".#yYyyy#..", ".#Yyyy#...", "..####....", ".#........", "#........."]),
    ("bell", ["....##....", "...#yy#...", "..#yYyy#..", "..#yYyy#..", "..#yyyy#..", ".#yyyyyy#.", ".########.", "....#o#...", ".....#....", ".........."]),
    ("clover", ["..........", "..##..##..", ".#gg##gg#.", ".#gDggDg#.", "..##gg##..", ".#gD##Dg#.", ".#gg##gg#.", "..##.#....", ".....#....", "....#....."]),
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


def draw(cell, sign, x0, y0, scale=1):
    for y, row in enumerate(sign):
        assert len(row) == 10, (y, row)
        for x, c in enumerate(row):
            if c != ".":
                for dy in range(scale):
                    for dx in range(scale):
                        cell.putpixel((x0 + x * scale + dx, y0 + y * scale + dy), COLOURS[c])


def main():
    signs = SIGNS + [sign for _, sign in TRINKETS]
    sheet = Image.new("RGBA", (256, 128), (0, 0, 0, 0))
    for i, sign in enumerate(signs):
        cell = bubble()
        draw(cell, sign, LEFT + 8, TOP + 4)
        sheet.paste(cell, ((i % 8) * 32, (i // 8) * 32))
    sheet.save(MEDIA / "bubble.png", optimize=True)
    shelf = Image.new("RGBA", (256, 16), (0, 0, 0, 0))
    for i, (_, sign) in enumerate(TRINKETS):
        draw(shelf, sign, i * 16 + 3, 3)
    shelf.save(MEDIA / "trinkets.png", optimize=True)
    letter = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    draw(letter, SIGNS[8], 6, 10, 2)
    letter = letter.crop((0, 0, 32, 32))
    letter.save(MEDIA / "letter.png", optimize=True)
    print("bubble.png", len(signs), "trinkets.png", len(TRINKETS), "letter.png")
    if len(sys.argv) > 1:
        look = Image.new("RGBA", sheet.size, (70, 110, 70, 255))
        look.alpha_composite(sheet)
        look.resize((256 * 4, 128 * 4), Image.NEAREST).save(Path(sys.argv[1]) / "bubble.png")
        look = Image.new("RGBA", (256, 48), (70, 110, 70, 255))
        look.alpha_composite(shelf)
        look.alpha_composite(letter, (0, 16))
        look.resize((256 * 4, 48 * 4), Image.NEAREST).save(Path(sys.argv[1]) / "trinkets.png")


if __name__ == "__main__":
    main()
