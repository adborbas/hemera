// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Mortar",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "Mortar",
            targets: ["Mortar"]
        )
    ],
    targets: [
        .target(
            name: "Mortar",
            resources: [
                .process("Assets.xcassets"),
                .copy("Resources/materialdesignicons-webfont.ttf"),
                .copy("Resources/MDICodepoints.json"),
                .copy("Resources/MDI-LICENSE.txt")
            ]
        )
    ]
)
