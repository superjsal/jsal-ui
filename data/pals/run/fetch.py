"""Downloads Pal run's ground from PixelLab into this folder: for each country a side-on tileset of
16 tiles, 16 pixels each (create_sidescroller_tileset, 16 Nov 2026), as <land>.png, with <land>.json
saying which corners of each tile are ground. And the finish flag, an object, as flag.png.
python -I fetch.py        (skips what's already here; says what isn't ready)"""
import json
import urllib.request
from pathlib import Path

HERE = Path(__file__).parent
TILESETS = {
    "meadow": "a7234ee3-7251-4bb3-b40b-d8600999ea55",
    "snow": "b0cb6b54-6443-4aaa-9082-b06307b42a3a",
    "desert": "d1fe4887-9f03-4e85-b8e4-a1ef4d51b36f",
    "swamp": "cb69a366-c989-4b1b-87e8-22828dd24a06",
    "coast": "a39b24fc-afd9-4f2d-8318-2a9e4490ca79",
    "darkwood": "960f6eaa-6e1c-46c3-bfac-37c3fe367a01",
    "savanna": "4f88c972-4900-4dd3-ba7e-f2c1d83a58ce",
    "volcanic": "6ac59793-fd25-4c0d-8621-2590a4d0e8b0",
    "jungle": "34e0eb84-06e5-4daa-a83e-2ee82626faf5",
}
OBJECTS = {"flag": "6db0179e-25dc-4d10-8760-1b098ab1e9bf"}


def slim(data):
    """Only what tools/make_run_tiles.py reads: where each tile is in the picture, and which of its corners are ground."""
    tiles = json.loads(data)["tileset_data"]["tiles"]
    kept = [{"corners": tile["corners"], "bounding_box": tile["bounding_box"]} for tile in tiles]
    return (json.dumps({"tileset_data": {"tiles": kept}}, indent=1) + chr(10)).encode("utf-8")


def get(url, to, picture=True):
    if to.exists() and to.stat().st_size > 200:
        return "have"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "curl/8"})
        data = urllib.request.urlopen(req, timeout=60).read()
    except Exception as e:  # noqa: BLE001
        return "not yet: %s" % e
    if picture and data[:4] != b"\x89PNG":
        return "not a picture yet (%d bytes)" % len(data)
    if not picture:
        if data[:1] != b"{":
            return "not its layout yet (%d bytes)" % len(data)
        data = slim(data)
    to.write_bytes(data)
    return "got %d bytes" % len(data)


for name, tileset in TILESETS.items():
    base = "https://api.pixellab.ai/mcp/sidescroller-tilesets/%s/" % tileset
    print(name, get(base + "image", HERE / (name + ".png")), "|", get(base + "metadata", HERE / (name + ".json"), False))
for name, obj in OBJECTS.items():
    print(name, get("https://api.pixellab.ai/mcp/objects/%s/download" % obj, HERE / (name + ".png")))
