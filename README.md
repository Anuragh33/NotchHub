# NotchHub

**NotchHub** is a native macOS 15+ utility built with **Swift 6**, **SwiftUI**, and **AppKit** that transforms the MacBook hardware camera cutout (or top-center menu bar on external displays) into an interactive Dynamic Island-style hub inspired by Alcove and Boring Notch.

---

## Download & Install

1. Download **`NotchHub-v1.0.0-macOS.dmg`** (or **`NotchHub-v1.0.0-macOS.zip`**) from the [Latest GitHub Release](https://github.com/Anuragh33/NotchHub/releases/latest).
2. Open `NotchHub-v1.0.0-macOS.dmg` and drag **`NotchHub.app`** into your **`Applications`** folder.
3. Since the app is ad-hoc signed without an Apple Developer ID certificate, remove the quarantine attribute on first launch or right-click → **Open**:
   ```bash
   xattr -cr /Applications/NotchHub.app
   open /Applications/NotchHub.app
   ```

---

## Features

- **Hardware Notch Geometry Detection**: Uses `NSScreen.safeAreaInsets`, `auxiliaryTopLeftArea`, and `auxiliaryTopRightArea` to compute the exact physical camera cutout dimensions, with an automatic fallback pill on external monitors and non-notch MacBooks.
- **Borderless Non-Activating Overlay (`NSPanel`)**: Runs above the system menu bar (`NSWindow.Level.mainMenu + 3`) across all Mission Control spaces and full-screen apps without stealing focus from your active application.
- **Three Morphing States (`#000000` Pitch Black + Top Ear Cutouts)**:
  - **Collapsed**: Matches the exact physical notch dimensions so it stays invisible until hovered.
  - **Compact Wings**: Widens horizontally to show miniature album art on the left and a live animated equalizer waveform or active Pomodoro countdown on the right.
  - **Expanded**: Smoothly morphs outward with interactive spring physics (`spring(response: 0.35, dampingFraction: 0.78)`) after 150ms of hover or when dragging files into the top 60px of the screen, and collapses 300ms after the cursor exits.
- **Modular Widgets**:
  - **Media Controller Tab**: Live Apple Music & Spotify bridge via AppleScript plus an interactive preview mode, blurred album artwork glow, scrubbing progress bar, and animated 6-band equalizer.
  - **File Drop Shelf Tab**: Drag files, images, or text snippets into the top of the screen to hold them temporarily, drag them back out into any app, or clear with one click.
  - **Quick Utilities Bar**: Built-in 25m/5m Pomodoro timer, persistent local scratchpad, and quick settings menu.

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
