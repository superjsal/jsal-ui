"""Builds jsalUI/Quests/QuestScoreData.lua: for each quest, its place in a chain and how often the
items it asks for drop, for the quest tags beside the tracker (how long a quest is likely to take,
and whether skipping it costs later quests).

From pfQuest (https://github.com/shagu/pfQuest, MIT licence, data/quests/pfquest/LICENSE), whose
database comes from VMaNGOS, Classic's own numbers: each quest's earlier quests ("pre") and the
races it's for, each item's drop chance from every creature, and the items' English names. Forever
is built on Classic and keeps its quests, so a few chances may be off where Forever changed a drop.

Two steps:
  python -I tools/build_quest_scores.py --from <pfQuest checkout>
      reads pfQuest's db/quests.lua, db/items.lua and db/enUS/items.lua (as data, never run) and
      keeps what's needed in data/quests/pfquest.json;
  python -I tools/build_quest_scores.py
      writes the Lua from that file.

Each quest is one line of text, read only for the quests in your log: "k,n;Item=chance;..."
where k of n is the quest's place in its chain (left empty when it stands alone) and chance is the
best drop chance in percent among the creatures that drop the item. Every quest pfQuest knows has a
line, even an empty one, so a quest with none is one it doesn't know (new to Forever).
"""

import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SNAPSHOT = ROOT / "data" / "quests" / "pfquest.json"
OUT = ROOT / "jsalUI" / "Quests" / "QuestScoreData.lua"
REVISION = "104f35678ca39ab1fb78b655f815cc7016f5e0c8"  # pfQuest master, as read


def fetch(checkout):
    sys.path.insert(0, str(ROOT / "tools"))
    from luadata import table_after, seq

    db = pathlib.Path(checkout) / "db"
    read = lambda p: p.read_text(encoding="utf-8")
    quests = table_after(read(db / "quests.lua"), 'pfDB["quests"]["data"] =')
    items = table_after(read(db / "items.lua"), 'pfDB["items"]["data"] =')
    names = table_after(read(db / "enUS" / "items.lua"), 'pfDB["items"]["enUS"] =')
    out = {}
    for qid, q in quests.items():
        entry = {}
        pre = seq(q.get("pre"))
        if pre:
            entry["pre"] = pre
        if q.get("race"):
            entry["race"] = q["race"]
        drops = {}
        for item in seq((q.get("obj") or {}).get("I")):
            chances = [c for c in ((items.get(item) or {}).get("U") or {}).values() if c and c > 0]
            name = names.get(item)
            if chances and name:
                drops[name] = round(max(chances), 2)
        if drops:
            entry["drops"] = drops
        out[str(qid)] = entry
    SNAPSHOT.parent.mkdir(parents=True, exist_ok=True)
    SNAPSHOT.write_text(json.dumps({"source": "pfQuest", "revision": REVISION, "quests": out},
                                   indent=0, sort_keys=True, ensure_ascii=False), encoding="utf-8")
    print(f"kept {len(out)} quests in {SNAPSHOT.relative_to(ROOT)}")


EGLINK = ROOT / "data" / "quests" / "eglink.json"
EGLINK_REVISION = "e0f8585914c134d9cb5d76756bd065b1e3e92ece"  # JIVESCORP/eg-link-output-wowf main, as read


def fetch_eglink(folder):
    """Every quest Forever's server has described to EG Link's players (quests.enUS.json from each
    live build under data/wowf/ of https://github.com/JIVESCORP/eg-link-output-wowf, CC BY 4.0,
    data from Efficient Games), newest build first: its level, the next quest, the races it's for
    (left out when every race) and the items it asks for, by ID."""
    files = []
    for f in pathlib.Path(folder).glob("*.json"):
        d = json.loads(f.read_text(encoding="utf-8"))
        files.append((d["meta"]["clientBuild"], d["quests"]))
    out = {}
    for build, quests in sorted(files, reverse=True):
        for qid, q in quests.items():
            if qid in out:
                continue
            entry = {"level": q.get("level")}
            if q.get("nextQuestId"):
                entry["next"] = q["nextQuestId"]
            mask = int(q.get("raceMask") or "0", 16)
            if mask and mask != (1 << 64) - 1:
                entry["race"] = mask
            items = [o["objectId"] for o in q.get("objectives", []) if o.get("type") == "item" and o.get("objectId")]
            if items:
                entry["items"] = items
            out[qid] = entry
    EGLINK.write_text(json.dumps({"source": "EG Link output: World of Warcraft: Forever (Efficient Games, CC BY 4.0)",
                                  "revision": EGLINK_REVISION, "builds": sorted(b for b, _ in files),
                                  "quests": out}, indent=0, sort_keys=True), encoding="utf-8")
    print(f"kept {len(out)} quests in {EGLINK.relative_to(ROOT)}")


