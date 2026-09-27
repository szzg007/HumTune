// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HumTune",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        // 核心引擎（无 UI 依赖，可被 App 与 CLI 共用）
        .target(
            name: "HumTuneCore"
        ),
        // 命令行验证器（替代 XCTest，CLT 环境可跑）
        .executableTarget(
            name: "HumTuneCli",
            dependencies: ["HumTuneCore"]
        ),
        // SwiftUI 应用
        .executableTarget(
            name: "HumTuneApp",
            dependencies: ["HumTuneCore"]
        )
    ]
)