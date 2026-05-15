import SwiftUI

struct KioskModeView: View {

    @Bindable var screenManager: ScreenManager

    var body: some View {
        List {
            Section {
                Toggle(Localization.kioskMode, isOn: $screenManager.stayAwake)
                if screenManager.stayAwake {
                    Picker(Localization.dimAfter, selection: $screenManager.dimTimeout) {
                        ForEach(DimTimeout.allCases) { timeout in
                            Text(timeout.label).tag(timeout)
                        }
                    }
                    Picker(Localization.timeFormat, selection: $screenManager.clockFormat) {
                        ForEach(ClockFormat.allCases) { format in
                            Text(format.label).tag(format)
                        }
                    }
                    Button(Localization.previewDimScreen) {
                        screenManager.requestPreviewDim()
                    }
                }
            } footer: {
                Text(screenManager.stayAwake ? Localization.footerOn : Localization.footerOff)
            }
        }
        .navigationTitle(Localization.kioskMode)
        .animation(.default, value: screenManager.stayAwake)
    }
}

private extension KioskModeView {
    enum Localization {
        static let kioskMode = String(localized: "Kiosk Mode", comment: "Navigation title and master toggle for kiosk mode settings (stay awake, dimming)")
        static let dimAfter = String(localized: "Dim After", comment: "Picker label for choosing how long before the screen dims due to inactivity")
        static let timeFormat = String(localized: "Time Format", comment: "Picker label for choosing between 12-hour and 24-hour clock display on the dimmed screen")
        static let previewDimScreen = String(localized: "Preview Dim Screen", comment: "Button that immediately dims the screen so the user can preview the dimmed clock display")
        static let footerOn = String(localized: "The screen will dim after inactivity but the device won't auto-lock while Hemera is active.", comment: "Footer text when Kiosk Mode is enabled")
        static let footerOff = String(localized: "The device will auto-lock based on your system settings.", comment: "Footer text when Kiosk Mode is disabled")
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        KioskModeView(screenManager: ScreenManager())
    }
}
#endif
