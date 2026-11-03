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
    /// Only at the root: on a pushed screen the same swipe goes back.
    let canSwipeOpen: Bool
    let onSelect: (FeedID) -> Void
    let openSettings: () -> Void

    @State private var drag: CGFloat = 0
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

                panel
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

    private var panel: some View {
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
                            subtitle: subtitle(feed.id),
                            icon: feed.summary.icon,
                            isSelected: feed.id == selection
                        ) {
                            onSelect(feed.id)
                        }
                    }
                }
                .padding(.horizontal, Mortar.Spacing.l)
            }

            Divider()
            DrawerRow(title: Localization.settings, icon: "gearshape", isSelected: false) {
                isOpen = false
                openSettings()
            }
            .padding(.horizontal, Mortar.Spacing.l)
            .padding(.vertical, Mortar.Spacing.s)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
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
    /// SF Symbol name, or an `mdi:` name.
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    @ScaledMetric(relativeTo: .title3) private var iconSize = Mortar.IconSize.xs

    var body: some View {
        Button(action: action) {
            HStack(spacing: Mortar.Spacing.m) {
                Group {
                    if icon.hasPrefix("mdi:") {
                        MDIIcon(name: icon, size: iconSize)
                    } else {
                        Image(systemName: icon).font(.title3)
                    }
                }
                .frame(width: Mortar.TapTarget.minimum, height: Mortar.TapTarget.minimum)
                .background(Color(.tertiarySystemFill), in: .circle)
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
            .background(isSelected ? Color(.secondarySystemFill) : .clear, in: .rect(cornerRadius: Mortar.Radii.m))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(subtitle ?? "")
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
