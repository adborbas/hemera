import SwiftUI

public struct EntityControlPanel<Content: View, Footer: View>: View {
    @Binding var isPresented: Bool
    public let title: String
    public let subtitle: String?

    @ViewBuilder
    private let content: () -> Content

    @ViewBuilder
    private let footer: () -> Footer

    public init(
        isPresented: Binding<Bool>,
        title: String,
        subtitle: String?,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self._isPresented = isPresented
        self.title = title
        self.subtitle = subtitle
        self.content = content
        self.footer = footer
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, Mortar.PanelSpacing.content)
            Color.clear
                .frame(height: 56)
                .overlay { footer() }
                .padding(.bottom, Mortar.PanelSpacing.footer)
        }
        .overlay(alignment: .topTrailing) {
            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(Mortar.Spacing.xl)
        }
        .background(.ultraThickMaterial)
        .applySheetStyle()
    }

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .center, spacing: Mortar.Spacing.m) {
            Text(title)
                .font(.system(.largeTitle, design: .rounded))
                .lineLimit(1)

            Text(subtitle ?? " ")
                .font(.title3)
                .foregroundStyle(Color.secondary)
                .lineLimit(1)
                .opacity(subtitle != nil ? 1 : 0)
        }
        .padding(.top, Mortar.PanelSpacing.header)
    }
}

// MARK: - Convenience init (no footer)

extension EntityControlPanel where Footer == EmptyView {
    public init(
        isPresented: Binding<Bool>,
        title: String,
        subtitle: String?,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            isPresented: isPresented,
            title: title,
            subtitle: subtitle,
            content: content,
            footer: { EmptyView() }
        )
    }
}

private extension View {
    @ViewBuilder
    func applySheetStyle() -> some View {
        #if canImport(UIKit)
        if UIDevice.current.userInterfaceIdiom == .pad {
            self.presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        } else {
            self.presentationCompactAdaptation(.fullScreenCover)
        }
        #else
        self
        #endif
    }
}

#Preview("Cover") {
    @Previewable @State var value: Double = 0.5
    @Previewable @State var isAnimating = false
    EntityControlPanel(isPresented: .constant(true),
                      title: "Cover",
                      subtitle: "\(value * 100)% open") {
        VerticalSlider(value: $value,
                       style: .fill(.top),
                       onCommit: { _ in
            withAnimation {
                isAnimating = true
            }
        })
        .sliderFill(.blue)
    }
}
