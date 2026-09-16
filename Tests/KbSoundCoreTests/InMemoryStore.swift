@testable import KbSoundCore

/// A purely in-memory `SettingsStore`, so every test is isolated and never touches disk.
///
/// A separate `UserDefaults` suite was tried first, but both spellings have problems: a
/// reusable incrementing suite name lets the previous run's dirty data be read back on a
/// cold start (`defaultsAreSensible` failed at random), while a unique suite name still
/// leaves an empty plist in `~/Library/Preferences` via cfprefsd even after the data is
/// cleared.
final class InMemoryStore: SettingsStore {
    private var values: [String: Any] = [:]
    private var registered: [String: Any] = [:]

    func bool(forKey key: String) -> Bool { value(forKey: key) as? Bool ?? false }
    func double(forKey key: String) -> Double { value(forKey: key) as? Double ?? 0 }
    func string(forKey key: String) -> String? { value(forKey: key) as? String }

    func set(_ value: Any?, forKey key: String) {
        if let value { values[key] = value } else { values.removeValue(forKey: key) }
    }

    /// Matches `UserDefaults.register`: only fills in when nothing was written explicitly.
    func register(defaults registrationDictionary: [String: Any]) {
        registered.merge(registrationDictionary) { current, _ in current }
    }

    private func value(forKey key: String) -> Any? { values[key] ?? registered[key] }
}
