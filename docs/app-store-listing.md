# App Store Connect — listing draft (Aeria+)

Paste into App Store Connect. Bundle id `com.aeriaplus.appletv`, category
Entertainment, primary language English.

---

## Name

**Aeria+** (6 chars — well under the 30-char limit).

> Trademark note: "Aeria Games" is an existing games company. A tvOS IPTV player
> is a different class of goods and the "+" differentiates, but if Apple or a
> rights-holder ever objects, `Aeria TV` / `Aeria Player` are fallbacks that need
> no code change (only `CFBundleDisplayName` + the listing).

## Subtitle (30 chars max)

`Your IPTV, done beautifully` (26)

## Promotional text (170 chars, editable any time without review)

> Built for picture, for sound, and for the silence between them. Connect your own
> IPTV service and watch it like a modern streaming app — artwork, guide, resume, search.

## Description

> **We provide the player. You choose what to watch.**
> Aeria+ is a player for the IPTV service you already subscribe to. It provides,
> hosts, and controls no channels or content of its own — you connect your own
> source, and it turns it into something that feels like a modern streaming app
> instead of a spreadsheet.
>
> **Bring your own source**
> Connect with Xtream Codes or an M3U playlist URL. Your details are stored
> securely on your Apple TV and are only ever sent to your provider.
>
> **It cleans up the mess**
> "SE | TV4 HD [1080p]" becomes "TV4". Episodes are matched into seasons.
> Languages, subtitle tracks, quality and year are detected automatically.
>
> **Built for the Siri Remote**
> A cinematic Home screen with Continue Watching and a "Tonight" rail. A TV guide
> that's actually navigable. Movie and series pages with resume, favourites and
> episode lists. The native Apple TV player, with subtitle and audio track
> selection.
>
> **Search the way you think**
> Ask for "a scary movie with Swedish subtitles" or "something under two hours"
> and it works out what you mean, then shows you exactly which filters it applied.
>
> **Private by design**
> No account. No analytics. No ads. Nothing is sent anywhere except your own
> provider. Optional AI-assisted search sends only your words and your library's
> genre/language list — never credentials, links, or history.
>
> Aeria+ is not affiliated with any IPTV service and includes no channel lists.
> We take no responsibility for content that third parties choose to view through
> the player.

## Keywords (100 chars, comma-separated, no spaces after commas)

`iptv,m3u,xtream,player,playlist,epg,tv guide,live tv,stream,m3u8,xmltv`

## Category

Primary: **Entertainment**

## Age rating

Answer the questionnaire honestly. The app itself has no mature content; it plays
whatever the user's provider sends. "Unrestricted web access" = **No** (it only
contacts the user-configured provider). Expect a 12+ or 17+ outcome because
user-supplied streams are uncontrolled — that's fine and correct.

## App Privacy ("Data Not Collected")

Select **Data Not Collected**. Verify against the built binary before submitting:
- One SPM dependency: **VLCKitSPM** (bundled media decoder, no network, no
  telemetry). No analytics SDK, no ad SDK, no crash reporter. ✅
- Credentials (Xtream user/pass, M3U URL, optional TMDB/Claude keys): **Keychain
  only**, never transmitted except to their own service. ✅
- TMDB enrichment (on by default): each request sends only a **title + year**. No
  user identifier, no provider details, no watch history. Uses the app's bundled
  read token or the user's own key.
- AI-assisted search: **off by default**; when on, sends only the query string +
  the library's genre/language vocabulary. Requires the user's own Claude key.
- Catalog cache + preferences + watch progress: local files / `UserDefaults` /
  Keychain on the device only. No iCloud, no server.

## Export compliance

Uses only standard HTTPS / system crypto → typically "No" to the custom-encryption
question (`ITSAppUsesNonExemptEncryption = false`).

## Required URLs

Contact email is set to `info@aeriaplus.se` in both pages.

You own **aeriaplus.se** — host the two pages there for a professional URL:
- **Privacy Policy URL:** `https://aeriaplus.se/privacy` (or `/privacy-policy.html`)
- **Support URL:** `https://aeriaplus.se/support`

The files to publish are `docs/privacy-policy.html` and `docs/support.html`
(plus `docs/index.html` as the landing page at `https://aeriaplus.se`). Any static
host works — a `docs/` folder on GitHub Pages with a CNAME to `aeriaplus.se`, Netlify,
Cloudflare Pages, or plain web hosting.

After publishing, open both URLs in a browser and confirm they render.

## App Review notes (paste into the review notes field)

> This app is an IPTV **player only**. It does not provide, sell, host, bundle, or
> recommend any channels, streams, or media. The user connects an IPTV service
> they already subscribe to (Xtream Codes or an M3U playlist URL). It is
> conceptually the same category as a web browser or a media player: the software
> is neutral; the content is entirely user-supplied.
>
> **To review without credentials:** on the first screen choose **"Try the demo"**.
> This loads a built-in sample library backed by public-domain test streams (Apple
> and Mux) so you can exercise every screen — Home, Movies/Series browsing and
> filters, Live TV, the guide, natural-language search, detail pages with cast and
> "More Like This", Watch History, Favorites, Settings — and play content end to end.
>
> No account is required or offered. No data is collected or transmitted to us (we
> operate no servers). All settings and the library cache are stored locally on the
> device; credentials are in the keychain and are only ever sent to the user's own
> provider.
>
> Optional artwork enrichment queries The Movie Database with only a title and year.
> Optional AI-assisted search is off by default and requires the user's own API key.
>
> The app declares an App Group (`group.com.aeriaplus.appletv`) used solely to pass
> a small "Continue Watching" list to the bundled Top Shelf extension on the same
> device. Nothing leaves the device.

## Screenshots

tvOS requires 1920×1080 or 3840×2160. Capture from the Simulator (⌘S) with the
**Demo Library** loaded (its titles are real public-domain films, so artwork looks
real):
1. Home — rotating hero + shelves
2. A movie detail page — cast rail + "More Like This"
3. Live TV
4. The TV guide
5. Search with interpreted filter chips

Optional: a 15–30s app preview video (same resolution).
