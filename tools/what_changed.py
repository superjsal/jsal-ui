"""What changed upstream since jsal.ui's data was last built: one report for keeping up with Forever.

It compares each source the data comes from with what jsal.ui ships, and reads nothing it runs:
  - The game's own tables (wago.tools, product "wowf"): the newest Forever build against the build
    named at the top of each generated file (SpellData, TalentData, DungeonData, FlightData). When
    one is behind, the newest build's tables are downloaded (as data, into a temporary folder) and
    compared with data/: new dungeons, new bosses, new trainer spells.
  - Blizzard's UI code (github.com/Gethe/wow-ui-source, branch forever), which the private tests'
    lists of game functions are built from: its newest commit against data/sources.json.
  - EG Link (github.com/JIVESCORP/eg-link-output-wowf): its newest commit against the revision
    data/trainers/eglink-trainers.json was refreshed from (tools/refresh_eglink.py).
  - WoWSims Forever (github.com/wowsims/forever): its newest commit against
    data/gear/wowsims-forever/COMMIT, which the stat weights were worked out from, and which the
    Endgame page's consumables (data/gear/wowsims-forever/consumables, tools/build_consumables.py)
    were read at.
And what's still missing in what ships (not a change, a to-do): bosses with no loot, gear with no
known source. Those come from Wowhead Forever, which is read by hand in the browser.

Run: python -I tools/what_changed.py              the report, as text
     python -I tools/what_changed.py --markdown   the same, for a GitHub issue
     python -I tools/what_changed.py --accept-ui  after rebuilding the private tests' function lists
                                                  (forever_names_build.lua): records Gethe's commit
Exit code: 0 when nothing has changed, 10 when something has (the weekly job opens an issue then).
A token in GITHUB_TOKEN or GH_TOKEN is used for GitHub's API when there is one (more requests).
"""

import csv
import io
import json
import os
import pathlib
import re
import sys
import tempfile
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCES = ROOT / "data" / "sources.json"
AGENT = "jsal.ui data check (github.com/superjsal/jsal-ui)"

# What each generated file was built from: the build number at its top.
GENERATED = {
    "Spells and trainers": "jsalUI/Training/SpellData.lua",
    "Talents": "jsalUI/Talents/TalentData.lua",
    "Dungeons and bosses": "jsalUI/Dungeons/DungeonData.lua",
    "Flight paths": "jsalUI/Games/FlightData.lua",
}


def fetch(url, token=None):
    request = urllib.request.Request(url, headers={"User-Agent": AGENT})
    if token:
        request.add_header("Authorization", "Bearer " + token)
    with urllib.request.urlopen(request, timeout=60) as response:
        return response.read()


def github(path):
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    return json.loads(fetch("https://api.github.com/" + path, token))


def build_of(path):
    head = (ROOT / path).read_text(encoding="utf-8", errors="replace")[:2000]
    m = re.search(r"build (\d+\.\d+\.\d+\.\d+)", head)
    return m.group(1) if m else None


def number(build):
    return tuple(int(x) for x in build.split("."))


def latest_forever_build():
    builds = json.loads(fetch("https://wago.tools/api/builds")).get("wowf") or []
    versions = [b["version"] for b in builds if re.fullmatch(r"\d+\.\d+\.\d+\.\d+", b.get("version", ""))]
    return max(versions, key=number) if versions else None


def table(name, build, folder):
    """A game table of a build, from wago.tools, saved as data in `folder` and read as CSV rows."""
    path = pathlib.Path(folder) / (name + ".csv")
    if not path.exists():
        path.write_bytes(fetch(f"https://wago.tools/db2/{name}/csv?build={build}"))
    return list(csv.DictReader(io.StringIO(path.read_text(encoding="utf-8", errors="replace"))))


def shipped(rel):
    with open(ROOT / rel, encoding="utf-8", errors="replace", newline="") as f:
        return list(csv.DictReader(f))


