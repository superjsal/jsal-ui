// Reads Wowhead Forever's dungeon pages for data/dungeons/wowhead.json. Run in the browser on
// a www.wowhead.com/forever page, after the window.__bosses line that tools/wowhead/bosses.py
// prints. For each zone: its page (quests, NPCs, and the Drops tab naming bosses), then each
// boss's NPC page (drops with Wowhead's kill counts; a number among a boss's names is an NPC's
// ID, for a boss the zone's page doesn't list). One page every 8 seconds, kept in
// localStorage ("jsalDungeons"), so if the site stops it to ask for a confirmation, the
// script run again carries on. When done, it sends the result to tools/wowhead/receive.py (start it first,
// writing to a new file), and tools/wowhead/merge_dungeons.py folds that into wowhead.json.
// To start afresh next month: localStorage.removeItem('jsalDungeons').
//
// It keeps every uncommon-or-better drop each NPC page lists, with Wowhead's counts as they are
// (count -1 where Wowhead lists a drop it hasn't counted), and the items the zone's Drops tab
// names the boss for. Which of them a boss's card shows is merge_dungeons.py's rule, so the rule
// can change without reading the pages again.
//
// Wowhead writes a page's lists two ways, "id: 'drops', ... data: [...]" and, on newer pages,
// '"id":"npcs", ... "data":[...]': both are read.
const grab = (t, id) => {
  let i = t.indexOf("id: '" + id + "'");
  if (i < 0) i = t.indexOf('"id":"' + id + '"');
  if (i < 0) return null;
  const from = t.lastIndexOf('new Listview(', i);
  const next = t.indexOf('new Listview(', i + 5);
  const m = /"?data"?\s*:\s*\[/g; m.lastIndex = from >= 0 ? from : i;
  const r = m.exec(t);
  if (!r || (next > 0 && next < r.index)) return null;
  const s = r.index + r[0].length - 1;
  let d = 0, quoted = false;
  for (let p = s; p < t.length; p++) {
    const c = t[p];
    if (quoted) { if (c === '\\') p++; else if (c === '"') quoted = false; continue; }
    if (c === '"') quoted = true;
    else if (c === '[') d++;
    else if (c === ']') { d--; if (d === 0) { try { return JSON.parse(t.slice(s, p + 1)); } catch (e) { return null; } } }
  }
  return null;
};
const norm = s => s.toLowerCase().replace(/[^a-z0-9]/g, '');
// The pause is timed in a worker: a tab's own timers slow to one a minute while it's in the
// background, a worker's don't.
const timer = new Worker(URL.createObjectURL(new Blob(['onmessage = e => setTimeout(() => postMessage(0), e.data)'])));
const wait = ms => new Promise(r => { timer.onmessage = r; timer.postMessage(ms); });
async function page(url) {
  const r = await fetch(url);
  const t = await r.text();
  if (r.status !== 200 || t.includes('<title>Human Verification')) throw new Error('blocked at ' + url);
  return t;
}
const FETCHED = new Date().toISOString().slice(0, 10);
window.__dungeons = { done: false, log: [], err: null, unmatched: [], pages: 0 };
(async () => {
  let store;
  try { store = JSON.parse(localStorage.getItem('jsalDungeons') || '{}'); } catch (e) { store = {}; }
  const save = () => localStorage.setItem('jsalDungeons', JSON.stringify(store));
  try {
    for (const [z, bosses] of Object.entries(window.__bosses)) {
      if (store[z] && store[z].done) continue;
      const Z = store[z] || { drops: {}, named: {}, unmatched: [], quests: [], done: false };
      store[z] = Z;
      const t = await page('/forever/zone=' + z);
      __dungeons.pages++;
      await wait(8000);
      const npcs = grab(t, 'npcs') || [];
      Z.quests = (grab(t, 'quests') || []).map(q => [q.id, q.name, q.level, q.reqlevel, q.side, q.reqclass || 0]);
      // Items the zone's own Drops tab says a boss drops.
      const named = {};
      for (const d of grab(t, 'drops') || []) {
        if ((d.quality || 0) < 2) continue;
        for (const s of d.sourcemore || []) if (s.t === 1 && s.n) (named[norm(s.n)] = named[norm(s.n)] || new Set()).add(d.id);
      }
      Z.unmatched = [];
      for (const [boss, names] of Object.entries(bosses)) {
        if (Z.drops[boss]) continue;
        const want = names.filter(n => typeof n === 'string').map(norm);
        const ids = names.filter(n => typeof n === 'number');
        const hits = ids.map(id => ({ id })).concat(npcs.filter(n => want.includes(norm(n.name)) && !ids.includes(n.id)));
        if (!hits.length) { Z.unmatched.push(boss); __dungeons.unmatched.push(z + ': ' + boss); continue; }
        // Each NPC page's drops: [item, quality, count, kills], as Wowhead has them.
        const read = [];
        for (const h of hits) {
          const u = await page('/forever/npc=' + h.id);
          __dungeons.pages++;
          await wait(8000);
          read.push([h.id, (grab(u, 'drops') || []).filter(d => (d.quality || 0) >= 2)
            .map(d => [d.id, d.quality, d.count == null ? -1 : d.count, d.outof || 0])]);
        }
        Z.drops[boss] = read;
        Z.named[boss] = [...new Set(want.flatMap(w => [...(named[w] || [])]))];
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
  for (const [z, v] of Object.entries(store)) zones[z] = { drops: v.drops, named: v.named, unmatched: v.unmatched, quests: v.quests };
  location.href = 'http://127.0.0.1:8799/#' + encodeURIComponent(JSON.stringify({ fetched: FETCHED, zones }));
})();
'started: ' + Object.keys(window.__bosses).length + ' zones; watch window.__dungeons'
