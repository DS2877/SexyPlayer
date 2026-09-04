# Sprint — the big feature + polish pass (build hand-off)

You asked: *map the whole structure, find every improvement and new function,
execute it.* This is the master hand-off for everything that landed on
`import-progress-checklist` since the last build (`dc13123`).

Two sprints, one build:

1. **Speed + sidebar** (`19264c4`, `6159362`) — the fix for "way too slow" and
   "menu not premium". Deep detail in **`release/SPRINT-speed-and-sidebar.md`**.
2. **Features + polish** (`74ebe29` … `8a079fe`) — 9 commits, covered below.

---

## Build & test — exact steps

**New files this time, so `xcodegen generate` is required:**
`Sources/UI/Features/Browse/GenreGridView.swift`.

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
2. **⌘B** (Build) — if red, copy the error text **with the file name** back to me.
3. **⌘U** (test suite) — expect all green. Copy any failing test name + message.
4. Pick your **Apple TV**, **⌘R**.

Reply *"builds, tests green"* and then walk §4.

**On first launch after this update the library re-imports once** (schema bumped
to v3 in the speed sprint). Home still paints instantly from the cached screen
while it happens. This only happens once.

---

## 1. The codebase, mapped

```
Sources/
  App/            AeriaApp (entry) · RootView (onboarding flow) · AppEnvironment
                  (DI container + top-level state, ~560 lines) · TMDBDefaults
  Core/           HTTPClient · AppLogger · Utilities (Regex, StableHash,
                  StringNormalization, ConcurrentMap, RuntimeStats, LenientCoding)
  Domain/
    Models/       Movie · Series/Season/Episode · Channel · EPGEvent · EPGIndex ·
                  EPGWindow · Catalog · CoreTypes (CatalogID, Language, Genre,
                  VideoQuality, CatalogFreshness) · UserPreferences (+ HomeRowKind) ·
                  UserState (WatchProgress, Favorite)
    Search/       SearchIntent · SearchResult · SearchEngine
    Playback/     PlaybackItem · PlaybackEngine · StreamCompatibility · UpNext
    Providers/    ProviderClient (the one seam) · RawCatalog · ProviderError ·
                  ImportProgress
  Data/
    Providers/    ProviderStore · ProviderConfiguration · KeychainStore ·
                  Xtream/* · M3U/* · XMLTV/*
    Normalization/ Normalizer (orchestrator) · TitleNormalizer · GenreDetector ·
                  LanguageDetector · QualityDetector · AdultContentDetector ·
                  CategoryMapper · EpisodeParser · RelevanceFilter (region gate)
    Persistence/  SQLiteConnection/Statement (raw import SQLite3, no SPM dep) ·
                  CatalogSchema (v3) · CatalogValues (codecs) ·
                  CatalogDatabase (the store: 2 connections, WAL, ~1100 lines)
    Repositories/ CatalogQuerying (protocol) · SQLiteCatalogRepository (ships) ·
                  InMemoryCatalogRepository (test double) · CatalogRepository
                  (shared value types: CatalogFilter, BrowseAnchor, BrowseSort…)
    Import/       CatalogWriter (streams a provider import in ~2k-row chunks)
    Metadata/     TMDBClient · MetadataService (actor: dedup, rate-limit, disk cache)
    Stores/       WatchProgressStore · FavoritesStore · ChannelHistoryStore ·
                  PreferencesStore · ParentalControlsStore · NetworkMonitor
    Mock/         MockCatalogData · MockProviderClient (the Demo Library)
  AI/             AIService (the privacy boundary) · DeterministicQueryParser ·
                  ClaudeQueryParser · AIQueryParser
  UI/
    DesignSystem/ Metrics · Palette · Theme · RowButtonStyle (+ Primary/Secondary CTA)
    Navigation/   SidebarShell (collapsing rail + keep-alive panels) ·
                  SectionModels (per-section VM lifetime) · AppRoute
    Components/   PosterCard · ChannelCard · Shelf · SectionHeader · HeroBanner ·
                  ArtworkView/GeneratedArtwork · ImageCache (2-tier, size-aware) ·
                  StateViews (skeletons, empty/error) · FilterChip · FilterSheet ·
                  QualityBadge · Wordmark · PINPadView · LibraryLoadingPlaceholder
    Features/
      Home/       HomeView · HomeViewModel (two-phase rebuild) · HomeModels ·
                  HomeSnapshotStore (instant-paint cache)
      Browse/     VODBrowseView(Model) · LiveTVBrowseView(Model) · GenreGridView (new) ·
                  BrowseModels
      Guide/      GuideView (+ GuideViewModel)
      Search/     SearchView · SearchViewModel
      Detail/     Movie/Series/ChannelDetailView · DetailScaffold · DetailExtras
                  (CastRail, RelatedRail)
      Player/     PlayerScreen (+ SystemPlayerView) · PlayerModel (AVPlayer) ·
                  VLCPlayerModel/Screen (MKV/TS) · ChannelZapping
      Favorites/  FavoritesView
      History/    HistoryView
      Settings/   SettingsView · AIKeyView · TMDBKeyView
      Setup/      ProviderSetupView · PersonalizeView
  TopShelf/       TopShelfPayload · ContentProvider (the tvOS extension)
Tests/AeriaTests/ ~34 files
```

