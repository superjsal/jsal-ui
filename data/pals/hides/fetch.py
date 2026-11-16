"""Downloads the pen's hiding places from PixelLab into this folder: one for each scene, made by
create_map_object (16 Nov 2026): meadow and volcanic in style-matching mode on a 64-pixel corner of
that scene, the other seven plain (48 by 48), as style-matching drew those as discs.
python -I fetch.py        (skips what's already here; says what isn't ready)"""
import urllib.request
from pathlib import Path

HERE = Path(__file__).parent
OBJECTS = {
    "meadow": "e1f5d594-75d6-485e-9f4f-02442329e8ad",
    "snow": "805f1ca6-d090-4ad1-bebf-4d0327b8bf20",
    "desert": "5a22748f-3790-4f0f-be41-62098475b730",
    "swamp": "a05aba7b-72be-4691-aa03-d0c2cdd9dd4e",
    "coast": "38967114-5905-4ca0-b12b-1ce5331d8da9",
    "darkwood": "6510a29b-ae55-439b-ac49-6c32b96649b6",
    "savanna": "00711c94-98bd-44eb-aa61-67c0e15e7bb9",
    "volcanic": "61a369b8-3308-4604-9a89-1febbd8b663b",
    "jungle": "c5bcb5fa-b117-4378-ac8e-9d05d7441ada",
}


def get(url, to):
    if to.exists() and to.stat().st_size > 200:
        return "have"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "curl/8"})
        data = urllib.request.urlopen(req, timeout=60).read()
    except Exception as e:  # noqa: BLE001
        return "not yet: %s" % e
    if data[:4] != b"\x89PNG":
        return "not a picture yet (%d bytes)" % len(data)
    to.write_bytes(data)
    return "got %d bytes" % len(data)


for name, obj in OBJECTS.items():
    print(name, get("https://api.pixellab.ai/mcp/map-objects/%s/download" % obj, HERE / (name + ".png")))
