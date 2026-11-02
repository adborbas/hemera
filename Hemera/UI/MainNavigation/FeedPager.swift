import SwiftUI
import Mortar

/// Horizontal paging over feeds, bound to the selection in both directions.
struct FeedPager: View {
    let feeds: [FeedID]
    @Binding var selection: FeedID
    let contentMargins: EdgeInsets
    let page: (FeedID) -> AnyView

    @State private var visibleFeed: FeedID?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var selectedIndex: Int {
        feeds.firstIndex(of: selection) ?? 0
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                /**
                 Not a lazy stack: one drops the page behind a programmatic jump and rebuilding it mid-swipe
                 stalls the snap. Distant pages are placeholders instead, so only neighbours stay alive.
                */
                HStack(spacing: 0) {
                    ForEach(Array(feeds.enumerated()), id: \.element) { index, id in
                        Group {
                            if abs(index - selectedIndex) <= 1 {
                                page(id)
                                    // Per page: on the pager they would hit its own paging scroll view.
                                    .contentMargins(.top, contentMargins.top, for: .scrollContent)
                                    .contentMargins(.bottom, contentMargins.bottom, for: .scrollContent)
                            } else {
                                Color.clear
                            }
                        }
                        .containerRelativeFrame(.horizontal)
                    }
                }
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            // One-shot scrolls: a `scrollPosition` binding is re-asserted mid-swipe and stalls it.
            .onScrollGeometryChange(for: Int.self) { geometry in
                guard geometry.containerSize.width > 0 else { return 0 }
                return Int((geometry.contentOffset.x / geometry.containerSize.width).rounded())
            } action: { _, index in
                guard feeds.indices.contains(index) else { return }
                visibleFeed = feeds[index]
                selection = feeds[index]
            }
            .onChange(of: selection) {
                guard visibleFeed != selection else { return }
                withAnimation(reduceMotion ? nil : Mortar.Motion.springNormal) {
                    proxy.scrollTo(selection, anchor: .leading)
                }
            }
            .onAppear { proxy.scrollTo(selection, anchor: .leading) }
        }
    }
}
