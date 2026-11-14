#if DEBUG
import Mortar
import SwiftUI

/** The App Store header, live: the welcome cards on a hue-cycling backdrop, recorded from an iPad. */
struct AppStoreHeaderStage: View {

    static let isRequested = CommandLine.arguments.contains("-appStoreHeader")
    /// `-appStoreHeaderCaption "Your home|live"`; `|` breaks the line, empty leaves the grid alone.
    private static let caption = UserDefaults.standard.string(forKey: "appStoreHeaderCaption")?
        .replacingOccurrences(of: "|", with: "\n") ?? "Your home\nlive"

    @State private var viewModel: WelcomeViewModel
    private let schedule: LoopSchedule

    init() {
        let schedule = LoopSchedule(loop: Layout.loop)
        self.schedule = schedule
        _viewModel = State(initialValue: WelcomeViewModel(sleep: schedule.sleepUntilNextChange, pickTile: schedule.nextTile))
    }

    // shortcut: copies WelcomeView's cluster constants; extract a shared cluster view if this ships.
    private enum Layout {
        static let loop = 30.0
        /// Theme hues the backdrop moves through and back, skipping the drab yellow-greens.
        static let hues = [0.72, 0.6, 0.5, 0.6, 0.72, 0.86, 1.07, 0.86]
        static let drift = 6.0
        static let bandAspect = 3840.0 / 1646.0
        static let tileRotation = 3.0
        static let columnOffset = 40.0
        static let tileSpacing = 14.0
        static let mediumHeight = 168.0
        static let smallHeight = 80.0
        static let clusterWidth = 380.0
        static let clusterScale = 1.2
        static let leftColumn = [0, 2, 4]
        static let rightColumn = [3, 5, 1]
    }

    var body: some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSince(schedule.anchor)
            GeometryReader { proxy in
                ZStack {
                    backdrop(time: time)
                    band(time: time)
                        .frame(width: proxy.size.width, height: proxy.size.width / Layout.bandAspect)
                }
            }
        }
        .ignoresSafeArea()
        .environment(\.cardSurface, .wash)
        .environment(\.colorScheme, .dark)
        .statusBarHidden()
        .task { await viewModel.run() }
    }

    /** Muted like the listing backdrops; eases through `Layout.hues` once per loop, so it loops. */
    private func backdrop(time: TimeInterval) -> some View {
        let position = (time / Layout.loop).truncatingRemainder(dividingBy: 1) * Double(Layout.hues.count)
        let index = Int(position) % Layout.hues.count
        let from = Layout.hues[index], to = Layout.hues[(index + 1) % Layout.hues.count]
        let eased = (1 - cos((position - Double(index)) * .pi)) / 2
        let hue = from + (to - from) * eased
        let color = { (hue: Double) in Color(hue: hue.truncatingRemainder(dividingBy: 1), saturation: 0.45, brightness: 0.5) }
        return ZStack {
            LinearGradient(colors: [color(hue), color(hue + 0.08)], startPoint: .leading, endPoint: .trailing)
            LinearGradient(colors: [.clear, .black.opacity(0.5)], startPoint: .top, endPoint: .bottom)
        }
    }

    private func band(time: TimeInterval) -> some View {
        HStack(spacing: 56) {
            if !Self.caption.isEmpty {
                Text(Self.caption)
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
            HStack(alignment: .center, spacing: Mortar.Spacing.s) {
                column(Layout.leftColumn, rotation: -Layout.tileRotation, time: time)
                    .offset(y: -Layout.columnOffset / 2)
                column(Layout.rightColumn, rotation: Layout.tileRotation, time: time)
                    .offset(y: Layout.columnOffset / 2)
            }
            .frame(width: Layout.clusterWidth)
            .scaleEffect(Layout.clusterScale)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
    }

    private func column(_ indices: [Int], rotation: Double, time: TimeInterval) -> some View {
        VStack(spacing: Layout.tileSpacing) {
            ForEach(indices.filter(viewModel.tiles.indices.contains), id: \.self) { index in
                let tile = viewModel.tiles[index]
                tile.card.makeCardView()
                    .environment(\.isMediumTile, tile.isMedium)
                    .allowsHitTesting(false)
                    .frame(height: tile.isMedium ? Layout.mediumHeight : Layout.smallHeight)
                    .rotationEffect(.degrees(rotation))
                    .offset(y: sin(time * 2 * .pi / Layout.drift + Double(index)) * 4)
            }
        }
    }
}

/**
 One loop of state changes: random-looking but fixed, one tile at a time, 1.5-2 s apart across the
 loop point too. Toggling tiles change an even number of times, so each loop ends where it started.
*/
private final class LoopSchedule {

    /// Changes per tile in `WelcomeViewModel.tiles` order; the scene (4) is momentary, so any count.
    private static let changesPerTile = [4, 4, 2, 2, 3, 2]

    let anchor = Date.now.addingTimeInterval(1)
    private let loop: TimeInterval
    private let tiles: [Int]
    private let times: [TimeInterval]
    private var step = 0

    init(loop: TimeInterval) {
        var rng = SplitMix(seed: 2026)
        let pool = Self.changesPerTile.enumerated().flatMap { Array(repeating: $0.offset, count: $0.element) }
        var tiles = pool
        repeat {
            tiles.shuffle(using: &rng)
        } while tiles.indices.contains { tiles[$0] == tiles[($0 + 1) % tiles.count] }
        var gaps: [Double]
        repeat {
            gaps = tiles.map { _ in Double.random(in: 1.5...2, using: &rng) }
            let sum = gaps.reduce(0, +)
            gaps = gaps.map { $0 * loop / sum }
        } while !gaps.allSatisfy { (1.5...2).contains($0) }
        self.loop = loop
        self.tiles = tiles
        self.times = gaps.indices.map { gaps[..<$0].reduce(0, +) }
    }

    @MainActor
    func sleepUntilNextChange(_: Duration) async throws {
        let cycle = Double(step / times.count)
        let target = anchor.addingTimeInterval(cycle * loop + times[step % times.count])
        try await Task.sleep(for: .seconds(max(0, target.timeIntervalSinceNow)))
    }

    func nextTile(_: [Int]) -> Int? {
        defer { step += 1 }
        return tiles[step % tiles.count]
    }
}

/// Seeded, so every launch plays the same loop.
private struct SplitMix: RandomNumberGenerator {
    var seed: UInt64

    mutating func next() -> UInt64 {
        seed &+= 0x9E37_79B9_7F4A_7C15
        var z = seed
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
#endif
