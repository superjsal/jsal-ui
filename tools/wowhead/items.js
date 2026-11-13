// Reads who drops each item that starts a dungeon quest, from Wowhead Forever's item pages, for
// data/dungeons/quest-items.json. Run in the browser pane on a www.wowhead.com/forever page, after
// the window.__itemIds line that tools/wowhead/quest_items.py prints. For each item: the NPC that
// drops it most often (Wowhead's "Dropped by" tab) and its zone, or else the object it's found in.
// One page every 10 seconds; on a Wowhead check the batch stops and sends what it read to
// tools/wowhead/receive.py (start it first, writing to a scratch file), and
// tools/wowhead/merge_quests.py --items folds it in. Then run build_dungeons.py again.
const wait = ms => new Promise(r => setTimeout(r, ms));
async function page(url) {
  const r = await fetch(url);
  const t = await r.text();
  if (r.status !== 200 || t.includes('<title>Human Verification')) throw new Error('blocked at ' + url);
  return t;
}
const grab = (t, id) => {
  const i = t.indexOf("id: '" + id + "'");
  if (i < 0) return null;
  const m = /data:\s*\[/g; m.lastIndex = i;
  const r = m.exec(t);
  if (!r) return null;
  const s = r.index + r[0].length - 1;
  let d = 0;
  for (let p = s; p < t.length; p++) {
    const c = t[p];
    if (c === '[') d++;
    else if (c === ']') { d--; if (d === 0) { try { return JSON.parse(t.slice(s, p + 1)); } catch (e) { return null; } } }
  }
  return null;
};
// [who, area, 1 dropped by an NPC or 2 found in an object], or null when Wowhead lists neither.
function readItem(t) {
  const best = list => (list || []).filter(o => o.name).sort((a, b) => (b.count || 0) - (a.count || 0))[0];
  const npc = best(grab(t, 'dropped-by'));
  if (npc) return [npc.name, (npc.location || [])[0] || 0, 1];
  const obj = best(grab(t, 'contained-in-object'));
  if (obj) return [obj.name, (obj.location || [])[0] || 0, 2];
  return null;
}
const FETCHED = new Date().toISOString().slice(0, 10);
window.__items = { done: false, read: 0, left: 0, err: null };
(async () => {
  const store = {};
  const todo = [...window.__itemIds];
  try {
    while (todo.length) {
      const id = todo.shift();
      __items.left = todo.length;
      store[id] = readItem(await page('/forever/item=' + id));
      __items.read++;
      await wait(10000);
    }
  } catch (e) { __items.err = e.message; }
  __items.done = true;
  const out = { fetched: FETCHED, items: store };
  if (__items.err) out.stopped = __items.err;
  location.href = 'http://127.0.0.1:8799/#' + encodeURIComponent(JSON.stringify(out));
})();
'started: ' + window.__itemIds.length + ' items; watch window.__items'
