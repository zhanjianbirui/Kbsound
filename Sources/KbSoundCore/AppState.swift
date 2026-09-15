import AVFoundation
import Foundation
import Observation
import os

/// 把监听、音频、偏好、权限串起来，作为界面的唯一数据源。
@MainActor
@Observable
public final class AppState {
    public enum Status: Equatable {
        case ok
        case needsAccessibility
        case failed(String)
    }

    private static let logger = Logger(subsystem: "com.kbsound", category: "AppState")

    public private(set) var packs: [PackRef] = []
    public private(set) var status: Status = .ok

    public var isEnabled: Bool {
        didSet {
            settings.isEnabled = isEnabled
            isEnabled ? startTap() : tap.stop()
        }
    }

    public var volume: Double {
        didSet {
            settings.volume = volume
            player.volume = Float(volume)
        }
    }

    public var selectedPackID: String {
        didSet {
            guard selectedPackID != oldValue else { return }
            settings.packID = selectedPackID
            loadSelectedPack()
        }
    }

    public var isLoginItemEnabled: Bool {
        didSet {
            guard isLoginItemEnabled != oldValue else { return }
            do {
                try LoginItem.setEnabled(isLoginItemEnabled)
            } catch {
                Self.logger.error("开机自启设置失败：\(error.localizedDescription, privacy: .public)")
                isLoginItemEnabled = LoginItem.isEnabled
            }
        }
    }

    @ObservationIgnored private let settings: Settings
    @ObservationIgnored private let loader: SoundPackLoader
    @ObservationIgnored private let player = AudioPlayer()
    @ObservationIgnored private var tap: KeyEventTap!
    @ObservationIgnored private var loadedPack: LoadedPack?
    @ObservationIgnored private var permissionTimer: Timer?
    /// 导入的音效包装到这里。为 nil 时界面不显示导入入口。
    @ObservationIgnored private let userPacksDirectory: URL?

    public init(settings: Settings = Settings(), searchPaths: [URL],
                userPacksDirectory: URL? = nil) {
        self.settings = settings
        self.loader = SoundPackLoader(searchPaths: searchPaths)
        self.userPacksDirectory = userPacksDirectory
        self.isEnabled = settings.isEnabled
        self.volume = settings.volume
        self.selectedPackID = settings.packID
        self.isLoginItemEnabled = LoginItem.isEnabled

        self.packs = loader.availablePacks()
        // 存着的包可能已被删除，回退到第一个可用的
        if !packs.contains(where: { $0.id == selectedPackID }), let first = packs.first {
            selectedPackID = first.id
        }

        self.tap = KeyEventTap { [weak self] keyCode, phase in
            self?.playSound(keyCode: keyCode, phase: phase)
        }
    }

    /// 启动监听与音频。界面就绪后调用。
    public func start() {
        player.volume = Float(volume)
        loadSelectedPack()
        if isEnabled { startTap() }
    }

    public func stop() {
        permissionTimer?.invalidate()
        permissionTimer = nil
        tap.stop()
        player.stop()
    }

    public var canImportPacks: Bool { userPacksDirectory != nil }

    /// 导入一个外部音效包并立刻切换过去。失败时抛出，界面状态保持原样。
    public func importPack(from source: URL) throws {
        guard let userPacksDirectory else { throw PackImporter.ImportError.unrecognizedFormat }
        let ref = try PackImporter.importPack(from: source, into: userPacksDirectory)
        packs = loader.availablePacks()
        selectedPackID = ref.id
    }

    /// 用户点击提示条时弹出系统授权对话框并打开设置面板。
    public func requestAccessibility() {
        AccessibilityPermission.requestWithPrompt()
        AccessibilityPermission.openSystemSettings()
    }

    private func playSound(keyCode: Int, phase: KeyPhase) {
        guard isEnabled, let buffer = loadedPack?.buffer(for: keyCode, phase: phase) else { return }
        player.play(buffer)
    }

    private func startTap() {
        guard AccessibilityPermission.isTrusted else {
            status = .needsAccessibility
            startPollingForPermission()
            return
        }
        if tap.start() {
            status = .ok
        } else {
            status = .failed("无法建立按键监听")
        }
    }

    /// 没权限时每 2 秒查一次；一旦拿到就停掉定时器并自动启动。
    private func startPollingForPermission() {
        guard permissionTimer == nil else { return }
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, AccessibilityPermission.isTrusted else { return }
                self.permissionTimer?.invalidate()
                self.permissionTimer = nil
                self.startTap()
            }
        }
    }

    private func loadSelectedPack() {
        guard let ref = packs.first(where: { $0.id == selectedPackID }) else {
            loadedPack = nil
            status = .failed("没有可用的音效包")
            return
        }
        do {
            let pack = try LoadedPack(ref: ref)
            try player.prepare(format: pack.format)
            loadedPack = pack
            if case .failed = status { status = .ok }
        } catch {
            Self.logger.error("加载音效包 \(ref.id, privacy: .public) 失败：\(error.localizedDescription, privacy: .public)")
            loadedPack = nil
            status = .failed("音效包加载失败：\(ref.name)")
        }
    }
}
