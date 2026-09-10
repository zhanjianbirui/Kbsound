import Foundation

/// 用户偏好的持久化。开机自启不在这里——那以 SMAppService 的状态为唯一数据源。
public final class Settings {
    public static let defaultPackID = "com.klinkmac.mx-brown-pbt"

    private enum Key {
        static let enabled = "KbSound.enabled"
        static let volume = "KbSound.volume"
        static let packID = "KbSound.packID"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
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

    /// 读写都钳制到 0...1——外部改坏配置也不该让音量越界。
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
