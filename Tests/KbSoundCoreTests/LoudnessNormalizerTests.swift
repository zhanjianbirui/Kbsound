import AVFoundation
import Testing
@testable import KbSoundCore

private let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!

/// Builds a square-wave segment at a given amplitude — the RMS of a square wave equals
/// its amplitude, which makes assertions easy.
private func makeTone(amplitude: Float, ms: Double = 200) -> AVAudioPCMBuffer {
    let frames = AVAudioFrameCount(48.0 * ms)
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
    buffer.frameLength = frames
    let data = buffer.floatChannelData![0]
    for i in 0..<Int(frames) { data[i] = i % 2 == 0 ? amplitude : -amplitude }
    return buffer
}

private func onsetRMS(_ buffer: AVAudioPCMBuffer) -> Float {
    LoudnessNormalizer.onsetRMS(of: buffer)
}

private func decibels(_ linear: Float) -> Float { 20 * log10(linear) }

@Test func boostsQuietPack() {
    // A −40 dBFS pack should be brought up
    #expect(LoudnessNormalizer.gain(for: [makeTone(amplitude: 0.01)]) > 1)
}

@Test func attenuatesLoudPack() {
    #expect(LoudnessNormalizer.gain(for: [makeTone(amplitude: 0.5)]) < 1)
}

@Test func convergesLoudnessAcrossPacks() {
    // Two packs 20 dB apart should end up within 3 dB of each other
    let quiet = makeTone(amplitude: 0.004)
    let loud = makeTone(amplitude: 0.04)
    let quietOut = LoudnessNormalizer.applying(gain: LoudnessNormalizer.gain(for: [quiet]), to: quiet)
    let loudOut = LoudnessNormalizer.applying(gain: LoudnessNormalizer.gain(for: [loud]), to: loud)
    #expect(abs(decibels(onsetRMS(quietOut)) - decibels(onsetRMS(loudOut))) < 3)
}

@Test func neverPushesPeakAboveCeiling() {
    // High peak but low RMS (short transient, long decay) — raising the RMS would push the
    // peak past full scale
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 9600)!
    buffer.frameLength = 9600
    let data = buffer.floatChannelData![0]
    for i in 0..<9600 { data[i] = i < 48 ? 0.95 : 0.001 }

    let output = LoudnessNormalizer.applying(gain: LoudnessNormalizer.gain(for: [buffer]), to: buffer)
    var peak: Float = 0
    for i in 0..<Int(output.frameLength) { peak = max(peak, abs(output.floatChannelData![0][i])) }
    #expect(peak <= LoudnessNormalizer.peakCeiling)
}

@Test func clampsGainToSaneRange() {
    // A nearly silent pack must not be amplified into noise
    #expect(LoudnessNormalizer.gain(for: [makeTone(amplitude: 0.000001)]) <= LoudnessNormalizer.maxGain)
}

@Test func silentPackKeepsUnityGain() {
    let silent = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 480)!
    silent.frameLength = 480
    #expect(LoudnessNormalizer.gain(for: [silent]) == 1)
}

@Test func emptyPackKeepsUnityGain() {
    #expect(LoudnessNormalizer.gain(for: []) == 1)
}

@Test func unityGainReturnsOriginalBuffer() {
    let original = makeTone(amplitude: 0.1)
    #expect(LoudnessNormalizer.applying(gain: 1, to: original) === original)
}

@Test func doesNotMutateSourceBuffer() {
    let original = makeTone(amplitude: 0.5)
    let before = original.floatChannelData![0][0]
    _ = LoudnessNormalizer.applying(gain: 0.25, to: original)
    #expect(original.floatChannelData![0][0] == before)
}

@Test func appliedGainScalesSamples() {
    let original = makeTone(amplitude: 0.4)
    let output = LoudnessNormalizer.applying(gain: 0.5, to: original)
    #expect(abs(output.floatChannelData![0][0] - 0.2) < 0.0001)
    #expect(output.frameLength == original.frameLength)
}

