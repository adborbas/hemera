import SwiftData
import HAKit
import Foundation

@Model
final class CoverEntity: StoredEntity {

    static let domain = "cover"

@Attribute(.unique) var entityId: String
    var name: String
    var state: State
    var currentPosition: Int?
    private var supportedFeaturesRaw: Int
    var deviceClass: DeviceClass
    var icon: String?
    var deviceId: String?
    var isAvailable: Bool = true
    var isHidden: Bool = false
    var isHiddenInHA: Bool = false
    var area: AreaEntity?
    var preferredControlMode: String?

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
        currentPosition: Int? = nil,
        supportedFeaturesRaw: Int = 0,
        deviceClass: DeviceClass = .unknown,
        icon: String? = nil
    ) {
        self.entityId = entityId
        self.name = name
        self.state = state
        self.currentPosition = currentPosition
        self.supportedFeaturesRaw = supportedFeaturesRaw
        self.deviceClass = deviceClass
        self.icon = icon
    }

    // MARK: - Updates from network

    /// Update this storage object from a network HAEntity.
    func update(from entity: HAEntity) {
        entityId = entity.entityId
        name = entity.attributes["friendly_name"] as? String ?? entityId
        state = State(rawValue: entity.state) ?? .unknown

        currentPosition = entity.attributes["current_position"] as? Int

        let deviceClassRaw = entity.attributes["device_class"] as? String
        deviceClass = DeviceClass(rawValue: deviceClassRaw ?? "") ?? .unknown

        supportedFeaturesRaw = entity.attributes["supported_features"] as? Int ?? 0
        icon = entity.attributes["icon"] as? String
    }
}

// MARK: - StoredEntity

extension CoverEntity {
    static func entityIdPredicate(_ id: String) -> Predicate<CoverEntity> {
        #Predicate { $0.entityId == id }
    }

    static var unassignedPredicate: Predicate<CoverEntity> {
        #Predicate { $0.area == nil && $0.isAvailable == true }
    }
}

// MARK: - Types

extension CoverEntity {
    enum DeviceClass: String, Codable, CaseIterable, Identifiable {
        case unknown
        case awning
        case blind
        case curtain
        case damper
        case door
        case garage
        case gate
        case shade
        case shutter
        case window

        var id: String { rawValue }
    }

    enum State: String, Codable, CaseIterable, Identifiable {
        case open, closed, opening, closing, unknown, unavailable

        var id: String { rawValue }
    }

    struct Features: OptionSet, Decodable {
        let rawValue: Int

        static let open = Features(rawValue: 1 << 0) // 1
        static let close = Features(rawValue: 1 << 1) // 2
        static let setPosition = Features(rawValue: 1 << 2) // 4
        static let stop = Features(rawValue: 1 << 3) // 8
    }
}
