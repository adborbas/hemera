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
        let store = InMemorySettingsStore()

        SettingsMigration.run(on: store, defaults: defaults)

        let settings = UserSettings.load(from: store)
        #expect(settings.stayAwake == true)
        #expect(settings.dimTimeout == .fiveMinutes)
        #expect(settings.clockFormat == .twentyFourHour)
        #expect(settings.areasGroupedByFloor == false)
    }

    @Test func run_removesLegacyKeys() {
        defaults.set(true, forKey: "screenManager.stayAwake")
        defaults.set(false, forKey: "areaDisplaySettings.areasGroupedByFloor")

        SettingsMigration.run(on: InMemorySettingsStore(), defaults: defaults)

        #expect(defaults.object(forKey: "screenManager.stayAwake") == nil)
        #expect(defaults.object(forKey: "areaDisplaySettings.areasGroupedByFloor") == nil)
    }

    /// The trap: `bool(forKey:)` returns `false` for an absent key while
    /// `areasGroupedByFloor` defaults to `true`, so a naive import turns grouping off for
    /// every user who never touched it.
    @Test func run_withSomeLegacyKeysAbsent_leavesThemAtTheirDefaults() {
        defaults.set(true, forKey: "screenManager.stayAwake")
        let store = InMemorySettingsStore()

        SettingsMigration.run(on: store, defaults: defaults)

        let settings = UserSettings.load(from: store)
        #expect(settings.stayAwake == true)
        #expect(settings.areasGroupedByFloor == true)
        #expect(settings.dimTimeout == .thirtySeconds)
        #expect(settings.clockFormat == .system)
    }

    // MARK: - Fresh Install

    @Test func run_onFreshInstall_writesNothing() {
        let store = InMemorySettingsStore()

        SettingsMigration.run(on: store, defaults: defaults)

        #expect(store.json == nil)
    }

    // MARK: - Idempotence

    @Test func run_withExistingSettings_keepsThemAndDropsStaleLegacyKeys() {
        let stored = #"{"schemaVersion":1,"stayAwake":false}"#
        let store = InMemorySettingsStore(json: stored)
        defaults.set(true, forKey: "screenManager.stayAwake")

        SettingsMigration.run(on: store, defaults: defaults)

        // The stored settings win — the legacy key is a leftover, not newer truth.
        #expect(store.json == stored)
        #expect(defaults.object(forKey: "screenManager.stayAwake") == nil)
    }

    @Test func run_twice_isStable() {
        defaults.set(true, forKey: "screenManager.stayAwake")
        let store = InMemorySettingsStore()

        SettingsMigration.run(on: store, defaults: defaults)
        let afterFirst = store.json
        SettingsMigration.run(on: store, defaults: defaults)

        #expect(store.json == afterFirst)
    }
}
