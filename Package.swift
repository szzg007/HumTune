// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HumTune",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "HumTuneCore", targets: ["HumTuneCore"]),
        .executable(name: "HumTune", targets: ["HumTuneApp"]),
    ],
    targets: [
        .target(name: "HumTuneCore"),
        .executableTarget(name: "HumTuneCli", dependencies: ["HumTuneCore"]),
        .executableTarget(
            name: "HumTuneApp",
            dependencies: ["HumTuneCore"],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("SwiftUI"),
            ]
        ),
        .testTarget(name: "HumTuneCoreTests", dependencies: ["HumTuneCore"]),
    ]
)
