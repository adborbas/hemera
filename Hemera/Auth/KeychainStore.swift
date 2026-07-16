import Foundation
import KeychainAccess

protocol KeychainStoring: Sendable {
    func saveCredentials(_ credentials: ServerCredentials) throws
    func loadCredentials() -> ServerCredentials?
    func clearAll() throws
}

final class KeychainStore: KeychainStoring, @unchecked Sendable {

    static let shared = KeychainStore()

    private let keychain: Keychain

    init(service: String = "com.hemera.auth") {
        self.keychain = Keychain(service: service)
            .accessibility(.afterFirstUnlockThisDeviceOnly)
    }

    private static let credentialsKey = "server_credentials"

    func saveCredentials(_ credentials: ServerCredentials) throws {
        let data = try JSONEncoder().encode(credentials)
        try keychain.set(data, key: Self.credentialsKey)
    }

    func loadCredentials() -> ServerCredentials? {
        guard let data = try? keychain.getData(Self.credentialsKey) else { return nil }
        return try? JSONDecoder().decode(ServerCredentials.self, from: data)
    }

    func clearAll() throws {
        try keychain.removeAll()
    }
}
