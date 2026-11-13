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

    private(set) var destination: Destination
    /// Whether the current login's first sync has finished.
    private(set) var isSessionReady = false

    init(authManager: some AuthManaging) {
        switch authManager.state {
        case .unauthenticated: destination = .onboarding
        case .authenticated: destination = .authenticated
        case .sessionExpired: destination = .sessionExpired
        }

        authManager.addOnChangeHandler { [weak self] state, _ in
            guard let self else { return }
            self.isSessionReady = false
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

    /// Called by SessionManager once the WebSocket connection is established.
    func sessionReady() {
        isSessionReady = true
        if destination == .connecting {
            withAnimation(Mortar.Motion.springSnappy) {
                destination = .authenticated
            }
        }
    }

    func navigate(to newDestination: Destination) {
        withAnimation(Mortar.Motion.springSnappy) {
            destination = newDestination
        }
    }
}
