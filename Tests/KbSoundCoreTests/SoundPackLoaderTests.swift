import Foundation
import Testing
@testable import KbSoundCore

/// 在临时目录里造一个音效包。`files` 是要创建的空占位文件名。
private func makePack(
    in root: URL,
    dirName: String,
    manifestJSON: String,
    files: [String]
) throws {
    let dir = root.appending(path: dirName)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    try Data(manifestJSON.utf8).write(to: dir.appending(path: "manifest.json"))
    for file in files {
        try Data().write(to: dir.appending(path: file))
    }
}

private func tempDir() throws -> URL {
    let url = URL.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func goodManifest(id: String, name: String) -> String {
    """
    {
      "formatVersion": 1, "id": "\(id)", "name": "\(name)",
      "defaults": { "down": "d.wav" }
    }
    """
}

@Test func findsPacksInASingleDirectory() throws {
    let root = try tempDir()
    try makePack(in: root, dirName: "alpha",
                 manifestJSON: goodManifest(id: "com.test.alpha", name: "Alpha"),
                 files: ["d.wav"])
    try makePack(in: root, dirName: "beta",
                 manifestJSON: goodManifest(id: "com.test.beta", name: "Beta"),
                 files: ["d.wav"])

    let packs = SoundPackLoader(searchPaths: [root]).availablePacks()
    #expect(packs.map(\.id) == ["com.test.alpha", "com.test.beta"])
    #expect(packs.map(\.name) == ["Alpha", "Beta"])
}

@Test func laterSearchPathOverridesEarlierWithSameID() throws {
    let builtIn = try tempDir()
    let user = try tempDir()
    try makePack(in: builtIn, dirName: "alpha",
                 manifestJSON: goodManifest(id: "com.test.alpha", name: "内置版"),
                 files: ["d.wav"])
    try makePack(in: user, dirName: "alpha",
                 manifestJSON: goodManifest(id: "com.test.alpha", name: "用户版"),
                 files: ["d.wav"])

    let packs = SoundPackLoader(searchPaths: [builtIn, user]).availablePacks()
    #expect(packs.count == 1)
    #expect(packs[0].name == "用户版")
}

@Test func skipsPackWithMissingAudioFile() throws {
    let root = try tempDir()
    try makePack(in: root, dirName: "broken",
                 manifestJSON: goodManifest(id: "com.test.broken", name: "Broken"),
                 files: [])  // manifest 引用了 d.wav 但文件不存在
    try makePack(in: root, dirName: "fine",
                 manifestJSON: goodManifest(id: "com.test.fine", name: "Fine"),
                 files: ["d.wav"])

    let packs = SoundPackLoader(searchPaths: [root]).availablePacks()
    #expect(packs.map(\.id) == ["com.test.fine"])
}

@Test func skipsPackWithUnparseableManifest() throws {
    let root = try tempDir()
    try makePack(in: root, dirName: "broken",
                 manifestJSON: "{ not json at all",
                 files: ["d.wav"])
    try makePack(in: root, dirName: "fine",
                 manifestJSON: goodManifest(id: "com.test.fine", name: "Fine"),
                 files: ["d.wav"])

    let packs = SoundPackLoader(searchPaths: [root]).availablePacks()
    #expect(packs.map(\.id) == ["com.test.fine"])
}

@Test func ignoresDirectoryWithoutManifest() throws {
    let root = try tempDir()
    try FileManager.default.createDirectory(
        at: root.appending(path: "not-a-pack"), withIntermediateDirectories: true)
    #expect(SoundPackLoader(searchPaths: [root]).availablePacks().isEmpty)
}

@Test func missingSearchPathIsNotAnError() {
    let ghost = URL.temporaryDirectory.appending(path: "definitely-does-not-exist-\(UUID())")
    #expect(SoundPackLoader(searchPaths: [ghost]).availablePacks().isEmpty)
}

@Test func resultIsSortedByDisplayName() throws {
    let root = try tempDir()
    try makePack(in: root, dirName: "z", manifestJSON: goodManifest(id: "com.test.z", name: "Zulu"), files: ["d.wav"])
    try makePack(in: root, dirName: "a", manifestJSON: goodManifest(id: "com.test.a", name: "Alpha"), files: ["d.wav"])
    let packs = SoundPackLoader(searchPaths: [root]).availablePacks()
    #expect(packs.map(\.name) == ["Alpha", "Zulu"])
}

@Test func allBundledPacksPassValidation() {
    let repoRoot = URL(filePath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let loader = SoundPackLoader(searchPaths: [repoRoot.appending(path: "Resources/Packs")])
    let packs = loader.availablePacks()
    #expect(packs.count == 21)
    #expect(packs.contains { $0.id == "com.klinkmac.mx-brown-pbt" })
}
