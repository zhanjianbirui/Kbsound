import CoreAudio
import Foundation
import os

/// 调小默认输出设备的 IO buffer，缩短按键到出声的间隔。
///
/// 实测（48kHz 设备）：系统默认 512 frames = 10.67ms，播放调度的平均等待约 8ms；
/// 降到 128 frames 后约 2.7ms。这是 spec §12 为「延迟不达标」列的第一对策。
///
/// 注意：buffer 大小是**整台设备共享**的，CoreAudio 会在各 app 的诉求间仲裁。
/// 调得过小可能让其他音频 app 出现爆音，所以只降到 128 而不是最小值。
public enum OutputDeviceLatency {
    private static let logger = Logger(subsystem: "com.kbsound", category: "OutputLatency")

    /// 目标 buffer 大小。128 frames 在 48kHz 下是 2.67ms。
    public static let preferredFrames: UInt32 = 128

    /// 把诉求钳制到设备实际支持的区间内。
    public static func clamped(_ desired: UInt32, to range: ClosedRange<UInt32>) -> UInt32 {
        min(max(desired, range.lowerBound), range.upperBound)
    }

    /// 尽力调小默认输出设备的 buffer。失败只记日志——延迟大一点也比不出声强。
    public static func minimize() {
        guard let device = defaultOutputDevice() else {
            logger.error("找不到默认输出设备，跳过 buffer 调整")
            return
        }
        guard let range = bufferFrameRange(of: device) else {
            logger.error("读取 buffer 区间失败，跳过 buffer 调整")
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
            logger.info("输出 buffer 设为 \(target, privacy: .public) frames")
        } else {
            logger.error("设置输出 buffer 失败，状态码 \(status, privacy: .public)")
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
