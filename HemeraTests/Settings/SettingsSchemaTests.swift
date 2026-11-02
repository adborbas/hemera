import Foundation
import Testing
@testable import Hemera

/**
 The exact JSON each released schema version writes.

 Every fixture here must keep decoding, and the current encoder must keep producing the
 newest one. A silent change to either resets settings for everyone on upgrade — the one
 failure this layer exists to prevent.
*/
@MainActor
struct SettingsSchemaTests {

    /// v1 — the first release to store settings as one value. Taken off a real device.
    static let v1 = """
    {
      "areasGroupedByFloor" : true,
      "clockFormat" : 0,
      "dimTimeout" : 30,
      "schemaVersion" : 1,
      "stayAwake" : true
    }
    """

    let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: "com.hemera.tests.\(UUID().uuidString)")!
    }

    @Test func v1_decodes() {
        defaults.set(Self.v1, forKey: UserDefaultsSettingsStore.storageKey)

        let settings = UserDefaultsSettingsStore(defaults: defaults).settings

        #expect(settings.stayAwake == true)
        #expect(settings.dimTimeout == .thirtySeconds)
        #expect(settings.clockFormat == .system)
        #expect(settings.areasGroupedByFloor == true)
        #expect(settings.schemaVersion == 1)
    }

    /// Fails if the stored format drifts — a renamed key, a changed raw value, different
    /// formatting. Update the fixture only alongside a `SettingsMigration` step.
    @Test func currentEncoding_matchesV1() {
        let store = UserDefaultsSettingsStore(defaults: defaults)
        store.settings.stayAwake = true

        let written = defaults.string(forKey: UserDefaultsSettingsStore.storageKey)

        #expect(written == Self.v1)
    }
}
