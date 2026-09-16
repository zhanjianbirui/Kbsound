<div align="center">

# KbSound

**macOS 菜单栏里的机械键盘音效。**

![macOS 26+](https://img.shields.io/badge/macOS-26%2B-black)
![Swift 6](https://img.shields.io/badge/Swift-6-orange)
![Tests](https://img.shields.io/badge/tests-113%20passing-brightgreen)
![License](https://img.shields.io/badge/license-MIT-blue)

### [⬇︎ 下载最新版 DMG](https://github.com/zhanjianbirui/Kbsound/releases/latest)

[English](README.md)

</div>

---

| | |
|---|---|
| 🎹 | **内置 21 套音效包** —— Cherry MX、Topre、NovelKeys Cream、Holy Pandas 等，菜单栏随点随切 |
| 🔊 | **响度归一** —— 每套包听感音量一致，切包不会忽大忽小 |
| ⚡️ | **低延迟** —— 裁掉音频前导段 + 调小 IO buffer，按键到出声很紧 |
| 📦 | **可导入 Mechvibes 音效包** —— 丢进任意社区包文件夹即可，无需转码 |
| 🌏 | **中英双语界面**，跟随系统语言 |
| 🔒 | **不联网、无遥测** —— 约 7MB 音频，CPU 占用可忽略 |

## 安装

**1 · 下载并拖入。** 打开[最新版 DMG](https://github.com/zhanjianbirui/Kbsound/releases/latest)，
把 **KbSound** 拖到「应用程序」文件夹上。

**2 · 去掉隔离标记。** 本 app 使用 ad-hoc 签名，没有 Apple 开发者证书，
所以从网上下载的版本会被 macOS 拦下。执行一次：

```sh
xattr -dr com.apple.quarantine /Applications/KbSound.app
```

<details>
<summary>不想用终端？</summary>

双击 KbSound，让系统拒绝一次，然后打开**系统设置 › 隐私与安全性**，
滑到最下面点**仍要打开**。部分 macOS 版本对未签名的 app 不提供这条路径，
那就只能用上面的 `xattr` 命令。
</details>

**3 · 授予辅助功能权限。** 启动 KbSound。Dock 里不会有图标——看菜单栏右侧，
会出现一个「喇叭划线」图标。点它，再点黄色提示条，到
**系统设置 › 隐私与安全性 › 辅助功能** 中勾选 KbSound。无需重启：约 2 秒后
图标会变成键盘，敲键盘就有声音了。

> 辅助功能权限就是用来读按键事件的——app 靠它才知道你按了键。
> 不存储、不上传任何内容；[`KeyEventTap.swift`](Sources/KbSoundCore/KeyEventTap.swift)
> 一共 100 行，键码拿到手就直接进字典查表。

<details>
<summary>也可以自己从源码编译</summary>

```sh
./scripts/dmg.sh      # 生成 build/KbSound-1.0.dmg
# 或者只打 .app：
./scripts/bundle.sh && cp -R build/KbSound.app /Applications/
```

本机编译出来的 app 不需要 `xattr` 那一步。但 ad-hoc 签名按代码哈希标识二进制，
所以**每次重新打包都会让已有的辅助功能授权失效**——需要在系统设置里删掉旧条目、勾上新的。

必须以打包好的 `.app` 运行：辅助功能权限按 bundle identifier 授予，
用 `swift run` 跑的话授权对象是终端，且开机自启不可用。
</details>

## 使用

点菜单栏的键盘图标：

| 控件 | 说明 |
|---|---|
| **键盘音效** | 总开关。关闭或未授权时图标变为喇叭划线 |
| **音量** | 实时生效 |
| **音效包** | 内置 21 套，点击即切换 |
| **导入音效包…** | 导入外部音效包，见下 |
| **开机自启** | 以系统的登录项状态为准 |

## 响度归一

社区音效包的录制电平差异极大——21 套内置包的起振段 RMS 跨度达 **23.7dB**
（`topre-silent` 为 −16.6dBFS，`lofi` 为 −40.3dBFS）。同一个音量设置下，
切包就意味着音量忽大忽小。

加载时对整包做一次测量，给出一个增益把它拉齐到统一目标，残差收敛到 **2.9dB**。
目标电平取 −34dBFS，使 21 套包的增益中位数约为 0dB：归一只是把各包**拉齐**，
并不把任何东西变响——同一个滑块位置，听感和以前一样。
四个刻意的取舍（见 `Sources/KbSoundCore/LoudnessNormalizer.swift`）：

1. **整包一个增益，不逐文件归一。** 空格键比字母键录得响是作者的本意，
   逐文件归一会把这层设计抹平。
2. **测起振后 120ms 窗内的 RMS**，而不是整段 RMS。整段 RMS 会被尾音长度和
   静音拖尾带偏，而按键音的响度感受几乎只由起振那一小段决定。
3. **目标电平不改变整体音量。** 最初取各包原始电平的中位数（−28dBFS），
   结果整体被抬高 5.25dB——多数包本就在自身中位数之下。现在的目标锁定为
   让默认包落在 −0.75dB。
4. **用软限幅而不是直接压低增益。** 有几套包（`cream-travel`、`mx-brown-pbt`）
   峰值已贴顶但 RMS 很低，按峰值留余量的话它们永远拉不上来；按键音是极短的瞬态，
   几 dB 的 tanh 软限幅听不出来。

测量还按「有多少个键引用该文件」加权——决定一套包「打起来有多响」的是覆盖大多数键
的那个默认音，不是只给空格用的那个。

## 音效包

随 app 附带 21 套。来源与授权情况见 [`THIRD-PARTY.md`](THIRD-PARTY.md)。

### 导入现成的包

点 **导入音效包…** 并选中音效包所在的**文件夹**。三种格式会自动识别：

| 格式 | 识别依据 |
|---|---|
| KbSound 原生 | 目录下有 `manifest.json` |
| Mechvibes `multi` | 有 `config.json`，每个音一个文件 |
| Mechvibes `single` | 有 `config.json` 和一个音频精灵，按时间切片 |

网上流传的 Mechvibes 包基本都能直接导入。wav / mp3 / m4a / flac / Ogg Vorbis / Opus
由 macOS 原生解码，无需事先转码。

导入的包装在 `~/Library/Application Support/KbSound/Packs/<pack-id>/` 下。
同 id 会覆盖内置包；重复导入是替换，不会堆叠。

### 手写一个包

把带有合法 `manifest.json` 的目录放到同一位置即可。schema 见
[`docs/sound-pack-format.md`](docs/sound-pack-format.md)。

命令行批量转换 Mechvibes 包：

```sh
python3 scripts/import-mechvibes.py <mechvibes 的 src/audio 目录> <输出目录>
```

## 关于延迟

按键到出声的延迟来自三处，前两处已在代码里处理：

1. **音频文件的前导段** —— 影响最大。有几套包录进了完整按键行程，真正的瞬态出现得
   很晚（实测最差的一套要 195ms）。加载时按相对峰值裁掉，并保留 2ms 预卷，
   免得瞬态被削平。
2. **输出设备 IO buffer** —— macOS 默认 512 frames（48kHz 下 10.67ms），
   引擎启动前调到 128。这是整台设备共享的设置；如果别的音频 app 开始爆音，
   把 `OutputDeviceLatency.preferredFrames` 调回 256。
3. **音效包自身的录音风格** —— `NovelKeys Cream`、`Turquoise` 和
   `NK Cream · Full Travel` 起振最快。最看重跟手感的话选这几套。

在自己机器上实测按键事件投递延迟：

```sh
swift run LatencyProbe
```

## 开发

```sh
swift build && swift test      # 编译 + 单元测试（113 条）
swift run TapProbe             # 验证 CGEventTap 是否可用
swift run LatencyProbe         # 测量按键事件投递延迟
swift run KbSound              # 开发期运行（在仓库根目录；不支持开机自启）
```

架构：`KbSoundCore` 承载全部可测试的部分——事件监听、音频引擎、音效包加载、
响度归一、偏好设置；`KbSound` 可执行文件只是外面一层很薄的 AppKit/SwiftUI 壳。
切包时整包解码成常驻内存的 PCM buffer，按键回调里只剩字典查找，热路径上绝无文件 I/O。

界面文案放在 `Sources/KbSoundCore/Resources/<locale>.lproj/Localizable.strings`，
统一经 `Localization.swift` 里的 `loc(_:)` 取用。新增语言：加一个 `.lproj` 目录，
并把该 locale 写进 `scripts/bundle.sh` 的 `CFBundleLocalizations`。

## 授权

代码采用 MIT 许可（见 [`LICENSE`](LICENSE)）。

内置音频**不在此列**。它们来自
[klinkmac](https://github.com/rockykusuma/klinkmac)、
[mechvibes](https://github.com/hainguyents13/mechvibes) 和
[kbsim](https://github.com/tplai/kbsim)；来源以及各包授权情况的已知边界记录在
[`THIRD-PARTY.md`](THIRD-PARTY.md)。若你是其中某段录音的权利人并希望移除，请开 issue。
