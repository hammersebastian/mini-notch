// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "MiniNotch",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MiniNotch", targets: ["MiniNotch"])
    ],
    targets: [
        .executableTarget(
            name: "MiniNotch",
            path: "Sources/MiniNotch"
        ),
        .testTarget(
            name: "MiniNotchTests",
            dependencies: ["MiniNotch"],
            path: "Tests/MiniNotchTests"
        )
    ]
)
