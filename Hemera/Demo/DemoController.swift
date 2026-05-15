import Foundation
import SwiftData

/// Simulates Home Assistant entity control for demo mode.
///
/// Mutates SwiftData `@Model` entities directly with realistic delays.
/// Since `@Model` types are `@Observable`, mutations trigger SwiftUI updates automatically.
///
/// Protocol conformances live alongside each entity domain:
/// e.g. `Entities/Light/DemoController+LightControlling.swift`.
@MainActor
final class DemoController {

    /// Standard delay applied before mutating entities to simulate network latency.
    private static let simulatedDelay: Duration = .milliseconds(300)

    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Sleeps for the standard simulated network delay.
    func simulateNetworkDelay() async {
        try? await Task.sleep(for: Self.simulatedDelay)
    }
}
