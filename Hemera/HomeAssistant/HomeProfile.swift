import Foundation
import HAKit
import HemeraLog

/// The signed-in Home Assistant user.
struct Account: Equatable {
    enum Role: Equatable {
        case owner
        case admin
        case user

        var displayName: String {
            switch self {
            case .owner: Localization.owner
            case .admin: Localization.admin
            case .user: Localization.user
            }
        }
    }

    let name: String
    let role: Role
    let pictureURL: URL?
    var badge = BadgeColors.standard

    /// As Home Assistant draws them: the first letter of up to three words, case kept; nil when blank.
    var initials: String? {
        let letters = name.split(whereSeparator: \.isWhitespace).prefix(3).compactMap(\.first)
        return letters.isEmpty ? nil : String(letters)
    }
}

extension Account {
    /// The picture is the `person` linked by `user_id`, resolved against the server.
    init(user: HAResponseCurrentUser, persons: [HAEntity], baseURL: URL, primaryColor: String? = nil) {
        let picture = persons
            .first { $0.attributes["user_id"] as? String == user.id }?
            .attributes["entity_picture"] as? String
        self.init(
            name: user.name ?? "",
            role: user.isOwner ? .owner : user.isAdmin ? .admin : .user,
            pictureURL: picture.flatMap { $0.isEmpty ? nil : URL(string: $0, relativeTo: baseURL)?.absoluteURL },
            badge: BadgeColors(primaryColor: primaryColor)
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

    /// Home Assistant's location name, or "Home" until it loads or when the server has none.
    var displayName: String {
        guard let homeName, !homeName.trimmingCharacters(in: .whitespaces).isEmpty else {
            return Localization.defaultHomeName
        }
        return homeName
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
            // The colours picked in the Home Assistant profile, which its avatar is drawn from.
            let theme = try? await connection.send(HARequest(
                type: .webSocket("frontend/get_user_data"), data: ["key": "theme"]
            ))
            let settings = theme.flatMap { try? $0.decode("value") as [String: Any] }
            let primaryColor = settings?["primaryColor"] as? String
            account = Account(user: user, persons: persons, baseURL: baseURL, primaryColor: primaryColor)
        } catch {
            Log.warning("Failed to fetch the current Home Assistant user", cause: error)
        }
    }
}

private enum Localization {
    static let defaultHomeName = String(
        localized: "Home",
        comment: "Name shown for the home until Home Assistant reports one, or when it has none"
    )
    static let owner = String(localized: "Owner", comment: "Role of the Home Assistant user who owns the server")
    static let admin = String(localized: "Administrator", comment: "Role of a Home Assistant administrator user")
    static let user = String(localized: "User", comment: "Role of a regular, non-admin Home Assistant user")
}
