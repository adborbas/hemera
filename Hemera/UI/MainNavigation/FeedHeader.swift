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
            // Top row, shared with the account button floating above it.
            Color.clear
                .frame(height: Mortar.TapTarget.minimum)
            Text(title)
                .font(.largeTitle.bold())
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
                isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.regularMaterial),
                in: .capsule
            )
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
            Label(Localization.pinArea, systemImage: "plus")
                .labelStyle(.iconOnly)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.primary)
                .frame(width: Mortar.TapTarget.minimum, height: Mortar.TapTarget.minimum)
                .background(.regularMaterial, in: .circle)
                .contentShape(.circle)
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
