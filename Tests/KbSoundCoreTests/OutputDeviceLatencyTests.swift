import Testing
@testable import KbSoundCore

@Test func clampsDesiredSizeIntoDeviceRange() {
    // 设备只接受 256...4096 时，128 的诉求要抬到 256
    #expect(OutputDeviceLatency.clamped(128, to: 256...4096) == 256)
}

@Test func keepsDesiredSizeWhenDeviceAllowsIt() {
    #expect(OutputDeviceLatency.clamped(128, to: 64...4096) == 128)
}

@Test func clampsDownWhenDeviceMaximumIsSmall() {
    #expect(OutputDeviceLatency.clamped(128, to: 32...64) == 64)
}

@Test func preferredSizeIsSmallerThanTypicalDefault() {
    // 系统默认通常是 512 frames；我们要明显更小才有意义
    #expect(OutputDeviceLatency.preferredFrames < 512)
}
