import AVFoundation
import Foundation

/// Cuts one slice out of an audio sprite and writes it as a standalone wav file.
///
/// Mechvibes `single` packs pack every key sound into one file, addressed by
/// `[offset ms, duration ms]`. Slicing at import time keeps the runtime format
/// identical to every other pack (one sound per file) and lets the slices benefit
/// from `AudioTrim`'s lead-in trimming like everything else.
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

        // The requested duration may run past the end of the source; clamp it to what
        // is actually available.
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
