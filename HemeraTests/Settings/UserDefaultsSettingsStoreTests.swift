import Foundation
import Testing
@testable import Hemera

@MainActor
struct UserDefaultsSettingsStoreTests {

    let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: "com.hemera.tests.\(UUID().uuidString)")!
    }

    @Test func settings_withNothingStored_areDefaults() {
        let store = UserDefaultsSettingsStore(defaults: defaults)

        #expect(store.settings == Settings())
    }

    @Test func mutating_persistsAcrossStores() {
        let store = UserDefaultsSettingsStore(defaults: defaults)
        store.settings.stayAwake = true
        store.settings.dimTimeout = .fiveMinutes

        let reloaded = UserDefaultsSettingsStore(defaults: defaults)

        #expect(reloaded.settings.stayAwake == true)
        #expect(reloaded.settings.dimTimeout == .fiveMinutes)
    }

    @Test func init_withUnreadableValue_fallsBackToDefaults() {
        defaults.set("not json", forKey: UserDefaultsSettingsStore.storageKey)

        let store = UserDefaultsSettingsStore(defaults: defaults)

        #expect(store.settings == Settings())
    }

    // MARK: - Downgrade
    //
    // An older build must never re-encode newer settings: it would permanently drop every
    // field it doesn't know about.

    @Test func init_withNewerSchemaVersion_usesDefaults() {
        defaults.set(#"{"schemaVersion":99,"stayAwake":true}"#, forKey: UserDefaultsSettingsStore.storageKey)

        let store = UserDefaultsSettingsStore(defaults: defaults)

        #expect(store.settings.stayAwake == false)
    }

    @Test func mutating_afterLoadingNewerSchemaVersion_doesNotWriteBack() {
        let stored = #"{"schemaVersion":99,"stayAwake":true}"#
        defaults.set(stored, forKey: UserDefaultsSettingsStore.storageKey)
        let store = UserDefaultsSettingsStore(defaults: defaults)

        store.settings.stayAwake = true

        #expect(defaults.string(forKey: UserDefaultsSettingsStore.storageKey) == stored)
    }
}
