# Aeria+ — App Store submission runbook

Do the steps in order. Everything you paste into App Store Connect is in
`release/app-store-listing.md`. Bundle ID is **`com.aeriaplus.appletv`** and is
**permanent** once the first build is uploaded.

Legend: **Terminal** = the macOS Terminal app · **Xcode** / **portal** / **ASC** =
click there. Keyboard shortcuts are written like `⇧⌘K`.

---

## Before you start — checklist

- [ ] Apple Developer Program membership is **active** (paid). — confirmed
- [ ] Team ID `4YJN2S39Q4` is already in `project.yml`. — done
- [ ] You can sign in to <https://developer.apple.com/account> and
      <https://appstoreconnect.apple.com>.
- [ ] Node is installed on the Mac (`node --version`). If not:
      `brew install node`
- [ ] (Optional but recommended) a **TMDB API Read Access Token** — free, instant,
      at <https://www.themoviedb.org/settings/api> (create account → "Developer" →
      copy the long "API Read Access Token"). Without it the app still works but
      shows far fewer posters/backdrops, and the screenshots look bare.

---

## Step 0 — Branch

All the real code lives on **`import-progress-checklist`** (`main` is stale at the
M6 milestone). Just build from where you are:

```bash
cd ~/Developer/SexyPlayer
git checkout import-progress-checklist
git pull
```

*Optional, if you want the release to come from `main`:*
```bash
git checkout main && git merge import-progress-checklist && git push origin main
git checkout import-progress-checklist
```
Not required — the build is byte-identical either way.

---

## Step 1 — Publish the privacy & support pages (GitHub Pages)

App Store Connect requires a public Privacy Policy URL and Support URL. The pages
are already written in `docs/`.

