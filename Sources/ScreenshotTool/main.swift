import AppKit
import KbSoundCore
import SwiftUI

// Renders the menu bar panel to docs/screenshot.png, so the README image can be
// regenerated after a UI change instead of being re-shot by hand.
//
//     swift run ScreenshotTool
//
// Run it through scripts/make-screenshot.sh, which wraps this binary in a throwaway
// .app. The bundle matters twice over: CFBundle only resolves a non-default localization
// when the main bundle declares CFBundleLocalizations, and an unbundled process cannot
// make itself active — AppKit then draws `.toggleStyle(.switch)`, a bridged NSSwitch, in
// its inactive grey no matter what the window says.
//
// Takes the output path as its argument; the locale comes from `-AppleLanguages`, which
// UserDefaults picks up from the command line on its own.
//
// SwiftUI is hosted in a real (offscreen) window rather than handed to ImageRenderer:
// the renderer cannot draw AppKit-backed controls such as `.toggleStyle(.switch)`, and
// leaves ScrollView content out entirely.

let app = NSApplication.shared
// .regular rather than .accessory: an accessory app cannot become active, and AppKit
// draws `.toggleStyle(.switch)` — a bridged NSSwitch — in its inactive grey whenever the
// window is not key. The window stays offscreen, so this only takes focus for a moment.
app.setActivationPolicy(.regular)

// The panel should be shown doing its job. These land in the tool's own defaults
// domain, not the app's, and AppState reads them in init — where property observers do
// not fire, so nothing starts an event tap or an audio engine.
UserDefaults.standard.set(true, forKey: "KbSound.enabled")
UserDefaults.standard.set(0.62, forKey: "KbSound.volume")

let repoRoot = URL(filePath: FileManager.default.currentDirectoryPath)
let state = AppState(searchPaths: [repoRoot.appending(path: "Resources/Packs")],
                     userPacksDirectory: URL.applicationSupportDirectory
                         .appending(path: "KbSound/Packs"))

// start() is deliberately not called: no event tap, no audio engine. The panel only
// needs the pack list and the stored defaults to render.
// AppKit draws controls in their inactive grey unless the app is active and its window
// is key, and an unbundled executable cannot reliably activate itself. Telling SwiftUI
// the control state directly is what makes the switches render as switched on.
let panel = PopoverView(state: state)
    .environment(\.controlActiveState, .key)

let hosting = NSHostingView(rootView: panel)
hosting.frame = CGRect(origin: .zero, size: hosting.fittingSize)

/// A borderless window refuses to become key by default, and AppKit draws controls in
/// their inactive grey when the window is not key — the switches would come out looking
/// disabled.
final class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

let window = KeyableWindow(contentRect: hosting.frame, styleMask: [.borderless],
                           backing: .buffered, defer: false)
window.contentView = hosting
window.backgroundColor = .windowBackgroundColor
// Placed on screen on purpose: a window parked far offscreen never becomes key, and a
// window that is not key gets the inactive grey switches. It flashes for a moment while
// this runs.
window.center()
window.makeKeyAndOrderFront(nil)
NSApp.activate()

// Let SwiftUI lay out, load the pack list, and draw before the snapshot is taken.
RunLoop.current.run(until: Date().addingTimeInterval(1.5))

hosting.layoutSubtreeIfNeeded()
guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
    FileHandle.standardError.write(Data("could not allocate a bitmap\n".utf8))
    exit(1)
}
hosting.cacheDisplay(in: hosting.bounds, to: rep)

guard let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("could not encode the PNG\n".utf8))
    exit(1)
}
let outputArgument = CommandLine.arguments.dropFirst().first { !$0.hasPrefix("-") }
let output = repoRoot.appending(path: outputArgument ?? "docs/screenshot.png")
try png.write(to: output)
print("==> \(output.lastPathComponent)  \(rep.pixelsWide)x\(rep.pixelsHigh)  (\(state.packs.count) packs)")
