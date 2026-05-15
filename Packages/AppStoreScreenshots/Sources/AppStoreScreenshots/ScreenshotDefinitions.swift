import SwiftUI
import AppScreenshotKit

// MARK: - Home

@AppScreenshot(.iPhone69Inch(model: .iPhone16ProMax(orientation: .portrait), size: .w1320h2868), .iPad130Inch(model: .iPadPro13M4(orientation: .portrait), size: .w2048h2732))
struct S01_Home: View {
    @Environment(\.appScreenshotEnvironment) var environment
    var body: some View {
        FramedScreenshotView(screenshotName: "01_Home_Portrait", environment: environment, directorySuffix: "-Dark", headerText: ScreenshotText.home)
    }
}

// MARK: - Area Detail

@AppScreenshot(.iPhone69Inch(model: .iPhone16ProMax(orientation: .portrait), size: .w1320h2868), .iPad130Inch(model: .iPadPro13M4(orientation: .portrait), size: .w2048h2732))
struct S02_AreaDetail: View {
    @Environment(\.appScreenshotEnvironment) var environment
    var body: some View {
        FramedScreenshotView(screenshotName: "07_AreaDetail_Portrait", environment: environment, directorySuffix: "-Dark", headerText: ScreenshotText.areaDetail)
    }
}

// MARK: - Areas

@AppScreenshot(.iPhone69Inch(model: .iPhone16ProMax(orientation: .portrait), size: .w1320h2868), .iPad130Inch(model: .iPadPro13M4(orientation: .portrait), size: .w2048h2732))
struct S03_Areas: View {
    @Environment(\.appScreenshotEnvironment) var environment
    var body: some View {
        FramedScreenshotView(screenshotName: "02_Areas_Portrait", environment: environment, directorySuffix: "-Dark", headerText: ScreenshotText.areas)
    }
}

// MARK: - Light Control

@AppScreenshot(.iPhone69Inch(model: .iPhone16ProMax(orientation: .portrait), size: .w1320h2868), .iPad130Inch(model: .iPadPro13M4(orientation: .portrait), size: .w2048h2732))
struct S04_LightControl: View {
    @Environment(\.appScreenshotEnvironment) var environment
    var body: some View {
        FramedScreenshotView(screenshotName: "03_LightControl_Portrait", environment: environment, directorySuffix: "-Dark", headerText: ScreenshotText.lightControl)
    }
}

// MARK: - Cover Control

@AppScreenshot(.iPhone69Inch(model: .iPhone16ProMax(orientation: .portrait), size: .w1320h2868), .iPad130Inch(model: .iPadPro13M4(orientation: .portrait), size: .w2048h2732))
struct S05_CoverControl: View {
    @Environment(\.appScreenshotEnvironment) var environment
    var body: some View {
        FramedScreenshotView(screenshotName: "04_CoverControl_Portrait", environment: environment, directorySuffix: "-Dark", headerText: ScreenshotText.coverControl)
    }
}

// MARK: - Switch Control

@AppScreenshot(.iPhone69Inch(model: .iPhone16ProMax(orientation: .portrait), size: .w1320h2868), .iPad130Inch(model: .iPadPro13M4(orientation: .portrait), size: .w2048h2732))
struct S06_SwitchControl: View {
    @Environment(\.appScreenshotEnvironment) var environment
    var body: some View {
        FramedScreenshotView(screenshotName: "05_SwitchControl_Portrait", environment: environment, directorySuffix: "-Dark", headerText: ScreenshotText.switchControl)
    }
}

// MARK: - Climate Control

@AppScreenshot(.iPhone69Inch(model: .iPhone16ProMax(orientation: .portrait), size: .w1320h2868), .iPad130Inch(model: .iPadPro13M4(orientation: .portrait), size: .w2048h2732))
struct S07_ClimateControl: View {
    @Environment(\.appScreenshotEnvironment) var environment
    var body: some View {
        FramedScreenshotView(screenshotName: "06_ClimateControl_Portrait", environment: environment, directorySuffix: "-Dark", headerText: ScreenshotText.climateControl)
    }
}
