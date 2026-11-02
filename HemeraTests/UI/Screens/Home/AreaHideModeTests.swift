import Foundation
import Testing
@testable import Hemera

/// Tile changes must animate around a mode toggle and not on a background sync.
@MainActor
struct AreaHideModeTests {

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
