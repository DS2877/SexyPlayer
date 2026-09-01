# The catalog database — migration plan

**Why:** the in-memory catalog (`Catalog` held whole in RAM, twice, plus indexes,
plus JSON/plist encode peaks during import) jetsams the app on a 4 GB Apple TV
with a real provider. Six rounds of targeted memory trims didn't stop it. The
fix is to stop holding the library in memory at all: normalise → stream into
SQLite in small transactions → answer every screen with a bounded query.

**App Store submission is paused until this lands and verifies on device.**

---

## Design

- **Raw SQLite** (`import SQLite3`, the system library — *no* SPM dependency, so
  nothing new to resolve). A ~200-line typed wrapper (`SQLiteConnection`,
  `SQLiteStatement`, `SQLiteRow`), then everything is plain SQL text.
- **One connection, owned by an `actor`** (`CatalogDatabase`). The actor
  serialises access — no locks, no connection pool, no GCD. WAL mode,
  `synchronous = NORMAL`, 4 MB page cache.
- **Schema:** `channel`, `movie`, `movie_genre`, `series`, `series_genre`,
  `episode`, `epg_event`, `meta`. `title_fold` columns + indices for search and
  the A–Z rails. `is_relevant` and `is_adult` precomputed at import so the
  region / adult toggles are just `WHERE` clauses. Guide window enforced on
  write (`epg_event` only ever holds ±window).
- **Streaming import** (`CatalogWriter`): each staged slice from the provider
  client is normalised and inserted in ~2 000-row transactions, then freed. Peak
  memory is one chunk, flat regardless of library size. `PRAGMA user_version`
  drives migrations; a schema bump wipes and re-imports (the catalog is
  disposable — user state lives in `UserDefaults`, untouched).
- **`CatalogQuerying`** protocol — the paginated read model the feature layer
  already expects. `snapshot()` / `epgIndex()` (whole-catalog returns) are gone;
  in their place, targeted queries + a `homeFeed(...)` that returns just the
  bounded slices the Home screen shapes into rows.

## Delivery — two hand-offs, each a clean Mac build

### Hand-off A — the foundation (this batch)  ·  *additive, nothing else changes*

New files only. The running app still uses `InMemoryCatalogRepository`; the new
code compiles and is exercised by tests, in isolation. If SQLite linking or the
wrapper has a problem, it surfaces here with the app still working.

- `Sources/Data/Persistence/SQLiteConnection.swift`
- `Sources/Data/Persistence/SQLiteStatement.swift`
- `Sources/Data/Persistence/CatalogSchema.swift`
- `Sources/Data/Persistence/CatalogValues.swift`   (domain ⇄ column codecs)
- `Sources/Data/Persistence/CatalogDatabase.swift`
- `Sources/Data/Repositories/SQLiteCatalogRepository.swift`
- `Sources/Data/Import/CatalogWriter.swift`
- `Tests/AeriaTests/CatalogDatabaseTests.swift`
- `project.yml` — `libsqlite3.tbd` added to the `Aeria` target

### Hand-off B — the switch-over

- `AppEnvironment` opens `CatalogDatabase`, imports through `CatalogWriter`,
  queries through `SQLiteCatalogRepository`
- `HomeViewModel` / Search / Guide / Favorites / History / detail screens move
  from `snapshot()` to targeted queries
- `CatalogCache` deleted
- `CatalogQuerying` becomes the one repository protocol; `InMemoryCatalogRepository`
  kept only as the test double

---

## Build risk (no Swift toolchain on the box these were written on)

Lowest-risk points, in order:

1. **`import SQLite3` / linking** — `libsqlite3.tbd` is added to the target.
   If `⌘B` says *"no such module 'SQLite3'"*, the fix is one line in `project.yml`.
2. **`SQLITE_TRANSIENT`** — the standard `unsafeBitCast(-1, …)` idiom; if the
   compiler rejects the literal width, it's a one-liner.
3. Everything else is textbook C SQLite (`prepare` / `bind` / `step` /
   `finalize`) and plain SQL.

Send any red errors from `⌘B` and they'll be fixed fast.
