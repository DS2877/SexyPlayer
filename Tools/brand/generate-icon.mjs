// Regenerates the tvOS app icon (layered parallax) + top-shelf art for Aeria+.
// Usage:  cd Tools/brand && npm i sharp && node generate-icon.mjs
//
// The mark: a near-black tile with a soft blue aura, a chrome capital "A"
// (two rounded strokes meeting at a point), and a blue "+" floating in the
// crossbar gap. Parallax layers: Back = tile + glow · Middle = the A ·
// Front = the +  (so the plus lifts off the A on the Apple TV home screen).
import sharp from "sharp";
import { mkdirSync, writeFileSync } from "fs";
import { dirname, join } from "path";
import { fileURLToPath } from "url";

const REPO = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const BRAND = join(REPO, "Resources/Assets.xcassets/App Icon & Top Shelf Image.brandassets");
const PREVIEW = join(REPO, "docs/brand");

// ---- palette --------------------------------------------------------------
const TILE_TOP = "#15161A";   // top of the tile
const TILE_BOT = "#08080A";   // bottom of the tile
const BLUE     = "#3C9DFF";   // the plus + the aura
const BLUE_DEEP = "#1E63E6";

// ---- geometry helpers ---------------------------------------------------------
// The "A": one open polyline foot → apex → foot, round caps + joins.
function aPath(cx, cy, h) {
  const AH = h * 0.300;            // half-height
  const AW = h * 0.232;            // half-width at the feet
  const apex = [cx, cy - AH];
  const lf   = [cx - AW, cy + AH];
  const rf   = [cx + AW, cy + AH];
  const d = `M ${lf[0].toFixed(1)} ${lf[1].toFixed(1)} ` +
            `L ${apex[0].toFixed(1)} ${apex[1].toFixed(1)} ` +
            `L ${rf[0].toFixed(1)} ${rf[1].toFixed(1)}`;
  return { d, width: h * 0.088 };
}

// The "+": two rounded bars, centred just below the icon centre.
function plusPaths(cx, cy, h) {
  const c = [cx, cy + h * 0.055];
  const arm = h * 0.120;          // half-length of each bar
  const t   = h * 0.066;          // bar thickness
  const r   = t * 0.42;
  const hBar = `M ${(c[0]-arm).toFixed(1)} ${(c[1]-t/2).toFixed(1)} h ${(2*arm).toFixed(1)} a ${r} ${r} 0 0 1 ${r} ${r} v ${(t-2*r).toFixed(1)} a ${r} ${r} 0 0 1 ${-r} ${r} h ${(-2*arm).toFixed(1)} a ${r} ${r} 0 0 1 ${-r} ${-r} v ${(-(t-2*r)).toFixed(1)} a ${r} ${r} 0 0 1 ${r} ${-r} Z`;
  const vBar = `M ${(c[0]-t/2).toFixed(1)} ${(c[1]-arm).toFixed(1)} v ${(2*arm).toFixed(1)} a ${r} ${r} 0 0 1 ${-r} ${r} h ${(-(t-2*r)).toFixed(1)} a ${r} ${r} 0 0 1 ${-r} ${-r} v ${(-2*arm).toFixed(1)} a ${r} ${r} 0 0 1 ${r} ${-r} h ${(t-2*r).toFixed(1)} a ${r} ${r} 0 0 1 ${r} ${r} Z`;
  return `${hBar} ${vBar}`;
}

// ---- one layer --------------------------------------------------------------
// layer: back | middle | front | flat
function svg(w, h, layer, { cxFrac = 0.5, cyFrac = 0.5, markScale = 1 } = {}) {
  const cx = w * cxFrac, cy = h * cyFrac;
  const a = aPath(cx, cy, h * markScale);
  const plus = plusPaths(cx, cy, h * markScale);
  const has = (name) => layer === name || layer === "flat";

  const defs = `
    <linearGradient id="tile" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%"  stop-color="${TILE_TOP}"/>
      <stop offset="100%" stop-color="${TILE_BOT}"/>
    </linearGradient>
    <radialGradient id="aura" cx="50%" cy="46%" r="42%">
      <stop offset="0%"  stop-color="${BLUE}" stop-opacity="0.42"/>
      <stop offset="55%" stop-color="${BLUE_DEEP}" stop-opacity="0.14"/>
      <stop offset="100%" stop-color="${BLUE_DEEP}" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="chrome" x1="0" y1="0" x2="0.15" y2="1">
      <stop offset="0%"   stop-color="#FFFFFF"/>
      <stop offset="34%"  stop-color="#DFE2E6"/>
      <stop offset="52%"  stop-color="#9BA1A9"/>
      <stop offset="70%"  stop-color="#C6CBD1"/>
      <stop offset="100%" stop-color="#FFFFFF"/>
    </linearGradient>
    <filter id="blueGlow" x="-80%" y="-80%" width="260%" height="260%">
      <feGaussianBlur stdDeviation="${h * 0.03}"/>
    </filter>
    <filter id="soft" x="-60%" y="-60%" width="220%" height="220%">
      <feGaussianBlur stdDeviation="${h * 0.012}"/>
    </filter>`;

  const parts = [];

  if (has("back")) {
    parts.push(`<rect width="${w}" height="${h}" fill="url(#tile)"/>`);
    parts.push(`<rect width="${w}" height="${h}" fill="url(#aura)"/>`);
  }

  if (has("middle")) {
    // faint drop for depth, then the chrome A
    parts.push(`<g opacity="0.5"><path d="${a.d}" fill="none" stroke="#000" stroke-width="${a.width}" stroke-linecap="round" stroke-linejoin="round" filter="url(#soft)" transform="translate(0 ${h*0.012})"/></g>`);
    parts.push(`<path d="${a.d}" fill="none" stroke="url(#chrome)" stroke-width="${a.width}" stroke-linecap="round" stroke-linejoin="round"/>`);
  }

  if (has("front")) {
    // nonzero winding — the two bars overlap in the centre and must stay solid
    parts.push(`<g filter="url(#blueGlow)" opacity="0.9"><path d="${plus}" fill="${BLUE}"/></g>`);
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
