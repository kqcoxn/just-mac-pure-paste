// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "JustPurePaste",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "JustPurePaste", targets: ["JustPurePaste"])],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", exact: "3.1.0")
    ],
    targets: [
        .target(name: "PasteCore"),
        .target(name: "UpdateCore"),
        .executableTarget(name: "JustPurePaste", dependencies: ["PasteCore", "UpdateCore", "KeyboardShortcuts"]),
        .testTarget(name: "PasteCoreTests", dependencies: ["PasteCore"]),
        .testTarget(name: "UpdateCoreTests", dependencies: ["UpdateCore"]),
        .testTarget(name: "AppLifecycleTests", dependencies: ["JustPurePaste"])
    ],
    swiftLanguageModes: [.v6]
)
