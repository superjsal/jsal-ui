"""Copies the trainer visits saved in game into data/prices/trainers.json.

jsal.ui saves every trainer it sees to its SavedVariables (jsalUI.lua). This
takes just the trainers from that file: each one's class, name, zone and
rows (spell, price, level, kind), so build_spells.py can ship the prices
with the addon. Nothing else in the saved file is copied.

Run: python -I tools/bake_prices.py "<path to WTF\\Account\\...\\SavedVariables\\jsalUI.lua>"
"""

import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "data" / "prices" / "trainers.json"
KINDS = {"available", "unavailable", "used"}
LETTERS = {"a": "available", "u": "unavailable", "x": "used"}


def row_of(r):
    """A saved row: a table of named fields, or (the slimmer form) one line
    of text, spell|name|rank|level|cost|kind, the kind as a letter."""
    if not isinstance(r, str):
        return r
    spell, name, rank, level, cost, kind = (r.split("|") + [""] * 6)[:6]
    return {"spell": int(spell) if spell else None, "name": name, "rank": rank or None,
            "level": int(level or 0), "cost": int(cost or 0), "category": LETTERS.get(kind)}

TOKEN = re.compile(r'\s*(?:(\{)|(\})|(=)|(,|;)|\[\s*"((?:[^"\\]|\\.)*)"\s*\]|\[\s*(-?\d+(?:\.\d+)?)\s*\]|'
                   r'"((?:[^"\\]|\\.)*)"|(-?\d+(?:\.\d+)?(?:e-?\d+)?)|(true|false|nil)|([A-Za-z_]\w*))')


def parse_lua(text):
    """A SavedVariables file as {name: value}: tables become dicts (or lists
    when they only hold array entries)."""
    # The game numbers a list's entries in a comment at the end of each line.
    text = re.sub(r"--\s*\[\d+\]\s*$", "", text, flags=re.M)
    tokens = []
    for m in TOKEN.finditer(text):
        tokens.append(m.groups())
    pos = 0

    def value():
        nonlocal pos
        t = tokens[pos]
        pos += 1
        if t[0]:
            return table()
        if t[6] is not None:
            return bytes(t[6], "utf-8").decode("unicode_escape").encode("latin-1").decode("utf-8")
        if t[7] is not None:
            return float(t[7]) if "." in t[7] or "e" in t[7] else int(t[7])
        if t[8]:
            return {"true": True, "false": False, "nil": None}[t[8]]
        raise ValueError(f"unexpected token {t}")

    def table():
        nonlocal pos
        out, items = {}, []
        while True:
            t = tokens[pos]
            if t[1]:
                pos += 1
                break
            if t[3]:
                pos += 1
                continue
            if t[4] is not None or t[5] is not None:
                key = t[4] if t[4] is not None else int(t[5])
                pos += 2   # the key and "="
                out[key] = value()
            else:
                items.append(value())
        if items and not out:
            return items
        for i, item in enumerate(items, start=1):
            out[i] = item
        return out

    result = {}
    while pos < len(tokens):
        name = tokens[pos][9]
        pos += 2   # the name and "="
        result[name] = value()
    return result


def main():
    saved = parse_lua(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
    trainers = (saved.get("jsalUIDB") or {}).get("trainers") or {}
    out = []
    for key in sorted(trainers):
        t = trainers[key]
        # "?" is Beast Training, saved as a trainer before that was caught.
        if key.startswith("? @ "):
            continue
        npc, zone = t.get("npc"), t.get("zone")
        if not npc:
            m = re.match(r"^(.*?) @ ([^(]+)", key)
            npc, zone = (m.group(1), m.group(2).strip()) if m else (key, None)
        rows = []
        rows_saved = t.get("rows") or []
        if isinstance(rows_saved, dict):
            rows_saved = [rows_saved[k] for k in sorted(rows_saved)]
        for r in map(row_of, rows_saved):
            # Visits saved before Forever's order was known hold the kind
            # where the rank should be.
            kind = r.get("category") if r.get("category") in KINDS else r.get("rank") if r.get("rank") in KINDS else None
            rows.append({"spell": r.get("spell"), "name": r.get("name"), "cost": r.get("cost"),
                         "level": r.get("level"), "kind": kind})
        out.append({"class": t.get("class"), "npc": npc, "zone": zone, "seen": t.get("seen"), "rows": rows})
    # A warlock's demon trainer sells Grimoires from a shop window instead.
    shops = []
    for key, s in sorted(((saved.get("jsalUIDB") or {}).get("grimoires") or {}).items()):
        shops.append({"class": s.get("class"), "npc": s.get("npc"), "zone": s.get("zone"), "seen": s.get("seen"),
                      "rows": [{"name": r.get("name"), "cost": r.get("cost")} for r in s.get("rows") or []]})
    OUT.parent.mkdir(parents=True, exist_ok=True)
    data = {"trainers": out, "grimoires": shops}
    OUT.write_text(json.dumps(data, indent=1, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
    print(f"-> {OUT.relative_to(ROOT)}: {len(out)} trainers, {len(shops)} Grimoire shops")
    for t in out + shops:
        print(f"  class {t['class']}: {t['npc']}, {t['zone']} ({len(t['rows'])} rows)")


if __name__ == "__main__":
    main()
