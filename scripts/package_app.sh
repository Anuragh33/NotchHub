#!/usr/bin/env zsh
set -euo pipefail

APP_NAME="NotchHub"
VERSION="1.1.0"
BUNDLE_ID="com.anuragh33.NotchHub"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"
APP_BUNDLE="${DIST_DIR}/${APP_NAME}.app"
DMG_STAGING="${DIST_DIR}/dmg-staging"
ZIP_PATH="${DIST_DIR}/${APP_NAME}-v${VERSION}-macOS.zip"
DMG_PATH="${DIST_DIR}/${APP_NAME}-v${VERSION}-macOS.dmg"

echo "==> Building ${APP_NAME} release binary..."
cd "${ROOT_DIR}"
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)/${APP_NAME}"

echo "==> Creating ${APP_NAME}.app bundle structure..."
rm -rf "${DIST_DIR}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BIN_PATH}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

echo "==> Generating AppIcon.icns..."
ICONSET_DIR="${DIST_DIR}/AppIcon.iconset"
mkdir -p "${ICONSET_DIR}"

swift - "${ICONSET_DIR}" << 'EOF'
import AppKit
import Foundation

let iconsetPath = CommandLine.arguments[1]
let sizes: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]

for (px, filename) in sizes {
    let size = NSSize(width: px, height: px)
    let img = NSImage(size: size)
    img.lockFocus()

    let rect = NSRect(origin: .zero, size: size)
    let cornerRadius = CGFloat(px) * 0.225
    let bgPath = NSBezierPath(roundedRect: rect.insetBy(dx: CGFloat(px) * 0.04, dy: CGFloat(px) * 0.04), xRadius: cornerRadius, yRadius: cornerRadius)

    let bgGradient = NSGradient(colors: [
        NSColor(srgbRed: 0.12, green: 0.13, blue: 0.22, alpha: 1.0),
        NSColor(srgbRed: 0.04, green: 0.04, blue: 0.07, alpha: 1.0)
    ])
    bgGradient?.draw(in: bgPath, angle: -90)

    // Draw Dynamic Island / Notch pill at top center
    let notchW = CGFloat(px) * 0.56
    let notchH = CGFloat(px) * 0.24
    let notchRect = NSRect(
        x: (CGFloat(px) - notchW) / 2.0,
        y: CGFloat(px) * 0.50,
        width: notchW,
        height: notchH
    )
    let notchPath = NSBezierPath(roundedRect: notchRect, xRadius: notchH / 2.0, yRadius: notchH / 2.0)
    NSColor.black.setFill()
    notchPath.fill()

    // Glowing indigo border around the notch pill
    NSColor(srgbRed: 0.39, green: 0.40, blue: 0.95, alpha: 0.85).setStroke()
    notchPath.lineWidth = max(1.0, CGFloat(px) * 0.018)
    notchPath.stroke()

    img.unlockFocus()

    if let tiff = img.tiffRepresentation,
       let rep = NSBitmapImageRep(data: tiff),
       let png = rep.representation(using: .png, properties: [:]) {
        let outURL = URL(fileURLWithPath: iconsetPath).appendingPathComponent(filename)
        try? png.write(to: outURL)
    }
}
EOF

iconutil -c icns "${ICONSET_DIR}" -o "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
rm -rf "${ICONSET_DIR}"

echo "==> Writing Info.plist..."
cat > "${APP_BUNDLE}/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>NotchHub uses AppleEvents to display and control Now Playing tracks in Apple Music and Spotify.</string>
</dict>
</plist>
EOF

echo "==> Ad-hoc code signing ${APP_NAME}.app..."
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "==> Creating ZIP archive: ${ZIP_PATH}"
ditto -c -k --sequesterRsrc --keepParent "${APP_BUNDLE}" "${ZIP_PATH}"

echo "==> Creating DMG installer: ${DMG_PATH}"
mkdir -p "${DMG_STAGING}"
cp -R "${APP_BUNDLE}" "${DMG_STAGING}/"
ln -s /Applications "${DMG_STAGING}/Applications"
hdiutil create -volname "${APP_NAME}" -srcfolder "${DMG_STAGING}" -ov -format UDZO "${DMG_PATH}"
rm -rf "${DMG_STAGING}"

echo "==> Packaging complete!"
ls -lh "${ZIP_PATH}" "${DMG_PATH}"
