import AppKit
import SwiftUI

/// 菜单栏图标 + 点击弹出的 popover。
@MainActor
public final class MenuBarController {
    private let state: AppState
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()

    public init(state: AppState) {
        self.state = state
    }

    public func install() {
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: PopoverView(state: state))

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = icon(enabled: state.isEnabled)
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        item.button?.setAccessibilityLabel("KbSound 键盘音效")
        statusItem = item
    }

    /// 图标必须是 template，才能自动适配深浅色与菜单栏材质。
    private func icon(enabled: Bool) -> NSImage? {
        let name = enabled ? "keyboard" : "keyboard.slash"
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "键盘音效")
        image?.isTemplate = true
        return image
    }

    public func refreshIcon() {
        let active = state.isEnabled && state.status == .ok
        statusItem?.button?.image = icon(enabled: active)
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
        refreshIcon()
    }
}
