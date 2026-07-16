import Foundation
import Testing
import HAKit
@testable import Hemera

struct ClimateEntityTests {

    private func makeHAEntity(attributes: [String: Any]) throws -> HAEntity {
        try HAEntity(
            entityId: "climate.test",
            domain: "climate",
            state: "heat",
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: attributes,
            context: .init(id: "", userId: nil, parentId: nil)
        )
    }

    @Test
    func update_withInvertedTempBounds_sortsMinMax() throws {
        let entity = ClimateEntity(entityId: "climate.test")
        let haEntity = try makeHAEntity(attributes: ["min_temp": 35.0, "max_temp": 7.0])

        entity.update(from: haEntity)

        #expect(entity.minTemp == 7)
        #expect(entity.maxTemp == 35)
        #expect(entity.minTemp <= entity.maxTemp)
    }

    @Test
    func update_withOrderedTempBounds_preservesValues() throws {
        let entity = ClimateEntity(entityId: "climate.test")
        let haEntity = try makeHAEntity(attributes: ["min_temp": 10.0, "max_temp": 30.0])

        entity.update(from: haEntity)

        #expect(entity.minTemp == 10)
        #expect(entity.maxTemp == 30)
    }

    @Test
    func update_withMissingTempBounds_usesSortedDefaults() throws {
        let entity = ClimateEntity(entityId: "climate.test")
        let haEntity = try makeHAEntity(attributes: [:])

        entity.update(from: haEntity)

        #expect(entity.minTemp == 7)
        #expect(entity.maxTemp == 35)
        #expect(entity.minTemp <= entity.maxTemp)
    }
}
