"""Builds the pictures for weather in the pen.

    python -I tools/make_pet_weather.py [preview folder]

Writes three pictures into jsalUI/Media/Pet, each one 128-pixel tile that
the pen repeats across itself and slides (so its edges join: anything drawn
off one side comes back on the other):

  weather_rain.png   streaks falling, leaning a little to the left
  weather_snow.png   flakes, some larger
  weather_sand.png   grains and short dashes, blowing sideways

Everything is two pixels to a step, the size of the pen's own pixels (its
meadow is drawn at twice its art's size). Drawn here, the same every run.
Run tools/shrink_pet_pngs.py afterwards.
"""
import random
import sys
from pathlib import Path

from PIL import Image

T = 128
MEDIA = Path(__file__).resolve().parent.parent / "jsalUI" / "Media" / "Pet"


def block(tile, x, y, colour, wide=2, high=2):
    for px in range(wide):
        for py in range(high):
            tile.putpixel(((x + px) % T, (y + py) % T), colour)


def rain(seed=2, count=30):
    """Each streak is five steps long, paler at its head, and leans left as it falls."""
    rng = random.Random(seed)
    tile = Image.new("RGBA", (T, T))
    for _ in range(count):
        x, y = rng.randrange(0, T, 2), rng.randrange(0, T, 2)
        for d in range(5):
            block(tile, x - d // 2 * 2, y + d * 2, (214, 230, 255, 190) if d > 1 else (170, 198, 240, 120))
    return tile


def snow(seed=3, count=20):
    rng = random.Random(seed)
    tile = Image.new("RGBA", (T, T))
    for _ in range(count):
        x, y, big = rng.randrange(0, T, 2), rng.randrange(0, T, 2), rng.random() < 0.4
        block(tile, x, y, (255, 255, 255, 235 if big else 190), 4 if big else 2, 4 if big else 2)
    return tile


def sand(seed=5, count=46):
    """Grains, and dashes three or four steps long, lying nearly flat."""
    rng = random.Random(seed)
    tile = Image.new("RGBA", (T, T))
    for _ in range(count):
        x, y = rng.randrange(0, T, 2), rng.randrange(0, T, 2)
        if rng.random() < 0.45:
            for d in range(rng.randrange(3, 5)):
                block(tile, x + d * 2, y + (2 if d > 1 else 0), (232, 196, 132, 170) if d else (245, 220, 170, 200))
        else:
            block(tile, x, y, (240, 210, 150, 200))
    return tile


def main():
    made = {"weather_rain": rain(), "weather_snow": snow(), "weather_sand": sand()}
    for name, tile in made.items():
        tile.save(MEDIA / (name + ".png"), optimize=True)
        print(name, "->", MEDIA / (name + ".png"))
    if len(sys.argv) > 1:
        look = Image.new("RGBA", (T * 3 * 2, T * 2), (42, 47, 58, 255))
        for n, tile in enumerate(made.values()):
            look.alpha_composite(tile.resize((T * 2, T * 2), Image.NEAREST), (n * T * 2, 0))
        look.save(Path(sys.argv[1]) / "weather.png")


if __name__ == "__main__":
    main()
