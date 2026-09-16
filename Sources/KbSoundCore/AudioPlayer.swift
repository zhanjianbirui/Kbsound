import AVFoundation
import Foundation
import os

/// `AVAudioEngine` plus a fixed-size pool of player nodes.
///
/// Used entirely from the main thread: the `CGEventTap` callback runs on the main
/// run loop.
@MainActor
public final class AudioPlayer {
    private static let logger = Logger(subsystem: "com.kbsound", category: "Audio")

    private let engine = AVAudioEngine()
    private let nodes: [AVAudioPlayerNode]
    private var nextNode = 0
    private var currentFormat: AVAudioFormat?
    private var storedVolume: Float = 0.5
    private var configObserver: (any NSObjectProtocol)?

    /// Number of reconnects, used only by tests to assert that `prepare` is idempotent.
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

    /// `isolated deinit`: the observer is non-Sendable, and a nonisolated deinit is
    /// not allowed to touch it under Swift 6 strict concurrency.
    isolated deinit {
        if let configObserver {
            NotificationCenter.default.removeObserver(configObserver)
        }
    }

    /// Volume, clamped to 0...1. Preserved across reconnects.
    public var volume: Float {
        get { storedVolume }
        set {
            storedVolume = min(max(newValue, 0), 1)
            engine.mainMixerNode.outputVolume = storedVolume
        }
    }

    /// Gets the engine ready to play buffers in this format. A no-op when the format
    /// has not changed.
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

        // Must happen before start: the buffer size sets the quantization of playback
        // scheduling and is the main contributor to the gap between key and sound.
        // This method runs again after a device change.
        OutputDeviceLatency.minimize()

        engine.prepare()
        try engine.start()
        for node in nodes { node.play() }

        engine.mainMixerNode.outputVolume = storedVolume
        currentFormat = format
        reconnectCount += 1
        Self.logger.info("Engine ready at \(format.sampleRate, privacy: .public)Hz \(format.channelCount, privacy: .public)ch")
    }

    /// Plays one sound. Nodes rotate so consecutive keystrokes can overlap.
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

    /// The engine is invalidated when headphones are plugged in or the output device
    /// changes; rebuild it with the current format.
    private func handleConfigurationChange() {
        guard let format = currentFormat else { return }
        Self.logger.info("Audio device changed, rebuilding the engine")
        currentFormat = nil
        do {
            try prepare(format: format)
        } catch {
            Self.logger.error("Failed to rebuild the engine: \(error.localizedDescription, privacy: .public)")
        }
    }
}
