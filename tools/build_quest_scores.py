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
        drops, asked = {}, {}
        for item in seq((q.get("obj") or {}).get("I")):
            chances = [c for c in ((items.get(item) or {}).get("U") or {}).values() if c and c > 0]
            name = names.get(item)
            if name:
                asked[str(item)] = name
            if chances and name:
                drops[name] = round(max(chances), 2)
        if drops:
            entry["drops"] = drops
        # Every item it asks for, by ID, so Wowhead Forever's chance can take the place of pfQuest's.
        if asked:
            entry["items"] = asked
        out[str(qid)] = entry
    SNAPSHOT.parent.mkdir(parents=True, exist_ok=True)
    SNAPSHOT.write_text(json.dumps({"source": "pfQuest", "revision": REVISION, "quests": out},
                                   indent=0, sort_keys=True, ensure_ascii=False), encoding="utf-8")
    print(f"kept {len(out)} quests in {SNAPSHOT.relative_to(ROOT)}")


EGLINK = ROOT / "data" / "quests" / "eglink.json"
EGLINK_REVISION = "e0f8585914c134d9cb5d76756bd065b1e3e92ece"  # JIVESCORP/eg-link-output-wowf main, as read


def fetch_eglink(folder, creature_folder=None):
    """Every quest Forever's server has described to EG Link's players (quests.enUS.json from each
    live build under data/wowf/ of https://github.com/JIVESCORP/eg-link-output-wowf, CC BY 4.0,
    data from Efficient Games), newest build first: its level, the next quest, the races it's for
    (left out when every race), the items it asks for by ID, its reward tier, and its item and kill
    objectives with how many each needs ("obj": [["i" or "k", id, amount]]). With creature_folder
    (each build's creature_details.enUS.json), the names of the creatures those objectives are for."""
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
            obj = [["i" if o["type"] == "item" else "k", o["objectId"], o["amount"]]
                   for o in q.get("objectives", [])
                   if o.get("type") in ("item", "monster") and o.get("objectId") and o.get("amount")]
            if obj:
                entry["obj"] = obj
            rewards = q.get("rewards") or {}
            if rewards.get("xpDifficulty") is not None:
                entry["xp"] = [rewards["xpDifficulty"], rewards.get("xpMultiplier", 1)]
            out[qid] = entry
    wanted = {str(o[1]) for q in out.values() for o in q.get("obj", []) if o[0] == "k"}
    creatures = {}
    for f in sorted(pathlib.Path(creature_folder).glob("*.json"), reverse=True) if creature_folder else []:
        for cid, c in json.loads(f.read_text(encoding="utf-8")).get("creatures", {}).items():
            if cid in wanted and cid not in creatures and c.get("name"):
                creatures[cid] = c["name"]
    EGLINK.write_text(json.dumps({"source": "EG Link output: World of Warcraft: Forever (Efficient Games, CC BY 4.0)",
                                  "revision": EGLINK_REVISION, "builds": sorted(b for b, _ in files),
                                  "quests": out, "creatures": creatures}, indent=0, sort_keys=True), encoding="utf-8")
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
EGLOOT = ROOT / "data" / "quests" / "eglink-drops.json"
FEWEST_KILLS = 10   # a drop chance from fewer kills than this isn't trusted
QUEST_ONLY = 0.5    # Wowhead's rate from a creature is trusted only when at least this high


def wowhead_chance(entry):
    """Wowhead Forever's chance for a quest item, in percent, or None.

    Wowhead counts every kill of a creature, by players with the quest or without it, and a quest item
    only drops for those with it: Ghoul Fang shows 14-25% there against 80% for someone on the quest.
    So a creature's rate is used only when at least half its kills dropped the item, which happens when
    nearly everyone killing it has the quest (a named target: Carnage's Head, 91%), marked "w". Objects
    (chests, crates, plants) are usually only lootable with the quest, so their rate per opening is
    used as it is, marked "o", each opening counted like a fight. Either needs FEWEST_KILLS tries."""
    entry = entry or {}
    rates = [found / tries for _, found, tries in entry.get("npcs", []) if tries >= FEWEST_KILLS]
    if rates and max(rates) >= QUEST_ONLY:
        return "%gw" % round(100 * max(rates), 2)
    if not entry.get("npcs"):
        rates = [found / tries for _, found, tries in entry.get("objects", []) if tries >= FEWEST_KILLS]
        if rates:
            return "%go" % round(100 * max(rates), 2)
    return None


