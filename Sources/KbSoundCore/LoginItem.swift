import Foundation
import ServiceManagement
import os

/// Launch at login. `SMAppService`'s status is the single source of truth — no copy in
/// UserDefaults, because the user can switch it off in System Settings and a cached
/// copy would immediately be out of sync.
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
        logger.info("Launch at login set to \(enabled, privacy: .public)")
    }
}
