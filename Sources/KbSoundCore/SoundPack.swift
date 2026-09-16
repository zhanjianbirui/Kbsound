import Foundation

/// Which audio file one key plays in each phase.
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

/// Model of a sound pack's manifest.json (klinkmac v1 format).
public struct PackManifest: Codable, Sendable, Equatable {
    public let formatVersion: Int
    public let id: String
    public let name: String
    public let author: String?
    /// Maps to `description` in the JSON; renamed to stay clear of Swift's own
    /// `description` semantics.
    public let detail: String?
    public let defaults: KeySound
    public let keys: [String: KeySound]?

    private enum CodingKeys: String, CodingKey {
        case formatVersion, id, name, author
        case detail = "description"
        case defaults, keys
    }

    /// Lookup order: the phase in `keys[keyCode]` → the phase in `defaults` → nil.
    public func fileName(for keyCode: Int, phase: KeyPhase) -> String? {
        if let specific = keys?[String(keyCode)]?.fileName(for: phase) {
            return specific
        }
        return defaults.fileName(for: phase)
    }

    /// Every audio file name the manifest references, used to check the pack is complete.
    public var referencedFiles: Set<String> {
        var files = Set([defaults.down, defaults.up].compactMap { $0 })
        for sound in keys?.values ?? [:].values {
            if let down = sound.down { files.insert(down) }
            if let up = sound.up { files.insert(up) }
        }
        return files
    }
}
