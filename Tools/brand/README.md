# Brand assets

`generate-icon.mjs` renders the tvOS **App Icon** (a layered parallax icon —
Back / Middle / Front), the **App Store icon**, and the **Top Shelf** images
straight into `Resources/Assets.xcassets/App Icon & Top Shelf Image.brandassets/`.

## The mark

Sibling to `tv+` / `D+` — a near-black tile with a faint top light and a clean
geometric **"A+"** wordmark. The A is a solid letterform (mitred legs + crossbar)
in soft off-white; the **"+"** is a small raised mark, the one spot of blue. No
chrome, no glow.

Parallax layers: **Back** = tile + light · **Middle** = the A · **Front** = the +
(so the plus lifts slightly on the Apple TV home screen).

Tune `letterA()` / `plusMark()` and the palette (`TILE_*`, `BLUE`, the `letter`
gradient) at the top of the script.

## Regenerate

```bash
cd Tools/brand
npm i sharp        # one-off; not committed
node generate-icon.mjs
```

Previews are written to `docs/brand/`.
