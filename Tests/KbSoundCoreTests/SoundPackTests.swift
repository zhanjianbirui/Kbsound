import Foundation
import Testing
@testable import KbSoundCore

private func decode(_ json: String) throws -> PackManifest {
    try JSONDecoder().decode(PackManifest.self, from: Data(json.utf8))
}

private let fullJSON = """
{
  "formatVersion": 1,
  "id": "com.test.full",
  "name": "Full Pack",
  "author": "Tester",
  "description": "有 up 也有 down",
  "defaults": { "down": "default-down.wav", "up": "default-up.wav" },
  "keys": {
    "49": { "down": "space-down.wav", "up": "space-up.wav" },
    "51": { "down": "backspace-down.wav" }
  }
}
"""

@Test func decodesAllFields() throws {
    let m = try decode(fullJSON)
    #expect(m.formatVersion == 1)
    #expect(m.id == "com.test.full")
    #expect(m.name == "Full Pack")
    #expect(m.author == "Tester")
    #expect(m.detail == "有 up 也有 down")
}

@Test func specificKeyWinsOverDefaults() throws {
    let m = try decode(fullJSON)
    #expect(m.fileName(for: 49, phase: .down) == "space-down.wav")
    #expect(m.fileName(for: 49, phase: .up) == "space-up.wav")
}

@Test func fallsBackToDefaultsForUnmappedKey() throws {
    let m = try decode(fullJSON)
    #expect(m.fileName(for: 999, phase: .down) == "default-down.wav")
    #expect(m.fileName(for: 999, phase: .up) == "default-up.wav")
}

@Test func fallsBackToDefaultsWhenPhaseMissingOnKey() throws {
    // keyCode 51 只定义了 down，up 应回退到 defaults
    let m = try decode(fullJSON)
    #expect(m.fileName(for: 51, phase: .down) == "backspace-down.wav")
    #expect(m.fileName(for: 51, phase: .up) == "default-up.wav")
}

@Test func returnsNilWhenNoSoundAnywhere() throws {
    // 只有 down 的包（多数真实包如此），up 应返回 nil 而不是崩溃
    let m = try decode("""
    {
      "formatVersion": 1, "id": "com.test.downonly", "name": "Down Only",
      "defaults": { "down": "d.wav" }
    }
    """)
    #expect(m.fileName(for: 1, phase: .down) == "d.wav")
    #expect(m.fileName(for: 1, phase: .up) == nil)
}

@Test func ignoresNonNumericKeys() throws {
    let m = try decode("""
    {
      "formatVersion": 1, "id": "com.test.junk", "name": "Junk",
      "defaults": { "down": "d.wav" },
      "keys": { "abc": { "down": "junk.wav" } }
    }
    """)
    #expect(m.fileName(for: 1, phase: .down) == "d.wav")
    #expect(m.referencedFiles == ["d.wav", "junk.wav"])
}

@Test func collectsEveryReferencedFile() throws {
    let m = try decode(fullJSON)
    #expect(m.referencedFiles == [
        "default-down.wav", "default-up.wav",
        "space-down.wav", "space-up.wav", "backspace-down.wav",
    ])
}

@Test func missingRequiredFieldThrows() {
    // 缺 defaults —— 必填，应当解码失败而不是给出半个包
    #expect(throws: (any Error).self) {
        try decode("""
        { "formatVersion": 1, "id": "com.test.bad", "name": "Bad" }
        """)
    }
}
