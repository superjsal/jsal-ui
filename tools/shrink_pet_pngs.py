"""Saves the pals' pictures smaller without changing a pixel.

    python -I tools/shrink_pet_pngs.py            shrink every picture that can be
    python -I tools/shrink_pet_pngs.py --check    change nothing; fail if one could be

Run it after any tool that writes into jsalUI/Media/Pet. The test run does the
--check, so a new picture that was left big fails the tests.

A picture with 256 colours or fewer (counting each see-through shade as its
own colour) is written as a PNG that keeps a list of its colours and one byte
a pixel, in place of four bytes a pixel. The game reads both kinds (seen in
game, 13 Nov 2026). Every picture is read back and compared with what it was,
and is only replaced when it is the same pixel for pixel and smaller on disk.
A picture with more colours than that is left as it is.

Always eight bits a pixel, never fewer: that is the kind seen working in game.
"""
import io
import sys
from pathlib import Path

from PIL import Image

MEDIA = Path(__file__).resolve().parent.parent / "jsalUI" / "Media" / "Pet"


def shrunk(path):
    """The picture's smaller bytes, or None when it has too many colours, is
    already the small kind, or would not come out smaller."""
    was = path.read_bytes()
    im = Image.open(io.BytesIO(was))
    im.load()
    if im.mode == "P":
        return None
    clear = im.mode in ("RGBA", "LA") or "transparency" in im.info
    full = im.convert("RGBA")
    counts = full.getcolors(maxcolors=256)
    if counts is None:
        return None
    # The most see-through colours first: the file then only has to list how
    # see-through the first few are.
    colours = sorted((c for _, c in counts), key=lambda c: (c[3], c))
    place = {c: i for i, c in enumerate(colours)}
    small = Image.new("P", full.size)
    pixels = full.get_flattened_data() if hasattr(full, "get_flattened_data") else full.getdata()
    small.putdata([place[c] for c in pixels])
    # At least 17 colours in the list, the spare ones black and unused: with
    # 16 or fewer the picture would be written with under eight bits a pixel.
    listed = colours + [(0, 0, 0, 255)] * max(0, 17 - len(colours))
    small.putpalette([v for c in listed for v in c[:3]])
    options = {"optimize": True, "bits": 8}
    if clear:
        alphas = bytes(c[3] for c in colours)
        options["transparency"] = alphas.rstrip(b"\xff") or alphas[:1]
    out = io.BytesIO()
    small.save(out, "PNG", **options)
    now = out.getvalue()
    back = Image.open(io.BytesIO(now))
    assert back.mode == "P" and back.size == full.size and now[24] == 8 and now[25] == 3, path.name
    assert back.convert("RGBA").tobytes() == full.tobytes(), path.name + " did not come back the same"
    return now if len(now) < len(was) else None


def main():
    check = "--check" in sys.argv[1:]
    could, before, after = [], 0, 0
    for path in sorted(MEDIA.glob("*.png")):
        size = path.stat().st_size
        before += size
        now = shrunk(path)
        if now is None:
            after += size
            continue
        could.append(path.name)
        if check:
            after += size
        else:
            path.write_bytes(now)
            after += len(now)
    if check:
        if could:
            print("FAIL these pictures could be saved smaller (python -I tools/shrink_pet_pngs.py):")
            for name in could:
                print("    " + name)
            sys.exit(1)
        print("ok   every pal picture that can be the small kind is")
        return
    print(len(could), "pictures shrunk:", before // 1024, "KB ->", after // 1024, "KB")


if __name__ == "__main__":
    main()
