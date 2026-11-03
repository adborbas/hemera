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
    @State private var buttonsWidth: CGFloat = 0
    @State private var collapseDistance: CGFloat = 0

    @Environment(ScreenManager.self) private var screenManager
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

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
                top: safeAreaInsets.top + (isFeedEditing ? 0 : headerHeight),
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
            // Editing brings up the system bar for the feed's toolbar, so the header steps aside.
            if !isFeedEditing {
                HeaderOffset(scroll: headerScroll) {
                    FeedHeader(
                        title: viewModel.title,
                        pills: viewModel.pills,
                        unpinnedFeeds: viewModel.unpinnedFeeds,
                        selection: viewModel.selectedFeed,
                        onSelect: select,
                        onPin: viewModel.pin,
                        onUnpin: viewModel.unpin,
                        scroll: headerScroll,
                        buttonsWidth: buttonsWidth,
                        onCollapseDistanceChange: { collapseDistance = $0 }
                    )
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0 }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        // Ours, not the system bar's: that bar takes every touch in its row, collapsed pills included.
        .overlay(alignment: .topTrailing) {
            if !isFeedEditing {
                HeaderButtons(
                    actions: toolbarActions,
                    account: viewModel.homeProfile.account,
                    perform: { viewModel.resolver.actionHandler(for: viewModel.selectedFeed)?.perform($0, item: $1) },
                    openSettings: { showSettings = true }
                )
                .padding(.trailing, Mortar.Spacing.l)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { buttonsWidth = $0 }
                .transition(.opacity)
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
        // Animated here, so the header, buttons, bar and margins move in one transaction.
        .onPreferenceChange(FeedIsEditingKey.self) { editing in
            withAnimation(reduceMotion ? nil : Mortar.Motion.springNormal) { isFeedEditing = editing }
        }
        .onChange(of: collapseDistance, initial: true) { headerScroll.hideRange = $1 }
        .onChange(of: headerCanHide, initial: true) { headerScroll.canHide = headerCanHide }
        .onChange(of: viewModel.selectedFeed) { headerScroll.reset() }
        // Copied in an animated transaction so the glass morphs; selection changes aren't animated.
        .onChange(of: viewModel.resolver.actions(for: viewModel.selectedFeed), initial: true) { _, actions in
            withAnimation(reduceMotion ? nil : Mortar.Motion.springNormal) { toolbarActions = actions }
        }
        .onChange(of: viewModel.pills.map(\.id)) { viewModel.reselectHomeIfSelectionIsHidden() }
        .toolbar(isFeedEditing ? .visible : .hidden, for: .navigationBar)
        .environment(\.openFeed, select)
    }

    /// Wide layouts have room to spare, so the header stays expanded there.
    private var headerCanHide: Bool {
        horizontalSizeClass == .compact && !voiceOverEnabled && !reduceMotion && !isFeedEditing
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

// MARK: - Header Buttons

/// The feed's actions and the account button, sharing one glass capsule only while there are actions.
private struct HeaderButtons: View {
    let actions: [FeedAction]
    let account: Account?
    let perform: (_ actionID: String, _ item: String?) -> Void
    let openSettings: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            if !actions.isEmpty {
                HStack(spacing: 0) {
                    ForEach(actions) { action in
                        FeedActionButton(action: action) { perform(action.id, $0) }
                    }
                }
                .tint(.primary)
                .padding(.horizontal, Mortar.Spacing.xxs)
            }
            AccountButton(account: account, action: openSettings)
        }
        .modifier(GlassCapsule(isActive: !actions.isEmpty))
    }
}

// MARK: - Account Button

private struct AccountButton: View {
    let account: Account?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            AccountAvatar(account: account, size: Constants.avatarSize)
                .frame(width: Mortar.TapTarget.minimum, height: Mortar.TapTarget.minimum)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
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
