# KbSound 设计文档

macOS 菜单栏小工具：敲键盘时播放机械键盘音效。

- 状态：已定稿，待实现
- 目标系统：macOS 26 / 27（Apple Silicon）
- 语言/构建：Swift 6.3 + SwiftPM，无 Xcode 工程

## 1. 目标

1. 在任意 app 中敲键盘时播放机械键盘音效，延迟低到听不出来（目标 < 15ms）
2. 菜单栏可开关、调音量、切换音效包
3. 可设置开机自启

## 2. 非目标（明确不做）

- 逐键自定义映射编辑器（直接编辑 manifest.json 即可）
- 应用黑名单 / 免打扰
- 音效包在线商店、下载器、`.klinkpack` 安装流程
- 力度感知、打字节奏自适应
- 独立设置窗口
- Intel 支持、macOS 26 以下支持
- 公开分发（见 §3 授权限制）

## 3. 音效素材与授权

内置音效包取自 [klinkmac](https://github.com/rockykusuma/klinkmac)（仓库 MIT），
共 15 套，位于其 `KlinkMac/Resources/Packs/`。

**限制：** 这些 wav 的 manifest 中 `author` 为 "Mechvibes Community"，
`license` 未标注或为 `unknown`。因此：

- 本项目仅供本机自用
- 不得公开分发打包好的 .app
- 仓库中保留 `THIRD-PARTY.md` 记录来源

## 4. 音效包格式

沿用 klinkmac 的 v1 格式，15 套包全部通用同一 schema：

```
<pack-id>/
├── manifest.json
└── *.wav
```

```jsonc
{
  "formatVersion": 1,
  "id": "com.klinkmac.mx-blue-pbt",
  "name": "Cherry MX Blue · PBT",     // 菜单里显示这个
  "author": "...",
  "description": "...",               // 菜单项副标题
  "defaults": { "down": "midpitch.wav", "up": "default-up.wav" },
  "keys": {
    "49": { "down": "spacebar.wav", "up": "space-up.wav" }
  }
}
```

- `keys` 的 key 是 macOS virtual keyCode 的十进制字符串
- `up` 可缺省；多数包只有 `down`
- 查找顺序：`keys[keyCode].down` → `defaults.down` → 无声
- 音色变化已内建在包里（不同 keyCode 指向 low/mid/high/altpitch），
  **不做运行时音高随机化**

### 包的来源目录

1. 内置：`KbSound.app/Contents/Resources/Packs/`
2. 用户：`~/Library/Application Support/KbSound/Packs/`

同 `id` 时用户包覆盖内置包。

## 5. 架构

```
CGEventTap (.cghidEventTap, .listenOnly)
      │  keyDown / keyUp / flagsChanged
      ▼
KeyEventTap ──── 过滤自动重复、还原修饰键按下/抬起
      │  (keyCode: CGKeyCode, phase: .down | .up)
      ▼
SoundPack ────── keyCode 查表 → AVAudioPCMBuffer（已常驻内存）
      ▼
AudioPlayer ──── AVAudioPlayerNode 池，scheduleBuffer
```

### 性能决策

切换音效包时**一次性**把该包所有 wav 解码成 `AVAudioPCMBuffer` 常驻内存
（单套包最大约 1.5MB）。按键回调里只做字典查找 + `scheduleBuffer`，
**绝不做文件 I/O 或解码**。

`AVAudioPlayerNode` 用固定大小的池（16 个）轮转，避免连打时后一声打断前一声，
也避免每次按键创建节点。

事件回调运行在 CGEventTap 的 run loop 上，必须快速返回；播放调用是非阻塞的。

## 6. 模块划分

| 文件 | 职责 | 主要接口 |
|---|---|---|
| `AccessibilityPermission.swift` | 辅助功能权限检查与引导 | `isTrusted() -> Bool`、`requestAccess()`、`openSettings()` |
| `KeyEventTap.swift` | tap 生命周期、事件归一化、自动重启 | `start()`、`stop()`、`onKey: (CGKeyCode, KeyPhase) -> Void` |
| `SoundPack.swift` | manifest 的 Codable 模型 + keyCode 查找 | `Manifest`、`LoadedPack.buffer(for:phase:)` |
| `SoundPackLoader.swift` | 扫描两个目录、解析、去重、解码 | `availablePacks() -> [PackRef]`、`load(id:) throws -> LoadedPack` |
| `AudioPlayer.swift` | AVAudioEngine、节点池、音量 | `play(_ buffer:)`、`volume`、`start() throws` |
| `Settings.swift` | UserDefaults 持久化 | `isEnabled`、`volume`、`packID` |
| `LoginItem.swift` | SMAppService 开机自启 | `isEnabled`、`setEnabled(_:) throws` |
| `AppState.swift` | `@Observable`，串起上面所有部件 | UI 唯一数据源 |
| `PopoverView.swift` | SwiftUI 面板 | — |
| `MenuBarController.swift` | NSStatusItem + NSPopover | — |
| `main.swift` | 组装、`NSApp.setActivationPolicy(.accessory)` | — |
| `scripts/bundle.sh` | 生成 .app + Info.plist + ad-hoc 签名 | — |

每个文件预期 50–150 行。

## 7. 界面设计

`NSStatusItem` 点击弹出 `NSPopover`，内容是 SwiftUI 视图（`NSHostingView`）。

```
┌────────────────────────┐
│  键盘音效          ●──  │   Toggle，.switch 样式
│                        │
│  🔈 ─────●───── 🔊    │   Slider，两端 SF Symbols
│                        │
│  音效包                 │   .font(.caption) 次级标题
│  ✓ Cherry MX Blue      │   选中项打勾 + accentColor
│    Cherry MX Brown     │
│    Topre Silent        │   可滚动，最多高 240pt
│  ──────────────────    │
│  开机自启          ○──  │
│  退出                   │
└────────────────────────┘
```

宽度 260pt，内边距 16pt。

### HIG / Liquid Glass 要点

参照项目内 `.claude/skills/liquid-glass` 与 `ui-review-tahoe`：

- **不要 glass on glass。** `NSPopover` 自身已经是导航层材质，
  面板内部**不再**调用 `.glassEffect()`，内部元素用填充色和 vibrancy 做层次。
- Liquid Glass 属于导航层，音效包列表是内容层，**列表项不加玻璃材质**。
- 只给主操作上 tint —— 即选中的音效包和开关，其余保持中性。
- 菜单栏图标用 SF Symbols `keyboard`（启用）/ `keyboard.slash`（停用/无权限），
  设 `isTemplate = true` 以适配深浅色和菜单栏材质。
- 圆角同心：面板内卡片圆角 = 父容器圆角 − 内边距。
- 无障碍：所有控件有 `accessibilityLabel`；Reduced Motion / Increased Contrast
  由系统自动处理，不自绘玻璃效果就能免费获得。

## 8. 错误处理

| 情况 | 行为 |
|---|---|
| 无辅助功能权限 | 图标变 `keyboard.slash`，面板顶部显示黄色提示条「需要辅助功能权限」+ 按钮直达系统设置；权限授予后自动启动 tap（轮询 `AXIsProcessTrusted`，2s 间隔，仅在未授权时轮询） |
| `CGEvent.tapCreate` 返回 nil | 面板显示错误条，记录日志，不崩溃 |
| tap 被系统禁用（`.tapDisabledByTimeout` / `.tapDisabledByUserInput`） | 在回调中检测到即调用 `CGEvent.tapEnable(tap:enable:true)` 重新启用。**这是这类工具"用着用着没声了"的头号原因，必须处理** |
| manifest 解析失败 / 引用的 wav 不存在 | 跳过该包，不在菜单中列出，日志记录原因；不影响其他包 |
| 当前选中的包被删除 | 回退到第一个可用包；一个都没有则禁用音效并提示 |
| `AVAudioEngine.start()` 失败 | 图标变灰，面板显示错误条 |
| 音频设备切换（插拔耳机） | 监听 `AVAudioEngineConfigurationChange`，重建引擎并重新连接节点 |

日志用 `os.Logger(subsystem: "com.kbsound", category: ...)`，不吞异常。

## 9. 设置持久化

`UserDefaults.standard`，键前缀 `KbSound.`：

| 键 | 类型 | 默认值 |
|---|---|---|
| `KbSound.enabled` | Bool | `true` |
| `KbSound.volume` | Double | `0.5`，读写时钳制到 `0...1` |
| `KbSound.packID` | String | `com.klinkmac.mx-brown-pbt` |

开机自启不存 UserDefaults，直接读 `SMAppService.mainApp.status`（单一数据源）。

## 10. 构建与打包

必须是 `.app` bundle —— 辅助功能权限按 bundle identifier 授予，
裸可执行文件每次重编都要重新授权，且 `SMAppService` 也要求 bundle。

`scripts/bundle.sh`：

1. `swift build -c release --arch arm64`
2. 组装 `KbSound.app/Contents/{MacOS,Resources}`
3. 写 `Info.plist`（`LSUIElement=true`、`CFBundleIdentifier=com.kbsound.KbSound`、
   `LSMinimumSystemVersion=26.0`）
4. 拷贝 `Packs/` 到 `Contents/Resources/`
5. `codesign --force --deep --sign -` ad-hoc 签名

**bundle identifier 一旦确定不要再改**，否则辅助功能授权失效、需要重新授权。

## 11. 测试策略

`swift test` 覆盖纯逻辑（不需要权限和硬件）：

- `SoundPack`：合法 manifest 解析；缺 `defaults`；`keys` 含非数字键；
  引用不存在的 wav；`up` 缺省
- 查找优先级：`keys[k].down` → `defaults.down` → nil
- `SoundPackLoader`：两个目录合并；同 id 时用户包覆盖内置包；
  坏包被跳过且不影响好包
- `Settings`：默认值；音量钳制（-1 → 0，2 → 1）；持久化往返
  （测试用独立 suite name 的 `UserDefaults`，不污染真实配置）

按 TDD 推进：先写测试看它失败，再实现。

**无法单测、走手动验证**（实现完成后提供清单）：CGEventTap 行为、
音频延迟、权限流程、开机自启、菜单栏外观。

## 12. 已知风险

1. **延迟不达标** —— 若 `scheduleBuffer` 路径仍偏慢，退路有两条：
   用 `AudioUnitSetProperty` 调小输出设备的 buffer frame size，
   或改用 `AVAudioSourceNode` 自己混音。先测量再优化，别提前上手段。
   （注意 macOS 上没有 `AVAudioSession`，那是 iOS 的 API。）
2. **macOS 27 上 CGEventTap 行为变化** —— 用户反馈同类 app 在 27 上失效。
   实现第一步就是写一个 20 行的最小 tap 验证程序，**先确认这条路在 27 上通**，
   再往下做。这是整个项目的最大未知数。
3. **Liquid Glass API 可用性** —— `NSGlassEffectView` / `.glassEffect()` 是 26+。
   本设计不在 popover 内部使用玻璃材质，因此不受影响。
