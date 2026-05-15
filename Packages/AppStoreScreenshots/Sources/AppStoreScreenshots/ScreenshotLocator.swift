import Foundation

public enum ScreenshotLocator {

    public static func projectRoot() -> URL {
        if let root = ProcessInfo.processInfo.environment["HEMERA_PROJECT_ROOT"] {
            return URL(fileURLWithPath: root)
        }
        // Fallback: derive from source file location
        // #filePath → Packages/AppStoreScreenshots/Sources/AppStoreScreenshots/ScreenshotLocator.swift
        return URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Sources/AppStoreScreenshots/
            .deletingLastPathComponent() // Sources/
            .deletingLastPathComponent() // Packages/AppStoreScreenshots/
            .deletingLastPathComponent() // Packages/
            .deletingLastPathComponent() // project root
    }

    public static func screenshotsDir() -> URL {
        projectRoot().appending(path: "Screenshots")
    }

    public static func deviceDir(for directoryName: String) -> URL {
        screenshotsDir().appending(path: directoryName)
    }

    public static func promoOutputDir() -> URL {
        screenshotsDir().appending(path: "Promo")
    }
}
