# Brand assets

`generate-icon.mjs` renders the tvOS **App Icon** (a layered parallax icon —
Back / Middle / Front), the **App Store icon**, and the **Top Shelf** images
straight into `Resources/Assets.xcassets/App Icon & Top Shelf Image.brandassets/`.

## The mark

Warm beige field · rich charcoal squircle (Apple superellipse) with a subtle top
bevel and soft contact shadow · an off-white play mark with a gently concave
trailing edge (reads as motion, and keeps the silhouette custom rather than a
generic play button).

Palette lives at the top of the script (`BEIGE`, `INK`, …).

## Regenerate

```bash
cd Tools/brand
npm i sharp        # one-off; not committed
node generate-icon.mjs
```

Previews are written to `docs/brand/`.
