import SwiftData
import SwiftUI

/// Aggregates the eight unassigned-by-domain `@Query` results used by both
/// the Areas grid (presence check) and the unassigned detail view
/// (entity-ID list). Keeping the predicates in one place avoids drift.
struct UnassignedEntities<Content: View>: View {

    @Query(filter: #Predicate<LightEntity> { $0.area == nil && $0.isAvailable == true }, sort: \LightEntity.entityId)
    private var lights: [LightEntity]
    @Query(filter: #Predicate<CoverEntity> { $0.area == nil && $0.isAvailable == true }, sort: \CoverEntity.entityId)
    private var covers: [CoverEntity]
    @Query(filter: #Predicate<SceneEntity> { $0.area == nil && $0.isAvailable == true }, sort: \SceneEntity.entityId)
    private var scenes: [SceneEntity]
    @Query(filter: #Predicate<SwitchEntity> { $0.area == nil && $0.isAvailable == true }, sort: \SwitchEntity.entityId)
    private var switches: [SwitchEntity]
    @Query(filter: #Predicate<ButtonEntity> { $0.area == nil && $0.isAvailable == true }, sort: \ButtonEntity.entityId)
    private var buttons: [ButtonEntity]
    @Query(filter: #Predicate<AutomationEntity> { $0.area == nil && $0.isAvailable == true }, sort: \AutomationEntity.entityId)
    private var automations: [AutomationEntity]
    @Query(filter: #Predicate<BinarySensorEntity> { $0.area == nil && $0.isAvailable == true }, sort: \BinarySensorEntity.entityId)
    private var binarySensors: [BinarySensorEntity]
    @Query(filter: #Predicate<ClimateEntity> { $0.area == nil && $0.isAvailable == true }, sort: \ClimateEntity.entityId)
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
    let switches: [SwitchEntity]
    let buttons: [ButtonEntity]
    let automations: [AutomationEntity]
    let binarySensors: [BinarySensorEntity]
    let climates: [ClimateEntity]

    /// Whether the virtual "Other" area should appear in the Areas list.
    /// Discounts user-hidden entities — an all-hidden Other area is dropped —
    /// while `entityIds` still carries hidden entities so Show/Hide mode can
    /// reveal them in the detail grid.
    var hasAny: Bool {
        lights.contains { !$0.isHidden }
            || covers.contains { !$0.isHidden }
            || scenes.contains { !$0.isHidden }
            || switches.contains { !$0.isHidden }
            || buttons.contains { !$0.isHidden }
            || automations.contains { !$0.isHidden }
            || binarySensors.contains { !$0.isHidden }
            || climates.contains { !$0.isHidden }
    }

    var entityIds: [String] {
        var ids: [String] = []
        ids += lights.map(\.entityId)
        ids += covers.map(\.entityId)
        ids += scenes.map(\.entityId)
        ids += switches.map(\.entityId)
        ids += buttons.map(\.entityId)
        ids += automations.map(\.entityId)
        ids += binarySensors.map(\.entityId)
        ids += climates.map(\.entityId)
        return ids
    }
}
