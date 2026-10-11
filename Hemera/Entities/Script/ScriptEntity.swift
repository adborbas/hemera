import SwiftData
import HAKit
import Foundation

@Model
final class ScriptEntity: StoredEntity {

    static let domain = "script"

    @Attribute(.unique) var entityId: String
    var name: String
    /// HA reports `on` while the script's sequence is executing, `off` when idle.
    var state: State = State.off
    var icon: String?
    var deviceId: String?
    var isAvailable: Bool = true
    var area: AreaEntity?

    var isRunning: Bool { state == .on }

    convenience init(entityId: String) {
        self.init(entityId: entityId, name: "")
    }

    init(entityId: String, name: String, state: State = .off, icon: String? = nil) {
        self.entityId = entityId
        self.name = name
        self.state = state
        self.icon = icon
    }

    func update(from entity: HAEntity) {
        entityId = entity.entityId
        name = entity.attributes["friendly_name"] as? String ?? entityId
        state = State(rawValue: entity.state) ?? .unknown
        icon = entity.attributes["icon"] as? String
    }
}

// MARK: - Types

extension ScriptEntity {
    enum State: String, Codable, CaseIterable, Identifiable {
        case on
        case off
        case unknown
        case unavailable

        var id: String { rawValue }
    }
}

// MARK: - StoredEntity

extension ScriptEntity {
    static func entityIdPredicate(_ id: String) -> Predicate<ScriptEntity> {
        #Predicate { $0.entityId == id }
    }

    static var unassignedPredicate: Predicate<ScriptEntity> {
        #Predicate { $0.area == nil && $0.isAvailable == true }
    }
}
