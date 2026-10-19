import Foundation
import Testing
@testable import Hemera

@MainActor
struct SettingsMigrationTests {

    let defaults: UserDefaults
    let suiteName: String

    init() {
        suiteName = "com.hemera.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    // MARK: - Legacy Import

    @Test func run_withAllLegacyKeys_importsThemIntoSettings() {
        defaults.set(true, forKey: "screenManager.stayAwake")
        defaults.set(300, forKey: "screenManager.dimTimeout")
        defaults.set(24, forKey: "screenManager.clockFormat")
        defaults.set(false, forKey: "areaDisplaySettings.areasGroupedByFloor")
        SettingsMigration.run(defaults: defaults)

        let settings = UserDefaultsSettingsStore(defaults: defaults).settings
        #expect(settings.stayAwake == true)
        #expect(settings.dimTimeout == .fiveMinutes)
        #expect(settings.clockFormat == .twentyFourHour)
        #expect(settings.areasGroupedByFloor == false)
    }

    @Test func run_removesLegacyKeys() {
        defaults.set(true, forKey: "screenManager.stayAwake")
        defaults.set(false, forKey: "areaDisplaySettings.areasGroupedByFloor")

        SettingsMigration.run(defaults: defaults)

        #expect(defaults.object(forKey: "screenManager.stayAwake") == nil)
        #expect(defaults.object(forKey: "areaDisplaySettings.areasGroupedByFloor") == nil)
    }

    /// The trap: `bool(forKey:)` returns `false` for an absent key while
    /// `areasGroupedByFloor` defaults to `true`, so a naive import turns grouping off for
    /// every user who never touched it.
    @Test func run_withSomeLegacyKeysAbsent_leavesThemAtTheirDefaults() {
        defaults.set(true, forKey: "screenManager.stayAwake")
        SettingsMigration.run(defaults: defaults)

        let settings = UserDefaultsSettingsStore(defaults: defaults).settings
        #expect(settings.stayAwake == true)
        #expect(settings.areasGroupedByFloor == true)
        #expect(settings.dimTimeout == .thirtySeconds)
        #expect(settings.clockFormat == .system)
    }

    // MARK: - Fresh Install

    @Test func run_onFreshInstall_writesNothing() {
        SettingsMigration.run(defaults: defaults)

        #expect(defaults.string(forKey: UserDefaultsSettingsStore.storageKey) == nil)
    }

    // MARK: - Idempotence

    @Test func run_withExistingSettings_keepsThemAndDropsStaleLegacyKeys() {
        let stored = #"{"schemaVersion":1,"stayAwake":false}"#
        defaults.set(stored, forKey: UserDefaultsSettingsStore.storageKey)
        defaults.set(true, forKey: "screenManager.stayAwake")

        SettingsMigration.run(defaults: defaults)

        // The stored settings win — the legacy key is a leftover, not newer truth.
        #expect(defaults.string(forKey: UserDefaultsSettingsStore.storageKey) == stored)
        #expect(defaults.object(forKey: "screenManager.stayAwake") == nil)
    }

    @Test func run_twice_isStable() {
        defaults.set(true, forKey: "screenManager.stayAwake")
        SettingsMigration.run(defaults: defaults)
        let afterFirst = defaults.string(forKey: UserDefaultsSettingsStore.storageKey)
        SettingsMigration.run(defaults: defaults)

        #expect(defaults.string(forKey: UserDefaultsSettingsStore.storageKey) == afterFirst)
    }
}
