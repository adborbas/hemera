import SwiftUI
import Testing
@testable import Hemera

@MainActor
struct ScreenManagerTests {

    let screenManager: ScreenManager
    let store: InMemorySettingsStore

    init() {
        store = InMemorySettingsStore()
        screenManager = ScreenManager(store: store)
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

    /// Logout calls `resetToDefaults()`; it must stay kiosk-only.
    @Test func resetToDefaults_leavesNonKioskSettingsUntouched() {
        store.settings.areasGroupedByFloor = false

        screenManager.resetToDefaults()

        #expect(store.settings.areasGroupedByFloor == false)
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

    // MARK: - Scene Phase

    @Test func handleScenePhase_inactive_whileDimmed_keepsDim() {
        screenManager.stayAwake = true
        screenManager.executePreviewDim()
        #expect(screenManager.isDimmed == true)

        screenManager.handleScenePhase(.inactive)

        #expect(screenManager.isDimmed == true)
    }

    @Test func handleScenePhase_background_whileDimmed_clearsDim() {
        screenManager.stayAwake = true
        screenManager.executePreviewDim()
        #expect(screenManager.isDimmed == true)

        screenManager.handleScenePhase(.background)

        #expect(screenManager.isDimmed == false)
    }

}
