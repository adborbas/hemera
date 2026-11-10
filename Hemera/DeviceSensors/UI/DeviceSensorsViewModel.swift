import Foundation
import SwiftData

/// Every sensor and binary sensor on one device, as the rows of its Sensors page.
@Observable
@MainActor
final class DeviceSensorsViewModel {

    struct Row: Identifiable {
        let id: String
        let name: String
        let icon: String?
        let value: String
        let percent: Double?
    }

    private let deviceId: String
    private let context: ModelContext
    private let iconResolver: any IconResolving
    private let locale: Locale

    init(
        deviceId: String,
        context: ModelContext,
        iconResolver: any IconResolving = IconResolver.shared,
        locale: Locale = .current
    ) {
        self.deviceId = deviceId
        self.context = context
        self.iconResolver = iconResolver
        self.locale = locale
    }

    /// Counts instead of building rows, so a panel doesn't redraw whenever a sensor's value changes.
    var hasSensors: Bool {
        let device: String? = deviceId
        let sensors = FetchDescriptor<SensorEntity>(predicate: #Predicate { $0.deviceId == device && !$0.isHiddenInHA })
        let binarySensors = FetchDescriptor<BinarySensorEntity>(
            predicate: #Predicate { $0.deviceId == device && !$0.isHiddenInHA }
        )
        return ((try? context.fetchCount(sensors)) ?? 0) + ((try? context.fetchCount(binarySensors)) ?? 0) > 0
    }

    /// A to Z by name, as Home Assistant lists them; ties by entity id so rows stay put.
    var rows: [Row] {
        (sensorRows + binarySensorRows).sorted {
            switch $0.name.localizedStandardCompare($1.name) {
            case .orderedSame: $0.id < $1.id
            case let order: order == .orderedAscending
            }
        }
    }
}

// MARK: - Rows

private extension DeviceSensorsViewModel {

    /// Hidden in Home Assistant is left out; Hemera's own `isHidden` only tidies area pages.
    var sensorRows: [Row] {
        let device: String? = deviceId
        let descriptor = FetchDescriptor<SensorEntity>(predicate: #Predicate { $0.deviceId == device && !$0.isHiddenInHA })
        return ((try? context.fetch(descriptor)) ?? []).map { sensor in
            let number = sensor.isAvailable ? Self.number(sensor.state) : nil
            return Row(
                id: sensor.entityId,
                name: Self.displayName(sensor.entityName ?? sensor.name),
                icon: iconResolver.iconName(
                    domain: SensorEntity.domain, deviceClass: sensor.deviceClass,
                    state: sensor.state, entityIcon: sensor.icon
                ),
                value: value(of: sensor, isNumber: number != nil),
                percent: sensor.unitOfMeasurement == "%" ? number : nil
            )
        }
    }

    var binarySensorRows: [Row] {
        let device: String? = deviceId
        let descriptor = FetchDescriptor<BinarySensorEntity>(
            predicate: #Predicate { $0.deviceId == device && !$0.isHiddenInHA }
        )
        return ((try? context.fetch(descriptor)) ?? []).map { binarySensor in
            let card = BinarySensorCardViewModel(binarySensor: binarySensor, iconResolver: iconResolver)
            return Row(
                id: binarySensor.entityId,
                name: Self.displayName(binarySensor.entityName ?? binarySensor.name),
                icon: card.iconName,
                value: binarySensor.isAvailable ? card.stateDescription : Localization.unavailable,
                percent: nil
            )
        }
    }

    /// Raw state with HA's unit and the locale's decimal separator: no rounding, no conversion.
    func value(of sensor: SensorEntity, isNumber: Bool) -> String {
        if !sensor.isAvailable || sensor.state == Self.unavailableState { return Localization.unavailable }
        if sensor.state == Self.unknownState { return Localization.unknown }
        guard isNumber else { return sensor.state.prefix(1).uppercased() + sensor.state.dropFirst() }

        let number = sensor.state.replacingOccurrences(of: ".", with: locale.decimalSeparator ?? ".")
        switch sensor.unitOfMeasurement {
        case nil, "": return number
        case "%": return number + "%"
        case let unit?: return number + " " + unit
        }
    }

    /// Some integrations build names with a stray space where a prefix was empty.
    static func displayName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Plain decimals only: `Double` alone would also take "nan", "inf" and hex as numbers.
    static func number(_ state: String) -> Double? {
        guard !state.isEmpty, state.allSatisfy({ "0123456789.-+eE".contains($0) }) else { return nil }
        return Double(state).flatMap { $0.isFinite ? $0 : nil }
    }

    static let unknownState = "unknown"
    static let unavailableState = "unavailable"
}

// MARK: - Localization

private extension DeviceSensorsViewModel {
    enum Localization {
        static let unknown = String(
            localized: "Unknown",
            comment: "Value of a device sensor that reports no reading, on a device's Sensors page"
        )
        static let unavailable = String(
            localized: "Unavailable",
            comment: "Value of a device sensor Home Assistant can't reach, on a device's Sensors page"
        )
    }
}
