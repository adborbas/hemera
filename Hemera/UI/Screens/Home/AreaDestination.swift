import Foundation
import SwiftData

/// Navigation value for the Areas screen.
///
/// `@Model` types are `Hashable` via `PersistentIdentifier`, but we still use
/// an enum so the "Unassigned" (virtual) area can sit alongside real ones in
/// the same `navigationDestination(for:)`.
///
/// `unassigned` carries `hasRealAreas` so the destination's display name
/// matches the label shown on the grid card ("Other" when real areas exist,
/// "Devices" otherwise).
enum AreaDestination: Hashable {
    case area(AreaEntity)
    case unassigned(hasRealAreas: Bool)

    var displayName: String {
        switch self {
        case .area(let area): area.name
        case .unassigned(let hasRealAreas):
            hasRealAreas ? Localization.other : Localization.devices
        }
    }

    var isVirtual: Bool {
        if case .unassigned = self { true } else { false }
    }
}

extension AreaDestination {
    enum Localization {
        static let other = String(
            localized: "Other",
            comment: "Title for the virtual area containing entities not assigned to any HA area, shown when real areas also exist"
        )
        static let devices = String(
            localized: "Devices",
            comment: "Title for the virtual area when no real HA areas exist in Home Assistant"
        )
    }
}
