import Testing
@testable import KbSoundCore

@Test func firstEventForAKeyIsDown() {
    var tracker = ModifierTracker()
    #expect(tracker.phase(forKeyCode: 56) == .down)   // 56 = 左 Shift
}

@Test func secondEventForSameKeyIsUp() {
    var tracker = ModifierTracker()
    _ = tracker.phase(forKeyCode: 56)
    #expect(tracker.phase(forKeyCode: 56) == .up)
}

@Test func phaseAlternatesAcrossRepeatedPresses() {
    var tracker = ModifierTracker()
    #expect(tracker.phase(forKeyCode: 56) == .down)
    #expect(tracker.phase(forKeyCode: 56) == .up)
    #expect(tracker.phase(forKeyCode: 56) == .down)
    #expect(tracker.phase(forKeyCode: 56) == .up)
}

@Test func differentModifiersTrackedIndependently() {
    var tracker = ModifierTracker()
    #expect(tracker.phase(forKeyCode: 56) == .down)   // 按下 Shift
    #expect(tracker.phase(forKeyCode: 55) == .down)   // 再按下 Command
    #expect(tracker.phase(forKeyCode: 56) == .up)     // 松开 Shift，Command 不受影响
    #expect(tracker.phase(forKeyCode: 55) == .up)     // 松开 Command
}

@Test func resetClearsAllHeldKeys() {
    // 失焦或 tap 重启后状态可能与现实不符，reset 让下一次事件重新从 down 开始
    var tracker = ModifierTracker()
    _ = tracker.phase(forKeyCode: 56)
    tracker.reset()
    #expect(tracker.phase(forKeyCode: 56) == .down)
}
