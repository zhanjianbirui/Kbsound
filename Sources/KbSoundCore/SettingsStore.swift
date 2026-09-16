import Foundation

/// The key-value store `Settings` depends on.
///
/// In production this is `UserDefaults`; the protocol exists so tests can use a pure
/// in-memory implementation and leave no plist behind in `~/Library/Preferences` —
/// `removePersistentDomain` clears the data, but cfprefsd still leaves an empty file.
public protocol SettingsStore: AnyObject {
    func bool(forKey key: String) -> Bool
    func double(forKey key: String) -> Double
    func string(forKey key: String) -> String?
    func set(_ value: Any?, forKey key: String)
    func register(defaults registrationDictionary: [String: Any])
}

/// `UserDefaults` already matches the protocol's signatures exactly; nothing to add.
extension UserDefaults: SettingsStore {}
