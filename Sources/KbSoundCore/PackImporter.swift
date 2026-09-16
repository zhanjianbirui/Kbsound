import AVFoundation
import Foundation
import os

/// Installs an external sound pack into the user directory, converting it to KbSound's
/// own format.
///
/// Three sources are recognized: KbSound native (has a `manifest.json`) and Mechvibes'
/// `multi` and `single` layouts. Conversion always lands in a temporary directory and
/// is only moved into place on success — a half-written pack must never be left behind,
/// or the next scan would pick up a broken pack.
public enum PackImporter {
    private static let logger = Logger(subsystem: "com.kbsound", category: "Import")

    public enum ImportError: Error, Equatable {
        case unrecognizedFormat
        case missingAudio(String)
        case unsupportedSoundPattern(String)
        case noKeysDefined
    }

    /// Imports a pack and returns it. `destination` is the user's sound pack directory.
    @discardableResult
    public static func importPack(from source: URL, into destination: URL) throws -> PackRef {
        let staging = URL.temporaryDirectory.appending(path: "kbsound-import-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: staging) }

        let manifest: PackManifest
        if FileManager.default.fileExists(atPath: source.appending(path: "manifest.json").path) {
            manifest = try copyNativePack(from: source, to: staging)
        } else if FileManager.default.fileExists(atPath: source.appending(path: "config.json").path) {
            manifest = try convertMechvibesPack(from: source, to: staging)
        } else {
            throw ImportError.unrecognizedFormat
        }

        let installed = destination.appending(path: manifest.id)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        // Re-importing the same id replaces the pack instead of piling up dup-1, dup-2.
        if FileManager.default.fileExists(atPath: installed.path) {
            try FileManager.default.removeItem(at: installed)
        }
        try FileManager.default.moveItem(at: staging, to: installed)

        logger.info("Imported sound pack \(manifest.id, privacy: .public)")
        return PackRef(id: manifest.id, name: manifest.name,
                       detail: manifest.detail, directory: installed)
    }

    // MARK: - KbSound native

    private static func copyNativePack(from source: URL, to staging: URL) throws -> PackManifest {
        let manifest = try JSONDecoder().decode(
            PackManifest.self, from: Data(contentsOf: source.appending(path: "manifest.json")))
        try copy(files: manifest.referencedFiles, from: source, to: staging)
        try Data(contentsOf: source.appending(path: "manifest.json"))
            .write(to: staging.appending(path: "manifest.json"))
        return manifest
    }

    // MARK: - Mechvibes

    private static func convertMechvibesPack(from source: URL, to staging: URL) throws -> PackManifest {
        let config = try JSONDecoder().decode(
            MechvibesConfig.self, from: Data(contentsOf: source.appending(path: "config.json")))

        let keys: [String: KeySound]
        let defaults: KeySound
        switch config.layout {
        case .multi(let defines):
            (keys, defaults) = try convertMultiLayout(config, defines: defines,
                                                      source: source, staging: staging)
        case .sprite(let slices):
            (keys, defaults) = try convertSpriteLayout(config, slices: slices,
                                                       source: source, staging: staging)
        }
        guard !keys.isEmpty else { throw ImportError.noKeysDefined }

        let manifest = PackManifest(
            formatVersion: 1, id: config.id, name: config.name,
            author: "Imported from Mechvibes", detail: nil, defaults: defaults, keys: keys)
        try JSONEncoder.prettyPrinted.encode(manifest)
            .write(to: staging.appending(path: "manifest.json"))
        return manifest
    }

    /// `multi`: both spellings have to work.
    /// - Packs shipped with mechvibes: `sound` is a `GENERIC_R{0-4}` row pattern and
    ///   `defines` only lists the keys with their own sound.
    /// - Community packs: `sound` is often a placeholder that does not exist, and every
    ///   key names its file individually in `defines`.
    private static func convertMultiLayout(
        _ config: MechvibesConfig, defines: [String: String], source: URL, staging: URL
    ) throws -> ([String: KeySound], KeySound) {
        // A config sometimes declares files that are not there; check each one.
        func existing(_ path: String?) -> String? {
            guard let path, FileManager.default.fileExists(
                atPath: source.appending(path: path).path) else { return nil }
            return path
        }
        let defaultUp = existing(config.soundup)

        var specials: [Int: (down: String?, up: String?)] = [:]
        for (rawKey, path) in defines {
            let isUp = rawKey.hasSuffix("-up")
            let code = Int(isUp ? String(rawKey.dropLast(3)) : rawKey)
            guard let code, let mac = KeycodeMap.macKeycode(forX11: code) else { continue }
            var entry = specials[mac] ?? (nil, nil)
            if isUp { entry.up = existing(path) } else { entry.down = existing(path) }
            specials[mac] = entry
        }

        let rowFiles = MechvibesConfig.expandRowPattern(config.sound)
            .map { $0.compactMapValues { existing($0) } }

        // Fallback sound: row 2 for a row pattern; otherwise the `sound` field; failing
        // that, the file that appears most often in `defines`.
        let fallback = rowFiles?[2]
            ?? existing(config.sound)
            ?? mostCommonSound(in: specials)
        guard let fallback else { throw ImportError.missingAudio(config.sound) }

        var keys: [String: KeySound] = [:]
        var referenced: Set<String> = [fallback]
        for mac in KeycodeMap.allKeycodes {
            let rowSound = KeycodeMap.row(forMac: mac).flatMap { rowFiles?[$0] }
            let down = specials[mac]?.down ?? rowSound ?? fallback
            let up = specials[mac]?.up ?? defaultUp
            keys[String(mac)] = KeySound(down: down, up: up)
            referenced.insert(down)
            if let up { referenced.insert(up) }
        }

        try copy(files: referenced, from: source, to: staging)
        return (keys, KeySound(down: fallback, up: defaultUp))
    }

    /// The sound appearing most often in `defines`, used as the fallback for undefined keys.
    private static func mostCommonSound(in specials: [Int: (down: String?, up: String?)]) -> String? {
        let counts = specials.values.compactMap(\.down).reduce(into: [String: Int]()) {
            $0[$1, default: 0] += 1
        }
        return counts.max { $0.value < $1.value }?.key
    }

    /// `single`: one sprite for the whole pack, cut into standalone wavs by
    /// `[offset, duration]`.
    private static func convertSpriteLayout(
        _ config: MechvibesConfig, slices: [String: MechvibesConfig.Slice],
        source: URL, staging: URL
    ) throws -> ([String: KeySound], KeySound) {
        let sprite = source.appending(path: config.sound)
        guard FileManager.default.fileExists(atPath: sprite.path) else {
            throw ImportError.missingAudio(config.sound)
        }

        var keys: [String: KeySound] = [:]
        var firstSlice: String?
        for (rawKey, slice) in slices.sorted(by: { $0.key < $1.key }) {
            guard let code = Int(rawKey), let mac = KeycodeMap.macKeycode(forX11: code) else {
                continue
            }
            let fileName = "key-\(mac).wav"
            do {
                try AudioSlicer.writeSlice(of: sprite, offsetMs: slice.offsetMs,
                                           durationMs: slice.durationMs,
                                           to: staging.appending(path: fileName))
            } catch {
                logger.error("Slicing failed for \(rawKey, privacy: .public), skipping that key")
                continue
            }
            keys[String(mac)] = KeySound(down: fileName)
            firstSlice = firstSlice ?? fileName
        }

        guard let fallback = firstSlice else { throw ImportError.noKeysDefined }
        // A sprite pack has no notion of a generic sound, so undefined keys reuse the
        // first slice.
        return (keys, KeySound(down: fallback))
    }

    // MARK: - Helpers

    private static func copy(files: Set<String>, from source: URL, to staging: URL) throws {
        for relativePath in files.sorted() {
            let from = source.appending(path: relativePath)
            guard FileManager.default.fileExists(atPath: from.path) else {
                throw ImportError.missingAudio(relativePath)
            }
            let to = staging.appending(path: relativePath)
            try FileManager.default.createDirectory(
                at: to.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: from, to: to)
        }
    }
}

extension JSONEncoder {
    fileprivate static var prettyPrinted: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
