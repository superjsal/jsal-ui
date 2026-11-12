"""Builds a hatchling's hatching animation and its egg's own picture.

    python -I tools/make_pet_hatch.py <name> <egg.png> [preview folder]

<egg.png> is the egg as it was drawn, on any canvas. The hatchling is taken
standing from the first cell of jsalUI/Media/Pet/<name>_special.tga, which
tools/make_pet_sheet.py must have written first, so it stands exactly where
it does in its special. Writes, beside it:

  <name>_hatch.tga   1024 by 128, ten 96-pixel cells in a row:
                     0     the egg, still, where the hatchling will stand
                     1-2   it rocks left, then right
                     3-4   rocking again, a jagged saw-tooth crack across
                           it, then a longer one with cracks running off it
                     5     it hops, cracked right across
                     6     the top of the shell pops up and the hatchling
                           shows out of the jagged bottom half
                     7     it stands in the broken bottom half, the top
                           tumbling off to one side
                     8     the bottom half falls open in two and it all fades
                     9     the hatchling, standing
  <name>_egg.tga     64 square, the egg alone, standing on the bottom middle.

Nothing is scaled or turned: the egg rocks by sliding its rows sideways, and
the pieces of shell are the egg cut along the crack and moved.
"""
import sys
from pathlib import Path

from PIL import Image

SIDE, COUNT = 96, 10
MEDIA = Path(__file__).resolve().parent.parent / "jsalUI" / "Media" / "Pet"
WHITE, GLOW = (255, 255, 255, 255), (255, 244, 190, 255)


def rocked(egg, lean):
    """The egg with its rows slid sideways, most at the top: `lean` pixels there."""
    out = Image.new("RGBA", (egg.width + 8, egg.height), (0, 0, 0, 0))
    for y in range(egg.height):
        slide = round(lean * (egg.height - 1 - y) / (egg.height - 1))
        out.paste(egg.crop((0, y, egg.width, y + 1)), (4 + slide, y))
    return out


TEETH = (-3, -1, 1, 3, 1, -1)  # the crack's saw-teeth: three pixels up and down, six across


def crack_row(egg, x):
    """The row the crack runs along at column x: big saw-teeth a little above the middle."""
    return egg.height * 9 // 20 + TEETH[x % len(TEETH)]


def darkest(im):
    px = im.load()
    solid = [px[x, y] for y in range(im.height) for x in range(im.width) if px[x, y][3] > 200]
    return min(solid, key=lambda p: p[0] + p[1] + p[2])


