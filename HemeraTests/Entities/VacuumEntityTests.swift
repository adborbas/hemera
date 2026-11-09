import Foundation
import Testing
import HAKit
@testable import Hemera

struct VacuumEntityTests {

    @Test(arguments: ["cleaning", "docked", "idle", "paused", "returning", "error", "unknown", "unavailable"])
    func update_mapsHomeAssistantState(_ state: String) throws {
        let entity = VacuumEntity(entityId: "vacuum.robot")

        entity.update(from: try haEntity(state: state))

        #expect(entity.state.rawValue == state)
    }

    // A state HA adds later must not crash the sync or pass for a known one.
    @Test
    func update_unrecognisedState_isUnknown() throws {
        let entity = VacuumEntity(entityId: "vacuum.robot", name: "Robot", state: .docked)

        entity.update(from: try haEntity(state: "mopping"))

        #expect(entity.state == .unknown)
    }

    @Test
    func update_mapsHomeAssistantFeatureBits() throws {
        let entity = VacuumEntity(entityId: "vacuum.robot")

        entity.update(from: try haEntity(attributes: ["supported_features": 4 | 8 | 16 | 512 | 8192]))

        #expect(entity.supportedFeatures == [.pause, .stop, .returnHome, .locate, .start])
    }

    @Test
    func update_ignoresUnmodelledFeatureBits() throws {
        let entity = VacuumEntity(entityId: "vacuum.robot")

        // Fan speed (32) and clean spot (1024) only.
        entity.update(from: try haEntity(attributes: ["supported_features": 32 | 1024]))

        #expect(entity.supportedFeatures.intersection([.pause, .stop, .returnHome, .locate, .start]).isEmpty)
    }

    @Test
    func update_parsesNameAndIcon() throws {
        let entity = VacuumEntity(entityId: "vacuum.robot")

        entity.update(from: try haEntity(attributes: ["friendly_name": "Roborock", "icon": "mdi:robot-mower"]))

        #expect(entity.name == "Roborock")
        #expect(entity.icon == "mdi:robot-mower")
    }

    @Test
    func update_withoutFriendlyName_fallsBackToEntityId() throws {
        let entity = VacuumEntity(entityId: "vacuum.robot")

        entity.update(from: try haEntity())

        #expect(entity.name == "vacuum.robot")
        #expect(entity.supportedFeatures.isEmpty)
    }

    private func haEntity(state: String = "docked", attributes: [String: Any] = [:]) throws -> HAEntity {
        try HAEntity(
            entityId: "vacuum.robot",
            domain: "vacuum",
            state: state,
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: attributes,
            context: .init(id: "", userId: nil, parentId: nil)
        )
    }
}
