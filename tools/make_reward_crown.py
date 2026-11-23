"""Writes jsalUI/Media/RewardCrown.tga: the gold crown on the best of a quest's rewards.

The shape is the Endgame tile's crown (tools/make_tile_icons.mjs, `endgame`: a band, three points, a ball
on each, in a 24-unit square), drawn on clear with what the game's own upgrade arrow has baked into its art,
so the crown sits beside the green arrows as their equal: a black rim about a pixel wide at 20, a soft black
shadow a touch low, and gold lit from the top, light at the balls to deeper at the band's foot. It's drawn in
full colour and shown untinted (Gear/RewardStar.lua), at 20 or 16, and inside the tooltip's line at 14.

64 by 64, 32-bit with alpha, drawn at 8 times and reduced.

Run from the repo root: python -I tools/make_reward_crown.py
"""
import os

from PIL import Image, ImageDraw, ImageFilter

N = 64
# The crown's own extent in its 24 units is x 1.1..22.9, y 2.4..20.2. It's drawn this many units across the 64,
# leaving room for the rim and the shadow.
SPAN = 31.0
# The gold from top to foot, by the 24-unit height.
RAMP = [(2.4, "f7d77a"), (9.0, "ebbd58"), (14.0, "e3b04b"), (20.2, "c18f33")]
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "jsalUI", "Media", "RewardCrown.tga")


def hexc(h):
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def unit_to_px(x, y, S):
    off = (SPAN - 24) / 2
    k = N * S / SPAN
    return (x + off) * k, (y + off - 0.4) * k


def crown_mask(S):
    """The crown's shape at S times its size."""
    m = Image.new("L", (N * S, N * S), 0)
    d = ImageDraw.Draw(m)
    k = N * S / SPAN

    def P(pts):
        return [unit_to_px(x, y, S) for x, y in pts]
    d.rectangle(P([(3.5, 17.2), (20.5, 20.2)]), fill=255)
    d.polygon(P([(3.5, 15.8), (2.6, 7.4), (7.8, 11.6), (12, 5.2), (16.2, 11.6), (21.4, 7.4), (20.5, 15.8)]), fill=255)
    for cx, cy, r in ((2.6, 6.4, 1.5), (12, 4, 1.6), (21.4, 6.4, 1.5)):
        x, y = unit_to_px(cx, cy, S)
        rr = r * k
        d.ellipse((x - rr, y - rr, x + rr, y + rr), fill=255)
    return m


def make_crown():
    S = 8
    big = N * S
    k = big / SPAN
    fill_mask = crown_mask(S)
    # The rim: the shape grown all round, drawn black under the gold.
    rim_mask = fill_mask.filter(ImageFilter.MaxFilter(int(round(1.4 * k)) | 1))
    # The shadow: the rim's shape a touch low, blurred, at 70%.
    shadow = Image.new("L", (big, big), 0)
    shadow.paste(rim_mask, (0, int(round(0.5 * k))))
    shadow = shadow.filter(ImageFilter.GaussianBlur(1.0 * k)).point(lambda v: int(v * 0.7))
    out = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    out.putalpha(shadow)
    rim = Image.new("RGBA", (big, big), (0, 0, 0, 255))
    rim.putalpha(rim_mask)
    out.alpha_composite(rim)
    grad = Image.new("RGBA", (big, big))
    gp = grad.load()
    pts = [(p, hexc(c)) for p, c in RAMP]
    for y in range(big):
        uy = y / k - (SPAN - 24) / 2 + 0.4
        c = pts[0][1] if uy <= pts[0][0] else pts[-1][1]
        for (p0, c0), (p1, c1) in zip(pts, pts[1:]):
            if p0 <= uy <= p1:
                t = (uy - p0) / (p1 - p0)
                c = tuple(c0[i] + (c1[i] - c0[i]) * t for i in range(3))
        col = tuple(int(round(v * 255)) for v in c) + (255,)
        for x in range(big):
            gp[x, y] = col
    grad.putalpha(fill_mask)
    out.alpha_composite(grad)
    return out.resize((N, N), Image.LANCZOS)


def main():
    make_crown().save(OUT)
    print("RewardCrown.tga")


if __name__ == "__main__":
    main()
