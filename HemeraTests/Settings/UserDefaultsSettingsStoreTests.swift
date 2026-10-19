import Foundation
import Testing
@testable import Hemera

@MainActor
struct UserDefaultsSettingsStoreTests {

    let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: "com.hemera.tests.\(UUID().uuidString)")!
    }

    private func seed(_ json: String) {
        defaults.set(json, forKey: UserDefaultsSettingsStore.storageKey)
    }

    @Test func settings_withNothingStored_areDefaults() {
        let store = UserDefaultsSettingsStore(defaults: defaults)

        #expect(store.settings == Settings())
    }

    @Test func mutating_persistsEverySettingAcrossStores() {
        let store = UserDefaultsSettingsStore(defaults: defaults)
        store.settings.stayAwake = true
        store.settings.dimTimeout = .fiveMinutes

        let reloaded = UserDefaultsSettingsStore(defaults: defaults)

        #expect(reloaded.settings.stayAwake == true)
        #expect(reloaded.settings.dimTimeout == .fiveMinutes)
    }

    // MARK: - Shape Tolerance
    //
    // Shipping a new setting must not disturb the ones a user already has.

    @Test func init_withSettingAddedSinceWriting_defaultsOnlyThatSetting() {
        // Written before `clockFormat` existed.
        seed(#"{"stayAwake":true,"dimTimeout":300,"areasGroupedByFloor":false}"#)

        let store = UserDefaultsSettingsStore(defaults: defaults)

        #expect(store.settings.clockFormat == .system)
        #expect(store.settings.stayAwake == true)
        #expect(store.settings.dimTimeout == .fiveMinutes)
        #expect(store.settings.areasGroupedByFloor == false)
    }

    @Test func init_withRemovedSetting_ignoresIt() {
        seed(#"{"stayAwake":true,"removedSetting":"x"}"#)

        #expect(UserDefaultsSettingsStore(defaults: defaults).settings.stayAwake == true)
    }

    /// No per-field recovery — a type change is a migration's job.
    @Test func init_withWrongTypedValue_fallsBackToDefaults() {
        seed(#"{"stayAwake":"not-a-bool","dimTimeout":300}"#)

        #expect(UserDefaultsSettingsStore(defaults: defaults).settings == Settings())
    }

    @Test func init_withUnknownEnumRawValue_fallsBackToDefaults() {
        seed(#"{"dimTimeout":999}"#)

        #expect(UserDefaultsSettingsStore(defaults: defaults).settings == Settings())
    }

    @Test func init_withJunk_fallsBackToDefaults() {
        seed("not json at all")

        #expect(UserDefaultsSettingsStore(defaults: defaults).settings == Settings())
    }

    /// Overwriting it would destroy the only evidence of why a user's settings reset.
    @Test func init_withUnreadableValue_keepsACopy() {
        seed("not json at all")

        let store = UserDefaultsSettingsStore(defaults: defaults)
        store.settings.stayAwake = true

        #expect(defaults.string(forKey: UserDefaultsSettingsStore.unreadableKey) == "not json at all")
    }

    @Test func init_withValidJSONThatIsNotAnObject_fallsBackToDefaults() {
        seed("[1,2,3]")

        #expect(UserDefaultsSettingsStore(defaults: defaults).settings == Settings())
    }

    // MARK: - Downgrade
    //
    // Re-encoding newer settings would permanently drop fields this build can't see.

    @Test func init_withNewerSchemaVersion_usesDefaults() {
        seed(#"{"schemaVersion":99,"stayAwake":true}"#)

        let store = UserDefaultsSettingsStore(defaults: defaults)

        #expect(store.settings.stayAwake == false)
    }

    @Test func mutating_afterLoadingNewerSchemaVersion_doesNotWriteBack() {
        let stored = #"{"schemaVersion":99,"stayAwake":true}"#
        seed(stored)
        let store = UserDefaultsSettingsStore(defaults: defaults)

        store.settings.stayAwake = true

        #expect(defaults.string(forKey: UserDefaultsSettingsStore.storageKey) == stored)
    }
}
