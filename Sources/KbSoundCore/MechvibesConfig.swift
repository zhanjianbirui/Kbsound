import Foundation

/// Mechvibes 音效包的 `config.json`。
///
/// 有两种排布方式，靠 `key_define_type` 区分：
/// - `multi`：每个音一个文件，`defines` 的值是文件路径
/// - `single`：整包一个音频「精灵」，`defines` 的值是 `[起始毫秒, 时长毫秒]`
///
/// 网上流传的社区包大多是 `single`。
public struct MechvibesConfig: Decodable {
    public struct Slice: Equatable {
        public let offsetMs: Double
        public let durationMs: Double
    }

    public enum Layout {
        case multi(defines: [String: String])
        case sprite(slices: [String: Slice])
    }

    public let id: String
    public let name: String
    /// `multi` 下可能是 `GENERIC_R{0-4}.mp3` 这样的行模式；`single` 下是精灵文件名。
    public let sound: String
    public let soundup: String?
    public let layout: Layout

    private enum CodingKeys: String, CodingKey {
        case id, name, sound, soundup, defines
        case keyDefineType = "key_define_type"
    }

    public enum ParseError: Error, Equatable {
        case unknownKeyDefineType(String)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        sound = try container.decode(String.self, forKey: .sound)
        soundup = try container.decodeIfPresent(String.self, forKey: .soundup)

        switch try container.decode(String.self, forKey: .keyDefineType) {
        case "multi":
            // 未定义的键会写成 null，可选解码把它们自然跳过
            let raw = try container.decodeIfPresent(
                [String: String?].self, forKey: .defines) ?? [:]
            layout = .multi(defines: raw.compactMapValues { $0 })
        case "single":
            // 未定义的键会写成 null，可选解码把它们自然跳过
            let raw = try container.decodeIfPresent(
                [String: [Double]?].self, forKey: .defines) ?? [:]
            var slices: [String: Slice] = [:]
            for (key, value) in raw {
                guard let pair = value, pair.count >= 2 else { continue }
                slices[key] = Slice(offsetMs: pair[0], durationMs: pair[1])
            }
            layout = .sprite(slices: slices)
        case let other:
            throw ParseError.unknownKeyDefineType(other)
        }
    }

    /// `press/GENERIC_R{0-4}.mp3` → 行号到文件名的映射；不是行模式时返回 nil。
    public static func expandRowPattern(_ pattern: String) -> [Int: String]? {
        guard let range = pattern.range(of: #"R\{(\d+)-(\d+)\}"#, options: .regularExpression)
        else { return nil }

        let braces = pattern[range].dropFirst(2).dropLast()
        let bounds = braces.split(separator: "-").compactMap { Int($0) }
        guard bounds.count == 2, bounds[0] <= bounds[1] else { return nil }

        return (bounds[0]...bounds[1]).reduce(into: [:]) { result, row in
            result[row] = pattern.replacingCharacters(in: range, with: "R\(row)")
        }
    }
}
