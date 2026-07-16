import SwiftUI

/// Protocol for view models that can be displayed as entity cards.
///
/// Card VMs hold an init-time reference to their backing `@Model`. The
/// `@Model`'s `@Observable` conformance drives per-card re-renders when
/// properties change in place on `mainContext`. The factory caches VMs
/// per-entityId for the session, so the same instance is reused — which
/// preserves ephemeral interaction state (`pendingBrightness`, cooldowns)
/// across re-renders.
@MainActor
protocol EntityCardViewModel: AnyObject, Observable, Identifiable where ID == String {
    nonisolated var id: String { get }
    var name: String { get }
    var isAvailable: Bool { get }
    var deviceId: String? { get }

    /// Creates the card view for this entity.
    @ViewBuilder
    func makeCardView() -> AnyView

    /// Whether this entity presents a detail overlay when its card body is tapped.
    /// Must stay in sync with `makeOverlayView` — `true` exactly when it returns non-nil.
    var hasOverlay: Bool { get }

    /// Creates the overlay view for this entity, if any.
    /// Return `nil` for entities that have no detail overlay (e.g. scenes).
    func makeOverlayView(isPresented: Binding<Bool>) -> AnyView?

    /// Performs the primary action for this entity (e.g., activate a scene).
    /// Called when the card body is tapped and no overlay exists.
    func performPrimaryAction()
}

extension EntityCardViewModel {
    var hasOverlay: Bool { false }
    func makeOverlayView(isPresented: Binding<Bool>) -> AnyView? { nil }
    func performPrimaryAction() { }
}

/// Identifiable wrapper for presenting an entity overlay.
struct OverlayItem: Identifiable {
    let id: String
    let viewModel: any EntityCardViewModel
}

extension Binding where Value == OverlayItem? {
    /// Bridges a `Binding<OverlayItem?>` (used with `.sheet(item:)`) to the
    /// `Binding<Bool>` form expected by overlay views' `isPresented`.
    /// Setting to `false` clears the underlying item.
    var isPresented: Binding<Bool> {
        Binding<Bool>(
            get: { wrappedValue != nil },
            set: { if !$0 { wrappedValue = nil } }
        )
    }
}
