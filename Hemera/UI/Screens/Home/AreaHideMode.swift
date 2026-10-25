import Foundation

/**
 Must stay view-owned `@State`: `AreasViewModel` rebuilds `AreaDetailViewModel` on every
 `navigationDestination` evaluation, so a flag there would reset on the next upstream `@Query`.
*/
@Observable
@MainActor
final class AreaHideMode {

    private(set) var isActive = false
    private(set) var animatesTileChanges = false

    /// How long tile changes stay animated after a mode toggle.
    private static let animationWindow = Duration.milliseconds(500)

    private var resetTask: Task<Void, Never>?

    func setActive(_ active: Bool) {
        resetTask?.cancel()
        animatesTileChanges = true
        isActive = active
        resetTask = Task { [weak self] in
            try? await Task.sleep(for: Self.animationWindow)
            guard !Task.isCancelled else { return }
            self?.animatesTileChanges = false
        }
    }

    /// Cancelling alone would strand `animatesTileChanges` armed, animating later syncs.
    func endAnimationWindow() {
        resetTask?.cancel()
        resetTask = nil
        animatesTileChanges = false
    }
}
