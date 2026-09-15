import Testing
@testable import KbSoundCore

@Test func mapsLetterKeysFromX11ToMac() {
    #expect(KeycodeMap.macKeycode(forX11: 30) == 0)    // A
    #expect(KeycodeMap.macKeycode(forX11: 16) == 12)   // Q
    #expect(KeycodeMap.macKeycode(forX11: 44) == 6)    // Z
}

@Test func mapsTheThreeSpecialKeysUsedByEveryMechvibesPack() {
    #expect(KeycodeMap.macKeycode(forX11: 14) == 51)   // Backspace
    #expect(KeycodeMap.macKeycode(forX11: 28) == 36)   // Enter
    #expect(KeycodeMap.macKeycode(forX11: 57) == 49)   // Space
}

@Test func mapsDigitsWhoseMacCodesAreNotInOrder() {
    // macOS 的数字键键码不是连号的，最容易写错
    #expect(KeycodeMap.macKeycode(forX11: 2) == 18)    // 1
    #expect(KeycodeMap.macKeycode(forX11: 6) == 23)    // 5
    #expect(KeycodeMap.macKeycode(forX11: 7) == 22)    // 6
    #expect(KeycodeMap.macKeycode(forX11: 11) == 29)   // 0
}

@Test func mapsModifiersAndArrows() {
    #expect(KeycodeMap.macKeycode(forX11: 42) == 56)   // 左 Shift
    #expect(KeycodeMap.macKeycode(forX11: 125) == 55)  // 左 Meta → Command
    #expect(KeycodeMap.macKeycode(forX11: 103) == 126) // 上
    #expect(KeycodeMap.macKeycode(forX11: 108) == 125) // 下
}

@Test func returnsNilForUnknownX11Code() {
    #expect(KeycodeMap.macKeycode(forX11: 9999) == nil)
}

@Test func x11MappingHasNoDuplicateTargets() {
    // 两个 X11 键码映射到同一个 macOS 键码，说明表写错了
    let targets = KeycodeMap.x11ToMac.values
    #expect(Set(targets).count == targets.count)
}

@Test func assignsEveryMappedKeyToARow() {
    for mac in KeycodeMap.x11ToMac.values {
        #expect(KeycodeMap.row(forMac: mac) != nil, "键码 \(mac) 没有归行")
    }
}

@Test func rowsMatchPhysicalKeyboardLayout() {
    #expect(KeycodeMap.row(forMac: 18) == 0)   // 数字 1 → 数字行
    #expect(KeycodeMap.row(forMac: 12) == 1)   // Q → QWERTY 行
    #expect(KeycodeMap.row(forMac: 0) == 2)    // A → ASDF 行
    #expect(KeycodeMap.row(forMac: 6) == 3)    // Z → ZXCV 行
    #expect(KeycodeMap.row(forMac: 49) == 4)   // 空格 → 底排
}

@Test func rowsAreDisjoint() {
    var seen = Set<Int>()
    for row in 0...4 {
        for code in KeycodeMap.keycodes(inRow: row) {
            #expect(seen.insert(code).inserted, "键码 \(code) 出现在多行")
        }
    }
}
