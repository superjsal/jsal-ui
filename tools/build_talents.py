"""Builds jsalUI/Talents/TalentData.lua: every class's three Forever talent trees.

The tables come from the game's files for the Forever build jsal.ui targets,
as CSV (https://wago.tools/db2/<Table>/csv?build=<version>), in data/talents/.

Forever runs its talents on the newer talent system (TraitNode and friends),
so that's the source of truth: which talents exist, their ranks, spells,
positions, the three trees (groups) and the arrows (edges). Forever's files
still carry the classic Talent and TalentTab tables, but some of their
talents were replaced; they're used only to name and order each tree and to
line up the columns.

Run: python -I tools/build_talents.py 1.60.1.70790
"""

import csv
import pathlib
import statistics
import sys
from collections import Counter, defaultdict

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "data" / "talents"
OUT = ROOT / "jsalUI" / "Talents" / "TalentData.lua"
REQUIRED_EDGE = "2"   # an arrow: the left talent is needed for the right one


def rows(name):
    with open(SRC / f"{name}.csv", newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def grid_step(position_sets):
    """The grid's spacing: the most common gap between neighbouring positions."""
    gaps = Counter()
    for values in position_sets:
        values = sorted(set(values))
        gaps.update(round(b - a, -1) for a, b in zip(values, values[1:]))
    return gaps.most_common(1)[0][0]


def on_grid(members, nodes, step, top, bottom):
    """Talents placed far off their tree's grid are parked there out of sight
    (taken out of the game). This keeps the ones inside the rows every tree
    shares (top to bottom) and within two and a half columns of the tree's
    middle."""
    xs = statistics.median(float(nodes[n]["PosX"]) for n in members)
    return [n for n in members
            if abs(float(nodes[n]["PosX"]) - xs) <= 2.5 * step
            and top - step / 2 <= float(nodes[n]["PosY"]) <= bottom + step / 2]


def main():
    build = sys.argv[1] if len(sys.argv) > 1 else "unknown"
    nodes = {int(r["ID"]): r for r in rows("TraitNode")}

    # Each node's first entry: its ranks and its spell.
    definition_spell = {int(r["ID"]): int(r["SpellID"]) for r in rows("TraitDefinition")}
    entries = {int(r["ID"]): r for r in rows("TraitNodeEntry")}
    node_entry = {}
    for r in sorted(rows("TraitNodeXTraitNodeEntry"), key=lambda r: int(r["_Index"])):
        node_entry.setdefault(int(r["TraitNodeID"]), entries.get(int(r["TraitNodeEntryID"])))

    def spell_of(node):
        e = node_entry.get(node)
        return definition_spell.get(int(e["TraitDefinitionID"]), 0) if e else 0

    # The classic tables, matched by spell, for names, order and columns.
    tabs = {int(r["ID"]): r for r in rows("TalentTab")}
    classic_by_spell = {}
    for t in rows("Talent"):
        for i in range(9):
            s = int(t[f"SpellRank_{i}"])
            if s:
                classic_by_spell[s] = t

    # Groups: a tree's three talent trees are its largest groups that sit
    # inside no other group.
    group_tree = {int(r["ID"]): int(r["TraitTreeID"]) for r in rows("TraitNodeGroup")}
    group_nodes = defaultdict(set)
    for r in rows("TraitNodeGroupXTraitNode"):
        group_nodes[int(r["TraitNodeGroupID"])].add(int(r["TraitNodeID"]))

    edges = [(int(e["LeftTraitNodeID"]), int(e["RightTraitNodeID"])) for e in rows("TraitEdge") if e["Type"] == REQUIRED_EDGE]
    pairs = set(edges)
    needs = {}
    for a, b in edges:
        if (b, a) not in pairs:   # two-way arrows aren't a requirement
            needs[b] = a

    class_trees = sorted({int(r["TraitTreeID"]) for r in rows("SkillLineXTraitTree")})
    step = grid_step(
        [float(r["PosY"]) for r in nodes.values() if int(r["TraitTreeID"]) == t] for t in class_trees
    )
    # The rows: positions that most class trees use.
    row_use = Counter()
    for t in class_trees:
        row_use.update({float(r["PosY"]) for r in nodes.values() if int(r["TraitTreeID"]) == t})
    shared = [y for y, count in row_use.items() if count > len(class_trees) / 2]
    row_top, row_bottom = min(shared), max(shared)
    out, report = {}, []
    for tree in class_trees:
        tree_nodes = {n for n, r in nodes.items() if int(r["TraitTreeID"]) == tree and spell_of(n)}
        groups = [g for g, t in group_tree.items() if t == tree and group_nodes[g] & tree_nodes]
        top = [g for g in groups if not any(g != h and group_nodes[g] < group_nodes[h] for h in groups)]
        top = sorted(top, key=lambda g: -len(group_nodes[g]))[:3]
        trees = []
        for g in top:
            everything = sorted(group_nodes[g] & tree_nodes)
            members = on_grid(everything, nodes, step, row_top, row_bottom)
            parked = len(everything) - len(members)
            classic = [classic_by_spell[spell_of(n)] for n in members if spell_of(n) in classic_by_spell]
            tab = tabs[Counter(int(c["TabID"]) for c in classic).most_common(1)[0][0]]
            mask = int(tab["ClassMask"])
            y0 = row_top
            x0 = min(float(nodes[n]["PosX"]) for n in members)
            def cell(n):
                return (round((float(nodes[n]["PosY"]) - y0) / step), round((float(nodes[n]["PosX"]) - x0) / step))
            # Line the columns up with the classic layout where talents match,
            # in case a tree leaves its first column empty.
            shift = [int(classic_by_spell[spell_of(n)]["ColumnIndex"]) - cell(n)[1]
                     for n in members if spell_of(n) in classic_by_spell]
            offset = round(statistics.median(shift)) if shift else 0
            talents = []
            for n in members:
                e = node_entry[n]
                row, col = cell(n)
                col += offset
                need = needs.get(n, 0) if needs.get(n, 0) in members else 0
                need_ranks = int(node_entry[need]["MaxRanks"]) if need else 0
                talents.append((row, col, n, int(e["MaxRanks"]), spell_of(n), need, need_ranks))
            talents.sort()
            trees.append((int(tab["OrderIndex"]), tab["Name_lang"], talents))
            rows_used = max(t[0] for t in talents) + 1
            cols_used = max(t[1] for t in talents) + 1
            report.append(f"{tab['Name_lang']:>14}: {len(members)} talents ({parked} parked), "
                          f"{rows_used} rows, {cols_used} columns (shift {offset})")
        trees.sort()
        out[mask.bit_length()] = trees

    lines = [
        "-- Every class's three Forever talent trees, from the game's own talent",
        f"-- tables (build {build}); regenerated by the build, not by hand. Per",
        "-- class ID, the trees in order; per talent: node, row, column, ranks,",
        "-- spell, and the talent it needs (node) at how many ranks, or 0.",
        "local _, ns = ...",
        "",
        "ns.TalentData = {",
    ]
    for class_id in sorted(out):
        lines.append(f"    [{class_id}] = {{")
        for _, name, talents in out[class_id]:
            lines.append(f'        {{ name = "{name}", talents = {{')
            for row, col, n, ranks, spell, need, need_ranks in talents:
                lines.append(f"            {{ {n}, {row}, {col}, {ranks}, {spell}, {need}, {need_ranks} }},")
            lines.append("        } },")
        lines.append("    },")
    lines += ["}", ""]
    OUT.write_text("\n".join(lines), encoding="utf-8", newline="\n")
    print(f"{len(out)} classes -> {OUT.relative_to(ROOT)}")
    for line in report:
        print("  " + line)


if __name__ == "__main__":
    main()
