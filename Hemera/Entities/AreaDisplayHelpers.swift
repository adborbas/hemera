import Foundation
import SwiftUI

struct AreaStatusIcon: Identifiable, Hashable {
    enum Category: Hashable {
        case light, cover, binarySensor
    }

    let category: Category
    let iconName: String
    let isActive: Bool
    let activeColor: Color

    var id: Category { category }
}

/// Pure functions that translate `AreaEntity` state into display values.
/// Lives alongside the model since the transforms are pure derivations of
/// model state with no presentation lifecycle of their own.
enum AreaDisplayHelpers {

    static func climateSummary(from sensors: [SensorEntity]) -> (String?, String?) {
        let temp = sensors.first { $0.deviceClass == "temperature" }
        let humidity = sensors.first { $0.deviceClass == "humidity" }

        let tempStr = temp.flatMap { Double($0.state) }
            .map { (value: Double) -> String in
                let number = value.formatted(.number.precision(.fractionLength(1)))
                return number + (temp?.unitOfMeasurement ?? "°")
            }
        let humStr = humidity.flatMap { Double($0.state) }
            .map { (value: Double) -> String in
                let number = value.formatted(.number.precision(.fractionLength(1)))
                return number + (humidity?.unitOfMeasurement ?? "%")
            }

        return (tempStr, humStr)
    }

    static func statusIcons(from area: AreaEntity) -> [AreaStatusIcon] {
        var icons: [AreaStatusIcon] = []

        if !area.lights.isEmpty {
            let anyOn = area.lights.contains { $0.state == .on && $0.isAvailable }
            icons.append(AreaStatusIcon(category: .light, iconName: "lightbulb.fill", isActive: anyOn, activeColor: .yellow))
        }

        if let firstCover = area.covers.first {
            let anyOpen = area.covers.contains { ($0.state == .open || $0.state == .opening) && $0.isAvailable }
            let symbolPair = firstCover.deviceClass.symbolPair
            let iconName = anyOpen ? symbolPair.open : symbolPair.closed
            icons.append(AreaStatusIcon(category: .cover, iconName: iconName, isActive: anyOpen, activeColor: .blue))
        }

        let relevantSensors = area.binarySensors.filter {
            [.motion, .door, .window].contains($0.deviceClass)
        }
        if !relevantSensors.isEmpty {
            let activeSensor = relevantSensors.first { $0.state == .on && $0.isAvailable }
            let representative = activeSensor ?? relevantSensors[0]
            let isActive = activeSensor != nil
            let iconName = representative.deviceClass.symbolName(isOn: isActive)
            icons.append(AreaStatusIcon(category: .binarySensor, iconName: iconName, isActive: isActive, activeColor: .teal))
        }

        return icons
    }
}