def same_side(a, b):
    """Whether two quests can be done by one character: their race masks overlap, or either is open."""
    return not a or not b or (a & b) != 0


def chains(quests):
    """Each quest's place in its chain: (quests before it + 1, that plus the quests after it)."""
    after = {}
    for qid, q in quests.items():
        for p in q.get("pre", []):
            after.setdefault(str(p), set()).add(qid)

    def walk(start, step):
        seen, todo = set(), [start]
        race = quests[start].get("race")
        while todo:
            for n in step(todo.pop()):
                if n not in seen and n in quests and same_side(race, quests[n].get("race")):
                    seen.add(n)
                    todo.append(n)
        return seen

    out = {}
    for qid in quests:
        before = walk(qid, lambda x: [str(p) for p in quests.get(x, {}).get("pre", [])])
        later = walk(qid, lambda x: after.get(x, ()))
        if before or later:
            out[qid] = (len(before) + 1, len(before) + 1 + len(later))
    return out


WOWHEAD = ROOT / "data" / "quests" / "wowhead-drops.json"
FEWEST_KILLS = 10   # a drop chance from fewer kills than this isn't trusted


def wowhead_chance(entry):
    """The best drop chance, in percent, among the creatures Wowhead Forever has seen kill this item
    at least FEWEST_KILLS times, or None."""
    rates = [dropped / kills for _, dropped, kills in (entry or {}).get("npcs", []) if kills >= FEWEST_KILLS]
    return round(100 * max(rates), 2) if rates else None


def merged():
    """pfQuest's quests, with EG Link's: Forever's own next quests as chain links, and the quests new
    to Forever, whose items take Wowhead Forever's drop chances (marked "w")."""
    quests = {k: dict(v) for k, v in json.loads(SNAPSHOT.read_text(encoding="utf-8"))["quests"].items()}
    if not EGLINK.exists():
        return quests
    eg = json.loads(EGLINK.read_text(encoding="utf-8"))["quests"]
    wh = json.loads(WOWHEAD.read_text(encoding="utf-8"))["items"] if WOWHEAD.exists() else {}
    for qid, q in eg.items():
        if qid in quests:
            continue
        entry = {"forever": True}
        if q.get("race"):
            entry["race"] = q["race"]
        drops = {}
        for item in q.get("items", []):
            got = wh.get(str(item))
            chance = wowhead_chance(got)
            if chance is not None and got.get("name"):
                drops[got["name"]] = "%gw" % chance
        if drops:
            entry["drops"] = drops
        quests[qid] = entry
    for qid, q in eg.items():
        nxt = str(q.get("next") or "")
        if nxt in quests and qid in quests and nxt != qid:
            pre = quests[nxt].setdefault("pre", [])
            if int(qid) not in pre:
                quests[nxt]["pre"] = pre + [int(qid)]
    return quests


def build():
    quests = merged()
    place = chains(quests)
    lines = []
    for qid in sorted(quests, key=int):
        drops = quests[qid].get("drops", {})
        for name in drops:
            assert ";" not in name and "=" not in name and '"' not in name, name
        text = ("%d,%d" % place[qid]) if qid in place else ""
        text += "".join(";%s=%s" % (name, chance if isinstance(chance, str) else ("%g" % chance))
                        for name, chance in sorted(drops.items()))
        lines.append('[%s]="%s",' % (qid, text.replace("\\", "\\\\")))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    head = [
        "-- Generated by tools/build_quest_scores.py from pfQuest (MIT licence, Copyright (c) 2017-2021",
        "-- Eric Mauser (Shagu); data/quests/pfquest/LICENSE). Don't edit: rebuild with that tool.",
        "-- Quests new to Forever, and Forever's own chain links, from EG Link output: World of Warcraft:",
        "-- Forever (data from Efficient Games, https://efficient.games, CC BY 4.0); their drop chances from",
        "-- Wowhead Forever. Each quest: \"k,n;Item=chance;...\", its place in its chain (empty when it",
        "-- stands alone) and the best drop chance, in percent, of each item it asks for (\"w\": Wowhead's).",
        "local _, ns = ...",
        "ns.QuestScoreData = {",
    ]
    OUT.write_bytes(("\r\n".join(head + lines + ["}", ""])).encode("utf-8"))
    print(f"wrote {len(lines)} quests ({sum(1 for q in place)} in chains) to {OUT.relative_to(ROOT)}, "
          f"{OUT.stat().st_size // 1024} KB")


if __name__ == "__main__":
    if len(sys.argv) > 2 and sys.argv[1] == "--from":
        fetch(sys.argv[2])
    if len(sys.argv) > 2 and sys.argv[1] == "--eglink":
        fetch_eglink(sys.argv[2])
    build()
