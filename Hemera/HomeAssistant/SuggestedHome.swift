import Foundation
import TileGridEngine

/// The tiles an onboarding login puts on Home, chosen from synced data only (docs/adr/0005).
enum SuggestedHome {

    struct Tile: Equatable {
        let entityId: String
        let size: TileSize
    }

    static let target = 12
    static let maxActions = 3
    static let maxMedium = 4

    private struct Candidate {
        let entityId: String
        let name: String
        let device: String
        let canBeMedium: Bool

        init(_ entity: some StoredEntity, canBeMedium: Bool = false) {
            entityId = entity.entityId
            name = entity.name
            device = entity.deviceId ?? entity.entityId
            self.canBeMedium = canBeMedium
        }
    }

    /// `states` maps entity id to Home Assistant's raw state string, as the sync fetched it.
    static func tiles(areas: [AreaEntity], states: [String: String], registry: EntityRegistrySnapshot) -> [Tile] {
        let areas = areas.sorted { $0.sortOrder < $1.sortOrder }

        // Scene and button state is the last press, so unknown only means never pressed.
        func isSuggestable(_ entityId: String, unknownIsNormal: Bool = false) -> Bool {
            guard !registry.hiddenEntityIds.contains(entityId),
                  !registry.disabledEntityIds.contains(entityId),
                  !registry.categorizedEntityIds.contains(entityId),
                  let state = states[entityId]
            else { return false }
            return state != "unavailable" && (unknownIsNormal || state != "unknown")
        }

        let switchesPerDevice = Dictionary(
            grouping: areas.flatMap(\.switches).filter { isSuggestable($0.entityId) },
            by: { $0.deviceId ?? $0.entityId }
        ).mapValues(\.count)

        // One list per kind, in kind order: light, climate, cover, switch, vacuum, action.
        func kinds(in area: AreaEntity) -> [[Candidate]] {
            let lights = area.lights.filter { isSuggestable($0.entityId) }.map { light in
                // Same rule as `LightCardViewModel.isDimmable`.
                Candidate(light, canBeMedium: light.supportedColorModes.map { Set($0) != ["onoff"] } ?? true)
            }
            let climates = area.climates.filter { isSuggestable($0.entityId) }.map { Candidate($0) }
            let covers = area.covers.filter { isSuggestable($0.entityId) }.map {
                Candidate($0, canBeMedium: $0.currentPosition != nil)
            }
            let switches = area.switches.filter {
                isSuggestable($0.entityId) && ($0.deviceClass == .outlet
                    || registry.mainEntityIds.contains($0.entityId)
                    || switchesPerDevice[$0.deviceId ?? $0.entityId] == 1)
            }.map { Candidate($0) }
            let vacuums = area.vacuums.filter { isSuggestable($0.entityId) }.map { Candidate($0) }
            let scenes = area.scenes.filter { isSuggestable($0.entityId, unknownIsNormal: true) }.map { Candidate($0) }
            let scripts = area.scripts.filter { isSuggestable($0.entityId) }.map { Candidate($0) }
            let buttons = area.buttons.filter {
                isSuggestable($0.entityId, unknownIsNormal: true)
                    && ($0.deviceId == nil || registry.mainEntityIds.contains($0.entityId))
            }.map { Candidate($0) }

            return [lights, climates, covers, switches, vacuums, scenes + scripts + buttons].map {
                $0.sorted { ($0.name, $0.entityId) < ($1.name, $1.entityId) }
            }
        }

        let perArea = areas.map(kinds(in:))
        let actionKind = 5
        // Within a kind, the first of every area, then the second of every area, and so on.
        var queues = (0...actionKind).map { kind in
            let lists = perArea.map { $0[kind] }
            let longest = lists.map(\.count).max() ?? 0
            return (0..<longest).flatMap { index in lists.compactMap { index < $0.count ? $0[index] : nil } }
        }

        var picked: [Candidate] = []
        var usedDevices: Set<String> = []
        var actions = 0
        while picked.count < target, queues.contains(where: { !$0.isEmpty }) {
            for kind in queues.indices where picked.count < target {
                if kind == actionKind, actions == maxActions {
                    queues[kind] = []
                    continue
                }
                while !queues[kind].isEmpty {
                    let next = queues[kind].removeFirst()
                    guard usedDevices.insert(next.device).inserted else { continue }
                    if kind == actionKind { actions += 1 }
                    picked.append(next)
                    break
                }
            }
        }

        var mediumLeft = maxMedium
        return picked.map { candidate in
            guard candidate.canBeMedium, mediumLeft > 0 else { return Tile(entityId: candidate.entityId, size: .small) }
            mediumLeft -= 1
            return Tile(entityId: candidate.entityId, size: .medium)
        }
    }
}
