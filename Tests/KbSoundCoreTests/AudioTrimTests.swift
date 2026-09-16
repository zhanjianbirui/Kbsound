import AVFoundation
import Testing
@testable import KbSoundCore

private let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!

/// Builds a buffer that is very quiet for the first `silentMs` milliseconds and then
/// jumps to full scale.
private func makeBuffer(silentMs: Double, loudMs: Double, quietLevel: Float = 0.02) -> AVAudioPCMBuffer {
    let silent = Int(48.0 * silentMs), loud = Int(48.0 * loudMs)
    let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                  frameCapacity: AVAudioFrameCount(silent + loud))!
    buffer.frameLength = AVAudioFrameCount(silent + loud)
    let data = buffer.floatChannelData![0]
    for i in 0..<silent { data[i] = quietLevel }
    for i in silent..<(silent + loud) { data[i] = 1.0 }
    return buffer
}

private func ms(_ frames: AVAudioFrameCount) -> Double { Double(frames) / 48.0 }

@Test func findsOnsetAfterQuietLeadIn() {
    let onset = AudioTrim.leadingFramesBeforeOnset(in: makeBuffer(silentMs: 20, loudMs: 50))
    // Onset at 20 ms with 2 ms of pre-roll, so about 18 ms should be trimmed
    #expect(ms(onset) > 17 && ms(onset) < 19)
}

@Test func doesNotTrimSoundThatStartsImmediately() {
    #expect(AudioTrim.leadingFramesBeforeOnset(in: makeBuffer(silentMs: 0, loudMs: 50)) == 0)
}

@Test func keepsPreRollSoTransientIsNotClipped() {
    // A little has to survive before the onset, or the flattened transient clicks
    let onset = AudioTrim.leadingFramesBeforeOnset(in: makeBuffer(silentMs: 50, loudMs: 50))
    #expect(ms(onset) < 50)
}

@Test func trimmedBufferIsShorterByTheTrimmedAmount() {
    let original = makeBuffer(silentMs: 20, loudMs: 50)
    let trimmed = AudioTrim.trimmingLeadIn(original)
    let removed = original.frameLength - trimmed.frameLength
    #expect(ms(removed) > 17 && ms(removed) < 19)
}

@Test func trimmedBufferStartsNearFullAmplitude() {
    let trimmed = AudioTrim.trimmingLeadIn(makeBuffer(silentMs: 20, loudMs: 50))
    // After trimming, full scale should arrive within 3 ms (2 ms pre-roll plus slack)
    let window = Int(48.0 * 3)
    var peak: Float = 0
    for i in 0..<min(window, Int(trimmed.frameLength)) {
        peak = max(peak, abs(trimmed.floatChannelData![0][i]))
    }
    #expect(peak > 0.9)
}

@Test func returnsOriginalWhenNothingToTrim() {
    let original = makeBuffer(silentMs: 0, loudMs: 50)
    #expect(AudioTrim.trimmingLeadIn(original) === original)
}

@Test func handlesAllSilentBufferWithoutTrimming() {
    // Fully silent buffers (some packs have extremely quiet key-up sounds) must not be
    // trimmed away entirely
    let silent = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 480)!
    silent.frameLength = 480
    #expect(AudioTrim.leadingFramesBeforeOnset(in: silent) == 0)
}
