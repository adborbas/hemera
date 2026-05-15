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
    private static let duration: TimeInterval = 1

    private var lastCommitDate: Date?
    private let now: @Sendable () -> Date

    init(now: @escaping @Sendable () -> Date = { Date() }) {
        self.now = now
    }

    var isSuppressed: Bool {
        guard let last = lastCommitDate else { return false }
        return now().timeIntervalSince(last) < Self.duration
    }

    func commit() {
        lastCommitDate = now()
    }
}
