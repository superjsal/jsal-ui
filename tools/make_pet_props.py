"""Turns the pen's small props into the pictures the game loads.

    python -I tools/make_pet_props.py <folder> [preview folder]

The folder holds dropping.png, bowl.png, ball.png, treat.png and scrubber.png, each 32 pixels square
with a see-through background. Writes jsalUI/Media/Pet/<name>.png for each,
unchanged but for the format.
"""
import sys
from pathlib import Path

from PIL import Image

PROPS = ("dropping", "bowl", "ball", "treat", "scrubber")


def main():
    folder = Path(sys.argv[1])
    out = Path(__file__).resolve().parent.parent / "jsalUI" / "Media" / "Pet"
    look = Image.new("RGBA", (len(PROPS) * 34, 34), (90, 150, 70, 255))
    for i, name in enumerate(PROPS):
        im = Image.open(folder / (name + ".png")).convert("RGBA")
        assert im.size == (32, 32), (name, im.size)
        im.save(out / (name + ".png"), optimize=True)
        look.alpha_composite(im, (i * 34 + 1, 1))
        print("wrote", name)
    if len(sys.argv) > 2:
        look.resize((look.width * 8, look.height * 8), Image.NEAREST).save(Path(sys.argv[2]) / "props.png")


if __name__ == "__main__":
    main()
