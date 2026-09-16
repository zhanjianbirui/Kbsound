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
    // macOS number-row key codes are not contiguous, which is the easiest thing to get wrong
    #expect(KeycodeMap.macKeycode(forX11: 2) == 18)    // 1
    #expect(KeycodeMap.macKeycode(forX11: 6) == 23)    // 5
    #expect(KeycodeMap.macKeycode(forX11: 7) == 22)    // 6
    #expect(KeycodeMap.macKeycode(forX11: 11) == 29)   // 0
}

@Test func mapsModifiersAndArrows() {
    #expect(KeycodeMap.macKeycode(forX11: 42) == 56)   // left Shift
    #expect(KeycodeMap.macKeycode(forX11: 125) == 55)  // left Meta → Command
    #expect(KeycodeMap.macKeycode(forX11: 103) == 126) // up
    #expect(KeycodeMap.macKeycode(forX11: 108) == 125) // down
}

@Test func returnsNilForUnknownX11Code() {
    #expect(KeycodeMap.macKeycode(forX11: 9999) == nil)
}

@Test func x11MappingHasNoDuplicateTargets() {
    // Two X11 codes mapping to the same macOS code means the table is wrong
    let targets = KeycodeMap.x11ToMac.values
    #expect(Set(targets).count == targets.count)
}

@Test func assignsEveryMappedKeyToARow() {
    for mac in KeycodeMap.x11ToMac.values {
        #expect(KeycodeMap.row(forMac: mac) != nil, "key code \(mac) has no row")
    }
}

@Test func rowsMatchPhysicalKeyboardLayout() {
    #expect(KeycodeMap.row(forMac: 18) == 0)   // 1 → number row
    #expect(KeycodeMap.row(forMac: 12) == 1)   // Q → QWERTY row
    #expect(KeycodeMap.row(forMac: 0) == 2)    // A → ASDF row
    #expect(KeycodeMap.row(forMac: 6) == 3)    // Z → ZXCV row
    #expect(KeycodeMap.row(forMac: 49) == 4)   // space → bottom row
}

@Test func rowsAreDisjoint() {
    var seen = Set<Int>()
    for row in 0...4 {
        for code in KeycodeMap.keycodes(inRow: row) {
            #expect(seen.insert(code).inserted, "key code \(code) appears in more than one row")
        }
    }
}
