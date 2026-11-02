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
    @Namespace private var highlight

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: Mortar.Spacing.s) {
                    ForEach(pills) { pill in
                        PillButton(pill: pill, isSelected: pill.id == selection, highlight: highlight) {
                            onSelect(pill.id)
                        }
                        .modifier(UnpinActions(isPinned: pill.isPinned) { onUnpin(pill.id) })
                        .id(pill.id)
                    }
                    PinMenu(unpinnedFeeds: unpinnedFeeds, onPin: onPin)
                }
                // Selection changes from swipes aren't animated, so the highlight animates itself.
                .animation(reduceMotion ? nil : Mortar.Motion.springElastic, value: selection)
                .padding(.horizontal, Mortar.Spacing.l)
                .padding(.vertical, Mortar.Spacing.xs)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
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
    let highlight: Namespace.ID
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
            .background {
                Capsule().fill(.regularMaterial)
                if isSelected {
                    // One capsule matched across pills, so the highlight slides to the new selection.
                    Capsule().fill(Color.accentColor).matchedGeometryEffect(id: "highlight", in: highlight)
                }
            }
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
