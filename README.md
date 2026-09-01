# Aeria+

A premium IPTV **client** for Apple TV (tvOS). It turns a user's own IPTV
subscription into an experience that feels like a modern streaming service.

**This app is a client only.** It does not provide, host, sell, recommend, or
bundle any IPTV streams or channel lists. The user supplies their own source
(Xtream Codes or an M3U playlist URL).

---

## Building

Apple TV apps build only on **macOS + Xcode**. This repo contains all the source;
the Xcode project is generated from [`project.yml`](project.yml) by
[XcodeGen](https://github.com/yonaskolb/XcodeGen).

👉 First time: **[SETUP-MAC.md](SETUP-MAC.md)** (click-by-click).

Day to day:

```bash
git pull
xcodegen generate        # after any pull that adds/removes files
open Aeria.xcodeproj
```

If the build system gets into a bad state (`invalid reuse after initialization
failure`, `internal inconsistency`), quit Xcode and
`rm -rf ~/Library/Developer/Xcode/DerivedData`.

---

## What's built

| Area | Status |
|---|---|
| Provider import — Xtream Codes, M3U, XMLTV EPG · staged so the app is usable in ~1s | ✅ |
| Normalization — name cleanup, SxxExx reconstruction, language/subtitle/quality/genre/adult detection | ✅ |
| Disk cache (3-phase) + on-disk image cache — instant relaunch, background refresh | ✅ |
| Onboarding — add provider → import checklist → personalize (never blocks) | ✅ |
| Sidebar navigation with two-column focus, Menu-to-sidebar | ✅ |
| Home — rotating hero, Continue Watching, Because You Watched, Top Rated, genre shelves, Live/Recently-Watched channels, Tonight | ✅ |
| Movies / Series / Live TV browse — composable filters, A–Z jump, region relevance | ✅ |
| TV Guide — per-channel programme strips | ✅ |
| Channel detail — now/next + a "Later today" EPG schedule | ✅ |
| Search — natural language → structured filters (on-device; optional Claude parser with your own key) | ✅ |
| Favorites · Watch History with management | ✅ |
| Detail screens + resume + "next unwatched episode" + autoplay-next | ✅ |
| Native AVKit player + bundled VLCKit for MKV/AVI/TS/RTMP · track selection · channel zapping · Now Playing · buffering state | ✅ |
| TMDB metadata enrichment — posters, backdrops, ratings, cast, "More Like This", episode stills | ✅ |
| Top Shelf extension + `aeria://` deep links | ✅ |
| Personalize — languages, subtitles, adult filter + Parental PIN, Home rows, AI toggle | ✅ |
| Accessibility — VoiceOver labels, Reduce Motion, focus order | ✅ |
| App icon + top-shelf art (chrome "Aeria+" wordmark) | ✅ |
| Reminders | ⬜ (deferred) |

See **[LAUNCH.md](LAUNCH.md)** and, to submit to the App Store,
**[release/SUBMIT.md](release/SUBMIT.md)** + **[release/app-store-listing.md](release/app-store-listing.md)**.

---

## Architecture

`ProviderClient` → `RawCatalog` → `Normalizer` (pure, tested) → `Catalog` →
`CatalogRepository` → SwiftUI features. The UI never touches a provider format.

- **Domain** — value types, `Sendable`. Provider protocol, search contracts.
- **Data** — normalization, provider adapters, repositories, disk cache, stores.
- **AI** — `AIQueryParser` (on-device `DeterministicQueryParser` + optional
  remote), `AIService` boundary with an explicit privacy contract.
- **UI** — `DesignSystem` tokens, reusable focusable components, feature screens.

Concurrency: `async/await`, actors for the import pipeline, `@Observable` +
`@MainActor` for view models. No Combine.

Dependencies: one — **VLCKitSPM** (bundled media decoder for containers AVPlayer
can't open). The catalog is held in memory; a SQLite backing is a ready seam if a
library ever outgrows it.

Toolchain: tvOS 18 deployment, built with the tvOS 26 SDK, Swift 5 language mode
(code is written Swift-6-clean).

---

## Repo layout

```
Sources/
  App/        entry point, AppEnvironment (DI), RootView
  Core/       networking, logging, small utilities
  Domain/     models, provider protocol, search + playback contracts
  Data/       normalization, providers (Xtream/M3U/XMLTV), repositories, cache, stores
  AI/         query parsers + AIService
  UI/
    DesignSystem/  colour, type, spacing, focus
    Components/     PosterCard, ChannelCard, Shelf, FilterSheet, state views…
    Navigation/     SidebarShell, AppRoute
    Features/       Home, Browse, Guide, Search, Favorites, Detail, Player, Setup, Settings
Tests/AeriaTests/   parsing, normalization, search, cache, preferences, compatibility
Tools/brand/        icon generator
docs/               the public site — privacy policy, support, landing (GitHub Pages)
release/            submission runbook, store-listing copy, changelog
```
