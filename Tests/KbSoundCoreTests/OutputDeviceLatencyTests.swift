import Testing
@testable import KbSoundCore

@Test func clampsDesiredSizeIntoDeviceRange() {
    // When a device only accepts 256...4096, a request for 128 has to be raised to 256
    #expect(OutputDeviceLatency.clamped(128, to: 256...4096) == 256)
}

@Test func keepsDesiredSizeWhenDeviceAllowsIt() {
    #expect(OutputDeviceLatency.clamped(128, to: 64...4096) == 128)
}

@Test func clampsDownWhenDeviceMaximumIsSmall() {
    #expect(OutputDeviceLatency.clamped(128, to: 32...64) == 64)
}

@Test func preferredSizeIsSmallerThanTypicalDefault() {
    // The system default is usually 512 frames; ours has to be clearly smaller to matter
    #expect(OutputDeviceLatency.preferredFrames < 512)
}
