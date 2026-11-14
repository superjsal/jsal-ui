// Writes jsalUI/Media/Icons/Parts/*.tga: a picture for each part of jsal.ui
// that has none among the menu bar's (Media/Icons/Menu), for its card on the
// Settings page. Each is a white shape on a clear 64 x 64 square, drawn from
// a 24-unit path as the menu bar's are; Settings tints it gold while the
// part is on, grey while it's off. Uses Playwright from jsal.io's build
// tools to draw the shapes, then writes plain 32-bit TGA files the game reads.
//
// Run from the repo root: node tools/make_part_icons.mjs
import { createRequire } from 'module';
import { mkdirSync, writeFileSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const require = createRequire('C:/Users/JSAL/Desktop/jsal.io/.github/build/package.json');
const { chromium } = require('playwright');

const ICONS = {
  dailyword: 'M2 8h6v8H2zm7 0h6v8H9zm7 0h6v8h-6z',
  chess: 'M12 3a3.2 3.2 0 0 1 2.2 5.5c1 .5 1.3 1.2 1.3 2h-1.8c.2 2.5 1.2 4.5 3.3 6.5v2H7v-2c2.1-2 3.1-4 3.3-6.5H8.5c0-.8.3-1.5 1.3-2A3.2 3.2 0 0 1 12 3zM6 20.5h12V22H6z',
  flight: 'M3 11 21 3l-6 18-3.5-7.5z',
  pet: 'M6.5 9.5a2 2 0 1 1 0-4 2 2 0 0 1 0 4zm11 0a2 2 0 1 1 0-4 2 2 0 0 1 0 4zM10 6.5a2 2 0 1 1 0-4 2 2 0 0 1 0 4zm4 0a2 2 0 1 1 0-4 2 2 0 0 1 0 4zM12 10.5c3 0 6 3.5 6 6.5 0 2-1.5 3-3 3-1.2 0-1.8-.6-3-.6s-1.8.6-3 .6c-1.5 0-3-1-3-3 0-3 3-6.5 6-6.5z',
  dungeons: 'M5 21V11a7 7 0 0 1 14 0v10h-4v-9a3 3 0 0 0-6 0v9z',
  nextlevel: 'M12 4l7 7h-4.2L12 8.2 9.2 11H5zm0 8l7 7h-4.2L12 16.2 9.2 19H5z',
  levelup: 'M12 2.5l2.9 6 6.6.9-4.8 4.6 1.2 6.5L12 17.4l-5.9 3.1 1.2-6.5L2.5 9.4l6.6-.9z',
  journal: 'M5 3h14v18H5zm3 4v2h8V7zm0 4v2h8v-2zm0 4v2h5v-2z',
  tametip: 'M7 4h3L8 20H5zm5.5 0h3l-2 16h-3zM18 4h3l-2 16h-3z',
  profwindow: 'M3 4h18v16H3zm2 5v9h14V9z',
  shopping: 'M4 5h3v3H4zm5 .5h11v2H9zm-5 5h3v3H4zm5 .5h11v2H9zm-5 5h3v3H4zm5 .5h11v2H9z',
  launcher: 'M4 4h7v7H4zm9 0h7v7h-7zM4 13h7v7H4zm9 0h7v7h-7z',
  minimap: 'M12 3a9 9 0 1 1 0 18 9 9 0 0 1 0-18zm0 3a6 6 0 1 0 0 12 6 6 0 0 0 0-12zm0 4a2 2 0 1 1 0 4 2 2 0 0 1 0-4z',
  menubar: 'M2 9h20v6H2zm3 2v2h2v-2zm5 0v2h2v-2zm5 0v2h2v-2z',
  vendor: 'M12 3a9 9 0 1 1 0 18 9 9 0 0 1 0-18zm0 3.5a5.5 5.5 0 1 0 0 11 5.5 5.5 0 0 0 0-11zM11 8.5h2v7h-2z',
  warnings: 'M12 3l10 18H2zm-1 6v6h2V9zm0 7.5v2h2v-2z',
  waypoint: 'M12 2a7 7 0 0 1 7 7c0 5-7 13-7 13S5 14 5 9a7 7 0 0 1 7-7zm0 4.5a2.5 2.5 0 1 0 0 5 2.5 2.5 0 0 0 0-5z',
  foodtile: 'M3 11h18c0 4.4-3 8-7 8.8V21h-4v-1.2C6 19 3 15.4 3 11zm6-7h2v5H9zm4 0h2v5h-2z',
  rangecheck: 'M12 4a8 8 0 1 1 0 16 8 8 0 0 1 0-16zm0 2.5a5.5 5.5 0 1 0 0 11 5.5 5.5 0 0 0 0-11zm0 4a1.5 1.5 0 1 1 0 3 1.5 1.5 0 0 1 0-3zM11 1h2v5h-2zm0 17h2v5h-2zM1 11h5v2H1zm17 0h5v2h-5z',
  layers: 'M12 3l9 4.5-9 4.5-9-4.5zm-9 9 2.2-1.1L12 14.3l6.8-3.4L21 12l-9 4.5zm0 4.5 2.2-1.1L12 18.8l6.8-3.4L21 16.5 12 21z',
  sharedFonts: 'M10.5 3h3l6 18h-3.2l-1.3-4H9l-1.3 4H4.5zm1.5 4.5L9.9 14h4.2z',
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

const out = join(dirname(fileURLToPath(import.meta.url)), '..', 'jsalUI', 'Media', 'Icons', 'Parts');
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
