import AppKit
import Testing
@testable import KbSoundCore

@Test func everySymbolNameResolvesToAnImage() {
    // 符号名写错时 NSImage 返回 nil，菜单栏按钮会变成空白不可见——
    // 曾经用过并不存在的 "keyboard.slash"，没权限时图标就整个消失了。
    for name in MenuBarIcon.allSymbolNames {
        #expect(NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil,
                "SF Symbol \"\(name)\" 不存在")
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
    // 两个状态用同一个符号的话，用户看不出开关有没有生效
    #expect(MenuBarIcon.activeSymbol != MenuBarIcon.inactiveSymbol)
}

@Test func fallsBackToAValidSymbolWhenNameIsBogus() {
    #expect(MenuBarIcon.image(symbolName: "definitely.not.a.symbol") != nil)
}
