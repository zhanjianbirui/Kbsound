import AVFoundation
import Foundation
import os

public enum PackLoadError: Error, Equatable {
    /// The manifest references no audio files at all.
    case empty
    /// One pack mixes sample rates or channel counts — an `AVAudioPlayerNode` can only
    /// be connected with a single format at a time.
    case mixedFormats
    case unreadable(String)
}

/// A sound pack decoded into memory and ready to play.
///
/// The key callback has to return within a few milliseconds, so the whole pack is
/// decoded into resident PCM buffers when it is selected, leaving the callback with
/// nothing but a dictionary lookup — no file I/O ever happens on that path.
///
/// `@unchecked Sendable`: `AVAudioPCMBuffer` is not `Sendable`, but this type is
/// fully read-only once constructed and is only used on the main thread.
public struct LoadedPack: @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.kbsound", category: "LoadedPack")

    public let ref: PackRef
    /// The one audio format shared by this pack. Packs differ from each other (some are
    /// 44.1k stereo, others 48k mono), so `AudioPlayer` must reconnect its nodes on switch.
    public let format: AVAudioFormat

    /// Range of macOS virtual key codes, used to walk the whole keyboard.
    private static let keyCodeRange = 128

    /// This pack's loudness-normalization gain; 1 means untouched. For logging and tests.
    public let gain: Float

    private let manifest: PackManifest
    /// File name → buffer. A file referenced by several key codes is stored once.
    private let buffers: [String: AVAudioPCMBuffer]

    public init(ref: PackRef) throws {
        let manifestURL = ref.directory.appending(path: "manifest.json")
        let manifest = try JSONDecoder().decode(
            PackManifest.self, from: Data(contentsOf: manifestURL))

        var buffers: [String: AVAudioPCMBuffer] = [:]
        var format: AVAudioFormat?

        for fileName in manifest.referencedFiles.sorted() {
            let url = ref.directory.appending(path: fileName)
            let file: AVAudioFile
            do {
                file = try AVAudioFile(forReading: url)
            } catch {
                Self.logger.error("\(fileName, privacy: .public) is unreadable: \(error.localizedDescription, privacy: .public)")
                throw PackLoadError.unreadable(fileName)
            }

            if let format, format != file.processingFormat {
                Self.logger.error("\(manifest.id, privacy: .public) mixes audio formats")
                throw PackLoadError.mixedFormats
            }
            format = file.processingFormat

            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: file.processingFormat,
                frameCapacity: AVAudioFrameCount(file.length)
            ) else {
                throw PackLoadError.unreadable(fileName)
            }
            try file.read(into: buffer)
            // Trim the quiet lead-in — the largest source of key-to-sound latency.
            buffers[fileName] = AudioTrim.trimmingLeadIn(buffer)
        }

        guard let format else { throw PackLoadError.empty }

        // One gain for the whole pack is what makes packs line up with each other; the
        // relative dynamics inside a pack are preserved.
        // Weighted by key count: a file counts in the measurement for as many keys as
        // reference it — how loud a pack *feels* while typing is set by the default
        // sound covering most keys, not by the one mapped only to the spacebar.
        let weighted = (0..<Self.keyCodeRange).flatMap { keyCode in
            [KeyPhase.down, .up].compactMap { phase in
                manifest.fileName(for: keyCode, phase: phase).flatMap { buffers[$0] }
            }
        }
        let gain = LoudnessNormalizer.gain(for: weighted)
        Self.logger.info("\(manifest.id, privacy: .public) loudness gain \(gain, privacy: .public)x")

        self.ref = ref
        self.manifest = manifest
        self.buffers = buffers.mapValues { LoudnessNormalizer.applying(gain: gain, to: $0) }
        self.gain = gain
        self.format = format
    }

    /// The buffer a key should play, or nil when the pack defines no sound for it
    /// (for instance a pack with no key-up sounds).
    public func buffer(for keyCode: Int, phase: KeyPhase) -> AVAudioPCMBuffer? {
        guard let fileName = manifest.fileName(for: keyCode, phase: phase) else { return nil }
        return buffers[fileName]
    }
}
