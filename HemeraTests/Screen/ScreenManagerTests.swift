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

    @Test func resetToDefaults_resetsScreensaverTimeoutToThirtySeconds() {
        screenManager.screensaverTimeout = .fiveMinutes

        screenManager.resetToDefaults()

        #expect(screenManager.screensaverTimeout == .thirtySeconds)
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

    // MARK: - Screensaver Preview

    @Test func executeScreensaverPreview_showsScreensaver() {
        screenManager.stayAwake = true

        screenManager.executeScreensaverPreview()

        #expect(screenManager.isScreensaverShown == true)
    }

    @Test func executeScreensaverPreview_withoutStayAwake_showsScreensaver() {
        screenManager.stayAwake = false

        screenManager.executeScreensaverPreview()

        #expect(screenManager.isScreensaverShown == true)
    }

    // MARK: - Scene Phase

    @Test func handleScenePhase_inactive_whileScreensaverShown_keepsScreensaver() {
        screenManager.stayAwake = true
        screenManager.executeScreensaverPreview()
        #expect(screenManager.isScreensaverShown == true)

        screenManager.handleScenePhase(.inactive)

        #expect(screenManager.isScreensaverShown == true)
    }

    @Test func handleScenePhase_background_whileScreensaverShown_hidesScreensaver() {
        screenManager.stayAwake = true
        screenManager.executeScreensaverPreview()
        #expect(screenManager.isScreensaverShown == true)

        screenManager.handleScenePhase(.background)

        #expect(screenManager.isScreensaverShown == false)
    }

}
