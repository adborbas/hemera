import SwiftData

extension DemoController: VacuumControlling {

    func startVacuum(_ id: String) async {
        VacuumEntity.fetch(byId: id, in: context)?.state = .cleaning
    }

    func pauseVacuum(_ id: String) async {
        VacuumEntity.fetch(byId: id, in: context)?.state = .paused
    }

    func stopVacuum(_ id: String) async {
        VacuumEntity.fetch(byId: id, in: context)?.state = .idle
    }

    func returnVacuumToBase(_ id: String) async {
        guard let vacuum = VacuumEntity.fetch(byId: id, in: context) else { return }
        vacuum.state = .returning
        vacuumDockingTasks[id]?.cancel()
        // Not tied to the caller's task: the card cancels it on the next tap, even a stateless Locate.
        vacuumDockingTasks[id] = Task {
            try? await Task.sleep(for: vacuumDockingDelay)
            guard !Task.isCancelled,
                  let vacuum = VacuumEntity.fetch(byId: id, in: context),
                  vacuum.state == .returning else { return }
            vacuum.state = .docked
        }
    }

    func locateVacuum(_ id: String) async {}
}
