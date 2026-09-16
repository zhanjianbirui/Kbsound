import CoreAudio
import Foundation
import os

/// Shrinks the default output device's IO buffer to narrow the gap between key and sound.
///
/// Measured on a 48 kHz device: the system default of 512 frames = 10.67 ms leaves an
/// average scheduling wait of about 8 ms; at 128 frames it drops to about 2.7 ms.
///
/// Note that the buffer size is **shared by the whole device** — CoreAudio arbitrates
/// between the apps asking for it. Going too low can make other audio apps glitch,
/// which is why this settles on 128 rather than the device minimum.
public enum OutputDeviceLatency {
    private static let logger = Logger(subsystem: "com.kbsound", category: "OutputLatency")

    /// Target buffer size. 128 frames is 2.67 ms at 48 kHz.
    public static let preferredFrames: UInt32 = 128

    /// Clamps the request into the range the device actually supports.
    public static func clamped(_ desired: UInt32, to range: ClosedRange<UInt32>) -> UInt32 {
        min(max(desired, range.lowerBound), range.upperBound)
    }

    /// Best-effort shrink of the default output device's buffer. Failures are only
    /// logged — slightly more latency beats no sound at all.
    public static func minimize() {
        guard let device = defaultOutputDevice() else {
            logger.error("No default output device found, skipping the buffer change")
            return
        }
        guard let range = bufferFrameRange(of: device) else {
            logger.error("Could not read the buffer range, skipping the buffer change")
            return
        }

        var target = clamped(preferredFrames, to: range)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyBufferFrameSize,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain)
        let status = AudioObjectSetPropertyData(
            device, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &target)

        if status == noErr {
            logger.info("Output buffer set to \(target, privacy: .public) frames")
        } else {
            logger.error("Failed to set the output buffer, status \(status, privacy: .public)")
        }
    }

    private static func defaultOutputDevice() -> AudioDeviceID? {
        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device)
        return status == noErr && device != kAudioObjectUnknown ? device : nil
    }

    private static func bufferFrameRange(of device: AudioDeviceID) -> ClosedRange<UInt32>? {
        var value = AudioValueRange()
        var size = UInt32(MemoryLayout<AudioValueRange>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyBufferFrameSizeRange,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain)
        let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value)
        guard status == noErr, value.mMinimum <= value.mMaximum else { return nil }
        return UInt32(value.mMinimum)...UInt32(value.mMaximum)
    }
}
