import Foundation

/// Owns the theme and the screensaver's Show Theme setting.
@Observable
@MainActor
final class ThemeManager {

    // MARK: - Properties

    /// What views draw from. Changes in memory during an edit session; written only on `commit()`.
    private(set) var theme: Theme

    /// The intensity the editor shows; kept while None is chosen, so picking a colour brings it back.
    private(set) var intensity = Theme.Gradient.defaultIntensity

    var screensaverShowsTheme: Bool {
        didSet { store.settings.screensaverShowsTheme = screensaverShowsTheme }
    }

    /// Settings came from a newer build, so changes made here will not persist.
    var settingsAreReadOnly: Bool { store.isReadOnly }

    private var themeBeforeEditing: Theme?

    private let store: any SettingsStoring

    private var isEditing: Bool { themeBeforeEditing != nil }

    // MARK: - Init

    /// Screenshot mode shows None without touching what is stored.
    init(store: any SettingsStoring, isScreenshotMode: Bool = CommandLine.arguments.contains("-screenshotMode")) {
        self.store = store
        self.theme = isScreenshotMode ? .none : store.settings.theme
        self.screensaverShowsTheme = store.settings.screensaverShowsTheme
    }

    // MARK: - Edit Session

    func beginEditing() {
        themeBeforeEditing = theme
        if case .gradient(let gradient) = theme {
            intensity = gradient.intensity
        } else {
            intensity = Theme.Gradient.defaultIntensity
        }
    }

    /// Like every change here, ignored outside a session: a touch can end after Done or Cancel.
    func setColor(_ color: ThemeColor, family: ThemeFamily?) {
        guard isEditing else { return }
        theme = .gradient(Theme.Gradient(color: color, intensity: intensity, family: family))
    }

    func setIntensity(_ intensity: Double) {
        guard isEditing else { return }
        self.intensity = intensity
        if case .gradient(var gradient) = theme {
            gradient.intensity = intensity
            theme = .gradient(gradient)
        }
    }

    func chooseNone() {
        guard isEditing else { return }
        theme = .none
    }

    func commit() {
        guard let themeBeforeEditing else { return }
        self.themeBeforeEditing = nil
        if theme != themeBeforeEditing {
            store.settings.theme = theme
        }
    }

    func cancel() {
        guard let themeBeforeEditing else { return }
        theme = themeBeforeEditing
        self.themeBeforeEditing = nil
    }

    // MARK: - Logout

    func resetToDefaults() {
        themeBeforeEditing = nil
        theme = .none
        store.settings.theme = .none
        screensaverShowsTheme = true
    }
}
