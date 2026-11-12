import SwiftUI

extension EnvironmentValues {
    /// Receives the screen's scrolling; set by the collapsing screen header, `nil` elsewhere.
    @Entry var feedHeaderScroll: FeedHeaderScroll?
    /// False on neighbour pages kept alive by the pager; their toolbar items would land in the shared bar.
    @Entry var isSelectedFeed = true
    /// Selects another feed in place, e.g. from an empty state pointing elsewhere.
    @Entry var openFeed: (@MainActor (FeedID) -> Void)?
    /// A change scrolls every feed that reports its scroll back to its top.
    @Entry var scrollToTopRequest = 0
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
    @Environment(\.scrollToTopRequest) private var scrollToTopRequest
    /// How far the content alone overflows, without the room added here.
    @State private var overflow: CGFloat = 0
    @State private var position = ScrollPosition()

    private var extraRoom: CGFloat {
        HeaderLayout.extraScrollRoom(overflow: overflow, collapseRange: headerScroll?.snapRange ?? 0)
    }

    func body(content: Content) -> some View {
        content
            .safeAreaPadding(.bottom, extraRoom)
            .scrollTargetBehavior(HeaderSnap(collapseRange: headerScroll?.snapRange ?? 0))
            .scrollPosition($position)
            .onChange(of: scrollToTopRequest) { position.scrollTo(edge: .top) }
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                // Top overscroll kept so a pull-down at the top reads as upward.
                HeaderLayout.headerOffset(
                    contentOffset: geometry.contentOffset.y + geometry.contentInsets.top,
                    maxOffset: geometry.maxRestingOffset,
                    collapseRange: headerScroll?.snapRange ?? 0
                )
            } action: { _, offset in
                headerScroll?.scrolled(to: offset)
            }
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top > 0
            } action: { _, isScrolled in
                headerScroll?.isScrolled = isScrolled
            }
            .onScrollPhaseChange { old, phase, context in
                // Read as a drag starts: geometry-change actions can drop during a push transition.
                if old == .idle { overflow = context.geometry.maxRestingOffset - extraRoom }
                headerScroll?.phaseChanged(to: phase)
            }
    }
}

/// Moves a drag's resting point out of the header's collapse range, so the header never rests part-way.
private struct HeaderSnap: ScrollTargetBehavior {
    let collapseRange: CGFloat

    /// Targets already count from the content's resting top, past the header's content margin.
    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        guard let snapped = HeaderLayout.snappedOffset(
            restingAt: target.rect.minY,
            collapseRange: collapseRange,
            maxOffset: context.contentSize.height - context.containerSize.height
        ) else { return }
        target.rect.origin.y = snapped
    }
}

private extension ScrollGeometry {
    /// Uses `visibleRect`, the only size that spans the insets; `containerSize` excludes them.
    var maxRestingOffset: CGFloat {
        contentSize.height + contentInsets.top + contentInsets.bottom - visibleRect.height
    }
}
