import SwiftUI
import Mortar

/// How far the feed header is scrolled away; its own object so scrolling redraws only the header.
@Observable
@MainActor
final class FeedHeaderScroll {

    // MARK: - Properties

    private(set) var hiddenAmount: CGFloat = 0
    /// How far the header moves up when fully collapsed.
    @ObservationIgnored var hideRange: CGFloat = 0
    /// 0 expanded, 1 collapsed; reads `hiddenAmount` first so views drawn before the range still track it.
    var progress: CGFloat {
        let hidden = hiddenAmount
        return hideRange > 0 ? min(1, hidden / hideRange) : 0
    }
    @ObservationIgnored var canHide = true {
        didSet { if !canHide { reset() } }
    }

    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var isInteracting = false
    @ObservationIgnored private var lastOffset: CGFloat = 0
    @ObservationIgnored private var lastTime = Date.distantPast
    @ObservationIgnored private var upwardTravel: CGFloat = 0
    @ObservationIgnored private var needsBaseline = true

    // MARK: - Init

    init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    // MARK: - Public Methods

    func scrolled(to offset: CGFloat) {
        let time = now()
        defer { lastOffset = offset; lastTime = time }
        guard canHide else { return }
        if needsBaseline {
            needsBaseline = false
            return
        }
        let delta = offset - lastOffset
        // Content-size changes and programmatic jumps aren't scrolling.
        guard abs(delta) < Constants.maxSampleJump else { return }

        var hidden = hiddenAmount
        if delta > 0 {
            upwardTravel = 0
            hidden = min(hidden + delta, hideRange)
        } else if delta < 0, hidden > 0 {
            upwardTravel -= delta
            let upwardSpeed = -delta / max(time.timeIntervalSince(lastTime), Constants.minSampleInterval)
            // Finger-down only: the end-of-content bounce comes after release, so it never reveals.
            if isInteracting, upwardTravel >= Constants.revealTravel, upwardSpeed >= Constants.revealSpeed {
                upwardTravel = 0
                withAnimation(Mortar.Motion.springNormal) { hiddenAmount = 0 }
                return
            }
        }
        // Never hidden further than scrolled, so no gap opens above the first row.
        hidden = min(hidden, max(0, offset))
        if hidden != hiddenAmount { hiddenAmount = hidden }
    }

    func phaseChanged(to phase: ScrollPhase) {
        isInteracting = phase == .interacting
        if phase == .idle { snap() }
    }

    func reset() {
        needsBaseline = true
        upwardTravel = 0
        guard hiddenAmount != 0 else { return }
        withAnimation(Mortar.Motion.springNormal) { hiddenAmount = 0 }
    }
}

// MARK: - Private Methods

private extension FeedHeaderScroll {
    enum Constants {
        static let revealTravel: CGFloat = 40
        static let revealSpeed: CGFloat = 600
        static let maxSampleJump: CGFloat = 150
        static let minSampleInterval: TimeInterval = 0.001
    }

    /// Within a hide range of the top the header moves with the content, so only snap beyond that.
    func snap() {
        guard lastOffset >= hideRange, hiddenAmount > 0, hiddenAmount < hideRange else { return }
        withAnimation(Mortar.Motion.springNormal) {
            hiddenAmount = hiddenAmount > hideRange / 2 ? hideRange : 0
        }
    }
}
