"""Brings the game's own tables in data/ up to a Forever build, then rebuilds what's made from them.

When tools/what_changed.py says the data is built from an older build than the newest, this is the
one command. Each table in data/spells, data/talents, data/dungeons, data/taxi and data/gear is fetched again
from wago.tools (https://wago.tools/db2/<Table>/csv?build=<build>), read as data, and saved the way
the old file was, so a diff shows only what the game changed:
  - only the old file's columns, in its order (several are kept trimmed, Map and Spell among them);
  - wago's own quoting, or none where the old file had none (and no comma needs it);
  - the old rows in their old order by ID, a changed row in its place, new rows after them (wago
    can send the same rows in another order);
  - the old file's line endings;
  - only the rows a cut table keeps (CUT below: SpellMisc keeps the rows with a duration; KEEP:
    SpellEffect keeps only the effects that teach a spell).
A table whose new build lacks one of the old columns is left as it was, and said.

Then it sets BUILD in tools/build_dungeons.py and runs tools/build_spells.py, build_talents.py,
build_dungeons.py and build_taxi.py for the build. Prices, EG Link and Wowhead are other tools'
(refresh_eglink.py, bake_prices.py, tools/wowhead/README.md).

Run: python -I tools/fetch_tables.py 1.60.1.70959
     python -I tools/fetch_tables.py 1.60.1.70959 --tables-only   fetch, don't rebuild
Then run the tests, and look at the diff of data/ for what the build changed.
"""

import pathlib
import re
import subprocess
import sys
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
FOLDERS = ["data/spells", "data/talents", "data/dungeons", "data/taxi", "data/gear"]
BUILDS = ["build_spells.py", "build_talents.py", "build_dungeons.py", "build_taxi.py"]
OUTPUTS = ["jsalUI/Training/SpellData.lua", "jsalUI/Talents/TalentData.lua", "jsalUI/Dungeons/DungeonData.lua",
           "jsalUI/Dungeons/DungeonLoot.lua", "jsalUI/Games/FlightData.lua"]
AGENT = "jsal-ui data refresh"
# Tables kept to some of their rows: the file's name, the column, and the value a row is left out for.
CUT = {"SpellMisc.csv": ("DurationIndex", "0")}
# Tables kept to the rows with one value in a column: the file's name, the column, the value kept.
KEEP = {"SpellEffect.csv": ("Effect", "36")}


def fetch(name, build):
    url = f"https://wago.tools/db2/{name}/csv?build={build}"
    request = urllib.request.Request(url, headers={"User-Agent": AGENT})
    with urllib.request.urlopen(request, timeout=120) as response:
        return response.read().decode("utf-8")


def records(text):
    """Rows of raw field texts, quotes kept, split on commas and line breaks outside quotes."""
    rows, row, field, quoted, i = [], [], [], False, 0
    while i < len(text):
        c = text[i]
        if quoted:
            field.append(c)
            if c == '"':
                if i + 1 < len(text) and text[i + 1] == '"':
                    field.append('"')
                    i += 1
                else:
                    quoted = False
        elif c == '"':
            quoted = True
            field.append(c)
        elif c == ",":
            row.append("".join(field))
            field = []
        elif c in "\r\n":
            if c == "\r" and i + 1 < len(text) and text[i + 1] == "\n":
                i += 1
            row.append("".join(field))
            field = []
            rows.append(row)
            row = []
        else:
            field.append(c)
        i += 1
    if field or row:
        row.append("".join(field))
        rows.append(row)
    return rows


def bare(text):
    return text[1:-1].replace('""', '"') if len(text) >= 2 and text[0] == '"' and text[-1] == '"' else text


def refresh(path, build):
    old = path.read_bytes().decode("utf-8")
    nl = "\r\n" if "\r\n" in old else "\n"
    old_rows = records(old)
    header = [bare(h) for h in old_rows[0]]
    new = records(fetch(path.stem, build))
    names = [bare(h) for h in new[0]]
    missing = [c for c in header if c not in names]
    if missing:
        return f"{path.name}: the build has no column {', '.join(missing)}; left as it was"
    at = [names.index(c) for c in header]
    unquoted = '"' not in old
    if path.name in CUT:
        column, dropped = CUT[path.name]
        j = names.index(column)
        new = new[:1] + [r for r in new[1:] if len(r) != len(names) or bare(r[j]) != dropped]
    if path.name in KEEP:
        column, kept = KEEP[path.name]
        j = names.index(column)
        new = new[:1] + [r for r in new[1:] if len(r) != len(names) or bare(r[j]) == kept]
    lines = {}
    order = []
    for r in new[1:]:
        if len(r) != len(names):
            raise SystemExit(f"{path.name}: a row of {len(r)} fields, not {len(names)}: {r[:3]}")
        fields = [r[j] for j in at]
        if unquoted:
            fields = [bare(f) if "," not in bare(f) and '"' not in bare(f) else f for f in fields]
        key = bare(fields[header.index("ID")]) if "ID" in header else None
        if key is None or key in lines:   # no ID, or not one a row: wago's order as it comes
            lines, order = None, None
            break
        lines[key] = ",".join(fields)
        order.append(key)
    if lines is None:
        body = []
        for r in new[1:]:
            fields = [r[j] for j in at]
            if unquoted:
                fields = [bare(f) if "," not in bare(f) and '"' not in bare(f) else f for f in fields]
            body.append(",".join(fields))
    else:
        id_at = header.index("ID")
        before = [bare(r[id_at]) for r in old_rows[1:] if len(r) > id_at]
        seen = set(before)
        body = [lines[k] for k in before if k in lines] + [lines[k] for k in order if k not in seen]
    text = nl.join([",".join(old_rows[0])] + body) + (nl if old.endswith(nl) else "")
    if text == old:
        return None
    path.write_bytes(text.encode("utf-8"))
    return f"{path.parent.name}/{path.name}: {len(old_rows) - 1} -> {len(body)} rows"


def main():
    if len(sys.argv) < 2 or not re.fullmatch(r"\d+\.\d+\.\d+\.\d+", sys.argv[1]):
        raise SystemExit(__doc__)
    build = sys.argv[1]
    changed = []
    for folder in FOLDERS:
        for path in sorted((ROOT / folder).glob("*.csv")):
            said = refresh(path, build)
            if said:
                changed.append(said)
                print(said)
    print(f"{len(changed)} table{'' if len(changed) == 1 else 's'} changed in {build}")
    if "--tables-only" in sys.argv:
        return
    dungeons = ROOT / "tools" / "build_dungeons.py"
    source = dungeons.read_bytes().decode("utf-8")
    updated = re.sub(r'(?m)^BUILD = "[\d.]+"', f'BUILD = "{build}"', source, count=1)
    if updated != source:
        dungeons.write_bytes(updated.encode("utf-8"))
    # The builds write their files with plain line ends; one kept with CR LF here keeps them.
    crlf = [p for p in OUTPUTS if (ROOT / p).exists() and b"\r\n" in (ROOT / p).read_bytes()]
    for tool in BUILDS:
        args = [sys.executable, "-I", str(ROOT / "tools" / tool)]
        if tool != "build_dungeons.py":
            args.append(build)
        print(f"== {tool}")
        subprocess.run(args, cwd=ROOT, check=True)
    for p in crlf:
        data = (ROOT / p).read_bytes()
        if b"\r\n" not in data:
            (ROOT / p).write_bytes(data.replace(b"\n", b"\r\n"))


if __name__ == "__main__":
    main()
