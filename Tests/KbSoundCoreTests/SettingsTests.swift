import Foundation
import Testing
@testable import KbSoundCore

/// 每个测试用独立 suite，互不干扰，也不碰 UserDefaults.standard。
private func isolatedSettings() -> Settings {
    let suite = "com.kbsound.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    return Settings(defaults: defaults)
}

@Test func defaultsAreSensible() {
    let s = isolatedSettings()
    #expect(s.isEnabled == true)
    #expect(s.volume == 0.5)
    #expect(s.packID == "com.klinkmac.mx-brown-pbt")
}

@Test func valuesRoundTrip() {
    let s = isolatedSettings()
    s.isEnabled = false
    s.volume = 0.25
    s.packID = "com.klinkmac.nk-cream"
    #expect(s.isEnabled == false)
    #expect(s.volume == 0.25)
    #expect(s.packID == "com.klinkmac.nk-cream")
}

@Test func volumeIsClampedOnWrite() {
    let s = isolatedSettings()
    s.volume = -1
    #expect(s.volume == 0)
    s.volume = 2
    #expect(s.volume == 1)
}

@Test func volumeIsClampedOnRead() {
    // 外部写坏了配置文件也不能让音量越界
    let suite = "com.kbsound.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.set(99.0, forKey: "KbSound.volume")
    #expect(Settings(defaults: defaults).volume == 1)
}

@Test func settingsPersistAcrossInstances() {
    let suite = "com.kbsound.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    Settings(defaults: defaults).volume = 0.8
    #expect(Settings(defaults: defaults).volume == 0.8)
}