def new_in_build(build, folder):
    """What the newest build's tables have that data/ doesn't: dungeons, bosses, trainer spells."""
    lines = []
    have = {r["ID"] for r in shipped("data/dungeons/LFGDungeons.csv")}
    added = [r for r in table("LFGDungeons", build, folder) if r["ID"] not in have]
    if added:
        names = ", ".join(sorted({r["Name_lang"] for r in added if r.get("Name_lang")})[:12])
        lines.append(f"{len(added)} new dungeon entries: {names}")
    have = {r["ID"] for r in shipped("data/dungeons/DungeonEncounter.csv")}
    added = [r for r in table("DungeonEncounter", build, folder) if r["ID"] not in have]
    if added:
        names = ", ".join(r["Name_lang"] for r in added[:12])
        lines.append(f"{len(added)} new bosses: {names}{' ...' if len(added) > 12 else ''}")
    have = {(r["SkillLine"], r["Spell"]) for r in shipped("data/spells/SkillLineAbility.csv")}
    added = [r for r in table("SkillLineAbility", build, folder)
             if (r["SkillLine"], r["Spell"]) not in have and r.get("AcquireMethod") == "0"]
    if added:
        lines.append(f"{len(added)} new spell{'' if len(added) == 1 else 's'} taught by trainers")
    return lines


def gaps():
    """What ships without what Wowhead would give: bosses with no loot, gear with no source."""
    data = (ROOT / "jsalUI/Dungeons/DungeonData.lua").read_text(encoding="utf-8")
    loot = (ROOT / "jsalUI/Dungeons/DungeonLoot.lua").read_text(encoding="utf-8")
    with_loot = {int(m.group(1)) for m in re.finditer(r"\[(\d+)\] = \{ \{", loot)}
    bosses = re.findall(r"\{ (\d+), \"([^\"]+)\"", data)
    empty = [name for eid, name in bosses if int(eid) not in with_loot]
    gear = (ROOT / "jsalUI/Gear/GearData.lua").read_text(encoding="utf-8")
    items = re.findall(r"(?:^|[;\"])\d+,\d+,\d+,\d+,-?\d+,\d+,\d+,\d+,(\d+),\d+", gear)
    unknown = sum(1 for kind in items if kind == "0")
    lines = [f"{len(empty)} of {len(bosses)} bosses have no loot listed"
             + (f": {', '.join(empty[:8])}{' ...' if len(empty) > 8 else ''}" if empty else "")]
    lines.append(f"{unknown} of {len(items)} gear items have no known source")
    return lines


