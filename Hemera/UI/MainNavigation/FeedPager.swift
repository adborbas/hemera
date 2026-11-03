import SwiftUI
import Mortar

/// Horizontal paging over feeds, bound to the selection in both directions.
struct FeedPager: View {
    let feeds: [FeedID]
    @Binding var selection: FeedID
    let contentMargins: EdgeInsets
    let page: (FeedID) -> AnyView

    @State private var visibleFeed: FeedID?
    @State private var jump: FeedPagerJump?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var selectedIndex: Int {
        feeds.firstIndex(of: selection) ?? 0
    }

    /// The feed a slot shows: the selection and its neighbours, or during a jump only its two ends.
    private func feed(at index: Int) -> FeedID? {
        if let jump { return jump.feed(at: index, in: feeds) }
        return abs(index - selectedIndex) <= 1 ? feeds[index] : nil
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                /**
                 Not a lazy stack: one drops the page behind a programmatic jump and rebuilding it mid-swipe
                 stalls the snap. Distant pages are placeholders instead, so only neighbours stay alive.
                */
                HStack(spacing: 0) {
                    ForEach(Array(feeds.enumerated()), id: \.element) { index, _ in
                        Group {
                            if let id = feed(at: index) {
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
                // A jump slides through a borrowed slot whose index isn't the feed it shows.
                guard jump == nil, feeds.indices.contains(index) else { return }
                visibleFeed = feeds[index]
                selection = feeds[index]
            }
            .onChange(of: selection) {
                guard visibleFeed != selection, jump == nil else { return }
                move(to: selection, with: proxy)
            }
            // A programmatic scroll isn't a state animation, so its end comes from the scroll view going idle.
            .onScrollPhaseChange { _, phase in
                guard phase == .idle, let jump else { return }
                finish(jump, with: proxy)
            }
            // A pill added or removed before the current page shifts pages under a scroll offset that stays put.
            .onChange(of: feeds) {
                guard jump == nil else { return }
                proxy.scrollTo(selection, anchor: .leading)
            }
            .onAppear { proxy.scrollTo(selection, anchor: .leading) }
        }
    }

    /// Any distance animates like a move to the next page: the target borrows the neighbouring slot.
    private func move(to target: FeedID, with proxy: ScrollViewProxy) {
        guard !reduceMotion,
              let from = visibleFeed.flatMap(feeds.firstIndex(of:)),
              let to = feeds.firstIndex(of: target) else {
            proxy.scrollTo(target, anchor: .leading)
            visibleFeed = target
            return
        }
        guard abs(to - from) > 1 else {
            withAnimation(Mortar.Motion.springNormal) { proxy.scrollTo(target, anchor: .leading) }
            return
        }
        let jump = FeedPagerJump(from: from, to: to)
        self.jump = jump
        withAnimation(Mortar.Motion.springNormal) {
            proxy.scrollTo(feeds[jump.slot], anchor: .leading)
        }
    }

    /// The target's real slot shows the same page, so swapping to it without animation is invisible.
    private func finish(_ jump: FeedPagerJump, with proxy: ScrollViewProxy) {
        self.jump = nil
        visibleFeed = feeds[jump.to]
        proxy.scrollTo(feeds[jump.to], anchor: .leading)
    }
}

/// A pill jump of more than one page, shown in the slot next to where it starts.
struct FeedPagerJump: Equatable {
    let from: Int
    let to: Int

    var slot: Int { from + (to > from ? 1 : -1) }

    /// Only the page being left and the borrowed slot are built; everything in between stays empty.
    func feed(at index: Int, in feeds: [FeedID]) -> FeedID? {
        switch index {
        case from: feeds[from]
        case slot: feeds[to]
        default: nil
        }
    }
}
