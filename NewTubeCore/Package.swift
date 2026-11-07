// swift-tools-version:6.4
import PackageDescription

let package = Package(
    name: "NewTubeCore",
    platforms: [
        .tvOS(.v27)
    ],
    products: [
        .library(name: "NewTubeCore", targets: ["NewTubeCore"])
    ],
    targets: [
        .target(
            name: "NewTubeCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "NewTubeCoreTests",
            dependencies: ["NewTubeCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
