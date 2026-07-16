import Foundation
import SwiftData
import HAKit
import Testing
@testable import Hemera

/**
 Tests the real-time buffering path of `HADataSyncService`: events that arrive
 before the initial snapshot is applied are buffered and flushed in arrival
 order, so a change during the fetch window is reconciled instead of lost.
 */
@MainActor
struct HADataSyncBufferingTests {

    let container: ModelContainer
    let context: ModelContext
    let service: HADataSyncService

    init() {
        let schema = Schema([LightEntity.self, AreaEntity.self, FloorEntity.self, HomeTile.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: config)
        context = container.mainContext

        EntityRegistry.shared.register(LightEntity.self)

        let url = URL(string: "http://localhost:8123")!
        let connectionManager = HAConnectionManager(serverURL: url, tokenProvider: { "" })
        let restClient = HARESTClient(urlProvider: { url }, tokenProvider: { "" })
        service = HADataSyncService(
            connectionManager: connectionManager,
            restClient: restClient,
            mainContext: context,
            entityRegistry: EntityRegistry.shared,
            onSyncComplete: {}
        )
    }

    // MARK: - Helpers

    private func lightEvent(entityId: String, state: String) throws -> HAResponseEventStateChanged {
        let newState = try HAEntity(
            entityId: entityId,
            domain: "light",
            state: state,
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: ["friendly_name": "Lamp"],
            context: .init(id: "", userId: nil, parentId: nil)
        )
        let event = HAResponseEvent(
            type: .stateChanged,
            timeFired: Date(),
            data: [:],
            origin: .local,
            context: .init(id: "", userId: nil, parentId: nil)
        )
        return HAResponseEventStateChanged(
            event: event,
            entityId: entityId,
            oldState: nil,
            newState: newState
        )
    }

    private func storedLight(_ entityId: String) throws -> LightEntity? {
        try context.fetch(FetchDescriptor<LightEntity>(predicate: LightEntity.entityIdPredicate(entityId))).first
    }

    // MARK: - Buffering during the snapshot window

    @Test
    func handleStateChanged_beforeSnapshot_buffersUntilFlush() throws {
        let light = LightEntity(entityId: "light.lamp", name: "Lamp", state: .off)
        context.insert(light)

        // Event arrives before the snapshot is applied — must be buffered, not applied.
        service.handleStateChanged(try lightEvent(entityId: "light.lamp", state: "on"))
        #expect(try storedLight("light.lamp")?.state == .off)

        // Snapshot lands → buffered event is applied.
        service.flushBufferedEvents()
        #expect(try storedLight("light.lamp")?.state == .on)
    }

    @Test
    func flushBufferedEvents_appliesInArrivalOrder_lastWriterWins() throws {
        let light = LightEntity(entityId: "light.lamp", name: "Lamp", state: .off)
        context.insert(light)

        // Two changes for one entity, buffered in arrival order: on then off.
        service.handleStateChanged(try lightEvent(entityId: "light.lamp", state: "on"))
        service.handleStateChanged(try lightEvent(entityId: "light.lamp", state: "off"))
        #expect(try storedLight("light.lamp")?.state == .off) // untouched until flush

        service.flushBufferedEvents()
        // Newest state wins — the older "on" must not overwrite the newer "off".
        #expect(try storedLight("light.lamp")?.state == .off)
    }

    @Test
    func handleStateChanged_afterSnapshot_appliesImmediately() throws {
        let light = LightEntity(entityId: "light.lamp", name: "Lamp", state: .off)
        context.insert(light)

        // Flush with an empty buffer marks the snapshot as applied.
        service.flushBufferedEvents()

        service.handleStateChanged(try lightEvent(entityId: "light.lamp", state: "on"))
        #expect(try storedLight("light.lamp")?.state == .on)
    }
}
