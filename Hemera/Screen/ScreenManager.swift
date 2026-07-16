import SwiftUI

enum ClockFormat: Int, CaseIterable, Identifiable {
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

enum DimTimeout: Int, CaseIterable, Identifiable {
    case thirtySeconds = 30
    case oneMinute = 60
    case fiveMinutes = 300

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .thirtySeconds:
            String(localized: "30 Seconds", comment: "Dim timeout option for 30 seconds")
        case .oneMinute:
            String(localized: "1 Minute", comment: "Dim timeout option for 1 minute")
        case .fiveMinutes:
            String(localized: "5 Minutes", comment: "Dim timeout option for 5 minutes")
        }
    }
}

@Observable
@MainActor
final class ScreenManager {

    // MARK: - Persisted Settings

    var stayAwake: Bool {
        didSet {
            UserDefaults.standard.set(stayAwake, forKey: Keys.stayAwake)
            applyStayAwake()
            if stayAwake {
                resetInactivityTimer()
            } else {
                cancelInactivityTimer()
                if isDimmed { wake() }
            }
        }
    }

    var dimTimeout: DimTimeout {
        didSet {
            UserDefaults.standard.set(dimTimeout.rawValue, forKey: Keys.dimTimeout)
            resetInactivityTimer()
        }
    }

    var clockFormat: ClockFormat {
        didSet {
            UserDefaults.standard.set(clockFormat.rawValue, forKey: Keys.clockFormat)
        }
    }

    // MARK: - Runtime State

    private(set) var isDimmed = false

    /// Choreography signal for the settings sheet during the preview-dim
    /// flow. The view binds settings presentation to this signal:
    /// - `.close`: the sheet should dismiss so a pending dim can fire.
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

    private enum Keys {
        static let stayAwake = "screenManager.stayAwake"
        static let dimTimeout = "screenManager.dimTimeout"
        static let clockFormat = "screenManager.clockFormat"
    }

    // MARK: - Init

    init() {
        let defaults = UserDefaults.standard
        self.stayAwake = defaults.bool(forKey: Keys.stayAwake)
        let rawTimeout = defaults.integer(forKey: Keys.dimTimeout)
        self.dimTimeout = DimTimeout(rawValue: rawTimeout) ?? .thirtySeconds
        let rawClockFormat = defaults.integer(forKey: Keys.clockFormat)
        self.clockFormat = ClockFormat(rawValue: rawClockFormat) ?? .system

        applyStayAwake()
        if stayAwake {
            resetInactivityTimer()
        }
    }

    // MARK: - Public

    func resetToDefaults() {
        cancelInactivityTimer()
        if isDimmed { wake() }
        stayAwake = false
        dimTimeout = .thirtySeconds
        clockFormat = .system
    }

    /// Asks the view to dismiss the settings sheet so a preview-dim can
    /// fire. The actual dim happens once the view acknowledges via
    /// `acknowledgeSettingsDismissed()`.
    func requestPreviewDim() {
        settingsRequest = .close
    }

    /// Called by the view after the settings sheet has actually closed. If
    /// a preview-dim was pending, it fires here.
    func acknowledgeSettingsDismissed() {
        guard settingsRequest == .close else { return }
        settingsRequest = .none
        executePreviewDim()
    }

    /// Called by the view after it has reopened the settings sheet for the
    /// kiosk-mode route requested post-wake, so the signal can clear.
    func acknowledgeSettingsOpened() {
        if settingsRequest == .openKioskMode {
            settingsRequest = .none
        }
    }

    /// Direct entrypoint used by tests and the dim-on-wake state machine.
    /// In production the choreography goes through `requestPreviewDim()` +
    /// `acknowledgeSettingsDismissed()` so the sheet closes before the dim.
    func executePreviewDim() {
        shouldReopenSettings = true
        cancelInactivityTimer()
        dim()
    }

    func registerUserActivity() {
        if isDimmed {
            wake()
        } else if stayAwake {
            resetInactivityTimer()
        }
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            applyStayAwake()
            if stayAwake && !isDimmed {
                resetInactivityTimer()
            }
        case .background:
            cancelInactivityTimer()
            if isDimmed {
                isDimmed = false
            }
        case .inactive:
            /**
             Transient interruptions (Control Center, Notification Center,
             incoming calls) yield `.inactive` without backgrounding the app.
             Keep the current dim state so it survives them.
             */
            break
        @unknown default:
            break
        }
    }

    // MARK: - Dim / Wake

    private func dim() {
        guard !isDimmed else { return }
        isDimmed = true
    }

    private func wake() {
        guard isDimmed else { return }
        isDimmed = false
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

        let interval = TimeInterval(dimTimeout.rawValue)
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
            Task { @MainActor [weak self] in
                self?.dim()
            }
        }
    }

    private func cancelInactivityTimer() {
        inactivityTimer?.invalidate()
        inactivityTimer = nil
    }
}
