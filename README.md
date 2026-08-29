# SexyPlayer

A premium IPTV **client** for Apple TV (tvOS). It turns a user's own IPTV
subscription into an experience that feels like a modern streaming service —
not like traditional IPTV software.

**This app is a client only.** It does not provide, host, sell, recommend, or
bundle any IPTV streams or channel lists. The user supplies their own source
(M3U playlist or Xtream Codes account).

---

## Status

| Milestone | Scope | State |
|-----------|-------|-------|
| **M0 — Foundation** | Repo structure, XcodeGen project, design system, domain models, normalization layer + tests, mock provider, in-memory repository, Home screen | ✅ in progress |
| M1 — Persistence | GRDB/SQLite catalog store + FTS5 search index | ⬜ |
| M2 — Live TV + EPG | Channel browsing, TV guide | ⬜ |
| M3 — Movies + Series | VOD browsing, seasons/episodes, resume | ⬜ |
| M4 — Search + AI | Deterministic + Claude-backed natural-language search | ⬜ |
| M5 — Player | AVKit playback, subtitles, audio tracks, channel zap | ⬜ |
| M6 — Provider import | Real M3U / Xtream / XMLTV adapters, onboarding flow | ⬜ |
| M7 — Performance + polish | Image cache, pagination tuning, accessibility, App Store prep | ⬜ |

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full design.

---

## Building this app

Apple TV apps can only be built on a **Mac** with **Xcode**. This repository
contains all the source code; the Xcode project itself is generated from
[`project.yml`](project.yml) by [XcodeGen](https://github.com/yonaskolb/XcodeGen).

👉 **Follow [SETUP-MAC.md](SETUP-MAC.md) for click-by-click setup instructions.**

Short version, once the one-time setup is done:

```bash
xcodegen generate
open SexyPlayer.xcodeproj
```

Then press ▶ in Xcode with the **Apple TV Simulator** (or your Apple TV 4K)
selected.

---

## Toolchain (verified 2026-08)

| Tool | Version |
|------|---------|
| tvOS deployment target | 18.0 |
| Build SDK | tvOS 26 (Xcode 26.x) |
| Swift language mode | 5 (code is written Swift-6-clean; we flip the flag in a later milestone) |
| Dependencies (M0) | none |
| Dependencies (M1+) | GRDB.swift |

---

## Repository layout

```
Sources/
  App/          App entry point, dependency container, root navigation
  Core/         Cross-cutting: logging, small utilities
  Domain/       Pure business types — models, provider protocol, search contracts
  Data/         Normalization layer, mock provider, repositories
  AI/           Natural-language search: query parsers + AI service boundary
  UI/
    DesignSystem/  Colour, type, spacing, focus tokens
    Components/     Reusable focusable views (cards, shelves, states)
    Features/       Screen-level views + view models (Home, …)
Tests/
  SexyPlayerTests/   Unit tests (normalization, parsing, search)
```
