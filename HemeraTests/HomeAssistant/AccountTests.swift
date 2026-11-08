import Foundation
import HAKit
import Testing
@testable import Hemera

@MainActor
struct AccountTests {

    private let baseURL = URL(string: "http://homeassistant.local:8123")!

    // MARK: - Initials

    // The avatar must show the same letters as Home Assistant's own badge for the same user.
    @Test func initials_keepTheNamesCase() {
        #expect(account(named: "dev").initials == "d")
        #expect(account(named: "ada Lovelace").initials == "aL")
    }

    @Test func initials_manyWords_takeTheFirstThree() {
        #expect(account(named: "Mary Ann Evans Cross").initials == "MAE")
    }

    @Test func initials_extraSpaces_areIgnored() {
        #expect(account(named: "  Ada   Lovelace ").initials == "AL")
    }

    @Test func initials_blankName_isNilSoTheAvatarShowsAPersonIcon() {
        #expect(account(named: "").initials == nil)
        #expect(account(named: "   ").initials == nil)
    }

    // MARK: - Role

    @Test func role_ownerWinsOverAdmin() {
        // Owners are also admins in Home Assistant; the more specific role is the one to show.
        let account = Account(user: user(isOwner: true, isAdmin: true), persons: [], baseURL: baseURL)

        #expect(account.role == .owner)
    }

    @Test func role_nonAdmin_isUser() {
        let account = Account(user: user(), persons: [], baseURL: baseURL)

        #expect(account.role == .user)
    }

    // MARK: - Picture

    @Test func pictureURL_fromPersonLinkedToUser_resolvesAgainstServer() throws {
        // Home Assistant serves person pictures as server-relative paths.
        let persons = [
            try person("person.other", userId: "other", picture: "/api/image/serve/other/512x512"),
            try person("person.adam", userId: "user-1", picture: "/api/image/serve/adam/512x512"),
        ]

        let account = Account(user: user(id: "user-1"), persons: persons, baseURL: baseURL)

        #expect(account.pictureURL?.absoluteString == "http://homeassistant.local:8123/api/image/serve/adam/512x512")
    }

    @Test func pictureURL_onlyOtherPeopleHavePictures_isNil() throws {
        // Showing someone else's face on the avatar would be worse than initials.
        let persons = [try person("person.other", userId: "other", picture: "/local/other.jpg")]

        let account = Account(user: user(id: "user-1"), persons: persons, baseURL: baseURL)

        #expect(account.pictureURL == nil)
    }

    @Test func pictureURL_linkedPersonWithoutPicture_isNil() throws {
        let persons = [try person("person.adam", userId: "user-1", picture: nil)]

        let account = Account(user: user(id: "user-1"), persons: persons, baseURL: baseURL)

        #expect(account.pictureURL == nil)
    }

    @Test func pictureURL_absolute_isKept() throws {
        let persons = [try person("person.adam", userId: "user-1", picture: "https://example.com/adam.png")]

        let account = Account(user: user(id: "user-1"), persons: persons, baseURL: baseURL)

        #expect(account.pictureURL?.absoluteString == "https://example.com/adam.png")
    }

    // MARK: - Helpers

    private func account(named name: String) -> Account {
        Account(name: name, role: .user, pictureURL: nil)
    }

    private func user(id: String = "user-1", isOwner: Bool = false, isAdmin: Bool = false) -> HAResponseCurrentUser {
        HAResponseCurrentUser(
            id: id, name: "Adam", isOwner: isOwner, isAdmin: isAdmin, credentials: [], mfaModules: []
        )
    }

    private func person(_ entityId: String, userId: String, picture: String?) throws -> HAEntity {
        var attributes: [String: Any] = ["user_id": userId]
        attributes["entity_picture"] = picture
        return try HAEntity(
            entityId: entityId,
            domain: "person",
            state: "home",
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: attributes,
            context: .init(id: "", userId: nil, parentId: nil)
        )
    }
}
