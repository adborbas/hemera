import SwiftUI
import AppScreenshotKit

/// Frames 1-3 as one wide canvas, so the background flows from each frame's theme into the next.
public struct ThemePanorama: View {
    let index: Int
    let environment: AppScreenshotEnvironment

    public init(index: Int, environment: AppScreenshotEnvironment) {
        self.index = index
        self.environment = environment
    }

    static let themes: [ScreenshotTheme] = [.purple, .teal, .orange]

    private var size: CGSize { environment.canvasSize }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            background
            HStack(spacing: 0) {
                FramedScreenshotView(screenshotName: "01_Home_Portrait", environment: environment,
                                     headerText: ScreenshotText.home, theme: Self.themes[0], showsBackground: false)
                FramedScreenshotView(screenshotName: "02_Areas_Portrait", environment: environment,
                                     headerText: ScreenshotText.areas, theme: Self.themes[1], showsBackground: false)
                themeTrio
                    .frame(width: size.width, height: size.height)
            }
        }
        .frame(width: size.width * 3, height: size.height, alignment: .topLeading)
        .offset(x: -CGFloat(index) * size.width)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .clipped()
    }

    private var background: some View {
        ZStack {
            LinearGradient(colors: Self.themes.map(\.backdrop), startPoint: .leading, endPoint: .trailing)
            LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
        }
        .frame(width: size.width * 3, height: size.height)
    }

    /// The same Home feed in three themes, the frame's own theme in front.
    private var themeTrio: some View {
        VStack(spacing: 0) {
            ScreenshotCaption(text: ScreenshotText.themes, canvasHeight: size.height)
            // Back phones stay inside this frame, so nothing leaks across the seam into frame 2.
            ZStack {
                phone(.blue).scaleEffect(0.8).offset(x: -size.width * 0.2, y: size.height * 0.03)
                phone(.purple).scaleEffect(0.8).offset(x: size.width * 0.2, y: size.height * 0.03)
                phone(Self.themes[2]).shadow(color: .black.opacity(0.5), radius: size.width * 0.04)
            }
            .padding(.horizontal, size.width * 0.15)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding(.top, size.height * 0.02)
    }

    private func phone(_ theme: ScreenshotTheme) -> some View {
        guard let device = TargetDevice.from(device: environment.device) else {
            fatalError("Unknown device: \(environment.device)")
        }
        return DeviceView {
            RawScreenshot.required(named: "01_Home_Portrait", in: theme.directoryName(for: device))
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
        }
    }
}

/// The bold white caption above the device, sized from the canvas.
struct ScreenshotCaption: View {
    let text: String
    let canvasHeight: CGFloat

    var body: some View {
        Text(text)
            .font(.system(size: canvasHeight * 0.032, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.top, canvasHeight * 0.06)
            .padding(.bottom, canvasHeight * 0.02)
    }
}
