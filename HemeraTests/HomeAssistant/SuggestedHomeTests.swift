import Foundation
import HAKit
import SwiftData
import Testing
import TileGridEngine
@testable import Hemera

/// The Suggested Home is a new user's first look at Home, so each rule protects that first impression.
@MainActor
struct SuggestedHomeTests {

    private let home = TestHome()

    // MARK: - Order

    @Test func tiles_takeOneEntityPerKindPerRound_inKindOrder() {
        let area = home.area("living", order: 0)
        home.add(SceneEntity(entityId: "scene.a"), in: area, state: "unknown")
        home.add(VacuumEntity(entityId: "vacuum.a"), in: area, state: "docked")
        home.add(SwitchEntity(entityId: "switch.a"), in: area)
        home.add(CoverEntity(entityId: "cover.a"), in: area, state: "open")
        home.add(CoverEntity(entityId: "cover.b"), in: area, state: "open")
        home.add(ClimateEntity(entityId: "climate.a"), in: area, state: "heat")
        home.add(LightEntity(entityId: "light.a"), in: area)
        home.add(LightEntity(entityId: "light.b"), in: area)

        #expect(home.suggestedIds == [
            "light.a", "climate.a", "cover.a", "switch.a", "vacuum.a", "scene.a",
            "light.b", "cover.b"
        ])
    }

    /// A kind spans the house before it repeats an area, in area order rather than the order areas were stored.
    @Test func tiles_interleaveAreasWithinAKind() {
        let kitchen = home.area("kitchen", order: 1)
        let bedroom = home.area("bedroom", order: 0)
        home.add(LightEntity(entityId: "light.kitchen_a"), in: kitchen)
        home.add(LightEntity(entityId: "light.kitchen_b"), in: kitchen)
        home.add(LightEntity(entityId: "light.bedroom_a"), in: bedroom)

        #expect(home.suggestedIds == ["light.bedroom_a", "light.kitchen_a", "light.kitchen_b"])
    }

    @Test func tiles_takeAtMostOneTilePerDevice() {
        let area = home.area("living", order: 0)
        home.add(LightEntity(entityId: "light.lamp"), in: area, device: "lamp")
        home.add(SwitchEntity(entityId: "switch.lamp_power"), in: area, device: "lamp")
        home.add(LightEntity(entityId: "light.lamp_night"), in: area, device: "lamp")

        #expect(home.suggestedIds == ["light.lamp"])
    }

    @Test func tiles_neverChooseEntitiesWithoutAnArea() {
        let area = home.area("living", order: 0)
        home.add(LightEntity(entityId: "light.placed"), in: area)
        home.add(LightEntity(entityId: "light.group"), in: nil)

        #expect(home.suggestedIds == ["light.placed"])
    }

    // MARK: - Switches

    @Test func switch_secondaryOnAMultiSwitchDevice_isLeftOut() {
        let area = home.area("living", order: 0)
        home.add(SwitchEntity(entityId: "switch.ac_turbo"), in: area, device: "ac")
        home.add(SwitchEntity(entityId: "switch.ac_quiet"), in: area, device: "ac")

        #expect(home.suggestedIds.isEmpty)
    }

    @Test func switch_outlet_isKeptOnAMultiSwitchDevice() {
        let area = home.area("living", order: 0)
        home.add(SwitchEntity(entityId: "switch.plug_led"), in: area, device: "plug")
        home.add(SwitchEntity(entityId: "switch.plug", name: "", state: .on, deviceClass: .outlet), in: area, device: "plug")

        #expect(home.suggestedIds == ["switch.plug"])
    }

    @Test func switch_mainEntity_isKeptOnAMultiSwitchDevice() {
        let area = home.area("living", order: 0)
        home.add(SwitchEntity(entityId: "switch.relay_child_lock"), in: area, device: "relay")
        home.add(SwitchEntity(entityId: "switch.relay"), in: area, device: "relay", registry: ["original_name": NSNull()])

        #expect(home.suggestedIds == ["switch.relay"])
    }

    @Test func switch_onlySwitchOnItsDevice_isKept() {
        let area = home.area("living", order: 0)
        home.add(SwitchEntity(entityId: "switch.heater"), in: area, device: "heater")
        // Excluded switches don't make a device multi-switch.
        home.add(SwitchEntity(entityId: "switch.heater_led"), in: area, device: "heater",
                 registry: ["entity_category": "config"])

        #expect(home.suggestedIds == ["switch.heater"])
    }

    // MARK: - Buttons

    @Test func button_withoutDevice_isKept() {
        let area = home.area("living", order: 0)
        home.add(ButtonEntity(entityId: "button.doorbell"), in: area, state: "unknown")

        #expect(home.suggestedIds == ["button.doorbell"])
    }

    @Test func button_onDeviceButNotItsMainEntity_isLeftOut() {
        let area = home.area("living", order: 0)
        home.add(ButtonEntity(entityId: "button.blind_identify"), in: area, device: "blind", state: "unknown")

        #expect(home.suggestedIds.isEmpty)
    }

    @Test func button_mainEntityOfItsDevice_isKept() {
        let area = home.area("living", order: 0)
        home.add(ButtonEntity(entityId: "button.gate"), in: area, device: "gate", state: "unknown",
                 registry: ["original_name": NSNull()])

        #expect(home.suggestedIds == ["button.gate"])
    }

    // MARK: - Actions

    @Test func actions_areCappedAtThreeAcrossScenesScriptsAndButtons() {
        let area = home.area("living", order: 0)
        home.add(SceneEntity(entityId: "scene.a"), in: area, state: "unknown")
        home.add(SceneEntity(entityId: "scene.b"), in: area, state: "unknown")
        home.add(ScriptEntity(entityId: "script.c"), in: area, state: "off")
        home.add(ButtonEntity(entityId: "button.d"), in: area, state: "unknown")
        home.add(LightEntity(entityId: "light.a"), in: area)
        home.add(LightEntity(entityId: "light.b"), in: area)
        home.add(LightEntity(entityId: "light.c"), in: area)
        home.add(LightEntity(entityId: "light.d"), in: area)

        let ids = home.suggestedIds
        #expect(ids.filter { !$0.hasPrefix("light.") } == ["button.d", "scene.a", "scene.b"])
        #expect(ids.filter { $0.hasPrefix("light.") }.count == 4)
    }

    // MARK: - Exclusions

    @Test(arguments: [
        ["hidden_by": "user"],
        ["disabled_by": "integration"],
        ["entity_category": "config"],
        ["entity_category": "diagnostic"]
    ] as [[String: String]])
    func registryFlag_leavesTheEntityOut(_ flag: [String: String]) {
        let area = home.area("living", order: 0)
        home.add(LightEntity(entityId: "light.flagged"), in: area, registry: flag)
        home.add(LightEntity(entityId: "light.plain"), in: area)

        #expect(home.suggestedIds == ["light.plain"])
    }

    @Test(arguments: ["unavailable", "unknown"])
    func unusableState_leavesTheEntityOut(_ state: String) {
        let area = home.area("living", order: 0)
        home.add(LightEntity(entityId: "light.broken"), in: area, state: state)
        home.add(ScriptEntity(entityId: "script.broken"), in: area, state: state)
        home.add(LightEntity(entityId: "light.plain"), in: area)

        #expect(home.suggestedIds == ["light.plain"])
    }

    /// A scene or button reports when it was last pressed, so unknown means never pressed, not broken.
    @Test func unknownState_keepsScenesAndButtons() {
        let area = home.area("living", order: 0)
        home.add(SceneEntity(entityId: "scene.never_run"), in: area, state: "unknown")
        home.add(ButtonEntity(entityId: "button.never_pressed"), in: area, state: "unknown")

        #expect(Set(home.suggestedIds) == ["scene.never_run", "button.never_pressed"])
    }

    @Test func unavailableState_leavesScenesAndButtonsOut() {
        let area = home.area("living", order: 0)
        home.add(SceneEntity(entityId: "scene.gone"), in: area, state: "unavailable")
        home.add(ButtonEntity(entityId: "button.gone"), in: area, state: "unavailable")

        #expect(home.suggestedIds.isEmpty)
    }

    @Test func entityMissingFromTheSync_isLeftOut() {
        let area = home.area("living", order: 0)
        home.add(LightEntity(entityId: "light.stale"), in: area, state: nil)

        #expect(home.suggestedIds.isEmpty)
    }

    @Test func sensorsBinarySensorsAndAutomations_areNeverSuggested() {
        let area = home.area("living", order: 0)
        home.add(SensorEntity(entityId: "sensor.temperature"), in: area, state: "21")
        home.add(BinarySensorEntity(entityId: "binary_sensor.door"), in: area)
        home.add(AutomationEntity(entityId: "automation.night"), in: area)

        #expect(home.suggestedIds.isEmpty)
    }

    // MARK: - Sizes

    @Test func sizes_dimmableLightsAndPositionedCoversAreMedium() {
        let area = home.area("living", order: 0)
        home.add(LightEntity(entityId: "light.dimmable", name: "", state: .on, supportedColorModes: ["brightness"]),
                 in: area)
        home.add(LightEntity(entityId: "light.onoff", name: "", state: .on, supportedColorModes: ["onoff"]),
                 in: area, device: "other")
        home.add(CoverEntity(entityId: "cover.positioned", name: "", state: .open, currentPosition: 40), in: area,
                 state: "open")
        home.add(CoverEntity(entityId: "cover.open_close"), in: area, state: "closed")
        home.add(ClimateEntity(entityId: "climate.ac"), in: area, state: "cool")

        #expect(home.suggested == [
            SuggestedHome.Tile(entityId: "light.dimmable", size: .medium),
            SuggestedHome.Tile(entityId: "climate.ac", size: .small),
            SuggestedHome.Tile(entityId: "cover.open_close", size: .small),
            SuggestedHome.Tile(entityId: "light.onoff", size: .small),
            SuggestedHome.Tile(entityId: "cover.positioned", size: .medium)
        ])
    }

    @Test func sizes_mediumIsCappedAtFourInResultOrder() {
        let area = home.area("living", order: 0)
        for index in 1...6 {
            home.add(LightEntity(entityId: "light.l\(index)", name: "", state: .on, supportedColorModes: ["brightness"]),
                     in: area)
        }

        #expect(home.suggested.map(\.size) == [.medium, .medium, .medium, .medium, .small, .small])
    }

    // MARK: - Target

    @Test func tiles_stopAtTheTargetWhenMoreAreAvailable() {
        let area = home.area("living", order: 0)
        for index in 10...25 {
            home.add(LightEntity(entityId: "light.l\(index)"), in: area)
        }

        #expect(home.suggestedIds.count == SuggestedHome.target)
        #expect(SuggestedHome.target == 12)
    }

    @Test func tiles_inASmallHome_returnEverythingThatQualifies() {
        let area = home.area("living", order: 0)
        home.add(LightEntity(entityId: "light.a"), in: area)
        home.add(CoverEntity(entityId: "cover.a"), in: area, state: "open")

        #expect(home.suggestedIds == ["light.a", "cover.a"])
    }

    @Test func tiles_withNothingThatQualifies_areEmpty() {
        home.area("living", order: 0)

        #expect(home.suggestedIds.isEmpty)
    }
}

