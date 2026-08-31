# Brand assets

`generate-icon.mjs` renders the tvOS **App Icon** (a layered parallax icon —
Back / Middle / Front), the **App Store icon**, and the **Top Shelf** images
straight into `Resources/Assets.xcassets/App Icon & Top Shelf Image.brandassets/`.

## The mark

Warm beige field · rich charcoal squircle (Apple superellipse) with a subtle top
bevel and soft contact shadow · an off-white geometric capital **"A"** (an upward
wedge that reads as the letter, as ascent/air for *Aeria*, and — rotated — still
nods to a play triangle). Built as a compound `fill-rule="evenodd"` path in
`markPath()`; tune `H` / `W` / `barY` / `apexDrop` / `innerW` there.

Palette lives at the top of the script (`BEIGE`, `INK`, …).

## Regenerate

```bash
cd Tools/brand
npm i sharp        # one-off; not committed
node generate-icon.mjs
```

Previews are written to `docs/brand/`.
