import Foundation
import SwiftData
import HAKit
import Testing
@testable import Hemera

/**
 Covers the wiring from a sync payload to the resolver.

 Everything either side of this is tested — the decode in `IconTranslationsDecodingTests`, the
 lookup in `IconResolverTests` — but the one line joining them was not, and losing it fails
 silently: every session would keep serving the bundled snapshot with no error and no failing test.
*/
@MainActor
struct IconTranslationsSyncTests {

    private let container: ModelContainer
    private let resolver: IconResolver
    private let service: HADataSyncService

    init() {
        let schema = Schema([LightEntity.self, AreaEntity.self, FloorEntity.self, HomeTile.self])
        container = try! ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))

        let url = URL(string: "http://localhost:8123")!
        resolver = IconResolver(translations: IconTranslationsFixture.translations)
        service = HADataSyncService(
            connectionManager: HAConnectionManager(urlProvider: { url }, tokenProvider: { "" }),
            mainContext: container.mainContext,
            entityRegistry: EntityRegistry.shared,
            iconResolver: resolver,
            onSyncComplete: {}
        )
    }

    // MARK: - Tests

    @Test func applySyncPayload_withTranslations_reachesTheResolver() async {
        await service.applySyncPayload(payload(translations: IconTranslations(resources: [
            "light": ["_": .init(defaultIcon: "mdi:ceiling-light")]
        ])))

        #expect(resolver.iconName(domain: "light") == "ceiling-light")
    }

    /// A failed or empty fetch must leave the bundled names in place rather than blanking the cards.
    @Test func applySyncPayload_withoutTranslations_keepsExistingNames() async {
        await service.applySyncPayload(payload(translations: nil))

        #expect(resolver.iconName(domain: "light") == "lightbulb")
    }

    /**
     Home Assistant only reports integrations it has loaded. A server not running `climate` must not
     strip the bundled climate icons out from under entities still in the store.
    */
    @Test func applySyncPayload_domainAbsentFromServer_keepsBundledIcons() async {
        await service.applySyncPayload(payload(translations: IconTranslations(resources: [
            "light": ["_": .init(defaultIcon: "mdi:ceiling-light")]
        ])))

        #expect(resolver.iconName(domain: "climate") == "thermostat")
    }

    /// Each update overlays the bundle, not the previous response, so a domain cannot accumulate.
    @Test func applySyncPayload_twice_doesNotStackOntoThePreviousResponse() async {
        await service.applySyncPayload(payload(translations: IconTranslations(resources: [
            "cover": ["_": .init(defaultIcon: "mdi:garage")]
        ])))
        await service.applySyncPayload(payload(translations: IconTranslations(resources: [
            "light": ["_": .init(defaultIcon: "mdi:ceiling-light")]
        ])))

        #expect(resolver.iconName(domain: "cover") == "window-open")
    }

    // MARK: - Helpers

    private func payload(translations: IconTranslations?) -> HADataSyncService.SyncPayload {
        HADataSyncService.SyncPayload(
            entities: [],
            areaMappings: [],
            deviceMappings: [],
            hiddenEntityIds: nil,
            areaSortOrder: [:],
            areaIcons: [:],
            areaMappingsFetchSucceeded: false,
            floors: nil,
            floorSortOrder: [:],
            areaFloorIds: [:],
            iconTranslations: translations
        )
    }
}
