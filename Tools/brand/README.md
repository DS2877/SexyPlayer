# Brand assets

`generate-icon.mjs` renders the tvOS **App Icon** (a layered parallax icon —
Back / Middle / Front), the **App Store icon**, and the **Top Shelf** images
straight into `Resources/Assets.xcassets/App Icon & Top Shelf Image.brandassets/`.

## The mark

Near-black tile with a soft blue aura · a **chrome capital "A"** (one open
polyline — foot → apex → foot — stroked with a vertical chrome gradient, round
caps) · a **blue "+"** floating in the crossbar gap with a blue glow.

Parallax layers: **Back** = tile + aura · **Middle** = the A · **Front** = the +
(so the plus lifts off the A on the Apple TV home screen).

Tune `aPath()` / `plusPaths()` and the palette (`TILE_*`, `BLUE`, `chrome`
gradient stops) at the top of the script.

## Regenerate

```bash
cd Tools/brand
npm i sharp        # one-off; not committed
node generate-icon.mjs
```

Previews are written to `docs/brand/`.
