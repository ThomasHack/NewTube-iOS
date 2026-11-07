// swift-tools-version:6.4
import PackageDescription

let package = Package(
    name: "SmartTubeIOS",
    defaultLocalization: "en",
    platforms: [
        .tvOS(.v27)
    ],
    products: [
        // Core: models + InnerTube/SponsorBlock services (Foundation only).
        .library(
            name: "SmartTubeIOSCore",
            targets: ["SmartTubeIOSCore"]
        ),
        // SwiftUI UI layer.
        .library(name: "SmartTubeIOS", targets: ["SmartTubeIOS"]),
    ],
    targets: [
        // MARK: Core (Foundation only)
        .target(
            name: "SmartTubeIOSCore",
            dependencies: [],
            path: "Sources/SmartTubeIOSCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // MARK: UI (SwiftUI)
        .target(
            name: "SmartTubeIOS",
            dependencies: ["SmartTubeIOSCore"],
            path: "Sources/SmartTubeIOS",
            resources: [
                .process("Localizable.xcstrings"),
                .copy("Resources/yt.solver.lib.min.js"),
                .copy("Resources/yt.solver.core.min.js"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // MARK: Tests
        .testTarget(
            name: "SmartTubeIOSTests",
            dependencies: ["SmartTubeIOSCore", "SmartTubeIOS"],
            path: "Tests/SmartTubeIOSTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
