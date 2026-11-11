"""Writes the companion's sprites: for each form, standing, mid-step and asleep.

Writes the companion's sprites to jsalUI/Media/Pet: each creature drawn from shapes on a
32 x 32 grid, shaded with the light from the upper left, and outlined in a dark tone of the
colour beside it. Original creatures, drawn for jsal.ui.

Run from the repo root: python tools/make_pets.py
A second argument writes large previews there too, for looking at: python tools/make_pets.py <folder>
"""
import sys
from pathlib import Path

from PIL import Image

N = 32
K = (21, 22, 27)
W = (255, 255, 255)


def hx(s):
    return tuple(int(s[i:i + 2], 16) for i in (1, 3, 5))


class G:
    def __init__(self):
        self.g = [[None] * N for _ in range(N)]

    def P(self, x, y, c):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < N and 0 <= y < N:
            self.g[y][x] = hx(c) if isinstance(c, str) else c

    def E(self, cx, cy, rx, ry, c):
        for y in range(N):
            for x in range(N):
                if ((x + .5 - cx) / rx) ** 2 + ((y + .5 - cy) / ry) ** 2 <= 1:
                    self.P(x, y, c)

    def R(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.P(x, y, c)

    def T(self, ax, ay, bx, by, cx, cy, c):
        def s(px, py, qx, qy, rx, ry):
            return (px - rx) * (qy - ry) - (qx - rx) * (py - ry)
        for y in range(N):
            for x in range(N):
                px, py = x + .5, y + .5
                d = (s(px, py, ax, ay, bx, by), s(px, py, bx, by, cx, cy), s(px, py, cx, cy, ax, ay))
                if not (min(d) < 0 and max(d) > 0):
                    self.P(x, y, c)

    def at(self, x, y):
        return self.g[y][x] if 0 <= x < N and 0 <= y < N else None

    def shade(self):
        def mix(c, to, t):
            return tuple(int(round(v + (to - v) * t)) for v in c)
        out = [row[:] for row in self.g]
        for y in range(N):
            for x in range(N):
                c = self.g[y][x]
                if not c:
                    continue
                if not self.at(x + 1, y + 1) or not self.at(x + 2, y + 2) or not self.at(x, y + 1):
                    out[y][x] = mix(c, 0, .26)
                elif not self.at(x - 1, y - 1) or not self.at(x - 2, y - 2):
                    out[y][x] = mix(c, 255, .2)
        self.g = out

    def outline(self):
        add = []
        for y in range(N):
            for x in range(N):
                if self.g[y][x]:
                    continue
                n = self.at(x, y - 1) or self.at(x, y + 1) or self.at(x - 1, y) or self.at(x + 1, y)
                if n:
                    add.append((x, y, tuple(int(v * .34) for v in n)))
        for x, y, c in add:
            self.g[y][x] = c

    def finish(self):
        self.shade()
        self.outline()

    def image(self):
        im = Image.new("RGBA", (N, N), (0, 0, 0, 0))
        for y in range(N):
            for x in range(N):
                if self.g[y][x]:
                    im.putpixel((x, y), self.g[y][x] + (255,))
        return im


def briarboar(g, step=False, sleep=False):
    brown, dark, light, cream, pink = "#a8683c", "#7d4a2a", "#c98a55", "#f0dcb8", "#e59a8a"
    green, dgreen = "#5fae57", "#3f8f4a"
    # far ear, back ridge of leaf-thorns, tail
    g.T(6.5, 12, 5, 6.5, 10, 9.5, dark)
    g.T(16.5, 13, 18, 8.5, 19.8, 13, green)
    g.T(19.5, 13.3, 21.3, 9, 23, 13.6, dgreen)
    g.T(22.6, 14.2, 24.4, 10.5, 25.8, 15, green)
    g.P(27, 19, dark); g.P(28, 18, dark); g.P(29, 18, dark)
    g.E(29.6, 16.2, 1.8, 1.6, green)
    # hind leg, body, belly
    # a step: the far front leg lifts and the others shift, so two frames read as walking
    far, near, hind = ((8, 10, 28), (15, 18, 29), (21, 24, 29)) if step else ((9, 11, 29), (14, 17, 29), (22, 25, 29))
    g.R(hind[0], 24, hind[1], hind[2], dark)
    g.E(20, 20, 7.6, 6.6, brown)
    # front legs
    g.R(far[0], 25, far[1], far[2], brown)
    g.R(near[0], 25, near[1], near[2], brown)
    # near ear, head
    g.T(13, 10.5, 16.5, 5.5, 18, 12, brown)
    g.E(12, 17, 7.6, 7.2, light)
    g.finish()
    # inner ear, muzzle, snout, belly: flat details over the shading
    g.T(14, 10.6, 16.2, 7.4, 16.8, 11.4, pink)
    g.E(9.5, 21, 4.2, 3, cream)
    g.E(8.4, 20.6, 2.6, 1.9, pink)
    g.P(7, 20, K); g.P(9, 20, K)
    # the belly shows only between the front and hind legs
    g.E(19.8, 24.3, 2.1, 1.7, cream)
    # hooves
    for x0, x1, y in (far, near, hind):
        g.R(x0, y, x1, y, dark)
    # little tusks
    g.R(5, 21, 5, 22, W); g.R(12, 22, 12, 23, W)
    # eyes: tall and dark, a white glint at the top
    if sleep:
        # asleep: each eye a closed line
        g.P(6, 17, K); g.R(12, 17, 13, 17, K)
    else:
        g.R(6, 15, 6, 17, K); g.P(6, 15, W)
        g.R(12, 15, 13, 17, K); g.P(12, 15, W)
    # a small smile
    g.P(9, 23, dark); g.P(10, 23, dark); g.P(11, 22, dark)


def thornhog(g, step=False, sleep=False):
    """The grown form: bigger, a longer ridge of four thorns, bigger tusks, a brow."""
    brown, dark, light, cream, pink = "#a8683c", "#7d4a2a", "#c98a55", "#f0dcb8", "#e59a8a"
    green, dgreen = "#5fae57", "#3f8f4a"
    g.T(6, 11.5, 5, 6.5, 9.5, 9, brown)
    g.T(15, 12, 17, 6, 19, 12, green)
    g.T(18.5, 11.5, 21, 5.5, 23, 12, dgreen)
    g.T(22, 12.5, 25, 7.5, 26.5, 14, green)
    g.T(25.5, 15, 28.5, 11.5, 29, 17.5, dgreen)
    g.P(29, 21, dark); g.P(30, 20, dark)
    g.E(30.2, 18.4, 1.5, 1.5, green)
    far, near, hind = ((7, 10, 29), (15, 18, 30), (22, 26, 30)) if step else ((8, 11, 30), (14, 17, 30), (23, 27, 30))
    g.R(hind[0], 25, hind[1], hind[2], dark)
    g.E(21, 19.5, 8.6, 7.6, brown)
    g.R(far[0], 25, far[1], far[2], brown)
    g.R(near[0], 26, near[1], near[2], brown)
    g.T(12.5, 10, 16, 4.5, 17.5, 11.5, brown)
    g.E(11.5, 16, 7.6, 7.4, light)
    g.finish()
    g.T(13.5, 10, 15.7, 6.4, 16.3, 10.8, pink)
    g.E(9, 20.2, 4.4, 3.1, cream)
    g.E(7.9, 19.8, 2.7, 2, pink)
    g.P(6, 19, K); g.P(8, 19, K)
    g.E(20.6, 25, 2, 1.6, cream)
    for x0, x1, y in (far, near, hind):
        g.R(x0, y, x1, y, dark)
    g.R(4, 20, 5, 22, W); g.P(4, 19, W)
    g.R(12, 21, 13, 23, W); g.P(13, 20, W)
    if sleep:
        g.P(5, 16, K); g.R(11, 16, 12, 16, K)
    else:
        g.R(5, 14, 5, 16, K); g.P(5, 14, W)
        g.R(11, 14, 12, 16, K); g.P(11, 14, W)
        g.P(4, 12, K); g.P(5, 13, K); g.P(6, 13, K)
        g.P(10, 13, K); g.P(11, 13, K); g.P(12, 12, K); g.P(13, 12, K)
    g.P(8, 22, dark); g.P(9, 22, dark); g.P(10, 22, dark)


def brambletusk(g, step=False, sleep=False):
    """Fully grown: three tall thorns tipped in pale wood, a dark crest, tusks that curve up."""
    brown, dark, light, cream, pink = "#96592f", "#6b3f22", "#b97a48", "#ead2aa", "#d98a7a"
    green, dgreen, thorn = "#4f9a52", "#2f7a3a", "#d9c48a"
    g.T(5.5, 11, 4, 5.5, 9, 8.5, brown)
    g.T(13.5, 10.5, 16.5, 1.5, 19.5, 10.5, dgreen)
    g.T(18.5, 10, 22.5, 1, 25, 11, green)
    g.T(24, 12, 28.5, 5, 29.5, 14.5, dgreen)
    g.P(30, 21, dark); g.P(31, 20, dark)
    far, near, hind = ((6, 10, 29), (15, 19, 30), (22, 27, 30)) if step else ((7, 11, 30), (14, 18, 30), (23, 28, 30))
    g.R(hind[0], 25, hind[1], hind[2], dark)
    g.E(21.5, 18.5, 9.5, 8.5, brown)
    g.R(far[0], 25, far[1], far[2], brown)
    g.R(near[0], 26, near[1], near[2], brown)
    g.T(12, 9.5, 15.5, 3.5, 17.5, 11, brown)
    g.E(11, 16, 8, 7.8, light)
    g.T(8.5, 9.6, 10.5, 5, 12.5, 9.4, dark)
    g.finish()
    g.T(13.2, 9.6, 15.3, 5.6, 16.2, 10.3, pink)
    g.E(8.5, 20.6, 4.8, 3.3, cream)
    g.E(7.4, 20.2, 2.9, 2.1, pink)
    g.P(5, 19, K); g.P(8, 19, K)
    g.E(20.8, 25.6, 2, 1.4, cream)
    for x0, x1, y in (far, near, hind):
        g.R(x0, y, x1, y, dark)
    for x, y in ((4, 23), (4, 22), (3, 22), (3, 21), (3, 20), (2, 20), (2, 19), (2, 18)):
        g.P(x, y, W)
    for x, y in ((12, 24), (12, 23), (13, 23), (13, 22), (13, 21), (14, 21), (14, 20), (14, 19)):
        g.P(x, y, W)
    g.P(16, 3, thorn); g.P(22, 2, thorn); g.P(28, 6, thorn)
    if sleep:
        g.P(5, 15, K); g.R(11, 15, 12, 15, K)
    else:
        g.R(5, 14, 5, 15, K); g.P(5, 14, W)
        g.R(11, 14, 12, 15, K); g.P(11, 14, W)
        g.P(3, 11, K); g.P(4, 12, K); g.P(5, 13, K); g.P(6, 13, K)
        g.P(10, 13, K); g.P(11, 13, K); g.P(12, 12, K); g.P(13, 11, K)
    g.P(8, 23, dark); g.P(9, 23, dark); g.P(10, 23, dark)


def preview(g, path):
    im = g.image()
    card = Image.new("RGBA", (352, 272), (38, 42, 51, 255))
    card.alpha_composite(im.resize((256, 256), Image.NEAREST), (8, 8))
    card.alpha_composite(im.resize((64, 64), Image.NEAREST), (276, 8))
    card.alpha_composite(im, (292, 88))
    card.save(path)


# Each file and how it's drawn.
SPRITES = {}
for _name, _draw in (("briarboar", briarboar), ("thornhog", thornhog), ("brambletusk", brambletusk)):
    SPRITES[_name] = lambda g, d=_draw: d(g)
    SPRITES[_name + "_step"] = lambda g, d=_draw: d(g, step=True)
    SPRITES[_name + "_sleep"] = lambda g, d=_draw: d(g, sleep=True)

if __name__ == "__main__":
    out = Path(__file__).resolve().parent.parent / "jsalUI" / "Media" / "Pet"
    out.mkdir(parents=True, exist_ok=True)
    for name, draw in SPRITES.items():
        g = G()
        draw(g)
        g.image().save(out / (name + ".tga"))
        if len(sys.argv) > 1:
            preview(g, str(Path(sys.argv[1]) / (name + ".png")))
        print("wrote", name)
