import Foundation

/// Linux/X11 键码与 macOS 虚拟键码之间的对照表。
///
/// Mechvibes 是 Electron 应用，用 Linux input-event-codes 的键码（`KEY_A` = 30）；
/// macOS 用自己的一套虚拟键码（A = 0），两者毫无规律可循，只能逐个列。
/// 数字键尤其容易写错——macOS 的 1…0 是 18,19,20,21,23,22,26,28,25,29，并非连号。
public enum KeycodeMap {
    /// X11 键码 → macOS 虚拟键码。
    public static let x11ToMac: [Int: Int] = [
        // 数字行
        1: 53, 2: 18, 3: 19, 4: 20, 5: 21, 6: 23, 7: 22, 8: 26, 9: 28, 10: 25,
        11: 29, 12: 27, 13: 24, 14: 51,
        // QWERTY 行
        15: 48, 16: 12, 17: 13, 18: 14, 19: 15, 20: 17, 21: 16, 22: 32, 23: 34,
        24: 31, 25: 35, 26: 33, 27: 30, 28: 36,
        // ASDF 行
        29: 59, 30: 0, 31: 1, 32: 2, 33: 3, 34: 5, 35: 4, 36: 38, 37: 40, 38: 37,
        39: 41, 40: 39, 41: 50,
        // ZXCV 行
        42: 56, 43: 42, 44: 6, 45: 7, 46: 8, 47: 9, 48: 11, 49: 45, 50: 46,
        51: 43, 52: 47, 53: 44, 54: 60,
        // 底排与功能键
        56: 58, 57: 49, 58: 57,
        59: 122, 60: 120, 61: 99, 62: 118, 63: 96, 64: 97, 65: 98, 66: 100,
        67: 101, 68: 109, 87: 103, 88: 111,
        97: 62, 100: 61, 125: 55, 126: 54,
        // 方向键
        103: 126, 105: 123, 106: 124, 108: 125,
    ]

    /// macOS 虚拟键码 → 键盘第几行。行的含义与 Mechvibes 的 `GENERIC_R{0-4}` 一致。
    private static let rows: [Int: [Int]] = [
        0: [50, 18, 19, 20, 21, 23, 22, 26, 28, 25, 29, 27, 24, 51,
            53, 122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111],
        1: [48, 12, 13, 14, 15, 17, 16, 32, 34, 31, 35, 33, 30, 42],
        2: [57, 0, 1, 2, 3, 5, 4, 38, 40, 37, 41, 39, 36],
        3: [56, 6, 7, 8, 9, 11, 45, 46, 43, 47, 44, 60],
        4: [63, 59, 58, 55, 49, 54, 61, 62, 123, 124, 125, 126],
    ]

    private static let rowByKeycode: [Int: Int] = rows.reduce(into: [:]) { result, entry in
        for keycode in entry.value { result[keycode] = entry.key }
    }

    public static func macKeycode(forX11 code: Int) -> Int? {
        x11ToMac[code]
    }

    public static func row(forMac code: Int) -> Int? {
        rowByKeycode[code]
    }

    public static func keycodes(inRow row: Int) -> [Int] {
        rows[row] ?? []
    }

    /// 所有已归行的 macOS 键码，用于给音效包铺满按键映射。
    public static var allKeycodes: [Int] {
        rows.values.flatMap { $0 }
    }
}
