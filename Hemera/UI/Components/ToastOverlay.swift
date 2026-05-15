import SwiftUI
import Mortar

/// Displays transient error toasts at the bottom of the screen.
///
/// Mounted once at `RootView` level. Observes `ErrorNotifier` and
/// renders a capsule-shaped pill that auto-dismisses after 3 seconds.
struct ToastOverlay: View {

    let notifier: ErrorNotifier

    var body: some View {
        VStack {
            Spacer()

            if let toast = notifier.currentToast {
                HStack(spacing: Mortar.Spacing.s) {
                    Image(systemName: toast.icon)
                        .foregroundStyle(.white)
                    Text(toast.message)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, Mortar.Spacing.l)
                .padding(.vertical, Mortar.Spacing.m)
                .background {
                    Capsule()
                        .fill(.red.opacity(0.85))
                        .mortarShadow(.medium)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onTapGesture {
                    notifier.dismiss()
                }
                .padding(.bottom, Mortar.Spacing.xxl)
            }
        }
        .animation(Mortar.Motion.springNormal, value: notifier.currentToast?.id)
    }
}
