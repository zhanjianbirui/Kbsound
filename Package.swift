// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "KbSound",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "KbSoundCore", resources: [.process("Resources")]),
        .executableTarget(name: "KbSound", dependencies: ["KbSoundCore"]),
        .executableTarget(name: "TapProbe"),
        .executableTarget(name: "LatencyProbe"),
        // Dev tool: regenerates the README screenshot. Not part of the shipped app.
        .executableTarget(name: "ScreenshotTool", dependencies: ["KbSoundCore"]),
        .testTarget(name: "KbSoundCoreTests", dependencies: ["KbSoundCore"]),
    ]
)