def fetch_egloot(folder):
    """How often each quest item dropped for EG Link's players who had the quest (the loot.json files
    from each live build under data/wowf/ of https://github.com/JIVESCORP/eg-link-output-wowf, CC BY 4.0,
    data from Efficient Games): the corpses tied to an active quest, per creature, solo only, summed."""
    out = {}
    for f in sorted(pathlib.Path(folder).glob("*.json")):
        d = json.loads(f.read_text(encoding="utf-8"))
        for key, src in d.get("sources", {}).items():
            if not key.startswith("npc:") or "|quest" not in key or "|group" in key:
                continue
            npc = key.split("|")[0][4:]
            for q in (src.get("quests") or {}).values():
                windows = q.get("windows") or 0
                for item, it in (q.get("items") or {}).items():
                    row = out.setdefault(item, {}).setdefault(npc, [0, 0])
                    row[0] += it.get("drops") or 0
                    row[1] += windows
    EGLOOT.write_text(json.dumps({"source": "EG Link output: World of Warcraft: Forever (Efficient Games, CC BY 4.0)",
                                  "revision": EGLOOT_REVISION, "items": out}, indent=0, sort_keys=True), encoding="utf-8")
    print(f"kept {len(out)} quest items in {EGLOOT.relative_to(ROOT)}")


EGLOOT_REVISION = "ea970da071079b32e56f349e09648ff0e314b351"  # JIVESCORP/eg-link-output-wowf main, as read


OWN = ROOT / "data" / "quests" / "own-drops.json"   # the Drop log's counts, baked by tools/bake_drops.py


def eglink_chance(rows, own=None):
    """A chance from players on the quest, in percent, or None: EG Link's best creature with
    FEWEST_KILLS kills or more ("e"), pooled with jsal.ui's own Drop log counts for the item when it has
    that many loots too ("p"); or the Drop log's alone ("j")."""
    best = max(((d, k) for d, k in (rows or {}).values() if k >= FEWEST_KILLS), key=lambda r: r[0] / r[1], default=None)
    mine = own if own and own.get("tries", 0) >= FEWEST_KILLS else None
    if best and mine:
        return "%gp" % round(100 * min(1, (best[0] + mine["finds"]) / (best[1] + mine["tries"])), 2)
    if best:
        return "%ge" % round(100 * min(1, best[0] / best[1]), 2)
    if mine:
        return "%gj" % round(100 * min(1, mine["finds"] / mine["tries"]), 2)
    return None


def merged():
    """pfQuest's quests, with EG Link's: Forever's own next quests as chain links, and the quests new
    to Forever. A drop chance from EG Link's players on the quest ("e") wins anywhere; Classic's quests
    otherwise keep pfQuest's, and new ones take Wowhead Forever's where it can be trusted."""
    quests = {k: dict(v) for k, v in json.loads(SNAPSHOT.read_text(encoding="utf-8"))["quests"].items()}
    if not EGLINK.exists():
        return quests
    eg = json.loads(EGLINK.read_text(encoding="utf-8"))["quests"]
    wh = json.loads(WOWHEAD.read_text(encoding="utf-8"))["items"] if WOWHEAD.exists() else {}
    el = json.loads(EGLOOT.read_text(encoding="utf-8"))["items"] if EGLOOT.exists() else {}
    own = json.loads(OWN.read_text(encoding="utf-8"))["items"] if OWN.exists() else {}
    # Classic's quests: Forever's own players on the quest win over pfQuest's Classic number.
    for q in quests.values():
        for item, name in q.get("items", {}).items():
            chance = eglink_chance(el.get(item), own.get(item))
            if chance is not None:
                q.setdefault("drops", {})[name] = chance
    for qid, q in eg.items():
        if qid in quests:
            continue
        entry = {"forever": True}
        if q.get("race"):
            entry["race"] = q["race"]
        drops = {}
        for item in q.get("items", []):
            got = wh.get(str(item))
            chance = eglink_chance(el.get(str(item)), own.get(str(item))) or wowhead_chance(got)
            if chance is not None and got and got.get("name"):
                drops[got["name"]] = chance
                entry.setdefault("items", {})[str(item)] = got["name"]
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


QUESTXP = ROOT / "data" / "quests" / "QuestXP.csv"   # the game's own table, build 1.60.1.70938, from wago.tools


def full_xp():
    """Each quest's full XP, as the game's QuestXP table gives it for the quest's level and reward tier
    (EG Link's quest records): it matched 1,613 of 1,846 turn-ins players recorded within 5 levels of
    the quest; the rest were a few percent higher, from bonuses. {quest id: (xp, quest level)}."""
    if not (EGLINK.exists() and QUESTXP.exists()):
        return {}
    import csv
    table = {int(r["ID"]): r for r in csv.DictReader(QUESTXP.open(encoding="utf-8"))}
    out = {}
    for qid, q in json.loads(EGLINK.read_text(encoding="utf-8"))["quests"].items():
        level, xp = q.get("level"), q.get("xp")
        row = table.get(level) if isinstance(level, int) else None
        if row and xp:
            amount = round(int(row["Difficulty_%d" % xp[0]]) * (xp[1] or 1))
            if amount > 0:
                out[qid] = (amount, level)
    return out


