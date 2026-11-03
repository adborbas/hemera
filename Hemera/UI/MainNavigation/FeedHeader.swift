import SwiftUI
import Mortar

/// The title and pill row floating over the feeds; collapsing moves the pills up into the button row.
struct FeedHeader: View {
    let title: String
    let pills: [MainNavigationViewModel.Pill]
    let selection: FeedID
    let onSelect: (FeedID) -> Void
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
                selection: selection,
                onSelect: onSelect
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
    let selection: FeedID
    let onSelect: (FeedID) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: Mortar.Spacing.s) {
                    ForEach(pills) { pill in
                        PillButton(pill: pill, isSelected: pill.id == selection) {
                            onSelect(pill.id)
                        }
                        .id(pill.id)
                    }
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
