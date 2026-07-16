import Testing
import UIKit
@testable import Hemera

@MainActor
struct MDISymbolMapperTests {

    // MARK: - Area Mapping: Prefix Handling

    @Test func sfSymbol_withMDIPrefix_stripsPrefix() {
        #expect(MDISymbolMapper.sfSymbol(for: "mdi:sofa") == "sofa.fill")
    }

    @Test func sfSymbol_withoutPrefix_mapsDirectly() {
        #expect(MDISymbolMapper.sfSymbol(for: "sofa") == "sofa.fill")
    }

    @Test func sfSymbol_unknownIcon_returnsNil() {
        #expect(MDISymbolMapper.sfSymbol(for: "mdi:totally-unknown-icon") == nil)
    }

    // MARK: - Area Mapping: Many-to-One Mappings

    @Test func sfSymbol_livingRoomVariants_allMapToSofa() {
        let expected = "sofa.fill"
        #expect(MDISymbolMapper.sfSymbol(for: "sofa") == expected)
        #expect(MDISymbolMapper.sfSymbol(for: "sofa-outline") == expected)
        #expect(MDISymbolMapper.sfSymbol(for: "television") == expected)
        #expect(MDISymbolMapper.sfSymbol(for: "tv") == expected)
    }

    @Test func sfSymbol_bedroomVariants_allMapToBed() {
        let expected = "bed.double.fill"
        #expect(MDISymbolMapper.sfSymbol(for: "bed") == expected)
        #expect(MDISymbolMapper.sfSymbol(for: "bed-double") == expected)
        #expect(MDISymbolMapper.sfSymbol(for: "bed-single") == expected)
        #expect(MDISymbolMapper.sfSymbol(for: "bedroom-outline") == expected)
        #expect(MDISymbolMapper.sfSymbol(for: "sleep") == expected)
        #expect(MDISymbolMapper.sfSymbol(for: "bunk-bed") == expected)
    }

    @Test func sfSymbol_kitchenVariants_allMapToForkKnife() {
        let expected = "fork.knife"
        #expect(MDISymbolMapper.sfSymbol(for: "silverware-fork-knife") == expected)
        #expect(MDISymbolMapper.sfSymbol(for: "stove") == expected)
        #expect(MDISymbolMapper.sfSymbol(for: "fridge") == expected)
        #expect(MDISymbolMapper.sfSymbol(for: "microwave") == expected)
        #expect(MDISymbolMapper.sfSymbol(for: "countertop") == expected)
    }

    @Test func sfSymbol_gardenVariants_allMapToLeaf() {
        let expected = "leaf.fill"
        #expect(MDISymbolMapper.sfSymbol(for: "flower") == expected)
        #expect(MDISymbolMapper.sfSymbol(for: "tree") == expected)
        #expect(MDISymbolMapper.sfSymbol(for: "grass") == expected)
        #expect(MDISymbolMapper.sfSymbol(for: "sprinkler") == expected)
        #expect(MDISymbolMapper.sfSymbol(for: "leaf") == expected)
    }

    @Test func sfSymbol_toiletMapsToToilet() {
        #expect(MDISymbolMapper.sfSymbol(for: "toilet") == "toilet.fill")
    }

    @Test func sfSymbol_bathroomVariants_allMapToShower() {
        let expected = "shower.fill"
        #expect(MDISymbolMapper.sfSymbol(for: "shower") == expected)
        #expect(MDISymbolMapper.sfSymbol(for: "bathtub") == expected)
        #expect(MDISymbolMapper.sfSymbol(for: "bathtub-outline") == expected)
    }

    @Test func sfSymbol_garageVariants_allMapToCar() {
        let expected = "car.fill"
        #expect(MDISymbolMapper.sfSymbol(for: "garage") == expected)
        #expect(MDISymbolMapper.sfSymbol(for: "garage-open") == expected)
        #expect(MDISymbolMapper.sfSymbol(for: "car") == expected)
    }

    @Test func sfSymbol_officeVariants_allMapToDesktop() {
        let expected = "desktopcomputer"
        #expect(MDISymbolMapper.sfSymbol(for: "desk") == expected)
        #expect(MDISymbolMapper.sfSymbol(for: "laptop") == expected)
        #expect(MDISymbolMapper.sfSymbol(for: "monitor") == expected)
    }

