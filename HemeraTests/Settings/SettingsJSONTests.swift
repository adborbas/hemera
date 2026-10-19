import Foundation
import Testing
@testable import Hemera

@MainActor
struct SettingsJSONTests {

    // MARK: - Round Trip

    @Test func encodeThenDecode_preservesEverySetting() {
        var settings = Settings()
        settings.stayAwake = true
        settings.dimTimeout = .fiveMinutes
        settings.clockFormat = .twentyFourHour
        settings.areasGroupedByFloor = false

        let decoded = SettingsJSON.encode(settings).flatMap(SettingsJSON.decode)

        #expect(decoded == settings)
    }

    @Test func encode_usesLegibleSortedJSON() {
        let json = SettingsJSON.encode(Settings())

        #expect(json?.contains("\"stayAwake\" : false") == true)
        #expect(json?.contains("\n") == true)
    }

    // MARK: - Shape Tolerance
    //
    // Shipping a new setting must not disturb the ones a user already has.

    @Test func decode_withSettingAddedSinceWriting_defaultsOnlyThatSetting() {
        // Written before `clockFormat` existed.
        let decoded = SettingsJSON.decode(#"{"stayAwake":true,"dimTimeout":300,"areasGroupedByFloor":false}"#)

        #expect(decoded?.clockFormat == .system)
        #expect(decoded?.stayAwake == true)
        #expect(decoded?.dimTimeout == .fiveMinutes)
        #expect(decoded?.areasGroupedByFloor == false)
    }

    @Test func decode_withRemovedSetting_ignoresIt() {
        let decoded = SettingsJSON.decode(#"{"stayAwake":true,"removedSetting":"x"}"#)

        #expect(decoded?.stayAwake == true)
    }

    /// No per-field recovery — a type change is a migration's job.
    @Test func decode_withWrongTypedValue_returnsNil() {
        #expect(SettingsJSON.decode(#"{"stayAwake":"not-a-bool"}"#) == nil)
    }

    @Test func decode_withUnknownEnumRawValue_returnsNil() {
        #expect(SettingsJSON.decode(#"{"dimTimeout":999}"#) == nil)
    }

    @Test func decode_withJunk_returnsNil() {
        #expect(SettingsJSON.decode("not json at all") == nil)
    }

    @Test func decode_withValidJSONThatIsNotAnObject_returnsNil() {
        #expect(SettingsJSON.decode("[1,2,3]") == nil)
    }

    // MARK: - Merging
    //
    // Direct: no nested settings struct exists yet, so a decode can't reach the recursion.

    @Test func merging_recursesIntoNestedObjects() {
        let defaults: [String: Any] = ["kiosk": ["stayAwake": false, "dimTimeout": 30]]
        let stored: [String: Any] = ["kiosk": ["stayAwake": true]]

        let merged = SettingsJSON.merging(defaults, over: stored)

        let kiosk = merged["kiosk"] as? [String: Any]
        #expect(kiosk?["stayAwake"] as? Bool == true)
        #expect(kiosk?["dimTimeout"] as? Int == 30)
    }

    @Test func merging_replacesArraysWholesale() {
        let defaults: [String: Any] = ["widgets": ["clock", "date", "weather"]]
        let stored: [String: Any] = ["widgets": ["clock"]]

        let merged = SettingsJSON.merging(defaults, over: stored)

        // Element-wise merging would leave "date"/"weather" as phantom tail entries.
        #expect(merged["widgets"] as? [String] == ["clock"])
    }
}
