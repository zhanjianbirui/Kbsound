import Foundation

/// Persistence for user preferences. Launch at login lives elsewhere — `SMAppService`
/// is the single source of truth for that.
public final class Settings {
    public static let defaultPackID = "com.klinkmac.mx-brown-pbt"

    private enum Key {
        static let enabled = "KbSound.enabled"
        static let volume = "KbSound.volume"
        static let packID = "KbSound.packID"
    }

    private let defaults: SettingsStore

    public init(defaults: SettingsStore = UserDefaults.standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.enabled: true,
            Key.volume: 0.5,
            Key.packID: Self.defaultPackID,
        ])
    }

    public var isEnabled: Bool {
        get { defaults.bool(forKey: Key.enabled) }
        set { defaults.set(newValue, forKey: Key.enabled) }
    }

    /// Clamped to 0...1 on both read and write — a stored value corrupted from outside
    /// should not push the volume out of range.
    public var volume: Double {
        get { Self.clamp(defaults.double(forKey: Key.volume)) }
        set { defaults.set(Self.clamp(newValue), forKey: Key.volume) }
    }

    public var packID: String {
        get { defaults.string(forKey: Key.packID) ?? Self.defaultPackID }
        set { defaults.set(newValue, forKey: Key.packID) }
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}
