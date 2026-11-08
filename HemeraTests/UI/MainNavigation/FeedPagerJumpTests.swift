import Testing
@testable import Hemera

@MainActor
struct FeedPagerJumpTests {

    private let feeds: [FeedID] = [.home, .areas, .domain("light"), .domain("cover"), .domain("climate")]

    // The target borrows the slot next to the start, so a long jump slides exactly one page.
    @Test func feedAt_forwardJump_showsTargetInNextSlot() {
        let jump = FeedPagerJump(from: 0, to: 4)

        #expect(jump.slot == 1)
        #expect(jump.feed(at: 0, in: feeds) == .home)
        #expect(jump.feed(at: 1, in: feeds) == .domain("climate"))
    }

    @Test func feedAt_backwardJump_showsTargetInPreviousSlot() {
        let jump = FeedPagerJump(from: 4, to: 1)

        #expect(jump.slot == 3)
        #expect(jump.feed(at: 3, in: feeds) == .areas)
        #expect(jump.feed(at: 4, in: feeds) == .domain("climate"))
    }

    // Feeds passed over are never built, so they can't flash by during the slide.
    @Test func feedAt_jump_leavesPagesInBetweenEmpty() {
        let jump = FeedPagerJump(from: 0, to: 4)

        #expect(jump.feed(at: 2, in: feeds) == nil)
        #expect(jump.feed(at: 3, in: feeds) == nil)
        #expect(jump.feed(at: 4, in: feeds) == nil)
    }
}
