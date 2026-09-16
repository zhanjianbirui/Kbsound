import AVFoundation
import Foundation
import Testing
@testable import KbSoundCore

private let repoRoot = URL(filePath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

/// An in-memory store keeps tests independent and leaves no plist in the preferences
/// directory.
private func isolatedSettings() -> Settings {
    Settings(defaults: InMemoryStore())
}

@MainActor
private func makeState(settings: Settings = isolatedSettings()) -> AppState {
    AppState(settings: settings, searchPaths: [repoRoot.appending(path: "Resources/Packs")])
}

@MainActor
@Test func discoversAllBundledPacks() {
    #expect(makeState().packs.count == 21)
}

@MainActor
@Test func readsInitialValuesFromSettings() {
    let settings = isolatedSettings()
    settings.volume = 0.3
    settings.isEnabled = false
    let state = makeState(settings: settings)
    #expect(state.volume == 0.3)
    #expect(state.isEnabled == false)
}

@MainActor
@Test func writesVolumeBackToSettings() {
    let settings = isolatedSettings()
    let state = makeState(settings: settings)
    state.volume = 0.9
    #expect(settings.volume == 0.9)
}

@MainActor
@Test func writesSelectedPackBackToSettings() {
    let settings = isolatedSettings()
    let state = makeState(settings: settings)
    state.selectedPackID = "com.klinkmac.nk-cream"
    #expect(settings.packID == "com.klinkmac.nk-cream")
}

@MainActor
@Test func fallsBackToFirstPackWhenSavedPackIsGone() {
    let settings = isolatedSettings()
    settings.packID = "com.example.deleted-pack"
    let state = makeState(settings: settings)
    // When the stored pack is gone, fall back to the first available one rather than
    // keeping an invalid id
    #expect(state.packs.map(\.id).contains(state.selectedPackID))
}

@MainActor
@Test func selectedPackIDIsStableWhenSavedPackExists() {
    let settings = isolatedSettings()
    settings.packID = "com.klinkmac.topre-silent"
    #expect(makeState(settings: settings).selectedPackID == "com.klinkmac.topre-silent")
}

@MainActor
@Test func emptySearchPathYieldsNoPacksAndDoesNotCrash() {
    let ghost = URL.temporaryDirectory.appending(path: "nope-\(UUID())")
    let state = AppState(settings: isolatedSettings(), searchPaths: [ghost])
    #expect(state.packs.isEmpty)
}

// MARK: - Importing sound packs

/// Builds a minimal usable Mechvibes multi pack.
private func makeImportableSource() throws -> URL {
    let dir = URL.temporaryDirectory.appending(path: "src-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!
    for row in 0...4 {
        let file = try AVAudioFile(forWriting: dir.appending(path: "GENERIC_R\(row).wav"),
                                   settings: format.settings)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4800)!
        buffer.frameLength = 4800
        for i in 0..<4800 { buffer.floatChannelData![0][i] = 0.5 }
        try file.write(from: buffer)
    }
    try Data("""
    {"id":"com.test.imported","name":"Imported Pack","key_define_type":"multi",
     "sound":"GENERIC_R{0-4}.wav","defines":{}}
    """.utf8).write(to: dir.appending(path: "config.json"))
    return dir
}

@MainActor
@Test func importedPackAppearsInTheListAndGetsSelected() throws {
    let userDir = URL.temporaryDirectory.appending(path: "user-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: userDir) }
    let source = try makeImportableSource()
    defer { try? FileManager.default.removeItem(at: source) }

    let state = AppState(settings: isolatedSettings(),
                         searchPaths: [repoRoot.appending(path: "Resources/Packs"), userDir],
                         userPacksDirectory: userDir)
    let before = state.packs.count

    try state.importPack(from: source)

    #expect(state.packs.count == before + 1)
    #expect(state.packs.contains { $0.id == "com.test.imported" })
    #expect(state.selectedPackID == "com.test.imported")
}

@MainActor
@Test func failedImportLeavesStateUntouched() throws {
    let userDir = URL.temporaryDirectory.appending(path: "user-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: userDir) }
    let empty = URL.temporaryDirectory.appending(path: "empty-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: empty) }

    let state = AppState(settings: isolatedSettings(),
                         searchPaths: [repoRoot.appending(path: "Resources/Packs"), userDir],
                         userPacksDirectory: userDir)
    let before = state.packs.count
    let selected = state.selectedPackID

    #expect(throws: (any Error).self) { try state.importPack(from: empty) }
    #expect(state.packs.count == before)
    #expect(state.selectedPackID == selected)
}
