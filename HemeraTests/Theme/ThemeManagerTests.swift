import Foundation
import Testing
@testable import Hemera

@MainActor
struct ThemeManagerTests {

    let store: InMemorySettingsStore
    let manager: ThemeManager

    static let red = ThemeColor(hue: 0, saturation: 0.8, brightness: 1)
    static let blue = ThemeColor(hue: 0.6, saturation: 0.8, brightness: 1)
    static let storedGradient = Theme.Gradient(color: red, intensity: 0.7, family: .bright)

    init() {
        store = InMemorySettingsStore(settings: Settings(theme: .gradient(Self.storedGradient)))
        manager = ThemeManager(store: store, isScreenshotMode: false)
    }

    // MARK: - Edit Session

    @Test func init_showsStoredTheme() {
        #expect(manager.theme == .gradient(Self.storedGradient))
    }

    @Test func cancel_restoresThemeFromBeginning() {
        manager.beginEditing()
        manager.setColor(Self.blue, family: .bright)
        manager.setIntensity(0.1)

        manager.cancel()

        #expect(manager.theme == .gradient(Self.storedGradient))
    }

    @Test func liveChanges_beforeCommit_writeNothing() {
        // Dragging through colours must not persist anything the user then cancels.
        manager.beginEditing()
        manager.setColor(Self.blue, family: .pastel)
        manager.setIntensity(0.2)
        manager.chooseNone()

        #expect(store.settings.theme == .gradient(Self.storedGradient))
    }

    @Test func commit_writesLiveTheme() {
        manager.beginEditing()
        manager.setColor(Self.blue, family: nil)

        manager.commit()

        #expect(store.settings.theme == .gradient(Theme.Gradient(color: Self.blue, intensity: 0.7, family: nil)))
    }

    @Test func changes_afterCommit_areIgnored() {
        // A drag can end after Done; it must neither crash nor change what was just saved.
        manager.beginEditing()
        manager.setColor(Self.blue, family: .bright)
        manager.commit()
        let saved = manager.theme

        manager.setColor(Self.red, family: .bright)
        manager.setIntensity(1)
        manager.chooseNone()

        #expect(manager.theme == saved)
        #expect(store.settings.theme == saved)
    }

    @Test func chooseNone_commit_storesNoColourOrIntensity() {
        manager.beginEditing()
        manager.chooseNone()

        manager.commit()

        #expect(store.settings.theme == .none)
    }

    @Test func colourAfterNone_inSameSession_bringsBackShownIntensity() {
        manager.beginEditing()
        manager.setIntensity(0.4)
        manager.chooseNone()

        manager.setColor(Self.blue, family: .bright)

        #expect(manager.theme == .gradient(Theme.Gradient(color: Self.blue, intensity: 0.4, family: .bright)))
    }

    @Test func colourFromNone_newSession_usesDefaultIntensity() {
        manager.beginEditing()
        manager.chooseNone()
        manager.commit()

        manager.beginEditing()
        manager.setColor(Self.blue, family: .bright)

        let expected = Theme.Gradient(color: Self.blue, intensity: Theme.Gradient.defaultIntensity, family: .bright)
        #expect(manager.theme == .gradient(expected))
    }

    // MARK: - Show Theme

    @Test func screensaverShowsTheme_writesThroughImmediately() {
        manager.screensaverShowsTheme = false

        #expect(store.settings.screensaverShowsTheme == false)
    }

    @Test func screensaverShowsTheme_survivesThemeChangesAndNone() {
        manager.screensaverShowsTheme = false

        manager.beginEditing()
        manager.setColor(Self.blue, family: .bright)
        manager.chooseNone()
        manager.commit()
        manager.beginEditing()
        manager.setColor(Self.red, family: .bright)
        manager.commit()

        #expect(manager.screensaverShowsTheme == false)
        #expect(store.settings.screensaverShowsTheme == false)
    }

    // MARK: - Logout

    @Test func resetToDefaults_clearsThemeAndShowTheme_andPersists() {
        manager.screensaverShowsTheme = false

        manager.resetToDefaults()

        #expect(manager.theme == .none)
        #expect(manager.screensaverShowsTheme == true)
        #expect(store.settings.theme == .none)
        #expect(store.settings.screensaverShowsTheme == true)
    }

    // MARK: - Read-Only Store

    @Test func readOnlyStore_savesNothing() throws {
        let defaults = try #require(UserDefaults(suiteName: "com.hemera.tests.\(UUID().uuidString)"))
        let newer = #"{ "schemaVersion" : 99 }"#
        defaults.set(newer, forKey: UserDefaultsSettingsStore.storageKey)
        let manager = ThemeManager(store: UserDefaultsSettingsStore(defaults: defaults), isScreenshotMode: false)

        manager.beginEditing()
        manager.setColor(Self.blue, family: .bright)
        manager.commit()
        manager.screensaverShowsTheme = false

        #expect(manager.settingsAreReadOnly)
        #expect(defaults.string(forKey: UserDefaultsSettingsStore.storageKey) == newer)
    }

    // MARK: - Screenshot Mode

    @Test func screenshotMode_showsNone_andLeavesStoredThemeAlone() {
        // App Store screenshots must look unthemed without wiping the developer's own theme.
        let manager = ThemeManager(store: store, isScreenshotMode: true)

        manager.beginEditing()
        manager.commit()

        #expect(manager.theme == .none)
        #expect(store.settings.theme == .gradient(Self.storedGradient))
    }
}
