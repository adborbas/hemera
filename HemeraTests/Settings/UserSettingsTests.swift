import Foundation
import Testing
@testable import Hemera

@MainActor
struct UserSettingsTests {

    // MARK: - Defaults & Round Trip

    @Test func load_withEmptyStore_usesDefaults() {
        let settings = UserSettings.load(from: InMemorySettingsStore())

        #expect(settings.stayAwake == false)
        #expect(settings.dimTimeout == .thirtySeconds)
        #expect(settings.clockFormat == .system)
        #expect(settings.areasGroupedByFloor == true)
    }

    @Test func load_withEmptyStore_doesNotWrite() {
        let store = InMemorySettingsStore()

        _ = UserSettings.load(from: store)

        // Loading must never persist, so an untouched default stays changeable later.
        #expect(store.json == nil)
    }

    @Test func mutation_persistsAndReloads() {
        let store = InMemorySettingsStore()
        let settings = UserSettings.load(from: store)

        settings.stayAwake = true
        settings.dimTimeout = .fiveMinutes
        settings.clockFormat = .twentyFourHour
        settings.areasGroupedByFloor = false

        let reloaded = UserSettings.load(from: store)
        #expect(reloaded.stayAwake == true)
        #expect(reloaded.dimTimeout == .fiveMinutes)
        #expect(reloaded.clockFormat == .twentyFourHour)
        #expect(reloaded.areasGroupedByFloor == false)
    }

    // MARK: - Shape Tolerance
    //
    // Each case asserts the *other* settings survive — the whole point of the machinery.

    @Test func load_withFieldAddedSinceWriting_defaultsOnlyThatField() {
        // Written before `clockFormat` existed.
        let store = InMemorySettingsStore(json: #"{"stayAwake":true,"dimTimeout":300,"areasGroupedByFloor":false}"#)

        let settings = UserSettings.load(from: store)

        #expect(settings.clockFormat == .system)
        #expect(settings.stayAwake == true)
        #expect(settings.dimTimeout == .fiveMinutes)
        #expect(settings.areasGroupedByFloor == false)
    }

    @Test func load_withUnknownField_ignoresIt() {
        let store = InMemorySettingsStore(json: #"{"stayAwake":true,"removedSetting":"x"}"#)

        let settings = UserSettings.load(from: store)

        #expect(settings.stayAwake == true)
    }

    @Test func load_withOneCorruptField_revertsOnlyThatField() {
        let store = InMemorySettingsStore(json: #"{"stayAwake":"not-a-bool","dimTimeout":300,"areasGroupedByFloor":false}"#)

        let settings = UserSettings.load(from: store)

        #expect(settings.stayAwake == false)
        #expect(settings.dimTimeout == .fiveMinutes)
        #expect(settings.areasGroupedByFloor == false)
    }

    @Test func load_withTwoCorruptFields_revertsOnlyThoseFields() {
        let store = InMemorySettingsStore(json: #"{"stayAwake":"x","dimTimeout":"y","areasGroupedByFloor":false}"#)

        let settings = UserSettings.load(from: store)

        #expect(settings.stayAwake == false)
        #expect(settings.dimTimeout == .thirtySeconds)
        #expect(settings.areasGroupedByFloor == false)
    }

    @Test func load_withUnknownEnumRawValue_revertsOnlyThatField() {
        let store = InMemorySettingsStore(json: #"{"dimTimeout":999,"areasGroupedByFloor":false}"#)

        let settings = UserSettings.load(from: store)

        #expect(settings.dimTimeout == .thirtySeconds)
        #expect(settings.areasGroupedByFloor == false)
    }

    @Test func load_withJunkData_fallsBackToDefaults() {
        let settings = UserSettings.load(from: InMemorySettingsStore(json: "not json at all"))

        #expect(settings.stayAwake == false)
        #expect(settings.areasGroupedByFloor == true)
    }

    /// Empty `codingPath` — the prune loop must bail out, not spin.
    @Test func load_withValidJSONThatIsNotAnObject_fallsBackToDefaults() {
        let settings = UserSettings.load(from: InMemorySettingsStore(json: "[1,2,3]"))

        #expect(settings.areasGroupedByFloor == true)
    }

    // MARK: - Downgrade

    @Test func load_withNewerSchemaVersion_usesDefaults() {
        let stored = #"{"schemaVersion":99,"stayAwake":true}"#
        let settings = UserSettings.load(from: InMemorySettingsStore(json: stored))

        #expect(settings.stayAwake == false)
    }

    /// Re-encoding newer settings would permanently drop values this build can't see.
    @Test func mutation_afterLoadingNewerSchemaVersion_doesNotOverwriteDocument() {
        let stored = #"{"schemaVersion":99,"stayAwake":true}"#
        let store = InMemorySettingsStore(json: stored)
        let settings = UserSettings.load(from: store)

        settings.stayAwake = true

        #expect(store.json == stored)
    }

    // MARK: - Merge Recursion
    //
    // Tested directly: no nested feature struct exists yet, so a decode can't reach it.

    @Test func merging_recursesIntoNestedObjects() {
        let defaults: [String: Any] = ["kiosk": ["stayAwake": false, "dimTimeout": 30]]
        let stored: [String: Any] = ["kiosk": ["stayAwake": true]]

        let merged = SettingsValues.merging(defaults, over: stored)

        let kiosk = merged["kiosk"] as? [String: Any]
        #expect(kiosk?["stayAwake"] as? Bool == true)
        #expect(kiosk?["dimTimeout"] as? Int == 30)
    }

    @Test func merging_replacesArraysWholesale() {
        let defaults: [String: Any] = ["widgets": ["clock", "date", "weather"]]
        let stored: [String: Any] = ["widgets": ["clock"]]

        let merged = SettingsValues.merging(defaults, over: stored)

        // Element-wise merging would leave "date"/"weather" as phantom tail entries.
        #expect(merged["widgets"] as? [String] == ["clock"])
    }

    @Test func revert_atNestedPath_restoresOnlyThatField() {
        var object: [String: Any] = ["kiosk": ["stayAwake": "bad", "dimTimeout": 300]]
        let defaults: [String: Any] = ["kiosk": ["stayAwake": false, "dimTimeout": 30]]

        SettingsValues.revert(path: ["kiosk", "stayAwake"], in: &object, to: defaults)

        let kiosk = object["kiosk"] as? [String: Any]
        #expect(kiosk?["stayAwake"] as? Bool == false)
        #expect(kiosk?["dimTimeout"] as? Int == 300)
    }

    // MARK: - Reset

    @Test func resetToDefaults_restoresEverySetting() {
        let settings = UserSettings.load(from: InMemorySettingsStore())
        settings.stayAwake = true
        settings.areasGroupedByFloor = false

        settings.resetToDefaults()

        #expect(settings.stayAwake == false)
        #expect(settings.areasGroupedByFloor == true)
    }

}
