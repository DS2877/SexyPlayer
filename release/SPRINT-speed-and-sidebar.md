# Sprint — the "way too slow" + "not premium sidebar" pass

You reported, from the TestFlight beta:

1. **Loading is still way too slow.**
2. **The left menu still doesn't feel premium.**
3. Everything else is good.

Plus a product decision: **focus is Sweden / Europe** — drop Arabic, African,
Russian (and Asian / Latin-American) content *unless it has English or Swedish
audio or subtitles*.

This document is the full audit, what I changed this session, the exact build
steps, and the backlog of everything I found but didn't do.

---

## 1. Why loading was slow — root causes

I read the whole catalog store, the import pipeline, the bootstrap path, the Home
model and the browse models. The launch-speed work from the last sprint (snapshot
paint, two-phase Home, section-model reuse) was sound. The remaining slowness was
**below** that, in the SQLite store and the import:

| # | Cause | Impact |
|---|---|---|
| A | **No index supported the region / adult filter.** Every browse, count, shelf and A–Z query was `WHERE is_relevant = 1 AND is_adult = 0 ORDER BY <indexed col>` — but `is_relevant` / `is_adult` were never indexed. On a big provider where 70–90 % of the dump is foreign, SQLite walked 5–10× the rows it displayed. Counts were full-table scans. | **The big one.** Every screen. |
| B | The filter was written as `(? OR is_adult = 0) AND (? OR is_relevant = 1)` with bound parameters, which SQLite **cannot** turn into an index seek even when an index exists. | Blocks the fix for A. |
| C | **`RelevanceFilter.isRelevant` ran ~80 regex `\b marker \b` scans per row** with no detected country — at import, for every channel / movie / series. A 100k-item provider = up to 8 million regex evaluations on the import thread. | Cold-start / first-launch import. |
| D | **The A–Z rail read every matching title** in sort order across the SQLite→Swift boundary (tens of thousands of strings) just to compute ~30 letter positions, on every filter / sort change. | Movies / Series / Live TV, "lands a beat later". |
| E | **`presentLanguages` did two full-table scans** (`movie` ∪ `series`) on every launch (search vocabulary) and every browse-facet refresh. `presentGenres` / `channelCategories` similar. | Every launch. |
| F | `searchVocabulary` used `SELECT count(*)` on three whole tables just to ask "are there any movies?". | Every launch. |
| G | `similarMovies` / `similarSeries` computed a correlated `shared`-genre count for **every visible row**, then filtered `shared > 0`. | "More Like This" on every detail screen. |
| H | The warm-launch fast path `await`ed the **full** `applyPreferences()` (which can rewrite a whole channel column) before flipping the app interactive. | Warm launch, first frame. |

The sidebar's "not premium" is separate — see §3.

---

## 2. What I changed this session

All changes are on `import-progress-checklist`, surgical, and covered by
tests where a test exists for that surface. **The schema version bumped (v2 → v3),
so every existing install re-imports once on first launch after this** — that's by
design (the catalog is disposable; the Home snapshot still paints instantly while
it happens).

### Store & import (fixes A–H)

1. **Schema v3 — composite visibility indexes.** New indexes led by
   `(is_relevant, is_adult, …)` on `movie`, `series` and `channel`, one per sort
   order the UI actually uses (added-at, title, year; channel "for you" / name /
   category). The filtered browse and shelf queries now seek straight to the
   visible slice and the `ORDER BY` is a plain index walk — **O(page), not
   O(library)**. `Sources/Data/Persistence/CatalogSchema.swift`.

2. **Plain-equality filter predicate.** `scopeClause` now emits `is_relevant = 1
   AND is_adult = 0` (only the parts the scope needs) instead of the
   `(? OR …)` form, so SQLite can use the indexes from (1).
   `Sources/Data/Persistence/CatalogDatabase.swift`.

