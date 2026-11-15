"""Refreshes the quest tags' data from EG Link output: World of Warcraft: Forever
(https://github.com/JIVESCORP/eg-link-output-wowf, CC BY 4.0, data from Efficient Games), whose
players' counts grow every day: Forever's own quests and next-quest links (each live build's
quests.enUS.json), how often quest items drop for players on the quest (each build's loot.json),
and every trainer players opened, with what each teaches and its costs (each build's trainers.json).
Downloads them into a temporary folder (read as data, never run), updates data/quests/eglink.json,
data/quests/eglink-drops.json and data/trainers/eglink-trainers.json, and rebuilds
jsalUI/Quests/QuestScoreData.lua; then runs tools/build_spells.py and tools/build_trainers.py, which read
the trainers file (Training/SpellData.lua's prices, TrainerData.lua's weapon masters and pet trainers).

Run: python -I tools/refresh_eglink.py
Then run the tests and compare the counts it prints with the last time's.
"""
import json
import pathlib
import re
import subprocess
import sys
import tempfile
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import build_quest_scores as build  # noqa: E402

REPO = "JIVESCORP/eg-link-output-wowf"
WANT = ("quests.enUS.json", "loot.json", "trainers.json", "creature_details.enUS.json")
TRAINERS = ROOT / "data" / "trainers" / "eglink-trainers.json"


def get(url):
    request = urllib.request.Request(url, headers={"User-Agent": "jsal-ui-data-refresh"})
    with urllib.request.urlopen(request, timeout=120) as response:
        return response.read()


def merge_trainers(folder, revision):
    """Every trainer players opened on a live build, newest build first: its name, where players stood
    when they opened it (uiMap is Forever's own map, mapX/mapY 0-1 across it), whether it teaches a
    profession, and each service by spell ID with the level it's learned at (0 means only players who
    already knew it saw it), the skill it needs and its price in copper at each standing seen (4
    Neutral to 8 Exalted; a better standing is cheaper, so the full price is the one at the lowest
    standing). A class trainer lists only what players of that class saw, so services from older builds
    are kept where the newer ones lack them."""
    builds = sorted((f for f in pathlib.Path(folder).glob("*.json")), key=lambda f: [int(x) for x in f.stem.split(".")])
    out = {}
    for f in builds:   # oldest first, so a newer build's value replaces an older one
        data = json.loads(f.read_text(encoding="utf-8"))
        for npc, t in data.get("trainers", {}).items():
            row = out.setdefault(npc, {"services": {}})
            for key in ("name", "trainerType", "tradeskill", "lastSeen"):
                if t.get(key) is not None:
                    row[key] = t[key]
            if t.get("positions"):
                row["positions"] = [{k: p[k] for k in ("uiMap", "mapX", "mapY") if k in p} for p in t["positions"]]
            row["builds"] = sorted(set(row.get("builds", [])) | {f.stem})
            for spell, sv in (t.get("services") or {}).items():
                old = row["services"].get(spell, {})
                new = {k: sv[k] for k in ("name", "rankText", "level", "skill", "skillRank", "profession", "step") if sv.get(k) is not None}
                if new.get("level") == 0 and old.get("level"):
                    new["level"] = old["level"]
                costs = dict(old.get("costs", {}))
                costs.update(sv.get("costs") or {})
                if costs:
                    new["costs"] = costs
                row["services"][spell] = new
    TRAINERS.parent.mkdir(parents=True, exist_ok=True)
    TRAINERS.write_text(json.dumps({
        "about": "Every trainer players opened on WoW Forever, from EG Link output: World of Warcraft: Forever "
                 "(https://github.com/JIVESCORP/eg-link-output-wowf), data from Efficient Games "
                 "(https://efficient.games), licensed under CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/); "
                 "merged across live builds and reduced to name, spots, services, levels and costs by "
                 "tools/refresh_eglink.py.",
        "revision": revision, "trainers": out}, indent=0, sort_keys=True), encoding="utf-8")
    print(f"kept {len(out)} trainers ({sum(len(t['services']) for t in out.values())} services) in "
          f"{TRAINERS.relative_to(ROOT)}")


def main():
    head = json.loads(get(f"https://api.github.com/repos/{REPO}/commits/main"))["sha"]
    tree = json.loads(get(f"https://api.github.com/repos/{REPO}/git/trees/{head}?recursive=1"))["tree"]
    with tempfile.TemporaryDirectory() as scratch:
        folders = {name: pathlib.Path(scratch, name.split(".")[0]) for name in WANT}
        for folder in folders.values():
            folder.mkdir()
        count = 0
        for entry in tree:
            parts = entry["path"].split("/")
            if entry["type"] == "blob" and len(parts) == 4 and parts[:2] == ["data", "wowf"] and parts[3] in WANT:
                body = get(f"https://raw.githubusercontent.com/{REPO}/{head}/{entry['path']}")
                (folders[parts[3]] / f"{parts[2]}.json").write_bytes(body)
                count += 1
        print(f"read {count} files from {REPO} at {head[:7]}")
        build.EGLINK_REVISION = head
        build.EGLOOT_REVISION = head
        build.fetch_eglink(folders["quests.enUS.json"], folders["creature_details.enUS.json"])
        build.fetch_egloot(folders["loot.json"])
        merge_trainers(folders["trainers.json"], head)
    build.build()
    # The training builds read the trainers file too: rebuild them, for the same game build as before.
    spells = (ROOT / "jsalUI" / "Training" / "SpellData.lua").read_text(encoding="utf-8")
    game = re.search(r"own spell tables \(build ([\d.]+)\)", spells)
    for tool, args in (("build_spells.py", [game.group(1)] if game else []), ("build_trainers.py", [])):
        subprocess.run([sys.executable, "-I", str(ROOT / "tools" / tool)] + args, check=True)


if __name__ == "__main__":
    main()
