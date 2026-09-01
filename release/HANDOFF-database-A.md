# Hand-off A — the catalog database foundation

This is the first of two batches for the SQLite catalog store (see
`DATABASE-MIGRATION.md`). **It is additive** — eight new files plus one line in
`project.yml`. Nothing that runs today is touched, so the app behaves exactly as
your last build. The point of this batch is to prove the new store compiles and
works on your Mac *before* the app is switched over to it in batch B.

**8 new files. `xcodegen generate` is required.**

---

## Do this on the Mac

Open Terminal and paste these four lines one block at a time:

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

In Xcode:

1. Press **⇧⌘K**  (Product → Clean Build Folder)
2. Press **⌘B**  (Product → Build)
3. If the build is green: press **⌘U**  (Product → Test) to run the new
   `CatalogDatabaseTests` along with the rest of the suite.

Then tell me:

- **the build result** — "green" or the exact red error text (copy the whole
  line, and the file name it points at)
- **the test result** — "all passing" or which tests failed and their message

Do **not** run the app on the Apple TV for this batch — there's nothing new to
see there yet. Batch B wires the store into the app; that's the one you'll test
on device.

---

## What changed

| File | What it is |
|---|---|
| `Sources/Data/Persistence/SQLiteConnection.swift` | Typed wrapper over the system `SQLite3` — open, prepare, bind, step, transactions |
| `Sources/Data/Persistence/SQLiteStatement.swift` | Prepared-statement + result-row helpers |
| `Sources/Data/Persistence/CatalogSchema.swift` | The table layout + `user_version` migrations |
| `Sources/Data/Persistence/CatalogValues.swift` | Domain ⇄ column value codecs |
| `Sources/Data/Persistence/CatalogDatabase.swift` | The store: an actor with the whole query + write surface |
| `Sources/Data/Repositories/CatalogQuerying.swift` | The read-model protocol the app will move onto in batch B |
| `Sources/Data/Repositories/SQLiteCatalogRepository.swift` | `CatalogQuerying` over `CatalogDatabase` |
| `Sources/Data/Import/CatalogWriter.swift` | Streams a provider import into the store in small chunks |
| `Tests/AeriaTests/CatalogDatabaseTests.swift` | Round-trip tests for all of the above |
| `project.yml` | one line: `- sdk: libsqlite3.tbd` on the `Aeria` target |

## If the build is red — the likely three, in order

1. **`No such module 'SQLite3'`** — the `libsqlite3.tbd` line in `project.yml`
   didn't take. Tell me and it's a one-line fix (there's an alternative form).
2. **Something about `SQLITE_TRANSIENT` / `unsafeBitCast`** — a known idiom that
   very occasionally needs a width tweak on a new compiler. One-liner.
3. **A Swift concurrency complaint in `SQLiteCatalogRepository`** (an `actor`
   calling an `actor`) — send the exact text; these are usually a small
   annotation.

Everything else in the batch is plain SQL and textbook C SQLite calls.

## What comes next (batch B, after this builds clean)

`AppEnvironment` opens the store and imports through `CatalogWriter`; Home,
Search, Guide, Favorites, History and the detail screens move from the
in-memory catalog to targeted queries; `CatalogCache` is deleted. That's the
batch that fixes the memory crash — and the one you'll verify on the Apple TV
with your real provider and the Memory gauge open.
