import SwiftUI
import Mortar

extension Bundle {
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }
}

struct SettingsView: View {

    @Bindable var viewModel: SettingsViewModel
    /// Closes Settings and opens the theme editor; without it there is no Theme row.
    var editTheme: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(ScreenManager.self) private var screenManager
    @Environment(UpdateNudge.self) private var updateNudge
    @State private var presentedUpdate: AvailableUpdate?
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        NavigationStack(path: $viewModel.path) {
            List {
                accountSection
                appearanceSection
                kioskModeSection
                aboutSection
            }
            .task {
                viewModel.navigateToPendingRoute()
                if !viewModel.isDemoMode {
                    await viewModel.fetchHAVersion()
                }
            }
            .navigationDestination(for: SettingsViewModel.Route.self) { route in
                switch route {
                case .kioskMode:
                    KioskModeView(screenManager: viewModel.screenManager)
                case .serverURL:
                    ServerAddressView(handler: ServerURLViewModel(), placement: .toolbar) {
                        if !viewModel.path.isEmpty {
                            viewModel.path.removeLast()
                        }
                    }
                case .account:
                    accountPage
                }
            }
            .navigationTitle(Localization.settings)
            .reportsFeedScroll()
            .pushedScreenHeader(Localization.settings, leading: .close(label: Localization.close), staysCollapsed: true)
            .overlay {
                if viewModel.showConfetti {
                    ConfettiView {
                        viewModel.confettiFinished()
                    }
                    .allowsHitTesting(false)
                }
            }
        }
        .fullScreenCover(isPresented: $viewModel.showServerWebView) {
            if let url = viewModel.serverURL {
                NavigationStack {
                    AuthenticatedWebView(url: url) {
                        try await viewModel.validAccessToken()
                    }
                    .ignoresSafeArea()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(Localization.done) { viewModel.closeServer() }
                                .accessibilityIdentifier("serverWebViewDone")
                        }
                    }
                }
            }
        }
        .alert(Localization.logOutQuestion, isPresented: $viewModel.showLogoutConfirmation) {
            Button(Localization.logOut, role: .destructive) {
                viewModel.confirmLogout()
                dismiss()
            }
            .accessibilityIdentifier("logOutConfirm")
            Button(Localization.cancel, role: .cancel) {}
        } message: {
            if let host = viewModel.logoutHost {
                Text(Localization.logOutMessageWithHost(host))
            } else {
                Text(Localization.logOutMessage)
            }
        }
        .alert(Localization.exitDemoQuestion, isPresented: $viewModel.showExitDemoConfirmation) {
            Button(Localization.exitDemo, role: .destructive) {
                dismiss()
                viewModel.confirmExitDemo()
            }
            Button(Localization.cancel, role: .cancel) {}
        } message: {
            Text(Localization.exitDemoMessage)
        }
        .interactiveDismissDisabled()
    }

    private var accountSection: some View {
        Section {
            if viewModel.isAccountPageAvailable {
                NavigationLink(value: SettingsViewModel.Route.account) {
                    accountRow
                }
                .accessibilityIdentifier("settingsAccount")
            } else {
                HStack {
                    accountRow
                    Spacer()
                    Button(Localization.exitDemo) {
                        viewModel.exitDemoTapped()
                    }
                    .buttonStyle(.mortarDestructive())
                }
            }
        }
    }

    private var accountRow: some View {
        HStack(spacing: Mortar.Spacing.l) {
            AccountAvatar(account: viewModel.account, size: Mortar.AvatarSize.m)
            VStack(alignment: .leading, spacing: Mortar.Spacing.xxs) {
                Text(viewModel.accountName)
                    .font(.title3.weight(.semibold))
                Text(viewModel.accountSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .renderIf(!viewModel.accountSubtitle.isEmpty)
            }
        }
        .padding(.vertical, Mortar.Spacing.xs)
    }

    private var accountPage: some View {
        List {
            Section {
                AccountAvatar(account: viewModel.account, size: Mortar.AvatarSize.l)
                    .frame(maxWidth: .infinity)
            }
            .listRowBackground(Color.clear)
            if let account = viewModel.account {
                Section(Localization.account) {
                    LabeledContent(Localization.name, value: account.name)
                    LabeledContent(Localization.role, value: account.role.displayName)
                }
            }
            serverInfoSection
            logoutSection
        }
        .navigationTitle(Localization.account)
        .reportsFeedScroll()
        .pushedScreenHeader(Localization.account, staysCollapsed: true)
    }

    private var serverInfoSection: some View {
        Section(Localization.server) {
            if let url = viewModel.serverURL {
                NavigationLink(value: SettingsViewModel.Route.serverURL) {
                    LabeledContent(Localization.url, value: url.absoluteString)
                }
                .accessibilityIdentifier("settingsServerURL")
                if let haVersion = viewModel.haVersion {
                    LabeledContent(Localization.version, value: haVersion)
                        .accessibilityIdentifier("settingsHAVersion")
                }
                Button {
                    viewModel.openServer()
                } label: {
                    HStack {
                        Text(Localization.openServer)
                        Spacer()
                        ExternalLinkIndicator()
                    }
                }
                .tint(.primary)
                .accessibilityIdentifier("settingsOpenServer")
            }
        }
    }

    private var logoutSection: some View {
        // A footer, because a row is clipped to the section's corners, which are rounder than the button's.
        Section {
        } footer: {
            Button {
                viewModel.logoutTapped()
            } label: {
                Text(Localization.logOut)
            }
            .buttonStyle(.mortarDestructive(width: .fullWidth))
            .accessibilityIdentifier("settingsLogOut")
            .listRowInsets(EdgeInsets())
        }
    }

    @ViewBuilder
    private var appearanceSection: some View {
        if let editTheme {
            Section {
                Button(action: editTheme) {
                    LabeledContent(Localization.theme) {
                        HStack(spacing: Mortar.Spacing.s) {
                            ThemeSwatch(theme: themeManager.theme)
                            DisclosureIndicator()
                        }
                    }
                }
                .tint(.primary)
                .disabled(themeManager.settingsAreReadOnly)
            } header: {
                Text(Localization.appearance)
            } footer: {
                if themeManager.settingsAreReadOnly {
                    Text(Localization.appearanceReadOnly)
                }
            }
        }
    }

    private var kioskModeSection: some View {
        Section(Localization.kioskMode) {
            NavigationLink(value: SettingsViewModel.Route.kioskMode) {
                LabeledContent(Localization.kioskMode) {
                    Text(viewModel.screenManager.stayAwake ? Localization.on : Localization.off)
                }
            }
            .accessibilityIdentifier("settingsKioskMode")
        }
    }

    private var aboutSection: some View {
        Section(Localization.about) {
            LabeledContent {
                HStack(spacing: Mortar.Spacing.s) {
                    Text(Bundle.main.appVersion)
                    if updateNudge.availableUpdate != nil {
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            } label: {
                Text(Localization.version)
                if let update = updateNudge.availableUpdate {
                    Text(update.label)
                        .font(.caption)
                        .foregroundStyle(Color.warning)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if let update = updateNudge.availableUpdate {
                    presentedUpdate = update
                } else {
                    viewModel.versionTapped()
                }
            }
            .accessibilityAddTraits(updateNudge.availableUpdate == nil ? [] : .isButton)
            .sheet(item: $presentedUpdate) { update in
                UpdateSheet(update: update, installedVersion: Bundle.main.appVersion) {
                    updateNudge.skip()
                    presentedUpdate = nil
                }
            }
            NavigationLink(Localization.acknowledgements) {
                AcknowledgementsView()
            }
            .accessibilityIdentifier("settingsAcknowledgements")
            #if DEBUG
            NavigationLink {
                DebugPanelContentView()
            } label: {
                Label(Localization.debugPanel, systemImage: "ladybug")
            }
            #endif
        }
    }
}

private extension SettingsView {
    enum Localization {
        static let settings = String(localized: "Settings", comment: "Navigation title for the settings screen")
        static let close = String(localized: "Close", comment: "Button to dismiss the settings screen")
        static let done = String(localized: "Done", comment: "Button to dismiss the current screen")
        static let cancel = String(localized: "Cancel", comment: "Button to cancel the current action")

        // Account
        static let account = String(localized: "Account", comment: "Title of the account page and its section header in settings")
        static let name = String(localized: "Name", comment: "Label for the signed-in user's name on the account page")
        static let role = String(localized: "Role", comment: "Label for the signed-in user's Home Assistant role on the account page")

        // Demo
        static let exitDemo = String(localized: "Exit Demo", comment: "Destructive button to leave demo mode")
        static let exitDemoQuestion = String(localized: "Exit Demo?", comment: "Alert title confirming exit from demo mode")
        static let exitDemoMessage = String(localized: "Return to the welcome screen to connect to your Home Assistant server.", comment: "Alert message explaining what happens when exiting demo mode")

        // Server section
        static let server = String(localized: "Server", comment: "Settings section header for server connection details")
        static let url = String(localized: "URL", comment: "Label for the server URL in settings")
        static let version = String(localized: "Version", comment: "Label for the version in settings")
        static let openServer = String(localized: "Open Home Assistant", comment: "Button to open the Home Assistant web interface")

        // Logout
        static let logOut = String(localized: "Log Out", comment: "Destructive button to log out of the server")
        static let logOutQuestion = String(localized: "Log Out?", comment: "Alert title confirming logout")
        static let logOutMessage = String(localized: "This will remove all local data including your Home layout.", comment: "Alert message explaining logout will delete local data")
        static func logOutMessageWithHost(_ host: String) -> String {
            String(localized: "Log out of \(host)? This will remove all local data including your Home layout.", comment: "Alert message explaining logout will delete local data, with the server hostname")
        }

        // Appearance
        static let appearance = String(localized: "Appearance", comment: "Settings section header for the app's theme")
        static let theme = String(localized: "Theme", comment: "Settings row that opens the theme editor")
        static let appearanceReadOnly = String(
            localized: "These settings were saved by a newer version of Hemera, so they can't be changed here. Update Hemera to change them.",
            comment: "Footer under the Theme row when stored settings came from a newer build, so changes cannot be saved"
        )

        // Kiosk Mode
        static let kioskMode = String(localized: "Kiosk Mode", comment: "Settings section header and navigation link for kiosk mode (stay awake, screensaver)")
        static let on = String(localized: "On", comment: "Status label indicating a setting is enabled")
        static let off = String(localized: "Off", comment: "Status label indicating a setting is disabled")

        // About
        static let about = String(localized: "About", comment: "Settings section header for app information")
        static let acknowledgements = String(localized: "Acknowledgements", comment: "Navigation link to the open-source acknowledgements screen")
        static let debugPanel = String(localized: "Debug Panel", comment: "Button to open the debug panel from settings (debug builds only)")
    }
}

#if DEBUG
#Preview {
    ServiceLocator.configureForPreview()
    return SettingsView(viewModel: SettingsViewModel())
}

#Preview("Account") {
    ServiceLocator.configureForPreview()
    let sl = ServiceLocator.shared
    return SettingsView(viewModel: SettingsViewModel(
        authManager: sl.authManager,
        demoCoordinator: sl.demoCoordinator,
        screenManager: sl.screenManager,
        restClient: nil,
        homeProfile: HomeProfile(
            homeName: "Hemera Home",
            account: Account(name: "Alex Morgan", role: .admin, pictureURL: nil)
        ),
        initialRoute: .account
    ))
}
#endif
