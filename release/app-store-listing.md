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

## Version / build

`MARKETING_VERSION` = **1.0**, `CURRENT_PROJECT_VERSION` = **1** (both in `project.yml`).
Every upload to App Store Connect needs a build number higher than the last one
accepted — bump `CURRENT_PROJECT_VERSION` (`"2"`, `"3"`, …) and re-run `xcodegen`
before re-archiving. `MARKETING_VERSION` only changes for a user-visible release.

## "What's New in This Version" (release notes)

> First release. Connect your IPTV service and watch it like a modern streaming app.

## Category

Primary: **Entertainment**. Leave the secondary category blank (or "Utilities").

## Age rating

Answer the questionnaire for the app itself (which ships no content):
- All violence / sexual content / profanity / drugs / horror categories → **None**.
- **Unrestricted Web Access → No.** It is not a browser; it only contacts the
  IPTV service the user configures.
- Gambling, contests, unrestricted access → **No**.
- If asked whether the app can display user-generated or unmoderated content:
  the streams come from the user's own subscription. Note the built-in
  **"Hide adult categories"** filter (on by default) and the optional
  **Parental PIN**.

Expect Apple to land on **17+** for an IPTV player regardless — content the app
plays isn't moderated by Apple. That's the correct and expected outcome; the
parental controls back it up.

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

## Required URLs — GitHub Pages

Hosting is the repo's `docs/` folder on GitHub Pages (see `release/SUBMIT.md` step 1).
**Rename the repo `SexyPlayer` → `aeria` first** (Settings → General → Repository name;
GitHub keeps the old URL redirecting, and the git remote keeps working). Then:

- **Privacy Policy URL:** `https://ds2877.github.io/aeria/privacy-policy.html`
- **Support URL:** `https://ds2877.github.io/aeria/support.html`
- **Marketing URL** (optional field): `https://ds2877.github.io/aeria/`

If you skip the rename, substitute `SexyPlayer` for `aeria` in those URLs — it works,
it just reads oddly next to the app name. Later, point `aeriaplus.se` at Pages with a
`docs/CNAME` file containing `aeriaplus.se` and the DNS records GitHub shows you.

Contact email in all three pages: `info@aeriaplus.se`.

After Pages builds (~1 min), open all three URLs in a browser and confirm they render.

## App Review notes (paste into the review notes field)

> **What this app is:** an IPTV **player only**. It ships with no channels, no
> playlists, no streams, and no content of any kind. It does not sell, host,
> aggregate, or recommend media. The user brings an IPTV service they already
> subscribe to (Xtream Codes credentials or an M3U playlist URL); the app fetches
> that user's own list, tidies the naming, and plays it with a native interface.
> It is the same category as a media player or a browser: neutral software,
> user-supplied content.
>
> **Reviewing without credentials:** on the first screen, choose **"Try the demo"**.
> This loads a built-in sample library of **public-domain films** (Night of the
> Living Dead, Nosferatu, Metropolis, His Girl Friday, The Stranger, …) with
> playback backed by Apple's public HLS reference streams. It exercises every
> screen — Home with the rotating hero and shelves, Movies/Series browsing with
> genre filters and an A–Z index, Live TV, the TV guide, natural-language search
> with visible filter chips, detail pages with a cast rail and "More Like This",
> the channel schedule screen, Watch History, Favorites, Personalize, Settings —
> and plays content end to end via both the native player and the bundled decoder.
>
> **Privacy:** no account is required or offered. We operate no servers; nothing is
> transmitted to us. Preferences, the library cache and watch progress are stored
> locally; provider credentials and optional API keys are in the keychain and are
> only ever sent to the user's own provider. Optional artwork enrichment queries
> The Movie Database with only a title + year (no identifier, no history). Optional
> AI-assisted search is off by default and needs the user's own API key.
>
> **`NSAllowsArbitraryLoads`:** IPTV panels and streams are very frequently plain
> HTTP on non-standard ports; a working IPTV client cannot require HTTPS. No
> first-party endpoint is contacted over HTTP (there are none).
>
> **App Group** (`group.com.aeriaplus.appletv`): used only to hand a short local
> "Continue Watching" list to the bundled Top Shelf extension on the same device.
> Nothing leaves the device.
>
> Contact for any questions during review: info@aeriaplus.se

## Screenshots

Apple TV screenshots must be exactly **1920×1080** or **3840×2160** (landscape).
Minimum 1; upload 5–8. Capture from the tvOS **Simulator** (menu **File → Save
Screen** / ⌘S — saves to the Desktop at native resolution).

**Prep for a full-looking Home:** load the **Demo Library**, wait ~30s for TMDB
artwork, then **play 2–3 different titles** for a few seconds each (and start one
series) so *Continue Watching*, *Because You Watched* and *Top Rated* all have
content. The hero rotates every 9s — catch it on a title with a good backdrop
(Metropolis, Nosferatu, The Stranger).

1. **Home** — the rotating hero + "Top Rated" / genre shelves
2. **Movie detail** — poster + backdrop, the cast rail, "More Like This"
3. **Live TV** — the channel grid with now-playing lines
4. **TV Guide** — the per-channel programme strips
5. **Search** — a query with the interpreted filter chips showing
6. (optional) **Channel detail** — "On now" + the "Later today" schedule
7. (optional) **Personalize** — shows the privacy-forward options

A reviewer sees these before the demo, so lead with Home. Optional: a 15–30s
app-preview video at the same resolution.
