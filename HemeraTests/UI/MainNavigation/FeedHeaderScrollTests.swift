import Foundation
import SwiftUI
import Synchronization
import Testing
@testable import Hemera

@MainActor
struct FeedHeaderScrollTests {

    private let clock = TestClock()
    private let scroll: FeedHeaderScroll

    init() {
        scroll = FeedHeaderScroll(now: { [clock] in clock.now })
        scroll.hideRange = 100
    }

    // MARK: - Hiding

    @Test func scrolled_down_hidesOneToOne() {
        drag(to: [0, 500, 530])

        #expect(scroll.hiddenAmount == 30)
    }

    @Test func scrolled_downPastHideRange_stopsAtHideRange() {
        drag(to: [0, 500, 560, 620])

        #expect(scroll.hiddenAmount == 100)
    }

    @Test func scrolled_nearTop_neverHidesMoreThanScrolled() {
        // Hiding further than the offset would open a gap above the first row.
        drag(to: [0, 40, 80, 60])

        #expect(scroll.hiddenAmount == 60)
    }

    @Test func scrolled_jump_isIgnored() {
        // A content-size change moves the offset without anyone scrolling.
        drag(to: [0, 500, 900])

        #expect(scroll.hiddenAmount == 0)
    }

    // MARK: - Revealing

    @Test func scrolled_fastFlickUpWithFingerDown_reveals() {
        hideFully()

        drag(to: [600, 575, 550], interval: 0.02)

        #expect(scroll.hiddenAmount == 0)
    }

    @Test func scrolled_slowScrollUp_neverReveals() {
        // A slow scroll up is reading, not asking for the header back.
        hideFully()

        drag(to: [580, 560, 540, 520], interval: 0.1)

        #expect(scroll.hiddenAmount == 100)
    }

    @Test func scrolled_fastButShortFlickUp_doesNotReveal() {
        hideFully()

        drag(to: [610, 590], interval: 0.01)

        #expect(scroll.hiddenAmount == 100)
    }

    @Test func scrolled_bounceAfterRelease_neverReveals() {
        // The end-of-content bounce moves fast and upward, but the finger is already off.
        hideFully()
        scroll.phaseChanged(to: .decelerating)

        drag(to: [595, 570, 545], interval: 0.01, phase: nil)

        #expect(scroll.hiddenAmount == 100)
    }

    // MARK: - Snapping

    @Test func phaseIdle_beyondHideRange_snapsToNearerState() {
        drag(to: [0, 500, 560, 590])
        scroll.phaseChanged(to: .idle)

        #expect(scroll.hiddenAmount == 100)
    }

    @Test func phaseIdle_lessThanHalfHidden_snapsShown() {
        drag(to: [0, 500, 530])
        scroll.phaseChanged(to: .idle)

        #expect(scroll.hiddenAmount == 0)
    }

    @Test func phaseIdle_withinHideRangeOfTop_staysAttachedToContent() {
        // Near the top the header moves with the content; snapping would detach it.
        drag(to: [0, 30, 70])
        scroll.phaseChanged(to: .idle)

        #expect(scroll.hiddenAmount == 70)
    }

    // MARK: - Short Screens

    @Test func shortScreen_forceScroll_collapsesFullyThenExpandsOnRelease() {
        // Max offset 30 of a 100 range: the header follows the finger fully, then never rests part-way.
        let offsets: [CGFloat] = [0, 20, 30, 45, 60, 70]
        drag(to: offsets.map { HeaderLayout.headerOffset(contentOffset: $0, maxOffset: 30, collapseRange: 100) })
        #expect(scroll.hiddenAmount == 100)

        scroll.phaseChanged(to: .decelerating)
        drag(to: [50, 30, 10, 0].map { HeaderLayout.headerOffset(contentOffset: $0, maxOffset: 30, collapseRange: 100) }, phase: nil)
        scroll.phaseChanged(to: .idle)

        #expect(scroll.hiddenAmount == 0)
    }

    // MARK: - Reset

    @Test func reset_showsHeaderFully() {
        hideFully()

        scroll.reset()

        #expect(scroll.hiddenAmount == 0)
    }

    @Test func reset_nextSampleIsBaseline() {
        // A new feed's offset differs from the old one's; that difference isn't scrolling.
        hideFully()
        scroll.reset()

        drag(to: [700])

        #expect(scroll.hiddenAmount == 0)
    }

    // MARK: - Progress

    @Test func progress_readBeforeRangeIsKnown_stillTracksHiding() {
        // The header draws before it's measured; if that read skipped the offset it would never redraw.
        scroll.hideRange = 0
        let changed = Mutex(false)
        withObservationTracking { _ = scroll.progress } onChange: { changed.withLock { $0 = true } }

        scroll.hideRange = 100
        drag(to: [0, 500, 550])

        #expect(changed.withLock { $0 })
        #expect(scroll.progress == 0.5)
    }

    @Test func canHideFalse_showsHeaderAndIgnoresScrolling() {
        // VoiceOver and Reduce Motion users must always reach the pills.
        hideFully()

        scroll.canHide = false
        drag(to: [600, 700])

        #expect(scroll.hiddenAmount == 0)
    }

    // MARK: - Snap Range

    @Test func snapRange_headerThatCannotHide_isZero() {
        // Snapping content to a collapse that never happens would only fight the user's scrolling.
        #expect(scroll.snapRange == 100)

        scroll.canHide = false

        #expect(scroll.snapRange == 0)
    }
}

// MARK: - Helpers

private extension FeedHeaderScrollTests {
    func drag(to offsets: [CGFloat], interval: TimeInterval = 0.016, phase: ScrollPhase? = .interacting) {
        if let phase { scroll.phaseChanged(to: phase) }
        for offset in offsets {
            clock.now += interval
            scroll.scrolled(to: offset)
        }
    }

    func hideFully() {
        drag(to: [0, 500, 560, 620])
        #expect(scroll.hiddenAmount == 100)
    }
}

private final class TestClock {
    var now = Date(timeIntervalSince1970: 0)
}
