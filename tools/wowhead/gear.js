// Reads Wowhead Forever's gear lists for data/gear/wowhead-items.json. Run it in the browser pane
// on a www.wowhead.com/forever page (javascript_tool). It reads one list every 12 seconds and keeps
// what it has read in localStorage ("jsalGear"), so after a Human Verification stop (John clears
// it in the pane) running it again carries on where it stopped. When every list is in, it sends
// the result to tools/wowhead/receive.py (start that first). To start afresh next month:
// localStorage.removeItem('jsalGear').
// Each item also keeps the percent crit and hit an "Equip:" line gives it ("Improves your chance
// to get a critical strike by 1%"): the game's item stats leave those out, and Wowhead's own item
// data on the page names them apart from rating (mlecritstrkpct, splhitpct...).
// And which rings and trinkets can be worn only once (Unique, or Unique-Equipped): Wowhead's
// item data doesn't say, but its lists filter on it, four short pages more.
const Q = '/quality:2:3:4';
const urls = [];
for (const a of ['cloth', 'leather', 'mail', 'plate'])
  // Robes come with the chest lists (slot 5), so there's no slot 20 list to read.
  for (const s of [1, 3, 5, 6, 7, 8, 9, 10]) urls.push(`/forever/items/armor/${a}/slot:${s}${Q}`);
for (const slug of ['amulets', 'rings', 'trinkets', 'cloaks', 'off-hand-frills', 'shields'])
  urls.push(`/forever/items/armor/${slug}${Q}`);
for (const w of ['one-handed-axes', 'two-handed-axes', 'bows', 'guns', 'one-handed-maces', 'two-handed-maces',
  'polearms', 'one-handed-swords', 'two-handed-swords', 'staves', 'fist-weapons', 'daggers', 'thrown',
  'crossbows', 'wands'])
  urls.push(`/forever/items/weapons/${w}${Q}`);
const UNIQUE = [];
for (const slug of ['rings', 'trinkets'])
  for (const cr of [15, 83]) UNIQUE.push(`/forever/items/armor/${slug}${Q}?filter=${cr};1;0`);
const FETCHED = new Date().toISOString().slice(0, 10);
window.__gear = { done: false, log: [], err: null };
(async () => {
  let store;
  try { store = JSON.parse(localStorage.getItem('jsalGear') || '{}'); } catch (e) { store = {}; }
  for (const u of [...urls, ...UNIQUE]) {
    if (store[u]) { __gear.log.push(u + ' (saved)'); continue; }
    try {
      const r = await fetch(u);
      const t = await r.text();
      if (r.status !== 200 || t.includes('<title>Human Verification')) { __gear.err = 'blocked at ' + u; break; }
      const m = t.match(/var listviewitems = (\[[\s\S]*?\]);\n/);
      const arr = m ? JSON.parse(m[1].replace(/([{,])\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*:/g, '$1"$2":')) : [];
      const pct = {};
      const re = /"(\d+)":\{"name_enus":"(?:[^"\\]|\\.)*"/g;
      let g;
      while ((g = re.exec(t))) {
        const j = t.indexOf('"jsonequip":{', g.index);
        if (j < 0 || j - g.index > 400) continue;
        const e = t.slice(j + 13, t.indexOf('}', j + 13));
        const found = e.match(/"(?:mle|rgd|spl)?(?:critstrk|hit)pct":[\d.]+/g);
        if (found) pct[g[1]] = Object.fromEntries(found.map(f => { const [k, v] = f.split(':'); return [k.slice(1, -1), +v]; }));
      }
      if (UNIQUE.includes(u)) store[u] = arr.map(o => o.id);
      else store[u] = arr.map(o => [o.id, o.name, o.quality, o.reqlevel || 0, o.level || 0, o.slot, o.classs, o.subclass,
        o.side || 0, o.reqclass || 0, o.source || [],
        (o.sourcemore || []).map(s => [s.n || '', s.t || 0, s.ti || 0, s.z || 0, s.c || 0]), pct[o.id] || 0]);
      localStorage.setItem('jsalGear', JSON.stringify(store));
      __gear.log.push(u + ' ' + arr.length);
    } catch (e) { __gear.err = u + ': ' + e; break; }
    await new Promise(r => setTimeout(r, 12000));
  }
  __gear.done = true;
  if (__gear.err) return;
  const by = new Map();
  const unique = new Set(UNIQUE.flatMap(u => store[u] || []));
  for (const u of urls) for (const i of store[u] || []) if (!by.has(i[0])) by.set(i[0], i);
  const items = [...by.values()].map(i => [...i.slice(0, 11), (i[11] || []).slice(0, 3), i[12] || 0, unique.has(i[0]) ? 1 : 0]);
  const out = JSON.stringify({ fetched: FETCHED,
    fields: ['id', 'name', 'quality', 'reqlevel', 'itemlevel', 'slot', 'class', 'subclass', 'side', 'reqclass',
      'source', 'sourcemore[name,type,id,zone,c]', 'pct', 'unique'], items });
  location.href = 'http://127.0.0.1:8799/#' + encodeURIComponent(out);
})();
'started: ' + (urls.length + UNIQUE.length) + ' lists; watch window.__gear'
