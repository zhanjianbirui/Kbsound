// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "KbSound",
    defaultLocalization: "en",
    platforms: [.macOS(.v26)],
    targets: [
        .target(name: "KbSoundCore", resources: [.process("Resources")]),
        .executableTarget(name: "KbSound", dependencies: ["KbSoundCore"]),
        .executableTarget(name: "TapProbe"),
        .executableTarget(name: "LatencyProbe"),
        .testTarget(name: "KbSoundCoreTests", dependencies: ["KbSoundCore"]),
    ]
)
