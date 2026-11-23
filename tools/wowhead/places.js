// Reads where each placeless drop drops, from Wowhead Forever's item pages, for
// data/gear/wowhead-places.json (the dungeons the Dungeon guide's Trash card lists an item under).
// Run in the browser on a www.wowhead.com/forever page, after the window.__placeIds line
// tools/wowhead/place_items.py prints. For each item: its name, and every creature Wowhead lists
// under "Dropped by" with its NPC ID, the zones it's found in, its classification, and how many
// times it dropped the item in how many kills, as the page gives them.
// One page every 10 seconds; when the site asks for a confirmation the batch stops and sends what it read to
// tools/wowhead/receive.py (start it first, writing to a scratch file), and
// tools/wowhead/merge_places.py folds it in. Then run tools/build_gear.py.
const wait = ms => new Promise(r => setTimeout(r, ms));
// The page's text, or null when Wowhead has no such item (404); a confirmation page stops the batch.
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
// { name, npcs: [{ name, id, zones, classification, count, outof }, ...] }, or { name, none: true }
// when the page lists no creature.
function readItem(t) {
  const title = (/<title>(.*?) - Item - WoW Forever/.exec(t) || [])[1] || null;
  const name = title && title.replace(/&#039;/g, "'").replace(/&quot;/g, '"').replace(/&amp;/g, '&');
  const npcs = (grab(t, 'dropped-by') || []).filter(o => o.name && o.id).map(o => ({
    name: o.name, id: o.id, zones: o.location || [], classification: o.classification || 0,
    count: o.count === undefined ? null : o.count, outof: o.outof === undefined ? null : o.outof }));
  return npcs.length ? { name, npcs } : { name, none: true };
}
const FETCHED = new Date().toLocaleDateString('en-CA');  // the local date, as 2026-11-22
window.__places = { done: false, read: 0, left: 0, err: null };
(async () => {
  // Pages read are held in the page as they come, so a reload loses only the page in progress;
  // the next batch picks them up, and the hold is emptied once a batch has gone to the receiver.
  const store = JSON.parse(localStorage.getItem('jsalPlacesHeld') || '{}');
  const todo = window.__placeIds.filter(id => !(String(id) in store));
  try {
    while (todo.length) {
      const id = todo.shift();
      __places.left = todo.length;
      const t = await page('/forever/item=' + id);
      store[id] = t === null ? { missing: true } : readItem(t);
      localStorage.setItem('jsalPlacesHeld', JSON.stringify(store));
      __places.read++;
      if (todo.length) await wait(10000);
    }
  } catch (e) { __places.err = e.message; }
  __places.done = true;
  const out = { fetched: FETCHED, items: store };
  if (__places.err) out.stopped = __places.err;
  localStorage.removeItem('jsalPlacesHeld');
  location.href = 'http://127.0.0.1:8799/#' + encodeURIComponent(JSON.stringify(out));
})();
'started: ' + window.__placeIds.length + ' items; watch window.__places'