def main():
    markdown = "--markdown" in sys.argv
    known = json.loads(SOURCES.read_text(encoding="utf-8")) if SOURCES.exists() else {}
    changed, sections = [], []

    # The game's tables.
    game = []
    latest = latest_forever_build()
    if not latest:
        game.append("wago.tools listed no Forever build (product wowf): check it by hand")
    behind = []
    for label, path in GENERATED.items():
        built = build_of(path)
        if built and latest and number(built) < number(latest):
            behind.append(f"{label}: built from {built}")
    if behind:
        game.append(f"Newest Forever build is {latest}; behind it:")
        game += ["  " + b for b in behind]
        with tempfile.TemporaryDirectory() as folder:
            try:
                found = new_in_build(latest, folder)
            except Exception as e:  # a download that fails is said, not hidden
                found = [f"couldn't compare the new build's tables: {e}"]
        game += ["  " + f for f in found] or ["  (no new dungeons, bosses or trainer spells in its tables)"]
        game.append(f"  Run tools/fetch_tables.py {latest}: the tables, then the four builds; then the tests")
        changed.append("game build")
    elif latest:
        game.append(f"Up to date with the newest Forever build, {latest}")
    sections.append(("The game's own tables", game))

    # Blizzard's UI code.
    ui = []
    head = github("repos/Gethe/wow-ui-source/commits/forever")
    sha, title = head["sha"], head["commit"]["message"].splitlines()[0]
    if known.get("gethe") != sha:
        ui.append(f"New commit on Gethe/wow-ui-source forever: {title} ({sha[:7]}). Rebuild the private "
                  "tests' function lists (forever_names_build.lua, forever_bare_build.lua, "
                  "forever_api_build.lua), run the tests, then: what_changed.py --accept-ui")
        changed.append("UI code")
    else:
        ui.append(f"No change since {title} ({sha[:7]})")
    sections.append(("Blizzard's UI code", ui))

    # EG Link.
    eg = []
    trainers = json.loads((ROOT / "data/trainers/eglink-trainers.json").read_text(encoding="utf-8"))
    have = trainers.get("revision")
    commits = github("repos/JIVESCORP/eg-link-output-wowf/commits?per_page=1")
    sha = commits[0]["sha"] if commits else None
    if sha and sha != have:
        eg.append(f"New EG Link data ({sha[:7]}, {commits[0]['commit']['committer']['date'][:10]}); "
                  f"jsal.ui has {str(have)[:7]}. Run tools/refresh_eglink.py: quest drops, trainers, vendors")
        changed.append("EG Link")
    else:
        eg.append("No change")
    sections.append(("EG Link (players' quest drops, trainers, vendors)", eg))

    # WoWSims Forever.
    sims = []
    have = (ROOT / "data/gear/wowsims-forever/COMMIT").read_text(encoding="utf-8").strip()
    head = github("repos/wowsims/forever/commits?per_page=1")[0]
    if head["sha"] != have:
        compare = github(f"repos/wowsims/forever/compare/{have}...{head['sha']}")
        files = [f["filename"] for f in compare.get("files", [])]
        # The presets (talents, gear, rotations) the weights were worked out on.
        weighty = [f for f in files if re.search(r"/presets/|/apls?/|preset", f, re.I)]
        sims.append(f"{compare.get('ahead_by', '?')} new commits since the weights were worked out "
                    f"({have[:7]} to {head['sha'][:7]}), {len(files)} files changed"
                    + (f", {len(weighty)} of them presets or rotations: {', '.join(weighty[:5])}"
                       if weighty else ", none of them presets or rotations"))
        if weighty:
            sims.append("Worth re-running its Stat Weights tool for the trees whose presets changed")
            changed.append("WoWSims")
        # Each spec's consumables, which the Endgame page's RAID NIGHT lists.
        consumed = [f for f in files if re.search(r"defaults\.siml$|presets\.ts$|consumables_auto_gen\.ts$", f)]
        if consumed:
            sims.append(f"{len(consumed)} files that name consumables changed: {', '.join(consumed[:5])}. Fetch them into "
                        "data/gear/wowsims-forever/consumables and run tools/build_consumables.py")
            if "WoWSims" not in changed:
                changed.append("WoWSims")
    else:
        sims.append("No change")
    sections.append(("WoWSims Forever (stat weights)", sims))

    sections.append(("Still missing (from Wowhead Forever, read by hand)", gaps()))

    out = []
    if markdown:
        out.append("Forever data has changed: " + ", ".join(changed) + "." if changed else "Nothing has changed.")
        for title, lines in sections:
            out.append("")
            out.append("### " + title)
            out += ["- " + line.strip() if not line.startswith("  ") else "  - " + line.strip() for line in lines]
    else:
        out.append("Changed: " + (", ".join(changed) if changed else "nothing"))
        for title, lines in sections:
            out.append("")
            out.append(title)
            out += ["  " + line for line in lines]
    print("\n".join(out))
    return 10 if changed else 0


def accept_ui():
    known = json.loads(SOURCES.read_text(encoding="utf-8")) if SOURCES.exists() else {}
    head = github("repos/Gethe/wow-ui-source/commits/forever")
    known["gethe"] = head["sha"]
    known["gethe_title"] = head["commit"]["message"].splitlines()[0]
    SOURCES.write_text(json.dumps(known, indent=2) + "\n", encoding="utf-8")
    print(f"Recorded Gethe/wow-ui-source forever at {known['gethe'][:7]} ({known['gethe_title']})")
    return 0


if __name__ == "__main__":
    sys.exit(accept_ui() if "--accept-ui" in sys.argv else main())
