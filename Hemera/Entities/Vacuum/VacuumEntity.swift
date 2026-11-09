import SwiftData
import HAKit
import Foundation

@Model
final class VacuumEntity: StoredEntity {

    static let domain = "vacuum"

    @Attribute(.unique) var entityId: String
    var name: String
    var state: State
    private var supportedFeaturesRaw: Int
    var icon: String?
    var deviceId: String?
    var isAvailable: Bool = true
    var isHidden: Bool = false
    var isHiddenInHA: Bool = false
    var area: AreaEntity?

    var supportedFeatures: Features {
        get { Features(rawValue: supportedFeaturesRaw) }
        set { supportedFeaturesRaw = newValue.rawValue }
    }

    convenience init(entityId: String) {
        self.init(entityId: entityId, name: "", state: .unknown)
    }

    init(
        entityId: String,
        name: String,
        state: State,
        supportedFeaturesRaw: Int = 0,
        icon: String? = nil
    ) {
        self.entityId = entityId
        self.name = name
        self.state = state
        self.supportedFeaturesRaw = supportedFeaturesRaw
        self.icon = icon
    }

    // MARK: - Updates from network

    func update(from entity: HAEntity) {
        entityId = entity.entityId
        name = entity.attributes["friendly_name"] as? String ?? entityId
        state = State(rawValue: entity.state) ?? .unknown
        supportedFeaturesRaw = entity.attributes["supported_features"] as? Int ?? 0
        icon = entity.attributes["icon"] as? String
    }
}

// MARK: - StoredEntity

extension VacuumEntity {
    static func entityIdPredicate(_ id: String) -> Predicate<VacuumEntity> {
        #Predicate { $0.entityId == id }
    }
}

// MARK: - Types

extension VacuumEntity {
    enum State: String, Codable, CaseIterable, Identifiable {
        case cleaning, docked, idle, paused, returning, error, unknown, unavailable

        var id: String { rawValue }
    }

    struct Features: OptionSet, Decodable {
        let rawValue: Int

        static let pause = Features(rawValue: 1 << 2) // 4
        static let stop = Features(rawValue: 1 << 3) // 8
        static let returnHome = Features(rawValue: 1 << 4) // 16
        static let locate = Features(rawValue: 1 << 9) // 512
        static let start = Features(rawValue: 1 << 13) // 8192
    }
}
