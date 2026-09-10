import Foundation
import os

/// 菜单里列出一个音效包所需的最少信息。
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

/// 扫描若干目录，找出其中可用的音效包。
public struct SoundPackLoader {
    private static let logger = Logger(subsystem: "com.kbsound", category: "PackLoader")

    /// 优先级从低到高：靠后的目录里同 id 的包会覆盖靠前的。
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
            // 目录不存在是正常情况（用户从未创建过自定义包目录）。
            Self.logger.debug("跳过不可读的搜索路径 \(path.path, privacy: .public)")
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
            Self.logger.error("跳过 \(directory.lastPathComponent, privacy: .public)：manifest 解析失败 \(error.localizedDescription, privacy: .public)")
            return nil
        }

        for file in manifest.referencedFiles
        where !FileManager.default.fileExists(atPath: directory.appending(path: file).path) {
            Self.logger.error("跳过 \(manifest.id, privacy: .public)：缺少音频文件 \(file, privacy: .public)")
            return nil
        }

        return PackRef(id: manifest.id, name: manifest.name,
                       detail: manifest.detail, directory: directory)
    }
}
