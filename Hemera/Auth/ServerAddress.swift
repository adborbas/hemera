import Foundation

enum ServerAddress {

    /// Guesses https for a bare host: guessing http would downgrade settings' session silently.
    static func normalised(_ input: String) -> URL? {
        guard let trimmed = trimmed(input) else { return nil }
        return url(trimmed.contains("://") ? trimmed : "https://\(trimmed)")
    }

    /**
     What to try for the typed address, best first. A typed scheme is an instruction and is
     never substituted; a bare host gets https then http, so a redirect to https never matters.
    */
    static func candidates(_ input: String) -> [URL] {
        guard let trimmed = trimmed(input) else { return [] }
        guard !trimmed.contains("://") else {
            return [url(trimmed)].compactMap { $0 }
        }
        return ["https", "http"].compactMap { url("\($0)://\(trimmed)") }
    }

    // MARK: - Private

    private static func trimmed(_ input: String) -> String? {
        let trimmed = input
            .trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func url(_ string: String) -> URL? {
        guard let components = URLComponents(string: string),
              let host = components.host, !host.isEmpty,
              let scheme = components.scheme, ["http", "https"].contains(scheme.lowercased()),
              let url = components.url else {
            return nil
        }
        return url
    }
}
