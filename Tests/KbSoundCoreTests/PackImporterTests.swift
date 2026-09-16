import AVFoundation
import Foundation
import Testing
@testable import KbSoundCore

private func makeTone(at url: URL, seconds: Double = 1.0, level: Float = 0.5) throws {
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!
    let frames = AVAudioFrameCount(48000 * seconds)
    let file = try AVAudioFile(forWriting: url, settings: format.settings)
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
    buffer.frameLength = frames
    for i in 0..<Int(frames) { buffer.floatChannelData![0][i] = level }
    try file.write(from: buffer)
}

private func withTempDirs(_ body: (_ source: URL, _ destination: URL) throws -> Void) throws {
    let root = URL.temporaryDirectory.appending(path: "import-\(UUID().uuidString)")
    let source = root.appending(path: "src")
    let destination = root.appending(path: "dst")
    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try body(source, destination)
}

// MARK: - Mechvibes multi

@Test func importsMultiFilePack() throws {
    try withTempDirs { source, destination in
        for row in 0...4 { try makeTone(at: source.appending(path: "press/GENERIC_R\(row).wav")) }
        try makeTone(at: source.appending(path: "press/SPACE.wav"))
        try makeTone(at: source.appending(path: "release/GENERIC.wav"))
        try Data("""
        {"id":"multi-1","name":"Multi Pack","key_define_type":"multi",
         "sound":"press/GENERIC_R{0-4}.wav","soundup":"release/GENERIC.wav",
         "defines":{"57":"press/SPACE.wav"}}
        """.utf8).write(to: source.appending(path: "config.json"))

        let ref = try PackImporter.importPack(from: source, into: destination)
        #expect(ref.name == "Multi Pack")

        let pack = try LoadedPack(ref: ref)
        #expect(pack.buffer(for: 0, phase: .down) != nil)    // A, via the row variant
        #expect(pack.buffer(for: 49, phase: .down) != nil)   // space, via its own sound
        #expect(pack.buffer(for: 0, phase: .up) != nil)      // key-up sound
    }
}

@Test func mapsRowVariantsByPhysicalRow() throws {
    try withTempDirs { source, destination in
        // A different amplitude per row confirms that A gets the row-2 sound
        for row in 0...4 {
            try makeTone(at: source.appending(path: "GENERIC_R\(row).wav"),
                         level: Float(row + 1) / 10)
        }
        try Data("""
        {"id":"rows","name":"Rows","key_define_type":"multi",
         "sound":"GENERIC_R{0-4}.wav","defines":{}}
        """.utf8).write(to: source.appending(path: "config.json"))

        let pack = try LoadedPack(ref: try PackImporter.importPack(from: source, into: destination))
        let a = try #require(pack.buffer(for: 0, phase: .down))    // A is in row 2 → 0.3
        let q = try #require(pack.buffer(for: 12, phase: .down))   // Q is in row 1 → 0.2
        // Divide out the pack's normalization gain to compare recorded levels
        #expect(abs(a.floatChannelData![0][100] / pack.gain - 0.3) < 0.01)
        #expect(abs(q.floatChannelData![0][100] / pack.gain - 0.2) < 0.01)
    }
}

// MARK: - Mechvibes single (sprite)

@Test func importsSpritePackBySlicingTheSharedFile() throws {
    try withTempDirs { source, destination in
        try makeTone(at: source.appending(path: "sound.wav"), seconds: 2.0)
        try Data("""
        {"id":"sprite-1","name":"Sprite Pack","key_define_type":"single","sound":"sound.wav",
         "defines":{"30":[0,100],"57":[200,150],"2":null}}
        """.utf8).write(to: source.appending(path: "config.json"))

        let pack = try LoadedPack(ref: try PackImporter.importPack(from: source, into: destination))
        let a = try #require(pack.buffer(for: 0, phase: .down))     // X11 30 = A
        #expect(abs(Double(a.frameLength) / a.format.sampleRate - 0.1) < 0.01)
        #expect(pack.buffer(for: 49, phase: .down) != nil)          // X11 57 = space
    }
}

// MARK: - KbSound native

@Test func copiesNativePackAsIs() throws {
    try withTempDirs { source, destination in
        try makeTone(at: source.appending(path: "tap.wav"))
        try Data("""
        {"formatVersion":1,"id":"native-1","name":"Native","defaults":{"down":"tap.wav"}}
        """.utf8).write(to: source.appending(path: "manifest.json"))

        let ref = try PackImporter.importPack(from: source, into: destination)
        #expect(ref.id == "native-1")
        #expect(try LoadedPack(ref: ref).buffer(for: 0, phase: .down) != nil)
    }
}

