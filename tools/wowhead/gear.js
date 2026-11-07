// Reads Wowhead Forever's gear lists for data/gear/wowhead-items.json. Run it in the browser pane
// on a www.wowhead.com/forever page (javascript_tool). It reads one list every 12 seconds and keeps
// what it has read in localStorage ("jsalGear"), so after a Human Verification stop (John clears
// it in the pane) running it again carries on where it stopped. When every list is in, it sends
// the result to tools/wowhead/receive.py (start that first). To start afresh next month:
// localStorage.removeItem('jsalGear').
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
const FETCHED = new Date().toISOString().slice(0, 10);
window.__gear = { done: false, log: [], err: null };
(async () => {
  let store;
  try { store = JSON.parse(localStorage.getItem('jsalGear') || '{}'); } catch (e) { store = {}; }
  for (const u of urls) {
    if (store[u]) { __gear.log.push(u + ' (saved)'); continue; }
    try {
      const r = await fetch(u);
      const t = await r.text();
      if (r.status !== 200 || t.includes('<title>Human Verification')) { __gear.err = 'blocked at ' + u; break; }
      const m = t.match(/var listviewitems = (\[[\s\S]*?\]);\n/);
      const arr = m ? JSON.parse(m[1].replace(/([{,])\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*:/g, '$1"$2":')) : [];
      store[u] = arr.map(o => [o.id, o.name, o.quality, o.reqlevel || 0, o.level || 0, o.slot, o.classs, o.subclass,
        o.side || 0, o.reqclass || 0, o.source || [],
        (o.sourcemore || []).map(s => [s.n || '', s.t || 0, s.ti || 0, s.z || 0, s.c || 0])]);
      localStorage.setItem('jsalGear', JSON.stringify(store));
      __gear.log.push(u + ' ' + arr.length);
    } catch (e) { __gear.err = u + ': ' + e; break; }
    await new Promise(r => setTimeout(r, 12000));
  }
  __gear.done = true;
  if (__gear.err) return;
  const by = new Map();
  for (const list of Object.values(store)) for (const i of list) if (!by.has(i[0])) by.set(i[0], i);
  const items = [...by.values()].map(i => [...i.slice(0, 11), (i[11] || []).slice(0, 3)]);
  const out = JSON.stringify({ fetched: FETCHED,
    fields: ['id', 'name', 'quality', 'reqlevel', 'itemlevel', 'slot', 'class', 'subclass', 'side', 'reqclass',
      'source', 'sourcemore[name,type,id,zone,c]'], items });
  location.href = 'http://127.0.0.1:8799/#' + encodeURIComponent(out);
})();
'started: ' + urls.length + ' lists; watch window.__gear'
