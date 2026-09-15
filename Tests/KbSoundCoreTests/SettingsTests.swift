import Foundation
import Testing
@testable import KbSoundCore

/// 纯内存的 `SettingsStore`，让每个测试完全隔离且不碰磁盘。
///
/// 曾经用过独立的 `UserDefaults` suite，但两种写法都有问题：可复用的递增套件名会让
/// 上一轮的脏数据在冷启动时被读到（`defaultsAreSensible` 随机失败），而唯一套件名
/// 即便清空了数据，cfprefsd 仍会在 `~/Library/Preferences` 留下空 plist 文件。
private final class InMemoryStore: SettingsStore {
    private var values: [String: Any] = [:]
    private var registered: [String: Any] = [:]

    func bool(forKey key: String) -> Bool { value(forKey: key) as? Bool ?? false }
    func double(forKey key: String) -> Double { value(forKey: key) as? Double ?? 0 }
    func string(forKey key: String) -> String? { value(forKey: key) as? String }

    func set(_ value: Any?, forKey key: String) {
        if let value { values[key] = value } else { values.removeValue(forKey: key) }
    }

    /// 与 `UserDefaults.register` 语义一致：只在没有显式写入时兜底。
    func register(defaults registrationDictionary: [String: Any]) {
        registered.merge(registrationDictionary) { current, _ in current }
    }

    private func value(forKey key: String) -> Any? { values[key] ?? registered[key] }
}

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
