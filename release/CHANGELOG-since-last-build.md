# Changes since your last verified build

Your last green build was **hand-off A** (the SQLite foundation, additive).
Since then:

## The switch-over — hand-off B  ·  read `release/HANDOFF-database-B.md`

The app now runs entirely on the SQLite catalog store. `CatalogCache` (the old
binary-plist cache) is **deleted**. `AppEnvironment` opens the database, imports
through the streaming `CatalogWriter`, and every screen queries through
`SQLiteCatalogRepository`.

**Behaviour changes on device:**
- first launch does one full re-import (old cache format is gone), then every
  launch is instant
- import memory stays flat regardless of library size — this is the crash fix
- Home / browse / search / guide run off bounded queries, not the whole catalog

New files: none. Deleted: `Sources/Data/Cache/CatalogCache.swift`,
`Tests/AeriaTests/CatalogCacheTests.swift`. `xcodegen generate` still recommended.

## Language pickers

Personalize (and Settings → Personalize) now always offer the common European
languages for audio and subtitles — before, a Swedish-heavy library only showed
"Swedish". Merged with whatever the library scan detected.

## Build risk

- Concurrency around `AppEnvironment.bootstrap` / `handleImportStage` (a
  `@MainActor` class driving two actors — `CatalogDatabase` and `CatalogWriter`).
- The `HomeViewModel.performRebuild` rewrite.

Both were written without a compiler. Send any red `⌘B` output.
