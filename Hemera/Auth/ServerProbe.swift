import Foundation

/**
 Checks that an address answers as Home Assistant before the OAuth flow commits to it.

 Preparing an OAuth session is pure string work, so without this nothing touches the network
 until after the user has signed in — a typo or an unrelated host both end up as a sign-in
 sheet that silently never loads.
*/
protocol ServerProbing: Sendable {
    /**
     Throws `AuthError.serverUnreachable` or `AuthError.notHomeAssistant` if the address can't sign us in.

     `timeout` is the caller's patience. Resolving a bare host tries a scheme the user never
     named, so that guess gets a short one — the cost of being wrong is a delay the user did
     not ask for.
    */
    func probe(_ serverURL: URL, timeout: TimeInterval) async throws
}

struct ServerProbe: ServerProbing {

    /// A scheme the user actually typed is worth waiting for.
    static let confirmed: TimeInterval = 10
    /// A scheme we guessed at is not — falling through to the other one quickly matters more.
    static let speculative: TimeInterval = 3

    /**
     `/auth/providers` is the login page's own unauthenticated endpoint, so anything able to
     serve the OAuth flow answers it with a provider list. It separates the two failures the
     user has to act on differently: a transport error means the address or the network is
     wrong, a bad answer means the address reached something that isn't Home Assistant.
    */
    func probe(_ serverURL: URL, timeout: TimeInterval) async throws {
        var request = URLRequest(url: serverURL.appendingPathComponent("/auth/providers"))
        request.timeoutInterval = timeout

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
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

/**
 Only the shape is checked, not the contents — the providers a server offers are its own
 business, and pinning fields here would reject Home Assistant versions that add or rename them.
*/
private struct AuthProviders: Decodable {
    struct Provider: Decodable {}
    let providers: [Provider]
}
