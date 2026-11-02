import Foundation
import SwiftUI
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

    @Test func canHideFalse_showsHeaderAndIgnoresScrolling() {
        // VoiceOver and Reduce Motion users must always reach the pills.
        hideFully()

        scroll.canHide = false
        drag(to: [600, 700])

        #expect(scroll.hiddenAmount == 0)
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
