import SwiftUI
import Mortar

/// The title and pill row floating over the feeds.
struct FeedHeader: View {
    let title: String
    let pills: [MainNavigationViewModel.Pill]
    let unpinnedFeeds: [MainNavigationViewModel.Pill]
    let selection: FeedID
    let onSelect: (FeedID) -> Void
    let onPin: (FeedID) -> Void
    let onUnpin: (FeedID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.largeTitle.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, Mortar.Spacing.l)
            PillRow(
                pills: pills,
                unpinnedFeeds: unpinnedFeeds,
                selection: selection,
                onSelect: onSelect,
                onPin: onPin,
                onUnpin: onUnpin
            )
        }
        .padding(.bottom, Mortar.Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground), ignoresSafeAreaEdges: .top)
    }
}

private struct PillRow: View {
    let pills: [MainNavigationViewModel.Pill]
    let unpinnedFeeds: [MainNavigationViewModel.Pill]
    let selection: FeedID
    let onSelect: (FeedID) -> Void
    let onPin: (FeedID) -> Void
    let onUnpin: (FeedID) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pillFrames: [FeedID: CGRect] = [:]
    @State private var highlightX: CGFloat = 0
    @State private var highlightWidth: CGFloat = 0
    @State private var highlightMove = 0
    @State private var highlightedFeed: FeedID?
    @State private var isHighlightMoving = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: Mortar.Spacing.s) {
                    ForEach(pills) { pill in
                        PillButton(pill: pill, isSelected: pill.id == selection) {
                            onSelect(pill.id)
                        }
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: {
                            pillFrames[pill.id] = $0
                        }
                        .modifier(UnpinActions(isPinned: pill.isPinned) { onUnpin(pill.id) })
                        .id(pill.id)
                    }
                    PinMenu(unpinnedFeeds: unpinnedFeeds, onPin: onPin)
                }
                .coordinateSpace(.named(Self.space))
                // Drawn behind the pills rather than in each one, so the highlight can travel between them.
                .background {
                    // Indexed, not by feed ID: `scrollTo` would otherwise find these full-width layers.
                    ForEach(Array(pills.enumerated()), id: \.offset) { _, pill in
                        if let frame = pillFrames[pill.id] {
                            Capsule().fill(.regularMaterial)
                                .frame(width: frame.width, height: frame.height)
                                .position(x: frame.midX, y: frame.midY)
                        }
                    }
                    if let frame = pillFrames[selection] {
                        Capsule().fill(Color.accentColor)
                            .frame(width: highlightWidth, height: frame.height)
                            .position(x: highlightX, y: frame.midY)
                    }
                }
                .padding(.horizontal, Mortar.Spacing.l)
                .padding(.vertical, Mortar.Spacing.xs)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .onChange(of: selection) {
                moveHighlight()
                withAnimation(reduceMotion ? nil : Mortar.Motion.springNormal) {
                    proxy.scrollTo(selection, anchor: .center)
                }
            }
            // Keyed to the pill it sits on, so a selection change can't snap it before it starts moving.
            .onChange(of: pillFrames[highlightedFeed ?? selection], initial: true) { _, frame in
                guard let frame, !isHighlightMoving else { return }
                highlightX = frame.midX
                highlightWidth = frame.width
            }
        }
    }

    private static let space = "pillRow"

    /// Like the system tab bar: the highlight balls up into a circle, travels, then spreads over the new pill.
    private func moveHighlight() {
        guard let target = pillFrames[selection] else { return }
        highlightedFeed = selection
        guard !reduceMotion, highlightWidth > 0 else {
            highlightX = target.midX
            highlightWidth = target.width
            return
        }
        highlightMove += 1
        let move = highlightMove
        isHighlightMoving = true
        withAnimation(Mortar.Motion.springSnappy) { highlightX = target.midX }
        withAnimation(.easeOut(duration: Mortar.Motion.fast)) {
            highlightWidth = target.height
        } completion: {
            guard move == highlightMove else { return }
            withAnimation(Mortar.Motion.springBouncy) {
                highlightWidth = target.width
            } completion: {
                if move == highlightMove { isHighlightMoving = false }
            }
        }
    }
}

private struct PillButton: View {
    let pill: MainNavigationViewModel.Pill
    let isSelected: Bool
    let action: () -> Void

    @ScaledMetric(relativeTo: .subheadline) private var iconSize = Mortar.IconSize.xs

    var body: some View {
        Button(action: action) {
            Label {
                Text(pill.summary.title)
            } icon: {
                if pill.summary.icon.hasPrefix("mdi:") {
                    MDIIcon(name: pill.summary.icon, size: iconSize)
                } else {
                    Image(systemName: pill.summary.icon)
                }
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, Mortar.Spacing.l)
            .frame(minHeight: Mortar.TapTarget.minimum)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .animation(.easeInOut(duration: Mortar.Motion.normal), value: isSelected)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A feed action in the navigation bar, where the system draws its glass.
struct FeedActionButton: View {
    let action: FeedAction
    let perform: (_ item: String?) -> Void

    var body: some View {
        if let menu = action.menu {
            Menu {
                ForEach(menu) { item in
                    // A toggle draws the checkmark; unselected it looks like a plain menu button.
                    Toggle(isOn: Binding(get: { item.isSelected }, set: { _ in perform(item.id) })) {
                        if let icon = item.icon {
                            Label(item.title, systemImage: icon)
                        } else {
                            Text(item.title)
                        }
                    }
                }
            } label: {
                Label(action.title, systemImage: action.icon)
                    .labelStyle(.iconOnly)
            }
        } else {
            Button { perform(nil) } label: {
                Label(action.title, systemImage: action.icon)
                    .labelStyle(.iconOnly)
            }
        }
    }
}

private struct HeaderIconLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .labelStyle(.iconOnly)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color.primary)
            .frame(width: Mortar.TapTarget.minimum, height: Mortar.TapTarget.minimum)
            .background(.regularMaterial, in: .circle)
            .contentShape(.circle)
    }
}

/// Long-press menu and VoiceOver action, only on pills the user pinned.
private struct UnpinActions: ViewModifier {
    let isPinned: Bool
    let unpin: () -> Void

    func body(content: Content) -> some View {
        if isPinned {
            content
                .contextMenu {
                    Button(Localization.unpin, systemImage: "pin.slash", role: .destructive, action: unpin)
                }
                .accessibilityAction(named: Localization.unpin, unpin)
        } else {
            content
        }
    }
}

/// The + at the end of the row, offering feeds not yet pinned.
private struct PinMenu: View {
    let unpinnedFeeds: [MainNavigationViewModel.Pill]
    let onPin: (FeedID) -> Void

    var body: some View {
        Menu {
            if unpinnedFeeds.isEmpty {
                Button(Localization.allAreasPinned) {}
                    .disabled(true)
            } else {
                ForEach(unpinnedFeeds) { feed in
                    Button(feed.summary.title) { onPin(feed.id) }
                }
            }
        } label: {
            HeaderIconLabel(title: Localization.pinArea, systemImage: "plus")
        }
        .buttonStyle(.plain)
    }
}

private extension UnpinActions {
    enum Localization {
        static let unpin = String(localized: "Unpin", comment: "Removes a pinned area's pill from the main screen's pill row")
    }
}

private extension PinMenu {
    enum Localization {
        static let pinArea = String(localized: "Pin Area", comment: "Accessibility label for the + button that pins an area to the pill row")
        static let allAreasPinned = String(
            localized: "All areas pinned",
            comment: "Disabled item in the + menu of the pill row when every area is already pinned"
        )
    }
}
