import Foundation
@testable import Hemera

@MainActor
final class InMemorySettingsStore: SettingsStoring {

    var settings: Settings
    let isReadOnly: Bool

    init(settings: Settings = Settings(), isReadOnly: Bool = false) {
        self.settings = settings
        self.isReadOnly = isReadOnly
    }
}
