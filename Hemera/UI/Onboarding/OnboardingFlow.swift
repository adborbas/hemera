import SwiftUI

struct OnboardingFlow: View {

    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeView()
                .navigationDestination(for: OnboardingDestination.self) { destination in
                    switch destination {
                    case .serverSelection:
                        OnboardingView()
                    }
                }
        }
    }
}

enum OnboardingDestination: Hashable {
    case serverSelection
}
