"""Copies the trainer visits saved in game into data/prices/trainers.json.

jsal.ui saves every trainer it sees to its SavedVariables (jsalUI.lua). This
takes just the trainers from that file: each one's class, name, zone and
rows (spell, price, level, kind), so build_spells.py can ship the prices
with the addon. Nothing else in the saved file is copied.

The saved file keeps only each trainer's latest visit, and a trainer charges
less at a better standing with its faction, so a revisit can save lower
prices than the ones already baked. The bake is therefore merged into the
trainers.json already there, never written over it: what's there stands,
and a visit changes it only where it brings a higher price or something new.
  - A trainer is the same one by class, name and zone (where two share all
    three, by the time they were seen, then by order).
  - A row (a spell, or a Grimoire by name) the visit prices higher replaces
    the old row whole: a price that went up is taken. One it prices the same
    or lower leaves the old row as it was (its cost, and its level, which a
    later visit saves as 0 for a rank already bought).
  - A row or trainer the visit has and the file lacks is added; one the file
    has and the visit lacks is kept.
  - A trainer's "seen" moves to the visit only when something was taken from
    it.
It prints, by trainer, what it kept higher, what it raised and what it
added, so the diff of trainers.json is explained by the run.

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


def row_key(r):
    return r.get("spell") if r.get("spell") is not None else r.get("name")


def row_text(r):
    return f"{r.get('name')} ({r['spell']})" if r.get("spell") is not None else str(r.get("name"))


def merge_one(old, new):
    """One trainer's last bake and its new visit as one entry, and what was
    kept higher, raised and added (lists of text)."""
    kept, raised, added = [], [], []
    fresh = {}
    for r in new["rows"]:
        fresh.setdefault(row_key(r), r)
    rows, have = [], set()
    for r in old["rows"]:
        k = row_key(r)
        have.add(k)
        n = fresh.get(k)
        if n is not None and (n.get("cost") or 0) > (r.get("cost") or 0):
            raised.append(f"{row_text(r)} {r.get('cost')} to {n.get('cost')}")
            rows.append(n)
            continue
        if n is not None and (n.get("cost") or 0) < (r.get("cost") or 0):
            kept.append(f"{row_text(r)} {r.get('cost')} over {n.get('cost')}")
        rows.append(r)
    for r in new["rows"]:
        k = row_key(r)
        if k not in have:
            have.add(k)
            added.append(f"{row_text(r)} {r.get('cost')}")
            rows.append(r)
    if not raised and not added:
        return old, kept, raised, added
    out = dict(new)
    out["rows"] = rows
    return out, kept, raised, added


def merge(old_list, new_list, what):
    """A whole list (trainers or Grimoire shops) merged, printing what each
    trainer kept higher, raised and added."""
    pool = {}
    for i, t in enumerate(old_list):
        pool.setdefault((t.get("class"), t.get("npc"), t.get("zone")), []).append(i)
    used, out = set(), []
    for t in new_list:
        same = [i for i in pool.get((t.get("class"), t.get("npc"), t.get("zone")), []) if i not in used]
        pick = next((i for i in same if old_list[i].get("seen") == t.get("seen")), same[0] if same else None)
        name = f"  {what} {t.get('npc')}, {t.get('zone')} (class {t.get('class')})"
        if pick is None:
            out.append(t)
            print(f"{name}: new, {len(t['rows'])} rows")
            continue
        used.add(pick)
        merged, kept, raised, added = merge_one(old_list[pick], t)
        out.append(merged)
        for label, items in (("kept higher than this visit", kept), ("raised", raised), ("added", added)):
            if items:
                print(f"{name}: {label}, {len(items)}: " + "; ".join(items))
    for i, t in enumerate(old_list):
        if i not in used:
            out.append(t)
            print(f"  {what} {t.get('npc')}, {t.get('zone')} (class {t.get('class')}): kept from the last bake, not in this saved file")
    return out


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
    last = json.loads(OUT.read_text(encoding="utf-8")) if OUT.exists() else {}
    print(f"{len(out)} trainers and {len(shops)} Grimoire shops in the saved file; "
          f"{len(last.get('trainers') or [])} and {len(last.get('grimoires') or [])} in the last bake")
    out = merge(last.get("trainers") or [], out, "trainer")
    shops = merge(last.get("grimoires") or [], shops, "Grimoire shop")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    data = {"trainers": out, "grimoires": shops}
    OUT.write_text(json.dumps(data, indent=1, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
    print(f"-> {OUT.relative_to(ROOT)}: {len(out)} trainers, {len(shops)} Grimoire shops")


if __name__ == "__main__":
    main()
