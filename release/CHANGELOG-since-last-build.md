# Changes since your last verified build

Your last green build was **hand-off A** (the SQLite foundation, additive).
Since then — one batch, `release/HANDOFF-database-B.md`:

## The switch-over

The app now runs entirely on the SQLite catalog store. `CatalogCache` (the old
binary-plist cache) is **deleted**. `AppEnvironment` opens the database, imports
through the streaming `CatalogWriter`, and every screen queries through
`SQLiteCatalogRepository`.

## Two-connection store + generation-stamped imports

- `CatalogDatabase` now holds a **writer** connection and a **reader** connection
  (each on its own serial queue). WAL lets the reader answer queries while the
  import commits — browsing stays responsive mid-import.
- Every imported row carries a **generation** number. `finish()` prunes rows an
  earlier generation left behind (provider-removed titles, aged-out EPG), so a
  background refresh never needs a destructive wipe. **Schema is v2** — the store
  rebuilds itself once on first launch.

## Behaviour on device

- first launch: one full re-import (old cache format gone), then instant launches
- import memory stays flat regardless of library size — the crash fix
- Home / browse / search / guide run off bounded queries, not the whole catalog

## Language pickers

Personalize (and Settings → Personalize) now always offer the common European
languages for audio + subtitles — before, a Swedish-heavy library only showed
"Swedish".

## Build risk (no compiler on the dev box)

1. `withCheckedThrowingContinuation` in `CatalogDatabase` — if the newer compiler
   wants `isolation:` / `sending`, one-line fix.
2. `@unchecked Sendable` on `SQLiteConnection` / `CatalogDatabase`.
3. concurrency around `AppEnvironment.bootstrap` / `handleImportStage`.
4. the `HomeViewModel.performRebuild` rewrite.

Send any red `⌘B` output with the file name.

## After this builds + verifies on device

App Store submission is **un-paused**. Follow `release/SUBMIT.md` from the
"Device pass" step.
