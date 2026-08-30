# Install SexyPlayer on your Apple TV

This is for running the app on **your own Apple TV 4K** — no App Store, no
review. You need a Mac with Xcode (the same one you build on) and the Apple TV
on the same Wi-Fi network.

There are two paths. Start with the free one.

---

## Path A — Free Apple ID (good enough to use it every day)

**Limits:** the app stops opening after **7 days** and you re-install it from
Xcode (30 seconds). Max 3 self-signed apps per device. No TestFlight.

### One-time setup

1. **Add your Apple ID to Xcode**
   Xcode → Settings (⌘,) → **Accounts** → **+** → Apple ID → sign in.
   A "Personal Team" appears automatically — that's all you need.

2. **Set signing** (once)
   Open `SexyPlayer.xcodeproj`, select the **SexyPlayer** target → **Signing &
   Capabilities**:
   - ✅ Automatically manage signing
   - **Team:** your Personal Team (`Your Name (Personal Team)`)
   - **Bundle Identifier:** must be globally unique. Change it to something
     personal, e.g. `com.philipklingstedt.sexyplayer`. (Also update it in
     `project.yml` under `PRODUCT_BUNDLE_IDENTIFIER` so `xcodegen generate`
     doesn't overwrite it.)

3. **Pair the Apple TV** (once, sometimes flaky — retry if it doesn't take)
   - Apple TV: **Settings → Remote and Devices → Remote App and Devices**.
     Leave that screen open — it's now discoverable.
   - Mac: Xcode → **Window → Devices and Simulators → Devices**. Your Apple TV
     shows up under "Discovered". Click **Pair**, enter the 6-digit code shown
     on the TV.
   - It may say "preparing for development" for a few minutes the first time.

### Every time you want to install/update

1. Plug the Apple TV in, same Wi-Fi as the Mac, TV powered on (not just asleep).
2. In Xcode, pick your Apple TV as the run destination (top bar, next to the
   scheme).
3. Press **▶ Run**.
4. **First run only:** the app installs but iOS blocks it. On the Apple TV:
   **Settings → General → VPN & Device Management → [your Apple ID] → Trust**.
   Then launch SexyPlayer from the home screen.

When the 7 days are up the icon greys out / won't open — just press ▶ Run in
Xcode again.

---

## Path B — Apple Developer Program ($99/year)

Worth it once you're past daily tinkering.

- Apps signed for **1 year**, not 7 days.
- **TestFlight**: install over the air, no Mac needed after the first upload,
  share with a few people.
- Required for any App Store submission later.

Setup is the same as Path A but the Team is your real developer team, and you
can additionally: Product → **Archive** → **Distribute App → TestFlight** →
install from the TestFlight app on the Apple TV.

Enrolment takes 24–48h (identity check). Start at
[developer.apple.com/programs](https://developer.apple.com/programs/).

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| Apple TV never appears to pair | Both devices on the *same* Wi-Fi (not guest network). Restart the Apple TV. Toggle its Remote App and Devices screen off/on. |
| "Untrusted Developer" on launch | Settings → General → VPN & Device Management → Trust (Path A step 4). |
| "Failed to code sign" / provisioning error | Bundle ID isn't unique — change it (setup step 2). Or Xcode → Settings → Accounts → Download Manual Profiles. |
| App opens then closes instantly | Usually the 7-day signing expired — re-run from Xcode. If fresh install: check the Xcode console for the crash line. |
| Build works, Apple TV shows old version | Delete the app on the Apple TV (hold Select → ✗), run again. |

---

## Connecting your provider

On first launch: **Add your TV provider** → **Xtream Codes** (server URL,
username, password) or **M3U Playlist URL**. Or pick **Try the demo** to look
around with sample content first.

If a real import comes back empty, double-check the host includes the port
(`http://example.com:8080`) and the `http`/`https` matches what your provider
gave you.
