import SwiftUI
import Mortar

struct WelcomeView: View {

    var body: some View {
        VStack(spacing: Mortar.Spacing.xxl) {
            Spacer()

            Image(.hemeraLogo)
                .resizable()
                .scaledToFit()
                .frame(height: 80)

            Text(Localization.instructions)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            VStack(spacing: Mortar.Spacing.m) {
                NavigationLink(value: OnboardingDestination.serverSelection) {
                    Text(Localization.getStarted)
                }
                .buttonStyle(.mortarPrimary(width: .fullWidth))
                .accessibilityIdentifier("welcomeGetStarted")
            }

            Spacer()
                .frame(height: Mortar.PanelSpacing.edge)
        }
        .padding(.horizontal, Mortar.Spacing.xl)
        .frame(maxWidth: Mortar.ContentWidth.narrow)
    }
}

private extension WelcomeView {
    enum Localization {
        static let instructions = String(localized: "Connect to your Home Assistant server to get started", comment: "Instructions on the welcome screen")
        static let getStarted = String(localized: "Get Started", comment: "Button on welcome screen to begin server setup")
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        WelcomeView()
    }
}
#endif
