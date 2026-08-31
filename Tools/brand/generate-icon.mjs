// Regenerates the tvOS app icon (layered parallax) + top-shelf art for Aeria+.
// Usage:  cd Tools/brand && npm i sharp && node generate-icon.mjs
//
// The mark is the wordmark: "Aeria+" set in a heavy grotesque with a polished
// chrome vertical gradient on near-black — the way it should read on the Apple
// TV home screen and everywhere in the app. Parallax layers: Back = tile +
// faint light · Middle = a soft drop of the wordmark · Front = the chrome text.
import sharp from "sharp";
import { mkdirSync, writeFileSync } from "fs";
import { dirname, join } from "path";
import { fileURLToPath } from "url";

const REPO = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const BRAND = join(REPO, "Resources/Assets.xcassets/App Icon & Top Shelf Image.brandassets");
const PREVIEW = join(REPO, "docs/brand");

const WORD = "Aeria+";
// Bold grotesque. resvg (via sharp) resolves these from the Mac's system fonts
// (/System/Library/Fonts). Helvetica / Helvetica Neue are always present.
const FONT = "Helvetica, Helvetica Neue, Arial, sans-serif";

// ---- one layer -----------------------------------------------------------
// layer: back | middle | front | flat
function svg(w, h, layer, { widthFrac = 0.80, yFrac = 0.5 } = {}) {
  const cx = w / 2, cy = h * yFrac;
  // size the type to a target fraction of the tile width
  const fontSize = (w * widthFrac) / 3.05;         // ≈ advance width of "Aeria+" at weight 800
  const has = (name) => layer === name || layer === "flat";

  const defs = `
    <linearGradient id="tile" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#0C0C0E"/><stop offset="100%" stop-color="#000000"/>
    </linearGradient>
    <radialGradient id="toplight" cx="50%" cy="4%" r="70%">
      <stop offset="0%" stop-color="#FFFFFF" stop-opacity="0.06"/>
      <stop offset="55%" stop-color="#FFFFFF" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="chrome" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%"  stop-color="#F8F9FB"/>
      <stop offset="38%" stop-color="#ADB2BA"/>
      <stop offset="50%" stop-color="#767C86"/>
      <stop offset="56%" stop-color="#EEF0F3"/>
      <stop offset="78%" stop-color="#C2C6CD"/>
      <stop offset="100%" stop-color="#9DA2AA"/>
    </linearGradient>
    <filter id="drop" x="-20%" y="-20%" width="140%" height="160%">
      <feGaussianBlur stdDeviation="${h * 0.012}"/>
    </filter>`;

  const label = (fill, extra = "") =>
    `<text x="${cx.toFixed(1)}" y="${cy.toFixed(1)}" text-anchor="middle" ` +
    `dominant-baseline="central" font-family="${FONT}" font-weight="800" ` +
    `font-size="${fontSize.toFixed(1)}" letter-spacing="-0.015em" ${extra} ` +
    `fill="${fill}">${WORD}</text>`;

  const parts = [];
  if (has("back")) {
    parts.push(`<rect width="${w}" height="${h}" fill="url(#tile)"/>`);
    parts.push(`<rect width="${w}" height="${h}" fill="url(#toplight)"/>`);
  }
  if (has("middle")) {
    parts.push(`<g opacity="0.55" filter="url(#drop)" transform="translate(0 ${(h * 0.010).toFixed(1)})">` +
               label("#000000") + `</g>`);
  }
  if (has("front")) {
    parts.push(label("url(#chrome)"));
  }

  return `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">
    <defs>${defs}</defs>${parts.join("")}</svg>`;
}

// ---- render + asset catalog --------------------------------------------------
async function render(svgStr, w, h, outPath) {
  mkdirSync(dirname(outPath), { recursive: true });
  await sharp(Buffer.from(svgStr), { density: 384 }).resize(w, h).png().toFile(outPath);
}
function imagesetContents(dir, files) {
  writeFileSync(join(dir, "Contents.json"), JSON.stringify({
    images: files.map(f => ({ idiom: "tv", filename: f.name, scale: f.scale })),
    info: { author: "xcode", version: 1 },
  }, null, 2) + "\n");
}
async function buildStack(stackDir, w, h, opts) {
  for (const L of ["Back", "Middle", "Front"]) {
    const dir = join(stackDir, `${L}.imagestacklayer`, "Content.imageset");
    const k = L.toLowerCase();
    await render(svg(w, h, k, opts), w, h, join(dir, `${k}.png`));
    await render(svg(w * 2, h * 2, k, opts), w * 2, h * 2, join(dir, `${k}@2x.png`));
    imagesetContents(dir, [{ name: `${k}.png`, scale: "1x" }, { name: `${k}@2x.png`, scale: "2x" }]);
  }
}
async function buildFlat(dir, w, h, opts) {
  await render(svg(w, h, "flat", opts), w, h, join(dir, "image.png"));
  await render(svg(w * 2, h * 2, "flat", opts), w * 2, h * 2, join(dir, "image@2x.png"));
  imagesetContents(dir, [{ name: "image.png", scale: "1x" }, { name: "image@2x.png", scale: "2x" }]);
}

await buildStack(join(BRAND, "App Icon.imagestack"), 400, 240, { widthFrac: 0.80 });
await buildStack(join(BRAND, "App Icon - App Store.imagestack"), 1280, 768, { widthFrac: 0.80 });
await buildFlat(join(BRAND, "Top Shelf Image.imageset"), 1920, 720, { widthFrac: 0.34 });
await buildFlat(join(BRAND, "Top Shelf Image Wide.imageset"), 2320, 720, { widthFrac: 0.30 });

await render(svg(1200, 720, "flat", { widthFrac: 0.62 }), 1200, 720, join(PREVIEW, "icon-preview.png"));
await render(svg(400, 240, "flat", { widthFrac: 0.80 }), 400, 240, join(PREVIEW, "icon-400.png"));
await render(svg(1920, 720, "flat", { widthFrac: 0.34 }), 1920, 720, join(PREVIEW, "topshelf-preview.png"));
console.log("done — check docs/brand/icon-preview.png");
