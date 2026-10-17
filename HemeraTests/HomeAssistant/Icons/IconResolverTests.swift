import Observation
import Synchronization
import Testing
@testable import Hemera

@MainActor
struct IconResolverTests {

    // MARK: - Fixtures

    /// Mirrors the real shape of HA's `cover` and `climate` icon translations.
    private static func fixture() -> IconTranslations {
        IconTranslations(resources: [
            "cover": [
                "_": .init(defaultIcon: "mdi:window-open", state: ["closed": "mdi:window-closed"]),
                "garage": .init(defaultIcon: "mdi:garage-open", state: ["closed": "mdi:garage"])
            ],
            "climate": [
                "_": .init(
                    defaultIcon: "mdi:thermostat",
                    stateAttributes: [
                        "hvac_action": .init(
                            defaultIcon: "mdi:circle-medium",
                            state: ["cooling": "mdi:snowflake", "heating": "mdi:fire"]
                        )
                    ]
                )
            ]
        ])
    }

    private func resolver() -> IconResolver {
        IconResolver(translations: Self.fixture())
    }

    // MARK: - Precedence

    /**
     The entity's own `icon` attribute is a deliberate user or integration override, so it has to win
     over anything the translations say — this is the first branch of HA's own `getEntityIcon`.
    */
    @Test func iconName_entityIconOverride_winsOverTranslations() {
        #expect(resolver().iconName(domain: "cover", deviceClass: "garage", state: "closed",
                                    entityIcon: "mdi:rocket") == "rocket")
    }

    @Test func iconName_deviceClassEntry_preferredOverDomainFallback() {
        #expect(resolver().iconName(domain: "cover", deviceClass: "garage", state: "open") == "garage-open")
    }

    @Test func iconName_stateMatch_beatsDefault() {
        #expect(resolver().iconName(domain: "cover", deviceClass: "garage", state: "closed") == "garage")
    }

    /**
     An unmodelled device_class must fall through to the domain-wide `_` entry rather than resolving
     to nothing, otherwise every class Hemera does not know about renders blank.
    */
    @Test func iconName_unknownDeviceClass_fallsBackToDomainEntry() {
        #expect(resolver().iconName(domain: "cover", deviceClass: "awning", state: "closed") == "window-closed")
    }

    @Test func iconName_noDeviceClass_usesDomainEntry() {
        #expect(resolver().iconName(domain: "cover", state: "open") == "window-open")
    }

    @Test func iconName_unknownDomain_returnsNil() {
        #expect(resolver().iconName(domain: "vacuum", state: "cleaning") == nil)
    }

    /// An unresolvable icon pack must not shadow the translations — fall through, don't return nil.
    @Test func iconName_unsupportedEntityIconPack_fallsThroughToTranslations() {
        #expect(resolver().iconName(domain: "cover", deviceClass: "garage", state: "closed",
                                    entityIcon: "phu:garage") == "garage")
    }

    // MARK: - Attributes

    @Test func attributeIconName_matchingValue_returnsStateIcon() {
        #expect(resolver().attributeIconName(domain: "climate", attribute: "hvac_action",
                                             value: "heating") == "fire")
    }

    /**
     HA's `hvac_action` entry defaults to `mdi:circle-medium`, a placeholder dot. Returning it would
     put a grey blob on the card, so an unmatched value must resolve to nil and let the caller choose.
    */
    @Test func attributeIconName_unmatchedValue_returnsNilRatherThanPlaceholderDot() {
        #expect(resolver().attributeIconName(domain: "climate", attribute: "hvac_action",
                                             value: "idle") == nil)
    }

    @Test func attributeIconName_nilValue_returnsNil() {
        #expect(resolver().attributeIconName(domain: "climate", attribute: "hvac_action", value: nil) == nil)
    }

    // MARK: - Observation

    /**
     Translations land after the first paint, so cards only pick them up if the resolver emits an
     observation change. Asserting the resolved name alone would pass even with a plain class, which
     is exactly the regression this guards: the icons would render only after some unrelated redraw.
    */
    @Test func update_emitsObservationChange() {
        let resolver = IconResolver(translations: IconTranslations(resources: [:]))
        let didChange = Mutex(false)

        withObservationTracking {
            _ = resolver.translations
        } onChange: {
            didChange.withLock { $0 = true }
        }

        resolver.update(Self.fixture())

        #expect(didChange.withLock { $0 })
        #expect(resolver.iconName(domain: "cover", state: "open") == "window-open")
    }

    /**
     Call sites hold the resolver as `any IconResolving`, and an existential is the one thing in the
     observation path that could plausibly swallow the change notification. If it did, every card
     would stay pinned to the bundled snapshot for the whole session with nothing to show for it.
    */
    @Test func update_emitsObservationChange_throughExistential() {
        let resolver = IconResolver(translations: IconTranslations(resources: [:]))
        let erased: any IconResolving = resolver
        let didChange = Mutex(false)

        withObservationTracking {
            _ = erased.iconName(domain: "cover", state: "open")
        } onChange: {
            didChange.withLock { $0 = true }
        }

        resolver.update(Self.fixture())

        #expect(didChange.withLock { $0 })
        #expect(erased.iconName(domain: "cover", state: "open") == "window-open")
    }
}
