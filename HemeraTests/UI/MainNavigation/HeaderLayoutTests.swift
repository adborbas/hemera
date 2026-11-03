import CoreGraphics
import Testing
@testable import Hemera

@MainActor
struct HeaderLayoutTests {

    // MARK: - Collapse Distance

    @Test func collapseDistance_centresPillRowOnButtonRow() {
        // Button row 44, title 41, pill row 52; the header's 12pt bottom padding lies below the pills.
        let pillRowMidY: CGFloat = 44 + 41 + 52 / 2

        let distance = HeaderLayout.collapseDistance(pillRowMidY: pillRowMidY, buttonRowHeight: 44)

        // Counting the header's bottom padding as pill row put the pills 6pt below the avatar's centre.
        #expect(distance == 89)
        #expect(pillRowMidY - distance == 22)
    }

    @Test func collapseDistance_beforeLayout_isZero() {
        // Unmeasured, the pill row reports zero; the header must not move down.
        #expect(HeaderLayout.collapseDistance(pillRowMidY: 0, buttonRowHeight: 44) == 0)
    }

    // MARK: - Title Opacity

    @Test func titleOpacity_hiddenHalfTheTitle_isGone() {
        // Faded out before it reaches the button row, where it would collide with the buttons.
        #expect(HeaderLayout.titleOpacity(hiddenAmount: 20, titleHeight: 40) == 0)
        #expect(HeaderLayout.titleOpacity(hiddenAmount: 10, titleHeight: 40) == 0.5)
    }

    @Test func titleOpacity_unmeasuredTitle_isVisible() {
        #expect(HeaderLayout.titleOpacity(hiddenAmount: 30, titleHeight: 0) == 1)
    }

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
}
