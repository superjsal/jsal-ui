// Writes jsalUI/Media/Icons/Menu/*.tga: the icons jsal.ui draws on the game's
// menu bar buttons. Each is a white shape on a clear 64 x 64 square, drawn
// from a 24-unit path like the mockup John picked; the game tints it gold
// (or grey while a button is off). Uses Playwright from jsal.io's build tools
// to draw the shapes, then writes plain 32-bit TGA files the game reads.
//
// Run from the repo root: node tools/make_menu_icons.mjs
import { createRequire } from 'module';
import { mkdirSync, writeFileSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const require = createRequire('C:/Users/JSAL/Desktop/jsal.io/.github/build/package.json');
const { chromium } = require('playwright');

const ICONS = {
  character: 'M12 3a4.5 4.5 0 1 1 0 9 4.5 4.5 0 0 1 0-9zm-8 18c0-4.2 3.6-7 8-7s8 2.8 8 7z',
  professions: 'M4 6h11l-1.2 3H11v2.5c1.7.4 3 1.6 3.5 3.5H18v3H6v-3h3.5c.5-1.9 1.8-3.1 3.5-3.5V9H8.5C6.3 9 4.5 7.7 4 6zm15-1h2v3h-2z',
  spellbook: 'M6 3h11a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2zm6 4.2-1.1 2.6-2.7.3 2 1.8-.6 2.7L12 13.2l2.4 1.4-.6-2.7 2-1.8-2.7-.3z',
  talents: 'M12 2.5a2.5 2.5 0 0 1 1 4.8V10l4.2 2.4a2.5 2.5 0 1 1-1 1.7L12 11.7l-4.2 2.4a2.5 2.5 0 1 1-1-1.7L11 10V7.3a2.5 2.5 0 0 1 1-4.8zM11 15h2v4.2a2.5 2.5 0 1 1-2 0z',
  legacy: 'M12 2 20 5v6c0 5-3.4 8.9-8 11-4.6-2.1-8-6-8-11V5zm0 3.2L7 7v4c0 3.3 2 6 5 7.7z',
  quests: 'M10 3h4l-.7 11h-2.6zm2 13.5a2.2 2.2 0 1 1 0 4.4 2.2 2.2 0 0 1 0-4.4z',
  guild: 'M6 2h12v19l-6-4-6 4z',
  group: 'M8 5.5a3 3 0 1 1 0 6 3 3 0 0 1 0-6zm8 0a3 3 0 1 1 0 6 3 3 0 0 1 0-6zM2 19c0-3.2 2.7-5.5 6-5.5 1.6 0 3 .5 4 1.4 1-.9 2.4-1.4 4-1.4 3.3 0 6 2.3 6 5.5z',
  collections: 'M6 3h3.5v8.5a2.5 2.5 0 0 0 5 0V3H18v8.5a6 6 0 0 1-12 0zM5 18h4.5v3H5zm9.5 0H19v3h-4.5z',
  shop: 'M12 2.5 21 9l-9 12.5L3 9zm0 3.6L7.4 9.3h9.2z',
  bag: 'M9 3h6a2 2 0 0 1 2 2v1h1.5A2.5 2.5 0 0 1 21 8.5V19a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8.5A2.5 2.5 0 0 1 5.5 6H7V5a2 2 0 0 1 2-2zm0 2v1h6V5zm-1 6v2h8v-2z',
  help: 'M12 3c3.4 0 6 2.1 6 5.2 0 2.4-1.5 3.6-3 4.5-1.2.7-1.6 1.2-1.6 2.3v.5h-3v-.8c0-2 .9-3 2.4-3.9 1.2-.7 2-1.3 2-2.5 0-1.4-1.2-2.4-2.8-2.4-1.7 0-2.9 1-3 2.6H6C6.2 5.2 8.6 3 12 3zm-1.6 14.5h3.2V21h-3.2z',
};
const SIZE = 64;

// A plain 32-bit TGA, rows from the top, as the game reads it.
function Tga(rgba) {
  const head = Buffer.alloc(18);
  head[2] = 2;
  head.writeUInt16LE(SIZE, 12);
  head.writeUInt16LE(SIZE, 14);
  head[16] = 32;
  head[17] = 8 | 32;
  const body = Buffer.alloc(SIZE * SIZE * 4);
  for (let i = 0; i < SIZE * SIZE; i++) {
    body[i * 4] = rgba[i * 4 + 2];
    body[i * 4 + 1] = rgba[i * 4 + 1];
    body[i * 4 + 2] = rgba[i * 4];
    body[i * 4 + 3] = rgba[i * 4 + 3];
  }
  return Buffer.concat([head, body]);
}

const out = join(dirname(fileURLToPath(import.meta.url)), '..', 'jsalUI', 'Media', 'Icons', 'Menu');
mkdirSync(out, { recursive: true });
const browser = await chromium.launch({ channel: 'msedge' });
const page = await browser.newPage();
for (const [name, path] of Object.entries(ICONS)) {
  const pixels = await page.evaluate(async ({ path, size }) => {
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 24 24"><path fill="#fff" d="${path}"/></svg>`;
    const img = new Image();
    img.src = 'data:image/svg+xml;base64,' + btoa(svg);
    await img.decode();
    const canvas = document.createElement('canvas');
    canvas.width = canvas.height = size;
    const ctx = canvas.getContext('2d');
    ctx.drawImage(img, 0, 0, size, size);
    return Array.from(ctx.getImageData(0, 0, size, size).data);
  }, { path, size: SIZE });
  writeFileSync(join(out, name + '.tga'), Tga(pixels));
  console.log('wrote', name);
}
await browser.close();
