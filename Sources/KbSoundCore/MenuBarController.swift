import AppKit
import SwiftUI
import os

/// The menu bar icon and the popover it opens.
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
            // Switch to applicationDefined for the duration of the modal panel and
            // restore afterwards; otherwise the popover closes itself the moment the
            // NSOpenPanel appears.
            let previous = popover.behavior
            popover.behavior = .applicationDefined
            defer { popover.behavior = previous }
            work()
        }
        let hosting = NSHostingController(rootView: content)
        // Without this, NSHostingController never passes SwiftUI's ideal size on to the
        // popover, which then uses a too-small default and clips the bottom half of the
        // panel.
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = MenuBarIcon.image(active: state.isEnabled)
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        item.button?.setAccessibilityLabel(loc("KbSound keyboard sounds"))
        statusItem = item
        Self.logger.info("Status item installed")
    }

    public func refreshIcon() {
        let active = state.isEnabled && state.status == .ok
        statusItem?.button?.image = MenuBarIcon.image(active: active)
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button else {
            Self.logger.error("statusItem.button is nil")
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
