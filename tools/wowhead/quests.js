// Reads where each dungeon quest starts, and the quest before it in its chain, from Wowhead
// Forever's quest pages, for data/dungeons/quest-starts.json. Run in the browser pane on a
// www.wowhead.com/forever page, after the window.__questIds line that tools/wowhead/quest_ids.py
// prints (with --missing, the quests quest-starts.json doesn't have yet, and a window.__questSeen
// line with the ones it has, so a batch carries on from there). A quest whose chain has an earlier step that isn't on the list gets that step read
// too. One page every 10 seconds. Wowhead challenges the reader every 25 pages or so: the batch
// then stops and sends what it read to tools/wowhead/receive.py (start it first, writing to a
// scratch file), and tools/wowhead/merge_quests.py folds that into quest-starts.json, so nothing
// read is lost; John clears the check in the pane, and the next batch carries on.
const wait = ms => new Promise(r => setTimeout(r, ms));
async function page(url) {
  const r = await fetch(url);
  const t = await r.text();
  if (r.status !== 200 || t.includes('<title>Human Verification')) throw new Error('blocked at ' + url);
  return t;
}
// One quest's page: who or what starts it, where (Wowhead's zone, its area ID and the spot, 0
// to 100), and the quest before it in its series.
function readQuest(t) {
  const out = { n: null, s: null, z: null, prev: null };
  const h1 = t.match(/<h1[^>]*>([^<]*)<\/h1>/);
  if (h1) out.n = h1[1].replace(/&#039;/g, "'").replace(/&amp;/g, '&').trim();
  const st = t.match(/Start: \[url=\\\/forever\\\/(npc|object|item)=(\d+)[^\]]*\]([^\[]*)\[/);
  if (st) out.s = [st[1], +st[2], st[3].replace(/\\'/g, "'")];
  const mm = t.match(/new Mapper\((\{.*?\})(?:, *true)?\);/);
  if (mm) {
    try {
      const o = JSON.parse(mm[1]);
      for (const [area, v] of Object.entries(o.objectives || {})) {
        for (const lv of v.levels || []) for (const p of lv) {
          if (p.point !== 'start' && p.point !== 'startend') continue;
          const c = p.coord && typeof p.coord[0] === 'number' ? p.coord : null;
          if (!out.z || (c && !out.z[2])) out.z = [+area, v.zone || '', c ? c[0] : 0, c ? c[1] : 0];
        }
      }
    } catch (e) { /* no spot */ }
  }
  const doc = new DOMParser().parseFromString(t, 'text/html');
  const rows = [...doc.querySelectorAll('table.series tr')];
  const here = rows.findIndex(r => !r.querySelector('a[href*="quest="]'));
  if (here > 0) {
    const a = rows[here - 1].querySelector('a[href*="quest="]');
    const id = a && a.getAttribute('href').match(/quest=(\d+)/);
    if (id) out.prev = +id[1];
  }
  return out;
}
const FETCHED = new Date().toISOString().slice(0, 10);
window.__quests = { done: false, read: 0, left: 0, err: null };
(async () => {
  const store = {};
  const seen = new Set(window.__questSeen || []);
  const todo = [...window.__questIds];
  try {
    while (todo.length) {
      const id = todo.shift();
      __quests.left = todo.length;
      if (!store[id] && !seen.has(id)) {
        store[id] = readQuest(await page('/forever/quest=' + id));
        __quests.read++;
        await wait(10000);
      }
      const prev = store[id] && store[id].prev;
      if (prev && !store[prev] && !seen.has(prev) && !todo.includes(prev)) todo.unshift(prev);
    }
  } catch (e) { __quests.err = e.message; }
  __quests.done = true;
  // Done or stopped, what's read goes to the receiver: a stop leaves "stopped" saying where.
  const out = { fetched: FETCHED, quests: store };
  if (__quests.err) out.stopped = __quests.err;
  location.href = 'http://127.0.0.1:8799/#' + encodeURIComponent(JSON.stringify(out));
})();
'started: ' + window.__questIds.length + ' quests; watch window.__quests'
