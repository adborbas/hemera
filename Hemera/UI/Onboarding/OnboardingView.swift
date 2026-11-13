import SwiftUI

/// Puts each onboarding page into the frame and hands its results to the coordinator.
struct OnboardingView: View {

    @State private var serverSelection: ServerSelectionViewModel
    @State private var coordinator: OnboardingCoordinator

    init(theme: any OnboardingTheming) {
        let serverSelection = ServerSelectionViewModel()
        _serverSelection = State(initialValue: serverSelection)
        _coordinator = State(initialValue: OnboardingCoordinator(
            connection: serverSelection,
            authManager: ServiceLocator.shared.authManager,
            router: ServiceLocator.shared.router,
            connectionRetrier: ServiceLocator.shared.sessionManager,
            theme: theme
        ))
    }

    var body: some View {
        OnboardingContainer(
            coordinator: coordinator,
            title: title,
            subtitle: subtitle,
            fillsWidth: coordinator.contentPage >= .home
        ) {
            switch coordinator.contentPage {
            case .server, .login:
                ServerListView(
                    viewModel: serverSelection,
                    onSelect: { url in Task { await serverSelection.connect(to: url) } },
                    onEnterManually: coordinator.enterAddressManually
                )
            case .manualAddress:
                ServerAddressView(handler: serverSelection, placement: .external)
            case .home:
                if let home = coordinator.home {
                    OnboardingHomeStep(
                        home: home,
                        state: coordinator.homeState,
                        serverHost: coordinator.serverHost,
                        onRetry: coordinator.retryConnection
                    )
                }
            case .theme:
                if let home = coordinator.home {
                    OnboardingThemeStep(home: home, resetCount: coordinator.themeResetCount)
                }
            }
        } titleAccessory: {
            if coordinator.contentPage == .home, let home = coordinator.home {
                OnboardingHomeHistory(home: home)
            }
        }
        .themedBackground(isShown: coordinator.contentPage == .theme)
        .onDisappear(perform: coordinator.disappeared)
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
                        if serverSelection.errorMessage != nil {
                            coordinator.loginCancelled()
                        } else if let session = ServiceLocator.shared.session {
                            coordinator.loggedIn(home: CuratedHomeViewModel(
                                homeTileRepository: session.homeTileRepository,
                                viewModelFactory: session.viewModelFactory,
                                authManager: ServiceLocator.shared.authManager,
                                demoCoordinator: ServiceLocator.shared.demoCoordinator
                            ))
                        }
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
        .alert(
            Localization.logOutTitle(coordinator.serverHost),
            isPresented: Binding(get: { coordinator.isConfirmingLogOut }, set: { if !$0 { coordinator.cancelLogOut() } })
        ) {
            Button(Localization.logOut, role: .destructive, action: coordinator.logOut)
                .accessibilityIdentifier("onboardingLogOut")
            Button(Localization.cancel, role: .cancel, action: coordinator.cancelLogOut)
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
        case .home: Localization.homeTitle
        case .theme: Localization.themeTitle
        }
    }

    private var subtitle: String {
        switch coordinator.contentPage {
        case .server, .login: Localization.serverSubtitle
        case .manualAddress: Localization.manualAddressSubtitle
        case .home: Localization.homeSubtitle
        case .theme: Localization.themeSubtitle
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
        static let homeTitle = String(localized: "Your Home", comment: "Title of the onboarding step for arranging Home")
        static let homeSubtitle = String(
            localized: "We've picked a few to get you started. Remove, resize or rearrange them.",
            comment: "Subtitle of the onboarding step for arranging Home, which starts with suggested tiles"
        )
        static let themeTitle = String(localized: "Choose a look", comment: "Title of the onboarding step for choosing a theme")
        static let themeSubtitle = String(
            localized: "Pick a colour for your Home. You can change it any time in Settings.",
            comment: "Subtitle of the onboarding step for choosing a theme"
        )
        static func logOutTitle(_ host: String) -> String {
            String(
                localized: "Log out of \(host)?",
                comment: "Title of the alert shown on Back from the onboarding Home step. The placeholder is a server host name"
            )
        }
        static let logOut = String(localized: "Log Out", comment: "Alert button logging out and returning to the onboarding server list")
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
