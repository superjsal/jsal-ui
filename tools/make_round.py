# Writes jsalUI/Media/Round/r<N>.tga: a white square, 32 by 32, with its corners
# rounded to a radius of N pixels and smooth edges. Style.Round stretches one
# over a frame with its corners kept at their own size, and tints it, for a
# button, a card or a pill with round corners.
# And circle.tga: a white disc, 64 by 64, that Style.Circle draws whole at
# whatever size a round sign is.
#
# Run from the repo root: python -I tools/make_round.py
import os
import struct
from PIL import Image, ImageDraw

SIZE = 32
# One for each radius Style.lua asks for: a shape's line, and the fill a pixel inside it.
RADII = (4, 5, 6, 7, 8, 9, 10, 11, 12, 13)
OVER = 8    # drawn this many times too large, then shrunk, for the smooth edge

def tga(alpha):
    # A plain 32-bit TGA, rows from the top, as the game reads it: white, with the
    # shape in its alpha.
    head = bytearray(18)
    head[2] = 2
    struct.pack_into("<HH", head, 12, alpha.size[0], alpha.size[1])
    head[16] = 32
    head[17] = 8 | 32
    body = bytearray()
    for a in alpha.tobytes():
        body += bytes((255, 255, 255, a))
    return bytes(head) + bytes(body)

def main():
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "jsalUI", "Media", "Round")
    os.makedirs(out, exist_ok=True)
    for radius in RADII:
        big = Image.new("L", (SIZE * OVER, SIZE * OVER), 0)
        ImageDraw.Draw(big).rounded_rectangle((0, 0, SIZE * OVER - 1, SIZE * OVER - 1), radius * OVER, fill=255)
        alpha = big.resize((SIZE, SIZE), Image.LANCZOS)
        with open(os.path.join(out, "r%d.tga" % radius), "wb") as f:
            f.write(tga(alpha))
        print("r%d.tga" % radius)
    disc = 64
    big = Image.new("L", (disc * OVER, disc * OVER), 0)
    ImageDraw.Draw(big).ellipse((0, 0, disc * OVER - 1, disc * OVER - 1), fill=255)
    with open(os.path.join(out, "circle.tga"), "wb") as f:
        f.write(tga(big.resize((disc, disc), Image.LANCZOS)))
    print("circle.tga")

main()
