import Testing
@testable import KbSoundCore

@Test func firstEventForAKeyIsDown() {
    var tracker = ModifierTracker()
    #expect(tracker.phase(forKeyCode: 56) == .down)   // 56 = left Shift
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
    #expect(tracker.phase(forKeyCode: 56) == .down)   // press Shift
    #expect(tracker.phase(forKeyCode: 55) == .down)   // then press Command
    #expect(tracker.phase(forKeyCode: 56) == .up)     // release Shift; Command is unaffected
    #expect(tracker.phase(forKeyCode: 55) == .up)     // release Command
}

@Test func resetClearsAllHeldKeys() {
    // After losing focus or restarting the tap the state may not match reality; reset makes
    // the next event start from down again
    var tracker = ModifierTracker()
    _ = tracker.phase(forKeyCode: 56)
    tracker.reset()
    #expect(tracker.phase(forKeyCode: 56) == .down)
}
