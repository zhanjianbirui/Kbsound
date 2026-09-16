import Foundation
import Testing
@testable import KbSoundCore

@Test func defaultsAreSensible() {
    let s = Settings(defaults: InMemoryStore())
    #expect(s.isEnabled == true)
    #expect(s.volume == 0.5)
    #expect(s.packID == "com.klinkmac.mx-brown-pbt")
}

@Test func valuesRoundTrip() {
    let s = Settings(defaults: InMemoryStore())
    s.isEnabled = false
    s.volume = 0.25
    s.packID = "com.klinkmac.nk-cream"
    #expect(s.isEnabled == false)
    #expect(s.volume == 0.25)
    #expect(s.packID == "com.klinkmac.nk-cream")
}

@Test func volumeIsClampedOnWrite() {
    let s = Settings(defaults: InMemoryStore())
    s.volume = -1
    #expect(s.volume == 0)
    s.volume = 2
    #expect(s.volume == 1)
}

@Test func volumeIsClampedOnRead() {
    // A preferences file corrupted from outside must not push the volume out of range
    let store = InMemoryStore()
    store.set(99.0, forKey: "KbSound.volume")
    #expect(Settings(defaults: store).volume == 1)
}

@Test func settingsPersistAcrossInstances() {
    let store = InMemoryStore()
    Settings(defaults: store).volume = 0.8
    #expect(Settings(defaults: store).volume == 0.8)
}

/// The real `UserDefaults` has to satisfy the same protocol contract — the in-memory fake
/// must not hide a signature mismatch.
@Test func userDefaultsConformsToSettingsStore() {
    let store: SettingsStore = UserDefaults.standard
    #expect(store is UserDefaults)
}
