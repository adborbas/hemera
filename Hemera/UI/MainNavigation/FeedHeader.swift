import SwiftUI
import Mortar

/// The title and pill row floating over the feeds.
struct FeedHeader: View {
    let title: String
    let pills: [MainNavigationViewModel.Pill]
    let selection: FeedID
    let onSelect: (FeedID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top row, shared with the account button floating above it.
            Color.clear
                .frame(height: Mortar.TapTarget.minimum)
            Text(title)
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, Mortar.Spacing.l)
            PillRow(pills: pills, selection: selection, onSelect: onSelect)
        }
        .padding(.bottom, Mortar.Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground), ignoresSafeAreaEdges: .top)
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

    var body: some View {
        Button(action: action) {
            Label(pill.summary.title, systemImage: pill.summary.icon)
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
