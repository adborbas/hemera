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

    /// v1 plus the pill row: both fields are additive, so the schema version is unchanged.
    static let v1FeedRow = """
    {
      "areasGroupedByFloor" : true,
      "clockFormat" : 0,
      "dimTimeout" : 30,
      "feedRow" : [
        "home",
        "area:kitchen",
        "custom:1234"
      ],
      "offeredBuiltInFeeds" : [
        "home",
        "areas",
        "domain:light",
        "domain:cover",
        "domain:climate",
        "domain:scene"
      ],
      "schemaVersion" : 1,
      "stayAwake" : true
    }
    """

    /// v1 plus a Gradient theme and Show Theme: additive, so the schema version is unchanged.
    static let v1Theme = """
    {
      "areasGroupedByFloor" : true,
      "clockFormat" : 0,
      "dimTimeout" : 30,
      "feedRow" : [
        "home",
        "area:kitchen",
        "custom:1234"
      ],
      "offeredBuiltInFeeds" : [
        "home",
        "areas",
        "domain:light",
        "domain:cover",
        "domain:climate",
        "domain:scene"
      ],
      "schemaVersion" : 1,
      "screensaverShowsTheme" : false,
      "stayAwake" : true,
      "theme" : {
        "color" : {
          "brightness" : 1,
          "hue" : 0.07,
          "saturation" : 0.8
        },
        "family" : "bright",
        "intensity" : 0.5,
        "kind" : "gradient"
      }
    }
    """

    /// The None theme still writes its key, so the decoder has a default to overlay onto.
    static let v1ThemeNone = """
    {
      "areasGroupedByFloor" : true,
      "clockFormat" : 0,
      "dimTimeout" : 30,
      "feedRow" : [
        "home",
        "area:kitchen",
        "custom:1234"
      ],
      "offeredBuiltInFeeds" : [
        "home",
        "areas",
        "domain:light",
        "domain:cover",
        "domain:climate",
        "domain:scene"
      ],
      "schemaVersion" : 1,
      "screensaverShowsTheme" : false,
      "stayAwake" : true,
      "theme" : {
        "kind" : "none"
      }
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

    @Test func v1_hasDefaultFeedRow() {
        // Settings written before the pill row existed must open on the default row.
        defaults.set(Self.v1, forKey: UserDefaultsSettingsStore.storageKey)

        let settings = UserDefaultsSettingsStore(defaults: defaults).settings

        #expect(settings.feedRow == nil)
        #expect(settings.offeredBuiltInFeeds == FeedID.builtIns)
    }

    @Test func v1FeedRow_writesBackUnknownFeedsUnchanged() {
        // Pins from a newer build must survive a downgrade and the next write.
        defaults.set(Self.v1FeedRow, forKey: UserDefaultsSettingsStore.storageKey)
        let store = UserDefaultsSettingsStore(defaults: defaults)

        store.settings.stayAwake = true

        let reloaded = UserDefaultsSettingsStore(defaults: defaults).settings
        #expect(reloaded.feedRow?.map(\.rawValue) == ["home", "area:kitchen", "custom:1234"])
    }

    /// Fails if the stored format drifts — a renamed key, a changed raw value, different
    /// formatting. Update the fixture only alongside a `SettingsMigration` step.
    @Test func currentEncoding_matchesV1Theme() {
        let store = UserDefaultsSettingsStore(defaults: defaults)
        store.settings.stayAwake = true
        store.settings.feedRow = [.home, FeedID(rawValue: "area:kitchen"), FeedID(rawValue: "custom:1234")]
        store.settings.screensaverShowsTheme = false
        store.settings.theme = .gradient(Self.gradient)

        let written = defaults.string(forKey: UserDefaultsSettingsStore.storageKey)

        #expect(written == Self.v1Theme)
    }

    // MARK: - Theme

    static let gradient = Theme.Gradient(
        color: ThemeColor(hue: 0.07, saturation: 0.8, brightness: 1),
        intensity: 0.5,
        family: .bright
    )

    @Test(arguments: [v1, v1FeedRow])
    func preThemeFixtures_haveNoThemeAndShowTheme(json: String) {
        // Settings written before themes existed must open unthemed, with Show Theme on.
        defaults.set(json, forKey: UserDefaultsSettingsStore.storageKey)

        let settings = UserDefaultsSettingsStore(defaults: defaults).settings

        #expect(settings.theme == .none)
        #expect(settings.screensaverShowsTheme == true)
    }

    @Test func v1Theme_decodes() {
        defaults.set(Self.v1Theme, forKey: UserDefaultsSettingsStore.storageKey)

        let settings = UserDefaultsSettingsStore(defaults: defaults).settings

        #expect(settings.theme == .gradient(Self.gradient))
        #expect(settings.screensaverShowsTheme == false)
    }

    @Test func v1Theme_choosingNone_writesNoColour() {
        // A colour or intensity left behind would come back if a later build reads them.
        defaults.set(Self.v1Theme, forKey: UserDefaultsSettingsStore.storageKey)
        let store = UserDefaultsSettingsStore(defaults: defaults)

        store.settings.theme = .none

        #expect(defaults.string(forKey: UserDefaultsSettingsStore.storageKey) == Self.v1ThemeNone)
    }

    @Test func v1ThemeNone_decodesAsNone() {
        defaults.set(Self.v1ThemeNone, forKey: UserDefaultsSettingsStore.storageKey)

        #expect(UserDefaultsSettingsStore(defaults: defaults).settings.theme == .none)
    }

    @Test func unknownFamily_keepsColour() {
        // A family from a newer build is only a hint; losing the colour would lose the user's pick.
        let json = Self.v1Theme.replacingOccurrences(of: "\"bright\"", with: "\"neon\"")
        defaults.set(json, forKey: UserDefaultsSettingsStore.storageKey)

        let theme = UserDefaultsSettingsStore(defaults: defaults).settings.theme

        #expect(theme == .gradient(Theme.Gradient(color: Self.gradient.color, intensity: 0.5, family: nil)))
    }

    @Test func missingFamily_keepsColour() {
        let json = Self.v1Theme.replacingOccurrences(of: "\"family\" : \"bright\",\n", with: "")
        defaults.set(json, forKey: UserDefaultsSettingsStore.storageKey)

        let theme = UserDefaultsSettingsStore(defaults: defaults).settings.theme

        #expect(theme == .gradient(Theme.Gradient(color: Self.gradient.color, intensity: 0.5, family: nil)))
    }

    @Test func unknownKind_loadsNoneAndKeepsOtherSettings() {
        // A theme kind from a newer build must not reset every other setting.
        let json = Self.v1Theme.replacingOccurrences(of: "\"gradient\"", with: "\"photo\"")
        defaults.set(json, forKey: UserDefaultsSettingsStore.storageKey)

        let settings = UserDefaultsSettingsStore(defaults: defaults).settings

        #expect(settings.theme == .none)
        #expect(settings.stayAwake == true)
        #expect(settings.screensaverShowsTheme == false)
        #expect(settings.feedRow?.map(\.rawValue) == ["home", "area:kitchen", "custom:1234"])
    }
}
