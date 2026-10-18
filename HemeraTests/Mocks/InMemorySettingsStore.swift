import Foundation
@testable import Hemera

/// Holds the raw JSON so tests can seed malformed or outdated shapes.
@MainActor
final class InMemorySettingsStore: SettingsStoring {

    var json: String?

    init(json: String? = nil) {
        self.json = json
    }

    func load() -> SettingsValues? {
        guard let json else { return nil }
        return decoded(from: json)
    }

    func save(_ values: SettingsValues) {
        json = encoded(values)
    }

    func clear() { json = nil }
}
