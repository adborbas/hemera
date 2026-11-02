import SwiftUI

extension EnvironmentValues {
    /// Receives the feed's scroll offset; set by the navigation screen, `nil` outside it.
    @Entry var feedScrollOffsetChanged: (@MainActor (CGFloat) -> Void)?
    @Entry var feedScrollPhaseChanged: (@MainActor (ScrollPhase) -> Void)?
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
    @Environment(\.feedScrollOffsetChanged) private var offsetChanged
    @Environment(\.feedScrollPhaseChanged) private var phaseChanged

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                // Bottom bounce clamped; top overscroll kept so a pull-down at the top reads as upward.
                let top = geometry.contentInsets.top
                let maxOffset = geometry.contentSize.height + top + geometry.contentInsets.bottom
                    - geometry.containerSize.height
                return min(geometry.contentOffset.y + top, max(0, maxOffset))
            } action: { _, offset in
                offsetChanged?(offset)
            }
            .onScrollPhaseChange { _, phase in
                phaseChanged?(phase)
            }
    }
}
