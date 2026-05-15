import Testing
@testable import Hemera

@MainActor
struct ScreenManagerTests {

    let screenManager: ScreenManager

    init() {
        screenManager = ScreenManager()
        screenManager.resetToDefaults()
    }

    // MARK: - Clock Format Defaults

    @Test func clockFormat_defaultsToSystem() {
        #expect(screenManager.clockFormat == .system)
    }

    // MARK: - Reset To Defaults

    @Test func resetToDefaults_resetsClockFormatToSystem() {
        screenManager.clockFormat = .twentyFourHour

        screenManager.resetToDefaults()

        #expect(screenManager.clockFormat == .system)
    }

    @Test func resetToDefaults_resetsDimTimeoutToThirtySeconds() {
        screenManager.dimTimeout = .fiveMinutes

        screenManager.resetToDefaults()

        #expect(screenManager.dimTimeout == .thirtySeconds)
    }

    @Test func resetToDefaults_resetsStayAwakeToFalse() {
        screenManager.stayAwake = true

        screenManager.resetToDefaults()

        #expect(screenManager.stayAwake == false)
    }

    // MARK: - Preview Dim

    @Test func executePreviewDim_dims() {
        screenManager.stayAwake = true

        screenManager.executePreviewDim()

        #expect(screenManager.isDimmed == true)
    }

    @Test func executePreviewDim_withoutStayAwake_dims() {
        screenManager.stayAwake = false

        screenManager.executePreviewDim()

        #expect(screenManager.isDimmed == true)
    }

}
