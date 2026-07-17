import Foundation
import Testing
import HAKit
@testable import Hemera

struct LightEntityTests {

    private func makeHAEntity(attributes: [String: Any]) throws -> HAEntity {
        try HAEntity(
            entityId: "light.test",
            domain: "light",
            state: "on",
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: attributes,
            context: .init(id: "", userId: nil, parentId: nil)
        )
    }

    @Test
    func update_withInvertedMireds_sortsBounds() throws {
        let entity = LightEntity(entityId: "light.test")
        let haEntity = try makeHAEntity(attributes: ["min_mireds": 500, "max_mireds": 153])

        entity.update(from: haEntity)

        #expect(entity.minMireds == 153)
        #expect(entity.maxMireds == 500)
        if let lo = entity.minMireds, let hi = entity.maxMireds {
            #expect(lo <= hi)
        }
    }

    @Test
    func update_withOrderedMireds_preservesValues() throws {
        let entity = LightEntity(entityId: "light.test")
        let haEntity = try makeHAEntity(attributes: ["min_mireds": 153, "max_mireds": 500])

        entity.update(from: haEntity)

        #expect(entity.minMireds == 153)
        #expect(entity.maxMireds == 500)
    }

    @Test
    func update_withMissingMireds_leavesBoundsNil() throws {
        let entity = LightEntity(entityId: "light.test")
        let haEntity = try makeHAEntity(attributes: [:])

        entity.update(from: haEntity)

        #expect(entity.minMireds == nil)
        #expect(entity.maxMireds == nil)
    }

    @Test
    func update_withKelvinAttributes_derivesInvertedMireds() throws {
        let entity = LightEntity(entityId: "light.test")
        // HA 2026.3 drops mireds; only kelvin bounds are sent. min mired ↔ max kelvin.
        let haEntity = try makeHAEntity(attributes: [
            "color_temp_kelvin": 4000,
            "min_color_temp_kelvin": 2000,
            "max_color_temp_kelvin": 6535
        ])

        entity.update(from: haEntity)

        #expect(entity.colorTemp == 1_000_000 / 4000)     // 250
        #expect(entity.minMireds == 1_000_000 / 6535)     // 153, from the highest kelvin
        #expect(entity.maxMireds == 1_000_000 / 2000)     // 500, from the lowest kelvin
    }

    @Test
    func update_prefersLegacyMiredsOverKelvin() throws {
        let entity = LightEntity(entityId: "light.test")
        let haEntity = try makeHAEntity(attributes: [
            "color_temp": 300,
            "min_mireds": 153,
            "max_mireds": 500,
            "color_temp_kelvin": 4000,
            "min_color_temp_kelvin": 2000,
            "max_color_temp_kelvin": 6535
        ])

        entity.update(from: haEntity)

        #expect(entity.colorTemp == 300)
        #expect(entity.minMireds == 153)
        #expect(entity.maxMireds == 500)
    }
}
