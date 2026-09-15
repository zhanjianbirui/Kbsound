import Foundation
import Testing
@testable import KbSoundCore

private func parse(_ json: String) throws -> MechvibesConfig {
    try JSONDecoder().decode(MechvibesConfig.self, from: Data(json.utf8))
}

@Test func parsesMultiFileConfig() throws {
    let config = try parse("""
    {"id":"x","name":"Turquoise","key_define_type":"multi",
     "sound":"press/GENERIC_R{0-4}.mp3","soundup":"release/GENERIC.mp3",
     "defines":{"14":"press/BACKSPACE.mp3","14-up":"release/BACKSPACE.mp3"}}
    """)
    #expect(config.name == "Turquoise")
    guard case .multi(let defines) = config.layout else {
        Issue.record("应解析为 multi"); return
    }
    #expect(defines["14"] == "press/BACKSPACE.mp3")
    #expect(config.soundup == "release/GENERIC.mp3")
}

@Test func parsesSingleSpriteConfig() throws {
    let config = try parse("""
    {"id":"y","name":"Sprite Pack","key_define_type":"single","sound":"sound.ogg",
     "defines":{"1":[0,120],"30":[500,140],"57":[1000,200]}}
    """)
    guard case .sprite(let slices) = config.layout else {
        Issue.record("应解析为 sprite"); return
    }
    #expect(slices["30"]?.offsetMs == 500)
    #expect(slices["30"]?.durationMs == 140)
    #expect(config.sound == "sound.ogg")
}

@Test func spriteEntriesThatAreNullAreSkipped() throws {
    // Mechvibes 的精灵包对未定义的键会写 null，不能让整份 config 解析失败
    let config = try parse("""
    {"id":"z","name":"P","key_define_type":"single","sound":"s.ogg",
     "defines":{"1":[0,100],"2":null}}
    """)
    guard case .sprite(let slices) = config.layout else {
        Issue.record("应解析为 sprite"); return
    }
    #expect(slices["1"] != nil)
    #expect(slices["2"] == nil)
}

@Test func expandsRowPatternIntoPerRowFiles() {
    let files = MechvibesConfig.expandRowPattern("press/GENERIC_R{0-4}.mp3")
    #expect(files?.count == 5)
    #expect(files?[0] == "press/GENERIC_R0.mp3")
    #expect(files?[4] == "press/GENERIC_R4.mp3")
}

@Test func returnsNilForNonPatternSoundPath() {
    #expect(MechvibesConfig.expandRowPattern("sound.ogg") == nil)
}

@Test func rejectsUnknownKeyDefineType() {
    #expect(throws: (any Error).self) {
        try parse("""
        {"id":"q","name":"N","key_define_type":"something-else","sound":"s.ogg","defines":{}}
        """)
    }
}

@Test func multiEntriesThatAreNullAreSkipped() throws {
    // 真实社区包的 defines 里同样会出现 null（未定义的键）
    let config = try parse("""
    {"id":"n","name":"N","key_define_type":"multi","sound":"s.ogg",
     "defines":{"1":"a.mp3","3597":null}}
    """)
    guard case .multi(let defines) = config.layout else {
        Issue.record("应解析为 multi"); return
    }
    #expect(defines["1"] == "a.mp3")
    #expect(defines["3597"] == nil)
}
