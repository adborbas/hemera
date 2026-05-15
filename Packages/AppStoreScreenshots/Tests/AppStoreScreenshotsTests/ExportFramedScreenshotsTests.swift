import Testing
import Foundation
import SwiftUI
import AppKit
import AppScreenshotKit
@testable import AppScreenshotCore
import AppScreenshotKitTestTools
@testable import AppStoreScreenshots

@Test @MainActor
func exportAllFramedScreenshots() throws {
    let outputDir = ScreenshotLocator.promoOutputDir()

    // Clean and recreate output directory
    try? FileManager.default.removeItem(at: outputDir)
    try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

    // Pre-create device subdirectories
    let fm = FileManager.default
    for device in TargetDevice.allCases {
        try fm.createDirectory(at: outputDir.appending(path: device.directoryName), withIntermediateDirectories: true)
    }

    // Check if real bezel images are available
    let bezelDir = ScreenshotLocator.projectRoot()
        .appending(path: "Packages/AppStoreScreenshots/Resources/Bezels")
    let bezelContents = (try? fm.contentsOfDirectory(atPath: bezelDir.path)) ?? []
    let hasRealBezels = bezelContents.contains(where: { $0.hasSuffix(".png") })

    try exportScreenshot(S01_Home.self, hasRealBezels: hasRealBezels, bezelDir: bezelDir, to: outputDir)
    try exportScreenshot(S02_AreaDetail.self, hasRealBezels: hasRealBezels, bezelDir: bezelDir, to: outputDir)
    try exportScreenshot(S03_Areas.self, hasRealBezels: hasRealBezels, bezelDir: bezelDir, to: outputDir)
    try exportScreenshot(S04_LightControl.self, hasRealBezels: hasRealBezels, bezelDir: bezelDir, to: outputDir)
    try exportScreenshot(S05_CoverControl.self, hasRealBezels: hasRealBezels, bezelDir: bezelDir, to: outputDir)
    try exportScreenshot(S06_SwitchControl.self, hasRealBezels: hasRealBezels, bezelDir: bezelDir, to: outputDir)
    try exportScreenshot(S07_ClimateControl.self, hasRealBezels: hasRealBezels, bezelDir: bezelDir, to: outputDir)
}

// MARK: - Unified export

@MainActor
private func exportScreenshot<T: AppScreenshot>(
    _ type: T.Type,
    hasRealBezels: Bool,
    bezelDir: URL,
    to outputDir: URL
) throws {
    let typeName = String(describing: T.self)

    if hasRealBezels {
        let exporter = AppScreenshotExporter(
            option: .file(
                outputURL: outputDir,
                fileNameRule: { env in
                    let device = TargetDevice.from(device: env.device)?.directoryName ?? "unknown"
                    return "\(device)/\(typeName)"
                }
            )
        )
        exporter.setAppleDesignResourceURL(bezelDir)
        try exporter.export(type)
    } else {
        for environment in type.configuration.environments() {
            let content = type.body(environment: environment)
            let pngData = try renderViewToPNG(content)

            let device = TargetDevice.from(device: environment.device)?.directoryName ?? "unknown"
            let fileName = "\(typeName).png"
            try pngData.write(to: outputDir.appending(path: device).appending(path: fileName))
        }
    }
}

// MARK: - PNG rendering

@MainActor
private func renderViewToPNG<Content: View>(_ content: Content) throws -> Data {
    let view = NSHostingView(rootView: content)
    let targetSize = view.intrinsicContentSize
    view.frame = NSRect(origin: .zero, size: targetSize)

    guard let bitmapRep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
        throw ExportError(message: "Failed to create bitmap representation")
    }

    view.cacheDisplay(in: view.bounds, to: bitmapRep)

    guard let data = bitmapRep.representation(using: .png, properties: [:]) else {
        throw ExportError(message: "Failed to generate PNG data")
    }

    return data
}

private struct ExportError: Error {
    let message: String
}
