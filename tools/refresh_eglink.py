"""Refreshes the quest tags' data from EG Link output: World of Warcraft: Forever
(https://github.com/JIVESCORP/eg-link-output-wowf, CC BY 4.0, data from Efficient Games), whose
players' counts grow every day: Forever's own quests and next-quest links (each live build's
quests.enUS.json) and how often quest items drop for players on the quest (each build's loot.json).
Downloads them into a temporary folder (read as data, never run), updates data/quests/eglink.json
and data/quests/eglink-drops.json, and rebuilds jsalUI/Quests/QuestScoreData.lua.

Run: python -I tools/refresh_eglink.py
Then run the tests and compare the counts it prints with the last time's.
"""
import json
import pathlib
import sys
import tempfile
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import build_quest_scores as build  # noqa: E402

REPO = "JIVESCORP/eg-link-output-wowf"
WANT = ("quests.enUS.json", "loot.json")


def get(url):
    request = urllib.request.Request(url, headers={"User-Agent": "jsal-ui-data-refresh"})
    with urllib.request.urlopen(request, timeout=120) as response:
        return response.read()


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
        build.fetch_eglink(folders["quests.enUS.json"])
        build.fetch_egloot(folders["loot.json"])
    build.build()


if __name__ == "__main__":
    main()
