# Install Aeria+ on your Apple TV

You have a paid Apple Developer account, so you have two good options:

- **Xcode direct install** — fastest, do this first. 1-year signing, needs the
  Mac + Apple TV on the same network each time you update.
- **TestFlight** — set up once, then install and auto-update straight on the
  Apple TV with no Mac. Best if you just want to *use* the app.

Do the direct install now to start using it today; set up TestFlight when you
want to stop being tethered to the Mac.

---

## 0 · One-time project setup (do this once)

1. **Find your Team ID**: [developer.apple.com](https://developer.apple.com) →
   account → **Membership details** → *Team ID* (10 characters, e.g. `A1B2C3D4E5`).

2. **Put it in `project.yml`** — replace `YOUR_TEAM_ID`:
   ```yaml
   DEVELOPMENT_TEAM: "A1B2C3D4E5"
   ```
   Commit it — it's not secret (it's embedded in every shipped app).

3. **Pick a bundle identifier.** `com.sexyplayer.app` in `project.yml` may be
   taken. Change both bundle IDs to your own reverse-domain, e.g.:
   ```yaml
   PRODUCT_BUNDLE_IDENTIFIER: com.philipklingstedt.sexyplayer        # app
   PRODUCT_BUNDLE_IDENTIFIER: com.philipklingstedt.sexyplayer.tests  # tests
   ```

4. Regenerate and open:
   ```bash
   cd ~/Developer/SexyPlayer && git pull && xcodegen generate && open Aeria.xcodeproj
   ```

5. In Xcode: select the **Aeria** target → **Signing & Capabilities**.
   It should show your team and **no errors**. If it complains, click
   *"Try Again"* / *"Register Device"* — with a paid account Xcode handles the
   provisioning profile automatically.

---

## 1 · Xcode direct install

### Pair the Apple TV (once)

- Apple TV: **Settings → Remote and Devices → Remote App and Devices** — leave
  this screen open.
- Mac: Xcode → **Window → Devices and Simulators → Devices**. The Apple TV
  appears under *Discovered*. Click **Pair**, type the 6-digit code from the TV.
- First pairing shows *"preparing for development…"* for a few minutes.

### Install / update

1. Apple TV powered on (awake), same Wi-Fi as the Mac.
2. Xcode top bar: set the run destination to your **Apple TV** (not a simulator).
3. Press **▶ Run**.
4. **First launch only:** if you see *"Untrusted Developer"*, on the Apple TV go
   **Settings → General → VPN & Device Management → [your account] → Trust**,
   then open Aeria+.

With the paid account this stays valid for **1 year**. To update, just press
▶ Run again.

---

## 2 · TestFlight (the no-Mac path)

### Create the App Store Connect record (once)

1. [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → **Apps → +
   → New App**.
2. Platform: **tvOS**. Name: anything unique (you can rename later — "Aeria"
   is fine for TestFlight, not for the public store). Primary language, SKU
   (any string, e.g. `sexyplayer-1`), and the **bundle ID** you set in step 0.3.

### Upload a build

1. In Xcode, set the destination to **Any tvOS Device (arm64)**.
2. **Product → Archive** (uses the Release config).
3. When the Organizer opens: **Distribute App → App Store Connect → Upload** →
   accept the defaults → **Upload**.
4. Wait ~10–30 min. You'll get an email when it finishes processing.

### Install on the Apple TV

1. App Store Connect → your app → **TestFlight** tab.
2. Under **Internal Testing**, create a group, add yourself (uses your Apple ID
   email). Internal builds need **no review**.
3. On the Apple TV: install the **TestFlight** app from the App Store, sign in
   with the same Apple ID, and Aeria+ will be there to install.
4. Future updates: bump `CURRENT_PROJECT_VERSION` in `project.yml` (must be
   unique per upload), `xcodegen generate`, Archive, Upload. It appears in
   TestFlight automatically.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| Signing: *"No profiles found"* / *"failed to register bundle identifier"* | Bundle ID is taken or malformed — change it (setup step 0.3). Xcode → Settings → Accounts → **Download Manual Profiles**. |
| Apple TV won't pair | Same Wi-Fi (not guest). Restart the Apple TV. Toggle its *Remote App and Devices* screen. |
| Archive menu greyed out | Destination must be **Any tvOS Device**, not a simulator. |
| Upload rejected: *"redundant binary"* | Build number (`CURRENT_PROJECT_VERSION`) already used — bump it. |
| App opens then closes | Check the Xcode console (⇧⌘C) for the crash line while running from Xcode. |
| Build works, TV shows old version | Delete the app on the Apple TV (hold Select → ✗), run/install again. |

---

## Connecting your provider

First launch: **Add your TV provider** → **Xtream Codes** (server URL incl.
port, username, password) or **M3U Playlist URL**. Or **Try the demo** to look
around first.

If a real import returns empty: confirm the host has the port
(`http://example.com:8080`) and `http` vs `https` matches your provider.
