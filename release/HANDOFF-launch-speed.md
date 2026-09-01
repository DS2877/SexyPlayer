# Hand-off — the instant launch

Two new files, so **`xcodegen generate` is required**.

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

**⇧⌘K**, **⌘B**, **⌘U**, then **⌘R** on the Apple TV.

---

## What you should feel

**Second launch onward, Home is populated before the app finishes animating in.**
Not a skeleton, not a spinner — the actual hero and the actual shelves, with the
posters already there.

That works because the shaped screen from your last session is cached to disk and
repainted immediately. The live rebuild then runs behind it and swaps in fresh
content a moment later. You should see rows *fill in and improve*, never a blank
screen waiting.

**First launch after this update** still shows the skeleton once — there's no
cached screen yet. Every launch after that is the fast one.

**Movies and Live TV** should now show their first grid of cards almost
immediately. The item count, the A–Z letter rail and the filter chips appear a
beat later. That ordering is deliberate: the A–Z rail has to read every matching
title in sort order, which on your library is far more work than the 60 cards you
can actually see.

### Worth checking specifically

- Launch, kill, launch again → second one should be instantly populated
- **Movies** → cards first, then the count and the A–Z rail appear
- **Live TV** → scroll several pages fast; "on now" text should keep up
- **Home** → let it sit a second; extra shelves (genres, Because You Watched)
  should slide in below the fold without the top of the screen flickering
- Switch provider in Settings → the cached screen must **not** show the old
  library (it's cleared on switch)

---

## What changed, in order of how much it matters

1. **Home snapshot** — `HomeSnapshotStore` caches the shaped screen (a few
   hundred cards of text + artwork URLs, tens of KB) and restores it on launch.
   Same URLs as last time, so the disk image cache serves the posters too.
2. **Two-phase Home rebuild** — a fast pass paints what's above the fold from
   five small queries; a full pass adds the rest. Previously one pass fetched
   500 movies + 200 series + 13 genre queries before anything appeared.
3. **No debounce on the first build** — the 300 ms coalescing delay exists for
   the import storm and was costing every launch a third of a second.
4. **Browse paints page 1 first** — count / A–Z rail / facets moved to a
   background pass.
5. **Live TV batches its EPG** — was one `nowPlaying()` per channel, i.e. 90
   round-trips to the store per page. Now one query per page.
6. **Store-level trims** — a prepared-statement cache (SQL compiled once instead
   of per call), a card projection that stops fetching cast lists / directors /
   stream URLs for grid and shelf rows, and `applyPreferences` no longer
   rewrites a whole channel column on every launch.

Plus: `bootstrap`'s fast path no longer blocks the first frame on building the
search vocabulary and writing the Top Shelf snapshot.

## Build risk

Lower than the last two rounds — no architecture change. Most likely spots:

1. `HomeContent` / `HomeCard` gaining `Codable` (if a field won't synthesise).
2. The statement cache in `SQLiteConnection` (`withStatement`).
3. `HomeView`'s restructured body.

Send any red `⌘B` output with the file name.

## If it's still not instant

Tell me which screen and roughly how long, and whether it's the *first* launch
after updating or a later one. The next levers, in order: cache the browse
screens' first page the same way Home is cached, and precompute the A–Z rail
into a table at import time instead of deriving it per query.
