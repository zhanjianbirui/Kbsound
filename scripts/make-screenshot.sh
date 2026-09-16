#!/usr/bin/env bash
# Regenerates the README screenshots from the real UI.
#
# The tool is wrapped in a throwaway .app because a bundle is what makes CFBundle
# resolve a non-default localization, and what lets the process become active so AppKit
# draws its switches in the on state rather than the inactive grey.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> Building ScreenshotTool"
swift build -c release --product ScreenshotTool

APP="build/ScreenshotTool.app"
rm -rf "$APP"
mkdir -p "${APP}/Contents/MacOS" "${APP}/Contents/Resources"
cp ".build/release/ScreenshotTool" "${APP}/Contents/MacOS/ScreenshotTool"
cp -R ".build/release/KbSound_KbSoundCore.bundle" "${APP}/Contents/Resources/"

cat > "${APP}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>              <string>ScreenshotTool</string>
    <key>CFBundleExecutable</key>        <string>ScreenshotTool</string>
    <key>CFBundleIdentifier</key>        <string>com.kbsound.ScreenshotTool</string>
    <key>CFBundlePackageType</key>       <string>APPL</string>
    <key>CFBundleDevelopmentRegion</key> <string>en</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>en</string>
        <string>zh-Hans</string>
    </array>
</dict>
</plist>
PLIST

# Run from the repository root so the tool finds Resources/Packs and writes into docs/.
"${APP}/Contents/MacOS/ScreenshotTool" docs/screenshot.png -AppleLanguages '(en)'
# docs/screenshot-zh.png is a real screenshot of the running app, so the Chinese render
# goes to build/ as a way to eyeball the localization rather than overwriting it.
"${APP}/Contents/MacOS/ScreenshotTool" build/screenshot-zh.png -AppleLanguages '(zh-Hans)'

rm -rf "$APP"
