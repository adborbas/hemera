import SwiftUI

struct KioskModeView: View {

    @Bindable var screenManager: ScreenManager
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        List {
            Section {
                Toggle(Localization.kioskMode, isOn: $screenManager.stayAwake)
                    .accessibilityIdentifier("kioskModeToggle")
                if screenManager.stayAwake {
                    Picker(Localization.startScreensaverAfter, selection: $screenManager.screensaverTimeout) {
                        ForEach(ScreensaverTimeout.allCases) { timeout in
                            Text(timeout.label).tag(timeout)
                        }
                    }
                    Picker(Localization.timeFormat, selection: $screenManager.clockFormat) {
                        ForEach(ClockFormat.allCases) { format in
                            Text(format.label).tag(format)
                        }
                    }
                    if themeManager.theme != .none {
                        Toggle(Localization.showTheme, isOn: Bindable(themeManager).screensaverShowsTheme)
                    }
                    Button(Localization.previewScreensaver) {
                        screenManager.requestScreensaverPreview()
                    }
                }
            } footer: {
                Text(footerText)
            }
            .disabled(screenManager.settingsAreReadOnly)
        }
        .navigationTitle(Localization.kioskMode)
        .reportsFeedScroll()
        .pushedScreenHeader(Localization.kioskMode, staysCollapsed: true)
        .animation(.default, value: screenManager.stayAwake)
    }

    private var footerText: String {
        if screenManager.settingsAreReadOnly { return Localization.footerReadOnly }
        return screenManager.stayAwake ? Localization.footerOn : Localization.footerOff
    }
}

private extension KioskModeView {
    enum Localization {
        static let kioskMode = String(localized: "Kiosk Mode", comment: "Navigation title and master toggle for kiosk mode settings (stay awake, screensaver)")
        static let startScreensaverAfter = String(localized: "Start Screensaver After", comment: "Picker label for choosing how long before the screensaver starts due to inactivity")
        static let timeFormat = String(localized: "Time Format", comment: "Picker label for choosing between 12-hour and 24-hour clock display on the screensaver")
        static let showTheme = String(localized: "Show Theme", comment: "Toggle for painting the theme, dimmed, behind the screensaver clock instead of plain black")
        static let previewScreensaver = String(localized: "Preview Screensaver", comment: "Button that immediately starts the screensaver so the user can preview its clock display")
        static let footerOn = String(localized: "The screensaver starts after inactivity, but the device won't auto-lock while Hemera is active.", comment: "Footer text when Kiosk Mode is enabled")
        static let footerOff = String(localized: "The device will auto-lock based on your system settings.", comment: "Footer text when Kiosk Mode is disabled")
        static let footerReadOnly = String(
            localized: "These settings were saved by a newer version of Hemera, so they can't be changed here. Update Hemera to change them.",
            comment: "Footer on the Kiosk Mode screen when stored settings came from a newer build, so changes cannot be saved"
        )
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        KioskModeView(screenManager: ScreenManager(store: UserDefaultsSettingsStore.preview()))
    }
    .environment(ThemeManager(store: UserDefaultsSettingsStore.preview()))
}
#endif