@Test func measuresShortBufferWithoutCrashing() {
    // Sounds far shorter than the measurement window (120 ms) must still be measurable
    let short = makeTone(amplitude: 0.2, ms: 5)
    #expect(onsetRMS(short) > 0.15)
}

@Test func packGainIsSharedAcrossAllItsSounds() {
    // Relative levels inside a pack must survive — one gain per pack, never per file
    let soft = makeTone(amplitude: 0.02)
    let hard = makeTone(amplitude: 0.2)
    let gain = LoudnessNormalizer.gain(for: [soft, hard])
    let softOut = LoudnessNormalizer.applying(gain: gain, to: soft)
    let hardOut = LoudnessNormalizer.applying(gain: gain, to: hard)
    #expect(abs(onsetRMS(hardOut) / onsetRMS(softOut) - 10) < 0.5)
}

// MARK: - Real data from the bundled packs

private let repoRoot = URL(filePath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

@Test func bundledPacksConvergeToTheSameLoudness() throws {
    // The spread is 23.7 dB before normalization (topre-silent −16.6 dBFS vs lofi
    // −40.3 dBFS) and 2.9 dB after.
    // This test is only about *alignment*, not absolute level — overall level is set by
    // targetRMS and guarded by normalizationDoesNotRaiseOverallLoudness.
    // What it locks down is the felt behavior: switching packs no longer jumps in volume.
    // Only key-down sounds are counted; packs with their own key-up sounds (the tplai
    // ones) read slightly higher as a result, which is expected.
    let loader = SoundPackLoader(searchPaths: [repoRoot.appending(path: "Resources/Packs")])
    var levels: [String: Float] = [:]

    for ref in loader.availablePacks() {
        let pack = try LoadedPack(ref: ref)
        let sounds = (0..<128).compactMap { pack.buffer(for: $0, phase: .down) }
        guard !sounds.isEmpty else { continue }
        let energy = sounds.reduce(Float(0)) { $0 + pow(LoudnessNormalizer.onsetRMS(of: $1), 2) }
        levels[ref.id] = 20 * log10((energy / Float(sounds.count)).squareRoot())
    }

    let loudest = try #require(levels.values.max())
    let quietest = try #require(levels.values.min())
    #expect(loudest - quietest < 3.5, "spread of \(loudest - quietest)dB, packs still differ noticeably: \(levels)")
}

@Test func noBundledPackClipsAfterNormalization() throws {
    let loader = SoundPackLoader(searchPaths: [repoRoot.appending(path: "Resources/Packs")])
    for ref in loader.availablePacks() {
        let pack = try LoadedPack(ref: ref)
        for keyCode in 0..<128 {
            for phase in [KeyPhase.down, .up] {
                guard let buffer = pack.buffer(for: keyCode, phase: phase) else { continue }
                #expect(LoudnessNormalizer.peak(of: buffer) <= 1.0, "\(ref.id) clipped")
            }
        }
    }
}

@Test func normalizationDoesNotRaiseOverallLoudness() throws {
    // Normalization aligns; it does not make things louder. Overall volume has to stay put,
    // or users would have to pull the slider back after every upgrade — the original
    // −28 dBFS target made exactly that mistake and raised the median by 5.25 dB.
    let loader = SoundPackLoader(searchPaths: [repoRoot.appending(path: "Resources/Packs")])
    let gains = try loader.availablePacks()
        .map { 20 * log10(try LoadedPack(ref: $0).gain) }
        .sorted()
    let median = gains[gains.count / 2]
    #expect(abs(median) < 1.5, "median gain \(median)dB, overall volume was changed")
}

@Test func defaultPackIsEssentiallyUnchanged() throws {
    // Nearly everyone hears the default pack, so its gain has to stay close to 0 dB
    let loader = SoundPackLoader(searchPaths: [repoRoot.appending(path: "Resources/Packs")])
    let ref = try #require(loader.availablePacks().first { $0.id == Settings.defaultPackID })
    let db = 20 * log10(try LoadedPack(ref: ref).gain)
    #expect(abs(db) < 1.5, "default pack gain \(db)dB")
}
