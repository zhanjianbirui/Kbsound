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
    #expect(player.reconnectCount == generation)  // Format unchanged, so it must not reconnect
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

    // Warm up to exclude the one-off cost of the first call
    for _ in 0..<10 { player.play(buffer) }

    let start = ContinuousClock.now
    for _ in 0..<100 { player.play(buffer) }
    let perCall = (ContinuousClock.now - start) / 100

    // The key callback has to return immediately. 1 ms is a very loose ceiling;
    // it normally takes tens of microseconds.
    #expect(perCall < .milliseconds(1))
    player.stop()
}
