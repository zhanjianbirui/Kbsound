import Accelerate
import AVFoundation
import Foundation

/// 把各音效包拉到统一响度。
///
/// 21 套内置包的起振段 RMS 跨度达 23.7dB（topre-silent 最响 −16.6dBFS，
/// lofi 最轻 −40.3dBFS），同一个总音量下切包会忽大忽小。加载时按整包算一个
/// 增益，把响度对齐到 `targetRMS`，实测残差可收敛到 2.6dB 以内。
///
/// 三个刻意的取舍：
/// - **整包一个增益**，不逐文件归一——包内空格键比字母键响是录音的本意，
///   逐文件归一会把这层设计抹平。
/// - **以起振后的固定窗测 RMS**，不用整段 RMS——整段 RMS 会被尾音长度和
///   静音拖尾带偏，而按键音的响度感受几乎只由起振那一小段决定。
/// - **用软限幅而不是直接压低增益**来守住峰值。有几套包（cream-travel、
///   mx-brown-pbt）峰值已经贴顶但 RMS 很低，只按峰值留余量的话它们永远拉不上来；
///   按键音是极短的瞬态，几 dB 的软限幅听不出来，响度却能对齐。
public enum LoudnessNormalizer {
    /// 目标响度，取 21 套内置包的中位数附近。线性值，对应 −28dBFS。
    public static let targetRMS: Float = 0.0398
    /// 增益后允许的峰值上限。留一点余量，避免连打时多声叠加削顶。
    public static let peakCeiling: Float = 0.99
    /// 增益上下限，约 ±18dB。防止近乎无声的包被放大成噪声。
    public static let maxGain: Float = 8
    public static let minGain: Float = 0.125

    /// 软限幅起点。这之下的样本原样通过，之上平滑压向 `peakCeiling`。
    static let limiterKnee: Float = 0.6
    /// 允许的最大限幅量：增益后的峰值不超过上限的这个倍数（约 12dB）。
    /// 再多就不是限幅而是失真了。
    static let maxLimiterDrive: Float = 4

    /// 测量窗长度。按键音的瞬态与主要能量都在这段之内。
    static let windowSeconds: Double = 0.12
    /// 起振判定门限，相对于整段峰值。
    static let onsetThreshold: Float = 0.05

    /// 整包统一增益。空包或全静音时返回 1（不动）。
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
        // 顶到上限的部分交给软限幅，但限幅量本身要有上限。
        let driveLimit = maxLimiterDrive * peakCeiling / peak
        return min(max(min(wanted, driveLimit), minGain), maxGain)
    }

    /// 应用增益并软限幅后的新 buffer；增益为 1 且无需限幅时原样返回。
    /// 原 buffer 不被修改。
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

    /// 拐点以下原样通过，以上用 tanh 平滑压向上限——在拐点处一阶连续，
    /// 不会像硬削顶那样产生刺耳的谐波。输出恒在 ±`peakCeiling` 内。
    static func softLimit(_ sample: Float) -> Float {
        let magnitude = abs(sample)
        guard magnitude > limiterKnee else { return sample }
        let headroom = peakCeiling - limiterKnee
        let limited = limiterKnee + headroom * tanh((magnitude - limiterKnee) / headroom)
        return sample < 0 ? -limited : limited
    }

    /// 起振点之后一个固定窗内的 RMS。整段比窗短时就用整段。
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
