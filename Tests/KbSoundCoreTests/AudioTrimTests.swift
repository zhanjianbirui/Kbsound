import AVFoundation
import Testing
@testable import KbSoundCore

private let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!

/// 造一个「前 silentMs 毫秒极轻，随后满幅」的 buffer。
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
    // 20ms 处起振，预卷 2ms，所以应裁掉约 18ms
    #expect(ms(onset) > 17 && ms(onset) < 19)
}

@Test func doesNotTrimSoundThatStartsImmediately() {
    #expect(AudioTrim.leadingFramesBeforeOnset(in: makeBuffer(silentMs: 0, loudMs: 50)) == 0)
}

@Test func keepsPreRollSoTransientIsNotClipped() {
    // 起振点之前必须保留一小段，否则瞬态被削平会变成爆音
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
    // 裁完之后 3ms 内就该到满幅（2ms 预卷 + 一点余量）
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
    // 全静音（例如某些包的抬键音极轻）不该被整段裁掉
    let silent = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 480)!
    silent.frameLength = 480
    #expect(AudioTrim.leadingFramesBeforeOnset(in: silent) == 0)
}
