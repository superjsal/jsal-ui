"""Makes the paddock's pictures and the nest's, as the game loads them.

    python -I tools/make_pet_paddock.py [preview folder]

The paddock is where settled pals live, and it has scenery of its own for
each kind of land the pen has: that land as a wide view from further off, a
big field with the fence and trees far away and a shelter, a trough and hay
at the left, so it reads as a bigger place than the pen (drawn by PixelLab
from the pen's scene, 14 Nov 2026, in two steps: the pen's scene with a
shelter added, then that redrawn wide). The
sources are data/pals/paddock/<land>.png, 220 by 100 like a pen scene. Each
is written as jsalUI/Media/Pet/paddock_<land>.png the way
tools/make_pet_scene.py writes a scene (in the top left of a 256 by 128
picture), and its dusk and night are made from it the way
tools/make_pet_night.py makes any scene's but the meadow's: the sky is
found, not known, since a redrawn meadow's blues aren't the first one's.

The nest (data/pals/nest.png, 64 by 48) is what an egg sits in while a fully
grown pal looks after it. It's written twice, each at the foot of a 64 by 64
picture: nest.png, the whole of it, drawn under the egg; and nest_front.png,
its front rim alone, drawn over the egg's foot so the egg sits in it.

Run tools/shrink_pet_pngs.py afterwards.
"""
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_pet_night as night  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
DATA, MEDIA = ROOT / "data" / "pals", ROOT / "jsalUI" / "Media" / "Pet"
LANDS = ["meadow", "snow", "desert", "swamp", "coast", "darkwood", "savanna", "volcanic", "jungle"]
W, H = 220, 100
# The row of the nest's source where its front rim starts: under the hollow.
RIM = 27


def main():
    preview = Path(sys.argv[1]) if len(sys.argv) > 1 else None
    # Where a band of cloud lies across the sky with more sky under it, the
    # search for the sky goes on through the clouds: the lands the pen's
    # scenes need that for, and in these wide views the meadow and jungle too.
    night.THROUGH_CLOUDS |= {"paddock_" + land for land in night.THROUGH_CLOUDS} | {"paddock_meadow", "paddock_jungle"}
    for land in LANDS:
        scene = Image.open(DATA / "paddock" / (land + ".png")).convert("RGBA")
        assert scene.size == (W, H), (land, scene.size)
        assert scene.getchannel("A").getextrema() == (255, 255), "a scene has no see-through parts"
        name = "paddock_" + land
        sheet = Image.new("RGBA", (256, 128), (0, 0, 0, 255))
        sheet.paste(scene, (0, 0))
        sheet.save(MEDIA / (name + ".png"), optimize=True)
        dark, dusk = night.found(name)
        night.save(dark, name, "_night")
        night.save(dusk, name, "_dusk")
        if preview:
            strip = Image.new("RGBA", (W * 3, H))
            for i, im in enumerate((scene, dusk, dark)):
                strip.paste(im, (i * W, 0))
            strip.resize((W * 6, H * 2), Image.NEAREST).save(preview / (name + "_preview.png"))
    nest = Image.open(DATA / "nest.png").convert("RGBA")
    assert nest.size == (64, 48), nest.size
    whole = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    whole.paste(nest, (0, 16))
    whole.save(MEDIA / "nest.png", optimize=True)
    front = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    front.paste(nest.crop((0, RIM, 64, 48)), (0, 16 + RIM))
    front.save(MEDIA / "nest_front.png", optimize=True)
    print("nest:", nest.getbbox(), "front rim from row", RIM)


if __name__ == "__main__":
    main()
