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

    /// Where a drag resting part-way through the collapse ends instead, like system large titles.
    static func snappedOffset(restingAt offset: CGFloat, collapseRange: CGFloat) -> CGFloat? {
        guard offset > 0, offset < collapseRange else { return nil }
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
