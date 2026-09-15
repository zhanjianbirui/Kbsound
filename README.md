# KbSound

macOS 菜单栏小工具：敲键盘时播放机械键盘音效。

## 安装

    ./scripts/bundle.sh
    cp -R build/KbSound.app /Applications/
    open /Applications/KbSound.app

首次运行需要在 **系统设置 › 隐私与安全性 › 辅助功能** 中勾选 KbSound。
授权后无需重启，app 每 2 秒轮询一次，拿到权限就自动开始工作。

> 必须以打包好的 `.app` 运行。辅助功能权限按 bundle identifier 授予，
> 用 `swift run` 跑的话授权对象是终端，且开机自启不可用。

## 使用

点菜单栏的键盘图标打开面板：

- **键盘音效**：总开关。关闭后图标变为 `keyboard.slash`
- **音量**：实时生效
- **音效包**：内置 21 套，点击即切换
- **导入音效包…**：见下
- **开机自启**：以系统的登录项状态为准

## 音效包

内置 21 套，来源与授权见 `THIRD-PARTY.md`。

### 导入现成的包

面板上点「导入音效包…」，选择音效包所在的**文件夹**。自动识别三种格式：

| 格式 | 判据 |
|---|---|
| KbSound 原生 | 目录内有 `manifest.json` |
| Mechvibes `multi` | 有 `config.json`，每个音一个文件 |
| Mechvibes `single` | 有 `config.json`，整包一个音频精灵，按时间切片 |

网上流传的 Mechvibes 包基本都能直接导入。macOS 原生支持 wav / mp3 / m4a /
flac / Ogg Vorbis / Opus，无需事先转码。

导入的包装在 `~/Library/Application Support/KbSound/Packs/<pack-id>/`，
同 id 会覆盖内置包。重复导入同一个包是替换，不会堆叠。

### 手写一个包

也可以直接往上述目录放符合 `manifest.json` 格式的包，
格式见 `docs/superpowers/specs/2026-09-10-kb-sound-design.md` 第 4 节。

批量转换 Mechvibes 包可以用命令行：

    python3 scripts/import-mechvibes.py <mechvibes的src/audio目录> <输出目录>

## 关于延迟

按键到出声的延迟主要来自三处，前两处已在代码里处理：

1. **音效文件的前导低电平段**——影响最大。不少包录进了完整按键行程，
   真正的瞬态出现得很晚（实测最差的包要 195ms）。加载时按相对峰值裁掉，
   并保留 2ms 预卷以免削平瞬态。
2. **输出设备 IO buffer**——系统默认 512 frames（48kHz 下 10.67ms），
   启动引擎前调小到 128 frames。这是整台设备共享的设置，
   若发现其他音频 app 出现爆音，把 `OutputDeviceLatency.preferredFrames` 提到 256。
3. **音效包本身的录音风格**——`NovelKeys Cream`、`Turquoise`、`NK Cream · Full Travel`
   起振最快，追求跟手感优先选这几套。

想实测自己机器上的按键事件投递耗时：

    swift run LatencyProbe

## 开发

    swift build && swift test      # 构建与单测（92 个）
    swift run TapProbe             # 验证 CGEventTap 是否可用
    swift run LatencyProbe         # 测量按键事件投递延迟
    swift run KbSound              # 开发模式运行（须在仓库根目录；开机自启不可用）

## 授权

音效素材来源与限制见 `THIRD-PARTY.md`。**本项目仅供自用，请勿公开分发。**
