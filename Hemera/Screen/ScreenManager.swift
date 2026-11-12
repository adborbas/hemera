import SwiftUI

enum ClockFormat: Int, CaseIterable, Identifiable, Codable {
    case system = 0
    case twelveHour = 12
    case twentyFourHour = 24

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .system:
            if Locale.current.hourCycle == .zeroToTwentyThree || Locale.current.hourCycle == .oneToTwentyFour {
                String(localized: "System (24-Hour)", comment: "Clock format option that follows the device's locale setting, currently 24-hour")
            } else {
                String(localized: "System (12-Hour)", comment: "Clock format option that follows the device's locale setting, currently 12-hour")
            }
        case .twelveHour:
            String(localized: "12-Hour", comment: "Clock format option for 12-hour time display")
        case .twentyFourHour:
            String(localized: "24-Hour", comment: "Clock format option for 24-hour time display")
        }
    }
}

enum ScreensaverTimeout: Int, CaseIterable, Identifiable, Codable {
    case thirtySeconds = 30
    case oneMinute = 60
    case fiveMinutes = 300

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .thirtySeconds:
            String(localized: "30 Seconds", comment: "Screensaver timeout option for 30 seconds")
        case .oneMinute:
            String(localized: "1 Minute", comment: "Screensaver timeout option for 1 minute")
        case .fiveMinutes:
            String(localized: "5 Minutes", comment: "Screensaver timeout option for 5 minutes")
        }
    }
}

@Observable
@MainActor
final class ScreenManager {

    // MARK: - Settings

    /// Settings came from a newer build, so changes made here will not persist.
    var settingsAreReadOnly: Bool { store.isReadOnly }

    var stayAwake: Bool {
        didSet {
            store.settings.stayAwake = stayAwake
            applyStayAwake()
            if stayAwake {
                resetInactivityTimer()
            } else {
                cancelInactivityTimer()
                if isScreensaverShown { wake() }
            }
        }
    }

    var screensaverTimeout: ScreensaverTimeout {
        didSet {
            store.settings.dimTimeout = screensaverTimeout
            resetInactivityTimer()
        }
    }

    var clockFormat: ClockFormat {
        didSet { store.settings.clockFormat = clockFormat }
    }

    // MARK: - Runtime State

    private(set) var isScreensaverShown = false

    /// Choreography signal for the settings sheet during the screensaver
    /// preview flow. The view binds settings presentation to this signal:
    /// - `.close`: the sheet should dismiss so a pending preview can fire.
    /// - `.openKioskMode`: the sheet should reopen on the kiosk route after
    ///   wake.
    /// - `.none`: no override; user-driven sheet state applies normally.
    private(set) var settingsRequest: SettingsRequest = .none

    private var shouldReopenSettings = false

    enum SettingsRequest: Equatable {
        case none
        case close
        case openKioskMode
    }

    // MARK: - Private

    private var inactivityTimer: Timer?

    private let store: any SettingsStoring

    // MARK: - Init

    init(store: any SettingsStoring) {
        self.store = store
        self.stayAwake = store.settings.stayAwake
        self.screensaverTimeout = store.settings.dimTimeout
        self.clockFormat = store.settings.clockFormat

        applyStayAwake()
        if stayAwake {
            resetInactivityTimer()
        }
    }

    // MARK: - Public

    func resetToDefaults() {
        cancelInactivityTimer()
        if isScreensaverShown { wake() }
        stayAwake = false
        screensaverTimeout = .thirtySeconds
        clockFormat = .system
    }

    /// Asks the view to dismiss the settings sheet so a screensaver preview can
    /// fire. The screensaver starts once the view acknowledges via
    /// `acknowledgeSettingsDismissed()`.
    func requestScreensaverPreview() {
        settingsRequest = .close
    }

    /// Called by the view after the settings sheet has actually closed. If
    /// a screensaver preview was pending, it fires here.
    func acknowledgeSettingsDismissed() {
        guard settingsRequest == .close else { return }
        settingsRequest = .none
        executeScreensaverPreview()
    }

    /// Called by the view after it has reopened the settings sheet for the
    /// kiosk-mode route requested post-wake, so the signal can clear.
    func acknowledgeSettingsOpened() {
        if settingsRequest == .openKioskMode {
            settingsRequest = .none
        }
    }

    /// Direct entrypoint used by tests and the screensaver state machine.
    /// In production the choreography goes through `requestScreensaverPreview()` +
    /// `acknowledgeSettingsDismissed()` so the sheet closes before the screensaver starts.
    func executeScreensaverPreview() {
        shouldReopenSettings = true
        cancelInactivityTimer()
        showScreensaver()
    }

    func registerUserActivity() {
        if isScreensaverShown {
            wake()
        } else if stayAwake {
            resetInactivityTimer()
        }
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            applyStayAwake()
            if stayAwake && !isScreensaverShown {
                resetInactivityTimer()
            }
        case .background:
            cancelInactivityTimer()
            if isScreensaverShown {
                isScreensaverShown = false
            }
        case .inactive:
            /**
             Transient interruptions (Control Center, Notification Center,
             incoming calls) yield `.inactive` without backgrounding the app.
             Keep the screensaver up so it survives them.
             */
            break
        @unknown default:
            break
        }
    }

    // MARK: - Screensaver / Wake

    private func showScreensaver() {
        guard !isScreensaverShown else { return }
        isScreensaverShown = true
    }

    private func wake() {
        guard isScreensaverShown else { return }
        isScreensaverShown = false
        if shouldReopenSettings {
            shouldReopenSettings = false
            settingsRequest = .openKioskMode
        }
        resetInactivityTimer()
    }

    // MARK: - Idle Timer

    private func applyStayAwake() {
        UIApplication.shared.isIdleTimerDisabled = stayAwake
    }

    // MARK: - Inactivity Timer

    private func resetInactivityTimer() {
        cancelInactivityTimer()
        guard stayAwake else { return }

        let interval = TimeInterval(screensaverTimeout.rawValue)
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
            Task { @MainActor [weak self] in
                self?.showScreensaver()
            }
        }
    }

    private func cancelInactivityTimer() {
        inactivityTimer?.invalidate()
        inactivityTimer = nil
    }
}
