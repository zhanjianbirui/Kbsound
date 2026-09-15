import AppKit
import os

/// 菜单栏图标。
///
/// 符号名写错时 `NSImage(systemSymbolName:)` 返回 nil，按钮会变成一块空白——
/// 用户看到的就是「菜单栏里什么都没有」，且完全没有报错。曾经用过并不存在的
/// `keyboard.slash`，导致没有辅助功能权限时图标整个消失。
/// 所以这里一律走兜底，绝不把 nil 交给按钮。
public enum MenuBarIcon {
    /// 有声音时。
    public static let activeSymbol = "keyboard"
    /// 静音或未就绪时。注意不存在 `keyboard.slash`，用喇叭划线表达「没声音」。
    public static let inactiveSymbol = "speaker.slash"

    public static var allSymbolNames: [String] { [activeSymbol, inactiveSymbol] }

    private static let logger = Logger(subsystem: "com.kbsound", category: "MenuBar")

    public static func image(active: Bool) -> NSImage? {
        image(symbolName: active ? activeSymbol : inactiveSymbol)
    }

    /// 取符号图像；符号不存在时退回到 `activeSymbol`，宁可图标语义不准也不能消失。
    public static func image(symbolName: String) -> NSImage? {
        let description = symbolName == inactiveSymbol ? "键盘音效已关闭" : "键盘音效"
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: description) {
            image.isTemplate = true
            return image
        }
        logger.error("SF Symbol \(symbolName, privacy: .public) 不存在，退回 \(activeSymbol, privacy: .public)")
        let fallback = NSImage(systemSymbolName: activeSymbol, accessibilityDescription: description)
        fallback?.isTemplate = true
        return fallback
    }
}
