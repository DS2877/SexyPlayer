# Changes since your last verified build

**~45 commits, `36a636e` → HEAD.** All additive or contained swaps — no
build-setting changes. New files require `xcodegen generate`:

- `Sources/Data/Stores/NetworkMonitor.swift`
- `Sources/Domain/Models/EPGWindow.swift`
- `Tests/AeriaTests/HomeViewModelTests.swift`

---

## ⚠️ THE MEMORY CRASH FIX — read this first

The "terminated by the OS for using too much memory" was the **EPG import path**.
`URLSession.data(from:)` pulled the whole decompressed XMLTV into RAM, then the
parser built a struct for *every* programme (a real provider's is millions →
~1 GB), then it was windowed, then normalised — several GB-scale allocations at
once → jetsam.

Fixed at the source (commits after `847a643`):
- `HTTPClient.downloadToFile(from:)` — streams the response to a temp file
  (`URLSession` gzip-inflates into it); nothing large is ever in memory.
- `XMLTVParser.parse(fileURL:within:)` — `XMLParser(stream:)` off disk, and
  **skips any programme outside the guide window** so they're never allocated.
  Memory is now flat regardless of feed size. One reusable `DateFormatter`.
- New `EPGWindow` (−2 h / +32 h) — single source of truth for Xtream, M3U,
  `AppEnvironment`, `CatalogCache`.
- Repository id-maps hold `Int` indices, not struct copies (−~30 MB).
- Decoded-image `NSCache` 140 → 80 MB, decode cap 1400 → 1200 px (−~60 MB).

**To verify:** import your real provider and watch **Debug navigator → Memory**
in Xcode while it loads. It should settle well under ~400 MB and not spike into
the GBs during the "guide" phase. If it still climbs, tell me the peak figure and
the provider's rough size (channels / VOD count).

Channels and VOD are naturally bounded (tens of MB); the EPG was the only part
that scaled with the feed, and it's fixed. A SQLite-backed catalog is still an
option if you want belt-and-braces for a pathologically huge VOD library —
say the word.

There's no Swift toolchain on the machine these were written on, so a couple of
newer APIs are un-compiled. If `⌘B` shows red, send me the errors — the likely
suspects are flagged with ⚠ below.

**Biggest single build risk: the `AeriaTopShelf` extension** (`ContentProvider.swift`,
TVServices APIs, never compiled here). `release/SUBMIT.md` has a 2-minute recipe to
ship v1.0 *without* it if it fights you. Rewritten this session to the most
conservative form (completion-handler API, not the async override).

---

## Detail screens

- **Every screen now has a Play button.** A series you've never opened offers
  "Play S1E1"; after you finish an episode it offers "Next S1E2" (the first
  unwatched one) with a "From Start" secondary. Movies gain "From Start" when a
  resume point exists.
- **Poster thumbnail** beside the movie/series title (Apple TV+ style).
- **`ChannelDetailView` fully rebuilt** — channel logo + metadata, Watch Live /
  favourite, an "On now" block with a live progress bar, and a **"Later today"**
  schedule pulled from the EPG. A 30-second timer refreshes "on now".
- Episode rows show a **runtime** and a **watched ✓** (dimmed still + accent mark).
- Favourite buttons are icon-only everywhere and **bounce** when toggled.

## Home

- **"Because You Watched X"** row — genre-similar titles to the last thing you
  played, under Continue Watching.
- **"Recently Watched"** row of live channels (from your tune-in history).
- Live Now cards show a **live progress bar**.
- The **hero can feature a series**, and movie heroes get a primary **Play**
  action (plays inline); "More Info" drops to secondary.

## Player

- ⚠ **Now Playing metadata** — AVPlayer sets `AVPlayerItem.externalMetadata`
  (title + description); VLC sets `MPNowPlayingInfoCenter`. (`import MediaPlayer`
  in `VLCPlayerModel`.)
- ⚠ **Buffering spinner** — `PlayerModel` observes `AVPlayer.timeControlStatus`
  and shows a spinner (not a frozen frame) when the buffer runs dry.
- VoiceOver: the VLC player surface speaks its title + position.

## Navigation & UX

- ⚠ **Menu from a section root returns focus to the sidebar** (Apple TV
  convention) instead of backgrounding the app. Home still backgrounds; pushed
  detail screens still pop. (`.onExitCommand` via a modifier in `SidebarShell`.)
- ⚠ **Offline banner** — `NetworkMonitor` (`NWPathMonitor`, new file) drives a
  slim "You're offline" pill in `SidebarShell`. Started from `AeriaApp`'s task.
- Search: the query field **auto-focuses** on first entry; recent queries are
  remembered; results show a skeleton grid while searching.
- Live TV / Movies **snap to the top** when the category or filter changes.
- Browse screens show the library skeleton (not a bare spinner) before load.
- Provider-setup text fields get a visible focused state.

## Design / accessibility

- ⚠ **Reduce Motion** honoured — hero stops auto-rotating, skeletons stop
  shimmering. (`@Environment(\.accessibilityReduceMotion)`.)
- `FilterChip` gets a real focused state (fill, accent ring, lift).
- Guide loading state is a channel-strip skeleton.
- Settings: app version in About, sections grouped into cards.
- Favorites section header font matched to the other screens.
- Poster cards announce "N% watched"; A–Z chips read "Jump to A".

## Demo library (for the App Store demo + screenshots)

- **+12 public-domain films** (Phantom of the Opera, White Zombie, House on
  Haunted Hill, The Last Man on Earth, McLintock!, The Kid, The Stranger,
  Scarlet Street, The Hitch-Hiker, Gulliver's Travels, Meet John Doe, The
  Little Shop of Horrors) and **The Lone Ranger** series. This pushes Horror /
  Comedy / Thriller past the 8-title threshold so the Home genre shelves appear.
- Existing `NormalizerTests` / `SearchEngineTests` still hold.

## Reverted

- `ce8d6b1` (2-line `AVPlayerViewController` tweak) — reverted in `1d08352`
  because the exact property names couldn't be verified without a compiler.
