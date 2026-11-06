"""Builds jsalUI/Talents/SuggestedBuilds.lua: ready-made leveling builds.

Each build is a Wowhead Forever talent calculator link, with its point order,
copied from a Wowhead Forever leveling guide into data/talents/suggested.json.
Every point is checked against TalentData.lua with the game's rules (the
talent is in that class's trees, not past full rank, its row is open, and the
talent its arrow comes from is at full rank first), so a build that doesn't
fit Forever's trees stops the build instead of shipping.

A guide whose link Wowhead's calculator can no longer place on Forever's
current trees (an older "v2" link for talents since removed) is left out
until the guide is updated: Rogue, for now.

Run: python -I tools/build_suggested.py
"""

import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "data" / "talents" / "suggested.json"
TALENTS = ROOT / "jsalUI" / "Talents" / "TalentData.lua"
OUT = ROOT / "jsalUI" / "Talents" / "SuggestedBuilds.lua"

MAX_POINTS = 51
PER_ROW = 5
FIRST_LEVEL = 10
SLUGS = {
    "warrior": 1, "paladin": 2, "hunter": 3, "rogue": 4, "priest": 5,
    "shaman": 7, "mage": 8, "warlock": 9, "druid": 11,
}


def read_talents():
    """Per class ID: the trees in order, each a name and its talents as dicts."""
    classes, current, tree = {}, None, None
    for line in TALENTS.read_text(encoding="utf-8").splitlines():
        m = re.match(r"\s*\[(\d+)\] = \{", line)
        if m:
            current = classes.setdefault(int(m.group(1)), [])
            continue
        m = re.match(r'\s*\{ name = "([^"]+)", talents = \{', line)
        if m:
            tree = {"name": m.group(1), "talents": []}
            current.append(tree)
            continue
        m = re.match(r"\s*\{ ([\d, ]+) \},", line)
        if m and tree is not None:
            node, row, col, ranks, spell, need, need_ranks = (int(x) for x in m.group(1).split(","))
            tree["talents"].append({
                "id": node, "row": row, "col": col, "max": ranks, "spell": spell,
                "need": need or None, "needRanks": need_ranks,
            })
    return classes


def split_code(code):
    """A Wowhead calculator code's two halves: the ranks (each tree's ranks as
    digits, trees joined by "-") and the order (a tree's number when the tree
    changes, then a letter per talent taken, a capital taking it to full
    rank). The ranks come after a short tag and may carry extra flags after
    "_t0" (like "_r95"); the order comes after the last "/"."""
    m = re.match(r"([a-z]+)([\d-]*)_t\d+(?:_[a-z]\d+)*/(\w+)$", code)
    if not m:
        raise ValueError(f"can't read the code {code!r}")
    return m.group(1), m.group(2), m.group(3)


def ranks_of(digits, trees):
    """Each tree's ranks per talent, in TalentData's order, from the digits."""
    parts = digits.split("-")
    if len(parts) > len(trees):
        return None
    out = []
    for i, tree in enumerate(trees):
        d = parts[i] if i < len(parts) else ""
        if len(d) > len(tree["talents"]):
            return None
        ranks = [int(x) for x in d] + [0] * (len(tree["talents"]) - len(d))
        if any(r > t["max"] for r, t in zip(ranks, tree["talents"])):
            return None
        out.append(ranks)
    return out


def tokens_of(order_part):
    """The order as (tree, letter) pairs."""
    tokens, tree = [], 0
    for c in order_part:
        if c.isdigit():
            tree = int(c)
        else:
            tokens.append((tree, c))
    return tokens


def order_from(tokens, ranks, trees):
    """Wowhead numbers a tree's talents with a few gaps that TalentData doesn't
    have, so a letter isn't simply the talent's place. But both run in the
    same order, top to bottom and left to right, so the letters a build uses,
    sorted, are the talents it has ranks in, in order. Returns the point order
    as node IDs, or None if the letters and ranks don't line up."""
    order, taken = [], {}
    for t, tree in enumerate(trees):
        letters = sorted({c.lower() for tt, c in tokens if tt == t})
        ranked = [tal for tal, r in zip(tree["talents"], ranks[t]) if r > 0]
        if len(letters) != len(ranked):
            return None
        tree["_map"] = dict(zip(letters, ranked))
    for t, c in tokens:
        talent = trees[t]["_map"][c.lower()]
        while True:
            order.append(talent["id"])
            taken[talent["id"]] = taken.get(talent["id"], 0) + 1
            if not c.isupper() or taken[talent["id"]] >= talent["max"]:
                break
    # Every talent ends at the ranks the code gives it.
    for t, tree in enumerate(trees):
        for tal, r in zip(tree["talents"], ranks[t]):
            if taken.get(tal["id"], 0) != r:
                return None
    return order


