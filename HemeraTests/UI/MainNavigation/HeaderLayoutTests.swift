import CoreGraphics
import Testing
@testable import Hemera

@MainActor
struct HeaderLayoutTests {

    // MARK: - Collapsed Title

    @Test func collapsedTitle_clearingBothSides_isCentredOnScreen() {
        // Like the system bar: a short title lines up with the screen's centre, not the gap's.
        let title = HeaderLayout.collapsedTitle(width: 100, rowWidth: 400, leadingReserve: 76, trailingReserve: 140)

        #expect(title.x == 150)
        #expect(title.width == 100)
    }

    @Test func collapsedTitle_tooWideToCentreOnScreen_isCentredInGap() {
        // Centred on screen it would run under the wider trailing buttons.
        let title = HeaderLayout.collapsedTitle(width: 160, rowWidth: 400, leadingReserve: 76, trailingReserve: 140)

        #expect(title.x == 88)
        #expect(title.width == 160)
    }

    @Test func collapsedTitle_widerThanGap_isTruncatedToGap() {
        // A long area name must stay between the buttons rather than overflow under them.
        let title = HeaderLayout.collapsedTitle(width: 300, rowWidth: 400, leadingReserve: 76, trailingReserve: 140)

        #expect(title.x == 76)
        #expect(title.width == 184)
    }

    // MARK: - Snapped Offset

    @Test func snappedOffset_lessThanHalfwayThroughCollapse_snapsExpanded() {
        #expect(HeaderLayout.snappedOffset(restingAt: 30, collapseRange: 100) == 0)
    }

    @Test func snappedOffset_pastHalfwayThroughCollapse_snapsCollapsed() {
        #expect(HeaderLayout.snappedOffset(restingAt: 60, collapseRange: 100) == 100)
    }

    @Test func snappedOffset_outsideCollapse_isLeftAlone() {
        // Resting at either end, or past the collapse where the header snaps on its own, is never moved.
        for offset: CGFloat in [-20, 0, 100, 400] {
            #expect(HeaderLayout.snappedOffset(restingAt: offset, collapseRange: 100) == nil)
        }
    }

    @Test func snappedOffset_headerThatCannotCollapse_isLeftAlone() {
        #expect(HeaderLayout.snappedOffset(restingAt: 30, collapseRange: 0) == nil)
    }

    @Test func snappedOffset_shortScreen_alwaysReturnsToTop() {
        // Past halfway a long screen snaps collapsed; a short one can't, and would rest part-way.
        #expect(HeaderLayout.snappedOffset(restingAt: 60, collapseRange: 100, maxOffset: 70) == 0)
        #expect(HeaderLayout.snappedOffset(restingAt: 20, collapseRange: 100, maxOffset: 70) == 0)
    }

    @Test func snappedOffset_screenThatReachesFullCollapse_snapsAsUsual() {
        #expect(HeaderLayout.snappedOffset(restingAt: 60, collapseRange: 100, maxOffset: 100) == 100)
    }

    // MARK: - Header Offset

    @Test func headerOffset_withinContent_followsTheContent() {
        #expect(HeaderLayout.headerOffset(contentOffset: 40, maxOffset: 500, collapseRange: 100) == 40)
    }

    @Test func headerOffset_longScreen_ignoresBottomBounce() {
        // The end-of-content bounce must not move a header that has already finished collapsing.
        #expect(HeaderLayout.headerOffset(contentOffset: 560, maxOffset: 500, collapseRange: 100) == 500)
    }

    @Test func headerOffset_shortScreen_amplifiesBounceToReachFullCollapse() {
        // Rubber-banding resists the finger, so one-to-one would never fully collapse the header.
        let offset = HeaderLayout.headerOffset(contentOffset: 65, maxOffset: 30, collapseRange: 100)

        #expect(offset >= 100)
    }

    @Test func headerOffset_contentShorterThanScreen_bounceCountsFromTheTop() {
        // Content that fits has a negative max offset, but its resting offset is still 0.
        #expect(HeaderLayout.headerOffset(contentOffset: 25, maxOffset: -200, collapseRange: 100) == 50)
    }

    @Test func headerOffset_headerThatCannotCollapse_ignoresBottomBounce() {
        #expect(HeaderLayout.headerOffset(contentOffset: 25, maxOffset: -200, collapseRange: 0) == 0)
    }

    // MARK: - Extra Scroll Room

    @Test func extraScrollRoom_slightlyTooTall_reachesFullCollapse() {
        // Without it the bottom of the content is cut off at rest, as the screen can't stay collapsed.
        #expect(HeaderLayout.extraScrollRoom(overflow: 56, collapseRange: 97) == 41)
    }

    @Test func extraScrollRoom_fractionalRange_neverFallsShortOfTheSnap() {
        // Just short of the range would count as too short to collapse, and return to the top.
        let room = HeaderLayout.extraScrollRoom(overflow: 56, collapseRange: 96.7)

        #expect(56 + room >= 96.7)
        #expect(HeaderLayout.snappedOffset(restingAt: 60, collapseRange: 96.7, maxOffset: 56 + room) == 96.7)
    }

    @Test func extraScrollRoom_contentThatFits_addsNothing() {
        // Nothing is cut off, so it stays expanded instead of scrolling into blank space.
        #expect(HeaderLayout.extraScrollRoom(overflow: 0, collapseRange: 97) == 0)
        #expect(HeaderLayout.extraScrollRoom(overflow: -200, collapseRange: 97) == 0)
    }

    @Test func extraScrollRoom_longScreen_addsNothing() {
        #expect(HeaderLayout.extraScrollRoom(overflow: 97, collapseRange: 97) == 0)
        #expect(HeaderLayout.extraScrollRoom(overflow: 500, collapseRange: 97) == 0)
    }

    @Test func extraScrollRoom_headerThatCannotCollapse_addsNothing() {
        #expect(HeaderLayout.extraScrollRoom(overflow: 56, collapseRange: 0) == 0)
    }

    // MARK: - Edge Fades

    @Test func edgeFades_atRest_fadesOnlyTheEndWithMorePills() {
        // The first pill sits fully inside the clip, so fading it would look like it was cut off.
        let fades = edgeFades(offset: 0)

        #expect(fades == HeaderLayout.EdgeFades(leading: false, trailing: true))
    }

    @Test func edgeFades_scrolledUntilPillsReachTheClip_startsFadingLeading() {
        #expect(edgeFades(offset: 8).leading == false)
        #expect(edgeFades(offset: 9).leading == true)
    }

    @Test func edgeFades_scrolledToTheEnd_fadesOnlyLeading() {
        let fades = edgeFades(offset: 210)

        #expect(fades == HeaderLayout.EdgeFades(leading: true, trailing: false))
    }

    @Test func edgeFades_pillsThatFit_neverFade() {
        let fades = edgeFades(offset: 0, contentWidth: 300)

        #expect(fades == HeaderLayout.EdgeFades())
    }

    private func edgeFades(offset: CGFloat, contentWidth: CGFloat = 600) -> HeaderLayout.EdgeFades {
        HeaderLayout.edgeFades(
            offset: offset,
            contentWidth: contentWidth,
            containerWidth: 390,
            padding: 16,
            clipInset: 8
        )
    }
}
