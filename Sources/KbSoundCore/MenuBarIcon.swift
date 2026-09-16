import AppKit
import os

/// The menu bar icon.
///
/// `NSImage(systemSymbolName:)` returns nil for a misspelled symbol name, which leaves
/// the status item blank — the user simply sees nothing in the menu bar, with no error
/// anywhere. An earlier version used `keyboard.slash`, which does not exist, and the
/// icon vanished entirely whenever Accessibility permission was missing.
/// Hence the fallback here: nil is never handed to the button.
public enum MenuBarIcon {
    /// Shown while sounds are playing.
    public static let activeSymbol = "keyboard"
    /// Shown while muted or not ready. Note that `keyboard.slash` does not exist, so a
    /// crossed-out speaker carries the "no sound" meaning.
    public static let inactiveSymbol = "speaker.slash"

    public static var allSymbolNames: [String] { [activeSymbol, inactiveSymbol] }

    private static let logger = Logger(subsystem: "com.kbsound", category: "MenuBar")

    public static func image(active: Bool) -> NSImage? {
        image(symbolName: active ? activeSymbol : inactiveSymbol)
    }

    /// Looks up a symbol image; falls back to `activeSymbol` when the symbol is missing,
    /// since an icon with imprecise meaning still beats no icon at all.
    public static func image(symbolName: String) -> NSImage? {
        let description = symbolName == inactiveSymbol
            ? loc("Keyboard sounds off")
            : loc("Keyboard sounds")
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: description) {
            image.isTemplate = true
            return image
        }
        logger.error("SF Symbol \(symbolName, privacy: .public) does not exist, falling back to \(activeSymbol, privacy: .public)")
        let fallback = NSImage(systemSymbolName: activeSymbol, accessibilityDescription: description)
        fallback?.isTemplate = true
        return fallback
    }
}
