#!/usr/bin/env bash
# Assembles the SwiftPM products into a double-clickable .app.
#
# Why a bundle is required:
#   1. Accessibility permission is granted per bundle identifier — a bare binary would
#      need re-authorizing after every rebuild.
#   2. SMAppService (launch at login) requires a bundle.
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="KbSound"
BUNDLE_ID="com.kbsound.KbSound"   # Never change this: it would invalidate the Accessibility grant.
APP="build/${APP_NAME}.app"

echo "==> Building release"
swift build -c release --product "$APP_NAME"

echo "==> Assembling ${APP}"
rm -rf "$APP"
mkdir -p "${APP}/Contents/MacOS" "${APP}/Contents/Resources"

cp ".build/release/${APP_NAME}" "${APP}/Contents/MacOS/${APP_NAME}"
cp -R "Resources/Packs" "${APP}/Contents/Resources/Packs"
# The localized UI strings live in the KbSoundCore resource bundle; without it the app
# falls back to the raw keys.
cp -R ".build/release/${APP_NAME}_KbSoundCore.bundle" "${APP}/Contents/Resources/"
# Rendered by scripts/make-icon.swift; re-run that after changing the artwork.
cp "Resources/AppIcon.icns" "${APP}/Contents/Resources/AppIcon.icns"

cat > "${APP}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>              <string>${APP_NAME}</string>
    <key>CFBundleExecutable</key>        <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>        <string>${BUNDLE_ID}</string>
    <key>CFBundlePackageType</key>       <string>APPL</string>
    <key>CFBundleIconFile</key>          <string>AppIcon</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key>           <string>1</string>
    <key>CFBundleDevelopmentRegion</key> <string>en</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>en</string>
        <string>zh-Hans</string>
    </array>
    <key>LSMinimumSystemVersion</key>    <string>26.0</string>
    <key>LSUIElement</key>               <true/>
</dict>
</plist>
PLIST

echo "==> Ad-hoc signing"
codesign --force --deep --sign - "$APP"

echo "==> Done: ${APP}"
echo "    Before the first run: open build/"
echo "    Then drag KbSound.app into /Applications and double-click it."
