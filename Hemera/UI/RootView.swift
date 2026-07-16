import SwiftData
import SwiftUI

struct RootView: View {

    let router: AppRouter
    let authManager: AuthManager
    @Environment(ScreenManager.self) private var screenManager
    #if DEBUG
    @State private var showDebugPanel = false
    #endif

    var body: some View {
        Group {
            switch router.destination {
            case .onboarding, .connectToServer:
                OnboardingFlow(
                    sessionExpiredMessage: router.sessionExpiredMessage,
                    onTryDemo: {
                        ServiceLocator.shared.demoCoordinator.enter()
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            case .connecting:
                ConnectingView(viewModel: ConnectingViewModel())
            case .authenticated:
                if let session = ServiceLocator.shared.session {
                    MainTabView(viewModel: MainTabViewModel())
                        .modelContainer(session.container)
                        .transaction { $0.animation = nil }
                } else {
                    // Session torn down while destination is briefly still .authenticated.
                    // Render nothing rather than crashing; the router handler will move
                    // destination away from .authenticated on the same runloop turn.
                    Color.clear
                }
            }
        }
        .environment(authManager)
        .environment(router)
        .background {
            WindowActivityTracker {
                screenManager.registerUserActivity()
            }
            DimOverlayWindowInstaller(screenManager: screenManager, isDimmed: screenManager.isDimmed)
        }
        .statusBarHidden(screenManager.isDimmed)
        .animation(.easeInOut(duration: 0.3), value: screenManager.isDimmed)
        .overlay {
            if let notifier = ServiceLocator.shared.session?.errorNotifier {
                ToastOverlay(notifier: notifier)
            }
        }
        #if DEBUG
        .onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
            showDebugPanel = true
        }
        .sheet(isPresented: $showDebugPanel) {
            DebugPanelView()
        }
        #endif
    }
}

// MARK: - Window Activity Tracker

/// Installs a gesture recognizer on the UIWindow to detect all touches,
/// including those inside sheets and other modal presentations.
private struct WindowActivityTracker: UIViewRepresentable {
    var onActivity: () -> Void

    func makeUIView(context: Context) -> WindowActivityInstallerView {
        let view = WindowActivityInstallerView()
        view.onActivity = onActivity
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: WindowActivityInstallerView, context: Context) {
        uiView.onActivity = onActivity
    }
}

private class WindowActivityInstallerView: UIView {
    var onActivity: (() -> Void)?
    private var recognizer: ActivityTrackingGestureRecognizer?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if let window, recognizer == nil {
            let r = ActivityTrackingGestureRecognizer { [weak self] in
                self?.onActivity?()
            }
            window.addGestureRecognizer(r)
            recognizer = r
        } else if window == nil, let r = recognizer {
            r.view?.removeGestureRecognizer(r)
            recognizer = nil
        }
    }
}

private class ActivityTrackingGestureRecognizer: UIGestureRecognizer, UIGestureRecognizerDelegate {
    private let onActivity: () -> Void

    init(onActivity: @escaping () -> Void) {
        self.onActivity = onActivity
        super.init(target: nil, action: nil)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
        delegate = self
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        onActivity()
        state = .failed
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }
}

// MARK: - Dim Overlay Window

/// Presents `DimOverlay` in a separate `UIWindow` above the main window so
/// it renders on top of sheets and other modal presentations.
private struct DimOverlayWindowInstaller: UIViewRepresentable {
    let screenManager: ScreenManager
    let isDimmed: Bool

    func makeUIView(context: Context) -> DimOverlayInstallerView {
        let view = DimOverlayInstallerView()
        view.screenManager = screenManager
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: DimOverlayInstallerView, context: Context) {
        uiView.updateStatusBar(hidden: isDimmed)
    }
}

private class DimOverlayInstallerView: UIView {
    var screenManager: ScreenManager?
    private var dimWindow: DimOverlayWindow?
    private var hostingController: DimOverlayHostingController?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if let windowScene = window?.windowScene, dimWindow == nil, let screenManager {
            let w = DimOverlayWindow(windowScene: windowScene)
            w.screenManager = screenManager
            w.windowLevel = .alert + 1
            w.backgroundColor = .clear

            let host = DimOverlayHostingController(
                rootView: DimOverlayWindowContent(screenManager: screenManager)
            )
            host.view.backgroundColor = .clear
            w.rootViewController = host
            w.isHidden = false

            dimWindow = w
            hostingController = host
        } else if window == nil, let w = dimWindow {
            w.isHidden = true
            w.rootViewController = nil
            dimWindow = nil
            hostingController = nil
        }
    }

    func updateStatusBar(hidden: Bool) {
        hostingController?.statusBarHidden = hidden
    }
}

private final class DimOverlayHostingController: UIHostingController<DimOverlayWindowContent> {
    var statusBarHidden = false {
        didSet {
            guard statusBarHidden != oldValue else { return }
            setNeedsStatusBarAppearanceUpdate()
        }
    }

    override var prefersStatusBarHidden: Bool { statusBarHidden }
}

/// Passes through all touches when the screen is not dimmed.
private final class DimOverlayWindow: UIWindow {
    weak var screenManager: ScreenManager?

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let screenManager, screenManager.isDimmed else { return nil }
        return super.hitTest(point, with: event)
    }
}

private struct DimOverlayWindowContent: View {
    let screenManager: ScreenManager

    var body: some View {
        ZStack {
            if screenManager.isDimmed {
                DimOverlay(clockFormat: screenManager.clockFormat)
                    .transition(.opacity)
                    .onTapGesture {
                        screenManager.registerUserActivity()
                    }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: screenManager.isDimmed)
    }
}