    @Test func sfSymbol_hallwayVariants_allMapToDoor() {
        let expected = "door.left.hand.open"
        #expect(MDISymbolMapper.sfSymbol(for: "door") == expected)
        #expect(MDISymbolMapper.sfSymbol(for: "door-open") == expected)
        #expect(MDISymbolMapper.sfSymbol(for: "coat-rack") == expected)
    }

    @Test func sfSymbol_laundryVariants_allMapToWasher() {
        let expected = "washer.fill"
        #expect(MDISymbolMapper.sfSymbol(for: "washing-machine") == expected)
        #expect(MDISymbolMapper.sfSymbol(for: "tumble-dryer") == expected)
    }

    @Test func sfSymbol_stairsVariants_allMapToStairs() {
        let expected = "stairs"
        #expect(MDISymbolMapper.sfSymbol(for: "stairs") == expected)
        #expect(MDISymbolMapper.sfSymbol(for: "stairs-up") == expected)
        #expect(MDISymbolMapper.sfSymbol(for: "home-floor-1") == expected)
    }

    @Test func sfSymbol_kidsVariants_allMapToFigureAndChild() {
        let expected = "figure.and.child.holdinghands"
        #expect(MDISymbolMapper.sfSymbol(for: "baby") == expected)
        #expect(MDISymbolMapper.sfSymbol(for: "toy-brick") == expected)
        #expect(MDISymbolMapper.sfSymbol(for: "teddy-bear") == expected)
    }

    @Test func sfSymbol_homeVariants_allMapToHouse() {
        let expected = "house.fill"
        #expect(MDISymbolMapper.sfSymbol(for: "home") == expected)
        #expect(MDISymbolMapper.sfSymbol(for: "home-outline") == expected)
        #expect(MDISymbolMapper.sfSymbol(for: "home-variant") == expected)
    }

    // MARK: - Entity Mapping

    @Test func entityAndAreaMappings_areIndependent() {
        #expect(MDISymbolMapper.sfSymbol(for: "speaker") == "play.tv.fill")
        #expect(MDISymbolMapper.entitySFSymbol(for: "speaker") == "hifispeaker.fill")
    }

    // MARK: - Mapping Integrity

    @Test func entityMapping_allMDINamesAreUnique() throws {
        try assertMDINamesAreUnique(in: "EntityMdiToSymbolMap")
    }

    @Test func areaMapping_allMDINamesAreUnique() throws {
        try assertMDINamesAreUnique(in: "AreaMdiToSymbolMap")
    }

    @Test func allMappedSFSymbols_existOnDevice() throws {
        for file in ["AreaMdiToSymbolMap", "EntityMdiToSymbolMap"] {
            let entries = try loadEntries(from: file)
            for entry in entries {
                if UIImage(systemName: entry.sfSymbol) == nil {
                    Issue.record("SF Symbol '\(entry.sfSymbol)' in \(file).json does not exist on this platform")
                }
            }
        }
    }

    @Test func bundledMaps_decodeToNonEmpty() throws {
        for file in ["AreaMdiToSymbolMap", "EntityMdiToSymbolMap"] {
            let entries = try loadEntries(from: file)
            #expect(!entries.isEmpty)
            #expect(entries.allSatisfy { !$0.mdiNames.isEmpty })
        }
    }

    // MARK: - Helpers

    private struct MappingEntry: Decodable {
        let sfSymbol: String
        let mdiNames: [String]
    }

    private func loadEntries(from resource: String) throws -> [MappingEntry] {
        let url = try #require(Bundle.main.url(forResource: resource, withExtension: "json"))
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([MappingEntry].self, from: data)
    }

    private func assertMDINamesAreUnique(in resource: String) throws {
        let entries = try loadEntries(from: resource)
        var seen: [String: String] = [:]
        for entry in entries {
            for mdiName in entry.mdiNames {
                if let existingSymbol = seen[mdiName] {
                    Issue.record("Duplicate MDI name '\(mdiName)' in \(resource).json: mapped to both '\(existingSymbol)' and '\(entry.sfSymbol)'")
                }
                seen[mdiName] = entry.sfSymbol
            }
        }
    }
}
