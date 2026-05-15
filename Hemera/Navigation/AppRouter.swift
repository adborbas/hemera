import Foundation
import Mortar
import SwiftUI

/// Pure UI routing coordinator. Maps auth state to root destination.
/// No side effects — only decides which view to show.
@Observable
@MainActor
final class AppRouter {

    enum Destination {
        case onboarding
        case connectToServer
        case connecting
        case authenticated
    }

    private(set) var destination: Destination
    /// Non-nil when the user was forced back to onboarding (e.g. session expired).
    private(set) var sessionExpiredMessage: String?

    init(authManager: some AuthManaging) {
        switch authManager.state {
        case .unauthenticated: destination = .onboarding
        case .authenticated: destination = .authenticated
        }

        authManager.addOnChangeHandler { [weak self] state, reason in
            guard let self else { return }
            switch state {
            case .unauthenticated:
                if reason == .sessionExpired {
                    self.sessionExpiredMessage = Localization.sessionExpired
                }
                withAnimation(Mortar.Motion.springSnappy) {
                    self.destination = .onboarding
                }
            case .authenticated:
                self.sessionExpiredMessage = nil
                withAnimation(Mortar.Motion.springSnappy) {
                    self.destination = .connecting
                }
            }
        }
    }

    /// Called by SessionManager once the WebSocket connection is established.
    func sessionReady() {
        if destination == .connecting {
            withAnimation(Mortar.Motion.springSnappy) {
                destination = .authenticated
            }
        }
    }

    func navigate(to newDestination: Destination) {
        sessionExpiredMessage = nil
        withAnimation(Mortar.Motion.springSnappy) {
            destination = newDestination
        }
    }
}

private extension AppRouter {
    enum Localization {
        static let sessionExpired = String(localized: "Your session has expired. Please log in again.", comment: "Message shown on the welcome screen after the user's authentication session expires")
    }
}