**Data flow:** `ProviderClient.fetchStaged` → `CatalogWriter` (normalise +
chunk-insert) → `CatalogDatabase` (SQLite) → `SQLiteCatalogRepository` (owns the
adult/region scope) → view models → SwiftUI. Durable user state
(favourites, watch progress, channel history, preferences) is JSON in
`UserDefaults`, never in the catalog DB (which is disposable and re-importable).

**The architecture is clean and mature.** Nothing below is a rewrite — every
change is additive or a contained swap.

---

## 2. What I changed this session — features & polish

### `74ebe29` · NEW badge
Titles the provider added in the last 12 days get a **NEW** pill on their poster
(gone once you start watching). `CatalogFreshness.isNew()` is the one rule;
`HomeCard`/`BrowseCard` carry the flag. Home-snapshot bumped to v2.

### `4279dd3` · "My List" Home row
A row of your favourited movies + series, in the order you hearted them, floated
just under Continue Watching. Resolved in Home's fast pass (two id-batch
lookups). Rebuilds when you heart/unheart anything while Home is on screen.

### `f46782d` · Series detail depth
- Header: **"N of M episodes watched"** + a progress bar, once you've finished one.
- Every episode row: a context-menu **Mark as Watched / Unwatched**.
- **"Mark season watched"** button (toggles the whole visible season).
- New batched `AppEnvironment.markEpisodesWatched/Unwatched(_:)`.

### `858cac3` · Search — "New to your library"
The empty search screen leads with a poster grid of recent additions (best-rated
first), above the recent-queries and prompts. Results / trending are their own
focus sections; submitting a query drops keyboard focus onto the results.

### `056f866` · Surprise Me
A **Surprise Me** button in the Movies and Series headers opens a random title
that matches whatever filter is active. New `randomMovie/randomSeries` on
`CatalogQuerying` (`ORDER BY random() LIMIT 1` over the scoped, filtered set).

### `5ab1266` · Polish grab-bag
- **RelevanceFilter**: dropped the ambiguous bare country nouns (`india`,
  `africa`, `china`, `japan`, `korea`, `iran`, `turk`, `thai`, `latin/mexico`)
  that caught English titles like *India Today* / *Out of Africa*; kept the
  unambiguous language / network markers.
- **Filter genre chips** now lead with the genres the library has most of (the
  facet cache stores them count-ordered).
- **"More Like This"** falls back to fresh arrivals when a title has no genre tags.
- **History**: tapping an in-progress row **resumes it**; press-and-hold for
  *Go to* / *Remove*.

### `aac8b9e` · Sleep timer
A **Sleep Timer** menu in the AVPlayer transport bar (15/30/45/60 min / Off).
For the VLC player it's a section in the "▲ options" sheet, which now opens for
any VOD stream, not only ones with multiple tracks. When it elapses the player
pauses and the screen closes. Live streams don't offer it.

### `74536d5` · Play Continue Watching straight from Home
Tapping a Continue Watching card now **resumes playback** where you left off
instead of opening the detail screen first (the Apple TV / Netflix behaviour).
*Go to <title>* moved into the card's context menu.

### `8a079fe` · "See all" a genre
Each Home genre shelf header is now a **"Genre ›" link** into a full grid of
every film and show tagged with that genre (newest first, paginated). New
`AppRoute.genre(Genre)` + `GenreGridView`, resolved through the ambient
`NavigationStack`.

