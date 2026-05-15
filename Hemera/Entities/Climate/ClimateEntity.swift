import SwiftData
import HAKit
import Foundation

@Model
final class ClimateEntity: StoredEntity {

    static let domain = "climate"

    @Attribute(.unique) var entityId: String
    var name: String
    var state: HVACMode
    var hvacAction: HVACAction?
    var currentTemperature: Double?
    var temperature: Double?
    var targetTempHigh: Double?
    var targetTempLow: Double?
    var currentHumidity: Double?
    var humidity: Double?
    var minTemp: Double
    var maxTemp: Double
    var minHumidity: Double
    var maxHumidity: Double
    var targetTempStep: Double
    var hvacModesRaw: [String]
    var fanMode: String?
    var fanModesRaw: [String]?
    var swingMode: String?
    var swingModesRaw: [String]?
    var presetMode: String?
    var presetModesRaw: [String]?
    private var supportedFeaturesRaw: Int
    var icon: String?
    var deviceId: String?
    var isAvailable: Bool = true
    var area: AreaEntity?

    var supportedFeatures: SupportedFeatures {
        get { SupportedFeatures(rawValue: supportedFeaturesRaw) }
        set { supportedFeaturesRaw = newValue.rawValue }
    }

    convenience init(entityId: String) {
        self.init(entityId: entityId, name: "", state: .unknown)
    }

    init(
        entityId: String,
        name: String,
        state: HVACMode,
        hvacAction: HVACAction? = nil,
        currentTemperature: Double? = nil,
        temperature: Double? = nil,
        targetTempHigh: Double? = nil,
        targetTempLow: Double? = nil,
        currentHumidity: Double? = nil,
        humidity: Double? = nil,
        minTemp: Double = 7,
        maxTemp: Double = 35,
        minHumidity: Double = 30,
        maxHumidity: Double = 99,
        targetTempStep: Double = 0.5,
        hvacModesRaw: [String] = [],
        fanMode: String? = nil,
        fanModesRaw: [String]? = nil,
        swingMode: String? = nil,
        swingModesRaw: [String]? = nil,
        presetMode: String? = nil,
        presetModesRaw: [String]? = nil,
        supportedFeaturesRaw: Int = 0,
        icon: String? = nil
    ) {
        self.entityId = entityId
        self.name = name
        self.state = state
        self.hvacAction = hvacAction
        self.currentTemperature = currentTemperature
        self.temperature = temperature
        self.targetTempHigh = targetTempHigh
        self.targetTempLow = targetTempLow
        self.currentHumidity = currentHumidity
        self.humidity = humidity
        self.minTemp = minTemp
        self.maxTemp = maxTemp
        self.minHumidity = minHumidity
        self.maxHumidity = maxHumidity
        self.targetTempStep = targetTempStep
        self.hvacModesRaw = hvacModesRaw
        self.fanMode = fanMode
        self.fanModesRaw = fanModesRaw
        self.swingMode = swingMode
        self.swingModesRaw = swingModesRaw
        self.presetMode = presetMode
        self.presetModesRaw = presetModesRaw
        self.supportedFeaturesRaw = supportedFeaturesRaw
        self.icon = icon
    }

    // MARK: - Updates from network

    func update(from entity: HAEntity) {
        entityId = entity.entityId
        name = entity.attributes["friendly_name"] as? String ?? entityId
        state = HVACMode(rawValue: entity.state) ?? .unknown

        if let actionRaw = entity.attributes["hvac_action"] as? String {
            hvacAction = HVACAction(rawValue: actionRaw)
        } else {
            hvacAction = nil
        }

        currentTemperature = entity.attributes["current_temperature"] as? Double
        temperature = entity.attributes["temperature"] as? Double
        targetTempHigh = entity.attributes["target_temp_high"] as? Double
        targetTempLow = entity.attributes["target_temp_low"] as? Double
        currentHumidity = entity.attributes["current_humidity"] as? Double
        humidity = entity.attributes["humidity"] as? Double
        minTemp = entity.attributes["min_temp"] as? Double ?? 7
        maxTemp = entity.attributes["max_temp"] as? Double ?? 35
        minHumidity = entity.attributes["min_humidity"] as? Double ?? 30
        maxHumidity = entity.attributes["max_humidity"] as? Double ?? 99
        targetTempStep = entity.attributes["target_temp_step"] as? Double ?? 0.5
        hvacModesRaw = entity.attributes["hvac_modes"] as? [String] ?? []
        fanMode = entity.attributes["fan_mode"] as? String
        fanModesRaw = entity.attributes["fan_modes"] as? [String]
        swingMode = entity.attributes["swing_mode"] as? String
        swingModesRaw = entity.attributes["swing_modes"] as? [String]
        presetMode = entity.attributes["preset_mode"] as? String
        presetModesRaw = entity.attributes["preset_modes"] as? [String]
        supportedFeaturesRaw = entity.attributes["supported_features"] as? Int ?? 0
        icon = entity.attributes["icon"] as? String
    }
}

// MARK: - StoredEntity

extension ClimateEntity {
    static func entityIdPredicate(_ id: String) -> Predicate<ClimateEntity> {
        #Predicate { $0.entityId == id }
    }

    static var unassignedPredicate: Predicate<ClimateEntity> {
        #Predicate { $0.area == nil && $0.isAvailable == true }
    }
}

// MARK: - Types

extension ClimateEntity {
    enum HVACMode: String, Codable, CaseIterable, Identifiable {
        case off
        case heat
        case cool
        case heatCool = "heat_cool"
        case auto
        case dry
        case fanOnly = "fan_only"
        case unknown
        case unavailable

        var id: String { rawValue }
    }

    enum HVACAction: String, Codable, CaseIterable, Identifiable {
        case off
        case preheating
        case heating
        case cooling
        case drying
        case idle
        case fan
        case defrosting

        var id: String { rawValue }
    }

    struct SupportedFeatures: OptionSet, Sendable {
        let rawValue: Int

        static let targetTemperature = SupportedFeatures(rawValue: 1)
        static let targetTemperatureRange = SupportedFeatures(rawValue: 2)
        static let targetHumidity = SupportedFeatures(rawValue: 4)
        static let fanMode = SupportedFeatures(rawValue: 8)
        static let presetMode = SupportedFeatures(rawValue: 16)
        static let swingMode = SupportedFeatures(rawValue: 32)
        static let turnOff = SupportedFeatures(rawValue: 64)
        static let turnOn = SupportedFeatures(rawValue: 128)
    }
}
