# NotchHub

**NotchHub** is a native macOS 15+ utility built with **Swift 6**, **SwiftUI**, and **AppKit** that transforms the MacBook hardware camera cutout (or top-center menu bar on external displays) into an interactive Dynamic Island-style hub inspired by Alcove and Boring Notch.

---

## Download & Install (Latest Release: v1.1.0)

1. Download **`NotchHub-v1.1.0-macOS.dmg`** (or **`NotchHub-v1.1.0-macOS.zip`**) from the [Latest GitHub Release](https://github.com/Anuragh33/NotchHub/releases/latest).
2. Open `NotchHub-v1.1.0-macOS.dmg` and drag **`NotchHub.app`** into your **`Applications`** folder.
3. Since the app is ad-hoc signed without an Apple Developer ID certificate, remove the quarantine attribute on first launch or right-click → **Open**:
   ```bash
   xattr -cr /Applications/NotchHub.app
   open /Applications/NotchHub.app
   ```

---

## Features

- **AI Subscription Remaining Usage Hub**:
  - Track remaining usage, prompt quotas, and reset timers across **Gemini**, **Claude**, **ChatGPT**, **OpenCode**, and **Ollama**.
  - Live local probe of `http://127.0.0.1:11434` for **Ollama** (automatically detects running daemon, installed models, active loaded models, and free VRAM %).
  - Interactive quota scrubber, `-1` / `+1` prompt logging, and instant quota reset right inside the expanded notch.
- **System Menu Bar Icon with On/Off Toggle**:
  - Displays a live status item in the macOS menu bar with average remaining AI quota and a dropdown menu showing each AI provider's remaining usage, quick tab launchers, and settings.
  - Toggle the Menu Bar Icon **On or Off** anytime from the top-right pill in the expanded notch (`Menu Icon On / Off`), the bottom gear menu (`Hide / Show Menu Bar Icon`), or the menu bar dropdown itself.
- **Hardware Notch Geometry Detection**: Uses `NSScreen.safeAreaInsets`, `auxiliaryTopLeftArea`, and `auxiliaryTopRightArea` to compute the exact physical camera cutout dimensions, with an automatic fallback pill on external monitors and non-notch MacBooks.
- **Borderless Non-Activating Overlay (`NSPanel`)**: Runs above the system menu bar (`NSWindow.Level.mainMenu + 3`) across all Mission Control spaces and full-screen apps without stealing focus from your active application.
- **Three Morphing States (`#000000` Pitch Black + Top Ear Cutouts)**:
  - **Collapsed**: Matches the exact physical notch dimensions so it stays invisible until hovered.
  - **Compact Wings**: Widens horizontally to show miniature album art on the left and live AI quota % + animated equalizer waveform (or active Pomodoro countdown) on the right.
  - **Expanded**: Smoothly morphs outward with interactive spring physics (`spring(response: 0.35, dampingFraction: 0.78)`) after 150ms of hover or when dragging files into the top 60px of the screen, and collapses 300ms after the cursor exits.
- **Media Controller & File Drop Shelf**:
  - Live Apple Music & Spotify bridge via AppleScript plus interactive preview mode, blurred album artwork glow, scrubbing progress bar, and animated 6-band equalizer.
  - Temporary drag-and-drop shelf for files, images, and text snippets.

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
