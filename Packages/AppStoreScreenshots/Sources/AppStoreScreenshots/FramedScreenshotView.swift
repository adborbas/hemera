import SwiftUI
import AppScreenshotKit

public struct FramedScreenshotView: View {
    let screenshotName: String
    let environment: AppScreenshotEnvironment
    let directorySuffix: String
    let headerText: String
    /// Picks the capture in this theme and a background to match; replaces `directorySuffix`.
    let theme: ScreenshotTheme?
    let showsBackground: Bool

    public init(
        screenshotName: String,
        environment: AppScreenshotEnvironment,
        directorySuffix: String = "",
        headerText: String = "",
        theme: ScreenshotTheme? = nil,
        showsBackground: Bool = true
    ) {
        self.screenshotName = screenshotName
        self.environment = environment
        self.directorySuffix = directorySuffix
        self.headerText = headerText
        self.theme = theme
        self.showsBackground = showsBackground
    }

    private var isLandscape: Bool {
        environment.canvasSize.width > environment.canvasSize.height
    }

    public var body: some View {
        ZStack {
            if showsBackground {
                theme?.background ?? ScreenshotGradient.default
            }

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
                ScreenshotCaption(text: headerText, canvasHeight: environment.canvasSize.height)
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

        let dirName = theme?.directoryName(for: targetDevice) ?? targetDevice.directoryName + directorySuffix
        guard let image = RawScreenshot.image(named: screenshotName, in: dirName) else {
            fatalError("Raw screenshot '\(screenshotName)' not found in \(dirName). Run capture-screenshots.sh first.")
        }
        return image
    }
}
