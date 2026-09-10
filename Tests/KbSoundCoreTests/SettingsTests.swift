import Foundation
import Testing
@testable import KbSoundCore

/// 独立 UserDefaults suite 的 fixture，测试结束后自动清理。
private struct IsolatedSettingsFixture: ~Copyable {
    let suiteName: String
    let defaults: UserDefaults
    let settings: Settings

    init() {
        suiteName = "com.kbsound.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        settings = Settings(defaults: defaults)
    }

    deinit {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        UserDefaults.standard.synchronize()
        let fileManager = FileManager.default
        let prefsDir = NSHomeDirectory() + "/Library/Preferences/"
        let plistPath = prefsDir + suiteName + ".plist"
        try? fileManager.removeItem(atPath: plistPath)
    }
}

@Test func defaultsAreSensible() {
    let fixture = IsolatedSettingsFixture()
    let s = fixture.settings
    #expect(s.isEnabled == true)
    #expect(s.volume == 0.5)
    #expect(s.packID == "com.klinkmac.mx-brown-pbt")
}

@Test func valuesRoundTrip() {
    let fixture = IsolatedSettingsFixture()
    let s = fixture.settings
    s.isEnabled = false
    s.volume = 0.25
    s.packID = "com.klinkmac.nk-cream"
    #expect(s.isEnabled == false)
    #expect(s.volume == 0.25)
    #expect(s.packID == "com.klinkmac.nk-cream")
}

@Test func volumeIsClampedOnWrite() {
    let fixture = IsolatedSettingsFixture()
    let s = fixture.settings
    s.volume = -1
    #expect(s.volume == 0)
    s.volume = 2
    #expect(s.volume == 1)
}

@Test func volumeIsClampedOnRead() {
    // 外部写坏了配置文件也不能让音量越界
    let suite = "com.kbsound.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer {
        UserDefaults.standard.removePersistentDomain(forName: suite)
        UserDefaults.standard.synchronize()
        let fileManager = FileManager.default
        let prefsDir = NSHomeDirectory() + "/Library/Preferences/"
        let plistPath = prefsDir + suite + ".plist"
        try? fileManager.removeItem(atPath: plistPath)
    }
    defaults.set(99.0, forKey: "KbSound.volume")
    #expect(Settings(defaults: defaults).volume == 1)
}

@Test func settingsPersistAcrossInstances() {
    let suite = "com.kbsound.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer {
        UserDefaults.standard.removePersistentDomain(forName: suite)
        UserDefaults.standard.synchronize()
        let fileManager = FileManager.default
        let prefsDir = NSHomeDirectory() + "/Library/Preferences/"
        let plistPath = prefsDir + suite + ".plist"
        try? fileManager.removeItem(atPath: plistPath)
    }
    Settings(defaults: defaults).volume = 0.8
    #expect(Settings(defaults: defaults).volume == 0.8)
}
