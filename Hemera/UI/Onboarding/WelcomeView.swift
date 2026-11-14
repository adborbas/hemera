import SwiftUI
import Mortar

struct WelcomeView: View {

    var onGetStarted: () -> Void

    @State private var viewModel = WelcomeViewModel()
    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        GeometryReader { proxy in
            if horizontalSizeClass == .regular {
                regularLayout(height: proxy.size.height)
            } else {
                compactLayout(height: proxy.size.height)
            }
        }
        .background { Color(uiColor: .systemBackground).ignoresSafeArea() }
        .environment(\.cardSurface, .wash)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            do { try await Task.sleep(for: .milliseconds(50)) } catch { return }
            hasAppeared = true
            await viewModel.run()
        }
        .onDisappear { hasAppeared = false }
    }
}

// MARK: - Layout

private extension WelcomeView {

    enum Layout {
        static let tileRotation = 3.0
        static let tileScale = 0.9
        static let columnOffset = 40.0
        static let tileSpacing = 14.0
        static let mediumHeight = 168.0
        static let smallHeight = 80.0
        static let clusterTop = 24.0
        static let clusterToHeadline = 32.0
        static let clusterWidth = 380.0
        // The taller column (168 + 80 + 80 + two gaps), the column offset and room for the tilt.
        static let clusterHeight = 412.0
        static let regularClusterScale = 1.45
        static let regularTextReserve = 330.0
        static let regularLift = 30.0
        static let regularHeadlineSize = 46.0
        static let regularHeadlineWidth = 560.0
        // Indices into `tiles`; the mediums sit on a diagonal, top left and bottom right.
        static let leftColumn = [0, 2, 4]
        static let rightColumn = [3, 5, 1]
    }

    var isAccessibilitySize: Bool { dynamicTypeSize.isAccessibilitySize }

    func compactLayout(height: CGFloat) -> some View {
        VStack(spacing: 0) {
            cluster
                .frame(maxWidth: .infinity)
                .frame(height: height * 0.5 * (isAccessibilitySize ? 0.7 : 1))
                .scaleEffect(isAccessibilitySize ? 0.75 : 1)
                .padding(.top, Layout.clusterTop)
            headline
                .padding(.top, Layout.clusterToHeadline)
            Spacer(minLength: Mortar.Spacing.l)
            actions
        }
        .padding(.horizontal, Mortar.Spacing.xl)
        .frame(maxWidth: .infinity)
    }

    /** Tiles, headline and button as one block, centred and lifted slightly. */
    func regularLayout(height: CGFloat) -> some View {
        // Shrinks on short windows so the text and button always fit under the cluster.
        let fit = (height - Layout.regularTextReserve) / Layout.clusterHeight
        let scale = min(Layout.regularClusterScale, max(0.6, fit))
        return VStack(spacing: 0) {
            Spacer(minLength: Mortar.Spacing.l)
            cluster
                .frame(width: Layout.clusterWidth, height: Layout.clusterHeight)
                .scaleEffect(scale)
                .frame(width: Layout.clusterWidth * scale, height: Layout.clusterHeight * scale)
            headline
                .frame(maxWidth: Layout.regularHeadlineWidth)
                .padding(.top, Layout.clusterToHeadline)
            actions
                .padding(.top, Mortar.Spacing.xl)
            Spacer(minLength: Mortar.Spacing.l)
        }
        .offset(y: -Layout.regularLift)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Mortar.Spacing.xl)
    }

    var cluster: some View {
        HStack(alignment: .center, spacing: Mortar.Spacing.s) {
            column(Layout.leftColumn, rotation: -Layout.tileRotation)
                .offset(y: -Layout.columnOffset / 2)
            column(Layout.rightColumn, rotation: Layout.tileRotation)
                .offset(y: Layout.columnOffset / 2)
        }
        .scaleEffect(Layout.tileScale)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Fixed-height tiles; larger text would spill out of them.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityHidden(true)
    }

    func column(_ indices: [Int], rotation: Double) -> some View {
        VStack(spacing: Layout.tileSpacing) {
            ForEach(indices.filter(viewModel.tiles.indices.contains), id: \.self) { index in
                tile(at: index, rotation: rotation)
            }
        }
    }

    func tile(at index: Int, rotation: Double) -> some View {
        let tile = viewModel.tiles[index]
        let isDrifting = hasAppeared && !viewModel.isLeaving && !reduceMotion
        return TimelineView(.animation(paused: !isDrifting)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let drift = isDrifting ? sin(time * 2 * .pi / 6 + Double(index)) * 4 : 0
            tile.card.makeCardView()
                .environment(\.isMediumTile, tile.isMedium)
                .allowsHitTesting(false)
                .frame(height: tile.isMedium ? Layout.mediumHeight : Layout.smallHeight)
                .rotationEffect(.degrees(rotation))
                .offset(y: drift)
        }
        .opacity(hasAppeared && !viewModel.isLeaving ? 1 : 0)
        .offset(y: hasAppeared || reduceMotion ? 0 : 40)
        .scaleEffect(viewModel.isLeaving && !reduceMotion ? 0.85 : 1)
        .animation(reduceMotion ? fade : spring.delay(Double(index) * 0.07), value: hasAppeared)
        .animation(reduceMotion ? fade : spring.delay(Double(index) * 0.03), value: viewModel.isLeaving)
        .contentShape(Rectangle())
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            viewModel.tap(tile)
        }
    }

    var headline: some View {
        Text(Localization.headline)
            .font(horizontalSizeClass == .regular
                  ? .system(size: Layout.regularHeadlineSize, weight: .bold)
                  : .largeTitle.bold())
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
            .opacity(hasAppeared && !viewModel.isLeaving ? 1 : 0)
            .offset(y: hasAppeared || reduceMotion ? 0 : 16)
            .animation(reduceMotion ? fade : spring.delay(0.35), value: hasAppeared)
            .animation(reduceMotion ? fade : spring, value: viewModel.isLeaving)
    }

    var actions: some View {
        VStack(spacing: Mortar.Spacing.m) {
            Button {
                viewModel.getStarted(then: onGetStarted)
            } label: {
                Text(Localization.getStarted)
            }
            .buttonStyle(.mortarPrimary(width: .fullWidth))
            .accessibilityIdentifier("welcomeGetStarted")
            Link(Localization.newToHomeAssistant, destination: URL(string: "https://www.home-assistant.io")!)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: Mortar.ContentWidth.narrow)
        .padding(.bottom, Mortar.Spacing.l)
    }

    var spring: Animation { .spring(duration: 0.6, bounce: 0.2) }
    var fade: Animation { .easeInOut(duration: 0.3) }
}

private extension WelcomeView {
    enum Localization {
        static let headline = String(localized: "Your home, at your fingertips.", comment: "Headline on the welcome screen")
        static let getStarted = String(localized: "Get Started", comment: "Button on welcome screen to begin server setup")
        static let newToHomeAssistant = String(
            localized: "New to Home Assistant?",
            comment: "Link on the welcome screen that opens the Home Assistant website"
        )
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        WelcomeView {}
    }
}
#endif
