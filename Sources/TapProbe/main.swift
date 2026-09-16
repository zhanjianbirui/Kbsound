import Cocoa

// When stdout is not attached to a terminal it is block-buffered by default, so the
// keystroke log would sit in the buffer unseen. This probe exists purely to give a
// human live feedback, so turn buffering off.
setbuf(stdout, nil)

guard AXIsProcessTrusted() else {
    print("❌ No Accessibility permission. Tick the terminal running this program in System Settings › Privacy & Security › Accessibility, then try again.")
    exit(1)
}

let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)

let callback: CGEventTapCallBack = { _, type, event, _ in
    switch type {
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
        print("⚠️  The system disabled the tap; re-enabling")
    case .keyDown, .keyUp:
        let code = event.getIntegerValueField(.keyboardEventKeycode)
        let repeated = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        print("\(type == .keyDown ? "↓" : "↑") keyCode=\(code)\(repeated ? " (repeat)" : "")")
    default:
        break
    }
    return Unmanaged.passUnretained(event)
}

guard let tap = CGEvent.tapCreate(
    tap: .cghidEventTap,
    place: .headInsertEventTap,
    options: .listenOnly,
    eventsOfInterest: CGEventMask(mask),
    callback: callback,
    userInfo: nil
) else {
    print("❌ CGEvent.tapCreate returned nil — this route is not available on this system")
    exit(1)
}

let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)
print("✅ Tap installed. Type a few keys; Ctrl+C to quit.")
CFRunLoopRun()
