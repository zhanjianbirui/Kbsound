import Testing
@testable import KbSoundCore

@Test func keyPhaseHasTwoDistinctCases() {
    #expect(KeyPhase.down != KeyPhase.up)
}
