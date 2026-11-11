"""Writes the companion's sprites to jsalUI/Media/Pet: each creature drawn from shapes on a
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


def briarboar(g, step=False):
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
    g.R(6, 15, 6, 17, K); g.P(6, 15, W)
    g.R(12, 15, 13, 17, K); g.P(12, 15, W)
    # a small smile
    g.P(9, 23, dark); g.P(10, 23, dark); g.P(11, 22, dark)


def preview(g, path):
    im = g.image()
    card = Image.new("RGBA", (352, 272), (38, 42, 51, 255))
    card.alpha_composite(im.resize((256, 256), Image.NEAREST), (8, 8))
    card.alpha_composite(im.resize((64, 64), Image.NEAREST), (276, 8))
    card.alpha_composite(im, (292, 88))
    card.save(path)


# Each file and how it's drawn.
SPRITES = {
    "briarboar": lambda g: briarboar(g),
    "briarboar_step": lambda g: briarboar(g, step=True),
}

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
