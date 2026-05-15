import Foundation
import UIKit

/// Centralized error notification channel for user-facing error feedback
/// and sync status tracking.
///
/// **Toasts**: `HAServiceCaller` and `HADataSyncService` push errors here.
/// `ToastOverlay` (mounted at `RootView` level) observes and renders toasts.
/// Auto-dismisses after 3 seconds. New errors replace the current toast.
///
/// **Sync status**: Tracks whether the initial data sync failed via `syncFailed`.
/// Dashboard views observe this to show a retry-able error state instead of
/// a misleading "empty" screen.
@Observable
@MainActor
final class ErrorNotifier: @unchecked Sendable {

    private(set) var currentToast: Toast?
    private(set) var syncFailed = false
    private(set) var dismissTask: Task<Void, Never>?
    private let autoDismissDelay: Duration

    struct Toast: Identifiable {
        let id = UUID()
        let message: String
        let icon: String
    }

    init(autoDismissDelay: Duration = .seconds(3)) {
        self.autoDismissDelay = autoDismissDelay
    }

    func showError(_ message: String, icon: String = "exclamationmark.circle.fill") {
        dismissTask?.cancel()
        currentToast = Toast(message: message, icon: icon)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        let delay = autoDismissDelay
        dismissTask = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            currentToast = nil
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        currentToast = nil
    }

    func markSyncFailed() {
        syncFailed = true
    }

    func clearSyncFailed() {
        syncFailed = false
    }

    /// Shows an appropriate toast for a Home Assistant service call failure.
    ///
    /// Classifies the error as a server rejection or connection issue and
    /// displays a corresponding user-facing message.
    func showServiceCallError(_ error: Error) {
        switch HAServiceCaller.classifyError(error) {
        case .server:
            showError(Localization.serverRejected)
        case .connection:
            showError(Localization.connectionFailed, icon: "wifi.slash")
        }
    }
}

// MARK: - Localization

private extension ErrorNotifier {
    enum Localization {
        static let connectionFailed = String(
            localized: "Could not reach your server. Check your connection.",
            comment: "Toast shown when a Home Assistant service call fails due to a network or connection issue"
        )
        static let serverRejected = String(
            localized: "Home Assistant could not complete the action.",
            comment: "Toast shown when the Home Assistant server returns an error for a service call"
        )
    }
}
