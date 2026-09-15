#!/usr/bin/env bash
# 把 KbSound.app 打成可分发的 .dmg。
#
# 注意：ad-hoc 签名没有开发者证书，在别的机器上首次打开会被 Gatekeeper 拦下，
# 需要右键「打开」，或执行 xattr -dr com.apple.quarantine /Applications/KbSound.app
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="KbSound"
VERSION="$(plutil -extract CFBundleShortVersionString raw "build/${APP_NAME}.app/Contents/Info.plist" 2>/dev/null || echo "1.0")"
VOLUME_NAME="${APP_NAME}"
DMG="build/${APP_NAME}-${VERSION}.dmg"
STAGING="build/dmg-staging"

echo "==> 确保 .app 是最新的"
./scripts/bundle.sh > /dev/null

echo "==> 准备 DMG 内容"
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "build/${APP_NAME}.app" "$STAGING/"
# 拖拽安装用的 /Applications 快捷方式
ln -s /Applications "$STAGING/Applications"
# 授权与使用说明一并放进去
cp THIRD-PARTY.md "$STAGING/第三方素材授权.md"
cat > "$STAGING/首次使用请先读我.txt" <<'TXT'
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

音效素材的来源与授权限制见「第三方素材授权.md」。
本项目仅供自用，请勿公开分发。
TXT

echo "==> 生成 ${DMG}"
# 用 diskutil 而非 hdiutil：macOS 26 起 `hdiutil create -volname` 已弃用。
# UDZO 是通用的压缩只读格式，老系统也能打开。
# 进度条走的是 stderr，正常时不需要看；失败了再把日志全量打出来
LOG="$(mktemp)"
if ! diskutil image create from \
        --format UDZO \
        --volumeName "$VOLUME_NAME" \
        "$STAGING" "$DMG" > "$LOG" 2>&1; then
    echo "!! 生成失败：" >&2
    cat "$LOG" >&2
    rm -f "$LOG"
    exit 1
fi
rm -f "$LOG"

rm -rf "$STAGING"

echo "==> 完成：${DMG}  ($(du -h "$DMG" | cut -f1))"
