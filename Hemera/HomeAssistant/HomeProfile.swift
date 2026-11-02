import Foundation
import HAKit
import HemeraLog

/// The signed-in Home Assistant user.
struct Account: Equatable {
    enum Role: Equatable {
        case owner
        case admin
        case user
    }

    let name: String
    let role: Role
    let pictureURL: URL?

    /// First letters of the first and last word, uppercased; nil when the name is blank.
    var initials: String? {
        let words = name.split(whereSeparator: \.isWhitespace)
        guard let first = words.first?.first else { return nil }
        guard words.count > 1, let last = words.last?.first else { return String(first).uppercased() }
        return (String(first) + String(last)).uppercased()
    }
}

extension Account {
    /// The picture is the `person` linked by `user_id`, resolved against the server.
    init(user: HAResponseCurrentUser, persons: [HAEntity], baseURL: URL) {
        let picture = persons
            .first { $0.attributes["user_id"] as? String == user.id }?
            .attributes["entity_picture"] as? String
        self.init(
            name: user.name ?? "",
            role: user.isOwner ? .owner : user.isAdmin ? .admin : .user,
            pictureURL: picture.flatMap { $0.isEmpty ? nil : URL(string: $0, relativeTo: baseURL)?.absoluteURL }
        )
    }
}

/// The home's name and the signed-in account, fetched once when a session starts.
@Observable
@MainActor
final class HomeProfile {
    private(set) var homeName: String?
    private(set) var account: Account?

    init(homeName: String? = nil, account: Account? = nil) {
        self.homeName = homeName
        self.account = account
    }

    func load(over connection: HAConnection, baseURL: URL) async {
        do {
            let config = try await connection.send(HARequest(type: .getConfig, data: [:]))
            homeName = try? config.decode("location_name") as String
        } catch {
            Log.warning("Failed to fetch the Home Assistant config — keeping the default home name", cause: error)
        }
        do {
            let user = try await connection.send(.currentUser())
            // shortcut: fetches all states for person pictures; query persons only if this gets slow.
            let states = try? await connection.send(HATypedRequest<[HAEntity]>(
                request: HARequest(type: .getStates, data: [:])
            ))
            let persons = (states ?? []).filter { $0.domain == "person" }
            account = Account(user: user, persons: persons, baseURL: baseURL)
        } catch {
            Log.warning("Failed to fetch the current Home Assistant user", cause: error)
        }
    }
}
