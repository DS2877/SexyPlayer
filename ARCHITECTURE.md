# Architecture

## Guiding principle

The IPTV source is **input**. The product is the **experience**. Every layer
below the UI exists to turn inconsistent, provider-specific data into a clean,
strongly-typed domain the UI can present like a premium streaming service.

The UI never knows whether data came from M3U, Xtream, or a mock.

---

## Layered data flow

```
 ProviderCredentials  ────────────────►  Keychain (never logged, never sent anywhere
        │                                 except the provider's own server)
        ▼
 ProviderClient  (protocol)
   ├─ MockProviderClient        ← M0
   ├─ M3UProviderClient         ← M6
   └─ XtreamProviderClient      ← M6
        │  returns provider-shaped DTOs
        ▼
 RawCatalog   { RawChannel, RawVODItem, RawSeriesItem, RawEPGEvent }
        │
        ▼
 Normalizer   (pure functions — no UI, no network, fully unit-tested)
   ├─ TitleNormalizer     "SE | TV4 HD [1080p]"  → "TV4"
   ├─ LanguageDetector    name/group             → audio + subtitle languages
   ├─ QualityDetector     "... 4K", "... FHD"    → VideoQuality
   └─ EpisodeParser       "Show S02E05"          → (season 2, episode 5, "Show")
        │
        ▼
 Catalog   { Channel, Movie, Series/Season/Episode, EPGEvent }   ← domain models, value types, Sendable
        │
        ▼
 CatalogRepository   (protocol)
   ├─ InMemoryCatalogRepository   ← M0
   └─ SQLiteCatalogRepository     ← M1  (GRDB + FTS5 index)
        │  paginated, indexed queries — never materialises whole tables
        ▼
 Features (SwiftUI)   Home · LiveTV · Guide · Movies · Series · Search · Player · Settings · Setup
        │
        ▼
 UI/DesignSystem  +  UI/Components  +  Focus + Navigation
```

Adding a provider = one new `ProviderClient` + its adapter into `RawCatalog`.
Nothing above the normalization layer changes.

---

## Video playback (M5)

- **`AVPlayer` + `AVPlayerViewController`** — the native tvOS player. Gives the
  system transport bar, scrubbing with the Siri Remote, the Info panel,
  subtitle/audio pickers, and Now Playing integration for free.
- Wrapped behind a **`PlaybackEngine` protocol** so an alternative engine
  (e.g. VLCKit) can be added later without touching feature code.
- Custom UI limited to a **channel-zap strip** and a **now/next EPG badge**,
  injected via `AVPlayerViewController`'s official overlay / custom-menu hooks —
  the player itself is never rebuilt.
- **Resume**: persist `{ itemID, positionSeconds, updatedAt }`; seek on load.
  Live streams excluded.
- **Known risk**: `AVPlayer` plays **HLS** (`.m3u8`) natively and well. Many
  IPTV *live* streams are raw **MPEG-TS** (`.ts`), which `AVPlayer` handles
  poorly. Plan: HLS-first, detect unsupported streams and show a clear message;
  add a VLCKit fallback engine only if the user's real source needs it.
- No DRM/FairPlay in v1. PiP does not exist on tvOS.

---

## AI / natural-language search (M4)

Not a chatbot. The AI only ever produces **structured constraints**, never
content — so it cannot hallucinate a title.

```
 "scary movie with swedish subs, under 2 hours"
        │
        ▼
 AIQueryParser  (protocol)
   ├─ DeterministicQueryParser   on-device, zero network, zero cost.
   │                             Synonym/regex maps handle a large share of queries.
   └─ ClaudeQueryParser          for fuzzy queries ("something like Game of Thrones").
        │                        Sends: the query string + a compact list of the
        │                        library's available genres / languages / kinds.
        │                        Never sends: credentials, stream URLs, library contents,
        │                        personal data, watch history.
        ▼
 SearchIntent  { kinds, genres, audioLanguages, subtitleLanguages,
                 minYear, maxYear, maxDurationMinutes, freeText, sort }
        │
        ▼
 SearchEngine   runs the intent against the local Catalog / FTS index, ranks results
        │
        ▼
 Ranked [SearchResult]   +  interpreted filter chips the user can edit
```

