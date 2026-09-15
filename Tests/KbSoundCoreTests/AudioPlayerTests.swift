import AVFoundation
import Testing
@testable import KbSoundCore

private func testFormat(sampleRate: Double = 44100, channels: AVAudioChannelCount = 2) -> AVAudioFormat {
    AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels)!
}

@MainActor
@Test func volumeIsClamped() {
    let player = AudioPlayer()
    player.volume = 2
    #expect(player.volume == 1)
    player.volume = -1
    #expect(player.volume == 0)
}

@MainActor
@Test func prepareIsIdempotentForSameFormat() throws {
    let player = AudioPlayer()
    let format = testFormat()
    try player.prepare(format: format)
    let generation = player.reconnectCount
    try player.prepare(format: format)
    #expect(player.reconnectCount == generation)  // 格式没变，不该重连
    player.stop()
}

@MainActor
@Test func prepareReconnectsWhenFormatChanges() throws {
    let player = AudioPlayer()
    try player.prepare(format: testFormat(sampleRate: 44100, channels: 2))
    let generation = player.reconnectCount
    try player.prepare(format: testFormat(sampleRate: 48000, channels: 1))
    #expect(player.reconnectCount == generation + 1)
    player.stop()
}

@MainActor
@Test func volumeSurvivesReconnect() throws {
    let player = AudioPlayer()
    player.volume = 0.3
    try player.prepare(format: testFormat())
    #expect(player.volume == 0.3)
    player.stop()
}

@MainActor
@Test func playReturnsFastEnoughForKeyCallback() throws {
    let player = AudioPlayer()
    let format = testFormat()
    try player.prepare(format: format)
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4410)!
    buffer.frameLength = 4410

    // 预热，排除首次调用的一次性开销
    for _ in 0..<10 { player.play(buffer) }

    let start = ContinuousClock.now
    for _ in 0..<100 { player.play(buffer) }
    let perCall = (ContinuousClock.now - start) / 100

    // 按键回调必须立刻返回。1ms 是很宽松的上限，正常应在几十微秒。
    #expect(perCall < .milliseconds(1))
    player.stop()
}
