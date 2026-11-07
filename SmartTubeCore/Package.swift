// swift-tools-version:6.4
import PackageDescription

let package = Package(
    name: "SmartTubeCore",
    defaultLocalization: "en",
    platforms: [
        .tvOS(.v27)
    ],
    products: [
        // Core: models + InnerTube/SponsorBlock services (Foundation only).
        .library(name: "SmartTubeCore", targets: ["SmartTubeCore"]),
        // SwiftUI UI layer.
        .library(name: "SmartTubeIOS", targets: ["SmartTubeIOS"]),
    ],
    targets: [
        .target(
            name: "SmartTubeCore",
            path: "Sources/SmartTubeCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "SmartTubeIOS",
            dependencies: ["SmartTubeCore"],
            path: "Sources/SmartTubeIOS",
            resources: [
                .process("Localizable.xcstrings"),
                .copy("Resources/yt.solver.lib.min.js"),
                .copy("Resources/yt.solver.core.min.js"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "SmartTubeCoreTests",
            dependencies: ["SmartTubeCore", "SmartTubeIOS"],
            path: "Tests/SmartTubeCoreTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
