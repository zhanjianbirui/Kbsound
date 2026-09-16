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
  "description": "has both up and down",
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
    #expect(m.detail == "has both up and down")
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
    // keyCode 51 only defines down, so up falls back to defaults
    let m = try decode(fullJSON)
    #expect(m.fileName(for: 51, phase: .down) == "backspace-down.wav")
    #expect(m.fileName(for: 51, phase: .up) == "default-up.wav")
}

@Test func returnsNilWhenNoSoundAnywhere() throws {
    // A down-only pack (most real packs) should return nil for up rather than crash
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
    // Missing defaults — it is required, so decoding must fail rather than yield half a pack
    #expect(throws: (any Error).self) {
        try decode("""
        { "formatVersion": 1, "id": "com.test.bad", "name": "Bad" }
        """)
    }
}
