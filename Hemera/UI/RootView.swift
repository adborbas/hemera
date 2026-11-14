import SwiftData
import SwiftUI

struct RootView: View {

    let router: AppRouter
    let authManager: AuthManager
    @Environment(ScreenManager.self) private var screenManager
    @Environment(ThemeManager.self) private var themeManager
    #if DEBUG
    @State private var showDebugPanel = false
    #endif

    var body: some View {
        Group {
            switch router.destination {
            case .onboarding:
                OnboardingFlow()
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            case .connecting:
                ConnectingView(viewModel: ConnectingViewModel())
            case .sessionExpired:
                SessionExpiredView()
            case .authenticated:
                if let session = ServiceLocator.shared.session {
                    MainNavigationView(session: session)
                        .modelContainer(session.container)
                } else {
                    /**
                     Session torn down while destination is briefly still .authenticated.
                     Render nothing rather than crashing; the router handler will move
                     destination away from .authenticated on the same runloop turn.
                     */
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
            ScreensaverWindowInstaller(
                screenManager: screenManager,
                themeManager: themeManager,
                isScreensaverShown: screenManager.isScreensaverShown
            )
        }
        .statusBarHidden(screenManager.isScreensaverShown)
        .animation(.easeInOut(duration: 0.3), value: screenManager.isScreensaverShown)
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

// MARK: - Screensaver Window

/// Presents `Screensaver` in a separate `UIWindow` above the main window so
/// it renders on top of sheets and other modal presentations.
private struct ScreensaverWindowInstaller: UIViewRepresentable {
    let screenManager: ScreenManager
    let themeManager: ThemeManager
    let isScreensaverShown: Bool

    func makeUIView(context: Context) -> ScreensaverInstallerView {
        let view = ScreensaverInstallerView()
        view.screenManager = screenManager
        view.themeManager = themeManager
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: ScreensaverInstallerView, context: Context) {
        uiView.updateStatusBar(hidden: isScreensaverShown)
    }
}

private class ScreensaverInstallerView: UIView {
    var screenManager: ScreenManager?
    var themeManager: ThemeManager?
    private var screensaverWindow: ScreensaverWindow?
    private var hostingController: ScreensaverHostingController?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if let windowScene = window?.windowScene, screensaverWindow == nil, let screenManager, let themeManager {
            let w = ScreensaverWindow(windowScene: windowScene)
            w.screenManager = screenManager
            w.windowLevel = .alert + 1
            w.backgroundColor = .clear

            let host = ScreensaverHostingController(
                rootView: ScreensaverWindowContent(screenManager: screenManager, themeManager: themeManager)
            )
            host.view.backgroundColor = .clear
            w.rootViewController = host
            w.isHidden = false

            screensaverWindow = w
            hostingController = host
        } else if window == nil, let w = screensaverWindow {
            w.isHidden = true
            w.rootViewController = nil
            screensaverWindow = nil
            hostingController = nil
        }
    }

    func updateStatusBar(hidden: Bool) {
        hostingController?.statusBarHidden = hidden
    }
}

private final class ScreensaverHostingController: UIHostingController<ScreensaverWindowContent> {
    var statusBarHidden = false {
        didSet {
            guard statusBarHidden != oldValue else { return }
            setNeedsStatusBarAppearanceUpdate()
        }
    }

    override var prefersStatusBarHidden: Bool { statusBarHidden }
}

/// Passes through all touches when the screensaver is not shown.
private final class ScreensaverWindow: UIWindow {
    weak var screenManager: ScreenManager?

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let screenManager, screenManager.isScreensaverShown else { return nil }
        return super.hitTest(point, with: event)
    }
}

private struct ScreensaverWindowContent: View {
    let screenManager: ScreenManager
    let themeManager: ThemeManager

    var body: some View {
        ZStack {
            if screenManager.isScreensaverShown {
                Screensaver(clockFormat: screenManager.clockFormat, paint: paint)
                    .transition(.opacity)
                    .onTapGesture {
                        screenManager.registerUserActivity()
                    }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: screenManager.isScreensaverShown)
    }

    private var paint: ThemePaint? {
        guard themeManager.screensaverShowsTheme, case .gradient(let gradient) = themeManager.theme else { return nil }
        return gradient.screensaverPainted
    }
}
