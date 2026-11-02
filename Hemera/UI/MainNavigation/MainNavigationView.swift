import SwiftUI
import Mortar

/// The authenticated root: feeds paged under a floating header, switched by pills.
struct MainNavigationView: View {

    @State private var viewModel: MainNavigationViewModel
    @State private var safeAreaInsets = EdgeInsets()
    @State private var headerHeight: CGFloat = 0
    @State private var isFeedEditing = false
    @State private var showSettings = false
    @State private var settingsInitialRoute: SettingsViewModel.Route?
    @State private var headerScroll = FeedHeaderScroll()

    @Environment(ScreenManager.self) private var screenManager
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(session: Session) {
        _viewModel = State(initialValue: MainNavigationViewModel(
            resolver: session.feedResolver,
            connectionStatusProvider: session.connectionStatusProvider
        ))
    }

    var body: some View {
        NavigationStack {
            viewModel.resolver.registerNavigationDestinations(on: AnyView(feeds))
        }
        .sheet(isPresented: $showSettings, onDismiss: {
            settingsInitialRoute = nil
            screenManager.acknowledgeSettingsDismissed()
        }) {
            SettingsView(viewModel: SettingsViewModel(initialRoute: settingsInitialRoute))
        }
        .onChange(of: screenManager.settingsRequest) { _, new in
            switch new {
            case .close:
                showSettings = false
            case .openKioskMode:
                settingsInitialRoute = .kioskMode
                showSettings = true
                screenManager.acknowledgeSettingsOpened()
            case .none:
                break
            }
        }
    }

    private var feeds: some View {
        FeedPager(
            feeds: viewModel.pills.map(\.id),
            selection: $viewModel.selectedFeed,
            contentMargins: EdgeInsets(
                top: safeAreaInsets.top + headerHeight,
                leading: 0,
                bottom: safeAreaInsets.bottom,
                trailing: 0
            ),
            page: { id in
                AnyView(viewModel.resolver.view(for: id)
                    .environment(\.feedHeaderScroll, id == viewModel.selectedFeed ? headerScroll : nil))
            }
        )
        .ignoresSafeArea()
        .onGeometryChange(for: EdgeInsets.self) { $0.safeAreaInsets } action: { safeAreaInsets = $0 }
        .overlay(alignment: .top) {
            HeaderOffset(scroll: headerScroll) {
                FeedHeader(
                    title: Localization.title,
                    pills: viewModel.pills,
                    selection: viewModel.selectedFeed,
                    onSelect: select
                )
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0 }
            }
        }
        .overlay(alignment: .topTrailing) {
            if !isFeedEditing {
                AccountButton { showSettings = true }
                    .padding(.trailing, Mortar.Spacing.s)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if viewModel.showOfflineBanner {
                OfflineBanner()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(Mortar.Motion.springNormal, value: viewModel.showOfflineBanner)
        .onChange(of: viewModel.isConnected, initial: true) {
            viewModel.updateBannerVisibility()
        }
        .onPreferenceChange(FeedIsEditingKey.self) { isFeedEditing = $0 }
        .onChange(of: safeAreaInsets.top + headerHeight, initial: true) { headerScroll.hideRange = $1 }
        .onChange(of: headerCanHide, initial: true) { headerScroll.canHide = headerCanHide }
        .onChange(of: viewModel.selectedFeed) { headerScroll.reset() }
        .toolbar(isFeedEditing ? .visible : .hidden, for: .navigationBar)
        .environment(\.openFeed, select)
    }

    private var headerCanHide: Bool {
        !voiceOverEnabled && !reduceMotion && !isFeedEditing
    }

    private func select(_ id: FeedID) {
        viewModel.selectedFeed = id
    }
}

// MARK: - Header Offset

/// Reads the per-frame offset itself so scrolling redraws only the header.
private struct HeaderOffset<Content: View>: View {
    let scroll: FeedHeaderScroll
    @ViewBuilder let content: Content

    var body: some View {
        content.offset(y: -scroll.hiddenAmount)
    }
}

// MARK: - Account Button

private struct AccountButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "person.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: Constants.avatarSize, height: Constants.avatarSize)
                .background(
                    LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: .circle
                )
                .frame(width: Mortar.TapTarget.minimum, height: Mortar.TapTarget.minimum)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Localization.accountAndSettings)
    }

    private enum Constants {
        static let avatarSize: CGFloat = 32
    }
}

// MARK: - Offline Banner

private struct OfflineBanner: View {
    var body: some View {
        HStack(spacing: Mortar.Spacing.xs) {
            Image(systemName: "wifi.slash")
            Text(Localization.noConnection)
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Mortar.Spacing.xs)
        .background(.ultraThinMaterial)
    }
}

private extension MainNavigationView {
    enum Localization {
        static let title = String(localized: "Home", comment: "Large title above the feeds on the main screen")
    }
}

private extension AccountButton {
    enum Localization {
        static let accountAndSettings = String(
            localized: "Account and Settings",
            comment: "Accessibility label for the avatar button that opens Settings"
        )
    }
}

private extension OfflineBanner {
    enum Localization {
        static let noConnection = String(
            localized: "No connection",
            comment: "Banner shown on the dashboard when the Home Assistant server is unreachable"
        )
    }
}
