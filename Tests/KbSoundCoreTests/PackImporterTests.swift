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
        #expect(pack.buffer(for: 0, phase: .down) != nil)    // A，走行变体
        #expect(pack.buffer(for: 49, phase: .down) != nil)   // 空格，走专属音
        #expect(pack.buffer(for: 0, phase: .up) != nil)      // 抬键音
    }
}

@Test func mapsRowVariantsByPhysicalRow() throws {
    try withTempDirs { source, destination in
        // 每行给不同幅度，用来确认 A 拿到的是第 2 行的音
        for row in 0...4 {
            try makeTone(at: source.appending(path: "GENERIC_R\(row).wav"),
                         level: Float(row + 1) / 10)
        }
        try Data("""
        {"id":"rows","name":"Rows","key_define_type":"multi",
         "sound":"GENERIC_R{0-4}.wav","defines":{}}
        """.utf8).write(to: source.appending(path: "config.json"))

        let pack = try LoadedPack(ref: try PackImporter.importPack(from: source, into: destination))
        let a = try #require(pack.buffer(for: 0, phase: .down))    // A 在第 2 行 → 0.3
        let q = try #require(pack.buffer(for: 12, phase: .down))   // Q 在第 1 行 → 0.2
        // 除掉整包的响度归一增益，还原成录制电平再比对
        #expect(abs(a.floatChannelData![0][100] / pack.gain - 0.3) < 0.01)
        #expect(abs(q.floatChannelData![0][100] / pack.gain - 0.2) < 0.01)
    }
}

// MARK: - Mechvibes single（精灵）

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
        #expect(pack.buffer(for: 49, phase: .down) != nil)          // X11 57 = 空格
    }
}

// MARK: - KbSound 原生

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

// MARK: - 错误处理

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
        // 不该堆出 dup-1、dup-2 之类的重复目录
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
        // 失败后不能在用户目录里留下半成品，否则下次扫描会看到一个坏包
        let entries = (try? FileManager.default.contentsOfDirectory(atPath: destination.path)) ?? []
        #expect(entries.isEmpty)
    }
}

@Test func importsMultiPackThatMapsEveryKeyDirectly() throws {
    // 真实社区包（如 mechvibes-lofi-sounds）常见：sound 字段是不存在的占位，
    // 118 个键全在 defines 里逐个指定文件，完全不用行模式
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
        // 没在 defines 里的键也该有声音，而不是静默
        #expect(pack.buffer(for: 12, phase: .down) != nil)
    }
}