// MARK: - Test Home

/// A Home Assistant setup in an in-memory store, with the states and registry entries a sync would fetch.
@MainActor
private final class TestHome {
    private let container: ModelContainer
    private var states: [String: String] = [:]
    private var registryEntries: [[String: Any]] = []

    init() {
        container = try! ModelContainer(
            for: AppEnvironment.createSchema(),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    var suggested: [SuggestedHome.Tile] {
        let areas = try! container.mainContext.fetch(FetchDescriptor<AreaEntity>())
        let registry = EntityRegistrySnapshot.decode(HAData(value: registryEntries))!
        return SuggestedHome.tiles(areas: areas, states: states, registry: registry)
    }

    var suggestedIds: [String] { suggested.map(\.entityId) }

    @discardableResult
    func area(_ id: String, order: Int) -> AreaEntity {
        let area = AreaEntity(areaId: id, name: id, sortOrder: order)
        container.mainContext.insert(area)
        return area
    }

    /// Registry entries carry an `original_name` unless `registry` overrides it, so no entity is a main one by default.
    func add(
        _ entity: some StoredEntity,
        in area: AreaEntity?,
        device: String? = nil,
        state: String? = "on",
        registry: [String: Any] = [:]
    ) {
        container.mainContext.insert(entity)
        entity.area = area
        entity.deviceId = device
        states[entity.entityId] = state
        var entry: [String: Any] = ["entity_id": entity.entityId, "original_name": "Own name"]
        entry.merge(registry) { $1 }
        registryEntries.append(entry)
    }
}