def item_names():
    """Item names by ID: pfQuest's, then Wowhead Forever's, then the game's own item table."""
    names = {}
    for q in json.loads(SNAPSHOT.read_text(encoding="utf-8"))["quests"].values():
        names.update(q.get("items", {}))
    if WOWHEAD.exists():
        for iid, v in json.loads(WOWHEAD.read_text(encoding="utf-8"))["items"].items():
            if v.get("name"):
                names.setdefault(iid, v["name"])
    sparse = ROOT / "data" / "professions" / "ItemSparse.csv"
    if sparse.exists():
        import csv
        for r in csv.DictReader(sparse.open(encoding="utf-8")):
            if r.get("Display_lang"):
                names.setdefault(r["ID"], r["Display_lang"])
    return names


def objectives():
    """Each quest's item and kill objectives, for a quest not taken yet: [(kind "i"/"k", amount, name)],
    from EG Link's records; the item's name is the one its drop chance is filed under. A quest with an
    objective whose name isn't known gets none, rather than a part of them."""
    if not EGLINK.exists():
        return {}
    data = json.loads(EGLINK.read_text(encoding="utf-8"))
    items, creatures = item_names(), data.get("creatures", {})
    out = {}
    for qid, q in data["quests"].items():
        rows = []
        for kind, oid, amount in q.get("obj", []):
            name = (items if kind == "i" else creatures).get(str(oid))
            if not name or any(c in name for c in "|=#;"):
                rows = None
                break
            rows.append((kind, amount, name))
        if rows:
            out[qid] = rows
    return out


def build():
    quests = merged()
    place = chains(quests)
    paid = full_xp()
    goals = objectives()
    lines, unnumbered = [], 0
    for qid in sorted(quests, key=int):
        drops = quests[qid].get("drops", {})
        for name in drops:
            assert ";" not in name and "=" not in name, name
        # Each drop's item ID, from the IDs the quest asks for, so a client in another language can
        # find the drop by the game's own name for it. A name two of its items share gets none.
        ids = {}
        for iid, name in quests[qid].get("items", {}).items():
            ids.setdefault(name, set()).add(int(iid))
        text = ("%d,%d" % place[qid]) if qid in place else ""
        for name, chance in sorted(drops.items()):
            text += ";%s=%s" % (name, chance if isinstance(chance, str) else ("%g" % chance))
            if len(ids.get(name, ())) == 1:
                text += ":%d" % next(iter(ids[name]))
            else:
                unnumbered += 1
        for kind, amount, name in goals.get(qid, []):
            text += "|%s%d=%s" % (kind, amount, name)
        if qid in paid:
            text += "#%d@%d" % paid[qid]
        lines.append('[%s]="%s",' % (qid, text.replace("\\", "\\\\").replace('"', '\\"')))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    head = [
        "-- Generated by tools/build_quest_scores.py from pfQuest (MIT licence, Copyright (c) 2017-2021",
        "-- Eric Mauser (Shagu); data/quests/pfquest/LICENSE). Don't edit: rebuild with that tool.",
        "-- Quests new to Forever, and Forever's own chain links, from EG Link output: World of Warcraft:",
        "-- Forever (data from Efficient Games, https://efficient.games, CC BY 4.0); their drop chances from",
        "-- Wowhead Forever. Each quest: \"k,n;Item=chance;...\", its place in its chain (empty when it",
        "-- stands alone) and the best drop chance, in percent, of each item it asks for (\"w\": Wowhead's",
        "-- from creatures, \"o\": Wowhead's from objects opened, \"p\": EG Link's pooled with jsal.ui's Drop log, \"j\": the Drop log's),",
        "-- then \":ID\", the item's ID, so another language's client finds it by its own name. Then \"#xp@level\": the full XP it pays and",
        "-- its level, from the game's QuestXP table (data/quests/QuestXP.csv) and EG Link's reward tiers.",
        "-- Before it: \"|i10=Item\" or \"|k6=Creature\" for each objective, for a quest not taken yet (EG Link).",
        "local _, ns = ...",
        "ns.QuestScoreData = {",
    ]
    OUT.write_bytes(("\r\n".join(head + lines + ["}", ""])).encode("utf-8"))
    print(f"wrote {len(lines)} quests ({sum(1 for q in place)} in chains) to {OUT.relative_to(ROOT)}, "
          f"{OUT.stat().st_size // 1024} KB; {unnumbered} drop chances with no item ID")


if __name__ == "__main__":
    if len(sys.argv) > 2 and sys.argv[1] == "--from":
        fetch(sys.argv[2])
    if len(sys.argv) > 2 and sys.argv[1] == "--eglink":
        fetch_eglink(sys.argv[2])
    if len(sys.argv) > 2 and sys.argv[1] == "--egloot":
        fetch_egloot(sys.argv[2])
    build()
