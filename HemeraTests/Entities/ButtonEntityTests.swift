import Foundation
import Testing
import HAKit
@testable import Hemera

struct ButtonEntityTests {

    @Test
    func update_parsesFriendlyName() throws {
        let entity = ButtonEntity(entityId: "button.test")
        let haEntity = try HAEntity(
            entityId: "button.test",
            domain: "button",
            state: "unknown",
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: ["friendly_name": "Restart Router"],
            context: .init(id: "", userId: nil, parentId: nil)
        )

        entity.update(from: haEntity)

        #expect(entity.name == "Restart Router")
    }

    @Test
    func update_fallsBackToEntityId_whenFriendlyNameMissing() throws {
        let entity = ButtonEntity(entityId: "button.test")
        let haEntity = try HAEntity(
            entityId: "button.restart_router",
            domain: "button",
            state: "unknown",
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: [:],
            context: .init(id: "", userId: nil, parentId: nil)
        )

        entity.update(from: haEntity)

        #expect(entity.name == "button.restart_router")
    }

    @Test
    func update_parsesKnownDeviceClass() throws {
        let entity = ButtonEntity(entityId: "button.test")

        for deviceClass in ButtonEntity.DeviceClass.allCases where deviceClass != .unknown {
            let haEntity = try HAEntity(
                entityId: "button.test",
                domain: "button",
                state: "unknown",
                lastChanged: Date(),
                lastUpdated: Date(),
                attributes: ["device_class": deviceClass.rawValue],
                context: .init(id: "", userId: nil, parentId: nil)
            )

            entity.update(from: haEntity)

            #expect(entity.deviceClass == deviceClass)
        }
    }

    @Test
    func update_fallsBackToUnknown_forUnrecognizedDeviceClass() throws {
        let entity = ButtonEntity(entityId: "button.test")
        let haEntity = try HAEntity(
            entityId: "button.test",
            domain: "button",
            state: "unknown",
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: ["device_class": "nonexistent_class"],
            context: .init(id: "", userId: nil, parentId: nil)
        )

        entity.update(from: haEntity)

        #expect(entity.deviceClass == .unknown)
    }

    @Test
    func update_fallsBackToUnknown_whenDeviceClassMissing() throws {
        let entity = ButtonEntity(entityId: "button.test")
        let haEntity = try HAEntity(
            entityId: "button.test",
            domain: "button",
            state: "unknown",
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: [:],
            context: .init(id: "", userId: nil, parentId: nil)
        )

        entity.update(from: haEntity)

        #expect(entity.deviceClass == .unknown)
    }

    // MARK: - isUserActionable

    @Test
    func isUserActionable_restart_isTrue() {
        #expect(ButtonEntity.DeviceClass.restart.isUserActionable == true)
    }

    @Test
    func isUserActionable_update_isTrue() {
        #expect(ButtonEntity.DeviceClass.update.isUserActionable == true)
    }

    @Test
    func isUserActionable_identify_isFalse() {
        #expect(ButtonEntity.DeviceClass.identify.isUserActionable == false)
    }

    @Test
    func isUserActionable_unknown_isFalse() {
        #expect(ButtonEntity.DeviceClass.unknown.isUserActionable == false)
    }

    // MARK: - requiresConfirmation

    @Test
    func requiresConfirmation_restart_isTrue() {
        #expect(ButtonEntity.DeviceClass.restart.requiresConfirmation == true)
    }

    @Test
    func requiresConfirmation_update_isTrue() {
        #expect(ButtonEntity.DeviceClass.update.requiresConfirmation == true)
    }

    @Test
    func requiresConfirmation_identify_isFalse() {
        #expect(ButtonEntity.DeviceClass.identify.requiresConfirmation == false)
    }

    @Test
    func requiresConfirmation_unknown_isFalse() {
        #expect(ButtonEntity.DeviceClass.unknown.requiresConfirmation == false)
    }
}
