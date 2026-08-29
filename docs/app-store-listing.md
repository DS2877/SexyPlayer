# App Store Connect — listing draft

Fill the blanks, then paste into App Store Connect. Nothing here is final —
especially the **name**.

---

## Name (30 chars max)

**"SexyPlayer" should not be the store name.** It reads as adult content (it
isn't), it's a weak search term, and App Review name guidelines (2.3.7 / 4.1)
will likely bounce it. Pick something calm and premium. Candidates:

- **Lumen TV**
- **Kanal**
- **Nord Player**
- **Halo — IPTV Player**
- **Clear — IPTV Player**
- **Tuner**

Whatever you pick, the codebase, bundle id, and icon don't depend on it.

## Subtitle (30 chars max)

- `Your IPTV, done beautifully`
- `A premium player for your IPTV`
- `Bring your own IPTV service`

## Promotional text (170 chars, editable any time without review)

> Connect the IPTV service you already have and watch it like a modern streaming
> app — clean names, real artwork, a proper guide, resume, and natural-language search.

## Description

> **[App Name] is a player for the IPTV service you already subscribe to.**
> It doesn't provide, sell, or host any channels or content — you connect your
> own source, and it turns it into something that feels like a modern streaming
> app instead of a spreadsheet.
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
> [App Name] is not affiliated with any IPTV service and does not include or
> recommend any channel lists.

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

Select **Data Not Collected**. Verify before submitting:
- No analytics SDK, no ad SDK, no third-party SDKs (only GRDB is planned, and it's
  a local database). ✅
- Credentials: Keychain only, never transmitted except to the provider. ✅
- If AI-assisted search ships enabled by default at some point, revisit this — but
  it's off by default and sends no personal data.

## Export compliance

Uses only standard HTTPS / system crypto → typically "No" to the custom-encryption
question (`ITSAppUsesNonExemptEncryption = false`).

## Required URLs

- **Privacy Policy URL:** host `docs/privacy-policy.html` (GitHub Pages: enable
  Pages on the repo, `/docs` folder → `https://<user>.github.io/SexyPlayer/privacy-policy.html`)
- **Support URL:** `docs/support.html` the same way
- Replace `REPLACE_WITH_SUPPORT_EMAIL` in both files first.

## App Review notes (paste into the review notes field)

> This app is an IPTV **player only**. It does not provide, sell, host, bundle, or
> recommend any channels, streams, or media. The user connects an IPTV service
> they already subscribe to (Xtream Codes or an M3U URL).
>
> **To review without credentials:** on the first screen choose **"Try the demo"**.
> This loads a built-in sample library (public-domain test streams from Apple and
> Mux) so you can exercise every screen — Home, browsing, filters, the guide,
> search, detail pages, and playback — end to end.
>
> No account is required or offered. No data is collected. All settings and the
> library cache are stored locally on the device.

## Screenshots

tvOS requires 1920×1080 or 3840×2160. Capture from the Simulator (⌘S) with the
**Demo Library** loaded so there's real-looking content:
1. Home — hero + shelves
2. A movie detail page
3. The TV guide
4. Search with interpreted filter chips
5. The player (optional)
