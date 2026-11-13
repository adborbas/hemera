import SwiftUI
import Mortar

/// Onboarding's toolbar: Back, the progress bar, and an optional trailing action.
struct OnboardingHeader: ToolbarContent {

    struct Action {
        let title: String
        let systemImage: String
        let isEnabled: Bool
        let perform: () -> Void
    }

    let progress: Double
    let stepCount: Int
    /// The width of the screen the toolbar spans.
    let width: CGFloat
    /// `nil` hides Back.
    var onBack: (() -> Void)?
    var trailingAction: Action?

    var body: some ToolbarContent {
        if let onBack {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: onBack) {
                    Label(Localization.back, systemImage: "chevron.backward")
                        .labelStyle(.iconOnly)
                }
                .accessibilityIdentifier("onboardingBack")
            }
        }
        ToolbarItem(placement: .principal) {
            ProgressView(value: progress, total: Double(stepCount))
                .progressViewStyle(.linear)
                .tint(.primary)
                .frame(width: progressWidth)
                .animation(Mortar.Motion.springNormal, value: progress)
                .accessibilityLabel(Localization.progress)
                .accessibilityValue(Localization.step(Int(progress), of: stepCount))
        }
        if let trailingAction {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: trailingAction.perform) {
                    Label(trailingAction.title, systemImage: trailingAction.systemImage)
                        .labelStyle(.iconOnly)
                }
                .disabled(!trailingAction.isEnabled)
            }
        }
    }

    /// Sized as if both sides had a button: the toolbar centres it only while it fits.
    private var progressWidth: CGFloat {
        let side = Mortar.Spacing.l + Mortar.TapTarget.minimum + Mortar.Spacing.l
        return min(max(width - 2 * side, 0), OnboardingLayout.maxContentWidth)
    }
}

// MARK: - Localization

private extension OnboardingHeader {
    enum Localization {
        static let back = String(localized: "Back", comment: "Button returning to the previous onboarding page")
        static let progress = String(
            localized: "Setup progress",
            comment: "Accessibility label of the progress bar at the top of the onboarding screens"
        )
        static func step(_ step: Int, of total: Int) -> String {
            String(
                localized: "Step \(step) of \(total)",
                comment: "Accessibility value of the onboarding progress bar, e.g. Step 1 of 2"
            )
        }
    }
}
