import AVFoundation
import Foundation
import Testing
@testable import KbSoundCore

/// 仓库根目录：本文件在 <root>/Tests/KbSoundCoreTests/ 下。
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
    // topre-silent 是 48000Hz 单声道，用来确认我们没写死格式
    let pack = try LoadedPack(ref: realPack("topre-silent"))
    #expect(pack.format.sampleRate == 48000)
    #expect(pack.format.channelCount == 1)
}

@Test func returnsBufferForMappedKey() throws {
    let pack = try LoadedPack(ref: realPack("mx-brown-pbt"))
    // keyCode 49 = 空格，manifest 里映射到 spacebar.wav
    let buffer = try #require(pack.buffer(for: 49, phase: .down))
    #expect(buffer.frameLength > 0)
}

@Test func returnsBufferForUnmappedKeyViaDefaults() throws {
    let pack = try LoadedPack(ref: realPack("mx-brown-pbt"))
    #expect(pack.buffer(for: 9999, phase: .down) != nil)
}

@Test func returnsNilForUpWhenPackHasNoUpSounds() throws {
    // mx-brown-pbt 只定义了 down
    let pack = try LoadedPack(ref: realPack("mx-brown-pbt"))
    #expect(pack.buffer(for: 49, phase: .up) == nil)
}

@Test func returnsBufferForUpWhenPackDefinesIt() throws {
    // topre-silent 同时定义了 down 和 up
    let pack = try LoadedPack(ref: realPack("topre-silent"))
    #expect(pack.buffer(for: 49, phase: .up) != nil)
}

@Test func sameFileIsDecodedOnlyOnce() throws {
    // manifest 里几十个 keyCode 指向同一个 wav，不该解码几十份
    let pack = try LoadedPack(ref: realPack("mx-brown-pbt"))
    let a = try #require(pack.buffer(for: 0, phase: .down))
    let b = try #require(pack.buffer(for: 1, phase: .down))
    #expect(a === b)  // 两个 keyCode 都映射到同一个 wav，应是同一个 buffer 实例
}

@Test func everyBundledPackDecodes() throws {
    let packsDir = repoRoot.appending(path: "Resources/Packs")
    let dirs = try FileManager.default.contentsOfDirectory(atPath: packsDir.path).sorted()
    #expect(dirs.count == 21)
    for dir in dirs {
        _ = try LoadedPack(ref: realPack(dir))  // 任何一套解码失败都会让测试失败
    }
}

@Test func trimsLeadInSoSoundsStartPromptly() throws {
    // mx-brown-pbt 原始录音要 23.7ms 才达到半峰；加载后应当立刻起振
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
