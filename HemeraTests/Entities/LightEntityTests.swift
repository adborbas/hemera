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
}
