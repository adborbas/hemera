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
    func commit_expiresAfterDuration() async {
        let cooldown = CommitCooldown(duration: 0.05)
        cooldown.commit()
        #expect(cooldown.isSuppressed == true)

        // Await the expiry task itself rather than a fixed sleep, so scheduler
        // contention can't flake the result.
        await cooldown.expiryTask?.value
        #expect(cooldown.isSuppressed == false)
    }

    // MARK: - Debounce

    @Test
    func commit_recommit_cancelsPreviousExpiryAndRearmsWindow() async {
        let cooldown = CommitCooldown(duration: 0.05)
        cooldown.commit()
        let firstExpiry = cooldown.expiryTask

        /**
         Re-commit before the first window expires (no suspension has occurred,
         so the first timer cannot have fired yet): the prior timer is cancelled
         and a fresh one armed, so the window is measured from the last commit.
         */
        cooldown.commit()
        #expect(firstExpiry?.isCancelled == true)
        #expect(cooldown.isSuppressed == true)

        // The re-armed window still expires.
        await cooldown.expiryTask?.value
        #expect(cooldown.isSuppressed == false)
    }
}