1. **Rename the repo** so the URL doesn't say "SexyPlayer":
   - GitHub → the repo → **Settings** → **General** → *Repository name* →
     change `SexyPlayer` to **`aeria`** → **Rename**.
   - GitHub auto-redirects the old URL and your local `git` keeps working, but to
     be tidy, in **Terminal**:
     ```bash
     cd ~/Developer/SexyPlayer
     git remote set-url origin https://github.com/DS2877/aeria.git
     ```
     (You can leave the local folder named `SexyPlayer` — that's fine.)
   - *If you'd rather not rename:* skip this and use `SexyPlayer` instead of
     `aeria` in every URL below. It works, it just reads oddly.

2. **Enable Pages:** GitHub → repo → **Settings** → **Pages** →
   *Build and deployment* → **Source: Deploy from a branch** →
   **Branch: `import-progress-checklist`** (that's where the current `docs/`
   folder is — or `main` if you did the optional merge in Step 0),
   **Folder: `/docs`** → **Save**.

3. Wait ~1 minute, then open all three in a browser and confirm they render:
   - <https://ds2877.github.io/aeria/>
   - <https://ds2877.github.io/aeria/privacy-policy.html>
   - <https://ds2877.github.io/aeria/support.html>

   (There's a `docs/.nojekyll` file so GitHub serves the HTML as-is.)

---

## Step 2 — Get the app building on the Mac

In **Terminal**:

```bash
cd ~/Developer/SexyPlayer
git pull
```

**TMDB token** (skip if you don't have one — see checklist):

```bash
./Scripts/set-tmdb-token.sh "PASTE_YOUR_TMDB_READ_ACCESS_TOKEN_HERE"
```

**Regenerate the app icon** (the wordmark art):

```bash
cd Tools/brand
npm install sharp
node generate-icon.mjs
cd ../..
```

Open `docs/brand/icon-preview.png` to eyeball it. If the tile is blank, the SVG
font didn't resolve — tell me and I'll switch the generator to a bundled TTF.

**Generate the Xcode project and open it:**

```bash
xcodegen generate
open Aeria.xcodeproj
```

**In Xcode:**
- Top-left toolbar: set the run destination to **Any tvOS Device (arm64)** for
  archiving, or your **Apple TV** for a device test.
- Press **⇧⌘K** (Clean Build Folder), then **⌘B** (Build).
- If it builds: press **⌘U** to run the test suite (should be all green).
- **If there are red build errors, stop and send them to me.** There were ~35
  commits since your last build (see `release/CHANGELOG-since-last-build.md`); a
  couple of new APIs are un-compiled here.

---

## Step 3 — Register the App ID and App Group (Developer portal)

<https://developer.apple.com/account/resources/identifiers/list>

1. **App Group:** Identifiers → **＋** → **App Groups** → Continue.
   - Description: `Aeria Plus App Group`
   - Identifier: `group.com.aeriaplus.appletv`
   - Register.

2. **App ID:** Identifiers → **＋** → **App IDs** → **App** → Continue.
   - Description: `Aeria Plus`
   - Bundle ID: **Explicit** → `com.aeriaplus.appletv`
   - Capabilities: tick **App Groups** → **Edit** → select
     `group.com.aeriaplus.appletv`.
   - Register.

3. **App ID for the Top Shelf extension:** Identifiers → **＋** → **App IDs** →
   **App** → Continue.
   - Description: `Aeria Plus Top Shelf`
   - Bundle ID: **Explicit** → `com.aeriaplus.appletv.topshelf`
   - Capabilities: tick **App Groups** → same group.
   - Register.

(Xcode's automatic signing can also create these, but doing it here first avoids
surprises.)

---

## Step 4 — Create the app in App Store Connect

<https://appstoreconnect.apple.com/apps> → **＋** → **New App**.

- Platforms: **tvOS**
- Name: **Aeria+**  *(if taken, try `Aeria Plus` or `Aeria TV`)*
- Primary language: **English (U.S.)**
- Bundle ID: **com.aeriaplus.appletv** (pick from the list)
- SKU: `aeria-plus-tvos-1` (any unique string, never shown to users)
- User access: **Full Access**

Create. Don't fill in the rest yet — you need a build first.

---

## Step 5 — Archive, validate, upload (Xcode)

1. **Signing:** Xcode → click the **Aeria** project in the navigator → target
   **Aeria** → **Signing & Capabilities**:
   - **Automatically manage signing** = ON
   - Team = your team (Team ID `4YJN2S39Q4`)
   - Confirm **App Groups** shows `group.com.aeriaplus.appletv` with a checkmark.
   - Repeat for the **AeriaTopShelf** target (Team + App Groups).

2. **Archive:** run destination = **Any tvOS Device (arm64)** →
   menu **Product → Archive**. Wait for it to finish; the **Organizer** opens.

3. In the Organizer, select the archive → **Distribute App** →
   **App Store Connect** → **Upload** → keep the defaults
   (Include bitcode: off, Upload symbols: on) → **Distribute**.
   - If **Validate** offers itself first, run it — fix anything it flags, re-archive.
   - Common validation stops: missing icon size (re-run the icon generator),
     App Group not on both targets, wrong Team.

4. Wait for the "processing" email from App Store Connect (5–30 min). The build
   then appears under the app's **TestFlight** tab and can be attached to the
   version.

**Re-uploading:** every new upload needs a higher build number. Edit
`project.yml` → `CURRENT_PROJECT_VERSION: "2"` (then `"3"`, …) →
`xcodegen generate` → archive again.

---

## Step 6 — TestFlight sanity check (10 min)

TestFlight tab → enable internal testing → install on your Apple TV via the
TestFlight app. Verify with **both** the demo and your real provider:

- onboarding → provider connects → library loads
- play a movie (native) and an MKV (bundled decoder), scrub, resume
- Live TV → a channel → the schedule screen → Watch Live → zap between channels
- the TV guide
- Search with a natural-language query
- background the app → the tvOS home screen's top row shows **Continue Watching**
  → selecting an item deep-links back into the app
- Settings → everything reachable; Personalize toggles work

Anything broken → send it to me.

---

## Step 7 — Fill in the listing (App Store Connect)

Open `release/app-store-listing.md` alongside ASC and copy each block:

- **App Information:** Category = Entertainment; Content Rights = "does not
  contain third-party content" (the app ships none); Age Rating → run the
  questionnaire per the doc → expect **17+**.
- **Privacy Policy URL:** `https://ds2877.github.io/aeria/privacy-policy.html`
- **App Privacy** (the separate "Data Collection" section): choose
  **"Data Not Collected"** → publish.
- **Version 1.0 page:**
  - Promotional Text, Description, Keywords, "What's New" → from the doc
  - **Support URL:** `https://ds2877.github.io/aeria/support.html`
  - **Marketing URL:** `https://ds2877.github.io/aeria/`
  - **Screenshots:** 1920×1080 from the Simulator (see the doc — 5 minimum)
  - **Build:** click **＋** next to Build, pick the one from Step 5
  - **App Review Information:** contact details; **Notes** → paste the review-notes
    block from the doc; Sign-in required = **No**
  - **Version Release:** "Automatically release after approval" (or manual)

---

## Step 8 — Submit

**Add for Review** → **Submit**. Export compliance question →
**No** (uses only standard HTTPS / system crypto;
`ITSAppUsesNonExemptEncryption` is already `false` in the build).

Then wait. First review is typically 24–48h.

---

## If it gets rejected

Most likely reasons and the response:

- **Guideline 4.2 / "IPTV" / unmoderated content.** Reply in Resolution Center
  pointing to the review notes: no bundled content, user brings their own
  subscription, demo uses public-domain films. This is the expected one round.
- **Guideline 2.1 — couldn't test.** Make sure they used **"Try the demo"**;
  re-state it in the reply.
- **Name collision (2.3.7 / trademark).** Rename to `Aeria TV` or `Aeria Plus`
  in ASC (App Information → Name). No code change needed —
  `CFBundleDisplayName` in `project.yml` is cosmetic and can follow later.
- **`NSAllowsArbitraryLoads` (2.5.x / 5.x).** Point to the review-notes paragraph:
  IPTV panels are HTTP; no first-party endpoint uses HTTP.
- **Privacy nutrition label mismatch.** Confirm "Data Not Collected" — the only
  SPM dependency (VLCKitSPM) is an offline decoder with no telemetry.

---

## Quick reference — the URLs

| Field | Value |
|---|---|
| Bundle ID | `com.aeriaplus.appletv` |
| App Group | `group.com.aeriaplus.appletv` |
| Team ID | `4YJN2S39Q4` |
| Privacy Policy | `https://ds2877.github.io/aeria/privacy-policy.html` |
| Support | `https://ds2877.github.io/aeria/support.html` |
| Marketing | `https://ds2877.github.io/aeria/` |
| Support email | `info@aeriaplus.se` |
