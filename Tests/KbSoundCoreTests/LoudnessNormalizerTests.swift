import AVFoundation
import Testing
@testable import KbSoundCore

private let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!

/// 造一个指定振幅的方波片段——方波的 RMS 就等于振幅，便于断言。
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
    // -40dBFS 的包应被拉高
    #expect(LoudnessNormalizer.gain(for: [makeTone(amplitude: 0.01)]) > 1)
}

@Test func attenuatesLoudPack() {
    #expect(LoudnessNormalizer.gain(for: [makeTone(amplitude: 0.5)]) < 1)
}

@Test func convergesLoudnessAcrossPacks() {
    // 两个相差 20dB 的包，归一后响度差应收敛到 3dB 以内
    let quiet = makeTone(amplitude: 0.004)
    let loud = makeTone(amplitude: 0.04)
    let quietOut = LoudnessNormalizer.applying(gain: LoudnessNormalizer.gain(for: [quiet]), to: quiet)
    let loudOut = LoudnessNormalizer.applying(gain: LoudnessNormalizer.gain(for: [loud]), to: loud)
    #expect(abs(decibels(onsetRMS(quietOut)) - decibels(onsetRMS(loudOut))) < 3)
}

@Test func neverPushesPeakAboveCeiling() {
    // 峰值高但 RMS 低（短瞬态 + 长衰减）——提升 RMS 会把峰值顶爆
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
    // 近乎无声的包不该被放大到爆炸
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
    // 比测量窗（120ms）短得多的音效也要能测
    let short = makeTone(amplitude: 0.2, ms: 5)
    #expect(onsetRMS(short) > 0.15)
}

@Test func packGainIsSharedAcrossAllItsSounds() {
    // 同一个包内部的音量关系必须保持——整包一个增益，不能逐文件归一
    let soft = makeTone(amplitude: 0.02)
    let hard = makeTone(amplitude: 0.2)
    let gain = LoudnessNormalizer.gain(for: [soft, hard])
    let softOut = LoudnessNormalizer.applying(gain: gain, to: soft)
    let hardOut = LoudnessNormalizer.applying(gain: gain, to: hard)
    #expect(abs(onsetRMS(hardOut) / onsetRMS(softOut) - 10) < 0.5)
}

// MARK: - 内置包的真实数据

private let repoRoot = URL(filePath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

@Test func bundledPacksConvergeToTheSameLoudness() throws {
    // 归一前跨度 23.7dB（topre-silent −16.6dBFS vs lofi −40.3dBFS），归一后 2.9dB。
    // 注意这里只管「齐不齐」，不管「响不响」——整体电平由 targetRMS 决定，
    // 由 normalizationDoesNotRaiseOverallLoudness 守住。
    // 这条测试锁住的是「切包不会忽大忽小」这个实际体感。
    // 只统计按下音；有独立抬键音的包（tplai 那几套）会因此略高一点，属预期。
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
    #expect(loudest - quietest < 3.5, "响度跨度 \(loudest - quietest)dB，包之间仍有明显落差：\(levels)")
}

@Test func noBundledPackClipsAfterNormalization() throws {
    let loader = SoundPackLoader(searchPaths: [repoRoot.appending(path: "Resources/Packs")])
    for ref in loader.availablePacks() {
        let pack = try LoadedPack(ref: ref)
        for keyCode in 0..<128 {
            for phase in [KeyPhase.down, .up] {
                guard let buffer = pack.buffer(for: keyCode, phase: phase) else { continue }
                #expect(LoudnessNormalizer.peak(of: buffer) <= 1.0, "\(ref.id) 削顶了")
            }
        }
    }
}

@Test func normalizationDoesNotRaiseOverallLoudness() throws {
    // 归一的职责是拉齐，不是变响。整体音量必须保持不变，否则用户每次
    // 升级后都得重新把滑块往回拉——最初取 −28dBFS 就犯了这个错，
    // 中位数被抬高 5.25dB。
    let loader = SoundPackLoader(searchPaths: [repoRoot.appending(path: "Resources/Packs")])
    let gains = try loader.availablePacks()
        .map { 20 * log10(try LoadedPack(ref: $0).gain) }
        .sorted()
    let median = gains[gains.count / 2]
    #expect(abs(median) < 1.5, "增益中位数 \(median)dB，整体音量被改变了")
}

@Test func defaultPackIsEssentiallyUnchanged() throws {
    // 绝大多数用户听的是默认包，它的增益必须接近 0dB
    let loader = SoundPackLoader(searchPaths: [repoRoot.appending(path: "Resources/Packs")])
    let ref = try #require(loader.availablePacks().first { $0.id == Settings.defaultPackID })
    let db = 20 * log10(try LoadedPack(ref: ref).gain)
    #expect(abs(db) < 1.5, "默认包增益 \(db)dB")
}
