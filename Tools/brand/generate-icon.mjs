// Regenerates the tvOS app icon (layered parallax) + top-shelf art.
// Usage:  cd Tools/brand && npm i sharp && node generate-icon.mjs
import sharp from "sharp";
import { mkdirSync, writeFileSync } from "fs";
import { dirname, join } from "path";
import { fileURLToPath } from "url";

const REPO = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const BRAND = join(REPO, "Resources/Assets.xcassets/App Icon & Top Shelf Image.brandassets");
const PREVIEW = join(REPO, "docs/brand");

// ---- palette ---------------------------------------------------------------
const BEIGE     = "#E8DFCC";
const BEIGE_HI  = "#F2ECDD";
const BEIGE_LO  = "#DBD0B8";
const INK       = "#1A1710";   // warm near-black
const INK_HI    = "#2E2A20";   // top bevel of the tile

// ---- superellipse (Apple-style squircle) ----------------------------------
function squirclePath(cx, cy, size, n = 4.6, steps = 96) {
  const a = size / 2, b = size / 2;
  let d = "";
  for (let i = 0; i <= steps; i++) {
    const t = (i / steps) * 2 * Math.PI;
    const ct = Math.cos(t), st = Math.sin(t);
    const x = cx + a * Math.sign(ct) * Math.pow(Math.abs(ct), 2 / n);
    const y = cy + b * Math.sign(st) * Math.pow(Math.abs(st), 2 / n);
    d += (i === 0 ? "M" : "L") + x.toFixed(2) + " " + y.toFixed(2) + " ";
  }
  return d + "Z";
}

// The "Aeria" mark: a bold geometric capital A — an upward wedge that reads as
// the letter, as ascent/air, and (rotated) still nods to a play triangle. Built
// as a compound path (solid outer A minus the counter above the crossbar) with
// `fill-rule="evenodd"`; corners are softened by a matched round-join stroke.
function markPath(cx, cy, h) {
  const H  = h * 0.235;              // half-height of the A
  const W  = h * 0.210;              // half-width at the base (outer)
  const barY = cy + H * 0.40;        // bottom of the counter = top of the crossbar
  const apexDrop = h * 0.072;        // inner apex sits below the outer apex
  const innerW = h * 0.085;          // half-width of the counter at the crossbar

  const topY = cy - H, botY = cy + H;

  const outer =
    `M ${cx.toFixed(2)} ${topY.toFixed(2)} ` +
    `L ${(cx + W).toFixed(2)} ${botY.toFixed(2)} ` +
    `L ${(cx - W).toFixed(2)} ${botY.toFixed(2)} Z`;

  // Counter (the triangular hole) — only the part above the crossbar.
  const counter =
    `M ${cx.toFixed(2)} ${(topY + apexDrop).toFixed(2)} ` +
    `L ${(cx + innerW).toFixed(2)} ${barY.toFixed(2)} ` +
    `L ${(cx - innerW).toFixed(2)} ${barY.toFixed(2)} Z`;

  // Small round-join stroke just to soften the points — thin enough that it
  // doesn't close the counter.
  return { d: `${outer} ${counter}`, round: h * 0.022 };
}

// ---- one layer ----------------------------------------------------------------
// layer: back | middle | front | flat
function svg(w, h, layer, { cxFrac = 0.5, cyFrac = 0.5, tile = 0.76 } = {}) {
  const cx = w * cxFrac, cy = h * cyFrac;
  const size = h * tile;
  const sq = squirclePath(cx, cy, size);
  const t = markPath(cx, cy, h);

  const defs = `
    <radialGradient id="bg" cx="${(cx / w) * 100}%" cy="${(cy / h) * 42}%" r="80%">
      <stop offset="0%"  stop-color="${BEIGE_HI}"/>
      <stop offset="55%" stop-color="${BEIGE}"/>
      <stop offset="100%" stop-color="${BEIGE_LO}"/>
    </radialGradient>
    <linearGradient id="tile" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%"  stop-color="${INK_HI}"/>
      <stop offset="14%" stop-color="${INK}"/>
      <stop offset="100%" stop-color="${INK}"/>
    </linearGradient>
    <filter id="sh" x="-60%" y="-60%" width="220%" height="220%">
      <feGaussianBlur stdDeviation="${h * 0.045}"/>
    </filter>`;

  const parts = [];
  const has = (name) => layer === name || layer === "flat";

  if (has("back")) parts.push(`<rect width="${w}" height="${h}" fill="url(#bg)"/>`);

  if (has("middle")) {
    parts.push(`<g opacity="0.20"><path d="${squirclePath(cx, cy + h * 0.03, size * 1.02)}" fill="${INK}" filter="url(#sh)"/></g>`);
    parts.push(`<path d="${sq}" fill="url(#tile)"/>`);
    // faint top rim light
    parts.push(`<path d="${sq}" fill="none" stroke="#FFFFFF" stroke-opacity="0.05" stroke-width="${h * 0.012}"/>`);
    // mark contact shadow lives here so it stays put during parallax
    parts.push(`<g opacity="0.28"><path d="${t.d}" fill="#000" fill-rule="evenodd" filter="url(#sh)" transform="translate(${h * 0.006} ${h * 0.016})"/></g>`);
  }

  if (has("front")) {
    if (layer === "flat") {
      parts.push(`<g opacity="0.24"><path d="${t.d}" fill="#000" fill-rule="evenodd" filter="url(#sh)" transform="translate(${h * 0.006} ${h * 0.016})"/></g>`);
    }
    parts.push(`<path d="${t.d}" fill="${BEIGE_HI}" fill-rule="evenodd" stroke="${BEIGE_HI}" stroke-width="${t.round}" stroke-linejoin="round"/>`);
  }

  return `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">
    <defs>${defs}</defs>${parts.join("")}</svg>`;
}

// ---- render + asset catalog ----------------------------------------------
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
await buildFlat(join(BRAND, "Top Shelf Image.imageset"), 1920, 720, { cxFrac: 0.30, tile: 0.62 });
await buildFlat(join(BRAND, "Top Shelf Image Wide.imageset"), 2320, 720, { cxFrac: 0.26, tile: 0.62 });

await render(svg(1200, 720, "flat"), 1200, 720, join(PREVIEW, "icon-preview.png"));
await render(svg(400, 240, "flat"), 400, 240, join(PREVIEW, "icon-400.png"));
await render(svg(1920, 720, "flat", { cxFrac: 0.30, tile: 0.62 }), 1920, 720, join(PREVIEW, "topshelf-preview.png"));
console.log("done");
