"""Wowhead's map spots, put on Forever's maps.

Wowhead Forever gives a spot as x, y (0 to 100) on Classic's map of the zone.
Forever draws four zones over a different stretch of the world than Classic
does (Stormwind, Mulgore, Eastern Plaguelands, Redridge), so on those the
same spot in the world has other numbers: a Stormwind trainer Wowhead puts
at 61.4, 15.4 stands at 67.2, 36.4 on Forever's map. `forever_spot` turns
the one into the other, through the world's own coordinates, and leaves
every other map's spots as they are.

Both tables are the game's UiMapAssignment, in data/maps/:
  UiMapAssignment.csv           Forever's, the build jsal.ui targets
  UiMapAssignment-classic.csv   Classic Era's, from
                                https://wago.tools/db2/UiMapAssignment/csv?branch=wow_classic_era
"""

import csv
import pathlib

MAPS = pathlib.Path(__file__).resolve().parent.parent / "data" / "maps"


def _bounds(name):
    """Each map's stretch of the world: (min x, min y, max x, max y)."""
    out = {}
    with open(MAPS / name, newline="", encoding="utf-8") as f:
        for r in csv.DictReader(f):
            ui_map = int(r["UiMapID"])
            if ui_map not in out or r["OrderIndex"] == "0":
                out[ui_map] = tuple(float(r[f"Region_{i}"]) for i in (0, 1, 3, 4))
    return out


FOREVER = _bounds("UiMapAssignment.csv")
CLASSIC = _bounds("UiMapAssignment-classic.csv")
# The maps Forever draws differently: only their spots are moved.
REDRAWN = sorted(m for m in FOREVER
                 if m in CLASSIC and any(abs(a - b) > 0.5 for a, b in zip(FOREVER[m], CLASSIC[m])))


def forever_spot(ui_map, x, y):
    """A spot Wowhead gives on Classic's map (x, y from 0 to 100), as Forever's
    map has it, to one decimal place. Unchanged where the two maps agree."""
    if ui_map not in REDRAWN:
        return x, y
    min_x, min_y, max_x, max_y = CLASSIC[ui_map]
    # A map's x runs along the world's y, from its highest to its lowest; its
    # y along the world's x, the same way.
    world_y = max_y - x / 100 * (max_y - min_y)
    world_x = max_x - y / 100 * (max_x - min_x)
    min_x, min_y, max_x, max_y = FOREVER[ui_map]
    return (round((max_y - world_y) / (max_y - min_y) * 100, 1),
            round((max_x - world_x) / (max_x - min_x) * 100, 1))
