import Foundation
@testable import Hemera

@MainActor
final class InMemorySettingsStore: SettingsStoring {

    var settings: Settings

    init(settings: Settings = Settings()) {
        self.settings = settings
    }
}
