// Regenerates the tvOS app icon (layered parallax) + top-shelf art for Aeria+.
// Usage:  cd Tools/brand && npm i sharp && node generate-icon.mjs
//
// Direction: sibling to "tv+" / "D+" — a near-black tile with a faint top light
// and a clean geometric "A+" wordmark. The A is a solid letterform in soft
// off-white; the "+" is a small raised mark, the one spot of blue. No chrome,
// no glow. Parallax layers: Back = tile + light · Middle = the A · Front = the +.
import sharp from "sharp";
import { mkdirSync, writeFileSync } from "fs";
import { dirname, join } from "path";
import { fileURLToPath } from "url";

const REPO = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const BRAND = join(REPO, "Resources/Assets.xcassets/App Icon & Top Shelf Image.brandassets");
const PREVIEW = join(REPO, "docs/brand");

// ---- palette --------------------------------------------------------------
const TILE_TOP = "#101216";
const TILE_BOT = "#060608";
const BLUE     = "#3B9EFF";   // the "+" — matches Palette.accent

// ---- the "A" ---------------------------------------------------------------
// Two mitred legs (a sharp ^) plus a crossbar, all one fill. `x` is the optical
// centre of the letter.
function letterA(x, cy, h) {
  const AH = h * 0.212;              // half-height
  const OW = h * 0.176;              // outer half-width at the feet
  const LT = h * 0.124;              // leg thickness
  const top = cy - AH, bot = cy + AH;

  const legs = `M ${(x - OW).toFixed(1)} ${bot.toFixed(1)} ` +
               `L ${x.toFixed(1)} ${top.toFixed(1)} ` +
               `L ${(x + OW).toFixed(1)} ${bot.toFixed(1)}`;

  // crossbar just above the vertical middle; spans to (almost) the outer edges
  const barY = cy + AH * 0.24;
  const f = (barY - top) / (2 * AH);
  const half = OW * f - LT * 0.12;
  const barT = h * 0.100;
  const cross = `M ${(x - half).toFixed(1)} ${(barY - barT / 2).toFixed(1)} ` +
                `h ${(2 * half).toFixed(1)} v ${barT.toFixed(1)} ` +
                `h ${(-2 * half).toFixed(1)} Z`;

  return { legs, cross, legWidth: LT, rightEdge: x + OW, apexY: top };
}

// ---- the "+" -------------------------------------------------------------
// Small raised mark to the upper-right of the A. Two rounded bars, nonzero fill.
function plusMark(cx, cy, h) {
  const arm = h * 0.082;
  const t   = h * 0.050;
  const r   = t * 0.44;
  const bar = (w, ht) =>
    `M ${(cx - w).toFixed(1)} ${(cy - ht).toFixed(1)} ` +
    `h ${(2 * w).toFixed(1)} a ${r} ${r} 0 0 1 ${r} ${r} ` +
    `v ${(2 * ht - 2 * r).toFixed(1)} a ${r} ${r} 0 0 1 ${-r} ${r} ` +
    `h ${(-2 * w).toFixed(1)} a ${r} ${r} 0 0 1 ${-r} ${-r} ` +
    `v ${(-(2 * ht - 2 * r)).toFixed(1)} a ${r} ${r} 0 0 1 ${r} ${-r} Z`;
  return `${bar(arm, t / 2)} ${bar(t / 2, arm)}`;
}

