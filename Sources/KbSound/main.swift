import AppKit
import KbSoundCore

/// Directory of the built-in sound packs. In a packaged `.app` they live in the
/// bundle's resources; under `swift run` there is no bundle copy, so fall back to the
/// repository's Resources/Packs.
private func builtInPacksURL() -> URL {
    if let resources = Bundle.main.resourceURL {
        let bundled = resources.appending(path: "Packs")
        if FileManager.default.fileExists(atPath: bundled.path) { return bundled }
    }
    return URL(filePath: FileManager.default.currentDirectoryPath)
        .appending(path: "Resources/Packs")
}

private func userPacksURL() -> URL {
    URL.applicationSupportDirectory.appending(path: "KbSound/Packs")
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var state: AppState?
    private var menuBar: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Search paths, lowest priority first: a user pack shadows a built-in one
        // with the same id.
        let state = AppState(searchPaths: [builtInPacksURL(), userPacksURL()],
                             userPacksDirectory: userPacksURL())
        let menuBar = MenuBarController(state: state)
        menuBar.install()
        state.start()
        menuBar.refreshIcon()
        self.state = state
        self.menuBar = menuBar
    }

    func applicationWillTerminate(_ notification: Notification) {
        state?.stop()
    }
}

let delegate = AppDelegate()
let app = NSApplication.shared
app.delegate = delegate
// .accessory: no Dock tile, no place in the app switcher — just the menu bar icon.
app.setActivationPolicy(.accessory)
app.run()
