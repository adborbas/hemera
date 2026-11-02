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
    @State private var toolbarActions: [FeedAction] = []

    @Environment(ScreenManager.self) private var screenManager
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(session: Session) {
        _viewModel = State(initialValue: MainNavigationViewModel(
            resolver: session.feedResolver,
            store: ServiceLocator.shared.settingsStore,
            homeProfile: session.homeProfile,
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
                    .environment(\.feedHeaderScroll, id == viewModel.selectedFeed ? headerScroll : nil)
                    .environment(\.isSelectedFeed, id == viewModel.selectedFeed)
                    // Neighbour pages stay alive; only the page on screen may switch to its editing bar.
                    .transformPreference(FeedIsEditingKey.self) { if id != viewModel.selectedFeed { $0 = false } })
            }
        )
        .ignoresSafeArea()
        .onGeometryChange(for: EdgeInsets.self) { $0.safeAreaInsets } action: { safeAreaInsets = $0 }
        .overlay(alignment: .top) {
            HeaderOffset(scroll: headerScroll) {
                FeedHeader(
                    title: viewModel.title,
                    pills: viewModel.pills,
                    unpinnedFeeds: viewModel.unpinnedFeeds,
                    selection: viewModel.selectedFeed,
                    onSelect: select,
                    onPin: viewModel.pin,
                    onUnpin: viewModel.unpin
                )
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0 }
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
        // Copied in an animated transaction so the bar's group morphs; selection changes aren't animated.
        .onChange(of: viewModel.resolver.actions(for: viewModel.selectedFeed), initial: true) { _, actions in
            withAnimation(reduceMotion ? nil : Mortar.Motion.springNormal) { toolbarActions = actions }
        }
        .onChange(of: viewModel.pills.map(\.id)) { viewModel.reselectHomeIfSelectionIsHidden() }
        // Always shown, so its inset never changes; one group makes the actions and avatar share one glass.
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            if !isFeedEditing {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    ForEach(toolbarActions) { action in
                        FeedActionButton(action: action) { item in
                            viewModel.resolver.actionHandler(for: viewModel.selectedFeed)?.perform(action.id, item: item)
                        }
                    }
                    AccountButton(account: viewModel.homeProfile.account) { showSettings = true }
                }
            }
        }
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
    let account: Account?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            AccountAvatar(account: account, size: Constants.avatarSize)
        }
        .accessibilityLabel(Localization.accountAndSettings)
        .accessibilityValue(account?.name ?? "")
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
