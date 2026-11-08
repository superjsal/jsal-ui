"""Writes jsalUI/Media/Shadow.tga: the soft shadow drawn around jsal.ui's windows.

A white square, opaque in the middle half, blurred so its edge fades out over
the outer quarter. Style.Shadow cuts it into corners and edges and tints it
black, so only the alpha matters. 128 x 128, a power of two as the game needs.

Run from the repo root: python tools/make_shadow.py
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

SIZE = 128
INSET = 32  # the window's edge sits here; the blur fades out beyond it
BLUR = 10

alpha = Image.new("L", (SIZE, SIZE), 0)
ImageDraw.Draw(alpha).rectangle([INSET, INSET, SIZE - INSET - 1, SIZE - INSET - 1], fill=255)
alpha = alpha.filter(ImageFilter.GaussianBlur(BLUR))

image = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 0))
image.putalpha(alpha)
out = Path(__file__).resolve().parent.parent / "jsalUI" / "Media" / "Shadow.tga"
image.save(out)
print(f"wrote {out}")
