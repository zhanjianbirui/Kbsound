import AppKit
import Testing
@testable import KbSoundCore

@Test func everySymbolNameResolvesToAnImage() {
    // NSImage returns nil for a misspelled symbol name and the status item goes blank —
    // an earlier version used "keyboard.slash", which does not exist, so the icon
    // disappeared entirely when permission was missing.
    for name in MenuBarIcon.allSymbolNames {
        #expect(NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil,
                "SF Symbol \"\(name)\" does not exist")
    }
}

@Test func alwaysProducesAnImageForBothStates() {
    #expect(MenuBarIcon.image(active: true) != nil)
    #expect(MenuBarIcon.image(active: false) != nil)
}

@Test func imagesAreTemplatesSoTheyAdaptToTheMenuBar() {
    #expect(MenuBarIcon.image(active: true)?.isTemplate == true)
    #expect(MenuBarIcon.image(active: false)?.isTemplate == true)
}

@Test func theTwoStatesLookDifferent() {
    // With the same symbol for both states the user cannot tell whether the switch worked
    #expect(MenuBarIcon.activeSymbol != MenuBarIcon.inactiveSymbol)
}

@Test func fallsBackToAValidSymbolWhenNameIsBogus() {
    #expect(MenuBarIcon.image(symbolName: "definitely.not.a.symbol") != nil)
}