def cracked(egg, reach):
    """The egg with the crack drawn `reach` of the way across in its darkest
    colour, an unbroken jagged line, and from most of the way across two
    short cracks running off it, one up and one down."""
    out = egg.copy()
    px = out.load()
    dark = darkest(egg)

    def mark(x, y):
        if 0 <= x < egg.width and 0 <= y < egg.height and px[x, y][3] > 0:
            px[x, y] = dark

    end = int(egg.width * reach)
    for x in range(end):
        here, before = crack_row(egg, x), crack_row(egg, max(0, x - 1))
        for y in range(min(here, before), max(here, before) + 1):
            mark(x, y)
    if reach >= 0.7:
        up, down = egg.width // 3, egg.width * 3 // 5
        for d in range(1, 5):
            mark(up + d // 2, crack_row(egg, up) - d)
            mark(down - d // 2, crack_row(egg, down) + d)
    return out


def halves(egg):
    """The egg cut along the crack: the top and the bottom, each with its
    broken edge drawn dark so the teeth show."""
    top, bottom = egg.copy(), egg.copy()
    tp, bp = top.load(), bottom.load()
    dark = darkest(egg)
    for x in range(egg.width):
        cut = crack_row(egg, x)
        beside = [crack_row(egg, n) for n in (x - 1, x + 1) if 0 <= n < egg.width]
        for y in range(egg.height):
            if y >= cut:
                tp[x, y] = (0, 0, 0, 0)
                if bp[x, y][3] > 0 and (y == cut or y < max(beside)):
                    bp[x, y] = dark
            else:
                bp[x, y] = (0, 0, 0, 0)
                if tp[x, y][3] > 0 and (y == cut - 1 or y >= min(beside)):
                    tp[x, y] = dark
    return top, bottom


def faint(im):
    out = im.copy()
    out.putalpha(out.getchannel("A").point(lambda a: a // 2))
    return out


def sparkle(cell, x, y, big):
    px = cell.load()
    for d in range(1, 3 if big else 2):
        for dx, dy in ((d, 0), (-d, 0), (0, d), (0, -d)):
            if 0 <= x + dx < SIDE and 0 <= y + dy < SIDE:
                px[x + dx, y + dy] = GLOW
    if 0 <= x < SIDE and 0 <= y < SIDE:
        px[x, y] = WHITE


def main():
    name = sys.argv[1]
    egg = Image.open(sys.argv[2]).convert("RGBA")
    egg = egg.crop(egg.getbbox())
    stand = Image.open(MEDIA / (name + "_special.tga")).convert("RGBA").crop((0, 0, SIDE, SIDE))
    box = stand.getbbox()
    mid, feet = (box[0] + box[2]) // 2, box[3]
    left, top = mid - egg.width // 2, feet - egg.height

    def blank():
        return Image.new("RGBA", (SIDE, SIDE), (0, 0, 0, 0))

    def with_egg(im, up=0):
        cell = blank()
        cell.alpha_composite(im, (left - (im.width - egg.width) // 2, top - up))
        return cell

    upper, lower = halves(egg)
    cut = egg.height * 9 // 20
    cells = [
        with_egg(egg),
        with_egg(rocked(egg, -2)),
        with_egg(rocked(egg, 2)),
        with_egg(rocked(cracked(egg, 0.45), -3)),
        with_egg(rocked(cracked(egg, 0.75), 3)),
        with_egg(cracked(egg, 1), up=3),
    ]
    # 6: the top of the shell pops up, tipped; the hatchling shows out of the
    # jagged bottom half, which stays on the ground in front of it.
    cell = blank()
    peek = stand.copy()
    peek.paste((0, 0, 0, 0), (0, top + cut + 4, SIDE, SIDE))
    cell.alpha_composite(peek)
    cell.alpha_composite(lower, (left, top))
    cap = rocked(upper, -3)
    cell.alpha_composite(cap, (left - 4 - 3, max(0, top - 10)))
    for dx, dy, big in ((-egg.width // 2 - 4, 0, True), (egg.width // 2 + 4, -2, True), (0, -egg.height // 2 - 8, True),
                        (-egg.width // 2, -12, False), (egg.width // 2 + 1, -14, False)):
        sparkle(cell, mid + dx, top + cut + dy, big)
    cells.append(cell)
    # 7: the hatchling stands in the broken bottom half; the top tumbles off to one side.
    cell = blank()
    cell.alpha_composite(stand)
    cell.alpha_composite(lower, (left, top))
    cap = rocked(upper, -5)
    cell.alpha_composite(cap, (max(0, left - 4 - 16), max(0, top - 14)))
    for dx, dy in ((-18, -30), (20, -34), (0, -44)):
        sparkle(cell, mid + dx, feet + dy, True)
    cells.append(cell)
    # 8: the bottom half falls open in two, the top lies on the ground, all of it fading.
    cell = blank()
    cell.alpha_composite(stand)
    half = egg.width // 2
    cell.alpha_composite(faint(lower.crop((0, 0, half, egg.height))), (max(0, left - 9), top + 1))
    cell.alpha_composite(faint(lower.crop((half, 0, egg.width, egg.height))), (min(SIDE - half, left + half + 9), top + 1))
    box = upper.getbbox()
    lid = faint(upper.crop(box))
    cell.alpha_composite(lid, (max(0, left - 26), feet - lid.height))
    for dx, dy in ((-26, -40), (27, -42), (-6, -52), (10, -20)):
        sparkle(cell, mid + dx, feet + dy, False)
    cells.append(cell)
    cells.append(stand)
    assert len(cells) == COUNT

    strip = Image.new("RGBA", (1024, 128), (0, 0, 0, 0))
    for i, cell in enumerate(cells):
        strip.paste(cell, (i * SIDE, 0))
    strip.save(MEDIA / (name + "_hatch.tga"), compression="tga_rle")
    alone = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    alone.paste(egg, ((64 - egg.width) // 2, 64 - egg.height))
    alone.save(MEDIA / (name + "_egg.tga"), compression="tga_rle")
    print("hatch ->", MEDIA / (name + "_hatch.tga"))
    if len(sys.argv) > 3:
        look = Image.new("RGBA", (COUNT * SIDE, SIDE), (42, 47, 58, 255))
        look.alpha_composite(strip.crop((0, 0, COUNT * SIDE, SIDE)))
        look.resize((look.width * 2, look.height * 2), Image.NEAREST).save(Path(sys.argv[3]) / (name + "_hatch.png"))


if __name__ == "__main__":
    main()
