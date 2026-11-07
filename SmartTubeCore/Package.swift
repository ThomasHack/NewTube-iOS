// swift-tools-version:6.4
import PackageDescription

let package = Package(
    name: "SmartTubeCore",
    platforms: [
        .tvOS(.v27)
    ],
    products: [
        .library(name: "SmartTubeCore", targets: ["SmartTubeCore"])
    ],
    targets: [
        .target(
            name: "SmartTubeCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "SmartTubeCoreTests",
            dependencies: ["SmartTubeCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
