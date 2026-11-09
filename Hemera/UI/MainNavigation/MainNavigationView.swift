import SwiftUI
import Mortar

/**
 The authenticated root: one feed under the screen header in compact width, paged feeds under pills
 in regular width. Both are roots of one stack, so a size-class change keeps the pushed screens.
*/
struct MainNavigationView: View {

    @State private var viewModel: MainNavigationViewModel
    @State private var safeAreaInsets = EdgeInsets()
    @State private var headerHeight: CGFloat = 0
    @State private var isFeedEditing = false
    @State private var showSettings = false
    @State private var settingsInitialRoute: SettingsViewModel.Route?
    @State private var toolbarActions: [FeedAction] = []

    @Environment(ScreenManager.self) private var screenManager
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
        NavigationStack(path: $viewModel.path) {
            viewModel.resolver.registerNavigationDestinations(on: AnyView(root))
        }
        .accessibilityHidden(viewModel.isDrawerOpen)
        .overlay {
            if horizontalSizeClass == .compact {
                FeedDrawer(
                    title: viewModel.title,
                    feeds: viewModel.pills,
                    subtitle: viewModel.resolver.subtitle(for:),
                    selection: viewModel.selectedFeed,
                    isOpen: $viewModel.isDrawerOpen,
                    canSwipeOpen: viewModel.path.isEmpty && !isFeedEditing,
                    onSelect: viewModel.select,
                    openSettings: { showSettings = true }
                )
            }
        }
        .onChange(of: horizontalSizeClass) { viewModel.isDrawerOpen = false }
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

    private var root: some View {
        Group {
            if horizontalSizeClass == .compact {
                feed
            } else {
                feeds
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
        // Copied in an animated transaction so the glass morphs; selection changes aren't animated.
        .onChange(of: viewModel.resolver.actions(for: viewModel.selectedFeed), initial: true) { _, actions in
            withAnimation(reduceMotion ? nil : Mortar.Motion.springNormal) { toolbarActions = actions }
        }
        .onChange(of: viewModel.pills.map(\.id)) { viewModel.reselectHomeIfSelectionIsHidden() }
        .environment(\.openFeed, viewModel.select)
    }

    /// Compact width: the selected feed alone, its name as the title and the avatar where back would be.
    private var feed: some View {
        viewModel.resolver.view(for: viewModel.selectedFeed)
            .pushedScreenHeader(
                viewModel.resolver.summary(for: viewModel.selectedFeed)?.title ?? viewModel.title,
                leading: .account(viewModel.homeProfile.account, action: openDrawer),
                isEditing: isFeedEditing,
                actions: toolbarActions,
                perform: perform
            )
            // A fresh header per feed, so a new feed starts expanded.
            .id(viewModel.selectedFeed)
    }

    /// Regular width: feeds paged under the pill header, which never collapses there.
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
                FeedHeader(
                    title: viewModel.title,
                    pills: viewModel.pills,
                    selection: viewModel.selectedFeed,
                    onSelect: viewModel.select
                ) {
                    HeaderButtons(
                        actions: toolbarActions,
                        account: viewModel.homeProfile.account,
                        perform: perform,
                        openSettings: { showSettings = true }
                    )
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0 }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .toolbar(isFeedEditing ? .visible : .hidden, for: .navigationBar)
    }

    private func perform(_ actionID: String, _ item: String?) {
        viewModel.resolver.actionHandler(for: viewModel.selectedFeed)?.perform(actionID, item: item)
    }

    private func openDrawer() {
        viewModel.isDrawerOpen = true
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
                FeedActionButtons(actions: actions, perform: perform)
            }
            AccountButton(account: account, action: openSettings)
        }
        .mortarGlass(isActive: !actions.isEmpty)
    }
}

// MARK: - Account Button

struct AccountButton: View {
    let account: Account?
    let action: () -> Void
    /// Compact width's avatar opens the side menu instead of Settings.
    var opensMenu = false

    @Environment(UpdateNudge.self) private var updateNudge

    var body: some View {
        Button(action: action) {
            AccountAvatar(account: account, size: Mortar.AvatarSize.s)
                .overlay(alignment: .topTrailing) {
                    if updateNudge.availableUpdate != nil { UpdateDot() }
                }
                .frame(width: Mortar.TapTarget.minimum, height: Mortar.TapTarget.minimum)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(opensMenu ? Localization.menu : Localization.accountAndSettings)
        .accessibilityValue([account?.name, updateNudge.availableUpdate?.label].compactMap(\.self).joined(separator: ", "))
        .accessibilityIdentifier("accountButton")
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
        static let menu = String(
            localized: "Menu",
            comment: "Accessibility label for the avatar button that opens the side menu of feeds and Settings"
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
