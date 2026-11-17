// Writes the icons in jsalUI/Media/Icons that were drawn after the first set: a gold shape on
// the set's own slate tile, 64 x 64, for the dashboard's menu and the quick buttons. The tile
// (its edge, corners and top-to-bottom shade) is taken from home.tga, with the house painted
// out, so a new icon sits in the set as one of it. Each shape is drawn in a 24-unit square in
// the tile's middle 40 pixels, as the others are.
//
//   profit  a stack of coins  Crafting profit
//   pals    a paw             Jsal's Pals (the paw its Settings card has)
//   crafts  an order sheet    Guild Crafts
//   run     a flag on a pole  Pal run
//
// Uses Playwright from jsal.io's build tools to draw the shapes, as make_menu_icons.mjs does.
// Run from the repo root: node tools/make_tile_icons.mjs
import { createRequire } from 'module';
import { readFileSync, writeFileSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const here = dirname(fileURLToPath(import.meta.url));
const require = createRequire(join(here, '..', '..', 'jsal.io', '.github', 'build', 'package.json'));
const { chromium } = require('playwright');

const GOLD = '#e3b04b';
const SIZE = 64;
// One coin's edge under the one above it: a band 2.4 thick, curved like the coin's rim.
const band = (y) => `M5 ${y}c0 1.66 3.13 3 7 3s7-1.34 7-3v2.4c0 1.66-3.13 3-7 3s-7-1.34-7-3z`;
const ICONS = {
  profit: `<ellipse cx="12" cy="6.6" rx="7" ry="3" fill="${GOLD}"/><path fill="${GOLD}" d="${band(7.8)} ${band(11.4)} ${band(15)}"/>`,
  pals: `<path fill="${GOLD}" d="M6.5 9.5a2 2 0 1 1 0-4 2 2 0 0 1 0 4zm11 0a2 2 0 1 1 0-4 2 2 0 0 1 0 4zM10 6.5a2 2 0 1 1 0-4 2 2 0 0 1 0 4zm4 0a2 2 0 1 1 0-4 2 2 0 0 1 0 4zM12 10.5c3 0 6 3.5 6 6.5 0 2-1.5 3-3 3-1.2 0-1.8-.6-3-.6s-1.8.6-3 .6c-1.5 0-3-1-3-3 0-3 3-6.5 6-6.5z"/>`,
  // A sheet with a turned corner and three lines on it: what's been asked for.
  crafts: `<path fill-rule="evenodd" fill="${GOLD}" d="M5.5 2.5h9L19 7v14.5H5.5zM8 9.6v2h8.5v-2zm0 3.9v2h8.5v-2zm0 3.9v2h5v-2z"/>`,
  // A pennant on its pole: the flag a run ends at.
  run: `<path fill="${GOLD}" d="M6 3h2.2v18H6zM9.2 4l10.3 4-10.3 4z"/>`,
};

const icons = join(dirname(fileURLToPath(import.meta.url)), '..', 'jsalUI', 'Media', 'Icons');

// The set's files are plain 32-bit TGAs, rows from the bottom, with the TGA 2 footer.
const HEAD = Buffer.from([0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, SIZE, 0, SIZE, 0, 32, 8]);
const FOOT = Buffer.concat([Buffer.alloc(8), Buffer.from('TRUEVISION-XFILE.\0', 'latin1')]);
function ReadTga(file) {
  const data = readFileSync(file);
  const rgba = new Uint8Array(SIZE * SIZE * 4);
  for (let y = 0; y < SIZE; y++) {
    for (let x = 0; x < SIZE; x++) {
      const from = 18 + ((SIZE - 1 - y) * SIZE + x) * 4, to = (y * SIZE + x) * 4;
      rgba[to] = data[from + 2]; rgba[to + 1] = data[from + 1]; rgba[to + 2] = data[from]; rgba[to + 3] = data[from + 3];
    }
  }
  return rgba;
}
function Tga(rgba) {
  const body = Buffer.alloc(SIZE * SIZE * 4);
  for (let y = 0; y < SIZE; y++) {
    for (let x = 0; x < SIZE; x++) {
      const from = (y * SIZE + x) * 4, to = ((SIZE - 1 - y) * SIZE + x) * 4;
      body[to] = rgba[from + 2]; body[to + 1] = rgba[from + 1]; body[to + 2] = rgba[from]; body[to + 3] = rgba[from + 3];
    }
  }
  return Buffer.concat([HEAD, body, FOOT]);
}

// The tile with nothing on it: inside its edge, each row is one colour, read just inside the
// edge where no shape reaches.
const tile = ReadTga(join(icons, 'home.tga'));
for (let y = 8; y < 56; y++) {
  const from = (y * SIZE + 7) * 4;
  for (let x = 8; x < 56; x++) tile.set(tile.subarray(from, from + 4), (y * SIZE + x) * 4);
}

const browser = await chromium.launch({ channel: 'msedge' });
const page = await browser.newPage();
for (const [name, shape] of Object.entries(ICONS)) {
  const pixels = await page.evaluate(async ({ shape, size, tile }) => {
    // 24 units in the middle 40 of 64 pixels.
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="-7.2 -7.2 38.4 38.4">${shape}</svg>`;
    const img = new Image();
    img.src = 'data:image/svg+xml;base64,' + btoa(svg);
    await img.decode();
    const under = document.createElement('canvas');
    under.width = under.height = size;
    under.getContext('2d').putImageData(new ImageData(new Uint8ClampedArray(tile), size, size), 0, 0);
    const canvas = document.createElement('canvas');
    canvas.width = canvas.height = size;
    const ctx = canvas.getContext('2d');
    ctx.drawImage(under, 0, 0);
    ctx.drawImage(img, 0, 0);
    return Array.from(ctx.getImageData(0, 0, size, size).data);
  }, { shape, size: SIZE, tile: Array.from(tile) });
  writeFileSync(join(icons, name + '.tga'), Tga(pixels));
  console.log('wrote', name + '.tga');
}
await browser.close();
