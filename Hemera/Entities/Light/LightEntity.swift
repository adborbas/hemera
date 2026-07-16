import SwiftData
import HAKit
import Foundation

@Model
final class LightEntity: StoredEntity {

    static let domain = "light"

@Attribute(.unique) var entityId: String
    var name: String
    var state: State
    var brightness: Int?
    var colorMode: String?
    var colorTemp: Int?
    var hsColor: [Double]?
    var minMireds: Int?
    var maxMireds: Int?
    var offBrightness: Int?
    var offWithTransition: Bool?
    var supportedColorModes: [String]?
    var supportedFeaturesRaw: Int
    var icon: String?
    var isOn: Bool { state == .on }
    var deviceId: String?
    var isAvailable: Bool = true
    var area: AreaEntity?

    convenience init(entityId: String) {
        self.init(entityId: entityId, name: "", state: .unknown)
    }

    init(
        entityId: String,
        name: String,
        state: State,
        brightness: Int? = nil,
        colorMode: String? = nil,
        colorTemp: Int? = nil,
        hsColor: [Double]? = nil,
        minMireds: Int? = nil,
        maxMireds: Int? = nil,
        offBrightness: Int? = nil,
        offWithTransition: Bool? = nil,
        supportedColorModes: [String]? = nil,
        supportedFeaturesRaw: Int = 0,
        icon: String? = nil
    ) {
        self.entityId = entityId
        self.name = name
        self.state = state
        self.brightness = brightness
        self.colorMode = colorMode
        self.colorTemp = colorTemp
        self.hsColor = hsColor
        self.minMireds = minMireds
        self.maxMireds = maxMireds
        self.offBrightness = offBrightness
        self.offWithTransition = offWithTransition
        self.supportedColorModes = supportedColorModes
        self.supportedFeaturesRaw = supportedFeaturesRaw
        self.icon = icon
    }


    static func empty() -> LightEntity {
        return LightEntity(
            entityId: "",
            name: "",
            state: .unknown
        )
    }

    func update(from entity: HAEntity) {
        entityId = entity.entityId
        name = entity.attributes["friendly_name"] as? String ?? entityId
        state = State(rawValue: entity.state) ?? .unknown
        brightness = entity.attributes["brightness"] as? Int
        colorMode = entity.attributes["color_mode"] as? String
        colorTemp = entity.attributes["color_temp"] as? Int
        if let hs = entity.attributes["hs_color"] as? [Any] {
            hsColor = hs.compactMap { ($0 as? NSNumber)?.doubleValue }
            if hsColor?.count != 2 { hsColor = nil }
        } else {
            hsColor = nil
        }
        let rawMinMireds = entity.attributes["min_mireds"] as? Int
        let rawMaxMireds = entity.attributes["max_mireds"] as? Int
        if let lo = rawMinMireds, let hi = rawMaxMireds {
            minMireds = Swift.min(lo, hi)
            maxMireds = Swift.max(lo, hi)
        } else {
            minMireds = rawMinMireds
            maxMireds = rawMaxMireds
        }
        offBrightness = entity.attributes["off_brightness"] as? Int
        offWithTransition = entity.attributes["off_with_transition"] as? Bool
        supportedColorModes = entity.attributes["supported_color_modes"] as? [String]
        supportedFeaturesRaw = entity.attributes["supported_features"] as? Int ?? 0
        icon = entity.attributes["icon"] as? String
    }
}

// MARK: - StoredEntity

extension LightEntity {
    static func entityIdPredicate(_ id: String) -> Predicate<LightEntity> {
        #Predicate { $0.entityId == id }
    }

    static var unassignedPredicate: Predicate<LightEntity> {
        #Predicate { $0.area == nil && $0.isAvailable == true }
    }
}

// MARK: - State

extension LightEntity {
    enum State: String, Codable, CaseIterable, Identifiable {
        case on
        case off
        case unknown
        case unavailable

        var id: String { rawValue }
    }
}
