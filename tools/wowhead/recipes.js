// Reads where Wowhead Forever says each recipe comes from, for data/professions/wowhead-sources.json.
// Run it in the browser pane on a www.wowhead.com/forever page (javascript_tool). First the eight
// recipe lists (each item's quest, single vendor or single mob). Then the vendors: every vendor a
// list names is read (its page has its side, zone, map spot and everything it sells, with prices);
// a vendor recipe no vendor read so far sells has its own page read for its "Sold by" list, and
// those vendors are read in turn. One page every 15 seconds, kept in localStorage ("jsalRecipes"),
// so after a Human Verification stop (John clears it in the pane) running it again carries on.
// When all is in, it sends the result to tools/wowhead/receive.py (start that first). To start
// afresh: localStorage.removeItem('jsalRecipes').
const PROFS = ['alchemy', 'blacksmithing', 'cooking', 'enchanting', 'engineering', 'first-aid', 'leatherworking',
  'tailoring'];
const FETCHED = new Date().toISOString().slice(0, 10);
window.__recipes = { done: false, pages: 0, left: 0, last: '', err: null };
(async () => {
  let store;
  try { store = JSON.parse(localStorage.getItem('jsalRecipes') || '{}'); } catch (e) { store = {}; }
  store.lists = store.lists || {}; store.npcs = store.npcs || {}; store.items = store.items || {};
  const save = () => localStorage.setItem('jsalRecipes', JSON.stringify(store));
  const page = async (u) => {
    const r = await fetch(u);
    const t = await r.text();
    if (r.status !== 200 || t.includes('<title>Human Verification')) throw new Error('blocked at ' + u);
    __recipes.pages++; __recipes.last = u;
    await new Promise(r => setTimeout(r, 15000));
    return t;
  };
  // The JSON array after "data:" in the list with this id, read by matching brackets.
  const listData = (t, id) => {
    const at = t.indexOf("id: '" + id + "'");
    if (at < 0) return [];
    const start = t.indexOf('data:', at);
    const open = t.indexOf('[', start);
    if (start < 0 || open < 0 || open - start > 12) return [];
    let depth = 0, inString = false;
    for (let i = open; i < t.length; i++) {
      const ch = t[i];
      if (inString) { if (ch === '\\') i++; else if (ch === '"') inString = false; continue; }
      if (ch === '"') inString = true;
      else if (ch === '[') depth++;
      else if (ch === ']' && --depth === 0) return JSON.parse(t.slice(open, i + 1));
    }
    return [];
  };
  try {
    for (const p of PROFS) {
      if (store.lists[p]) continue;
      const t = await page('/forever/items/recipes/' + p);
      const m = t.match(/var listviewitems = (\[[\s\S]*?\]);\n/);
      const arr = m ? JSON.parse(m[1].replace(/([{,])\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*:/g, '$1"$2":')) : [];
      store.lists[p] = arr.map(o => [o.id, o.name, o.skill || 0, o.source || [],
        (o.sourcemore || []).map(s => [s.n || '', s.t || 0, s.ti || 0, s.z || 0, s.c || 0])]);
      save();
    }
    const vendorItems = [];
    const wanted = new Set();
    for (const p of PROFS) for (const it of store.lists[p]) {
      if (!it[3].includes(5)) continue;
      vendorItems.push(it[0]);
      for (const s of it[4]) if (s[1] === 1 && s[2]) wanted.add(s[2]);
    }
    for (const list of Object.values(store.items)) for (const id of list) wanted.add(id);
    const readNpc = async (id) => {
      const t = await page('/forever/npc=' + id);
      const g = t.match(new RegExp('g_npcs\\[' + id + '\\], (\\{.*?\\})\\);'));
      const info = g ? JSON.parse(g[1]) : {};
      const mp = t.match(/var g_mapperData = (\{.*?\});\n/);
      let spot = [];
      if (mp) {
        const zones = JSON.parse(mp[1]);
        const zone = Object.keys(zones)[0];
        const first = zone && zones[zone][0];
        if (first && first.coords && first.coords[0]) spot = [first.uiMapId || 0, first.coords[0][0], first.coords[0][1]];
      }
      const sells = {};
      for (const o of listData(t, 'sells')) {
        if (o.classs !== 9) continue;
        const cost = o.cost && o.cost[0];
        sells[o.id] = [cost ? cost[0] || 0 : 0, o.avail === undefined ? -1 : o.avail,
          cost && ((cost[1] && cost[1].length) || (cost[2] && cost[2].length)) ? 1 : 0, o.standing || 0];
      }
      store.npcs[id] = { n: info.name || '', react: info.react || [], loc: info.location || [], spot, sells };
      save();
    };
    for (;;) {
      const next = [...wanted].find(id => !store.npcs[id]);
      if (next) { await readNpc(next); continue; }
      const sold = new Set();
      for (const npc of Object.values(store.npcs)) for (const id of Object.keys(npc.sells)) sold.add(+id);
      const open = vendorItems.filter(id => !sold.has(id) && !store.items[id]);
      __recipes.left = open.length;
      if (!open.length) break;
      const t = await page('/forever/item=' + open[0]);
      const ids = listData(t, 'sold-by').map(o => o.id).filter(Boolean);
      store.items[open[0]] = ids;
      save();
      for (const id of ids) wanted.add(id);
    }
  } catch (e) { __recipes.err = String(e.message || e); __recipes.done = true; return; }
  __recipes.done = true;
  const out = JSON.stringify({ fetched: FETCHED,
    fields: { lists: 'item, name, skill, source, sourcemore[name,type,id,zone,category]',
      npcs: 'n name, react [alliance, horde], loc zones, spot [uiMap, x, y], sells item: [copper, stock, other cost, standing]',
      items: 'vendor recipe: the vendors on its own page' },
    lists: store.lists, npcs: store.npcs, items: store.items });
  location.href = 'http://127.0.0.1:8799/#' + encodeURIComponent(out);
})();
'started; watch window.__recipes'
