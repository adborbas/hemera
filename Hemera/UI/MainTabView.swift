import SwiftUI
import SwiftData
import Mortar

struct MainTabView: View {

    @State private var selectedTab: Tab
    @Environment(ScreenManager.self) private var screenManager

    let viewModel: MainTabViewModel
    private let tabViewModels: TabViewModels

    init(viewModel: MainTabViewModel) {
        self.viewModel = viewModel
        _selectedTab = State(initialValue: viewModel.hasHomeTiles ? .home : .areas)

        guard let vms = ServiceLocator.shared.appCoordinator?.tabViewModels else {
            preconditionFailure("MainTabView requires AppCoordinator to have built tab VMs")
        }
        self.tabViewModels = vms
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            CuratedHomeView(viewModel: tabViewModels.curatedHome)
                .tabItem {
                    Label(Localization.home, systemImage: "house")
                }
                .tag(Tab.home)
                .accessibilityIdentifier("homeTab")

            AreasView(viewModel: tabViewModels.areas)
                .tabItem {
                    Label(Localization.areas, systemImage: "square.grid.2x2")
                }
                .tag(Tab.areas)
                .accessibilityIdentifier("areasTab")

            SettingsView(viewModel: tabViewModels.settings, presentationContext: .tab)
                .tabItem {
                    Label(Localization.settings, systemImage: "gearshape")
                }
                .tag(Tab.settings)
                .accessibilityIdentifier("settingsTab")
        }
        .safeAreaInset(edge: .bottom) {
            if viewModel.showOfflineBanner {
                OfflineBanner()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(Mortar.Motion.springNormal, value: viewModel.showOfflineBanner)
        .onChange(of: viewModel.isConnected, initial: true) {
            viewModel.updateBannerVisibility()
        }
        .onChange(of: screenManager.settingsRequest) { _, new in
            switch new {
            case .close:
                screenManager.acknowledgeSettingsDismissed()
            case .openKioskMode:
                selectedTab = .settings
                tabViewModels.settings.navigateToRoute(.kioskMode)
                screenManager.acknowledgeSettingsOpened()
            case .none:
                break
            }
        }
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

private extension OfflineBanner {
    enum Localization {
        static let noConnection = String(
            localized: "No connection",
            comment: "Banner shown on the dashboard when the Home Assistant server is unreachable"
        )
    }
}

private extension MainTabView {
    enum Tab: Hashable {
        case home
        case areas
        case settings
    }

    enum Localization {
        static let home = String(localized: "Home", comment: "Tab bar label for the Home screen showing pinned entities")
        static let areas = String(localized: "Areas", comment: "Tab bar label for the Areas screen showing entities grouped by area")
        static let settings = String(localized: "Settings", comment: "Tab bar label for the Settings screen")
    }
}
