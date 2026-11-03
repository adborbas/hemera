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
