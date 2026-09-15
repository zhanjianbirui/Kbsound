import AppKit
import KbSoundCore

/// 内置音效包目录。打包成 .app 后在 bundle 资源里；
/// `swift run` 开发时 bundle 里没有，回退到仓库的 Resources/Packs。
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
        // 搜索路径优先级从低到高：用户包覆盖同 id 的内置包
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
// .accessory：不进 Dock、不占 App 切换器，只留菜单栏图标
app.setActivationPolicy(.accessory)
app.run()