// MARK: - Error handling

@Test func rejectsFolderWithNeitherManifestNorConfig() throws {
    try withTempDirs { source, destination in
        try makeTone(at: source.appending(path: "stray.wav"))
        #expect(throws: PackImporter.ImportError.unrecognizedFormat) {
            try PackImporter.importPack(from: source, into: destination)
        }
    }
}

@Test func rejectsPackWhoseAudioIsMissing() throws {
    try withTempDirs { source, destination in
        try Data("""
        {"id":"broken","name":"Broken","key_define_type":"multi",
         "sound":"GENERIC_R{0-4}.wav","defines":{}}
        """.utf8).write(to: source.appending(path: "config.json"))
        #expect(throws: (any Error).self) {
            try PackImporter.importPack(from: source, into: destination)
        }
    }
}

@Test func reimportingSamePackReplacesTheOldCopy() throws {
    try withTempDirs { source, destination in
        for row in 0...4 { try makeTone(at: source.appending(path: "GENERIC_R\(row).wav")) }
        try Data("""
        {"id":"dup","name":"Dup","key_define_type":"multi",
         "sound":"GENERIC_R{0-4}.wav","defines":{}}
        """.utf8).write(to: source.appending(path: "config.json"))

        _ = try PackImporter.importPack(from: source, into: destination)
        let second = try PackImporter.importPack(from: source, into: destination)
        // No dup-1 / dup-2 directories should pile up
        let entries = try FileManager.default.contentsOfDirectory(atPath: destination.path)
        #expect(entries.count == 1)
        #expect(second.id == "dup")
    }
}

@Test func leavesNoPartialFolderWhenImportFails() throws {
    try withTempDirs { source, destination in
        try Data("""
        {"id":"halfway","name":"Halfway","key_define_type":"multi",
         "sound":"GENERIC_R{0-4}.wav","defines":{}}
        """.utf8).write(to: source.appending(path: "config.json"))
        _ = try? PackImporter.importPack(from: source, into: destination)
        // A failure must not leave a half-written pack behind, or the next scan would pick up
        // a broken pack
        let entries = (try? FileManager.default.contentsOfDirectory(atPath: destination.path)) ?? []
        #expect(entries.isEmpty)
    }
}

@Test func importsMultiPackThatMapsEveryKeyDirectly() throws {
    // Common in real community packs (mechvibes-lofi-sounds and friends): the sound field
    // is a placeholder that does not exist and all 118 keys name their file individually
    // in defines, with no row pattern at all
    try withTempDirs { source, destination in
        try makeTone(at: source.appending(path: "keyboard1.wav"), level: 0.2)
        try makeTone(at: source.appending(path: "keyboard4.wav"), level: 0.8)
        try Data("""
        {"id":"direct","name":"Direct Map","key_define_type":"multi","sound":"sound.ogg",
         "defines":{"1":"keyboard4.wav","2":"keyboard1.wav","30":"keyboard1.wav"}}
        """.utf8).write(to: source.appending(path: "config.json"))

        let pack = try LoadedPack(ref: try PackImporter.importPack(from: source, into: destination))
        let esc = try #require(pack.buffer(for: 53, phase: .down))   // X11 1 = Esc
        let a = try #require(pack.buffer(for: 0, phase: .down))      // X11 30 = A
        #expect(abs(esc.floatChannelData![0][100] / pack.gain - 0.8) < 0.01)
        #expect(abs(a.floatChannelData![0][100] / pack.gain - 0.2) < 0.01)
    }
}

@Test func unmappedKeysFallBackToADefinedSound() throws {
    try withTempDirs { source, destination in
        try makeTone(at: source.appending(path: "only.wav"))
        try Data("""
        {"id":"sparse","name":"Sparse","key_define_type":"multi","sound":"missing.ogg",
         "defines":{"30":"only.wav"}}
        """.utf8).write(to: source.appending(path: "config.json"))

        let pack = try LoadedPack(ref: try PackImporter.importPack(from: source, into: destination))
        // Keys absent from defines should still make a sound rather than staying silent
        #expect(pack.buffer(for: 12, phase: .down) != nil)
    }
}
