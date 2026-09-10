import Foundation
import Testing
@testable import KbSoundCore

/// 固定计数器和锁，用于生成可重用的 UserDefaults 套件名。
/// 每次测试运行后重置计数器，确保跨运行重用相同的套件名。
nonisolated(unsafe) private var suiteCounter = 0
nonisolated(unsafe) private var lastAccessTime: Int64 = 0
private let suiteLock = NSLock()

/// 获取下一个套件名（可重用且可预测）。
private func nextSuiteName() -> String {
    suiteLock.lock()
    defer { suiteLock.unlock() }

    let now = Int64(Date().timeIntervalSince1970 * 1000)
    // 如果距离上次访问超过5秒，视为新的测试运行，重置计数器
    if lastAccessTime > 0 && now - lastAccessTime > 5000 {
        suiteCounter = 0
    }
    lastAccessTime = now

    suiteCounter += 1
    return "com.kbsound.tests.\(suiteCounter)"
}

/// 独立 UserDefaults suite 的 fixture，测试结束后自动清理。
/// 使用递增计数器生成套件名，以便跨测试运行重用 plist 文件。
private struct IsolatedSettingsFixture: ~Copyable {
    let suiteName: String
    let defaults: UserDefaults
    let settings: Settings

    init() {
        suiteName = nextSuiteName()
        defaults = UserDefaults(suiteName: suiteName)!
        settings = Settings(defaults: defaults)
    }

    deinit {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        UserDefaults.standard.synchronize()
    }
}

@Test func defaultsAreSensible() {
    let fixture = IsolatedSettingsFixture()
    let s = fixture.settings
    #expect(s.isEnabled == true)
    #expect(s.volume == 0.5)
    #expect(s.packID == "com.klinkmac.mx-brown-pbt")
}

@Test func valuesRoundTrip() {
    let fixture = IsolatedSettingsFixture()
    let s = fixture.settings
    s.isEnabled = false
    s.volume = 0.25
    s.packID = "com.klinkmac.nk-cream"
    #expect(s.isEnabled == false)
    #expect(s.volume == 0.25)
    #expect(s.packID == "com.klinkmac.nk-cream")
}

@Test func volumeIsClampedOnWrite() {
    let fixture = IsolatedSettingsFixture()
    let s = fixture.settings
    s.volume = -1
    #expect(s.volume == 0)
    s.volume = 2
    #expect(s.volume == 1)
}

@Test func volumeIsClampedOnRead() {
    // 外部写坏了配置文件也不能让音量越界
    let suite = nextSuiteName()
    let defaults = UserDefaults(suiteName: suite)!
    defer {
        UserDefaults.standard.removePersistentDomain(forName: suite)
        UserDefaults.standard.synchronize()
    }
    defaults.set(99.0, forKey: "KbSound.volume")
    #expect(Settings(defaults: defaults).volume == 1)
}

@Test func settingsPersistAcrossInstances() {
    let suite = nextSuiteName()
    let defaults = UserDefaults(suiteName: suite)!
    defer {
        UserDefaults.standard.removePersistentDomain(forName: suite)
        UserDefaults.standard.synchronize()
    }
    Settings(defaults: defaults).volume = 0.8
    #expect(Settings(defaults: defaults).volume == 0.8)
}
