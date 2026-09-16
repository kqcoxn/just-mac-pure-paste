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
        .executableTarget(name: "JustPurePaste", dependencies: ["PasteCore", "KeyboardShortcuts"]),
        .testTarget(name: "PasteCoreTests", dependencies: ["PasteCore"])
    ],
    swiftLanguageModes: [.v6]
)
