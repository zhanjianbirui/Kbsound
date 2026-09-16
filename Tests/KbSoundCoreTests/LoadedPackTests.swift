import AVFoundation
import Foundation
import Testing
@testable import KbSoundCore

/// Repository root: this file lives in <root>/Tests/KbSoundCoreTests/.
private let repoRoot = URL(filePath: #filePath)
    .deletingLastPathComponent()   // KbSoundCoreTests
    .deletingLastPathComponent()   // Tests
    .deletingLastPathComponent()   // <root>

private func realPack(_ dirName: String) throws -> PackRef {
    let dir = repoRoot.appending(path: "Resources/Packs/\(dirName)")
    let manifest = try JSONDecoder().decode(
        PackManifest.self,
        from: Data(contentsOf: dir.appending(path: "manifest.json")))
    return PackRef(id: manifest.id, name: manifest.name,
                   detail: manifest.detail, directory: dir)
}

@Test func decodesStereoPack() throws {
    let pack = try LoadedPack(ref: realPack("mx-brown-pbt"))
    #expect(pack.format.sampleRate == 44100)
    #expect(pack.format.channelCount == 2)
}

@Test func decodesMonoPack() throws {
    // topre-silent is 48000 Hz mono, which confirms the format is not hardcoded
    let pack = try LoadedPack(ref: realPack("topre-silent"))
    #expect(pack.format.sampleRate == 48000)
    #expect(pack.format.channelCount == 1)
}

@Test func returnsBufferForMappedKey() throws {
    let pack = try LoadedPack(ref: realPack("mx-brown-pbt"))
    // keyCode 49 = space, mapped to spacebar.wav in the manifest
    let buffer = try #require(pack.buffer(for: 49, phase: .down))
    #expect(buffer.frameLength > 0)
}

@Test func returnsBufferForUnmappedKeyViaDefaults() throws {
    let pack = try LoadedPack(ref: realPack("mx-brown-pbt"))
    #expect(pack.buffer(for: 9999, phase: .down) != nil)
}

@Test func returnsNilForUpWhenPackHasNoUpSounds() throws {
    // mx-brown-pbt only defines down
    let pack = try LoadedPack(ref: realPack("mx-brown-pbt"))
    #expect(pack.buffer(for: 49, phase: .up) == nil)
}

@Test func returnsBufferForUpWhenPackDefinesIt() throws {
    // topre-silent defines both down and up
    let pack = try LoadedPack(ref: realPack("topre-silent"))
    #expect(pack.buffer(for: 49, phase: .up) != nil)
}

@Test func sameFileIsDecodedOnlyOnce() throws {
    // Dozens of key codes point at the same wav; it must not be decoded dozens of times
    let pack = try LoadedPack(ref: realPack("mx-brown-pbt"))
    let a = try #require(pack.buffer(for: 0, phase: .down))
    let b = try #require(pack.buffer(for: 1, phase: .down))
    #expect(a === b)  // Both key codes map to the same wav, so it must be the same buffer instance
}

@Test func everyBundledPackDecodes() throws {
    let packsDir = repoRoot.appending(path: "Resources/Packs")
    let dirs = try FileManager.default.contentsOfDirectory(atPath: packsDir.path).sorted()
    #expect(dirs.count == 21)
    for dir in dirs {
        _ = try LoadedPack(ref: realPack(dir))  // A decode failure in any pack fails the test
    }
}

@Test func trimsLeadInSoSoundsStartPromptly() throws {
    // The raw mx-brown-pbt recording takes 23.7 ms to reach half peak; after loading the
    // onset must be immediate
    let pack = try LoadedPack(ref: realPack("mx-brown-pbt"))
    let buffer = try #require(pack.buffer(for: 0, phase: .down))
    var peak: Float = 0
    for i in 0..<Int(buffer.frameLength) { peak = max(peak, abs(buffer.floatChannelData![0][i])) }

    var halfPeakFrame = Int(buffer.frameLength)
    for i in 0..<Int(buffer.frameLength) where abs(buffer.floatChannelData![0][i]) >= peak * 0.5 {
        halfPeakFrame = i
        break
    }
    let ms = Double(halfPeakFrame) / buffer.format.sampleRate * 1000
    #expect(ms < 5)
}
