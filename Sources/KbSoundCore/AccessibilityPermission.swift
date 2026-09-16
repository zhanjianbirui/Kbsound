import ApplicationServices
import Cocoa

/// Accessibility permission — without it a `CGEventTap` cannot be created.
///
/// The grant is keyed by bundle identifier, so the app has to run as a packaged
/// `.app`; otherwise every rebuild would need a fresh authorization.
public enum AccessibilityPermission {
    public static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// `kAXTrustedCheckOptionPrompt` is not used here: it is an imported global `var`,
    /// which Swift 6 strict concurrency treats as shared mutable state and refuses to
    /// reference. The literal below was verified against it at runtime.
    private static let promptOptionKey = "AXTrustedCheckOptionPrompt"

    /// Shows the system permission prompt. Only call this on an explicit user action —
    /// never nag at launch.
    public static func requestWithPrompt() {
        _ = AXIsProcessTrustedWithOptions([promptOptionKey: true] as CFDictionary)
    }

    /// Opens System Settings › Privacy & Security › Accessibility directly.
    public static func openSystemSettings() {
        let url = URL(string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
