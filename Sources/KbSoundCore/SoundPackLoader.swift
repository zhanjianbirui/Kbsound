import Foundation
import os

/// The minimum a sound pack needs for the menu to list it.
public struct PackRef: Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let detail: String?
    public let directory: URL

    public init(id: String, name: String, detail: String?, directory: URL) {
        self.id = id
        self.name = name
        self.detail = detail
        self.directory = directory
    }
}

/// Scans a list of directories for usable sound packs.
public struct SoundPackLoader {
    private static let logger = Logger(subsystem: "com.kbsound", category: "PackLoader")

    /// Lowest priority first: a pack in a later directory shadows one with the same id
    /// in an earlier directory.
    private let searchPaths: [URL]

    public init(searchPaths: [URL]) {
        self.searchPaths = searchPaths
    }

    public func availablePacks() -> [PackRef] {
        var byID: [String: PackRef] = [:]
        for path in searchPaths {
            for ref in scan(path) {
                byID[ref.id] = ref
            }
        }
        return byID.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func scan(_ path: URL) -> [PackRef] {
        let entries: [URL]
        do {
            entries = try FileManager.default.contentsOfDirectory(
                at: path, includingPropertiesForKeys: [.isDirectoryKey])
        } catch {
            // A missing directory is normal — the user may never have imported a pack.
            Self.logger.debug("Skipping unreadable search path \(path.path, privacy: .public)")
            return []
        }
        return entries.compactMap(packRef(at:))
    }

    private func packRef(at directory: URL) -> PackRef? {
        let manifestURL = directory.appending(path: "manifest.json")
        guard FileManager.default.fileExists(atPath: manifestURL.path) else { return nil }

        let manifest: PackManifest
        do {
            manifest = try JSONDecoder().decode(PackManifest.self, from: Data(contentsOf: manifestURL))
        } catch {
            Self.logger.error("Skipping \(directory.lastPathComponent, privacy: .public): could not parse the manifest, \(error.localizedDescription, privacy: .public)")
            return nil
        }

        for file in manifest.referencedFiles
        where !FileManager.default.fileExists(atPath: directory.appending(path: file).path) {
            Self.logger.error("Skipping \(manifest.id, privacy: .public): missing audio file \(file, privacy: .public)")
            return nil
        }

        return PackRef(id: manifest.id, name: manifest.name,
                       detail: manifest.detail, directory: directory)
    }
}
