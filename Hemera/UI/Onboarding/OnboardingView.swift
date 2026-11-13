import SwiftUI

/// Puts each onboarding page into the frame and hands its results to the coordinator.
struct OnboardingView: View {

    @State private var serverSelection: ServerSelectionViewModel
    @State private var coordinator: OnboardingCoordinator

    init() {
        let serverSelection = ServerSelectionViewModel()
        _serverSelection = State(initialValue: serverSelection)
        _coordinator = State(initialValue: OnboardingCoordinator(connection: serverSelection))
    }

    var body: some View {
        OnboardingContainer(coordinator: coordinator, title: title, subtitle: subtitle) {
            switch coordinator.contentPage {
            case .server, .login:
                ServerListView(
                    viewModel: serverSelection,
                    onSelect: { url in Task { await serverSelection.connect(to: url) } },
                    onEnterManually: coordinator.enterAddressManually
                )
            case .manualAddress:
                ServerAddressView(handler: serverSelection, placement: .external)
            }
        }
        // Every way of connecting (a server, Connect, Return, the HTTP warning) ends here.
        .onChange(of: serverSelection.authSession != nil) { _, isOpen in
            if isOpen { coordinator.loginOpened() }
        }
        .sheet(isPresented: Binding(
            get: { coordinator.page == .login },
            set: { if !$0 { coordinator.loginCancelled() } }
        )) {
            if let session = serverSelection.authSession {
                OnboardingLoginSheet(
                    session: session,
                    onCallback: { callbackURL in
                        await serverSelection.handleOAuthCallback(url: callbackURL, session: session)
                        if serverSelection.errorMessage != nil { coordinator.loginCancelled() }
                    },
                    onFailure: {
                        serverSelection.authSessionFailed()
                        coordinator.loginCancelled()
                    },
                    onCancel: coordinator.loginCancelled
                )
            }
        }
        .alert(
            Localization.unencryptedTitle,
            isPresented: $serverSelection.showHTTPWarning,
            presenting: serverSelection.pendingHTTPURL
        ) { _ in
            Button(Localization.continueAction) {
                Task { await serverSelection.confirmHTTPConnection() }
            }
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier("httpWarningContinue")
            Button(Localization.cancel, role: .cancel) {
                serverSelection.cancelHTTPWarning()
            }
        } message: { url in
            Text(Localization.unencryptedMessage(url.absoluteString))
        }
        // The address page shows its own errors under the field.
        .alert(
            Localization.connectionFailedTitle,
            isPresented: Binding(
                get: { serverSelection.errorMessage != nil && coordinator.page == .server },
                set: { if !$0 { serverSelection.errorMessage = nil } }
            )
        ) {
            Button(Localization.ok, role: .cancel) { serverSelection.errorMessage = nil }
        } message: {
            Text(serverSelection.errorMessage ?? "")
        }
    }

    private var title: String {
        switch coordinator.contentPage {
        case .server, .login: Localization.serverTitle
        case .manualAddress: Localization.manualAddressTitle
        }
    }

    private var subtitle: String {
        switch coordinator.contentPage {
        case .server, .login: Localization.serverSubtitle
        case .manualAddress: Localization.manualAddressSubtitle
        }
    }
}

// MARK: - Localization

private extension OnboardingView {
    enum Localization {
        static let serverTitle = String(localized: "Connect to your server", comment: "Title of the onboarding page listing Home Assistant servers")
        static let serverSubtitle = String(
            localized: "Choose your Home Assistant server, or enter its address.",
            comment: "Subtitle of the onboarding page listing Home Assistant servers"
        )
        static let manualAddressTitle = String(
            localized: "Enter your server address",
            comment: "Title of the onboarding page for typing a Home Assistant address"
        )
        static let manualAddressSubtitle = String(
            localized: "The address you use to open Home Assistant, like homeassistant.local:8123.",
            comment: "Subtitle of the onboarding page for typing a Home Assistant address"
        )
        static let connectionFailedTitle = String(localized: "Couldn’t Connect", comment: "Alert title shown when connecting to a Home Assistant server fails during onboarding")
        static let ok = String(localized: "OK", comment: "Button dismissing the connection-failure alert")
        static let cancel = String(localized: "Cancel", comment: "Button to cancel the current action")
        static let unencryptedTitle = String(localized: "Unencrypted Connection", comment: "Alert title warning about HTTP connection without encryption")
        static func unencryptedMessage(_ address: String) -> String {
            String(
                localized: "Home Assistant answered at \(address), but not over HTTPS. This connection won't be encrypted.",
                comment: "Alert message naming the address that answered and explaining it is unencrypted. The placeholder is a full URL such as http://192.168.1.100:8123"
            )
        }
        static let continueAction = String(localized: "Continue", comment: "Button to proceed with unencrypted HTTP connection")
    }
}
