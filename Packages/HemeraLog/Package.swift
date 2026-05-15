// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HemeraLog",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "HemeraLog",
            targets: ["HemeraLog"]
        )
    ],
    targets: [
        .target(
            name: "HemeraLog"
        ),
        .testTarget(
            name: "HemeraLogTests",
            dependencies: ["HemeraLog"]
        )
    ]
)
