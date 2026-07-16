import Foundation

/// Suppresses server-driven sync for a short period after the user commits a value,
/// preventing stale `state_changed` events from snapping sliders back to old positions.
///
/// Usage in view models:
/// ```swift
/// private let cooldown = CommitCooldown()
///
/// var brightness: Int {
///     if cooldown.isSuppressed, let pending = pendingBrightness { return pending }
///     return light.brightness ?? 0
/// }
///
/// func setBrightness(to value: Int) {
///     pendingBrightness = value
///     cooldown.commit()
///     ...
/// }
/// ```
@Observable
@MainActor
final class CommitCooldown {
    /// Stored & observed so window expiry notifies observers (a pure time-computed
    /// value would flip silently, leaving sliders stuck at the dragged position on
    /// a failed commit — no `state_changed` arrives to trigger reconciliation).
    private(set) var isSuppressed = false

    private let duration: TimeInterval
    private var expiryTask: Task<Void, Never>?

    init(duration: TimeInterval = 1) {
        self.duration = duration
    }

    func commit() {
        isSuppressed = true
        // Cancel-on-recommit debounces rapid drags: the window always measures
        // from the last commit.
        expiryTask?.cancel()
        expiryTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(self.duration))
            guard !Task.isCancelled else { return }
            self.isSuppressed = false
        }
    }
}
