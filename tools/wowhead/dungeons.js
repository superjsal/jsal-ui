// Reads Wowhead Forever's dungeon pages for data/dungeons/wowhead.json. Run in the browser pane on
// a www.wowhead.com/forever page, after the window.__bosses line that tools/wowhead/bosses.py
// prints. For each zone: its page (quests, NPCs, and the Drops tab naming bosses), then each
// boss's NPC page (drops with Wowhead's kill counts). One page every 8 seconds, kept in
// localStorage ("jsalDungeons"), so a Human Verification stop can be cleared and the script run
// again to carry on. When done, it sends the result to tools/wowhead/receive.py (start it first,
// writing to a new file), and tools/wowhead/merge_dungeons.py folds that into wowhead.json.
// To start afresh next month: localStorage.removeItem('jsalDungeons').
const grab = (t, id) => {
  const i = t.indexOf("id: '" + id + "'");
  if (i < 0) return null;
  const next = t.indexOf('new Listview(', i + 5);
  const m = /data:\s*\[/g; m.lastIndex = i;
  const r = m.exec(t);
  if (!r || (next > 0 && next < r.index)) return null;
  const s = r.index + r[0].length - 1;
  let d = 0;
  for (let p = s; p < t.length; p++) {
    const c = t[p];
    if (c === '[') d++;
    else if (c === ']') { d--; if (d === 0) { try { return JSON.parse(t.slice(s, p + 1)); } catch (e) { return null; } } }
  }
  return null;
};
const norm = s => s.toLowerCase().replace(/[^a-z0-9]/g, '');
const wait = ms => new Promise(r => setTimeout(r, ms));
async function page(url) {
  const r = await fetch(url);
  const t = await r.text();
  if (r.status !== 200 || t.includes('<title>Human Verification')) throw new Error('blocked at ' + url);
  return t;
}
const FETCHED = new Date().toISOString().slice(0, 10);
window.__dungeons = { done: false, log: [], err: null, unmatched: [] };
(async () => {
  let store;
  try { store = JSON.parse(localStorage.getItem('jsalDungeons') || '{}'); } catch (e) { store = {}; }
  const save = () => localStorage.setItem('jsalDungeons', JSON.stringify(store));
  try {
    for (const [z, bosses] of Object.entries(window.__bosses)) {
      if (store[z] && store[z].done) continue;
      const Z = store[z] || { loot: {}, quests: [], done: false };
      store[z] = Z;
      const t = await page('/forever/zone=' + z);
      await wait(8000);
      const npcs = grab(t, 'npcs') || [];
      Z.quests = (grab(t, 'quests') || []).map(q => [q.id, q.name, q.level, q.reqlevel, q.side, q.reqclass || 0]);
      // Items the zone's own Drops tab says a boss drops, kept even without kill counts.
      const named = {};
      for (const d of grab(t, 'drops') || []) {
        if ((d.quality || 0) < 2) continue;
        for (const s of d.sourcemore || []) if (s.t === 1 && s.n) (named[norm(s.n)] = named[norm(s.n)] || new Set()).add(d.id);
      }
      for (const [boss, names] of Object.entries(bosses)) {
        if (Z.loot[boss]) continue;
        const want = names.map(norm);
        const hits = npcs.filter(n => want.includes(norm(n.name)));
        if (!hits.length) { __dungeons.unmatched.push(z + ': ' + boss); continue; }
        const items = {};
        for (const h of hits) {
          const u = await page('/forever/npc=' + h.id);
          await wait(8000);
          for (const d of grab(u, 'drops') || []) {
            if ((d.quality || 0) < 2) continue;
            const o = items[d.id] || [0, 0];
            o[0] += d.count || 0; o[1] += d.outof || 0;
            items[d.id] = o;
          }
        }
        // Kept: dropped in at least 2% of 10 or more kills, or named on the zone's Drops tab.
        const zoneNamed = new Set(want.flatMap(w => [...(named[w] || [])]));
        const out = [];
        for (const [id, [count, outof]] of Object.entries(items)) {
          const pct = outof >= 10 ? Math.round(count / outof * 100) : null;
          if ((pct !== null && pct >= 2) || zoneNamed.has(+id)) out.push([+id, pct]);
        }
        Z.loot[boss] = out;
        save();
      }
      Z.done = true;
      save();
      __dungeons.log.push(z);
    }
  } catch (e) { __dungeons.err = String(e); }
  __dungeons.done = true;
  if (__dungeons.err) return;
  const zones = {};
  for (const [z, v] of Object.entries(store)) zones[z] = { loot: v.loot, quests: v.quests };
  location.href = 'http://127.0.0.1:8799/#' + encodeURIComponent(JSON.stringify({ fetched: FETCHED, zones }));
})();
'started: ' + Object.keys(window.__bosses).length + ' zones; watch window.__dungeons'
