import SwiftUI
import Mortar

/// Regular width's header: the home name, then the pills with the buttons at the row's end.
struct FeedHeader<Buttons: View>: View {
    let title: String
    let pills: [MainNavigationViewModel.Pill]
    let selection: FeedID
    let onSelect: (FeedID) -> Void
    @ViewBuilder let buttons: Buttons

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.largeTitle.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .accessibilityAddTraits(.isHeader)
                .modifier(WindowControlsOffset(sizeToFit: true))
                .padding(.horizontal, Mortar.Spacing.l)
                .padding(.top, HeaderLayout.titleSpacing)
            HStack(spacing: 0) {
                PillRow(pills: pills, selection: selection, onSelect: onSelect)
                buttons
            }
            .padding(.trailing, Mortar.Spacing.l)
        }
        .padding(.bottom, Mortar.Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mortarHeaderGlass()
    }
}

private struct PillRow: View {
    let pills: [MainNavigationViewModel.Pill]
    let selection: FeedID
    let onSelect: (FeedID) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fades = HeaderLayout.EdgeFades()

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
            .onScrollGeometryChange(for: HeaderLayout.EdgeFades.self) { geometry in
                HeaderLayout.edgeFades(
                    offset: geometry.contentOffset.x,
                    contentWidth: geometry.contentSize.width,
                    containerWidth: geometry.containerSize.width,
                    padding: Mortar.Spacing.l,
                    clipInset: Mortar.Spacing.s
                )
            } action: { _, fades in
                self.fades = fades
            }
            // Clipped a little inside the edges, fading only at an end with pills scrolled past it.
            .mask {
                HStack(spacing: 0) {
                    EdgeFade(edge: .leading, isActive: fades.leading)
                    Color.black
                    EdgeFade(edge: .trailing, isActive: fades.trailing)
                }
                .padding(.horizontal, Mortar.Spacing.s)
                .animation(.easeInOut(duration: Mortar.Motion.fast), value: fades)
            }
            .onChange(of: selection) {
                withAnimation(reduceMotion ? nil : Mortar.Motion.springNormal) {
                    proxy.scrollTo(selection, anchor: .center)
                }
            }
        }
    }
}

/// One end of the pill row's mask: a gradient while pills run past it, solid otherwise.
private struct EdgeFade: View {
    let edge: HorizontalEdge
    let isActive: Bool

    var body: some View {
        LinearGradient(
            colors: [.clear, .black],
            startPoint: edge == .leading ? .leading : .trailing,
            endPoint: edge == .leading ? .trailing : .leading
        )
        .overlay { Color.black.opacity(isActive ? 0 : 1) }
        .frame(width: Mortar.Spacing.l)
    }
}

private struct PillButton: View {
    let pill: MainNavigationViewModel.Pill
    let isSelected: Bool
    let action: () -> Void

    @ScaledMetric(relativeTo: .subheadline) private var iconSize = Mortar.IconSize.xs

    /// Drawn like a side menu row, so iPad's pills and iPhone's menu read as one control.
    var body: some View {
        Button(action: action) {
            HStack(spacing: Mortar.Spacing.s) {
                IconImage(pill.summary.icon, size: iconSize)
                    .accessibilityHidden(true)
                Text(pill.summary.title)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, Mortar.Spacing.m)
            .frame(minHeight: Mortar.TapTarget.minimum)
            .selectionFill(isSelected)
            .contentShape(.rect)
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
                    .labelStyle(.mortarIconButton)
            }
        } else {
            Button { perform(nil) } label: {
                Label(action.title, systemImage: action.icon)
                    .labelStyle(.mortarIconButton)
            }
        }
    }
}

/// The feed's action buttons in a row, for a header to put on glass.
struct FeedActionButtons: View {
    let actions: [FeedAction]
    let perform: (_ actionID: String, _ item: String?) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(actions) { action in
                FeedActionButton(action: action) { perform(action.id, $0) }
            }
        }
        .tint(.primary)
        .padding(.horizontal, Mortar.Spacing.xxs)
    }
}
