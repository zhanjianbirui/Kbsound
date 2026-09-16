import AVFoundation
import Foundation
import Testing
@testable import KbSoundCore

/// Builds one second of test audio in 100 ms segments of differing amplitude, so it is
/// easy to tell which segment a slice came from.
private func makeSpriteFile(at url: URL) throws {
    let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!
    let file = try AVAudioFile(forWriting: url, settings: format.settings)
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 48000)!
    buffer.frameLength = 48000
    for i in 0..<48000 {
        buffer.floatChannelData![0][i] = Float(i / 4800 + 1) / 10.0
    }
    try file.write(from: buffer)
}

private func withTempDir(_ body: (URL) throws -> Void) throws {
    let dir = URL.temporaryDirectory.appending(path: "slicer-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    try body(dir)
}

@Test func slicesRequestedRangeIntoItsOwnFile() throws {
    try withTempDir { dir in
        let sprite = dir.appending(path: "sprite.wav")
        try makeSpriteFile(at: sprite)
        let out = dir.appending(path: "slice.wav")

        try AudioSlicer.writeSlice(of: sprite, offsetMs: 200, durationMs: 100, to: out)

        let result = try AVAudioFile(forReading: out)
        #expect(abs(Double(result.length) / result.processingFormat.sampleRate - 0.1) < 0.005)
        let buffer = AVAudioPCMBuffer(pcmFormat: result.processingFormat,
                                      frameCapacity: AVAudioFrameCount(result.length))!
        try result.read(into: buffer)
        // 200 ms lands in the third segment (index 2), amplitude 0.3
        #expect(abs(buffer.floatChannelData![0][10] - 0.3) < 0.01)
    }
}

@Test func clampsSliceThatRunsPastTheEnd() throws {
    try withTempDir { dir in
        let sprite = dir.appending(path: "sprite.wav")
        try makeSpriteFile(at: sprite)
        let out = dir.appending(path: "tail.wav")
        // The source is only 1000 ms long; ask for 500 ms starting at 900 ms
        try AudioSlicer.writeSlice(of: sprite, offsetMs: 900, durationMs: 500, to: out)
        let result = try AVAudioFile(forReading: out)
        #expect(abs(Double(result.length) / result.processingFormat.sampleRate - 0.1) < 0.005)
    }
}

@Test func rejectsOffsetBeyondTheEnd() throws {
    try withTempDir { dir in
        let sprite = dir.appending(path: "sprite.wav")
        try makeSpriteFile(at: sprite)
        #expect(throws: (any Error).self) {
            try AudioSlicer.writeSlice(of: sprite, offsetMs: 5000, durationMs: 100,
                                       to: dir.appending(path: "bad.wav"))
        }
    }
}

@Test func rejectsNonPositiveDuration() throws {
    try withTempDir { dir in
        let sprite = dir.appending(path: "sprite.wav")
        try makeSpriteFile(at: sprite)
        #expect(throws: (any Error).self) {
            try AudioSlicer.writeSlice(of: sprite, offsetMs: 0, durationMs: 0,
                                       to: dir.appending(path: "bad.wav"))
        }
    }
}
