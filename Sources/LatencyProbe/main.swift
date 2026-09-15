import Cocoa
import CoreAudio
import Darwin

// 实时反馈用，关掉 stdout 缓冲
setbuf(stdout, nil)

// 顶层代码默认是 MainActor 隔离的，但 C 回调里要读它，所以显式标为 nonisolated
nonisolated(unsafe) var timebase = mach_timebase_info_data_t()
mach_timebase_info(&timebase)

/// mach 时钟刻度 → 毫秒
func ms(fromTicks ticks: UInt64) -> Double {
    Double(ticks) * Double(timebase.numer) / Double(timebase.denom) / 1_000_000
}

func outputDeviceBufferFrames() -> UInt32 {
    var device = AudioDeviceID(0)
    var deviceSize = UInt32(MemoryLayout<AudioDeviceID>.size)
    var deviceAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    AudioObjectGetPropertyData(
        AudioObjectID(kAudioObjectSystemObject), &deviceAddress, 0, nil, &deviceSize, &device)
    var frames: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyBufferFrameSize,
        mScope: kAudioObjectPropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
    AudioObjectGetPropertyData(device, &address, 0, nil, &size, &frames)
    return frames
}

guard AXIsProcessTrusted() else {
    print("❌ 无辅助功能权限。请到 系统设置 > 隐私与安全性 > 辅助功能 勾选运行本程序的终端，然后重试。")
    exit(1)
}

nonisolated(unsafe) var samples: [Double] = []

let callback: CGEventTapCallBack = { _, type, event, _ in
    guard type == .keyDown,
          event.getIntegerValueField(.keyboardEventAutorepeat) == 0 else {
        return Unmanaged.passUnretained(event)
    }
    // CGEvent.timestamp 是事件产生时的 mach 绝对时间；与此刻之差即投递延迟
    let delivery = ms(fromTicks: mach_absolute_time() &- event.timestamp)
    samples.append(delivery)
    let code = event.getIntegerValueField(.keyboardEventKeycode)
    print(String(format: "↓ keyCode=%-4d 事件投递 %6.2f ms", code, delivery))

    if samples.count % 10 == 0 {
        let sorted = samples.sorted()
        print(String(format: "   ── 已采 %d 次：中位 %.2f ms，P90 %.2f ms，设备 buffer %d frames",
                     sorted.count, sorted[sorted.count / 2],
                     sorted[min(sorted.count - 1, sorted.count * 9 / 10)],
                     outputDeviceBufferFrames()))
    }
    return Unmanaged.passUnretained(event)
}

let mask = (1 << CGEventType.keyDown.rawValue)
guard let tap = CGEvent.tapCreate(
    tap: .cghidEventTap, place: .headInsertEventTap, options: .listenOnly,
    eventsOfInterest: CGEventMask(mask), callback: callback, userInfo: nil
) else {
    print("❌ CGEvent.tapCreate 返回 nil")
    exit(1)
}

let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)

print("设备 buffer: \(outputDeviceBufferFrames()) frames")
print("✅ 开始敲键盘（至少 20 下），Ctrl+C 退出。\n")
CFRunLoopRun()
