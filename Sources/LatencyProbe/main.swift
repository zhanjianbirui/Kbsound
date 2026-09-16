import Cocoa
import CoreAudio
import Darwin

// Live feedback, so turn stdout buffering off.
setbuf(stdout, nil)

// Top-level code is MainActor-isolated by default, but the C callback reads this, so
// it is marked nonisolated explicitly.
nonisolated(unsafe) var timebase = mach_timebase_info_data_t()
mach_timebase_info(&timebase)

/// mach ticks → milliseconds
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
    print("❌ No Accessibility permission. Tick the terminal running this program in System Settings › Privacy & Security › Accessibility, then try again.")
    exit(1)
}

nonisolated(unsafe) var samples: [Double] = []

let callback: CGEventTapCallBack = { _, type, event, _ in
    guard type == .keyDown,
          event.getIntegerValueField(.keyboardEventAutorepeat) == 0 else {
        return Unmanaged.passUnretained(event)
    }
    // CGEvent.timestamp is the mach absolute time the event was created; the difference
    // from now is the delivery latency.
    let delivery = ms(fromTicks: mach_absolute_time() &- event.timestamp)
    samples.append(delivery)
    let code = event.getIntegerValueField(.keyboardEventKeycode)
    print(String(format: "↓ keyCode=%-4d delivery %6.2f ms", code, delivery))

    if samples.count % 10 == 0 {
        let sorted = samples.sorted()
        print(String(format: "   ── %d samples: median %.2f ms, P90 %.2f ms, device buffer %d frames",
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
    print("❌ CGEvent.tapCreate returned nil")
    exit(1)
}

let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)

print("Device buffer: \(outputDeviceBufferFrames()) frames")
print("✅ Start typing (at least 20 keys); Ctrl+C to quit.\n")
CFRunLoopRun()
