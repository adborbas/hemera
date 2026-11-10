import Foundation
import SwiftData

/// Every sensor and binary sensor on one device, as the rows of its Sensors page.
@Observable
@MainActor
final class DeviceSensorsViewModel {

    /// One card: a reading, or a part's life % paired with its time left.
    struct Row: Identifiable, Hashable {
        let id: String
        let name: String
        let icon: String?
        let value: String
        let percent: Double?
        let timeLeft: String?
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

    var hasSensors: Bool { !readings.isEmpty }

    /// A to Z by name, then `%` and time sensors of the same part merged into one row.
    var rows: [Row] {
        Self.paired(readings.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending })
    }
}

// MARK: - Readings

private extension DeviceSensorsViewModel {

    struct Reading {
        let id: String
        let name: String
        let icon: String?
        let value: String
        let unit: String?
        let percent: Double?
        let isNumber: Bool
    }

    var readings: [Reading] { sensorReadings + binarySensorReadings }

    /// Hidden in Home Assistant is left out; Hemera's own `isHidden` only tidies area pages.
    var sensorReadings: [Reading] {
        let device: String? = deviceId
        let descriptor = FetchDescriptor<SensorEntity>(predicate: #Predicate { $0.deviceId == device && !$0.isHiddenInHA })
        return ((try? context.fetch(descriptor)) ?? []).map { sensor in
            let number = sensor.isAvailable ? Double(sensor.state) : nil
            return Reading(
                id: sensor.entityId,
                name: sensor.entityName ?? sensor.name,
                icon: iconResolver.iconName(
                    domain: SensorEntity.domain, deviceClass: sensor.deviceClass,
                    state: sensor.state, entityIcon: sensor.icon
                ),
                value: value(of: sensor, isNumber: number != nil),
                unit: sensor.unitOfMeasurement,
                percent: sensor.unitOfMeasurement == "%" ? number : nil,
                isNumber: number != nil
            )
        }
    }

    var binarySensorReadings: [Reading] {
        let device: String? = deviceId
        let descriptor = FetchDescriptor<BinarySensorEntity>(
            predicate: #Predicate { $0.deviceId == device && !$0.isHiddenInHA }
        )
        return ((try? context.fetch(descriptor)) ?? []).map { binarySensor in
            let card = BinarySensorCardViewModel(binarySensor: binarySensor, iconResolver: iconResolver)
            return Reading(
                id: binarySensor.entityId,
                name: binarySensor.entityName ?? binarySensor.name,
                icon: card.iconName,
                value: card.stateDescription,
                unit: nil,
                percent: nil,
                isNumber: false
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

    static let unknownState = "unknown"
    static let unavailableState = "unavailable"
}

// MARK: - Pairing

extension DeviceSensorsViewModel {

    private static let timeUnits: Set<String> = ["s", "min", "h", "d"]

    /**
     Pairs a `%` reading with a time reading whose names match minus their last two words
     ("Filter Life Level" + "Filter Left Time" → "Filter"); only readings with a number, in entity-id order.
    */
    private static func paired(_ readings: [Reading]) -> [Row] {
        func stem(_ reading: Reading) -> String? {
            let words = reading.name.split(separator: " ")
            return words.count > 2 ? words.dropLast(2).joined(separator: " ") : nil
        }

        var timeByPercentId: [String: Reading] = [:]
        let byStem = Dictionary(grouping: readings.filter { stem($0) != nil }) { stem($0) ?? "" }
        for group in byStem.values {
            let percents = group.filter { $0.percent != nil }.sorted { $0.id < $1.id }
            let times = group.filter { $0.isNumber && ($0.unit.map(timeUnits.contains) ?? false) }.sorted { $0.id < $1.id }
            for (percent, time) in zip(percents, times) { timeByPercentId[percent.id] = time }
        }

        let pairedTimeIds = Set(timeByPercentId.values.map(\.id))
        return readings.filter { !pairedTimeIds.contains($0.id) }.map { reading in
            let time = timeByPercentId[reading.id]
            return Row(
                id: reading.id,
                name: time == nil ? reading.name : stem(reading) ?? reading.name,
                icon: reading.icon,
                value: reading.value,
                percent: reading.percent,
                timeLeft: time?.value
            )
        }
    }
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
