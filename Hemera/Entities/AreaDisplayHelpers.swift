import Foundation
import SwiftUI

struct AreaStatusIcon: Identifiable, Hashable {
    enum Category: Hashable {
        case light, cover, binarySensor
    }

    let category: Category
    /// Bare MDI name, or `nil` when the icon translations have not arrived yet.
    let iconName: String?
    let isActive: Bool
    let activeColor: Color

    var id: Category { category }
}

/// Pure functions that translate `AreaEntity` state into display values.
/// Lives alongside the model since the transforms are pure derivations of
/// model state with no presentation lifecycle of their own.
enum AreaDisplayHelpers {

    static func representativeSensors(
        for area: AreaEntity
    ) -> (temperature: SensorEntity?, humidity: SensorEntity?) {
        (
            temperature: representative(
                in: area.sensors,
                deviceClass: "temperature",
                assignedEntityId: area.temperatureEntityId
            ),
            humidity: representative(
                in: area.sensors,
                deviceClass: "humidity",
                assignedEntityId: area.humidityEntityId
            )
        )
    }

    static func climateSummary(for area: AreaEntity) -> (String?, String?) {
        let (temperature, humidity) = representativeSensors(for: area)

        let tempStr = temperature.flatMap { Double($0.state) }
            .map { (value: Double) -> String in
                let number = value.formatted(.number.precision(.fractionLength(1)))
                return number + (temperature?.unitOfMeasurement ?? "°")
            }
        let humStr = humidity.flatMap { Double($0.state) }
            .map { (value: Double) -> String in
                let number = value.formatted(.number.precision(.fractionLength(1)))
                return number + (humidity?.unitOfMeasurement ?? "%")
            }

        return (tempStr, humStr)
    }

    static func climateLabel(for area: AreaEntity) -> String? {
        let (temperature, humidity) = climateSummary(for: area)
        let parts = [temperature, humidity].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    static func statusIcons(
        from area: AreaEntity,
        iconResolver: any IconResolving = IconResolver.shared
    ) -> [AreaStatusIcon] {
        var icons: [AreaStatusIcon] = []

        // Status indicators must ignore HA-hidden and locally-hidden entities,
        // mirroring the grid.
        let lights = area.lights.filter { !$0.isHidden && !$0.isHiddenInHA }
        let covers = area.covers.filter { !$0.isHidden && !$0.isHiddenInHA }

        if !lights.isEmpty {
            let anyOn = lights.contains { $0.state == .on && $0.isAvailable }
            let iconName = iconResolver.iconName(
                domain: LightEntity.domain,
                state: anyOn ? LightEntity.State.on.rawValue : LightEntity.State.off.rawValue
            )
            icons.append(AreaStatusIcon(category: .light, iconName: iconName, isActive: anyOn, activeColor: .yellow))
        }

        if let firstCover = covers.first {
            let anyOpen = covers.contains { ($0.state == .open || $0.state == .opening) && $0.isAvailable }
            let iconName = iconResolver.iconName(
                domain: CoverEntity.domain,
                deviceClass: firstCover.deviceClass == .unknown ? nil : firstCover.deviceClass.rawValue,
                state: anyOpen ? CoverEntity.State.open.rawValue : CoverEntity.State.closed.rawValue
            )
            icons.append(AreaStatusIcon(category: .cover, iconName: iconName, isActive: anyOpen, activeColor: .blue))
        }

        let relevantSensors = area.binarySensors.filter {
            !$0.isHidden && !$0.isHiddenInHA && [.motion, .door, .window].contains($0.deviceClass)
        }
        if !relevantSensors.isEmpty {
            let activeSensor = relevantSensors.first { $0.state == .on && $0.isAvailable }
            let representative = activeSensor ?? relevantSensors[0]
            let isActive = activeSensor != nil
            let iconName = iconResolver.iconName(
                domain: BinarySensorEntity.domain,
                deviceClass: representative.deviceClassRaw,
                state: isActive ? BinarySensorEntity.State.on.rawValue : BinarySensorEntity.State.off.rawValue
            )
            icons.append(AreaStatusIcon(category: .binarySensor, iconName: iconName, isActive: isActive, activeColor: .teal))
        }

        return icons
    }
}

private extension AreaDisplayHelpers {

    /**
     An explicit assignment wins even when hidden; otherwise the lowest `entityId`
     among visible `state_class == "measurement"` sensors, never a setpoint.
     */
    static func representative(
        in sensors: [SensorEntity],
        deviceClass: String,
        assignedEntityId: String?
    ) -> SensorEntity? {
        if let assignedEntityId,
           let assigned = sensors.first(where: { $0.entityId == assignedEntityId }) {
            return assigned
        }
        return sensors
            .filter {
                !$0.isHiddenInHA
                    && $0.deviceClass == deviceClass
                    && $0.stateClass == "measurement"
            }
            .min { $0.entityId < $1.entityId }
    }
}
