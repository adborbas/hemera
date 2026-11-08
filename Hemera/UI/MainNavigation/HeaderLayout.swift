import CoreGraphics
import Mortar

/// Geometry shared by the collapsing headers, kept out of the views so it can be tested.
enum HeaderLayout {

    /// Between the button row and the large title.
    static let titleSpacing = Mortar.Spacing.m

    /**
     Where a collapsed title sits in a button row, like the system bar: centred on screen when it clears
     the buttons on both sides, else centred in the gap between them, else truncated to that gap.
    */
    static func collapsedTitle(
        width titleWidth: CGFloat,
        rowWidth: CGFloat,
        leadingReserve: CGFloat,
        trailingReserve: CGFloat
    ) -> (x: CGFloat, width: CGFloat) {
        let gap = max(0, rowWidth - leadingReserve - trailingReserve)
        let width = min(titleWidth, gap)
        if width <= rowWidth - 2 * max(leadingReserve, trailingReserve) {
            return ((rowWidth - width) / 2, width)
        }
        return (leadingReserve + (gap - width) / 2, width)
    }

    /// Enough that a firm drag on a short screen reaches full collapse despite the bounce's resistance.
    static let shortScreenOverscrollGain: CGFloat = 2

    /**
     The offset the collapsing header follows. The bottom bounce is ignored, except on a screen too short
     to scroll a full collapse: there it carries the header the rest of the way.
    */
    static func headerOffset(contentOffset: CGFloat, maxOffset: CGFloat, collapseRange: CGFloat) -> CGFloat {
        let maxOffset = max(0, maxOffset)
        guard contentOffset > maxOffset else { return contentOffset }
        guard maxOffset < collapseRange else { return maxOffset }
        return maxOffset + (contentOffset - maxOffset) * shortScreenOverscrollGain
    }

    /**
     A screen slightly too tall to fit scrolls far enough to collapse, as collapsing makes it fit. Whole
     points, so pixel rounding can't leave it just short of the snap.
    */
    static func extraScrollRoom(overflow: CGFloat, collapseRange: CGFloat) -> CGFloat {
        overflow > 0 && overflow < collapseRange ? (collapseRange - overflow).rounded(.up) : 0
    }

    /**
     Where a drag resting part-way through the collapse ends instead, like system large titles. A screen
     too short to reach full collapse has one resting place: the top.
    */
    static func snappedOffset(restingAt offset: CGFloat, collapseRange: CGFloat, maxOffset: CGFloat = .infinity) -> CGFloat? {
        guard offset > 0, collapseRange > 0 else { return nil }
        if maxOffset < collapseRange { return 0 }
        guard offset < collapseRange else { return nil }
        return offset < collapseRange / 2 ? 0 : collapseRange
    }

    /// Which ends of a padded scrolling row have content cut off by a clip `clipInset` inside its edges.
    static func edgeFades(
        offset: CGFloat,
        contentWidth: CGFloat,
        containerWidth: CGFloat,
        padding: CGFloat,
        clipInset: CGFloat
    ) -> EdgeFades {
        EdgeFades(
            leading: offset > padding - clipInset,
            trailing: contentWidth - padding - offset > containerWidth - clipInset
        )
    }

    struct EdgeFades: Equatable {
        var leading = false
        var trailing = false
    }
}
