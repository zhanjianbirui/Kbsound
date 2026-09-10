// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "KbSound",
    platforms: [.macOS(.v26)],
    targets: [
        .target(name: "KbSoundCore"),
        .executableTarget(name: "KbSound", dependencies: ["KbSoundCore"]),
        .executableTarget(name: "TapProbe"),
        .testTarget(name: "KbSoundCoreTests", dependencies: ["KbSoundCore"]),
    ]
)
