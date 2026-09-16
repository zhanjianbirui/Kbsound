import AVFoundation
import Foundation
import Observation
import os

/// Ties the event tap, audio engine, preferences and permissions together and
/// acts as the single source of truth for the UI.
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
                Self.logger.error("Failed to change the login item: \(error.localizedDescription, privacy: .public)")
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
    /// Where imported packs are written. When nil, the UI hides the import entry point.
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
        // The stored pack may have been deleted; fall back to the first available one.
        if !packs.contains(where: { $0.id == selectedPackID }), let first = packs.first {
            selectedPackID = first.id
        }

        self.tap = KeyEventTap { [weak self] keyCode, phase in
            self?.playSound(keyCode: keyCode, phase: phase)
        }
    }

    /// Starts the event tap and the audio engine. Call once the UI is ready.
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

    /// Imports an external sound pack and switches to it. On failure it throws and
    /// the UI state is left untouched.
    public func importPack(from source: URL) throws {
        guard let userPacksDirectory else { throw PackImporter.ImportError.unrecognizedFormat }
        let ref = try PackImporter.importPack(from: source, into: userPacksDirectory)
        packs = loader.availablePacks()
        selectedPackID = ref.id
    }

    /// Shows the system permission prompt and opens the settings pane when the user
    /// taps the banner.
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
            Self.logger.info("No Accessibility permission yet; showing the banner and polling")
            status = .needsAccessibility
            startPollingForPermission()
            return
        }
        if tap.start() {
            status = .ok
        } else {
            status = .failed(loc("Could not start the key listener."))
        }
    }

    /// Polls every 2 seconds while permission is missing; stops the timer and starts
    /// automatically as soon as the grant lands.
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
            status = .failed(loc("No sound pack available."))
            return
        }
        do {
            let pack = try LoadedPack(ref: ref)
            try player.prepare(format: pack.format)
            loadedPack = pack
            if case .failed = status { status = .ok }
        } catch {
            Self.logger.error("Failed to load sound pack \(ref.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
            loadedPack = nil
            status = .failed(loc("Could not load sound pack: \(ref.name)"))
        }
    }
}
