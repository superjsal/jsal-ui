"""Builds jsalUI/Media/Maps/*.png: the maps of Forever's own dungeons for the Dungeon guide's Map tab.

The maps are Santiago Reyes's, from Atlas de Azeroth: Forever (sreyesmaps.com), used with his leave and his
credit under each one in the addon. Each is 3000 by 2000 on his site, with his watermarks and his credit
line, which are kept as they are: a map is only made smaller, never cut. They're shown 612 wide and can be
zoomed in until drawn at their own size, so 1024 by 683 keeps them sharp there and no bigger than that.

The sources aren't in this repository. Give the folder they were saved in, each named as below.

python tools/build_map_art.py <folder>
"""
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "jsalUI", "Media", "Maps")
WIDE, TALL = 1024, 683
# The addon's name for each picture, from the source's file name (his site's page, then the floor).
ART = {
    "hallofthanes": "salon-de-los-feudales-hall-of-thanes_1",
    "lordaeron": "las-ruinas-de-lordaeron_1",
    "dalaran1": "la-ciudad-de-dalaran_1",
    "dalaran2": "la-ciudad-de-dalaran_3",
    "excavation": "sitio-de-excavacion-los-humedales_1",
    "drowned1": "la-ciudad-ahogada_1",
    "drowned2": "la-ciudad-ahogada_3",
    "kroldok": "la-fortaleza-krol-dok_1",
    "alcaz1": "la-prision-de-alcaz_1",
    "alcaz2": "la-prision-de-alcaz_2",
    "blackmaw1": "bastion-faucenegra_1",
    "blackmaw2": "bastion-faucenegra_2",
    "blackmaw3": "bastion-faucenegra_3",
    "blackmaw4": "bastion-faucenegra_4",
    "blackmaw5": "bastion-faucenegra_5",
    "blackmaw6": "bastion-faucenegra_6",
    "shaper1": "bancal-del-creador-shaper-s-terrace_1",
    "shaper2": "bancal-del-creador-shaper-s-terrace_3",
}


def main(src):
    os.makedirs(OUT, exist_ok=True)
    total = 0
    for name, source in sorted(ART.items()):
        im = Image.open(os.path.join(src, source + ".jpg")).convert("RGB")
        im = im.resize((WIDE, TALL), Image.LANCZOS)
        path = os.path.join(OUT, name + ".png")
        im.save(path, optimize=True)
        total += os.path.getsize(path)
        print("%-12s %5d KB" % (name, os.path.getsize(path) // 1024))
    print("%d pictures, %.1f MB" % (len(ART), total / 1048576))


if __name__ == "__main__":
    main(sys.argv[1])
