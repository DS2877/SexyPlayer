# Overnight session (2026-08-29 → 30)

Branch `import-progress-checklist`, commits `8e069b6` → HEAD (~20 commits).

**Not compiled** — I can't build Swift on Windows. But:
- A **tree-sitter parse check ran clean over all 109 Swift files** (one known
  false positive on `ChannelCard`'s line-split multi-trailing-closure).
- Every touched file was semantically hand-audited against the type it calls.

So syntax is verified; expect at most a couple of semantic fixes (a type
annotation, a conformance). Pull → `xcodegen generate` → wipe DerivedData →
build, and send me any errors.

## The lockout is dead — three fixes

1. **The app never full-screen-blocks on the import.** After you pick a provider
   you're *in the app*; a slim pill ("Importing your library…") floats over the
   content until it's done. Every screen shows a proper "still loading" state
   instead of a misleading "nothing here".
2. **12-second escape** on the onboarding checklist — "Enter the app" appears
   whether or not the import finished.
3. Import flips to *ready* the moment the catalog is in memory; the cache write
   is background.

## New

| | |
|---|---|
| **Sidebar navigation** | Fixed left sidebar (Home / Search / Live TV / Guide / Movies / Series / Favorites / Settings). `RootView` derives the onboarding step from state — no flash of the setup screen on relaunch. |
| **Search** | Natural language → on-device parse → your library. Removable interpreted-filter chips. Example queries. |
| **Guide** | Per-channel strips of upcoming programmes, now/next + live progress. |
| **Favorites** | Grids of everything you've hearted. |
| **Player** | Refuses MPEG-TS / MKV / rtmp up front with a plain explanation. 25s load timeout. Always a Close button. |
| **Autoplay next episode** | Finishing an episode records it watched and rolls to the next. Toggle in Personalize. |
| **Series Resume button** | Series detail jumps to your in-progress episode and shows "Resume S2E4" at the top. |
| **AI toggle now persists** | `aiAssistedSearch` preference, wired through `applyPreferences()`. Preferences decode leniently — new fields never wipe saved settings. |
| **Accessibility** | VoiceOver labels on sidebar, guide cells, filter chips, search examples. |

## App Store assets (docs/, host via GitHub Pages → `/docs`)

- `privacy-policy.html`, `support.html`, `index.html` — replace
  `REPLACE_WITH_SUPPORT_EMAIL` first.
- `app-store-listing.md` — **name candidates ("SexyPlayer" won't pass review)**,
  subtitle, description, keywords, age rating, App Privacy answers, and
  ready-to-paste App Review notes pointing the reviewer at the Demo Library.
- `LAUNCH.md` — the full checklist.

## Test in this order tomorrow

1. **It builds.** Errors → send them.
2. Onboarding → **Xtream** → connects? checklist progresses? into the app (button
   after 12s at worst)?
3. Sidebar focus feels OK; every section opens; you can always reach Settings.
4. A **movie** → Play. A **live channel** → note "not supported" (MPEG-TS) vs plays.
5. **Search** — the examples + your own phrasings.
6. **Guide** — do your channels show programmes?
7. Kill + relaunch → fast from cache, no flash.
8. `Try the demo` from onboarding — the reviewer's path; make sure it's flawless.

## Still not done (LAUNCH.md has the rest)

Reminders · Claude-backed search (needs API-key decision) · metadata enrichment ·
Top Shelf extension · perf validation at 20k+ items · Apple Developer Program
(you — 48h lead) · real-data testing (you).
