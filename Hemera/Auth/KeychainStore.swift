import Foundation
import KeychainAccess

final class KeychainStore: @unchecked Sendable {

    static let shared = KeychainStore()

    private let keychain: Keychain

    init(service: String = "com.hemera.auth") {
        self.keychain = Keychain(service: service)
            .accessibility(.afterFirstUnlockThisDeviceOnly)
    }

    private static let credentialsKey = "server_credentials"

    func saveCredentials(_ credentials: ServerCredentials) {
        guard let data = try? JSONEncoder().encode(credentials) else { return }
        try? keychain.set(data, key: Self.credentialsKey)
    }

    func loadCredentials() -> ServerCredentials? {
        guard let data = try? keychain.getData(Self.credentialsKey) else { return nil }
        return try? JSONDecoder().decode(ServerCredentials.self, from: data)
    }

    func clearAll() {
        try? keychain.removeAll()
    }
}
