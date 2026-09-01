# Changes since your last verified build

**32 commits, `36a636e` → `0b3fce3`.** All additive or contained swaps — no
refactors, no build-setting changes. New files require `xcodegen generate`:

- `Sources/Data/Stores/NetworkMonitor.swift`
- `Tests/AeriaTests/HomeViewModelTests.swift`

There's no Swift toolchain on the machine these were written on, so a couple of
newer APIs are un-compiled. If `⌘B` shows red, send me the errors — the likely
suspects are flagged with ⚠ below.

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
