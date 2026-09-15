#!/usr/bin/env bash
# 把 SwiftPM 产物组装成可双击运行的 .app。
#
# 必须打包成 bundle 的原因：
#   1. 辅助功能权限按 bundle identifier 授予，裸二进制每次重编都要重新授权
#   2. SMAppService（开机自启）要求 bundle
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="KbSound"
BUNDLE_ID="com.kbsound.KbSound"   # 永不修改：改了辅助功能授权会失效
APP="build/${APP_NAME}.app"

echo "==> 编译 release"
swift build -c release --product "$APP_NAME"

echo "==> 组装 ${APP}"
rm -rf "$APP"
mkdir -p "${APP}/Contents/MacOS" "${APP}/Contents/Resources"

cp ".build/release/${APP_NAME}" "${APP}/Contents/MacOS/${APP_NAME}"
cp -R "Resources/Packs" "${APP}/Contents/Resources/Packs"

cat > "${APP}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>              <string>${APP_NAME}</string>
    <key>CFBundleExecutable</key>        <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>        <string>${BUNDLE_ID}</string>
    <key>CFBundlePackageType</key>       <string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key>           <string>1</string>
    <key>LSMinimumSystemVersion</key>    <string>26.0</string>
    <key>LSUIElement</key>               <true/>
</dict>
</plist>
PLIST

echo "==> ad-hoc 签名"
codesign --force --deep --sign - "$APP"

echo "==> 完成：${APP}"
echo "    首次运行前先执行：open build/"
echo "    然后把 KbSound.app 拖到 /Applications 再双击。"
