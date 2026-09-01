# Launch status

The app is **feature-complete for v1.0** and being prepared for the App Store.

## The runbook

👉 **[release/SUBMIT.md](release/SUBMIT.md)** — the step-by-step submission guide
(GitHub Pages hosting → Mac build → Developer portal → App Store Connect →
archive → submit).

👉 **[release/app-store-listing.md](release/app-store-listing.md)** — every block
of copy to paste into App Store Connect (name, description, keywords, age-rating
answers, App Privacy, review notes).

👉 **[release/CHANGELOG-since-last-build.md](release/CHANGELOG-since-last-build.md)**
— what changed since the last Mac build, and the one build risk to watch.

## Where things stand

| | |
|---|---|
| Apple Developer Program | ✅ active (paid) |
| Team ID | `4YJN2S39Q4` (in `project.yml`) |
| Bundle ID / App Group | `com.aeriaplus.appletv` / `group.com.aeriaplus.appletv` |
| Privacy & support pages | written (`docs/`) — publish via GitHub Pages, SUBMIT.md step 1 |
| App icon + top-shelf art | committed; regenerate via `Tools/brand/` for freshness |
| Privacy manifest | ✅ `PrivacyInfo.xcprivacy` for app + extension |
| Demo library | public-domain films + Apple's HLS reference streams — reviewer needs no credentials |
| Screenshots | 👤 capture from the Simulator (guidance in app-store-listing.md) |
| TMDB token | 👤 run `Scripts/set-tmdb-token.sh` on the Mac before archiving |

## Feature completeness

Provider import (Xtream / M3U / XMLTV) · staged so the app is usable in ~1s ·
name/season/language/quality/genre normalization · 3-phase disk cache + image
cache · non-blocking onboarding · sidebar nav with two-column focus · Home
(rotating hero, Continue Watching, Because You Watched, Top Rated, genre shelves,
Live / Recently-Watched channels, Tonight) · Movies/Series/Live TV browse with
filters + A–Z jump + region relevance · TV Guide · channel detail with EPG
schedule · natural-language Search (on-device + optional Claude) · Favorites ·
Watch History · resume + next-unwatched-episode + autoplay-next · native AVKit +
bundled VLCKit players with track selection, channel zapping, Now Playing,
buffering state · TMDB enrichment (posters, backdrops, ratings, cast, More Like
This, episode stills) · Top Shelf + `aeria://` deep links · Personalize +
Parental PIN · VoiceOver + Reduce Motion.

Deferred to v1.1: "set a reminder" for upcoming programmes.

## Positioning (keep airtight)

Player only — no content provided, no channel lists bundled, no IPTV service
advertised or sold. Reflected in onboarding copy, Settings → About, the store
description, the review notes, and the privacy policy. No trademarked channel
names or logos in screenshots or marketing.
