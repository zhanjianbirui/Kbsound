@testable import KbSoundCore

/// 纯内存的 `SettingsStore`，让每个测试完全隔离且不碰磁盘。
///
/// 曾经用过独立的 `UserDefaults` suite，但两种写法都有问题：可复用的递增套件名会让
/// 上一轮的脏数据在冷启动时被读到（`defaultsAreSensible` 随机失败），而唯一套件名
/// 即便清空了数据，cfprefsd 仍会在 `~/Library/Preferences` 留下空 plist 文件。
final class InMemoryStore: SettingsStore {
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
