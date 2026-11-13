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
        case connecting
        case authenticated
        case sessionExpired
    }

    enum SessionSync {
        case pending
        case succeeded
        case failed
    }

    private(set) var destination: Destination
    /// How the current login's latest sync ended.
    private(set) var sessionSync = SessionSync.pending

    init(authManager: some AuthManaging) {
        switch authManager.state {
        case .unauthenticated: destination = .onboarding
        case .authenticated: destination = .authenticated
        case .sessionExpired: destination = .sessionExpired
        }

        authManager.addOnChangeHandler { [weak self] state, _ in
            guard let self else { return }
            self.sessionSync = .pending
            switch state {
            case .unauthenticated:
                withAnimation(Mortar.Motion.springSnappy) {
                    self.destination = .onboarding
                }
            case .sessionExpired:
                withAnimation(Mortar.Motion.springSnappy) {
                    self.destination = .sessionExpired
                }
            case .authenticated:
                // A login from onboarding keeps it on screen for the Home step.
                guard self.destination != .onboarding else { return }
                withAnimation(Mortar.Motion.springSnappy) {
                    self.destination = .connecting
                }
            }
        }
    }

    /// Called by SessionManager each time a sync finishes, whether or not it succeeded.
    func sessionReady(succeeded: Bool) {
        sessionSync = succeeded ? .succeeded : .failed
        if destination == .connecting {
            withAnimation(Mortar.Motion.springSnappy) {
                destination = .authenticated
            }
        }
    }

    /// A retried connection is syncing again, so an earlier failure no longer stands.
    func syncRetried() {
        sessionSync = .pending
    }

    func navigate(to newDestination: Destination) {
        withAnimation(Mortar.Motion.springSnappy) {
            destination = newDestination
        }
    }
}
