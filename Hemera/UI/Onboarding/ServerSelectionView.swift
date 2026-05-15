import SwiftUI
import Mortar

struct ServerSelectionView: View {

    @Bindable var viewModel: ServerSelectionViewModel
    @State private var activeSheet: ActiveSheet?
    @State private var isExchangingToken = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Mortar.Spacing.s) {
                discoveryContent
                manualEntryRow
            }
            .padding(.horizontal, Mortar.Spacing.xl)
            .padding(.top, Mortar.Spacing.s)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(Localization.title)
        .navigationBarTitleDisplayMode(.large)
        .onAppear { viewModel.startDiscovery() }
        .onDisappear { viewModel.stopDiscovery() }
        .alert(Localization.unencryptedTitle, isPresented: $viewModel.showHTTPWarning) {
            Button(Localization.continueAction) {
                viewModel.confirmHTTPConnection()
            }
            .keyboardShortcut(.defaultAction)
            Button(Localization.cancel, role: .cancel) {
                viewModel.cancelHTTPWarning()
            }
        } message: {
            Text(Localization.unencryptedMessage)
        }
        .sheet(item: $activeSheet, onDismiss: {
            if viewModel.authSession != nil {
                viewModel.cancelAuth()
            }
        }) { sheet in
            switch sheet {
            case .manualEntry:
                ManualEntrySheet(viewModel: viewModel) {
                    activeSheet = nil
                }
            case .oAuth(let session):
                NavigationStack {
                    OAuthWebView(url: session.authorizeURL, redirectURI: session.redirectURI) { callbackURL in
                        let captured = session
                        viewModel.authSession = nil
                        isExchangingToken = true
                        Task {
                            await viewModel.handleOAuthCallback(url: callbackURL, session: captured)
                            isExchangingToken = false
                            activeSheet = nil
                        }
                    }
                    .ignoresSafeArea()
                    .overlay {
                        if isExchangingToken {
                            ZStack {
                                Color(uiColor: .systemBackground)
                                    .ignoresSafeArea()
                                ProgressView()
                                    .controlSize(.large)
                            }
                        }
                    }
                    .navigationTitle(Localization.signIn)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(Localization.cancel) {
                                viewModel.cancelAuth()
                                activeSheet = nil
                            }
                            .opacity(isExchangingToken ? 0 : 1)
                        }
                    }
                }
            }
        }
        .onChange(of: viewModel.authSession?.id) {
            if let session = viewModel.authSession {
                activeSheet = .oAuth(session)
            }
        }
    }

    // MARK: - Discovery Content

    @ViewBuilder
    private var discoveryContent: some View {
        switch viewModel.discoveryState {
        case .scanning:
            HStack(spacing: Mortar.Spacing.m) {
                ProgressView()
                Text(Localization.scanning)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Mortar.Spacing.xxl)
            .padding(.horizontal, Mortar.Spacing.l)
            .cardBackground()
        case .empty:
            CardRow(
                iconName: "wifi.exclamationmark",
                iconColor: PlatformColor.systemGray3,
                title: Localization.noServersTitle,
                subtitle: Localization.noServersMessage,
                action: { viewModel.startDiscovery() }
            ) {
                Image(systemName: "arrow.clockwise")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
        case .found:
            ForEach(viewModel.discovery.servers) { server in
                serverCard(server)
            }
            .animation(Mortar.Motion.springBouncy, value: viewModel.discovery.servers.count)
        }
    }

    // MARK: - Server Card

    private func serverCard(_ server: DiscoveredServer) -> some View {
        CardRow(
            iconName: "server.rack",
            iconColor: .green,
            title: server.name,
            subtitle: server.host,
            action: { viewModel.connect(to: server.url) }
        ) {
            if viewModel.isConnecting {
                ProgressView()
            } else {
                DisclosureIndicator()
            }
        }
        .disabled(viewModel.isConnecting)
    }

    // MARK: - Manual Entry Row

    private var manualEntryRow: some View {
        CardRow(
            iconName: "keyboard",
            iconColor: .blue,
            title: Localization.enterManually,
            subtitle: Localization.enterManuallySubtitle,
            action: { activeSheet = .manualEntry }
        ) {
            DisclosureIndicator()
        }
    }
}

// MARK: - Active Sheet

private extension ServerSelectionView {
    enum ActiveSheet: Identifiable {
        case manualEntry
        case oAuth(OAuthFlowManager.AuthSession)

        var id: String {
            switch self {
            case .manualEntry: "manualEntry"
            case .oAuth: "oAuth"
            }
        }
    }
}

// MARK: - Localization

private extension ServerSelectionView {
    enum Localization {
        static let title = String(localized: "Connect to Server", comment: "Navigation title for the server connection screen")
        static let signIn = String(localized: "Sign In", comment: "Navigation title for the OAuth sign-in screen")
        static let cancel = String(localized: "Cancel", comment: "Button to cancel the current action")

        // Discovery
        static let scanning = String(localized: "Looking for servers on your network…", comment: "Status text shown while scanning for Home Assistant servers via Bonjour")
        static let noServersTitle = String(localized: "No servers found", comment: "Title when no Home Assistant servers are discovered")
        static let noServersMessage = String(localized: "Tap to scan again", comment: "Subtitle prompting user to retry server discovery")

        // Manual entry row
        static let enterManually = String(localized: "Enter address manually", comment: "Row label to open manual server address entry")
        static let enterManuallySubtitle = String(localized: "Type your server URL", comment: "Subtitle for manual entry row")

        // HTTP warning
        static let unencryptedTitle = String(localized: "Unencrypted Connection", comment: "Alert title warning about HTTP connection without encryption")
        static let unencryptedMessage = String(localized: "This connection is not encrypted. For better security, use HTTPS.", comment: "Alert message explaining the security risk of HTTP connections")
        static let continueAction = String(localized: "Continue", comment: "Button to proceed with unencrypted HTTP connection")
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Servers Found") {
    NavigationStack {
        ServerSelectionView(viewModel: .previewWithServers)
    }
}

#Preview("Scanning") {
    NavigationStack {
        ServerSelectionView(viewModel: .previewScanning)
    }
}

#Preview("Empty") {
    NavigationStack {
        ServerSelectionView(viewModel: .previewEmpty)
    }
}
#endif
