import AVFoundation
import Foundation
import os

public enum PackLoadError: Error, Equatable {
    /// manifest 一个音频文件都没引用。
    case empty
    /// 同一个包里混了不同采样率/声道数——AVAudioPlayerNode 一次只能连一种格式。
    case mixedFormats
    case unreadable(String)
}

/// 已经解码到内存、可以直接播放的音效包。
///
/// 按键回调必须在几毫秒内返回，所以整包在切换时一次性解码成常驻内存的 PCM buffer，
/// 回调里只剩字典查找——绝不在回调里做文件 I/O。
///
/// `@unchecked Sendable`：`AVAudioPCMBuffer` 不是 `Sendable`，
/// 但本类型构造完成后完全只读，且只在主线程使用。
public struct LoadedPack: @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.kbsound", category: "LoadedPack")

    public let ref: PackRef
    /// 本包统一的音频格式。包与包之间格式并不一致（有 44.1k 立体声也有 48k 单声道），
    /// 所以 AudioPlayer 切包时必须据此重连节点。
    public let format: AVAudioFormat

    /// macOS 虚拟键码的取值范围，用于遍历整个键盘。
    private static let keyCodeRange = 128

    /// 本包的响度归一增益，1 表示未调整。仅供日志与测试观察。
    public let gain: Float

    private let manifest: PackManifest
    /// 文件名 → buffer。同一文件被多个 keyCode 引用时只存一份。
    private let buffers: [String: AVAudioPCMBuffer]

    public init(ref: PackRef) throws {
        let manifestURL = ref.directory.appending(path: "manifest.json")
        let manifest = try JSONDecoder().decode(
            PackManifest.self, from: Data(contentsOf: manifestURL))

        var buffers: [String: AVAudioPCMBuffer] = [:]
        var format: AVAudioFormat?

        for fileName in manifest.referencedFiles.sorted() {
            let url = ref.directory.appending(path: fileName)
            let file: AVAudioFile
            do {
                file = try AVAudioFile(forReading: url)
            } catch {
                Self.logger.error("\(fileName, privacy: .public) 无法读取: \(error.localizedDescription, privacy: .public)")
                throw PackLoadError.unreadable(fileName)
            }

            if let format, format != file.processingFormat {
                Self.logger.error("\(manifest.id, privacy: .public) 内部音频格式不一致")
                throw PackLoadError.mixedFormats
            }
            format = file.processingFormat

            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: file.processingFormat,
                frameCapacity: AVAudioFrameCount(file.length)
            ) else {
                throw PackLoadError.unreadable(fileName)
            }
            try file.read(into: buffer)
            // 裁掉前导低电平段——这是按键到出声之间最大的延迟来源
            buffers[fileName] = AudioTrim.trimmingLeadIn(buffer)
        }

        guard let format else { throw PackLoadError.empty }

        // 整包一个增益，各包响度才对得齐；包内的强弱关系原样保留。
        // 按键位数加权：一个文件被多少个键用到，就在测量里占多少分量——
        // 决定「打起来有多响」的是覆盖大多数键的那个默认音，不是只给空格用的那个。
        let weighted = (0..<Self.keyCodeRange).flatMap { keyCode in
            [KeyPhase.down, .up].compactMap { phase in
                manifest.fileName(for: keyCode, phase: phase).flatMap { buffers[$0] }
            }
        }
        let gain = LoudnessNormalizer.gain(for: weighted)
        Self.logger.info("\(manifest.id, privacy: .public) 响度增益 \(gain, privacy: .public)x")

        self.ref = ref
        self.manifest = manifest
        self.buffers = buffers.mapValues { LoudnessNormalizer.applying(gain: gain, to: $0) }
        self.gain = gain
        self.format = format
    }

    /// 按键该播的 buffer；没有对应音效时返回 nil（例如包里没定义 up）。
    public func buffer(for keyCode: Int, phase: KeyPhase) -> AVAudioPCMBuffer? {
        guard let fileName = manifest.fileName(for: keyCode, phase: phase) else { return nil }
        return buffers[fileName]
    }
}
