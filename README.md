# KbSound

A tiny macOS menu bar app that plays mechanical keyboard sounds as you type.

一个 macOS 菜单栏小工具：敲键盘时播放机械键盘音效。

![macOS 26+](https://img.shields.io/badge/macOS-26%2B-black)
![Swift 6](https://img.shields.io/badge/Swift-6-orange)
![Tests](https://img.shields.io/badge/tests-111%20passing-brightgreen)

- **21 built-in sound packs**, switchable from the menu bar
- **Loudness-normalized** — every pack lands at the same perceived volume
- **Low latency** — lead-in trimming and a small IO buffer keep key-to-sound tight
- **Imports Mechvibes packs** — drop in any community pack folder
- No network access, no telemetry, ~7 MB of audio, negligible CPU

---

## Install / 安装

Build a DMG (recommended if you install on more than one machine):

```sh
./scripts/dmg.sh
open build/
```

Mount it and drag **KbSound** into Applications. Or build just the `.app`:

```sh
./scripts/bundle.sh
cp -R build/KbSound.app /Applications/
open /Applications/KbSound.app
```

> **Gatekeeper.** The app is ad-hoc signed — there is no developer certificate.
> On *another* machine, the first launch is blocked: right-click KbSound and choose
> **Open**, or run `xattr -dr com.apple.quarantine /Applications/KbSound.app`.
>
> Ad-hoc signatures identify the binary by its code hash, so **every rebuild
> invalidates the existing Accessibility grant.** Remove the stale entry in System
> Settings and tick the new one.
>
> 中文：本 app 使用 ad-hoc 签名，在别的机器上首次打开会被 Gatekeeper 拦下，
> 需右键点「打开」或执行上面的 `xattr` 命令。每次重新打包都会让已有的辅助功能授权失效。

On first run, enable KbSound in **System Settings › Privacy & Security › Accessibility**.
No restart needed — the app polls every 2 seconds and starts working as soon as the
grant lands.

首次运行需要在 **系统设置 › 隐私与安全性 › 辅助功能** 中勾选 KbSound，授权后无需重启。

> It must run as a packaged `.app`. Accessibility permission is granted per bundle
> identifier; under `swift run` the grant would go to your terminal, and Login Item
> support is unavailable.
>
> 必须以打包好的 `.app` 运行——用 `swift run` 跑的话授权对象是终端，且开机自启不可用。

## Usage / 使用

Click the keyboard icon in the menu bar:

| Control | 说明 |
|---|---|
| **Keyboard sounds** | 总开关。关闭或未授权时图标变为喇叭划线 |
| **Volume** | 音量，实时生效 |
| **Sound pack** | 音效包，内置 21 套，点击即切换 |
| **Import sound pack…** | 导入外部音效包，见下 |
| **Launch at login** | 开机自启，以系统的登录项状态为准 |

## Loudness normalization / 响度归一

Community packs are recorded at wildly different levels — across the 21 bundled
packs the onset RMS spans **23.7 dB** (`topre-silent` at −16.6 dBFS, `lofi` at
−40.3 dBFS). At a fixed volume setting, switching packs used to mean a jarring
jump in loudness.

Each pack is measured on load and given a single gain that aligns it to a target
of −28 dBFS, which brings the spread down to **2.9 dB**. Three deliberate choices
(`Sources/KbSoundCore/LoudnessNormalizer.swift`):

1. **One gain per pack, not per file.** A spacebar recorded louder than the letter
   keys is the pack author's intent; per-file normalization would flatten it.
2. **RMS over a 120 ms window after onset**, not over the whole file. Whole-file RMS
   is skewed by tail length and trailing silence, while the perceived loudness of a
   keystroke comes almost entirely from the onset.
3. **Soft limiting instead of backing the gain off.** A few packs (`cream-travel`,
   `mx-brown-pbt`) already peak near full scale but sit low in RMS; leaving peak
   headroom would mean they could never be brought up. A few dB of tanh soft limiting
   on a transient that short is inaudible.

Files are also weighted by how many keys reference them — what a pack *sounds like*
while typing is set by the default sound covering most keys, not by the one mapped
only to the spacebar.

中文：21 套内置包的录制电平跨度达 23.7dB，切包时音量忽大忽小。加载时按整包算一个
增益对齐到 −28dBFS，残差收敛到 2.9dB。取舍见上面三点，实现在
`LoudnessNormalizer.swift`，由 `LoudnessNormalizerTests.swift` 的真实数据测试守住。

## Sound packs / 音效包

21 packs ship with the app. Sources and licensing are in [`THIRD-PARTY.md`](THIRD-PARTY.md).

### Importing an existing pack / 导入现成的包

Click **Import sound pack…** and pick the pack's **folder**. Three formats are
auto-detected:

| Format | Detected by |
|---|---|
| KbSound native | a `manifest.json` in the directory |
| Mechvibes `multi` | a `config.json`, one file per sound |
| Mechvibes `single` | a `config.json` and a single audio sprite, sliced by timing |

Virtually every Mechvibes pack floating around online imports directly. macOS decodes
wav / mp3 / m4a / flac / Ogg Vorbis / Opus natively, so no transcoding is needed.

Imported packs land in `~/Library/Application Support/KbSound/Packs/<pack-id>/`.
A matching id shadows a built-in pack; re-importing replaces rather than stacks.

网上流传的 Mechvibes 包基本都能直接导入，无需事先转码。导入的包装在
`~/Library/Application Support/KbSound/Packs/` 下，同 id 会覆盖内置包。

### Writing one by hand / 手写一个包

Drop a directory with a valid `manifest.json` into the same location. The schema is
in section 4 of `docs/superpowers/specs/2026-09-10-kb-sound-design.md`.

To batch-convert Mechvibes packs from the command line:

```sh
python3 scripts/import-mechvibes.py <mechvibes src/audio dir> <output dir>
```

## About latency / 关于延迟

Key-to-sound latency comes from three places; the first two are handled in code:

1. **Lead-in in the audio file** — by far the largest. Several packs recorded the full
   key travel, so the actual transient starts very late (195 ms in the worst pack
   measured). Trimmed on load by relative peak, keeping 2 ms of pre-roll so the
   transient is not clipped flat.
2. **Output device IO buffer** — macOS defaults to 512 frames (10.67 ms at 48 kHz),
   lowered to 128 before the engine starts. This is a device-wide setting; if other
   audio apps start glitching, raise `OutputDeviceLatency.preferredFrames` to 256.
3. **The pack's own recording style** — `NovelKeys Cream`, `Turquoise` and
   `NK Cream · Full Travel` have the fastest attack. Pick those if responsiveness
   matters most to you.

To measure key event delivery on your own machine:

```sh
swift run LatencyProbe
```

中文：延迟主要来自音效文件的前导段（影响最大，加载时已裁掉）、输出设备 IO buffer
（已调小到 128 frames）和音效包本身的录音风格。

## Development / 开发

```sh
swift build && swift test      # build + unit tests (111)
swift run TapProbe             # verify CGEventTap works
swift run LatencyProbe         # measure key event delivery latency
swift run KbSound              # dev run (from the repo root; no Login Item support)
```

Architecture: `KbSoundCore` holds everything testable — event tap, audio engine,
pack loading, normalization, settings — and the `KbSound` executable is a thin
AppKit/SwiftUI shell around it. Sound packs are decoded to resident PCM buffers on
switch, so the key callback does nothing but a dictionary lookup; no file I/O ever
happens on the hot path.

## License / 授权

Code is released under the MIT License (see [`LICENSE`](LICENSE)).

Bundled audio is **not** covered by that license. It comes from
[klinkmac](https://github.com/rockykusuma/klinkmac),
[mechvibes](https://github.com/hainguyents13/mechvibes) and
[kbsim](https://github.com/tplai/kbsim); provenance and the limits of what is known
about each pack's licensing are documented in [`THIRD-PARTY.md`](THIRD-PARTY.md).
If you own one of these recordings and want it removed, open an issue.

代码采用 MIT 许可。内置音频不在此列，来源与授权情况见 `THIRD-PARTY.md`。
