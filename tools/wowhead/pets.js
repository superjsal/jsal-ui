// Reads Wowhead Forever's pet ability pages for data/pets/wowhead.json: which beasts carry each
// rank of each pet ability, and which beasts a hunter can tame. Run in the browser pane on a
// www.wowhead.com/forever page, after the window.__petSpells line that tools/wowhead/petspells.py
// prints. First each ability rank's page (its "Used by NPC" list), then each pet family those
// beasts belong to (its "Tameable" list). One page every 8 seconds, kept in localStorage
// ("jsalPets"), so a Human Verification stop can be cleared and the script run again to carry
// on. When done, it sends the result to tools/wowhead/receive.py (start it first). To start
// afresh: localStorage.removeItem('jsalPets').
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
    else if (c === ']') {
      d--;
      if (d === 0) {
        const raw = t.slice(s, p + 1);
        try { return JSON.parse(raw); } catch (e) {
          // Some lists carry a bare key (skin: "") among the quoted ones.
          try { return JSON.parse(raw.replace(/([{,])\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*:/g, '$1"$2":')); } catch (e2) { return null; }
        }
      }
    }
  }
  return null;
};
const wait = ms => new Promise(r => setTimeout(r, ms));
async function page(url) {
  const r = await fetch(url);
  const t = await r.text();
  if (r.status !== 200 || t.includes('<title>Human Verification')) throw new Error('blocked at ' + url);
  return t;
}
const FETCHED = new Date().toISOString().slice(0, 10);
window.__pets = { done: false, log: [], err: null, empty: [] };
(async () => {
  let store;
  try { store = JSON.parse(localStorage.getItem('jsalPets') || '{}'); } catch (e) { store = {}; }
  store.spells = store.spells || {};
  store.families = store.families || {};
  store.npcs = store.npcs || {};
  const save = () => localStorage.setItem('jsalPets', JSON.stringify(store));
  const keep = n => { store.npcs[n.id] = [n.name, n.minlevel || 0, n.maxlevel || 0, n.family || 0, n.classification || 0, (n.location || [])[0] || 0]; };
  try {
    for (const spell of window.__petSpells) {
      if (store.spells[spell]) continue;
      const list = grab(await page('/forever/spell=' + spell), 'used-by-npc');
      if (!list) __pets.empty.push(spell);
      (list || []).forEach(keep);
      store.spells[spell] = (list || []).map(n => n.id);
      save();
      __pets.log.push('spell ' + spell + ' ' + (list || []).length);
      await wait(8000);
    }
    const families = [...new Set(Object.values(store.npcs).map(n => n[3]).filter(f => f > 0))].sort((a, b) => a - b);
    for (const family of families) {
      if (store.families[family]) continue;
      const t = await page('/forever/pet=' + family);
      const list = grab(t, 'tameable');
      (list || []).forEach(keep);
      store.families[family] = { name: ((t.match(/<title>(.*?) - Hunter Pet/) || [])[1] || ''), tameable: (list || []).map(n => n.id) };
      save();
      __pets.log.push('family ' + family + ' ' + (list || []).length);
      await wait(8000);
    }
  } catch (e) { __pets.err = String(e.message || e); __pets.done = true; return; }
  __pets.done = true;
  const out = JSON.stringify({ fetched: FETCHED, npcFields: ['name', 'minlevel', 'maxlevel', 'family', 'classification', 'zone'],
    spells: store.spells, families: store.families, npcs: store.npcs });
  location.href = 'http://127.0.0.1:8799/#' + encodeURIComponent(out);
})();
'started: ' + window.__petSpells.length + ' ability ranks; watch window.__pets'