### `78bbf22` · harden — review pass on the above.

---

## 3. Tests

New / updated: `HomeViewModelTests` (My List row), `CatalogDatabaseTests`
(`randomMovie` stays in scope; region-scoped queries; facet cache),
`RelevanceFilterTests` (Europe kept + language escape hatch, from the speed
sprint). All existing tests still compile — the `makeContent` signature stayed
back-compatible (new params defaulted), and `HomeRowKind.myList` slots into
`defaultEnabled` without breaking the coding tests.

---

## 4. What to check on the device

Ordered by risk.

### Sidebar (from the speed sprint — highest risk)
- Land in the app → rail open. Press → into content → it collapses to icons.
  Press ← / Menu → it expands over the content, content doesn't shift.
- **⚠️ Focus containment:** on Home, hammer up/down/left/right. Focus must never
  jump to an invisible section. If it does — tell me the keys and from where.
- Home → Movies → scroll down → Live TV → back to Movies → you're where you left
  off.

### New features
- **NEW badge** — after the re-import, recent additions show a blue NEW pill;
  it's gone on anything you've started.
- **Home → "My List"** — heart a couple of films, go to Home → the row is there,
  in heart order, under Continue Watching.
- **Continue Watching** — tap a card → it *plays* from where you left off (not
  the detail screen). Press-and-hold → Go to / Mark Watched / Remove.
- **Home genre shelf** → focus the "Action ›" header, click → full genre grid;
  tap a poster → detail; Menu back twice → Home.
- **Series detail** — open a show, watch an episode part-way, come back →
  header shows "1 of N episodes watched". Press-and-hold an episode → Mark as
  Watched. "Mark season watched" button toggles the season.
- **Movies / Series header** → **Surprise Me** opens a random title. Set a genre
  filter first → Surprise Me stays in that genre.
- **Search** (empty) → "New to your library" grid on top. Submit a query → focus
  lands on the results, not back in the field.
- **Player → Sleep Timer** — start a film, open the transport bar (swipe down),
  the "Sleep Timer" menu is there. Pick 15 min (or wait) → it should pause +
  close when it fires. On an MKV (VLC): press **up** → the options sheet has a
  Sleep timer section. On a **live** channel: no sleep option (correct).
- **History** → tap an in-progress row → it resumes. Press-and-hold → Go to /
  Remove.

### Regional filter (from the speed sprint)
- Browse **Live TV** / **Movies**: Arabic / Turkish / Indian / Russian / African
  / Latin-American bulk should be gone. German / French / Spanish / Italian /
  Polish / Greek / Nordic / UK kept, plus anything with English or Swedish
  audio/subs wherever it's from.
- If something you want is missing or something unwanted is still there, note the
  name + its category label.

---

## 5. The backlog — everything found, not yet done

Prioritised. `[S]`/`[M]`/`[L]` = effort.

### Performance
- **`[M]` Drop foreign rows at import** instead of flagging them `is_relevant=0`.
  A 150k-item dump that's 80% foreign would become a fraction of the size —
  smaller indexes, faster everything. Cost: the "show all regions" toggle needs
  a re-import instead of being instant. Right trade for a Europe-focused product.
- **`[M]` Precompute the Home genre-shelf tallies** into `meta` like the facet
  cache — `genreCounts` is a double `GROUP BY` join on every Home full rebuild.
- **`[S]` `artworkSeeds` ordering** (`(added_at IS NULL), added_at DESC`) defeats
  the `movie_added_at` index — add a partial index or a `recent_rank` column.
- **`[M]` Cold-import fast path** — `PRAGMA journal_mode=OFF` + one big
  transaction for the *initial* import (disposable, re-run on failure), then WAL
  for incremental refreshes.
- **`[M]` Home rebuild frequency** — it re-shapes on watch-progress, metadata
  revision, preference change, catalog revision, refresh-finished, favourites.
  Some of these could patch the affected row in place.
- **`[S]` A `CatalogDatabase` scale test** (50k rows, region-scoped) so an index
  regression fails CI, not the Apple TV. The perf tests all use the in-memory repo.

