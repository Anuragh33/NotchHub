# NotchHub

**NotchHub** is a native macOS 15+ utility built with **Swift 6**, **SwiftUI**, and **AppKit** that transforms the MacBook hardware camera cutout (or top-center menu bar on external displays) into an interactive Dynamic Island-style hub for **Real-Time AI Subscription Quotas**, an **Animated Pomodoro Timer**, and a **Temporary File Drop Shelf**.

---

## Download & Install (Latest Release: v1.5.1)

1. Download **`NotchHub-v1.5.1-macOS.dmg`** (or **`NotchHub-v1.5.1-macOS.zip`**) from the [Latest GitHub Release](https://github.com/Anuragh33/NotchHub/releases/latest).
2. Open `NotchHub-v1.5.1-macOS.dmg` and drag **`NotchHub.app`** into your **`Applications`** folder.
3. Since the app is ad-hoc signed without an Apple Developer ID certificate, remove the quarantine attribute on first launch or right-click → **Open**:
   ```bash
   xattr -cr /Applications/NotchHub.app
   open /Applications/NotchHub.app
   ```

---

## Features

- **Universal Now Playing Media Island (`NotchTab.media`)**:
  - Live system-wide track metadata: Album artwork, Title, Artist, interactive scrubbing progress bar, and play/pause/prev/next controls.
  - Dynamically binds to macOS `MediaRemote.framework` with AppleScript fallback for Spotify and Apple Music.
  - While music is playing, compact wings display an animated audio equalizer waveform + live track ticker!

- **MagSafe & Battery Charging Dynamic Island**:
  - Event-driven battery monitoring via native macOS `IOKit.ps`.
  - When MagSafe or USB-C is plugged in, the notch triggers a dynamic island pulse displaying an animated green charge bolt, battery percentage, and charging status.

- **AirPods & Bluetooth Device Connection HUD**:
  - Monitors connected Bluetooth accessories (`IOBluetooth`) and pops open a temporary dynamic island alert with battery level indicators whenever AirPods or headphones connect.

- **Notch Camera Mirror & Meeting Preview (`NotchTab.mirror`)**:
  - Zero-latency HD webcam mirror preview nestled directly under the MacBook camera housing using `AVFoundation`.
  - Includes a live microphone VU meter, mirror horizontal flip toggle, and strict auto-shutdown on tab exit to prevent camera indicator light or battery drain.

- **Bento Home Dashboard (`NotchTab.home`)**:
  - Multi-tile glass-bento overview inside the expanded notch combining a live **AI Quotas Matrix**, an interactive **Pomodoro Focus Ring**, live **Now Playing Track** (or **Drop Shelf** counter), and **Clipboard History** preview.
- **Global Command Palette (`⌃⌥K`)**:
  - Press `⌃⌥K` from anywhere on macOS (or click the `⌘K` pill in the bottom bar) to search and trigger any NotchHub action or launch installed macOS applications.
- **Password-Safe Clipboard History Shelf (`NotchTab.clipboard`)**:
  - Automatically captures copied text, links, and images for 1-click reuse while filtering out concealed/transient entries from password managers.
- **Pinned App Launcher Dock (`NotchTab.apps`)**:
  - Pin your favorite macOS applications inside the notch for instant 1-click launching across full-screen spaces.
- **Resizable Idle Pill (`Compact` / `Standard` / `Wide`)**:
  - Customize the idle wings width inside Settings to fit 13-inch, 14-inch, or external displays.

- **Notch Display: Always / Off When Not in Use / Completely Off**:
  - In **Settings (`gearshape.fill`)** or the **Menu Bar Dropdown**, toggle between **Always Display Notch**, **Off When Not in Use (Hover Only)** (where the notch stays 100% invisible when idle and only materializes when you hover at the top center or drag a file), and **Completely Off (Menu Bar Only)**.

- **Real-Time System AI Account Sync & Built-In Sign-In**:
  - Automatically discovers and syncs live credentials, OAuth endpoints, and SQLite telemetry from your system for **Gemini** (`~/.gemini`), **Claude** (`~/.claude` & `api.anthropic.com/api/oauth/usage`), **ChatGPT** (`~/.codex/auth.json`, `chatgpt.com/backend-api/wham/usage`, and `~/.codex/state_5.sqlite`), **OpenCode** (`~/.local/share/opencode/opencode.db` & `auth.json`), and **Ollama** (`127.0.0.1:11434/api/tags` & `/api/ps`).
  - **Built-In Account Sign-In Window**: If an account session is missing or expired, click **Sign In** on any provider card (or in Settings) to open an embedded `WKWebView` sign-in modal, launch the CLI login in Terminal (`claude auth login`, `codex login`, `gemini`, `ollama serve`), or paste an OAuth/API token directly.
- **Animated Pomodoro Focus Timer**:
  - Dedicated Pomodoro Timer tab with a glowing circular progress ring, pulsing breathing aura while running, **Focus (25m)** / **Short Break (5m)** / **Long Break (15m)** phases, 4-session Pomodoro cycle dots, and `-5m` / `+5m` steppers.
  - Compact Wings mode displays a miniature animated circular progress ring + live countdown on the left wing and live synced AI remaining percentage on the right wing.
- **Temporary File Drop Shelf**:
  - Drag files, images, or text snippets toward the top 60px of your screen to automatically expand the Drop Shelf, hold items temporarily, and drag them back out into any app.
- **Clean Symbol-Only Navigation & Settings Menu**:
  - Top-left of the expanded notch features clean symbol-only tab pills (`sparkles`, `timer`, `tray.and.arrow.down.fill`).
  - **Menu Bar Icon On/Off** and **Compact Wings On/Off** toggles live cleanly inside the Settings (`gearshape.fill`) menu and the macOS Menu Bar dropdown.

---

## Build from Source

```bash
git clone https://github.com/Anuragh33/NotchHub.git
cd NotchHub

# Build and run directly
swift build -c release
.build/release/NotchHub

# Or package NotchHub.app, .zip, and .dmg installers into ./dist
chmod +x scripts/package_app.sh
./scripts/package_app.sh
```
