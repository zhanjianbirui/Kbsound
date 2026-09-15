import AVFoundation
import Foundation
import os

/// AVAudioEngine + 固定大小的播放节点池。
///
/// 全部在主线程使用：CGEventTap 的回调挂在主 run loop 上。
@MainActor
public final class AudioPlayer {
    private static let logger = Logger(subsystem: "com.kbsound", category: "Audio")

    private let engine = AVAudioEngine()
    private let nodes: [AVAudioPlayerNode]
    private var nextNode = 0
    private var currentFormat: AVAudioFormat?
    private var storedVolume: Float = 0.5
    private var configObserver: (any NSObjectProtocol)?

    /// 重连次数，仅供测试断言 prepare 的幂等性。
    private(set) var reconnectCount = 0

    public init(nodeCount: Int = 16) {
        self.nodes = (0..<nodeCount).map { _ in AVAudioPlayerNode() }
        configObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleConfigurationChange()
            }
        }
    }

    /// `isolated deinit`：观察者是非 Sendable 的，nonisolated deinit 在 Swift 6
    /// 严格并发下不允许访问它。
    isolated deinit {
        if let configObserver {
            NotificationCenter.default.removeObserver(configObserver)
        }
    }

    /// 音量，钳制到 0...1。跨重连保留。
    public var volume: Float {
        get { storedVolume }
        set {
            storedVolume = min(max(newValue, 0), 1)
            engine.mainMixerNode.outputVolume = storedVolume
        }
    }

    /// 让引擎准备好播放该格式的 buffer。格式未变时是空操作。
    public func prepare(format: AVAudioFormat) throws {
        guard currentFormat != format else { return }

        if engine.isRunning { engine.stop() }
        for node in nodes where node.engine != nil {
            engine.disconnectNodeOutput(node)
            engine.detach(node)
        }
        for node in nodes {
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
        }

        engine.prepare()
        try engine.start()
        for node in nodes { node.play() }

        engine.mainMixerNode.outputVolume = storedVolume
        currentFormat = format
        reconnectCount += 1
        Self.logger.info("引擎已就绪 \(format.sampleRate, privacy: .public)Hz \(format.channelCount, privacy: .public)ch")
    }

    /// 播放一声。轮转节点，让连打时前后两声能重叠。
    public func play(_ buffer: AVAudioPCMBuffer) {
        guard engine.isRunning else { return }
        let node = nodes[nextNode]
        nextNode = (nextNode + 1) % nodes.count
        node.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
    }

    public func stop() {
        for node in nodes where node.isPlaying { node.stop() }
        if engine.isRunning { engine.stop() }
        currentFormat = nil
    }

    /// 插拔耳机、切换输出设备后引擎会失效，用当前格式重建。
    private func handleConfigurationChange() {
        guard let format = currentFormat else { return }
        Self.logger.info("音频设备变化，重建引擎")
        currentFormat = nil
        do {
            try prepare(format: format)
        } catch {
            Self.logger.error("重建引擎失败：\(error.localizedDescription, privacy: .public)")
        }
    }
}
