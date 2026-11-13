import Foundation
import Testing
@testable import Hemera

@MainActor
struct WelcomeViewModelTests {

    private let clock = FakeClock()
    private let picker = SpyTilePicker()
    private let viewModel: WelcomeViewModel

    init() {
        let clock = clock
        let picker = picker
        viewModel = WelcomeViewModel(
            sleep: { try await clock.sleep(for: $0) },
            now: { clock.now },
            pickTile: { picker.pick(from: $0) }
        )
    }

    @Test func run_neverChangesTheSameTileTwiceInARow() async {
        clock.stopAfterSleeps = 10

        await viewModel.run()

        #expect(picker.picks.count == 9)
        for (previous, next) in zip(picker.picks, picker.picks.dropFirst()) {
            #expect(previous != next)
        }
    }

    @Test func run_afterTap_waitsFiveSecondsBeforeTheNextChange() async throws {
        clock.stopAfterSleeps = 3
        let tile = try #require(viewModel.tiles.first)

        viewModel.tap(tile)
        await viewModel.run()

        // The tap holds changes until 5 s, so after the 3 s wait the loop sleeps the remaining 2 s.
        #expect(clock.sleeps == [.seconds(3), .seconds(2), .seconds(3)])
        #expect(picker.picks.count == 1)
    }

    @Test func run_withoutTap_changesATileEveryThreeSeconds() async {
        clock.stopAfterSleeps = 3

        await viewModel.run()

        #expect(clock.sleeps == [.seconds(3), .seconds(3), .seconds(3)])
        #expect(picker.picks.count == 2)
    }

    @Test func run_whenCancelled_stopsChangingTiles() async {
        clock.stopAfterSleeps = 2

        await viewModel.run()

        #expect(picker.picks.count == 1)
    }

    @Test func run_afterGetStarted_stopsChangingTiles() async {
        clock.onSleep = { [viewModel] count in
            if count == 2 { viewModel.getStarted {} }
        }
        clock.stopAfterSleeps = 10

        await viewModel.run()

        #expect(viewModel.isLeaving)
        #expect(picker.picks.count == 1)
    }

    @Test func getStarted_proceedsAfterTheExit() async throws {
        var didProceed = false

        viewModel.getStarted { didProceed = true }
        try await Task.sleep(for: .milliseconds(100))

        #expect(didProceed)
        #expect(clock.sleeps == [.seconds(0.35)])
    }
}

// MARK: - Fakes

@MainActor
private final class FakeClock {
    var now = ContinuousClock.now
    var sleeps: [Duration] = []
    var stopAfterSleeps = Int.max
    var onSleep: ((Int) -> Void)?

    /** Advances time instantly; the last allowed sleep throws as a cancelled task's would. */
    func sleep(for duration: Duration) async throws {
        sleeps.append(duration)
        onSleep?(sleeps.count)
        now = now.advanced(by: duration)
        if sleeps.count >= stopAfterSleeps { throw CancellationError() }
    }
}

private final class SpyTilePicker {
    var picks: [Int] = []

    /** Always takes the first candidate, so a loop that offered the last tile again would repeat it. */
    func pick(from candidates: [Int]) -> Int? {
        let pick = candidates.first
        picks.append(pick ?? -1)
        return pick
    }
}
