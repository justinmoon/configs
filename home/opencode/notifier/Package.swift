// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpenCodeNotifier",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "OpenCodeNotifier", path: "Sources")
    ]
)
