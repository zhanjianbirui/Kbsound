import AppKit
import SwiftUI
import os

/// 菜单栏图标 + 点击弹出的 popover。
@MainActor
public final class MenuBarController {
    private static let logger = Logger(subsystem: "com.kbsound", category: "MenuBar")

    private let state: AppState
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()

    public init(state: AppState) {
        self.state = state
    }

    public func install() {
        popover.behavior = .transient
        let content = PopoverView(state: state) { [popover] work in
            // 模态面板期间改成 applicationDefined，结束后恢复，
            // 否则 NSOpenPanel 一弹出 popover 就自己关了
            let previous = popover.behavior
            popover.behavior = .applicationDefined
            defer { popover.behavior = previous }
            work()
        }
        let hosting = NSHostingController(rootView: content)
        // 不设这个的话 NSHostingController 不会把 SwiftUI 的理想尺寸传给 popover，
        // popover 会按一个偏小的默认值显示，面板下半截被裁掉。
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = MenuBarIcon.image(active: state.isEnabled)
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        item.button?.setAccessibilityLabel("KbSound 键盘音效")
        statusItem = item
        Self.logger.info("菜单栏项已安装")
    }

    public func refreshIcon() {
        let active = state.isEnabled && state.status == .ok
        statusItem?.button?.image = MenuBarIcon.image(active: active)
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button else {
            Self.logger.error("statusItem.button 为 nil")
            return
        }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
        refreshIcon()
    }
}
