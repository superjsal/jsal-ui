"""Turns a pen background into the picture the game loads.

    python -I tools/make_pet_scene.py meadow <scene.png> [preview folder]

The scene is pixel art at half the pen's size (the pen is 440 by 200, so 220
by 100; a wider picture loses the columns over at each side), drawn at twice its size
so its pixels match the creature's. The game wants sides that are powers of
two, so it's written into the top left of a 256 by 128 picture,
jsalUI/Media/Pet/<name>.png, and jsalUI/Pet/Pet.lua shows only that corner.
"""
import sys
from pathlib import Path

from PIL import Image

W, H = 220, 100


def main():
    name, source = sys.argv[1], Path(sys.argv[2])
    im = Image.open(source).convert("RGBA")
    assert im.height == H and im.width >= W, im.size
    left = (im.width - W) // 2
    scene = im.crop((left, 0, left + W, H))
    assert scene.getchannel("A").getextrema() == (255, 255), "a scene has no see-through parts"
    sheet = Image.new("RGBA", (256, 128), (0, 0, 0, 255))
    sheet.paste(scene, (0, 0))
    out = Path(__file__).resolve().parent.parent / "jsalUI" / "Media" / "Pet" / (name + ".png")
    sheet.save(out, optimize=True)
    print(scene.size, "->", out)
    if len(sys.argv) > 3:
        scene.resize((W * 2, H * 2), Image.NEAREST).save(Path(sys.argv[3]) / (name + "_scene.png"))


if __name__ == "__main__":
    main()
