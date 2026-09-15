import ApplicationServices
import Cocoa

/// 辅助功能权限——没有它就无法建立 CGEventTap。
///
/// 权限是按 bundle identifier 授予的，所以必须以打包好的 .app 运行，
/// 否则每次重新编译都要重新授权。
public enum AccessibilityPermission {
    public static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// 这里不用 `kAXTrustedCheckOptionPrompt`：它是导入的全局 `var`，在 Swift 6
    /// 严格并发下被判为共享可变状态而无法引用。字面值已用运行时打印核对过。
    private static let promptOptionKey = "AXTrustedCheckOptionPrompt"

    /// 弹出系统的授权提示。只在用户主动点击时调用，别在启动时骚扰。
    public static func requestWithPrompt() {
        _ = AXIsProcessTrustedWithOptions([promptOptionKey: true] as CFDictionary)
    }

    /// 直接打开 系统设置 > 隐私与安全性 > 辅助功能。
    public static func openSystemSettings() {
        let url = URL(string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
