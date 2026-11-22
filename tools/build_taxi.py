"""Builds jsalUI/Games/FlightData.lua from the game's own flight tables.

The tables come from the game's files for the build jsal.ui targets, as CSV
(wago.tools serves each build's tables):
  data/taxi/TaxiPath.csv      each direct path: ID, FromTaxiNode, ToTaxiNode
  data/taxi/TaxiPathNode.csv  each path's waypoints: PathID, NodeIndex,
                              ContinentID, Loc_0..2, Flags, Delay
Fetch them again after a patch, for example:
  https://wago.tools/db2/TaxiPath/csv?build=1.60.1.70790
  https://wago.tools/db2/TaxiPathNode/csv?build=1.60.1.70790

Each path's length is the distance along its waypoints, in yards, skipping
jumps between continents; waypoint delays (seconds the flight stops) are
summed separately.

A flight through a point it doesn't land at doesn't fly both paths whole: it
leaves the first before its approach to the perch and joins the next after its
climb away. The join is TrinityCore's emulation of the game's: the later path
drops its first two waypoints and those within JOIN_RADIUS yards of its start,
the earlier one its last and those within JOIN_RADIUS of its end, and where the
later path's waypoint is still within JOIN_RADIUS of the last one kept, that
one is taken back (so a corridor flown in and out again is flown once). What a
join saves depends on both paths, so it's kept per path by the next flight
point, where it's at least JOIN_MIN.

That take-back only sees a corridor whose waypoints come within JOIN_RADIUS of
each other right at the perch. Where the way in and the way out run together
further out but part a little near the perch (Ironforge's gate, for one), the
bird still flies the corridor only once: where CORRIDOR_RUN waypoints in a row
of the path in lie within CORRIDOR yards of the path out's, retraced in the
other order, it may cross from one to the other, and it takes whichever such
crossing, or the rule above, makes the shorter route. Crossings are looked for
in the half of each path nearest the point passed.

Some flight points are flown through shorter than the rule makes them: their
paths in and out run side by side for a few hundred yards, a hairpin the rule
barely trims. PASSED holds what flights through such a point measured beyond
the rule, added to every join there. Nothing in the path data gives it, so
each entry is measured, and a point without one is priced by the rule alone.

Elsewhere what's left over differs by the way in and the way out, so it can't
be one number for the point: through Ironforge it's 1 to 10 seconds by route.
JOINED holds what flights measured beyond the rule for one join, the path in
and the path out, and every other join there is priced by the rule alone.

Run: python -I tools/build_taxi.py 1.60.1.70790
"""

import csv
import math
import pathlib
import sys
from collections import defaultdict

ROOT = pathlib.Path(__file__).resolve().parent.parent
TAXI = ROOT / "data" / "taxi"
OUT = ROOT / "jsalUI" / "Games" / "FlightData.lua"
JOIN_RADIUS = 40   # yards from a flight point within which a path passed through is cut
JOIN_MIN = 30      # yards a join must save to be kept (about a second)
CORRIDOR = 60      # yards apart the way in and the way out may run and still be one corridor
CORRIDOR_RUN = 4   # waypoints in a row that must run together for a crossing

# Yards a flight through a point saves beyond the join rule, by flight point, measured
# at 29.92 yards a second.
PASSED = {
    2: 106,   # Stormwind: two flights through it read 3.8 s and 3.3 s long by the rule alone
}

# Yards a flight saves beyond the join rule (and PASSED) on one join, by the flight point
# flown from, the point passed and the point flown on to, measured at 29.92 yards a second.
JOINED = {
    # Aerie Peak > Ironforge > Stormwind: flown on to Booty Bay it read 6.65 s long, flown to
    # Stormwind 6.85 s (199 and 205 yards).
    (43, 6, 2): 202,
    # Stormwind > Ironforge > Aerie Peak: one flight read 7.0 s long.
    (2, 6, 43): 210,
    # Menethil Harbor > Ironforge > Stormwind: one flight, Southshore to Booty Bay through all three, read
    # 4.2 s long after Stormwind's; the recorded times put it all at Ironforge, none at Menethil Harbor.
    (7, 6, 2): 126,
}


