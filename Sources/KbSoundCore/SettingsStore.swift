import Foundation

/// `Settings` 依赖的键值存储抽象。
///
/// 生产环境就是 `UserDefaults`；抽出协议是为了让测试用纯内存实现，
/// 不在 `~/Library/Preferences` 里留下 plist 文件——`removePersistentDomain`
/// 能清空数据，但 cfprefsd 仍会留下空文件。
public protocol SettingsStore: AnyObject {
    func bool(forKey key: String) -> Bool
    func double(forKey key: String) -> Double
    func string(forKey key: String) -> String?
    func set(_ value: Any?, forKey key: String)
    func register(defaults registrationDictionary: [String: Any])
}

/// `UserDefaults` 的方法签名与协议完全一致，无需额外实现。
extension UserDefaults: SettingsStore {}