### Features
- **`[M]` "For You" VOD sort** — Movies/Series always sort by recency or title. A
  personalised default (preferred languages + watched genres) matters more than
  any speed fix for perceived quality.
- **`[L]` 2-D guide grid** — the Guide is a per-channel row list; a proper
  time × channel timeline is the expected premium shape.
- **`[M]` Live TV "Favorites" filter** — a "★" chip in the category row showing
  only favourited channels.
- **`[M]` Playback speed** — AVPlayerViewController on tvOS 16+ has a native
  `speeds` property; one line to enable custom speeds. VLC has `player.rate`.
- **`[M]` Remember the last sidebar section** across launches (`@AppStorage`).
- **`[S]` Channel-number chip** on `ChannelCard` (from `Channel.sortIndex`) — IPTV
  users navigate by number.
- **`[S]` "Mark movie watched / unwatched"** context menu on movie cards & detail
  (episodes have it now; movies don't).
- **`[M]` Trailer** — TMDB `/videos` endpoint → a YouTube key. tvOS can't play
  YouTube directly, so this needs a plan (web view or skip).
- **`[L]` Multi-profile** — one Apple TV, several viewers. Post-1.0.
- **`[S]` "Because you watched" for series** — the row exists for the newest
  played title; it could rotate through a few anchors.

### UX / polish
- **`[S]` Search** — add "trending" ranked by TMDB rating properly (it currently
  ranks recent additions by whatever rating is cached).
- **`[S]` Detail "From Start"** for episodes is there; movies get it too — good.
  Consider a "Watched" toggle on the movie detail actions row.
- **`[S]` Empty states** — a few still say "your provider didn't return any X";
  could offer "Switch to the Demo Library" as an action.
- **`[M]` Genre shelf header focus** — the "See all" link is a new focus stop
  above each genre shelf's cards. Watch it feels right on device; if the extra
  stop is annoying, gate it behind a long-press instead.
- **`[S]` `SeeAllLinkStyle`** only tints the chevron on focus (the header text
  keeps its explicit white). Fine, but a subtle underline or full tint might read
  better — eyeball it.

### Correctness / hardening
- **`[S]` `RelevanceFilter`** — a legit UK/US channel with a pruned-but-still-
  risky word (e.g. "Persian" in a documentary title) is still dropped when it has
  no country code and no English/Nordic track. Rare; note any real misses.
- **`[S]` `GenreGridView` paging** — loads a page each of movies + series with
  the same page index; ordering is "60 movies, 60 series, 60 movies…". Fine for a
  grid, but a merged sort would be tidier.
- **`[M]` `WatchProgressStore` / `FavoritesStore` → SQLite** — each JSON-encodes
  the whole list to `UserDefaults` on every write. Fine at current sizes; move to
  a `user_state` table if history grows past a few hundred.
- **`[S]` Sleep timer** — the `UIMenu` in `transportBarCustomMenuItems` is the
  one bit of new UIKit surface; if it doesn't render as a submenu on device,
  fall back to 3 flat `UIAction`s (30 / 60 / Off).

### App Store
- Submission is in review. If it bounces (IPTV clients draw 4.2 / 5.x scrutiny),
  responses are drafted in `docs/app-store-listing.md`.
- **This build is a strong TestFlight update to push before the verdict** — it
  directly addresses the two things that would sink it (speed + nav feel) and
  adds enough polish to look like a finished 1.0.

---

## 6. If the build breaks — likely spots, in order

1. **`SidebarShell.swift`** (speed sprint) — the `ZStack` keep-alive content,
   `.defaultFocus`, the `railExpanded` frames.
2. **`GenreGridView.swift`** (new) — the `NavigationLink` + `.buttonStyle(.card)`
   wrapper, or an `env` access in an async view method.
3. **`Shelf.swift`** — the `SeeAllLinkStyle` `ButtonStyle`, or `NavigationLink`
   in a `@ViewBuilder` var.
4. **`PlayerScreen.swift`** — the `UIMenu` / `[UIMenuElement]` in
   `transportBarCustomMenuItems`.
5. **`CatalogDatabase.swift`** — the `row_number()` window SQL (speed sprint),
   the genre-count `conn.query` tuple closure, `randomMovie` param counts.
6. **`RelevanceFilter.swift`** — the `split { }` returning `[Substring]`.

Paste the red text with the file name and I'll turn it around fast.
