import Foundation

/// 一个按键在某个阶段该播放哪个音频文件。
public struct KeySound: Codable, Sendable, Equatable {
    public let down: String?
    public let up: String?

    public init(down: String? = nil, up: String? = nil) {
        self.down = down
        self.up = up
    }

    func fileName(for phase: KeyPhase) -> String? {
        switch phase {
        case .down: down
        case .up: up
        }
    }
}

/// 音效包 manifest.json 的模型（klinkmac v1 格式）。
public struct PackManifest: Codable, Sendable, Equatable {
    public let formatVersion: Int
    public let id: String
    public let name: String
    public let author: String?
    /// 对应 JSON 里的 `description`，改名避开 Swift 的 `description` 语义。
    public let detail: String?
    public let defaults: KeySound
    public let keys: [String: KeySound]?

    private enum CodingKeys: String, CodingKey {
        case formatVersion, id, name, author
        case detail = "description"
        case defaults, keys
    }

    /// 查找顺序：`keys[keyCode]` 的对应阶段 → `defaults` 的对应阶段 → nil。
    public func fileName(for keyCode: Int, phase: KeyPhase) -> String? {
        if let specific = keys?[String(keyCode)]?.fileName(for: phase) {
            return specific
        }
        return defaults.fileName(for: phase)
    }

    /// manifest 引用到的全部音频文件名，用于校验文件是否齐全。
    public var referencedFiles: Set<String> {
        var files = Set([defaults.down, defaults.up].compactMap { $0 })
        for sound in keys?.values ?? [:].values {
            if let down = sound.down { files.insert(down) }
            if let up = sound.up { files.insert(up) }
        }
        return files
    }
}
