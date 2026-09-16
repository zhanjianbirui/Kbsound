#!/usr/bin/env bash
# Packs KbSound.app into a distributable .dmg.
#
# Note: ad-hoc signing means there is no developer certificate, so Gatekeeper blocks the
# first launch on another machine. The user has to right-click → Open, or run
# xattr -dr com.apple.quarantine /Applications/KbSound.app
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="KbSound"
VERSION="$(plutil -extract CFBundleShortVersionString raw "build/${APP_NAME}.app/Contents/Info.plist" 2>/dev/null || echo "1.0")"
VOLUME_NAME="${APP_NAME}"
DMG="build/${APP_NAME}-${VERSION}.dmg"
STAGING="build/dmg-staging"

echo "==> Making sure the .app is up to date"
./scripts/bundle.sh > /dev/null

echo "==> Preparing the DMG contents"
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "build/${APP_NAME}.app" "$STAGING/"
# Drag-to-install shortcut
ln -s /Applications "$STAGING/Applications"
# Licensing and usage notes ride along
cp THIRD-PARTY.md "$STAGING/THIRD-PARTY.md"
cat > "$STAGING/READ ME FIRST.txt" <<'TXT'
KbSound — installation
======================

1. Drag KbSound onto the Applications folder on the right.

2. The first launch is blocked by the system (this app is ad-hoc signed and has no
   developer certificate). Either:
     · right-click KbSound in Applications → Open → Open again in the dialog, or
     · run in Terminal:
         xattr -dr com.apple.quarantine /Applications/KbSound.app

3. There is no Dock icon after launching — look at the right side of the menu bar.
   Before permission is granted the icon is a crossed-out speaker, meaning no sound.

4. Click that icon → the yellow banner at the top of the panel → follow it to
   System Settings › Privacy & Security › Accessibility and tick KbSound.
   No restart needed: about 2 seconds after the grant the icon turns into a keyboard
   and the app starts working.

The app follows your system language (English and Simplified Chinese).

Where the audio comes from and how it is licensed: see THIRD-PARTY.md.
The code is MIT licensed; the audio comes from the community and its licensing chain is
not clear, so please check for yourself before redistributing it.


KbSound 安装说明
================

1. 把 KbSound 拖到右侧的 Applications 文件夹。

2. 首次打开会被系统拦下（本 app 使用 ad-hoc 签名，没有开发者证书）。
   解决办法二选一：
     · 在「应用程序」里右键点 KbSound → 选「打开」→ 在弹窗里再点「打开」
     · 或在终端执行：
         xattr -dr com.apple.quarantine /Applications/KbSound.app

3. 打开后 Dock 里不会有图标，请看菜单栏右侧。
   还没授权时显示的是「喇叭划线」图标，表示当前没有声音。

4. 点该图标 → 面板顶部黄色提示条 → 按提示到
   系统设置 › 隐私与安全性 › 辅助功能 中勾选 KbSound。
   无需重启，授权后约 2 秒图标会自动变成键盘，开始工作。

界面语言跟随系统（英文 / 简体中文）。

音效素材的来源与授权情况见 THIRD-PARTY.md。
代码采用 MIT 许可；音频部分来自社区，授权链并不清晰，转发前请自行确认。
TXT

echo "==> Building ${DMG}"
# diskutil rather than hdiutil: `hdiutil create -volname` is deprecated as of macOS 26.
# UDZO is the common compressed read-only format that older systems can open too.
# The progress bar goes to stderr and is not interesting while things work; dump the
# whole log only on failure.
LOG="$(mktemp)"
if ! diskutil image create from \
        --format UDZO \
        --volumeName "$VOLUME_NAME" \
        "$STAGING" "$DMG" > "$LOG" 2>&1; then
    echo "!! Build failed:" >&2
    cat "$LOG" >&2
    rm -f "$LOG"
    exit 1
fi
rm -f "$LOG"

rm -rf "$STAGING"

echo "==> Done: ${DMG}  ($(du -h "$DMG" | cut -f1))"
