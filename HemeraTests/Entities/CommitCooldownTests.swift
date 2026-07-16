import Foundation
import Testing
@testable import Hemera

@MainActor
struct CommitCooldownTests {

    // MARK: - Initial State

    @Test
    func isSuppressed_initially_isFalse() {
        let cooldown = CommitCooldown(duration: 0.2)
        #expect(cooldown.isSuppressed == false)
    }

    // MARK: - Commit

    @Test
    func commit_suppressesImmediately() {
        let cooldown = CommitCooldown(duration: 0.2)
        cooldown.commit()
        #expect(cooldown.isSuppressed == true)
    }

    @Test
    func commit_expiresAfterDuration() async throws {
        let cooldown = CommitCooldown(duration: 0.1)
        cooldown.commit()
        #expect(cooldown.isSuppressed == true)

        try await Task.sleep(for: .milliseconds(250))
        #expect(cooldown.isSuppressed == false)
    }

    // MARK: - Debounce

    @Test
    func commit_recommit_measuresWindowFromLastCommit() async throws {
        let cooldown = CommitCooldown(duration: 0.2)
        cooldown.commit()

        // Re-commit before the first window expires; the window must now be
        // measured from this second commit, not the first.
        try await Task.sleep(for: .milliseconds(120))
        cooldown.commit()

        // Past the original 200ms window but within the extended one.
        try await Task.sleep(for: .milliseconds(120))
        #expect(cooldown.isSuppressed == true)

        // Past the extended window.
        try await Task.sleep(for: .milliseconds(250))
        #expect(cooldown.isSuppressed == false)
    }
}
