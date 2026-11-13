import SwiftUI

struct OnboardingFlow: View {

    @State private var path = NavigationPath()
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeView { path.append(OnboardingDestination.serverSelection) }
                .navigationDestination(for: OnboardingDestination.self) { destination in
                    switch destination {
                    case .serverSelection:
                        OnboardingView(theme: themeManager)
                    }
                }
        }
    }
}

enum OnboardingDestination: Hashable {
    case serverSelection
}
