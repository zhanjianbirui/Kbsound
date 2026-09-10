import Cocoa

// 输出不接终端时 stdout 默认是块缓冲，敲键的日志会堵在缓冲区里看不见。
// 这个探针的全部意义就是给人看实时反馈，所以关掉缓冲。
setbuf(stdout, nil)

guard AXIsProcessTrusted() else {
    print("❌ 无辅助功能权限。请到 系统设置 > 隐私与安全性 > 辅助功能 勾选运行本程序的终端，然后重试。")
    exit(1)
}

let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)

let callback: CGEventTapCallBack = { _, type, event, _ in
    switch type {
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
        print("⚠️  tap 被系统禁用，重新启用")
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
    print("❌ CGEvent.tapCreate 返回 nil —— 这条路在本系统上不通")
    exit(1)
}

let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)
print("✅ tap 已建立。随便敲几个键，Ctrl+C 退出。")
CFRunLoopRun()
