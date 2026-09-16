import AVFoundation
import Foundation

/// Trims the quiet lead-in at the start of a sound.
///
/// This is by far the largest contributor to the gap between pressing a key and
/// hearing it — an order of magnitude bigger than anything on the engine side.
/// Several klinkmac packs recorded the full key travel, so the real transient starts
/// long after the beginning of the file: measured at 23.7 ms for MX Brown PBT and
/// 195.9 ms for MX Black ABS before reaching half peak.
/// The lead-in is not actually silent (roughly 2–6% of peak), so a "is it zero?" test
/// cannot trim it; the onset has to be found as a fraction of the peak level.
public enum AudioTrim {
    /// Onset threshold, relative to the peak of the whole buffer.
    static let onsetThreshold: Float = 0.15
    /// Pre-roll kept before the onset. Cutting exactly at the onset flattens the
    /// transient and sounds like a click.
    static let preRoll: Double = 0.002

    /// Number of frames that can be trimmed before the onset. Returns 0 when there is
    /// nothing to trim (or the whole buffer is very quiet).
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

    /// A new buffer with the lead-in removed; returns the original when there is
    /// nothing to trim.
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
