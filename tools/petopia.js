// Reads Petopia's WoW Forever ability page for data/pets/petopia.json: each pet ability rank, the
// pet level and training points it needs, and the beasts that have it (creature ID, name, and
// Petopia's "family, level, zone"). One page, no waiting. Start tools/wowhead/receive.py first
// (python -I tools/wowhead/receive.py data/pets/petopia.json), open
// https://www.wow-petopia.com/forever/abilities.php in the browser pane, and run this there.
(() => {
  const ranks = {};
  for (const li of document.querySelectorAll('li.abilityrank')) {
    const m = ((li.querySelector('.abilityrankname') || {}).textContent || '').trim().match(/^(.+?) (\d+)$/);
    if (!m) continue;
    const own = [...li.childNodes].filter(n => n.nodeType === 3).map(n => n.textContent).join(' ');
    const lv = own.match(/Pet Level (\d+), Cost (\d+) TP/) || [];
    ranks[m[1] + '|' + m[2]] = {
      level: +lv[1] || 0, cost: +lv[2] || 0,
      beasts: [...li.querySelectorAll('li.abilityranknpc')].map(b => {
        const a = b.querySelector('a');
        const id = ((a && a.getAttribute('href')) || '').match(/npc=(\d+)/);
        return [id ? +id[1] : 0, a ? a.textContent.trim() : '', (b.textContent.match(/\(([^()]*)\)\s*$/) || [])[1] || ''];
      }),
    };
  }
  const out = JSON.stringify({ fetched: new Date().toISOString().slice(0, 10), source: location.href, ranks });
  location.href = 'http://127.0.0.1:8799/#' + encodeURIComponent(out);
})();
