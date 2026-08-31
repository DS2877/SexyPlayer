# Mac setup — one time, ~30 minutes

You only do this once. After it's done, the day-to-day loop is just
`git pull` → press ▶ in Xcode.

Everything below is typed into the **Terminal** app on your Mac
(Applications → Utilities → Terminal), unless it says otherwise.

---

## 1. Install Xcode

1. Open the **App Store** on your Mac.
2. Search for **Xcode**, click **Get / Install**. It's large (~10 GB), give it
   time.
3. When it's installed, open Xcode once. Accept the license prompt. Let it
   "install additional components" if it asks.
4. Back in Terminal, run this so command-line tools point at Xcode:

   ```bash
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   ```

   It will ask for your Mac password (you won't see characters as you type —
   that's normal). Press Return.

5. Verify:

   ```bash
   xcodebuild -version
   ```

   You should see `Xcode 26.x`.

---

## 2. Install Homebrew (a package installer for Mac)

Paste this whole line:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Follow its prompts (it may ask for your password). When it finishes it prints
two lines starting with `eval` under **"Next steps"** — copy those, paste them,
and run them so `brew` works in your current Terminal.

Verify:

```bash
brew --version
```

---

## 3. Install XcodeGen

```bash
brew install xcodegen
```

Verify:

```bash
xcodegen --version
```

---

## 4. Get the code onto your Mac

You have two options. **Option A (git) is strongly recommended** — it's how new
versions of the app will reach you.

### Option A — via GitHub (recommended)

```bash
mkdir -p ~/Developer
cd ~/Developer
git clone https://github.com/DS2877/SexyPlayer.git
cd SexyPlayer
```

> ⚠️ **Do not put the project inside iCloud Drive, OneDrive, or Dropbox.**
> Xcode and cloud-sync folders corrupt each other's files. `~/Developer` is a
> safe place.

Later, to get updates: `git pull` inside the `SexyPlayer` folder.

### Option B — manual copy (only if you can't use GitHub yet)

Copy the whole `SexyPlayer` folder from your Windows PC to
`~/Developer/SexyPlayer` on the Mac (USB drive, AirDrop from another device,
etc.). Do **not** rely on OneDrive for this.

---

## 5. Generate the Xcode project and open it

Inside the `SexyPlayer` folder:

```bash
xcodegen generate
open Aeria.xcodeproj
```

Xcode opens.

---

## 6. Run it in the Simulator

1. At the top of the Xcode window, next to the ▶ button, there's a device
   selector. Click it and choose an **Apple TV** simulator (e.g.
   "Apple TV 4K (3rd generation)").
2. Press **▶** (or ⌘R).
3. First build takes a minute or two. The tvOS Simulator launches and the app
   appears.
4. Control the simulator with your **keyboard arrow keys** + **Return** to
   select, **Esc** to go back. Or use **Window → Show Apple TV Remote**
   (⇧⌘R) for an on-screen remote.

---

## 7. Run it on your real Apple TV 4K (optional, do this when you want)

1. Apple TV and Mac must be on the **same Wi-Fi network**.
2. On the Apple TV: **Settings → Remotes and Devices → Remote App and
   Devices**. Leave that screen open.
3. In Xcode: **Window → Devices and Simulators**. Your Apple TV should appear
   under "Discovered". Click **Pair** and enter the code shown on the TV.
4. You'll need a free **Apple ID** signed into Xcode: **Xcode → Settings →
   Accounts → +**. For Simulator-only work this isn't required; for real-device
   installs it is.
5. Pick your Apple TV in the device selector at the top, press ▶.

> Installing on a real device with a *free* Apple ID works but the app expires
> after 7 days and must be re-installed. A paid **Apple Developer Program**
> membership ($99/year) removes that limit and is required for TestFlight and
> the App Store. You don't need it yet.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `xcodegen: command not found` | `brew install xcodegen` didn't finish, or `brew` isn't on PATH. Re-run step 2's `eval` lines. |
| Xcode: "No account for team" / signing errors | Only happens for real-device runs. Add a free Apple ID in **Xcode → Settings → Accounts**, then in the project's **Signing & Capabilities** tab pick your name under Team. Not needed for Simulator. |
| Build fails after a `git pull` | Run `xcodegen generate` again — new files were added to `project.yml`. |
| "Could not find package" | You're offline or GitHub is blocked; Swift Package resolution needs internet on first build. |

When you hit an error you don't understand, copy the **full red error text**
from Xcode's Issue Navigator (the ⚠️ icon in the left sidebar) and send it to
Claude.
