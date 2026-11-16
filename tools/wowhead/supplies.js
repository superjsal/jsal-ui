// Reads who sells each vendor reagent, from Wowhead Forever, for data/vendors/wowhead-supplies.json:
// EG Link only has the vendors its players opened (two in Ironforge), so the shopping list could send
// someone to another city for thread. Run it in the browser pane on a www.wowhead.com/forever page
// (javascript_tool), after the window.__supplies line tools/wowhead/supplies.py prints. First each
// reagent's page, for its "Sold by" list (each seller's name, side, zones and price); then the page
// of each seller whose spot isn't known already, for where they stand. One page every 15 seconds,
// kept in localStorage ("jsalSupplies"), so after a Human Verification stop (John clears it in the
// pane) running it again carries on. When all is in, it sends the result to tools/wowhead/receive.py
// (start that first). To start afresh: localStorage.removeItem('jsalSupplies').
const FETCHED = new Date().toISOString().slice(0, 10);
window.__supply = { done: false, pages: 0, left: 0, last: '', err: null };
(async () => {
  const ask = window.__supplies;
  if (!ask) { __supply.err = 'run the window.__supplies line first'; return; }
  let store;
  try { store = JSON.parse(localStorage.getItem('jsalSupplies') || '{}'); } catch (e) { store = {}; }
  store.items = store.items || {}; store.npcs = store.npcs || {};
  const save = () => localStorage.setItem('jsalSupplies', JSON.stringify(store));
  const page = async (u) => {
    const r = await fetch(u);
    const t = await r.text();
    if (r.status !== 200 || t.includes('<title>Human Verification')) throw new Error('blocked at ' + u);
    __supply.pages++; __supply.last = u;
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
  const known = new Set(ask.known);
  try {
    for (const item of ask.items) {
      if (store.items[item]) continue;
      __supply.left = ask.items.filter(i => !store.items[i]).length;
      const t = await page('/forever/item=' + item);
      // Each seller: [npc, name, react [alliance, horde], zones, copper].
      store.items[item] = listData(t, 'sold-by').filter(o => o.id).map(o => [o.id, o.name || '', o.react || [],
        o.location || [], (o.cost && o.cost[0] && o.cost[0][0]) || 0]);
      save();
    }
    // Sellers of trade supplies first (thread, dye, salt, vials, flux), and those who sell the most
    // of them; those with only water, milk or wood (innkeepers and general goods, of which EG Link
    // has many) last, so a stop part-way has the useful ones.
    const COMMON = new Set([159, 1179, 4470]);
    const weight = {};
    for (const [item, list] of Object.entries(store.items)) for (const s of list) {
      if (known.has(s[0])) continue;
      weight[s[0]] = (weight[s[0]] || 0) + (COMMON.has(+item) ? 0.001 : 1);
    }
    const wanted = new Set(Object.keys(weight).map(Number).sort((a, b) => weight[b] - weight[a]));
    __supply.wanted = wanted.size;
    __supply.supplies = Object.values(weight).filter(w => w >= 1).length;
    for (const id of wanted) {
      if (store.npcs[id]) continue;
      // window.__supplyStop = true sends what's read so far (the build skips sellers with no spot).
      if (window.__supplyStop) break;
      __supply.left = [...wanted].filter(n => !store.npcs[n]).length;
      const t = await page('/forever/npc=' + id);
      const mp = t.match(/var g_mapperData = (\{.*?\});\n/);
      let spot = [];
      if (mp) {
        const zones = JSON.parse(mp[1]);
        const zone = Object.keys(zones)[0];
        const first = zone && zones[zone][0];
        if (first && first.coords && first.coords[0]) spot = [first.uiMapId || 0, first.coords[0][0], first.coords[0][1]];
      }
      store.npcs[id] = { spot };
      save();
    }
  } catch (e) { __supply.err = String(e.message || e); __supply.done = true; return; }
  __supply.done = true; __supply.left = 0;
  const out = JSON.stringify({ fetched: FETCHED,
    fields: { items: 'vendor reagent: its sellers on its page, [npc, name, react [alliance, horde], zones, copper]',
      npcs: 'a seller whose spot EG Link and the recipe read lacked: spot [uiMap, x, y] on Classic\'s map, [] for none' },
    items: store.items, npcs: store.npcs });
  location.href = 'http://127.0.0.1:8799/#' + encodeURIComponent(out);
})();
'started; watch window.__supply'
