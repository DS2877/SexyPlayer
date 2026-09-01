# Hand-off — the instant launch, plus the pre-submission review

This is the last code sprint before the App Store submission. Two batches are
folded together here: the launch-speed work, and a review pass over that work
that found and fixed five defects.

**Three new source files, so `xcodegen generate` is required.**

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

**Second launch onward, Home is populated before the app finishes animating
in** — the real hero and the real shelves, posters already there. The shaped
screen from your last session is cached to disk and repainted immediately, then
the live rebuild swaps in fresh content behind it. Rows should *fill in and
improve*, never a blank screen waiting.

*(First launch after this update still shows the skeleton once — there's no
cached screen yet.)*

**Moving around the sidebar is free.** Previously, scrolling from Home down to
History destroyed and rebuilt seven screens on the way past, each re-running its
queries. Section state now outlives the switch, so a screen you've visited comes
straight back — same scroll position, same focus.

**Movies and Live TV** show their first grid almost immediately; the count, the
A–Z rail and the filter chips land a beat later. Deliberate — the A–Z rail reads
every matching title in sort order, far more work than the 60 cards on screen.

**Scrolling is visibly smoother**, especially Live TV. Posters were decoded at
three times the size they render at and channel logos at nearly four; the memory
cache couldn't hold one screenful, so scrolling back always re-decoded.

**Resuming a film starts almost instantly** instead of pausing on a spinner, and
both players now name what's opening while it buffers.

---

## Test plan for the device

Work down this list — it's ordered by how likely something is to be wrong.

**Launch**
- Launch, kill, launch again → the second one is instantly populated
- First launch after updating shows the skeleton once — that's expected

**Navigation (the riskiest change)**
- Scroll the sidebar top to bottom and back → sections come back as you left
  them, nothing reloads, focus lands where you expect
- Menu from Movies / Search / Guide → focus returns to the sidebar
- Menu from Home → backgrounds the app

**Browse**
- **Movies** → cards first, then the count and A–Z rail appear
- Open a title, press Menu → grid and focus exactly where you left them
- Filter by genre, clear it, change sort → each settles without flicker
- **Live TV** → scroll several pages fast; logos and "on now" keep up
- **Series** → same as Movies

**Home**
- Let it sit a second → genre / Because-You-Watched shelves slide in below the
  fold without the top flickering
- Play something, press Menu back to Home → Continue Watching updates
- Browse into a title and straight back out → Home does *not* re-shape

**Player**
- Resume a part-watched film → picks up near where you left off, fast
- Start any stream → you see the title while it buffers, not a bare spinner
- On a live channel: open the transport bar → Channels → the list shows "on now"
  for the visible rows at once, not trickling in

**Favorites / History**
- Heart something on a detail screen, press Menu → the list updates
- Go into a title and straight back out → the list does *not* move

**Provider switching (the fix I found in review)**
- Settings → switch to the Demo Library → **every screen must show the demo
  content**, not leftovers from your real provider
- Switch back → your library returns

---

## What changed

### Launch speed
1. **Home snapshot** (`HomeSnapshotStore`) — the shaped screen cached to disk and
   repainted before any query runs.
2. **Two-phase Home rebuild** — a fast pass paints what's above the fold from
   five small queries; a full pass adds the rest.
3. **No 300 ms debounce on the first build** — that delay exists to coalesce the
   import storm and was costing every launch a third of a second.
4. **Browse paints page 1 first** — count / A–Z rail / facets moved behind it.
5. **Live TV batches its EPG** — was 90 store round-trips per page, now one. The
   zap panel had the same problem (60 lookups); also batched.
6. **Store trims** — prepared-statement cache, a card projection that stops
   fetching cast lists and stream URLs for grid rows, and `applyPreferences` no
   longer rewrites a whole channel column on every launch.
7. `bootstrap`'s fast path stopped blocking the first frame on the search
   vocabulary and the Top Shelf write.
8. **Section models outlive their views** (`SectionModels`) — the sidebar fix.
9. **Size-aware image decode** (`ImageSize`) — `.logo` / `.poster` / `.backdrop`
   drive the decode. Raw bytes on disk are shared across sizes; the memory cache
   went from 40 entries to 140 / 64 MB because each entry is much smaller.
10. **Screens reload only when their content changed** — Favorites, History and
    Home key on a store revision instead of re-querying on every
    back-navigation. Browse grids refresh progress bars in place.
11. **Player** — resume seeks with a 1.5 s tolerance; both players show the title
    while buffering.
12. **Lazy TMDB cache** — it was JSON-decoding hundreds of entries on the main
    thread during the first view build. The artwork sweep waits 4 s and runs at
    background priority.

### Defects found reviewing the above
13. **Provider switch left stale screens.** `SectionModels.reset()` discarded
    every model, but each view's `@State` handle still pointed at the old
    instance and its setup task was guarded on `model == nil`, so it never
    re-fetched. The store carries a generation now; views key on it.
14. **Store revisions were computed on read** — SwiftUI evaluates a `task(id:)`
    key on every redraw, so hashing the whole dictionary there put an
    O(entries) walk in the render path. Stored counters now.
15. **Watch progress wrote to `UserDefaults` every 10 s during playback**,
    encoding the whole history each time. Coalesced to 2 s; destructive edits
    still write at once.
16. **A section was marked "loaded" before its load finished** — switching
    section mid-build cancelled the task and left the screen half-built with no
    retry. Marked after, guarded on cancellation.
17. **Two unbounded caches** — `ImageCache`'s negative cache (capped at 600) and
    the TMDB enrichment cache (capped at 4000, trimmed to most-recently-fetched).
18. **`CatalogDatabase.open()` ended in `try!`** — an unwritable store crashed
    the app on launch. Falls back to an in-memory store instead.

New tests: Home snapshot round-trip, card projection vs by-id fetch, statement
cache timing, generation-stamped refresh, reads-during-write, store revisions,
SectionModels reuse + reset.

## Build risk

Most likely spots, in order:

1. `@Environment(SectionModels.self)` in the five section views (same pattern as
   the existing `AppEnvironment` injection).
2. `HomeContent` / `HomeCard` gaining `Codable`.
3. The statement cache in `SQLiteConnection` (`withStatement`).
4. `HomeView`'s restructured body.

Send any red `⌘B` output with the file name.

## After this builds and the device pass is clean

App Store submission is un-paused — `release/SUBMIT.md` from the "Device pass"
step. Nothing in this sprint changes the bundle id, entitlements, privacy
manifests or signing.
