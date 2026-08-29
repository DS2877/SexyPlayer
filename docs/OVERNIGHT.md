# Overnight session — what changed

Branch: `import-progress-checklist` · new commits `8e069b6` → `a3db0e8`.

**⚠️ None of this has been compiled.** I can't build Swift on the Windows box.
Structural checks pass (braces/parens balanced, patterns match ones that built
before), but budget for a few first-compile fixes. Pull → `xcodegen generate` →
build, and send me any errors.

## The lockout is fixed three ways

1. **The app never full-screen-blocks on the import any more.** After you pick a
   provider you land in the app; a slim status pill ("Importing your library…")
   shows over whatever screen you're on until it's done.
2. The onboarding checklist has a **12-second escape** — an "Enter the app"
   button appears whether or not the import finished, so a slow or stuck import
   can't trap you.
3. The import itself flips to "ready" the instant the catalog is in memory
   (cache-writing moved to the background), so on a big library you're not
   waiting on `JSONEncoder`.

## New: sidebar navigation

Replaced the top tab bar with a fixed **left sidebar** — Home / Search / Live TV
/ Guide / Movies / Series / Favorites / Settings. Selected item highlighted,
focus scales it. **Please check focus moves cleanly** between the sidebar and the
content, and that you can always get back to Settings (that's the anti-soft-lock
path if a provider is misconfigured).

## New screens

| Screen | What it does |
|---|---|
| **Search** | Type a natural request ("scary movie with Swedish subtitles", "something like Game of Thrones"). It's parsed on-device (no API key needed) into filters, shows them as removable chips, and searches your library. Example queries on the empty state. |
| **Guide** | Per-channel horizontal strips of upcoming programmes with now/next + a live progress bar. Chosen over a 2-D timeline grid because that's miserable to navigate with the Siri Remote. |
| **Favorites** | Grids of everything you've hearted (movies / series / channels). |

## Player hardening

- Streams AVPlayer can't handle — raw **MPEG-TS** (`.ts`), MKV/AVI containers,
  `rtmp://`/`rtsp://`/`udp://` — are now refused **before** the spinner, with a
  plain explanation ("ask your provider for an HLS output").
- 25-second load timeout: if AVPlayer never starts, you get an error + Close
  instead of an infinite spinner.
- The player error screen always has a **Close** button now.

## Personalize (from the earlier commit, in case it wasn't built yet)

Last onboarding step, and re-openable from **Settings → Personalize**: preferred
audio languages, subtitle language, hide-adult toggle, and which Home rows show
and in what order.

---

## What to test first (in order)

1. **It builds.** Send errors if not.
2. Fresh launch → onboarding → **Xtream** → does it connect? Does the checklist
   progress? Can you get into the app (button after 12s at worst)?
3. Sidebar focus feels OK, every section opens.
4. Open a **movie** → Play. Then a **live channel** — note if it's "not
   supported" (likely MPEG-TS) vs actually plays.
5. **Search** — try the examples and a couple of your own.
6. **Guide** — do your channels show programmes?
7. Kill and relaunch — does it come back **fast** from cache?

## Known gaps (see LAUNCH.md for the full list)

- Autoplay-next-episode: preference exists, not wired to the player.
- Claude-backed search: on-device parser only for now (needs an API-key
  decision).
- Guide is now/next strips, not a full timeline grid.
- Reminders for upcoming programmes: not built.
- No real-data testing yet — that's on you.
