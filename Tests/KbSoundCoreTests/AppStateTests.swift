import Foundation
import Testing
@testable import KbSoundCore

private let repoRoot = URL(filePath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

/// 用内存存储，测试之间互不干扰，也不在偏好目录留 plist。
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
    // 存的包不存在时应回退到第一个可用包，而不是留一个无效 id
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
