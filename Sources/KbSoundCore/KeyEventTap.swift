import Cocoa
import os

/// Global key listener. Requires Accessibility permission.
///
/// The callback is installed on the main run loop, so the whole type is `@MainActor`.
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

    /// Installs the tap. Returns false on failure — usually a missing Accessibility grant.
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
            Self.logger.error("CGEvent.tapCreate failed — usually a missing Accessibility grant")
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)

        machPort = port
        runLoopSource = source
        modifiers.reset()
        Self.logger.info("Event tap started")
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
        Self.logger.info("Event tap stopped")
    }

    /// Takes scalars only: `CGEvent` is not `Sendable`, so passing one into the
    /// `MainActor.assumeIsolated` closure would count as sending it. The fields are
    /// read in the callback itself; this method only holds the logic.
    fileprivate func handle(type: CGEventType, keyCode: Int, isAutorepeat: Bool) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // The system disables the tap on its own when it stalls or during user input.
            // Without re-enabling it you get the classic "it went silent after a while"
            // failure that plagues tools of this kind.
            if let port = machPort {
                CGEvent.tapEnable(tap: port, enable: true)
                modifiers.reset()
                Self.logger.warning("The system disabled the tap; re-enabled it")
            }

        case .keyDown, .keyUp:
            // Autorepeat events stay silent — a real keyboard does not keep clicking
            // while a key is held down.
            guard !isAutorepeat else { return }
            handler(keyCode, type == .keyDown ? .down : .up)

        case .flagsChanged:
            handler(keyCode, modifiers.phase(forKeyCode: keyCode))

        default:
            break
        }
    }
}

/// A C function pointer cannot capture context, so `self` is passed through `userInfo`.
private let tapCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let tap = Unmanaged<KeyEventTap>.fromOpaque(userInfo).takeUnretainedValue()
    let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
    let isAutorepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
    // The callback runs on the main run loop, so we really are on the MainActor here.
    MainActor.assumeIsolated {
        tap.handle(type: type, keyCode: keyCode, isAutorepeat: isAutorepeat)
    }
    return Unmanaged.passUnretained(event)
}
