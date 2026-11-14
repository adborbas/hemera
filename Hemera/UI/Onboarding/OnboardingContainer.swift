import SwiftUI
import Mortar

enum OnboardingLayout {
    static let maxContentWidth: CGFloat = 640
    static let pushDuration: Double = 0.35
}

/// The frame every onboarding page shares. Only the title, subtitle and content move between pages.
struct OnboardingContainer<Content: View, TitleAccessory: View>: View {

    let coordinator: OnboardingCoordinator
    let title: String
    let subtitle: String
    /// Grid steps span the screen, so they show what Home will look like.
    var fillsWidth = false
    /// Laid out hidden under the title and subtitle, so pages sharing the frame keep one height.
    var reservedText: (title: String, subtitle: String)?
    @ViewBuilder let content: Content
    @ViewBuilder let titleAccessory: TitleAccessory

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var width: CGFloat = 0

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: Mortar.Spacing.xs) {
                    HStack {
                        ZStack(alignment: .leading) {
                            if let reservedText { Text(reservedText.title).hidden() }
                            Text(title).id(title).transition(.opacity)
                        }
                        .font(.title2.bold())
                        Spacer()
                        titleAccessory
                    }
                    ZStack(alignment: .topLeading) {
                        if let reservedText { Text(reservedText.subtitle).hidden() }
                        Text(subtitle).id(subtitle).transition(.opacity)
                    }
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Mortar.Spacing.l)
                .padding(.bottom, Mortar.Spacing.s)

                content
                    .frame(maxHeight: .infinity, alignment: .top)
            }
            .frame(maxWidth: fillsWidth ? .infinity : OnboardingLayout.maxContentWidth)
            .frame(maxWidth: .infinity)
            .id(coordinator.contentPage.pushIdentity)
            .transition(pageTransition)
        }
        // Outside the moving page, so the button stays put and only its label changes.
        .safeAreaInset(edge: .bottom) { bottomButton }
        .animation(.smooth(duration: OnboardingLayout.pushDuration), value: coordinator.contentPage)
        .onGeometryChange(for: CGFloat.self, of: \.size.width) { width = $0 }
        .navigationBarTitleDisplayMode(.inline)
        // The first page keeps the system Back, which returns to the Welcome screen.
        .navigationBarBackButtonHidden(coordinator.canGoBack)
        .toolbar { header }
    }

    private var header: OnboardingHeader {
        OnboardingHeader(
            progress: coordinator.progress,
            stepCount: OnboardingCoordinator.stepCount,
            width: width,
            onBack: coordinator.canGoBack ? { coordinator.back() } : nil,
            trailingAction: coordinator.trailingAction
        )
    }

    @ViewBuilder
    private var bottomButton: some View {
        if let button = coordinator.bottomButton {
            MortarButton(button.title, width: .fullWidth, isLoading: button.isLoading) {
                Task { await coordinator.bottomButtonTapped() }
            }
            .disabled(!button.isEnabled)
            .accessibilityIdentifier("onboardingBottomButton")
            .frame(maxWidth: horizontalSizeClass == .regular ? Mortar.ContentWidth.narrow : .infinity)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Mortar.Spacing.l)
            .padding(.vertical, Mortar.Spacing.s)
            .transition(.opacity)
        }
    }

    private var pageTransition: AnyTransition {
        let isForward = coordinator.isForward
        return .asymmetric(
            insertion: .move(edge: isForward ? .trailing : .leading),
            removal: .move(edge: isForward ? .leading : .trailing)
        )
    }
}
