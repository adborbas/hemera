import CoreGraphics

/// Geometry shared by the collapsing headers, kept out of the views so it can be tested.
enum HeaderLayout {

    /// How far the header moves up for the pill row to sit centred in the button row at its top.
    static func collapseDistance(pillRowMidY: CGFloat, buttonRowHeight: CGFloat) -> CGFloat {
        max(0, pillRowMidY - buttonRowHeight / 2)
    }

    /// Fades over half the title's height: gone before it reaches the button row, back once clear of it.
    static func titleOpacity(hiddenAmount: CGFloat, titleHeight: CGFloat) -> Double {
        titleHeight > 0 ? max(0, 1 - hiddenAmount / (titleHeight / 2)) : 1
    }

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
}