3. **`RelevanceFilter` rewrite** (`Sources/Data/Normalization/RelevanceFilter.swift`):
   - **Europe is now kept.** `keptRegions` = Nordic + English-speaking + a
     continental-Europe set (Germany, France, Spain, Italy, Poland, Greece, the
     Baltics, the Balkans, …). **Russia and Belarus are excluded**; Turkey is
     treated as non-European.
   - **Language escape hatch.** Anything with **English or Nordic audio *or*
     subtitles** is kept no matter where it's from — this is your "unless it has
     english or swedish speak and text" rule. *(I read "and" as "either" — an
     item you can hear *or* read in English/Swedish stays. Say the word if you
     want it stricter — both audio *and* subtitles required.)*
   - **~80 regex scans → one set-membership test.** The no-country fallback now
     tokenises the name+category once and does a single `Set.isDisjoint` against
     the foreign-marker set. The marker list was pruned to genuinely-unwanted
     regions (MENA, Sub-Saharan Africa, Russia, South/East Asia, Latin America).
   - Audio/subtitle languages are now threaded into the per-row relevance check
     at insert (`insertChannels` / `insertMovies` / `insertSeries`).

4. **Facet cache.** The distinct genre / language / channel-category sets are
   computed **once** at the end of an import (`refreshFacetCache`) and stored in
   `meta`. `presentGenres` / `presentLanguages` / `channelCategories` read the
   cache and only fall back to a scan if it's missing. Kills fix E's scans from
   the launch path.

5. **`searchVocabulary` uses `EXISTS`** (`SELECT EXISTS(SELECT 1 FROM movie)`)
   instead of three full counts. Fix F.

6. **A–Z anchors computed in SQL.** A `row_number()` window over the same order
   the grid pages, grouped to first letter — **~30 `(letter, index)` rows cross
   the boundary instead of every title.** `movieTitleAnchors` /
   `seriesTitleAnchors` / `channelNameAnchors` on `CatalogDatabase`; the old
   `*TitlesInOrder` methods and the dead `SQLiteCatalogRepository.anchors` are
   gone. Fix D.

7. **`similarMovies` / `similarSeries` restrict candidates first** — `AND id IN
   (SELECT … FROM <genre table> WHERE genre IN (…))` before the `shared` count,
   so the correlated subquery runs over the genre-matching handful, not the whole
   library. Fix G.

8. **Warm launch stops blocking on `applyPreferences`.** The fast path now sets
   just the two scope booleans (in-memory, instant) before flipping the app
   interactive; the full `applyPreferences()` (region-priority rewrite, recent
   channels, API keys) runs behind the first frame. Fix H.
   `Sources/App/AppEnvironment.swift`.

### The sidebar (`Sources/UI/Navigation/SidebarShell.swift`) — full rewrite

**The premium move: the rail collapses to icons while you're in the content and
expands with labels, *over* the content, the moment focus returns to it** — the
Apple TV app pattern. The content keeps a permanent narrow gutter and the rail
draws over it when it expands, so **the content never reflows**.

- Collapsed: a 116-pt icon rail with a soft leading scrim (not a panel).
- Expanded (rail has focus, or you press Menu from a section): 300 pt, labels
  fade in, a solid floating panel with a drop shadow over the content.
- Animated with the app's standard `Metrics.focusAnimation` spring.

