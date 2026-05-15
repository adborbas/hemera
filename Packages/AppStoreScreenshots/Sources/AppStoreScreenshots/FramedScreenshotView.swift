import SwiftUI
import AppScreenshotKit

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

public struct FramedScreenshotView: View {
    let screenshotName: String
    let environment: AppScreenshotEnvironment
    let directorySuffix: String
    let headerText: String

    public init(screenshotName: String, environment: AppScreenshotEnvironment, directorySuffix: String = "", headerText: String = "") {
        self.screenshotName = screenshotName
        self.environment = environment
        self.directorySuffix = directorySuffix
        self.headerText = headerText
    }

    private var isLandscape: Bool {
        environment.canvasSize.width > environment.canvasSize.height
    }

    public var body: some View {
        ZStack {
            ScreenshotGradient.default

            if isLandscape {
                landscapeLayout
            } else {
                portraitLayout
            }
        }
        .frame(
            width: environment.canvasSize.width,
            height: environment.canvasSize.height
        )
    }

    private var portraitLayout: some View {
        VStack(spacing: 0) {
            if !headerText.isEmpty {
                Text(headerText)
                    .font(.system(size: environment.canvasSize.height * 0.032, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.top, environment.canvasSize.height * 0.06)
                    .padding(.bottom, environment.canvasSize.height * 0.02)
            }

            DeviceView {
                screenshotImage
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
            }
            .padding(.horizontal, environment.canvasSize.width * 0.08)
            .padding(.bottom, environment.canvasSize.height * 0.02)
        }
    }

    private var landscapeLayout: some View {
        HStack(spacing: 0) {
            if !headerText.isEmpty {
                Text(headerText)
                    .font(.system(size: environment.canvasSize.height * 0.05, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: environment.canvasSize.width * 0.3)
                    .padding(.leading, environment.canvasSize.width * 0.06)
            }

            DeviceView {
                screenshotImage
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
            }
            .padding(environment.canvasSize.height * 0.05)
        }
    }

    private var screenshotImage: Image {
        guard let targetDevice = TargetDevice.from(device: environment.device) else {
            fatalError("Unknown device: \(environment.device)")
        }

        let dirName = targetDevice.directoryName + directorySuffix
        let deviceDir = ScreenshotLocator.deviceDir(for: dirName)

        guard let screenshots = try? ManifestParser.load(from: deviceDir),
              let match = screenshots.first(where: { $0.name == screenshotName }) else {
            fatalError("Raw screenshot '\(screenshotName)' not found in \(dirName). Run capture-screenshots.sh first.")
        }

        return loadImage(from: match.filePath)
    }

    private func loadImage(from url: URL) -> Image {
        #if canImport(AppKit)
        guard let nsImage = NSImage(contentsOf: url) else {
            return Image(systemName: "photo")
        }
        return Image(nsImage: nsImage)
        #elseif canImport(UIKit)
        guard let data = try? Data(contentsOf: url),
              let uiImage = UIImage(data: data) else {
            return Image(systemName: "photo")
        }
        return Image(uiImage: uiImage)
        #endif
    }
}
