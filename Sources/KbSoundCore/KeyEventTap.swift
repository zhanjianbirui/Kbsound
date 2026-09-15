import Cocoa
import os

/// 全局按键监听。需要辅助功能权限。
///
/// 回调挂在主 run loop 上，所以整个类型都是 `@MainActor`。
@MainActor
public final class KeyEventTap {
    private static let logger = Logger(subsystem: "com.kbsound", category: "EventTap")

    private let handler: @MainActor (Int, KeyPhase) -> Void
    private var machPort: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var modifiers = ModifierTracker()

    public init(handler: @escaping @MainActor (Int, KeyPhase) -> Void) {
        self.handler = handler
    }

    public var isRunning: Bool { machPort != nil }

    /// 建立 tap。返回 false 表示失败——通常是没有辅助功能权限。
    public func start() -> Bool {
        guard machPort == nil else { return true }

        let mask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)

        guard let port = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: tapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            Self.logger.error("CGEvent.tapCreate 失败——通常是缺少辅助功能权限")
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)

        machPort = port
        runLoopSource = source
        modifiers.reset()
        Self.logger.info("事件监听已启动")
        return true
    }

    public func stop() {
        if let port = machPort {
            CGEvent.tapEnable(tap: port, enable: false)
            CFMachPortInvalidate(port)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        machPort = nil
        runLoopSource = nil
        modifiers.reset()
        Self.logger.info("事件监听已停止")
    }

    /// 只接收标量：`CGEvent` 不是 `Sendable`，跨进 `MainActor.assumeIsolated`
    /// 闭包会被判定为 sending。字段在回调里就地取出，这里只处理逻辑。
    fileprivate func handle(type: CGEventType, keyCode: Int, isAutorepeat: Bool) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // 系统在卡顿或用户输入时会主动禁用 tap。
            // 不重新启用的话就会出现「用着用着没声了」——这是同类工具最常见的故障。
            if let port = machPort {
                CGEvent.tapEnable(tap: port, enable: true)
                modifiers.reset()
                Self.logger.warning("tap 被系统禁用，已重新启用")
            }

        case .keyDown, .keyUp:
            // 长按不断重复的事件不发声——真实键盘按住不放也不会一直响。
            guard !isAutorepeat else { return }
            handler(keyCode, type == .keyDown ? .down : .up)

        case .flagsChanged:
            handler(keyCode, modifiers.phase(forKeyCode: keyCode))

        default:
            break
        }
    }
}

/// C 函数指针不能捕获上下文，靠 userInfo 把 self 传进来。
private let tapCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let tap = Unmanaged<KeyEventTap>.fromOpaque(userInfo).takeUnretainedValue()
    let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
    let isAutorepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
    // 回调运行在主 run loop 上，所以这里确实处于 MainActor。
    MainActor.assumeIsolated {
        tap.handle(type: type, keyCode: keyCode, isAutorepeat: isAutorepeat)
    }
    return Unmanaged.passUnretained(event)
}
