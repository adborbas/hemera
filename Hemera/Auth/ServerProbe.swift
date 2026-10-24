import Foundation

/// Checks an address answers as Home Assistant; without it a typo becomes a blank sign-in sheet.
protocol ServerProbing: Sendable {
    /// Throws `serverUnreachable` or `notHomeAssistant`. `timeout` is the caller's patience.
    func probe(_ serverURL: URL, timeout: TimeInterval) async throws
}

struct ServerProbe: ServerProbing {

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// A scheme the user actually typed is worth waiting for.
    static let confirmed: TimeInterval = 10
    /// A scheme we guessed at is not — falling through to the other one quickly matters more.
    static let speculative: TimeInterval = 3

    /// `/auth/providers` is unauthenticated, so anything that can serve OAuth answers it.
    func probe(_ serverURL: URL, timeout: TimeInterval) async throws {
        var request = URLRequest(url: serverURL.appendingPathComponent("/auth/providers"))
        request.timeoutInterval = timeout

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AuthError.serverUnreachable
        }

        guard let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              (try? JSONDecoder().decode(AuthProviders.self, from: data)) != nil else {
            throw AuthError.notHomeAssistant
        }
    }

}

/// Shape only. HA answered with a bare array up to 2024.1 and an object from 2024.2; both pass.
private struct AuthProviders: Decodable {

    struct Provider: Decodable {}

    let providers: [Provider]

    init(from decoder: any Decoder) throws {
        if let bare = try? decoder.singleValueContainer().decode([Provider].self) {
            providers = bare
            return
        }
        providers = try decoder.container(keyedBy: CodingKeys.self).decode([Provider].self, forKey: .providers)
    }

    private enum CodingKeys: String, CodingKey {
        case providers
    }
}
