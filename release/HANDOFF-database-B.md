# Hand-off B — the app now runs on the SQLite store

Hand-off A built for you. This batch **switches the app over** to the catalog
database and deletes the old in-memory cache. This is the one that fixes the
memory crash and the slow load — and the one to test on the Apple TV.

**No new files this time** — `xcodegen generate` is still safest to run, but the
change is edits to existing files plus two deletions.

---

## On the Mac

```bash
cd ~/Developer/SexyPlayer
git pull
```

```bash
xcodegen generate
```

```bash
open Aeria.xcodeproj
```

In Xcode: **⇧⌘K**, **⌘B**. If green, **⌘U** for the tests, then pick the Apple TV
and **⌘R**.

Paste any red build errors (with the file name). The riskiest edits are the
concurrency around `AppEnvironment.bootstrap` and the `HomeViewModel` rewrite.

---

## What to expect on the device

1. **First launch after this update: one full re-import.** The old on-disk cache
   format is gone, so the app rebuilds its catalog from your provider once. Watch
   the **Debug navigator → Memory** gauge during it — it should stay **flat**
   (a few hundred MB, no climb), where before it ran away and got killed.
   The app should become usable the moment the channel list lands, well before
   movies / guide finish.
2. **Every launch after that: basically instant.** The catalog is read straight
   from the database — no decode, no re-import. A background refresh runs only if
   the catalog is more than 6 hours old, and it never blanks the screen.
3. Home, Live TV, Movies, Guide, Search, Favorites, History, and the detail
   screens all now run off bounded queries — they should stay smooth on the big
   provider where they used to stutter.

### Walk this on the device

- **Home** — hero, Continue Watching, Because You Watched, genre shelves, Live Now
- **Live TV** — scroll deep, switch category, A–Z jump, sort toggle
- **Movies** — filter by genre / year, A–Z rail, scroll to load more pages
- **Guide** — channel rows with programmes; open a channel
- **Search** — "scary movies with swedish subtitles", chip removal
- **Favorites / History** — heart a few things, play a bit of something, check both
- **Settings → Personalize** — the language and subtitle lists now show the full
  European set, not just Swedish
- Kill and relaunch — it should come straight up populated

If memory still climbs during the import, tell me the peak figure and the
provider's rough size (channels / movies). Everything else, paste the symptom.

---

## What changed

- **`AppEnvironment`** — opens `CatalogDatabase`; imports through `CatalogWriter`
  (streamed, chunked); queries through `SQLiteCatalogRepository`. Fast path when a
  finished import is already on disk. `CatalogCache` deleted.
- **`HomeViewModel`** — `performRebuild` pulls a bounded working set (newest 500
  movies / 200 series, genre + language shelves, resolved Continue-Watching
  containers) instead of the whole catalog. `makeContent` and its tests are
  unchanged.
- **Search / Guide / Favorites / History / ChannelDetail** — moved from the
  whole-catalog snapshot to targeted queries.
- **`CatalogRepository` protocol retired** — `CatalogQuerying` is the one
  repository protocol now; `InMemoryCatalogRepository` stays as the test double.
- **Personalize** — audio / subtitle pickers always offer the common European
  languages (Nordic + major Western + Arabic/Turkish/Slavic), merged with what
  the library detected.
- Deleted: `Sources/Data/Cache/CatalogCache.swift`,
  `Tests/AeriaTests/CatalogCacheTests.swift`.
