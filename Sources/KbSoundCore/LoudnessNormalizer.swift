import Accelerate
import AVFoundation
import Foundation

/// Brings every sound pack to a common loudness.
///
/// Across the 21 bundled packs the onset RMS spans 23.7 dB (topre-silent loudest at
/// −16.6 dBFS, lofi quietest at −40.3 dBFS), so at a fixed volume setting switching
/// packs used to mean a jarring jump in level. Each pack gets a single gain on load
/// that aligns it to `targetRMS`, which measurably brings the spread under 2.6 dB.
///
/// Three deliberate choices:
/// - **One gain per pack**, not per file — a spacebar recorded louder than the letter
///   keys is the pack author's intent, and per-file normalization would flatten it.
/// - **RMS over a fixed window after the onset**, not over the whole file — whole-file
///   RMS is skewed by tail length and trailing silence, while the perceived loudness of
///   a keystroke comes almost entirely from the onset.
/// - **Soft limiting instead of backing the gain off** to protect the peak. A few packs
///   (cream-travel, mx-brown-pbt) already peak near full scale but sit low in RMS;
///   leaving peak headroom would mean they could never be brought up. A keystroke is an
///   extremely short transient, so a few dB of soft limiting is inaudible while the
///   loudness still lines up.
public enum LoudnessNormalizer {
    /// Target loudness, as a linear value; equals −34 dBFS.
    ///
    /// The number is not arbitrary: it puts the default pack, mx-brown-pbt, at −0.75 dB
    /// of gain, which is also the median gain across the 21 packs. In other words,
    /// normalization only *aligns* packs and leaves overall volume alone — a given
    /// slider position sounds as loud as it did without normalization.
    /// The first attempt used −28 dBFS (the median of the packs' recorded levels) and
    /// was wrong: most packs sit at −30 to −40 dBFS, so everything came out 5.25 dB
    /// louder and the slider had to be pulled way back to be usable.
    public static let targetRMS: Float = 0.01995
    /// Peak ceiling allowed after the gain. A little headroom keeps overlapping sounds
    /// from clipping during fast typing.
    public static let peakCeiling: Float = 0.99
    /// Gain bounds, roughly ±18 dB. Keeps a nearly silent pack from being amplified
    /// into noise.
    public static let maxGain: Float = 8
    public static let minGain: Float = 0.125

    /// Soft-limiter knee. Samples below it pass through untouched; above it they are
    /// pushed smoothly towards `peakCeiling`.
    static let limiterKnee: Float = 0.6
    /// Most limiting allowed: the post-gain peak may exceed the ceiling by this factor
    /// (about 12 dB). Beyond that it stops being limiting and becomes distortion.
    static let maxLimiterDrive: Float = 4

    /// Measurement window. A keystroke's transient and most of its energy fall inside it.
    static let windowSeconds: Double = 0.12
    /// Onset threshold, relative to the peak of the whole buffer.
    static let onsetThreshold: Float = 0.05

    /// The single gain for a pack. Returns 1 (no change) for an empty or silent pack.
    public static func gain(for buffers: [AVAudioPCMBuffer]) -> Float {
        var energy: Float = 0
        var peak: Float = 0
        var counted = 0

        for buffer in buffers {
            let rms = onsetRMS(of: buffer)
            guard rms > 0 else { continue }
            energy += rms * rms
            peak = max(peak, self.peak(of: buffer))
            counted += 1
        }
        guard counted > 0, peak > 0 else { return 1 }

        let packRMS = (energy / Float(counted)).squareRoot()
        let wanted = targetRMS / packRMS
        // Whatever exceeds the ceiling is handled by the soft limiter, but the amount of
        // limiting itself has to be bounded.
        let driveLimit = maxLimiterDrive * peakCeiling / peak
        return min(max(min(wanted, driveLimit), minGain), maxGain)
    }

    /// A new buffer with the gain and soft limiting applied; returns the original when
    /// the gain is 1 and no limiting is needed. The input buffer is never modified.
    public static func applying(gain: Float, to buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        let needsLimiting = peak(of: buffer) * gain > limiterKnee
        guard gain != 1 || needsLimiting,
              let source = buffer.floatChannelData,
              let scaled = AVAudioPCMBuffer(pcmFormat: buffer.format,
                                            frameCapacity: buffer.frameLength),
              let destination = scaled.floatChannelData
        else { return buffer }

        scaled.frameLength = buffer.frameLength
        let frameCount = Int(buffer.frameLength)
        for channel in 0..<Int(buffer.format.channelCount) {
            vDSP_vsmul(source[channel], 1, [gain], destination[channel], 1, vDSP_Length(frameCount))
            guard needsLimiting else { continue }
            for frame in 0..<frameCount {
                destination[channel][frame] = softLimit(destination[channel][frame])
            }
        }
        return scaled
    }

    /// Below the knee samples pass through; above it `tanh` eases them towards the
    /// ceiling — continuous in the first derivative at the knee, so it avoids the harsh
    /// harmonics of hard clipping. The output always stays within ±`peakCeiling`.
    static func softLimit(_ sample: Float) -> Float {
        let magnitude = abs(sample)
        guard magnitude > limiterKnee else { return sample }
        let headroom = peakCeiling - limiterKnee
        let limited = limiterKnee + headroom * tanh((magnitude - limiterKnee) / headroom)
        return sample < 0 ? -limited : limited
    }

    /// RMS over a fixed window starting at the onset. Uses the whole buffer when it is
    /// shorter than the window.
    static func onsetRMS(of buffer: AVAudioPCMBuffer) -> Float {
        guard let channels = buffer.floatChannelData, buffer.frameLength > 0 else { return 0 }
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        let peak = peak(of: buffer)
        guard peak > 0 else { return 0 }

        let level = peak * onsetThreshold
        var onset = 0
        search: for frame in 0..<frameCount {
            for channel in 0..<channelCount where abs(channels[channel][frame]) >= level {
                onset = frame
                break search
            }
        }

        let windowFrames = Int(windowSeconds * buffer.format.sampleRate)
        let end = min(onset + windowFrames, frameCount)
        guard end > onset else { return 0 }

        var energy: Float = 0
        for channel in 0..<channelCount {
            var channelEnergy: Float = 0
            vDSP_measqv(channels[channel] + onset, 1, &channelEnergy, vDSP_Length(end - onset))
            energy += channelEnergy
        }
        return (energy / Float(channelCount)).squareRoot()
    }

    static func peak(of buffer: AVAudioPCMBuffer) -> Float {
        guard let channels = buffer.floatChannelData, buffer.frameLength > 0 else { return 0 }
        var peak: Float = 0
        for channel in 0..<Int(buffer.format.channelCount) {
            var channelPeak: Float = 0
            vDSP_maxmgv(channels[channel], 1, &channelPeak, vDSP_Length(buffer.frameLength))
            peak = max(peak, channelPeak)
        }
        return peak
    }
}
