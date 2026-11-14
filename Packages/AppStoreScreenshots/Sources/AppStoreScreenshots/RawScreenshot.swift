import SwiftUI

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// A capture from `capture-screenshots.sh`, looked up by its test name in a device folder.
public enum RawScreenshot {

    public static func image(named name: String, in directoryName: String) -> Image? {
        let deviceDir = ScreenshotLocator.deviceDir(for: directoryName)
        guard let screenshots = try? ManifestParser.load(from: deviceDir),
              let match = screenshots.first(where: { $0.name == name }) else {
            return nil
        }
        #if canImport(AppKit)
        return NSImage(contentsOf: match.filePath).map(Image.init(nsImage:))
        #elseif canImport(UIKit)
        return (try? Data(contentsOf: match.filePath)).flatMap(UIImage.init(data:)).map(Image.init(uiImage:))
        #endif
    }

    /// Stops the export when a capture is missing, so no frame ships with a placeholder.
    public static func required(named name: String, in directoryName: String) -> Image {
        guard let image = image(named: name, in: directoryName) else {
            fatalError("Raw screenshot '\(name)' not found in \(directoryName). Run capture-screenshots.sh first.")
        }
        return image
    }
}

/// A theme captured with `THEMES=...`; mirrors the app's `HueName`, which this package can't see.
public struct ScreenshotTheme: Sendable, Hashable {
    public let name: String
    public let hue: Double

    /// The muted tint every listing background is built from; the app UI should carry the colour.
    public var backdrop: Color { Color(hue: hue, saturation: 0.45, brightness: 0.5) }

    /// The backdrop darkening downwards, so white captions read at the top.
    public var background: LinearGradient {
        LinearGradient(colors: [backdrop, Color(hue: hue, saturation: 0.55, brightness: 0.2)],
                       startPoint: .top, endPoint: .bottom)
    }

    public func directoryName(for device: TargetDevice) -> String {
        "\(device.directoryName)-Dark-\(name)"
    }

    public static let orange = ScreenshotTheme(name: "orange", hue: 0.07)
    public static let teal = ScreenshotTheme(name: "teal", hue: 0.5)
    public static let blue = ScreenshotTheme(name: "blue", hue: 0.6)
    public static let purple = ScreenshotTheme(name: "purple", hue: 0.72)
}
