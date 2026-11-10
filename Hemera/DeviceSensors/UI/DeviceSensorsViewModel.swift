import Foundation
import SwiftData

/// Every sensor and binary sensor on one device, as the rows of its Sensors page.
@Observable
@MainActor
final class DeviceSensorsViewModel {

    /// One card: a reading, plus the reading it was paired with as `detail` ("146 h left", "Charging").
    struct Row: Identifiable {
        let id: String
        let name: String
        let icon: String?
        let value: String
        let percent: Double?
        let detail: String?
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

    /// Paired readings merged into one row, A to Z by the name shown; ties by entity id so rows stay put.
    var rows: [Row] {
        Self.paired(readings).sorted {
            switch $0.name.localizedStandardCompare($1.name) {
            case .orderedSame: $0.id < $1.id
            case let order: order == .orderedAscending
            }
        }
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
        let deviceClass: String?
        let percent: Double?
        /// A number for a sensor, on or off for a binary sensor: what a pair needs to be worth showing.
        let hasReading: Bool
    }

    var readings: [Reading] { sensorReadings + binarySensorReadings }

    /// Hidden in Home Assistant is left out; Hemera's own `isHidden` only tidies area pages.
    var sensorReadings: [Reading] {
        let device: String? = deviceId
        let descriptor = FetchDescriptor<SensorEntity>(predicate: #Predicate { $0.deviceId == device && !$0.isHiddenInHA })
        return ((try? context.fetch(descriptor)) ?? []).map { sensor in
            let number = sensor.isAvailable ? Self.number(sensor.state) : nil
            return Reading(
                id: sensor.entityId,
                name: Self.displayName(sensor.entityName ?? sensor.name),
                icon: iconResolver.iconName(
                    domain: SensorEntity.domain, deviceClass: sensor.deviceClass,
                    state: sensor.state, entityIcon: sensor.icon
                ),
                value: value(of: sensor, isNumber: number != nil),
                unit: sensor.unitOfMeasurement,
                deviceClass: sensor.deviceClass,
                percent: sensor.unitOfMeasurement == "%" ? number : nil,
                hasReading: number != nil
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
                name: Self.displayName(binarySensor.entityName ?? binarySensor.name),
                icon: card.iconName,
                value: binarySensor.isAvailable ? card.stateDescription : Localization.unavailable,
                unit: nil,
                deviceClass: binarySensor.deviceClassRaw,
                percent: nil,
                hasReading: binarySensor.isAvailable && (binarySensor.state == .on || binarySensor.state == .off)
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

// MARK: - Pairing

extension DeviceSensorsViewModel {

    /// A main reading and the one that explains it, by Home Assistant device class.
    private static let deviceClassPairs: [(main: String, detail: String)] = [
        ("battery", BinarySensorEntity.DeviceClass.batteryCharging.rawValue),
        ("power", "energy"),
    ]

    private static let timeUnits: Set<String> = ["s", "min", "h", "d"]

    /// Merges paired readings into one row each; everything else stays its own row.
    private static func paired(_ readings: [Reading]) -> [Row] {
        var details: [String: (name: String?, detail: String)] = [:]
        var merged: Set<String> = []
        for (main, detail, name, text) in deviceClassMatches(readings) + nameMatches(readings) {
            let isFree = details[main.id] == nil && details[detail.id] == nil
            guard isFree, !merged.contains(main.id), !merged.contains(detail.id) else { continue }
            details[main.id] = (name, text)
            merged.insert(detail.id)
        }
        return readings.filter { !merged.contains($0.id) }.map { reading in
            Row(
                id: reading.id,
                name: details[reading.id]?.name ?? reading.name,
                icon: reading.icon,
                value: reading.value,
                percent: reading.percent,
                detail: details[reading.id]?.detail
            )
        }
    }

    private typealias Match = (main: Reading, detail: Reading, name: String?, text: String)

    /// Only when the device has exactly one of each, so nothing is guessed.
    private static func deviceClassMatches(_ readings: [Reading]) -> [Match] {
        deviceClassPairs.compactMap { pair in
            let mains = readings.filter { $0.deviceClass == pair.main }
            let details = readings.filter { $0.deviceClass == pair.detail }
            guard mains.count == 1, details.count == 1, let main = mains.first, let detail = details.first,
                  main.hasReading, detail.hasReading else { return nil }
            return (main, detail, nil, detail.value)
        }
    }

    /**
     A `%` reading and a time reading whose names match minus their last two words
     ("Filter Life Level" + "Filter Left Time" → "Filter"); several per name pair in entity-id order.
    */
    private static func nameMatches(_ readings: [Reading]) -> [Match] {
        func stem(_ reading: Reading) -> String? {
            let words = reading.name.split(separator: " ")
            return words.count > 2 ? words.dropLast(2).joined(separator: " ") : nil
        }

        let byStem = Dictionary(grouping: readings.filter { stem($0) != nil }) { stem($0) ?? "" }
        return byStem.flatMap { stem, group in
            let percents = group.filter { $0.percent != nil }.sorted { $0.id < $1.id }
            let times = group.filter { $0.hasReading && ($0.unit.map(timeUnits.contains) ?? false) }
                .sorted { $0.id < $1.id }
            return zip(percents, times).map { ($0, $1, stem, Localization.timeLeft($1.value)) }
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

        static func timeLeft(_ time: String) -> String {
            String(
                localized: "\(time) left",
                comment: "Time remaining for a part, e.g. '58 h left', under its life bar on a device's Sensors page"
            )
        }
    }
}
