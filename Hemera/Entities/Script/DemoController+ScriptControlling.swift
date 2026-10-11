import Foundation
import SwiftData

extension DemoController: ScriptControlling {

    /// Simulated run duration so the running state is visible in demo mode.
    private static let simulatedRunDuration: Duration = .seconds(2.5)

    func runScript(_ id: String) async {
        await simulateNetworkDelay()
        guard !Task.isCancelled else { return }
        guard let entity = ScriptEntity.fetch(byId: id, in: context) else { return }

        let token = UUID()
        scriptRunTokens[id] = token
        entity.state = .on

        try? await Task.sleep(for: Self.simulatedRunDuration)
        // Only revert if this run is still the current one — a newer run or a cancel owns the state otherwise.
        guard scriptRunTokens[id] == token else { return }
        scriptRunTokens[id] = nil
        entity.state = .off
    }

    func cancelScript(_ id: String) async {
        guard let entity = ScriptEntity.fetch(byId: id, in: context) else { return }
        scriptRunTokens[id] = nil
        entity.state = .off
    }
}
