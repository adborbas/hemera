import SwiftUI

extension EnvironmentValues {
    /// Receives the selected feed's scrolling; set by the navigation screen, `nil` elsewhere.
    @Entry var feedHeaderScroll: FeedHeaderScroll?
    /// False on neighbour pages kept alive by the pager; their toolbar items would land in the shared bar.
    @Entry var isSelectedFeed = true
    /// Selects another feed in place, e.g. from an empty state pointing elsewhere.
    @Entry var openFeed: (@MainActor (FeedID) -> Void)?
}

extension View {
    /// Put on a feed's main scroll view: a parent can't observe a nested scroll view's offset.
    func reportsFeedScroll() -> some View {
        modifier(FeedScrollReporter())
    }

    /// While `true`, the navigation screen shows the system navigation bar for the feed's toolbar.
    func feedIsEditing(_ isEditing: Bool) -> some View {
        preference(key: FeedIsEditingKey.self, value: isEditing)
    }
}

struct FeedIsEditingKey: PreferenceKey {
    static let defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

private struct FeedScrollReporter: ViewModifier {
    @Environment(\.feedHeaderScroll) private var headerScroll

    func body(content: Content) -> some View {
        content
            .scrollTargetBehavior(HeaderSnap(collapseRange: headerScroll?.snapRange ?? 0))
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                // Bottom bounce clamped; top overscroll kept so a pull-down at the top reads as upward.
                let top = geometry.contentInsets.top
                let maxOffset = geometry.contentSize.height + top + geometry.contentInsets.bottom
                    - geometry.containerSize.height
                return min(geometry.contentOffset.y + top, max(0, maxOffset))
            } action: { _, offset in
                headerScroll?.scrolled(to: offset)
            }
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top > 0
            } action: { _, isScrolled in
                headerScroll?.isScrolled = isScrolled
            }
            .onScrollPhaseChange { _, phase in
                headerScroll?.phaseChanged(to: phase)
            }
    }
}

/// Moves a drag's resting point out of the header's collapse range, so the header never rests part-way.
private struct HeaderSnap: ScrollTargetBehavior {
    let collapseRange: CGFloat

    /// Targets already count from the content's resting top, past the header's content margin.
    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        guard let snapped = HeaderLayout.snappedOffset(restingAt: target.rect.minY, collapseRange: collapseRange) else { return }
        target.rect.origin.y = snapped
    }
}
