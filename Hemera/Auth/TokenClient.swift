import Foundation

struct TokenResponse: Decodable {
    let access_token: String
    let refresh_token: String?
    let expires_in: Int
    let token_type: String
}

enum TokenClient {

    static func exchangeCode(
        code: String,
        clientId: String,
        serverURL: URL
    ) async throws -> TokenResponse {
        let body = formEncode([
            "grant_type": "authorization_code",
            "code": code,
            "client_id": clientId,
        ])
        return try await post(to: serverURL, body: body)
    }

    static func refresh(
        refreshToken: String,
        clientId: String,
        serverURL: URL
    ) async throws -> TokenResponse {
        let body = formEncode([
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientId,
        ])
        do {
            return try await post(to: serverURL, body: body)
        } catch let error as TokenClientError where error == .invalidGrant {
            throw AuthError.sessionExpired
        }
    }

    static func revoke(
        refreshToken: String,
        serverURL: URL
    ) async throws {
        let body = formEncode([
            "action": "revoke",
            "token": refreshToken,
        ])
        let url = serverURL.appendingPathComponent("/auth/token")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = body.data(using: .utf8)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw TokenClientError.httpError(response)
        }
    }

    // MARK: - Private

    private static func post(to serverURL: URL, body: String) async throws -> TokenResponse {
        let url = serverURL.appendingPathComponent("/auth/token")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            // Check for invalid_grant specifically
            if let errorBody = try? JSONDecoder().decode(HAAuthError.self, from: data),
               errorBody.error == "invalid_grant" {
                throw TokenClientError.invalidGrant
            }
            throw TokenClientError.httpError(response)
        }
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    /**
     RFC 3986 unreserved set — safe for x-www-form-urlencoded values.
     Excludes sub-delims (+ & = , ; …) which are structural in a form body;
     `.urlQueryAllowed` would leave them unescaped (notably `+` → space).
     */
    private static let formAllowedCharacters = CharacterSet(charactersIn:
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    // Internal (not private) so `formEncode` can be unit-tested directly via @testable import.
    static func formEncode(_ params: [String: String]) -> String {
        params.map { key, value in
            let encodedKey = key.addingPercentEncoding(withAllowedCharacters: formAllowedCharacters) ?? key
            let encodedValue = value.addingPercentEncoding(withAllowedCharacters: formAllowedCharacters) ?? value
            return "\(encodedKey)=\(encodedValue)"
        }.joined(separator: "&")
    }
}

private struct HAAuthError: Decodable {
    let error: String
}

enum TokenClientError: Error, Equatable {
    case invalidGrant
    case httpError(URLResponse)

    static func == (lhs: TokenClientError, rhs: TokenClientError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidGrant, .invalidGrant): return true
        case (.httpError, .httpError): return true
        default: return false
        }
    }
}
