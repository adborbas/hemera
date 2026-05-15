import SwiftData
import HAKit
import Foundation

@Model
final class AutomationEntity: StoredEntity {

    static let domain = "automation"

    @Attribute(.unique) var entityId: String
    var name: String
    var state: State
    var lastTriggered: Date?
    var icon: String?
    var deviceId: String?
    var isAvailable: Bool = true
    var area: AreaEntity?

    var isOn: Bool { state == .on }

    convenience init(entityId: String) {
        self.init(entityId: entityId, name: "", state: .unknown)
    }

    init(
        entityId: String,
        name: String,
        state: State,
        lastTriggered: Date? = nil,
        icon: String? = nil
    ) {
        self.entityId = entityId
        self.name = name
        self.state = state
        self.lastTriggered = lastTriggered
        self.icon = icon
    }

    func update(from entity: HAEntity) {
        entityId = entity.entityId
        name = entity.attributes["friendly_name"] as? String ?? entityId
        state = State(rawValue: entity.state) ?? .unknown

        if let dateString = entity.attributes["last_triggered"] as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            lastTriggered = formatter.date(from: dateString)
        }
        icon = entity.attributes["icon"] as? String
    }
}

// MARK: - StoredEntity

extension AutomationEntity {
    static func entityIdPredicate(_ id: String) -> Predicate<AutomationEntity> {
        #Predicate { $0.entityId == id }
    }

    static var unassignedPredicate: Predicate<AutomationEntity> {
        #Predicate { $0.area == nil && $0.isAvailable == true }
    }
}

// MARK: - Types

extension AutomationEntity {
    enum State: String, Codable, CaseIterable, Identifiable {
        case on
        case off
        case unknown
        case unavailable

        var id: String { rawValue }
    }
}
