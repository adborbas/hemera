import SwiftUI
import Mortar

/// The Server step's content: discovered servers, and a way to type an address instead.
struct ServerListView: View {

    let viewModel: ServerSelectionViewModel
    let onSelect: (URL) -> Void
    let onEnterManually: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Mortar.Spacing.s) {
                discoveryContent
                manualEntryRow
            }
            .padding(.horizontal, Mortar.Spacing.l)
            .padding(.top, Mortar.Spacing.s)
        }
        .onAppear { viewModel.startDiscovery() }
        .onDisappear { viewModel.stopDiscovery() }
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
            action: { onSelect(server.url) }
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
            action: onEnterManually
        ) {
            DisclosureIndicator()
        }
        .accessibilityIdentifier("serverEnterManually")
    }
}

// MARK: - Localization

private extension ServerListView {
    enum Localization {
        static let scanning = String(localized: "Looking for servers…", comment: "Status text shown while scanning for Home Assistant servers via Bonjour")
        static let noServersTitle = String(localized: "No servers found", comment: "Title when no Home Assistant servers are discovered")
        static let noServersMessage = String(
            localized: "Check you're on the same Wi-Fi as Home Assistant, or enter its address below.",
            comment: "Shown when no Home Assistant servers are discovered; tapping it scans again"
        )
        static let enterManually = String(localized: "Enter address manually", comment: "Row label to open manual server address entry")
        static let enterManuallySubtitle = String(localized: "Type your server URL", comment: "Subtitle for manual entry row")
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Servers Found") {
    ServerListView(viewModel: .previewWithServers, onSelect: { _ in }, onEnterManually: {})
}

#Preview("Scanning") {
    ServerListView(viewModel: .previewScanning, onSelect: { _ in }, onEnterManually: {})
}

#Preview("Empty") {
    ServerListView(viewModel: .previewEmpty, onSelect: { _ in }, onEnterManually: {})
}
#endif
