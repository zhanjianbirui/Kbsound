import Foundation
import Testing
@testable import KbSoundCore

@Test func defaultsAreSensible() {
    let s = Settings(defaults: InMemoryStore())
    #expect(s.isEnabled == true)
    #expect(s.volume == 0.5)
    #expect(s.packID == "com.klinkmac.mx-brown-pbt")
}

@Test func valuesRoundTrip() {
    let s = Settings(defaults: InMemoryStore())
    s.isEnabled = false
    s.volume = 0.25
    s.packID = "com.klinkmac.nk-cream"
    #expect(s.isEnabled == false)
    #expect(s.volume == 0.25)
    #expect(s.packID == "com.klinkmac.nk-cream")
}

@Test func volumeIsClampedOnWrite() {
    let s = Settings(defaults: InMemoryStore())
    s.volume = -1
    #expect(s.volume == 0)
    s.volume = 2
    #expect(s.volume == 1)
}

@Test func volumeIsClampedOnRead() {
    // 外部写坏了配置文件也不能让音量越界
    let store = InMemoryStore()
    store.set(99.0, forKey: "KbSound.volume")
    #expect(Settings(defaults: store).volume == 1)
}

@Test func settingsPersistAcrossInstances() {
    let store = InMemoryStore()
    Settings(defaults: store).volume = 0.8
    #expect(Settings(defaults: store).volume == 0.8)
}

/// 真正的 `UserDefaults` 必须满足同一份协议契约——内存 fake 不能掩盖签名不匹配。
@Test func userDefaultsConformsToSettingsStore() {
    let store: SettingsStore = UserDefaults.standard
    #expect(store is UserDefaults)
}
