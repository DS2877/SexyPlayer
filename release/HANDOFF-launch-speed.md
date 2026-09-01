# Hand-off — the instant launch (and the v1.0 polish pass)

**Four new files, so `xcodegen generate` is required.**

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
the live rebuild swaps in fresh content behind it. You should see rows *fill in
and improve*, never a blank screen waiting.

*(First launch after this update still shows the skeleton once — there's no
cached screen yet.)*

**Moving around the sidebar is now free.** Previously, scrolling the sidebar
from Home down to History destroyed and rebuilt seven screens on the way past,
each re-running its queries. Section state now outlives the switch, so a screen
you've visited comes straight back — same scroll position, same focus.

**Movies and Live TV** show their first grid almost immediately; the count, the
A–Z rail and the filter chips land a beat later. That ordering is deliberate —
the A–Z rail has to read every matching title in sort order, which is far more
work than the 60 cards you can see.

**Scrolling should be visibly smoother**, especially Live TV. Posters were being
decoded at three times the size they render at, and channel logos at nearly
four; the memory cache couldn't hold even one screenful, so scrolling back
always re-decoded.

**Resuming a film starts almost instantly** instead of pausing on a spinner, and
both players now name what's opening while it buffers.

### Walk this on the device

- Launch, kill, launch again → the second one is instantly populated
- Scroll the sidebar top to bottom, then back → sections come back as you left
  them, no reloading
- **Movies** → cards first, then the count and A–Z rail; open a title, press
  Menu → grid and focus exactly where you left them
- **Live TV** → scroll several pages fast; logos and "on now" keep up
- **Home** → let it sit a second; genre / Because-You-Watched shelves slide in
  below the fold without the top flickering
- Resume a part-watched film → picks up near where you left off, fast
- **Favorites / History** → heart something on a detail screen, press Menu →
  the list updates; go in and straight back out → it doesn't move
- Switch provider in Settings → the cached screen must **not** show the old
  library

---

## What changed

### Launch (previous batch, unbuilt until now)
1. **Home snapshot** (`HomeSnapshotStore`) — the shaped screen cached to disk and
   repainted before any query runs.
2. **Two-phase Home rebuild** — a fast pass paints what's above the fold from
   five small queries; a full pass adds the rest.
3. **No 300 ms debounce on the first build** — that delay exists to coalesce the
   import storm and was costing every launch a third of a second.
4. **Browse paints page 1 first** — count / A–Z rail / facets moved behind it.
5. **Live TV batches its EPG** — was 90 store round-trips per page, now one.
6. **Store trims** — prepared-statement cache, a card projection that stops
   fetching cast lists and stream URLs for grid rows, and `applyPreferences` no
   longer rewrites a whole channel column on every launch.
7. `bootstrap`'s fast path stopped blocking the first frame on the search
   vocabulary and the Top Shelf write.

### This batch
8. **Section models outlive their views** (`SectionModels`) — the sidebar fix
   above. They reset when the active provider changes, and each section records
   the catalog revision it loaded at, so a screen visited mid-import refreshes
   once after the import finishes rather than showing a stale partial library.
9. **Size-aware image decode** (`ImageSize`) — `.logo` / `.poster` / `.backdrop`
   drive the decode instead of one 900 px cap for everything. Raw bytes on disk
   are shared across sizes; the memory cache went from 40 entries to 140 / 64 MB
   because each entry is now much smaller. Dead artwork URLs are negatively
   cached for 10 minutes instead of being re-requested on every pass.
10. **Screens reload only when their content changed** — Favorites, History and
    Home key on a store revision instead of re-querying on every
    back-navigation. Browse grids refresh the progress bars in place.
11. **Player** — resume seeks with a 1.5 s tolerance (exact-frame seeking over a
    network stream is what made resume feel slow); both players show the title
    while buffering instead of a bare spinner on black.
12. **Lazy TMDB cache** — it was JSON-decoding hundreds of entries on the main
    thread during the first view build. The artwork sweep also waits 4 s and
    runs at background priority so the first screen's posters get the network.
13. **Hardening** — an unwritable catalog store falls back to memory instead of
    `try!`-crashing on launch; dropped a fragile force-unwrap in
    `CategoryMapper`.

New tests: Home snapshot round-trip, card projection vs by-id fetch, statement
cache timing, generation-stamped refresh, reads-during-write, store revisions.

## Build risk

No architecture change beyond `SectionModels`. Most likely spots:

1. `@Environment(SectionModels.self)` in the five section views (same pattern as
   the existing `AppEnvironment` injection, so it should be fine).
2. `HomeContent` / `HomeCard` gaining `Codable`.
3. The statement cache in `SQLiteConnection` (`withStatement`).
4. `HomeView`'s restructured body.

Send any red `⌘B` output with the file name.

## If it's still not instant

Tell me which screen, roughly how long, and whether it's the first launch after
updating or a later one. Next levers, in order: cache the browse screens' first
page the way Home is cached, and precompute the A–Z anchors into a table at
import time instead of deriving them per query.
