# Brand assets

`generate-icon.mjs` renders the tvOS **App Icon** (a layered parallax icon —
Back / Middle / Front), the **App Store icon**, and the **Top Shelf** images
straight into `Resources/Assets.xcassets/App Icon & Top Shelf Image.brandassets/`.

## The mark

The **"Aeria+" wordmark** — set in a heavy grotesque (Helvetica 800) with a
polished chrome vertical gradient on near-black. Same treatment everywhere: the
Apple TV home-screen icon, the top shelf, the sidebar (`Wordmark.swift`), the
website.

Parallax layers: **Back** = tile + faint top light · **Middle** = a soft dark
drop of the wordmark · **Front** = the chrome text.

The type is rendered by resvg (via `sharp`) from the Mac's system fonts. If the
preview shows a blank tile or the wrong face, the font name in `FONT` didn't
resolve — say so and we'll bundle the exact TTF + `opentype.js`.

Tune `FONT`, the `chrome` gradient stops, and `widthFrac` per call.

## Regenerate

```bash
cd Tools/brand
npm i sharp        # one-off; not committed
node generate-icon.mjs
```

Previews are written to `docs/brand/`.
