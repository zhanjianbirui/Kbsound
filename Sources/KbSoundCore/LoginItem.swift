import Foundation
import ServiceManagement
import os

/// 开机自启。以 `SMAppService` 的状态为唯一数据源，不另存 UserDefaults——
/// 用户可能在系统设置里直接关掉，存一份副本就会不同步。
public enum LoginItem {
    private static let logger = Logger(subsystem: "com.kbsound", category: "LoginItem")

    public static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    public static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
        logger.info("开机自启设为 \(enabled, privacy: .public)")
    }
}
