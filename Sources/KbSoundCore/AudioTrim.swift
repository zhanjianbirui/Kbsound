import AVFoundation
import Foundation

/// 裁掉音效开头的低电平段。
///
/// 这是按键到「听见声音」之间最大的一段延迟来源，比引擎侧的一切都大一个数量级：
/// klinkmac 的多套包录进了完整按键行程，真正的瞬态在文件开头之后很久才出现——
/// 实测 MX Brown PBT 要 23.7ms，MX Black ABS 要 195.9ms 才达到半峰。
/// 前导段本身并非静音（约为峰值的 2–6%），所以只看「是否为零」是裁不掉的，
/// 必须按相对峰值的比例找起振点。
public enum AudioTrim {
    /// 起振判定门限，相对于整段峰值。
    static let onsetThreshold: Float = 0.15
    /// 起振点之前保留的预卷时长。直接从起振点切会把瞬态削平，听起来像爆音。
    static let preRoll: Double = 0.002

    /// 起振点之前可以裁掉的帧数。没有可裁的（或整段都很轻）时返回 0。
    public static func leadingFramesBeforeOnset(in buffer: AVAudioPCMBuffer) -> AVAudioFrameCount {
        guard let channels = buffer.floatChannelData, buffer.frameLength > 0 else { return 0 }
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        var peak: Float = 0
        for channel in 0..<channelCount {
            for frame in 0..<frameCount {
                peak = max(peak, abs(channels[channel][frame]))
            }
        }
        guard peak > 0 else { return 0 }

        let level = peak * onsetThreshold
        var onset = frameCount
        search: for frame in 0..<frameCount {
            for channel in 0..<channelCount where abs(channels[channel][frame]) >= level {
                onset = frame
                break search
            }
        }

        let preRollFrames = Int(preRoll * buffer.format.sampleRate)
        return AVAudioFrameCount(max(0, min(onset - preRollFrames, frameCount)))
    }

    /// 裁掉前导段后的新 buffer；无需裁剪时原样返回。
    public static func trimmingLeadIn(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        let offset = leadingFramesBeforeOnset(in: buffer)
        guard offset > 0, let source = buffer.floatChannelData else { return buffer }

        let remaining = buffer.frameLength - offset
        guard remaining > 0,
              let trimmed = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: remaining),
              let destination = trimmed.floatChannelData
        else { return buffer }

        trimmed.frameLength = remaining
        for channel in 0..<Int(buffer.format.channelCount) {
            destination[channel].update(from: source[channel] + Int(offset), count: Int(remaining))
        }
        return trimmed
    }
}