def rows(name):
    with open(TAXI / f"{name}.csv", newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def length(pts):
    return sum(math.dist(a[2:5], b[2:5]) for a, b in zip(pts, pts[1:]) if a[1] == b[1])


def far(a, b):
    return a[1] != b[1] or (a[2] - b[2]) ** 2 + (a[3] - b[3]) ** 2 > JOIN_RADIUS * JOIN_RADIUS


def apart(a, b):
    return math.inf if a[1] != b[1] else math.hypot(a[2] - b[2], a[3] - b[3])


def along(pts):
    """Yards flown to reach each waypoint of `pts`."""
    out = [0.0]
    for a, b in zip(pts, pts[1:]):
        out.append(out[-1] + (math.dist(a[2:5], b[2:5]) if a[1] == b[1] else 0))
    return out


def crossed(a, b):
    """Yards flown from path `a` onto path `b` by the shortest crossing where they share a corridor, or None."""
    ca, cb = along(a), along(b)
    best = None
    for i in range(len(a) - len(a) // 2, len(a) - 1):
        for j in range(1, len(b) // 2):
            if all(i + k < len(a) and j - k >= 0 and apart(a[i + k], b[j - k]) <= CORRIDOR for k in range(CORRIDOR_RUN)):
                yards = ca[i] + math.dist(a[i][2:5], b[j][2:5]) + cb[-1] - cb[j]
                if best is None or yards < best:
                    best = yards
    return best


def joined(chain):
    """The waypoints flown along `chain` (each path's sorted waypoints) without landing between."""
    path = []
    last = len(chain) - 1
    for k, nodes in enumerate(chain):
        start, end = nodes[0], nodes[-1]
        passed = False
        for i, node in enumerate(nodes):
            if passed or k == 0 or not path or far(path[-1], node):
                if (k == 0 or (far(start, node) and i >= 2)) and (k == last or (far(end, node) and i < len(nodes) - 1)):
                    passed = True
                    path.append(node)
            else:
                path.pop()
    return path


def main():
    build = sys.argv[1] if len(sys.argv) > 1 else "unknown"
    paths = {int(r["ID"]): (int(r["FromTaxiNode"]), int(r["ToTaxiNode"])) for r in rows("TaxiPath")}
    points = defaultdict(list)
    for r in rows("TaxiPathNode"):
        points[int(r["PathID"])].append((
            int(r["NodeIndex"]), int(r["ContinentID"]),
            float(r["Loc_0"]), float(r["Loc_1"]), float(r["Loc_2"]),
            int(r["Delay"]),
        ))

    routes, kept = {}, {}
    for path_id, (src, dst) in paths.items():
        pts = sorted(points.get(path_id, []))
        if len(pts) < 2 or src == dst:
            continue
        delay = sum(a[5] for a in pts[:-1])
        routes[src * 10000 + dst] = (round(length(pts)), delay)
        kept[(src, dst)] = pts

    # What passing through a flight point saves, by the path flown in and the point flown on to.
    joins = {}
    for (src, via), a in kept.items():
        for (via2, dst), b in kept.items():
            if via2 != via or dst == src or a[-1][1] != b[0][1]:
                continue
            flown = length(joined([a, b]))
            corridor = crossed(a, b)
            if corridor is not None and corridor < flown:
                flown = corridor
            saved = round(length(a) + length(b) - flown) + PASSED.get(via, 0) + JOINED.get((src, via, dst), 0)
            if saved >= JOIN_MIN:
                joins.setdefault(src * 10000 + via, {})[dst] = saved

    lines = [
        "-- Every direct flight path's length in yards, and the seconds it stops",
        f"-- along the way, from the game's own flight tables (build {build}).",
        "-- Keyed fromNode * 10000 + toNode; regenerated by the build, not by hand.",
        "-- The third part, where there is one: the yards a flight that passes through this path's end saves,",
        f"-- by the flight point it goes on to (the join rule at {JOIN_RADIUS} yards, and what some points and joins measured",
        "-- beyond it; tools/build_taxi.py).",
        "local _, ns = ...",
        "",
        "ns.FlightPaths = {",
    ]
    for key in sorted(routes):
        yards, delay = routes[key]
        on = joins.get(key)
        more = (", { " + ", ".join(f"[{d}] = {n}" for d, n in sorted(on.items())) + " }") if on else ""
        lines.append(f"    [{key}] = {{ {yards}, {delay}{more} }},")
    lines += ["}", ""]
    OUT.write_text("\n".join(lines), encoding="utf-8", newline="\n")
    print(f"{len(routes)} paths, {sum(len(j) for j in joins.values())} joins -> {OUT.relative_to(ROOT)}")
    print(f"  Aerie Peak > Ironforge > Stormwind saves {joins.get(430006, {}).get(2)}, Stormwind > Ironforge > Aerie Peak {joins.get(20006, {}).get(43)},"
          f" Ironforge > Stormwind > Booty Bay {joins.get(60002, {}).get(19)}")
    for key in (20004, 40002):
        print(f"  {key}: {routes.get(key)}")


if __name__ == "__main__":
    main()
