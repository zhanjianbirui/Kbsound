import AVFoundation
import Foundation

/// 从「音频精灵」里切出一段，写成独立的 wav 文件。
///
/// Mechvibes 的 `single` 包把所有按键音拼在一个文件里，靠 `[起始毫秒, 时长毫秒]` 定位。
/// 导入时就地切开，运行时格式与其他包保持一致（一个音一个文件），
/// 切出来的片段也能照常享受 `AudioTrim` 的前导裁剪。
public enum AudioSlicer {
    public enum SliceError: Error, Equatable {
        case offsetBeyondEnd
        case nonPositiveDuration
        case unreadable
        case writeFailed
    }

    public static func writeSlice(
        of source: URL, offsetMs: Double, durationMs: Double, to destination: URL
    ) throws {
        guard durationMs > 0 else { throw SliceError.nonPositiveDuration }

        guard let file = try? AVAudioFile(forReading: source) else {
            throw SliceError.unreadable
        }
        let format = file.processingFormat
        let startFrame = AVAudioFramePosition(offsetMs / 1000 * format.sampleRate)
        guard startFrame < file.length else { throw SliceError.offsetBeyondEnd }

        // 请求的时长可能超出素材末尾，截到实际可用长度
        let requested = AVAudioFrameCount(durationMs / 1000 * format.sampleRate)
        let available = AVAudioFrameCount(file.length - startFrame)
        let frameCount = min(requested, available)
        guard frameCount > 0 else { throw SliceError.nonPositiveDuration }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw SliceError.unreadable
        }
        file.framePosition = startFrame
        try file.read(into: buffer, frameCount: frameCount)

        do {
            let output = try AVAudioFile(forWriting: destination, settings: format.settings)
            try output.write(from: buffer)
        } catch {
            throw SliceError.writeFailed
        }
    }
}