**Plus: visited screens stay mounted.** Instead of a `switch` that tears the
screen down on every section change, the content is a `ZStack` of the sections
you've opened, the current one on top. Switching sections is now genuinely
instant *and keeps scroll position and focus* — you land back exactly where you
were. (Guarded: during a cold import only the selected screen is mounted, so the
import isn't shaping several off-screen screens at once.)

- Menu behaviour unchanged: Menu from a section root → focus the rail; Menu from
  Home → backgrounds the app; Menu from a pushed detail screen → pops.
- Focus-driven switching kept (the Apple TV app does this) — it's cheap now.

### Tests

Updated: `RelevanceFilterTests` (Europe kept, escape-hatch cases),
`CatalogDatabaseTests` (region scope now uses a non-European Arabic-only fixture;
anchors via the new SQL path). Added: `testTitleAnchorsAddressTheSameOrderTheGridPages`,
`testRefreshFacetCacheServesFacetsWithoutARescan`.

---

## 3. Build & test — exact steps

No new source or test files this time — only edits to existing ones — so
`xcodegen generate` isn't strictly required. Run it anyway; it's harmless and
removes all doubt.

```bash
cd ~/Developer/SexyPlayer
```

```bash
git pull
```

```bash
xcodegen generate
```

```bash
open Aeria.xcodeproj
```

In Xcode:

1. **⇧⌘K** (Clean Build Folder)
2. **⌘B** (Build). If it fails, copy the **red** error text (with the file name)
   back to me.
3. **⌘U** (run the test suite). Expected: all green. If a test fails, copy its
   name and the assertion message back.
4. Pick your **Apple TV** in the device menu, then **⌘R**.

If the build is green, paste me: *"builds, tests green"* and then walk §4.

---

## 4. What to check on the device

Ordered by how likely something is wrong.

### The sidebar (the riskiest change)

- **Land in the app** → the rail is open (icons + labels), focus on Home.
- **Press → into the content** → the rail smoothly collapses to icons.
- **Press ← / Menu from a section** → the rail expands again, over the content,
  and the content **doesn't shift**.
- **Scroll the rail up and down** → the content follows each item; no frame
  flicker, no long reload.
- **⚠️ Focus containment:** on Home, press **up / down / left / right hard and
  fast**, and hold each direction. Focus must **never** jump to an invisible
  screen (a Movies poster, a Settings row) that isn't the one on screen. If it
  ever does — tell me exactly which keys and from where; the fix is one line.
- Home → Movies → scroll halfway down → Live TV → back to Movies → **you're
  exactly where you left off** (same scroll position, same focused poster).
- Menu from **Movies / Search / Guide** → focus returns to the rail.
- Menu from **Home** → the app backgrounds (unchanged).
- Open a movie, press Menu → back to the grid where you left it.
- Top Shelf deep link (background the app from a Continue-Watching item, reopen
  from the tvOS home row) → lands on the detail screen, rail on Home.

### Loading speed

- **Kill and relaunch** → Home is populated before the animation finishes (same
  as before — snapshot paint).
- **Movies / Series / Live TV** → the first grid is up fast; the count and the
  **A–Z rail** (switch sort to "A–Z") appear a beat later but noticeably quicker
  than before, even on the big provider.
- Sort Movies by **A–Z**, jump to "S", "T" → it scrolls to roughly the right
  place (anchor positions line up with the grid).
- Open a movie → **More Like This** fills in quickly.
- **First launch after this update**: the library re-imports once (schema bump).
  You'll see "Importing your library…" while Home shows the cached screen. This
  is expected and only happens once.

### Regional filter

- After the re-import, browse **Live TV** and **Movies**: the Arabic / Turkish /
  Indian / Russian / African / Latin-American bulk should be **gone**.
- **Kept:** anything German / French / Spanish / Italian / Polish / Greek / Nordic
  / UK, and anything (wherever it's from) tagged with English or Swedish
  audio/subs (e.g. "TR | Movie (EngSub)").
- Settings → toggle **"Limit to relevant regions"** off → the foreign content
  reappears (it's still in the store, just hidden). Toggle back on.
- If something you *want* is missing, or something you *don't* want is still
  there, note the channel/movie name + its category label — that tunes the
  marker list.

---

## 5. The backlog — everything else I found

Prioritised. None of this is done yet. `[S]` = small / low-risk, `[M]` = medium,
`[L]` = large.

### Performance

- **`[M]` Drop foreign rows at import instead of flagging them.** Right now every
  row of a 150k-item dump is inserted and just marked `is_relevant = 0`. If the
  region filter instead *skipped* them, the database would be a fraction of the
  size — smaller indexes, faster everything, less disk. Cost: the "show all
  regions" toggle would need a re-import instead of being instant. For a
  Nordic/Europe product that's probably the right trade.
- **`[M]` Precompute the genre-shelf tallies** (`genreCounts`) into `meta` at
  import, like the facet cache — it's a double `GROUP BY` join on every Home full
  rebuild.
- **`[S]` `artworkSeeds` ordering** uses `(added_at IS NULL), added_at DESC`
  which defeats the `movie_added_at` index. Add a partial index
  `WHERE added_at IS NOT NULL` or store a precomputed `recent_rank`.
- **`[M]` The import still normalises then inserts in 2 000-row chunks on one
  writer connection.** Consider a second bulk-load path: `PRAGMA journal_mode =
  OFF` + one big transaction for the *initial* cold import (it's disposable and
  re-run on failure anyway), then switch to WAL for incremental refreshes.
- **`[S]` `EPGWindow` / `insertEPG`** drops events outside the window at insert —
  good — but the guide still pulls an 8-hour window per channel-page. Cache the
  "now/next" per channel in a column updated on a timer.
- **`[M]` Image decode** is size-aware now, but `CachedImage` still decodes on
  the main actor path for cache misses. Move the `CGImageSourceCreateThumbnail`
  call fully onto a `DispatchQueue` / `Task.detached` and hand back a
  ready-to-draw `CGImage`.
- **`[S]` `WatchProgressStore` / `FavoritesStore` / `ChannelHistoryStore`** each
  JSON-encode the whole list to `UserDefaults` on every write. Fine at current
  sizes; move to the SQLite store (a `user_state` table) if history grows.

### Sidebar / navigation polish

- **`[S]` Debounce focus→selection by ~120 ms** if the fast rail-scroll still
  feels like it's "dragging" the content. (Left it immediate — the Apple TV app
  is immediate — but it's a one-liner if you want it.)
- **`[S]` A hairline / gradient separating the expanded rail from the content**,
  and a subtle parallax on the collapse.
- **`[M]` Remember the last section across launches** (`@AppStorage`) so a
  relaunch lands where you were, not always Home.
- **`[M]` The rail could show a tiny "now playing" mini-bar** at the bottom when
  something's playing in PiP-ish state (there's no PiP, but a "resume X" chip).

### UX / product

- **`[M]` "For You" VOD sort** — Movies/Series always sort by recency or title.
  A personalised default (preferred languages, watched genres) would matter more
  than any speed fix for perceived quality.
- **`[M]` 2-D guide grid** — the Guide is a per-channel row list; a proper
  time × channel grid is the expected premium shape.
- **`[S]` Search** — the recent-queries list is there; add "trending in your
  library" (top genres / newest) as chips.
- **`[M]` Reduce the Home rebuild frequency** — it rebuilds on watch-progress,
  metadata revision, preference change, catalog revision, refresh-finished. Some
  of these could patch the affected row in place instead of a full reshape.
- **`[S]` Detail screens** — cast/crew rows, "More Like This" via the TMDB
  recommendations endpoint instead of genre overlap.
- **`[L]` Multi-profile** — one Apple TV, several viewers. Big, post-1.0.

### Correctness / hardening

- **`[S]` `RelevanceFilter` false-negatives to watch:** a legit UK/US channel
  with "India" in the name ("India Today" is real news) is dropped. Consider a
  small allow-list, or trust the country code when present (already does).
- **`[S]` The `:memory:` fallback store** shares one connection — reads block on
  writes there. Acceptable as a last resort; log louder so we know if a user hits
  it.
- **`[S]` `CatalogWriter.finish()` calls `optimize()` with `try?`** — if the
  planner stats never refresh, the new composite indexes might not get picked.
  Worth confirming `PRAGMA optimize` actually runs post-import on device
  (`RuntimeStats` / a log line).
- **`[M]` No test exercises the SQLite store at provider scale** — the perf tests
  all use the in-memory repo. Add a `CatalogDatabase` scale test (50k movies,
  filtered) so an index regression fails CI instead of the Apple TV.

### App Store

- Submission is already in review. If it comes back (IPTV clients draw 4.2 / 5.x
  scrutiny), the responses are drafted in `docs/app-store-listing.md`
  (player-only positioning, "try the demo", the App Group only carries a local
  Continue-Watching list, why `NSAllowsArbitraryLoads`).
- This build is a strong TestFlight update to push *before* the review verdict —
  it directly addresses the two things that would sink it (speed + the nav feel).

---

## 6. If the build breaks

Most likely spots, in order:

1. **`SidebarShell.swift`** — the `ZStack` keep-alive content, `.defaultFocus`,
   or the `railExpanded`-driven frames. If SwiftUI complains about the
   `@ViewBuilder` `sectionView` or the `ForEach` `if`, that's where.
2. **`CatalogDatabase.swift`** — the `row_number()` window SQL (string
   interpolation), the `foldAnchors` tuple closure, or a param-count mismatch in
   `similarMovies` / `similarSeries`.
3. **`RelevanceFilter.swift`** — the `split { !$0.isLetter && !$0.isNumber }`
   returning `[Substring]` vs `[String]`.
4. **Tests** — `CatalogDatabaseTests` fixture change (`audio:` / `subs:` params).

Paste the red text with the file name and I'll turn it around fast.
