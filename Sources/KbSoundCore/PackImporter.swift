import AVFoundation
import Foundation
import os

/// 把外部音效包装进用户目录，转换成 KbSound 自己的格式。
///
/// 识别三种来源：KbSound 原生（有 `manifest.json`）、Mechvibes 的 `multi` 与 `single`。
/// 转换一律落到临时目录，成功后才搬进用户目录——失败时不能留下半成品，
/// 否则下次扫描会读到一个坏包。
public enum PackImporter {
    private static let logger = Logger(subsystem: "com.kbsound", category: "Import")

    public enum ImportError: Error, Equatable {
        case unrecognizedFormat
        case missingAudio(String)
        case unsupportedSoundPattern(String)
        case noKeysDefined
    }

    /// 导入并返回装好的包。`destination` 是用户音效包目录。
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
        // 同 id 重复导入就替换，不堆出 dup-1、dup-2
        if FileManager.default.fileExists(atPath: installed.path) {
            try FileManager.default.removeItem(at: installed)
        }
        try FileManager.default.moveItem(at: staging, to: installed)

        logger.info("已导入音效包 \(manifest.id, privacy: .public)")
        return PackRef(id: manifest.id, name: manifest.name,
                       detail: manifest.detail, directory: installed)
    }

    // MARK: - KbSound 原生

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
            author: "导入自 Mechvibes", detail: nil, defaults: defaults, keys: keys)
        try JSONEncoder.prettyPrinted.encode(manifest)
            .write(to: staging.appending(path: "manifest.json"))
        return manifest
    }

    /// `multi`：两种写法都要支持。
    /// - mechvibes 自带包：`sound` 是 `GENERIC_R{0-4}` 行模式，`defines` 只列专属键
    /// - 社区包：`sound` 常是不存在的占位，全部按键在 `defines` 里逐个指定文件
    private static func convertMultiLayout(
        _ config: MechvibesConfig, defines: [String: String], source: URL, staging: URL
    ) throws -> ([String: KeySound], KeySound) {
        // config 有时会声明并不存在的文件，逐个校验
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

        // 兜底音：行模式用第 2 行；否则用 sound 字段，再否则用 defines 里出现最多的文件
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

    /// defines 里出现次数最多的音频，作为未定义按键的兜底。
    private static func mostCommonSound(in specials: [Int: (down: String?, up: String?)]) -> String? {
        let counts = specials.values.compactMap(\.down).reduce(into: [String: Int]()) {
            $0[$1, default: 0] += 1
        }
        return counts.max { $0.value < $1.value }?.key
    }

    /// `single`：整包一个精灵文件，按 `[起始, 时长]` 切成独立 wav。
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
                logger.error("切片失败 \(rawKey, privacy: .public)，跳过该键")
                continue
            }
            keys[String(mac)] = KeySound(down: fileName)
            firstSlice = firstSlice ?? fileName
        }

        guard let fallback = firstSlice else { throw ImportError.noKeysDefined }
        // 精灵包没有「通用音」概念，未定义的键沿用第一个切片
        return (keys, KeySound(down: fallback))
    }

    // MARK: - 工具

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
