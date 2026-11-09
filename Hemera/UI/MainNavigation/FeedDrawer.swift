import SwiftUI
import Mortar

/// Compact width's side panel: the home name, one row per feed, and Settings pinned at the bottom.
struct FeedDrawer: View {
    let title: String
    let feeds: [MainNavigationViewModel.Pill]
    /// Read here, not by the parent, so entity state changes redraw only the drawer.
    let subtitle: (FeedID) -> String?
    let selection: FeedID
    @Binding var isOpen: Bool
    /// Only at the root and outside editing: on a pushed screen the same swipe goes back.
    let canSwipeOpen: Bool
    let onSelect: (FeedID) -> Void
    let openSettings: () -> Void

    @State private var drag: CGFloat = 0
    @Environment(UpdateNudge.self) private var updateNudge
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let width = min(geometry.size.width * Constants.widthFraction, Constants.maxWidth)
            let progress = min(1, max(0, (isOpen ? width : 0) + drag) / width)

            ZStack(alignment: .leading) {
                Color.black.opacity(Constants.scrimOpacity * progress)
                    .ignoresSafeArea()
                    .onTapGesture { isOpen = false }
                    .accessibilityHidden(true)

                // Counts only while visible, so a closed drawer doesn't redraw on every state change.
                panel(showsCounts: progress > 0)
                    .frame(width: width)
                    .offset(x: reduceMotion ? 0 : -width * (1 - progress))
                    .opacity(reduceMotion ? progress : 1)
                    .accessibilityHidden(!isOpen)
                    .accessibilityAddTraits(.isModal)
                    .accessibilityAction(.escape) { isOpen = false }
            }
            .animation(Mortar.Motion.springNormal, value: isOpen)
            .allowsHitTesting(progress > 0)
            .gesture(dragGesture(width: width))
            .overlay(alignment: .leading) {
                if canSwipeOpen && !isOpen {
                    Color.clear
                        .frame(width: Mortar.Spacing.l)
                        .contentShape(.rect)
                        .gesture(dragGesture(width: width))
                }
            }
        }
    }

    private func panel(showsCounts: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.title2.bold())
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
                .modifier(WindowControlsOffset())
                .padding(.horizontal, Mortar.Spacing.xxl)
                .padding(.vertical, Mortar.Spacing.m)

            ScrollView {
                VStack(spacing: Mortar.Spacing.xs) {
                    ForEach(feeds) { feed in
                        DrawerRow(
                            title: feed.summary.title,
                            subtitle: showsCounts ? subtitle(feed.id) : nil,
                            icon: feed.summary.icon,
                            isSelected: feed.id == selection
                        ) {
                            onSelect(feed.id)
                        }
                        .accessibilityIdentifier("feed.\(feed.id.rawValue)")
                    }
                }
                .padding(.horizontal, Mortar.Spacing.l)
            }

            Divider()
            DrawerRow(
                title: Localization.settings,
                update: updateNudge.availableUpdate?.label,
                icon: "gearshape",
                isSelected: false
            ) {
                isOpen = false
                openSettings()
            }
            .accessibilityIdentifier("drawerSettings")
            .padding(.horizontal, Mortar.Spacing.l)
            .padding(.vertical, Mortar.Spacing.s)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background {
            UnevenRoundedRectangle(bottomTrailingRadius: Mortar.Radii.xl, topTrailingRadius: Mortar.Radii.xl)
                .fill(PlatformColor.secondarySystemBackground)
                .ignoresSafeArea()
        }
    }

    private func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { drag = $0.translation.width }
            .onEnded { value in
                let end = (isOpen ? width : 0) + value.predictedEndTranslation.width
                // Explicit, so a drag that snaps back to where it started animates too.
                withAnimation(Mortar.Motion.springNormal) {
                    drag = 0
                    isOpen = end > width / 2
                }
            }
    }

    private enum Constants {
        static let widthFraction: CGFloat = 0.86
        static let maxWidth: CGFloat = 360
        static let scrimOpacity: Double = 0.35
    }
}

// MARK: - Row

private struct DrawerRow: View {
    let title: String
    var subtitle: String?
    /// Shows the update dot on the icon, and is read out in its place.
    var update: String?
    /// SF Symbol name, or an `mdi:` name.
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    @ScaledMetric(relativeTo: .title3) private var iconSize = Mortar.IconSize.xs

    var body: some View {
        Button(action: action) {
            HStack(spacing: Mortar.Spacing.m) {
                IconImage(icon, size: iconSize)
                    .font(.title3)
                    .overlay(alignment: .topTrailing) {
                        if update != nil { UpdateDot() }
                    }
                // A fixed column, so every title starts at the same x whatever the glyph's width.
                .frame(width: Mortar.IconSize.s, height: Mortar.TapTarget.minimum)
                .accessibilityHidden(true)

                VStack(alignment: .leading) {
                    Text(title)
                        .font(.body.weight(.semibold))
                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(.primary)
            .padding(Mortar.Spacing.s)
            .selectionFill(isSelected)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(subtitle ?? update ?? "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private extension FeedDrawer {
    enum Localization {
        static let settings = String(
            localized: "Settings",
            comment: "Row at the bottom of the side menu that opens Settings"
        )
    }
}
