import Foundation

/// The `config.json` of a Mechvibes sound pack.
///
/// Two layouts exist, distinguished by `key_define_type`:
/// - `multi`: one file per sound, `defines` values are file paths
/// - `single`: one audio sprite for the whole pack, `defines` values are
///   `[offset ms, duration ms]`
///
/// Most community packs found online are `single`.
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
    /// Under `multi` this can be a row pattern such as `GENERIC_R{0-4}.mp3`; under
    /// `single` it is the sprite's file name.
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
            // Undefined keys are written as null; optional decoding skips them naturally.
            let raw = try container.decodeIfPresent(
                [String: String?].self, forKey: .defines) ?? [:]
            layout = .multi(defines: raw.compactMapValues { $0 })
        case "single":
            // Undefined keys are written as null; optional decoding skips them naturally.
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

    /// `press/GENERIC_R{0-4}.mp3` → row number to file name. Returns nil when the
    /// string is not a row pattern.
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
