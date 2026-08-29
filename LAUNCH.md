# Launch checklist

Status legend: ✅ done · 🔨 in progress · ⬜ not started · 👤 needs you (Philip)

---

## 0 · Blockers before *any* public release

| | Item | Notes |
|---|---|---|
| 👤 | **Apple Developer Program enrollment** ($99/yr) | Identity verification takes 24–48h. Nothing App-Store-related can happen until this clears. Start at developer.apple.com/programs. |
| 👤 | Decide the **app name** | "SexyPlayer" will likely be rejected by App Review (name guidelines) and is a poor store search term. Pick a real product name — the icon/UI don't depend on it. |
| ✅ | App icon + top-shelf art | Layered parallax icon, App Store icon, both top-shelf sizes. Regenerate via `Tools/brand/`. |
| ⬜ | **Privacy policy URL** (hosted page) | Required field in App Store Connect. We collect ~nothing — easy to write, must be reachable at a stable URL. |
| ⬜ | **Support URL** (hosted page) | Required. Can be a single simple page. |
| ⬜ | App Store screenshots | tvOS requires 1920×1080 (or 3840×2160). Capture from the Simulator once the UI is final: Home, Search, a detail screen, the guide, the player. |

## 1 · Must work well (the "runs great on my Apple TV" bar)

| | Item | Notes |
|---|---|---|
| 🔨 | Onboarding never locks the user out | Non-blocking status pill + 12s "Enter the app" escape on the import checklist. **Verify on device.** |
| 👤 | **Real Xtream account, end to end** | Auth → library loads → movies play → series episodes load on demand → live TV → search → guide. Report everything rough. |
| ✅ | Catalog persists between launches | JSON disk cache, stale-while-revalidate. Big libraries no longer re-import every launch. |
| ✅ | Player refuses unplayable streams cleanly | MPEG-TS / MKV / rtmp etc. get a plain message, not a spinner. 25s load timeout. |
| ⬜ | Confirm playback with the user's actual streams | VOD should be fine; live may be MPEG-TS. If most live channels are `.ts`, decide on a VLCKit fallback engine (bigger dependency). |
| 🔨 | Sidebar navigation | Custom left sidebar. **Verify focus moves cleanly** sidebar ↔ content and you can always get back to Settings. |
| ⬜ | Empty / error states audited on every screen | Home, Search, Guide, Favorites, Browse, Detail, Player. |
| ⬜ | VoiceOver labels pass | Cards, buttons, the player. Accessibility is a review checkpoint and a quality bar. |
| ⬜ | Large-library performance check | 20k+ items: scrolling, filter response, memory. The in-memory store should hold; if not, move the catalog to SQLite/GRDB (seam is ready). |

## 2 · Feature completeness vs the plan

| | Item | Notes |
|---|---|---|
| ✅ | Home (shelves, Continue Watching, Tonight, configurable rows) | |
| ✅ | Movies / Series browse + composable filters | genre / language / subtitle / quality / year / sort |
| ✅ | Live TV browse (categories, now-playing badges) | |
| ✅ | TV Guide | per-channel upcoming strips (not a 2-D grid — better Siri-Remote fit) |
| ✅ | Movie / Series / Channel detail + resume + favourites | |
| ✅ | Native AVKit player, resume, subtitle/audio tracks | |
| ✅ | Natural-language Search (on-device parser) | interpreted filter chips, removable |
| ⬜ | **Claude-backed** query parser | Needs a decision: ship a tiny backend proxy for the API key, or a user-pasted key in Settings for now. On-device parser covers most queries already. |
| ✅ | Personalize (languages, subtitles, adult filter, Home rows) | onboarding + Settings |
| ⬜ | Autoplay next episode | preference exists (`autoPlayNextEpisode`), not wired into the player yet |
| ⬜ | "Set a reminder" for upcoming programmes | Tonight/Guide — `UNUserNotificationCenter`, tvOS supports local notifications |
| ⬜ | Top Shelf extension | `TVTopShelfContentProvider` — Continue Watching on the tvOS home screen. Nice-to-have. |
| ⬜ | Metadata enrichment (TMDB etc.) | Architecturally seamed, not built. Improves "something like X" and artwork. Not required for v1. |

## 3 · App Store submission mechanics (after the dev account clears)

| | Item |
|---|---|
| ⬜ | Set `DEVELOPMENT_TEAM` in `project.yml`, real bundle id, signing |
| ⬜ | App Store Connect record: name, subtitle, promotional text, description, keywords |
| ⬜ | **App Privacy** questionnaire — "Data Not Collected" (verify: no analytics, no ad SDK, credentials in Keychain only) |
| ⬜ | Age rating questionnaire |
| ⬜ | Export compliance (uses HTTPS only → usually "no" to custom crypto) |
| ⬜ | **App Review notes**: explain the bring-your-own-provider model; point the reviewer at the built-in **Demo Library** so they can exercise the whole app without credentials |
| ⬜ | Category: Entertainment |
| ⬜ | TestFlight build → internal test → fix → submit for review |
| ⬜ | Budget for **one rejection round** — IPTV clients get extra scrutiny (guidelines 4.2, 5.x) |

## 4 · Legal / positioning (keep airtight)

- The listing and UI must make clear: **player only, no content provided, no channel lists bundled, no IPTV service advertised or sold.** ✅ already reflected in onboarding + Settings "About" copy.
- No trademarked channel names or logos in screenshots / marketing.
- Don't claim legality of the user's own source.

---

## Realistic timeline

- **Now → 2 days:** verify the current build on device, real-data testing + fixes, audit states/accessibility → *runs great on your Apple TV*.
- **+2–3 days:** autoplay-next, reminders, perf hardening, polish → *TestFlight-ready*.
- **+1 day (after dev account clears):** metadata, privacy/support pages, screenshots → *submit*.
- **+3–7 days:** Apple review (plan for one rejection).
