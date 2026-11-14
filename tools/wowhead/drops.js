// Reads how often each quest item drops on Forever, from Wowhead Forever's item pages, for
// data/quests/wowhead-drops.json (the quest tags' drop chances). Run in the browser pane on a
// www.wowhead.com/forever page, after the window.__dropIds line tools/wowhead/drop_items.py prints.
// For each item: its name, and every creature Wowhead lists under "Dropped by" (and every object
// under "Contained in") with how many times it dropped and in how many kills or openings.
// One page every 10 seconds; on a Wowhead check the batch stops and sends what it read to
// tools/wowhead/receive.py (start it first, writing to a scratch file), and
// tools/wowhead/merge_quests.py --drops folds it in. Then run tools/build_quest_scores.py.
const wait = ms => new Promise(r => setTimeout(r, ms));
// The page's text, or null when Wowhead has no such item (404); a check stops the batch.
async function page(url) {
  const r = await fetch(url);
  const t = await r.text();
  if (t.includes('<title>Human Verification')) throw new Error('blocked at ' + url);
  if (r.status === 404) return null;
  if (r.status !== 200) throw new Error('blocked at ' + url);
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
// { name, npcs: [[name, dropped, kills], ...], objects: [[name, found, opened], ...] }
function readItem(t) {
  const title = (/<title>(.*?) - Item - WoW Forever/.exec(t) || [])[1] || null;
  const rows = list => (list || []).filter(o => o.name && o.count > 0 && o.outof > 0)
    .map(o => [o.name, o.count, o.outof]);
  return { name: title && title.replace(/&#039;/g, "'").replace(/&quot;/g, '"').replace(/&amp;/g, '&'),
           npcs: rows(grab(t, 'dropped-by')), objects: rows(grab(t, 'contained-in-object')) };
}
const FETCHED = new Date().toISOString().slice(0, 10);
window.__drops = { done: false, read: 0, left: 0, err: null };
(async () => {
  const store = {};
  const todo = [...window.__dropIds];
  try {
    while (todo.length) {
      const id = todo.shift();
      __drops.left = todo.length;
      const t = await page('/forever/item=' + id);
      store[id] = t === null ? { missing: true } : readItem(t);
      __drops.read++;
      await wait(10000);
    }
  } catch (e) { __drops.err = e.message; }
  __drops.done = true;
  const out = { fetched: FETCHED, items: store };
  if (__drops.err) out.stopped = __drops.err;
  location.href = 'http://127.0.0.1:8799/#' + encodeURIComponent(JSON.stringify(out));
})();
'started: ' + window.__dropIds.length + ' items; watch window.__drops'
