"""Re-saves every companion picture in the other file format, pixel for pixel.

    python -I tools/make_pet_format.py png
    python -I tools/make_pet_format.py tga

The pictures in jsalUI/Media/Pet are PNG: about a quarter the size on disk of
the run-length packed TGA they were, and the game reads both. Each is opened,
saved the other way, read back and compared pixel for pixel before the old
file is removed, so nothing changes but the size of the install.

Going back to TGA (if a picture ever shows blank or garbled in the game) is
this with "tga", and EXT = "" in jsalUI/Pet/Pet.lua, since the game finds a
TGA without being told its ending; the make_pet tools and the test's
Picture() would need turning back too.
"""
import sys
from pathlib import Path

from PIL import Image

MEDIA = Path(__file__).resolve().parent.parent / "jsalUI" / "Media" / "Pet"


def main():
    to = sys.argv[1]
    assert to in ("png", "tga"), to
    was = "tga" if to == "png" else "png"
    before = after = 0
    files = sorted(MEDIA.glob("*." + was))
    for old in files:
        im = Image.open(old).convert("RGBA")
        new = old.with_suffix("." + to)
        if to == "png":
            im.save(new, optimize=True)
        else:
            im.save(new, compression="tga_rle")
        back = Image.open(new).convert("RGBA")
        assert back.size == im.size and back.tobytes() == im.tobytes(), old.name
        before, after = before + old.stat().st_size, after + new.stat().st_size
        old.unlink()
    print(len(files), "pictures:", before, "->", after, "bytes")


if __name__ == "__main__":
    main()