def parse_link(link, trees):
    """The point order a Wowhead link carries, as node IDs. The ranks' tag is
    letters ("vkndmh") or, in older links, "v" and a version digit, so both
    readings are tried; the one whose ranks match the order wins."""
    m = re.search(r"talent-calc/[a-z-]+/(\S+)", link)
    if not m:
        raise ValueError("not a Wowhead talent calculator link")
    tag, digits, order_part = split_code(m.group(1))
    tokens = tokens_of(order_part)
    readings = [digits]
    if tag == "v" and digits[:1].isdigit():
        readings.append(digits[1:])
    found = []
    for d in readings:
        ranks = ranks_of(d, trees)
        order = ranks and order_from(tokens, ranks, trees)
        if order and not check(order, trees)[0]:
            found.append(order)
    if len(found) != 1:
        raise ValueError("the order and ranks don't line up" if not found else "the code reads two ways")
    return found[0]


def check(order, trees):
    """Problems with the order under the game's rules, and the points per tree."""
    nodes = {}
    for i, tree in enumerate(trees):
        for t in tree["talents"]:
            nodes[t["id"]] = dict(t, tree=i)
    ranks, spent, problems = {}, {}, []
    if len(order) > MAX_POINTS:
        problems.append(f"{len(order)} points, more than {MAX_POINTS}")
    for i, node_id in enumerate(order):
        level = FIRST_LEVEL + i
        n = nodes.get(node_id)
        if not n:
            problems.append(f"level {level}: node {node_id} isn't in this class's trees")
            continue
        if ranks.get(node_id, 0) >= n["max"]:
            problems.append(f"level {level}: node {node_id} is past its {n['max']} ranks")
        if spent.get(n["tree"], 0) < n["row"] * PER_ROW:
            problems.append(f"level {level}: node {node_id} (row {n['row'] + 1}) needs {n['row'] * PER_ROW} points in {trees[n['tree']]['name']}")
        if n["need"] and ranks.get(n["need"], 0) < n["needRanks"]:
            problems.append(f"level {level}: node {node_id} needs node {n['need']} at {n['needRanks']} first")
        ranks[node_id] = ranks.get(node_id, 0) + 1
        spent[n["tree"]] = spent.get(n["tree"], 0) + 1
    return problems, [spent.get(i, 0) for i in range(len(trees))]


def lua_string(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    classes = read_talents()
    builds = json.loads(SRC.read_text(encoding="utf-8"))
    out, failed = [], False
    for b in builds:
        class_id = SLUGS[b["class"]]
        trees = classes[class_id]
        try:
            order = parse_link(b["link"], trees)
        except ValueError as e:
            print(f"{b['name']} ({b['class']}): {e}")
            failed = True
            continue
        problems, spent = check(order, trees)
        split = "/".join(str(x) for x in spent)
        if problems:
            failed = True
            print(f"{b['name']} ({b['class']}, {split}): FAILS")
            for p in problems:
                print("   ", p)
            continue
        print(f"{b['name']} ({b['class']}): {len(order)} points, {split}, ok")
        out.append((b, class_id, order))
    if failed:
        print("Not written: fix the builds above first.")
        sys.exit(1)

    lines = [
        "-- Ready-made leveling builds, one per class, each a point-by-point order",
        "-- from a Wowhead Forever leveling guide, checked against TalentData's trees;",
        "-- regenerated by the build, not by hand. Per build: an ID, the class, a",
        "-- name, the tree it mainly goes into, where it's from, and the order (one",
        "-- talent node per point, from level 10). They're read-only: copy one to",
        "-- change it.",
        "local _, ns = ...",
        "",
        "ns.SuggestedBuilds = {",
    ]
    for b, class_id, order in out:
        lines.append("    {")
        lines.append(f"        id = {lua_string(b['id'])}, class = {class_id},")
        lines.append(f"        name = {lua_string(b['name'])}, spec = {lua_string(b['spec'])},")
        lines.append(f"        source = {lua_string(b['source'])},")
        lines.append(f"        link = {lua_string(b['link'])},")
        chunks = [", ".join(str(x) for x in order[i:i + 8]) for i in range(0, len(order), 8)]
        lines.append("        order = {")
        for chunk in chunks:
            lines.append(f"            {chunk},")
        lines.append("        },")
        lines.append("    },")
    lines.append("}")
    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    print(f"Wrote {len(out)} builds to {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
