// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "TileGridEngine",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "TileGridEngine",
            targets: ["TileGridEngine"]
        )
    ],
    targets: [
        .target(
            name: "TileGridEngine"
        ),
        .testTarget(
            name: "TileGridEngineTests",
            dependencies: ["TileGridEngine"]
        )
    ]
)
