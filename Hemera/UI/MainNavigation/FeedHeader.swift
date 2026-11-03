import SwiftUI
import Mortar

/// The title and pill row floating over the feeds; collapsing moves the pills up into the button row.
struct FeedHeader: View {
    let title: String
    let pills: [MainNavigationViewModel.Pill]
    let unpinnedFeeds: [MainNavigationViewModel.Pill]
    let selection: FeedID
    let onSelect: (FeedID) -> Void
    let onPin: (FeedID) -> Void
    let onUnpin: (FeedID) -> Void
    let scroll: FeedHeaderScroll
    /// Width of the floating buttons, which the pill row makes room for as it rises into their row.
    let buttonsWidth: CGFloat
    let onCollapseDistanceChange: (CGFloat) -> Void

    @State private var titleHeight: CGFloat = 0
    @State private var pillRowMidY: CGFloat = 0

    private let coordinateSpace = "FeedHeader"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The row the floating buttons sit in.
            Color.clear.frame(height: Mortar.TapTarget.minimum)
            Text(title)
                .font(.largeTitle.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, Mortar.Spacing.l)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { titleHeight = $0 }
                .modifier(TitleFade(scroll: scroll, titleHeight: titleHeight))
            PillRow(
                pills: pills,
                unpinnedFeeds: unpinnedFeeds,
                selection: selection,
                onSelect: onSelect,
                onPin: onPin,
                onUnpin: onUnpin
            )
            // Only the centre: the row's width changes every frame as it makes room for the buttons.
            .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(coordinateSpace)).midY } action: { pillRowMidY = $0 }
            .modifier(ButtonsReserve(scroll: scroll, width: buttonsWidth + Mortar.Spacing.l + Mortar.Spacing.s))
        }
        .coordinateSpace(.named(coordinateSpace))
        .padding(.bottom, Mortar.Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(HeaderBackground())
        .onChange(of: collapseDistance, initial: true) { onCollapseDistanceChange($1) }
    }

    private var collapseDistance: CGFloat {
        HeaderLayout.collapseDistance(pillRowMidY: pillRowMidY, buttonRowHeight: Mortar.TapTarget.minimum)
    }
}

// MARK: - Scroll Readers

/// Per-frame readers live in modifiers, so scrolling redraws them and not the views they wrap.
private struct TitleFade: ViewModifier {
    let scroll: FeedHeaderScroll
    let titleHeight: CGFloat

    func body(content: Content) -> some View {
        content.opacity(HeaderLayout.titleOpacity(hiddenAmount: scroll.hiddenAmount, titleHeight: titleHeight))
    }
}

private struct ButtonsReserve: ViewModifier {
    let scroll: FeedHeaderScroll
    let width: CGFloat

    func body(content: Content) -> some View {
        content.padding(.trailing, width * scroll.progress)
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

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: Mortar.Spacing.s) {
                    ForEach(pills) { pill in
                        PillButton(pill: pill, isSelected: pill.id == selection) {
                            onSelect(pill.id)
                        }
                        .modifier(UnpinActions(isPinned: pill.isPinned) { onUnpin(pill.id) })
                        .id(pill.id)
                    }
                    PinMenu(unpinnedFeeds: unpinnedFeeds, onPin: onPin)
                }
                .padding(.horizontal, Mortar.Spacing.l)
                .padding(.vertical, Mortar.Spacing.xs)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            // Pills fade out at both ends instead of being cut off.
            .mask {
                HStack(spacing: 0) {
                    LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                        .frame(width: Mortar.Spacing.l)
                    Color.black
                    LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: Mortar.Spacing.l)
                }
            }
            .onChange(of: selection) {
                withAnimation(reduceMotion ? nil : Mortar.Motion.springNormal) {
                    proxy.scrollTo(selection, anchor: .center)
                }
            }
        }
    }
}

private struct PillButton: View {
    let pill: MainNavigationViewModel.Pill
    let isSelected: Bool
    let action: () -> Void

    @ScaledMetric(relativeTo: .subheadline) private var iconSize = Mortar.IconSize.xs
    @Environment(\.colorScheme) private var colorScheme

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
            .background(
                isSelected ? AnyShapeStyle(Color.accentColor) : PillFill.unselected(colorScheme),
                in: .capsule
            )
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A feed action in the header's floating button group.
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
                    .frame(width: Mortar.TapTarget.minimum, height: Mortar.TapTarget.minimum)
                    .contentShape(.rect)
            }
        } else {
            Button { perform(nil) } label: {
                Label(action.title, systemImage: action.icon)
                    .labelStyle(.iconOnly)
                    .frame(width: Mortar.TapTarget.minimum, height: Mortar.TapTarget.minimum)
                    .contentShape(.rect)
            }
        }
    }
}

private struct HeaderIconLabel: View {
    let title: String
    let systemImage: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Label(title, systemImage: systemImage)
            .labelStyle(.iconOnly)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color.primary)
            .frame(width: Mortar.TapTarget.minimum, height: Mortar.TapTarget.minimum)
            .background(PillFill.unselected(colorScheme), in: .circle)
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
