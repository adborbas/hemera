import Foundation
import Testing
@testable import Hemera

/// Tile changes must animate around a mode toggle and not on a background sync.
@MainActor
struct AreaHideModeTests {

    /// Polled, not timed: the suite runs `@MainActor` tests in parallel, so the reset lands late.
    private func disarms(_ hideMode: AreaHideMode, within timeout: Duration = .seconds(5)) async throws -> Bool {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while ContinuousClock.now < deadline {
            if !hideMode.animatesTileChanges { return true }
            try await Task.sleep(for: .milliseconds(25))
        }
        return false
    }

    @Test func setActive_togglesMode() {
        let hideMode = AreaHideMode()
        #expect(hideMode.isActive == false)

        hideMode.setActive(true)
        #expect(hideMode.isActive == true)

        hideMode.setActive(false)
        #expect(hideMode.isActive == false)
    }

    @Test func setActive_armsTileAnimationImmediately() {
        let hideMode = AreaHideMode()

        hideMode.setActive(true)

        #expect(hideMode.animatesTileChanges == true)
    }

    /// Otherwise every later background sync would animate the grid.
    @Test func animatesTileChanges_afterWindow_disarms() async throws {
        let hideMode = AreaHideMode()

        hideMode.setActive(true)
        #expect(hideMode.animatesTileChanges == true)

        #expect(try await disarms(hideMode))
    }

    /// An uncancelled first timer would disarm partway through the new transition.
    @Test func setActive_twiceInsideWindow_keepsAnimatingUntilSecondWindowEnds() async throws {
        let hideMode = AreaHideMode()

        hideMode.setActive(true)
        try await Task.sleep(for: .milliseconds(300))
        hideMode.setActive(false)
        try await Task.sleep(for: .milliseconds(100))

        // The first window has elapsed; the second runs until 800ms.
        #expect(hideMode.animatesTileChanges == true)
    }

    /// Leaving mid-window must disarm, or every later background-sync change animates.
    @Test func endAnimationWindow_disarmsImmediately() {
        let hideMode = AreaHideMode()

        hideMode.setActive(true)
        hideMode.endAnimationWindow()

        #expect(hideMode.animatesTileChanges == false)
    }

    /// Re-entering after an early exit must animate again.
    @Test func setActive_afterEndAnimationWindow_rearms() {
        let hideMode = AreaHideMode()

        hideMode.setActive(true)
        hideMode.endAnimationWindow()
        hideMode.setActive(false)

        #expect(hideMode.animatesTileChanges == true)
    }
}