- Single **`AIService`** boundary. A Settings toggle disables the AI tier
  entirely (falls back to the deterministic parser).
- Provider is swappable. Default: **Claude Haiku** — cheap, fast, strong at
  strict-JSON output.
- **Production**: an API key must not ship in an app binary. Real release needs
  a thin backend proxy. Early development: key pasted into Settings, stored in
  Keychain. Tracked as an open decision.
- Unit tests mock the AI — never call a live model.

---

## Handling large libraries (10k+ channels, 50k+ movies)

| Concern | Approach |
|---|---|
| Import | Off the main thread on a background actor; large Xtream JSON decoded in batches to avoid memory spikes. |
| Storage | SQLite via **GRDB** (M1). Proven at this scale. |
| Search | SQLite **FTS5** virtual table over normalized titles + tags — sub-millisecond over 50k rows. |
| Lists | `LazyVGrid` / `LazyHStack` + **paginated** repository queries (keyset). Whole arrays never materialised. |
| Artwork | Custom async image loader, disk + memory cache, **downsampled to display size** (ImageIO) — critical for tvOS memory limits. |
| EPG | Events indexed by `(channelID, startTime)`; the guide queries only the visible channel × time window. |
| Refresh | Re-import **diffs** against existing rows using stable IDs (hash of provider + provider's own id) so favourites / progress survive. |

---

## State & concurrency

- `async / await` + structured concurrency. Actors for the import/normalization
  pipeline.
- `@Observable` (Observation framework) for view-model state; `@MainActor` on
  everything UI-facing.
- Dependency container: `AppEnvironment` (`@Observable @MainActor`), injected
  via `.environment(...)`.
- No Combine unless a specific API forces it. No third-party state libraries.
- Value types + `Sendable` throughout the domain. Code is written Swift-6
  strict-concurrency-clean; the language-mode flag flips in a later milestone
  once the Mac build loop is running.

---

## Security & privacy

- IPTV credentials → **Keychain** only.
- Logs are sanitised: no passwords, tokens, Xtream credentials, or raw private
  stream URLs ever written.
- No analytics SDK, no ad SDK, no third-party SDKs beyond GRDB (and later a
  minimal AI client).
- Provider URLs and credentials treated as sensitive everywhere.

---

## Module map

```
App/       SexyPlayerApp (@main) · AppEnvironment (DI) · RootView (tab navigation)
Core/      AppLogger · small pure utilities
Domain/    Models/ · Providers/ (ProviderClient, RawCatalog, ProviderError) · Search/ (contracts)
Data/      Normalization/ · Mock/ · Repositories/
AI/        AIQueryParser · DeterministicQueryParser · AIService
UI/
  DesignSystem/  Theme · Palette · Typography · Spacing · FocusStyle
  Components/     PosterCard · ChannelCard · Shelf · HeroBanner · FilterChip ·
                  SectionHeader · SkeletonView · EmptyStateView · ErrorStateView
  Features/       Home/ (HomeView, HomeViewModel) · … (added per milestone)
Tests/
  SexyPlayerTests/  normalization · parsing · search-intent · search-engine
```

---

## Open decisions (revisit before the relevant milestone)

1. **AI key delivery** — backend proxy vs user-supplied key. Needed by M4.
2. **MPEG-TS fallback** — whether to bundle VLCKit. Decide after testing the
   user's real source in M5/M6.
3. **Metadata enrichment** (TMDB etc.) — clean seam is reserved; not a v1
   dependency. Decide post-M6.
4. **App Store review** — reviewers need a working source. Likely ship a
   bundled mock/demo provider for review. Confirm against current guidelines
   before submission.
