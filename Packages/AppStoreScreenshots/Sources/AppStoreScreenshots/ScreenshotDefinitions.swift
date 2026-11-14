import SwiftUI
import AppScreenshotKit

// MARK: - Home (panorama 1/3)

@AppScreenshot(.iPhone69Inch(model: .iPhone16ProMax(orientation: .portrait), size: .w1320h2868), .iPhone63Inch(model: .iPhone16Pro(orientation: .portrait), size: .w1206h2622), .iPad130Inch(model: .iPadPro13M4(orientation: .portrait), size: .w2048h2732))
struct S01_Home: View {
    @Environment(\.appScreenshotEnvironment) var environment
    var body: some View {
        ThemePanorama(index: 0, environment: environment)
    }
}

// MARK: - Areas (panorama 2/3)

@AppScreenshot(.iPhone69Inch(model: .iPhone16ProMax(orientation: .portrait), size: .w1320h2868), .iPhone63Inch(model: .iPhone16Pro(orientation: .portrait), size: .w1206h2622), .iPad130Inch(model: .iPadPro13M4(orientation: .portrait), size: .w2048h2732))
struct S02_Areas: View {
    @Environment(\.appScreenshotEnvironment) var environment
    var body: some View {
        ThemePanorama(index: 1, environment: environment)
    }
}

// MARK: - Themes (panorama 3/3)

@AppScreenshot(.iPhone69Inch(model: .iPhone16ProMax(orientation: .portrait), size: .w1320h2868), .iPhone63Inch(model: .iPhone16Pro(orientation: .portrait), size: .w1206h2622), .iPad130Inch(model: .iPadPro13M4(orientation: .portrait), size: .w2048h2732))
struct S03_Themes: View {
    @Environment(\.appScreenshotEnvironment) var environment
    var body: some View {
        ThemePanorama(index: 2, environment: environment)
    }
}

// MARK: - Light Control

@AppScreenshot(.iPhone69Inch(model: .iPhone16ProMax(orientation: .portrait), size: .w1320h2868), .iPhone63Inch(model: .iPhone16Pro(orientation: .portrait), size: .w1206h2622), .iPad130Inch(model: .iPadPro13M4(orientation: .portrait), size: .w2048h2732))
struct S04_LightControl: View {
    @Environment(\.appScreenshotEnvironment) var environment
    var body: some View {
        FramedScreenshotView(screenshotName: "03_LightControl_Portrait", environment: environment, headerText: ScreenshotText.lightControl, theme: .blue)
    }
}

// MARK: - Climate Control

@AppScreenshot(.iPhone69Inch(model: .iPhone16ProMax(orientation: .portrait), size: .w1320h2868), .iPhone63Inch(model: .iPhone16Pro(orientation: .portrait), size: .w1206h2622), .iPad130Inch(model: .iPadPro13M4(orientation: .portrait), size: .w2048h2732))
struct S05_ClimateControl: View {
    @Environment(\.appScreenshotEnvironment) var environment
    var body: some View {
        FramedScreenshotView(screenshotName: "06_ClimateControl_Portrait", environment: environment, headerText: ScreenshotText.climateControl, theme: .purple)
    }
}

// MARK: - Climate History

@AppScreenshot(.iPhone69Inch(model: .iPhone16ProMax(orientation: .portrait), size: .w1320h2868), .iPhone63Inch(model: .iPhone16Pro(orientation: .portrait), size: .w1206h2622), .iPad130Inch(model: .iPadPro13M4(orientation: .portrait), size: .w2048h2732))
struct S06_ClimateHistory: View {
    @Environment(\.appScreenshotEnvironment) var environment
    var body: some View {
        FramedScreenshotView(screenshotName: "08_ClimateHistory_Portrait", environment: environment, headerText: ScreenshotText.climateHistory, theme: .teal)
    }
}

// MARK: - Area Detail

@AppScreenshot(.iPhone69Inch(model: .iPhone16ProMax(orientation: .portrait), size: .w1320h2868), .iPhone63Inch(model: .iPhone16Pro(orientation: .portrait), size: .w1206h2622), .iPad130Inch(model: .iPadPro13M4(orientation: .portrait), size: .w2048h2732))
struct S07_AreaDetail: View {
    @Environment(\.appScreenshotEnvironment) var environment
    var body: some View {
        FramedScreenshotView(screenshotName: "07_AreaDetail_Portrait", environment: environment, headerText: ScreenshotText.areaDetail, theme: .orange)
    }
}

// MARK: - Cover Control

@AppScreenshot(.iPhone69Inch(model: .iPhone16ProMax(orientation: .portrait), size: .w1320h2868), .iPhone63Inch(model: .iPhone16Pro(orientation: .portrait), size: .w1206h2622), .iPad130Inch(model: .iPadPro13M4(orientation: .portrait), size: .w2048h2732))
struct S08_CoverControl: View {
    @Environment(\.appScreenshotEnvironment) var environment
    var body: some View {
        FramedScreenshotView(screenshotName: "04_CoverControl_Portrait", environment: environment, headerText: ScreenshotText.coverControl, theme: .blue)
    }
}
