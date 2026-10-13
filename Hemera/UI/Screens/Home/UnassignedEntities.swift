import SwiftData
import SwiftUI

/// Aggregates the nine unassigned-by-domain `@Query` results used by both
/// the Areas grid (presence check) and the unassigned detail view
/// (entity-ID list). Keeping the predicates in one place avoids drift.
struct UnassignedEntities<Content: View>: View {

    @Query(filter: #Predicate<LightEntity> { $0.area == nil && $0.isAvailable == true && $0.isHiddenInHA == false }, sort: \LightEntity.entityId)
    private var lights: [LightEntity]
    @Query(filter: #Predicate<CoverEntity> { $0.area == nil && $0.isAvailable == true && $0.isHiddenInHA == false }, sort: \CoverEntity.entityId)
    private var covers: [CoverEntity]
    @Query(filter: #Predicate<SceneEntity> { $0.area == nil && $0.isAvailable == true && $0.isHiddenInHA == false }, sort: \SceneEntity.entityId)
    private var scenes: [SceneEntity]
    @Query(filter: #Predicate<ScriptEntity> { $0.area == nil && $0.isAvailable == true && $0.isHiddenInHA == false }, sort: \ScriptEntity.entityId)
    private var scripts: [ScriptEntity]
    @Query(filter: #Predicate<SwitchEntity> { $0.area == nil && $0.isAvailable == true && $0.isHiddenInHA == false }, sort: \SwitchEntity.entityId)
    private var switches: [SwitchEntity]
    @Query(filter: #Predicate<ButtonEntity> { $0.area == nil && $0.isAvailable == true && $0.isHiddenInHA == false }, sort: \ButtonEntity.entityId)
    private var buttons: [ButtonEntity]
    @Query(filter: #Predicate<AutomationEntity> { $0.area == nil && $0.isAvailable == true && $0.isHiddenInHA == false }, sort: \AutomationEntity.entityId)
    private var automations: [AutomationEntity]
    @Query(filter: #Predicate<BinarySensorEntity> { $0.area == nil && $0.isAvailable == true && $0.isHiddenInHA == false }, sort: \BinarySensorEntity.entityId)
    private var binarySensors: [BinarySensorEntity]
    @Query(filter: #Predicate<ClimateEntity> { $0.area == nil && $0.isAvailable == true && $0.isHiddenInHA == false }, sort: \ClimateEntity.entityId)
    private var climates: [ClimateEntity]

    let content: (UnassignedEntitiesSummary) -> Content

    init(@ViewBuilder content: @escaping (UnassignedEntitiesSummary) -> Content) {
        self.content = content
    }

    var body: some View {
        content(
            UnassignedEntitiesSummary(
                lights: lights,
                covers: covers,
                scenes: scenes,
                scripts: scripts,
                switches: switches,
                buttons: buttons,
                automations: automations,
                binarySensors: binarySensors,
                climates: climates
            )
        )
    }
}

struct UnassignedEntitiesSummary {
    let lights: [LightEntity]
    let covers: [CoverEntity]
    let scenes: [SceneEntity]
    let scripts: [ScriptEntity]
    let switches: [SwitchEntity]
    let buttons: [ButtonEntity]
    let automations: [AutomationEntity]
    let binarySensors: [BinarySensorEntity]
    let climates: [ClimateEntity]

    /**
     Whether the virtual "Other" area has any entities at all. It stays in the
     Areas list even when every entity is hidden, so the all-items-hidden
     placeholder can offer a way back into Show/Hide mode. `entityIds` likewise
     carries hidden entities so Show/Hide mode can reveal them.
    */
    var hasAny: Bool {
        !lights.isEmpty
            || !covers.isEmpty
            || !scenes.isEmpty
            || !scripts.isEmpty
            || !switches.isEmpty
            || !buttons.isEmpty
            || !automations.isEmpty
            || !binarySensors.isEmpty
            || !climates.isEmpty
    }

    /// Whether any unassigned entity is hidden — drives the all-items-hidden placeholder.
    var hasHidden: Bool {
        lights.contains { $0.isHidden }
            || covers.contains { $0.isHidden }
            || scenes.contains { $0.isHidden }
            || scripts.contains { $0.isHidden }
            || switches.contains { $0.isHidden }
            || buttons.contains { $0.isHidden }
            || automations.contains { $0.isHidden }
            || binarySensors.contains { $0.isHidden }
            || climates.contains { $0.isHidden }
    }

    var entityIds: [String] {
        var ids: [String] = []
        ids += lights.map(\.entityId)
        ids += covers.map(\.entityId)
        ids += scenes.map(\.entityId)
        ids += scripts.map(\.entityId)
        ids += switches.map(\.entityId)
        ids += buttons.map(\.entityId)
        ids += automations.map(\.entityId)
        ids += binarySensors.map(\.entityId)
        ids += climates.map(\.entityId)
        return ids
    }
}