// ---- one layer -----------------------------------------------------------
// layer: back | middle | front | flat
function svg(w, h, layer, { cxFrac = 0.5, cyFrac = 0.5, markScale = 1 } = {}) {
  const s = h * markScale;
  const cy = h * cyFrac;
  // shift the A left of centre so the whole "A+" lockup is optically centred
  const ax = w * cxFrac - s * 0.03;
  const a = letterA(ax, cy, s);
  const plusX = a.rightEdge + s * 0.03;      // kisses the A's right leg
  const plusY = a.apexY + s * 0.075;         // raised, near the apex
  const plus = plusMark(plusX, plusY, s);
  const has = (name) => layer === name || layer === "flat";

  const defs = `
    <linearGradient id="tile" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="${TILE_TOP}"/><stop offset="100%" stop-color="${TILE_BOT}"/>
    </linearGradient>
    <radialGradient id="toplight" cx="50%" cy="0%" r="75%">
      <stop offset="0%" stop-color="#FFFFFF" stop-opacity="0.05"/>
      <stop offset="60%" stop-color="#FFFFFF" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="letter" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#F6F7F9"/><stop offset="100%" stop-color="#DDDFE3"/>
    </linearGradient>`;

  const parts = [];

  if (has("back")) {
    parts.push(`<rect width="${w}" height="${h}" fill="url(#tile)"/>`);
    parts.push(`<rect width="${w}" height="${h}" fill="url(#toplight)"/>`);
  }

  if (has("middle")) {
    parts.push(`<g fill="none" stroke="url(#letter)" stroke-width="${a.legWidth}" ` +
               `stroke-linejoin="miter" stroke-miterlimit="6" stroke-linecap="butt">` +
               `<path d="${a.legs}"/></g>`);
    parts.push(`<path d="${a.cross}" fill="url(#letter)"/>`);
  }

  if (has("front")) {
    parts.push(`<path d="${plus}" fill="${BLUE}"/>`);
  }

  return `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">
    <defs>${defs}</defs>${parts.join("")}</svg>`;
}

// ---- render + asset catalog --------------------------------------------------
async function render(svgStr, w, h, outPath) {
  mkdirSync(dirname(outPath), { recursive: true });
  await sharp(Buffer.from(svgStr)).resize(w, h).png().toFile(outPath);
}
function imagesetContents(dir, files) {
  writeFileSync(join(dir, "Contents.json"), JSON.stringify({
    images: files.map(f => ({ idiom: "tv", filename: f.name, scale: f.scale })),
    info: { author: "xcode", version: 1 },
  }, null, 2) + "\n");
}
async function buildStack(stackDir, w, h) {
  for (const L of ["Back", "Middle", "Front"]) {
    const dir = join(stackDir, `${L}.imagestacklayer`, "Content.imageset");
    const k = L.toLowerCase();
    await render(svg(w, h, k), w, h, join(dir, `${k}.png`));
    await render(svg(w * 2, h * 2, k), w * 2, h * 2, join(dir, `${k}@2x.png`));
    imagesetContents(dir, [{ name: `${k}.png`, scale: "1x" }, { name: `${k}@2x.png`, scale: "2x" }]);
  }
}
async function buildFlat(dir, w, h, opts) {
  await render(svg(w, h, "flat", opts), w, h, join(dir, "image.png"));
  await render(svg(w * 2, h * 2, "flat", opts), w * 2, h * 2, join(dir, "image@2x.png"));
  imagesetContents(dir, [{ name: "image.png", scale: "1x" }, { name: "image@2x.png", scale: "2x" }]);
}

await buildStack(join(BRAND, "App Icon.imagestack"), 400, 240);
await buildStack(join(BRAND, "App Icon - App Store.imagestack"), 1280, 768);
await buildFlat(join(BRAND, "Top Shelf Image.imageset"), 1920, 720, { cxFrac: 0.30, markScale: 0.62 });
await buildFlat(join(BRAND, "Top Shelf Image Wide.imageset"), 2320, 720, { cxFrac: 0.26, markScale: 0.62 });

await render(svg(1200, 720, "flat"), 1200, 720, join(PREVIEW, "icon-preview.png"));
await render(svg(400, 240, "flat"), 400, 240, join(PREVIEW, "icon-400.png"));
await render(svg(1920, 720, "flat", { cxFrac: 0.30, markScale: 0.62 }), 1920, 720, join(PREVIEW, "topshelf-preview.png"));
console.log("done");
