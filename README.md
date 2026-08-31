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
| Provider import — Xtream Codes, M3U, XMLTV EPG | ✅ |
| Normalization — name cleanup, SxxExx, language/subtitle/quality/genre/adult detection | ✅ |
| Disk cache — instant relaunch, background refresh | ✅ |
| Onboarding — add provider → import checklist → personalize (never blocks) | ✅ |
| Sidebar navigation | ✅ |
| Home — hero, Continue Watching, Tonight, configurable rows | ✅ |
| Movies / Series / Live TV browse + composable filters | ✅ |
| TV Guide — per-channel programme strips | ✅ |
| Search — natural language → structured filters (on-device) | ✅ |
| Favorites | ✅ |
| Detail screens + resume + autoplay-next-episode | ✅ |
| Native AVKit player — subtitle/audio tracks, unsupported-stream detection | ✅ |
| Personalize — languages, subtitles, adult filter, Home rows, AI toggle | ✅ |
| App icon + top-shelf art | ✅ |
| Claude-backed search parser | ⬜ (needs API-key decision; on-device parser ships) |
| Reminders, Top Shelf extension, metadata enrichment | ⬜ |

See **[LAUNCH.md](LAUNCH.md)** for the launch checklist and
**[docs/app-store-listing.md](docs/app-store-listing.md)** for the store draft.

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
`@MainActor` for view models. No Combine. One dependency planned (GRDB, for when
libraries outgrow the in-memory store).

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
Tools/brand/             icon generator
docs/                    privacy policy, support, store listing (host via GitHub Pages)
```
