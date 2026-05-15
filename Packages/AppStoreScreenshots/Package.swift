// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AppStoreScreenshots",
    platforms: [.iOS(.v16), .macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/shitamori1272/AppScreenshotKit.git", branch: "main")
    ],
    targets: [
        .target(
            name: "AppStoreScreenshots",
            dependencies: [
                .product(name: "AppScreenshotKit", package: "AppScreenshotKit")
            ]
        ),
        .testTarget(
            name: "AppStoreScreenshotsTests",
            dependencies: [
                "AppStoreScreenshots",
                .product(name: "AppScreenshotKitTestTools", package: "AppScreenshotKit")
            ]
        )
    ]
)
