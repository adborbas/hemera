import Foundation
import HAKit
import Testing
@testable import Hemera

/// `applySyncPayload` deletes stored floors when handed `[]`, so nil-versus-empty is the point here.
@MainActor
struct RegistryEntriesDecodingTests {

    // MARK: - Area Registry

    @Test func areaDecodeList_decodesFloorAndIcon() throws {
        let entries = try #require(AreaRegistryEntry.decodeList(HAData(value: [
            ["area_id": "kitchen", "name": "Kitchen", "floor_id": "ground", "icon": "mdi:silverware-fork-knife"],
            ["area_id": "loft", "name": "Loft"]
        ])))

        #expect(entries.count == 2)
        #expect(entries[0].areaId == "kitchen")
        #expect(entries[0].floorId == "ground")
        #expect(entries[0].icon == "mdi:silverware-fork-knife")
        #expect(entries[1].floorId == nil)
        #expect(entries[1].icon == nil)
    }

    /// `AreaSortOrderResolver` reads this order positionally, so decoding must not reorder.
    @Test func areaDecodeList_preservesRegistryOrder() throws {
        let entries = try #require(AreaRegistryEntry.decodeList(HAData(value: [
            ["area_id": "c", "name": "C"], ["area_id": "a", "name": "A"], ["area_id": "b", "name": "B"]
        ])))

        #expect(entries.map(\.areaId) == ["c", "a", "b"])
    }

    @Test func areaDecodeList_skipsEntriesWithoutAreaId() throws {
        let entries = try #require(AreaRegistryEntry.decodeList(HAData(value: [
            ["name": "No id here"],
            ["area_id": "kitchen", "name": "Kitchen"]
        ])))

        #expect(entries.map(\.areaId) == ["kitchen"])
    }

    /// A nameless area would render as an untitled row.
    @Test func areaDecodeList_skipsEntriesWithoutName() throws {
        let entries = try #require(AreaRegistryEntry.decodeList(HAData(value: [
            ["area_id": "nameless"],
            ["area_id": "kitchen", "name": "Kitchen"]
        ])))

        #expect(entries.map(\.areaId) == ["kitchen"])
    }

    @Test func areaDecodeList_nonListResponse_isFailureNotEmpty() {
        #expect(AreaRegistryEntry.decodeList(HAData(value: ["error": "nope"])) == nil)
    }

    // MARK: - Floor Registry

    @Test func floorDecodeList_decodesLevel() throws {
        let entries = try #require(FloorRegistryEntry.decodeList(HAData(value: [
            ["floor_id": "ground", "name": "Ground Floor", "level": 0],
            ["floor_id": "attic", "name": "Attic"]
        ])))

        #expect(entries.count == 2)
        #expect(entries[0].level == 0)
        #expect(entries[1].name == "Attic")
        #expect(entries[1].level == nil)
    }

    /// A nameless floor would render as an untitled row.
    @Test func floorDecodeList_skipsEntriesMissingIdOrName() throws {
        let entries = try #require(FloorRegistryEntry.decodeList(HAData(value: [
            ["floor_id": "no-name"],
            ["name": "No id"],
            ["floor_id": "ground", "name": "Ground Floor"]
        ])))

        #expect(entries.map(\.floorId) == ["ground"])
    }

    /// Plenty of installs define no floors; that must stay distinct from a failure.
    @Test func floorDecodeList_emptyList_decodesAsNoFloors() throws {
        let entries = try #require(FloorRegistryEntry.decodeList(HAData(value: [])))

        #expect(entries.isEmpty)
    }

    /// Regression: a non-list response decoded as `[]`, deleting every stored `FloorEntity`.
    @Test func floorDecodeList_nonListResponse_isFailureNotEmpty() {
        #expect(FloorRegistryEntry.decodeList(HAData(value: ["error": "unknown_command"])) == nil)
    }

    // MARK: - Entity Registry

    @Test func entitySnapshot_decodesDeviceMappings() throws {
        let snapshot = try #require(EntityRegistrySnapshot.decode(HAData(value: [
            ["entity_id": "light.lamp", "device_id": "dev-1"],
            ["entity_id": "light.orphan"]
        ])))

        #expect(snapshot.deviceMappings.count == 1)
        #expect(snapshot.deviceMappings[0].entityId == "light.lamp")
        #expect(snapshot.deviceMappings[0].deviceId == "dev-1")
    }

    /// `hidden_by` carries *who* hid it; any non-null value means hidden.
    @Test func entitySnapshot_treatsAnyHiddenByValueAsHidden() throws {
        let snapshot = try #require(EntityRegistrySnapshot.decode(HAData(value: [
            ["entity_id": "light.by_user", "hidden_by": "user"],
            ["entity_id": "light.by_integration", "hidden_by": "integration"],
            ["entity_id": "light.visible", "hidden_by": NSNull()],
            ["entity_id": "light.no_key"]
        ])))

        #expect(snapshot.hiddenEntityIds == ["light.by_user", "light.by_integration"])
    }

    /// An entity's own area overrides the one it would inherit from its device.
    @Test func entitySnapshot_decodesEntityAreaIds() throws {
        let snapshot = try #require(EntityRegistrySnapshot.decode(HAData(value: [
            ["entity_id": "light.lamp", "area_id": "kitchen"],
            ["entity_id": "light.other"]
        ])))

        #expect(snapshot.entityAreaIds == ["light.lamp": "kitchen"])
    }

    /// `nil` suppresses `applyHAHidden`; an empty snapshot clears it. Never collapse the two.
    @Test func entitySnapshot_nonListResponse_isFailureNotEmptySnapshot() {
        #expect(EntityRegistrySnapshot.decode(HAData(value: ["error": "nope"])) == nil)
    }

    @Test func entitySnapshot_listWithNothingHidden_decodesAsEmptySet() throws {
        let snapshot = try #require(EntityRegistrySnapshot.decode(HAData(value: [
            ["entity_id": "light.lamp"]
        ])))

        #expect(snapshot.hiddenEntityIds.isEmpty)
    }

    // MARK: - Device Registry

    /// Device entries key the id as `id`; an entity inherits this area when it has none of its own.
    @Test func deviceDecodeList_readsIdAndArea() throws {
        let entries = try #require(DeviceRegistryEntry.decodeList(HAData(value: [
            ["id": "dev-1", "area_id": "kitchen"],
            ["id": "dev-2"]
        ])))

        #expect(entries.count == 2)
        #expect(entries[0].deviceId == "dev-1")
        #expect(entries[0].areaId == "kitchen")
        #expect(entries[1].areaId == nil)
    }

    @Test func deviceDecodeList_skipsEntriesWithoutId() throws {
        let entries = try #require(DeviceRegistryEntry.decodeList(HAData(value: [
            ["area_id": "kitchen"],
            ["id": "dev-1"]
        ])))

        #expect(entries.map(\.deviceId) == ["dev-1"])
    }

    /// An empty device registry and a failed fetch mean different things to the sync.
    @Test func deviceDecodeList_nonListResponse_isFailureNotEmpty() {
        #expect(DeviceRegistryEntry.decodeList(HAData(value: ["error": "nope"])) == nil)
    }
}
