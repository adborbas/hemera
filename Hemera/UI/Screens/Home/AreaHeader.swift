import SwiftUI
import Mortar

/// A pushed area's own collapsing header: the large title morphs into the centre of the button row.
struct AreaHeader: ViewModifier {
    /// Show/Hide mode brings up the system bar for its toolbar, so the header steps aside.
    let isEditing: Bool
    let title: String
    let area: AreaEntity?
    let actions: [FeedAction]
    let perform: (_ actionID: String, _ item: String?) -> Void

    @State private var scroll = FeedHeaderScroll()
    @State private var titleBlockHeight: CGFloat = 0

    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
        content
            .environment(\.feedHeaderScroll, isEditing ? nil : scroll)
            .contentMargins(.top, isEditing ? 0 : expandedHeight, for: .scrollContent)
            .toolbar(isEditing ? .visible : .hidden, for: .navigationBar)
            .background { SwipeBackRestorer() }
            .overlay(alignment: .top) {
                if !isEditing {
                    AreaHeaderBar(
                        scroll: scroll,
                        title: title,
                        area: area,
                        actions: actions,
                        perform: perform,
                        onTitleBlockHeightChange: { titleBlockHeight = $0 }
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? nil : Mortar.Motion.springNormal, value: isEditing)
            .onChange(of: titleBlockHeight, initial: true) { scroll.hideRange = $1 }
            .onChange(of: canCollapse, initial: true) { scroll.canHide = $1 }
    }

    /// The button row, the title block and the header's bottom paddings.
    private var expandedHeight: CGFloat {
        Mortar.TapTarget.minimum + titleBlockHeight + Mortar.Spacing.xs + Mortar.Spacing.s
    }

    /// Same rules as the main header.
    private var canCollapse: Bool {
        horizontalSizeClass == .compact && !voiceOverEnabled && !reduceMotion && !isEditing
    }
}

// MARK: - Bar

private struct AreaHeaderBar: View {
    let scroll: FeedHeaderScroll
    let title: String
    let area: AreaEntity?
    let actions: [FeedAction]
    let perform: (_ actionID: String, _ item: String?) -> Void
    let onTitleBlockHeightChange: (CGFloat) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var trailingWidth: CGFloat = 0

    var body: some View {
        let row = Mortar.TapTarget.minimum
        ZStack(alignment: .topLeading) {
            MorphingTitle(
                scroll: scroll,
                title: title,
                area: area,
                leadingReserve: Mortar.Spacing.l + row + Mortar.Spacing.s,
                trailingReserve: Mortar.Spacing.l + (trailingWidth > 0 ? trailingWidth + Mortar.Spacing.s : 0),
                onHeightChange: onTitleBlockHeightChange
            )
            .padding(.bottom, Mortar.Spacing.xs)
            HStack {
                Button { dismiss() } label: {
                    Label(Localization.back, systemImage: "chevron.left")
                        .labelStyle(.iconOnly)
                        .frame(width: row, height: row)
                        .contentShape(.circle)
                }
                .tint(.primary)
                .modifier(GlassCapsule())
                Spacer()
                HStack(spacing: 0) {
                    if !actions.isEmpty {
                        HStack(spacing: 0) {
                            ForEach(actions) { action in
                                FeedActionButton(action: action) { perform(action.id, $0) }
                            }
                        }
                        .tint(.primary)
                        .padding(.horizontal, Mortar.Spacing.xxs)
                        .modifier(GlassCapsule())
                    }
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { trailingWidth = $0 }
            }
            .padding(.horizontal, Mortar.Spacing.l)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .modifier(HeaderBackground())
    }
}

// MARK: - Swipe Back

/// Hiding the system bar also turns off the edge swipe back; this turns it on while the area is shown.
private struct SwipeBackRestorer: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) {}

    final class Controller: UIViewController, UIGestureRecognizerDelegate {
        private weak var systemDelegate: (any UIGestureRecognizerDelegate)?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard let gesture = navigationController?.interactivePopGestureRecognizer,
                  gesture.delegate !== self else { return }
            systemDelegate = gesture.delegate
            gesture.delegate = self
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            guard let gesture = navigationController?.interactivePopGestureRecognizer,
                  gesture.delegate === self else { return }
            gesture.delegate = systemDelegate
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            (navigationController?.viewControllers.count ?? 0) > 1
        }
    }
}

// MARK: - Morphing Title

/// The per-frame reader: the title and readings shrink and slide into the centre of the button row.
private struct MorphingTitle: View {
    let scroll: FeedHeaderScroll
    let title: String
    let area: AreaEntity?
    /// Room the back button and the trailing capsule take in the button row.
    let leadingReserve: CGFloat
    let trailingReserve: CGFloat
    let onHeightChange: (CGFloat) -> Void

    @State private var titleHeight: CGFloat = 0
    @State private var naturalTitleWidth: CGFloat = 0
    @State private var expandedReadingsSize: CGSize = .zero
    @State private var collapsedReadingsSize: CGSize = .zero
    @State private var width: CGFloat = 0

    private let readingsCollapsedScale: CGFloat = 0.85
    private let row = Mortar.TapTarget.minimum

    var body: some View {
        let progress = scroll.progress
        let collapsedScale = UIFont.preferredFont(forTextStyle: .headline).pointSize
            / UIFont.preferredFont(forTextStyle: .largeTitle).pointSize
        let scale = 1 - (1 - collapsedScale) * progress
        let collapsedBlock = titleHeight * collapsedScale + collapsedReadingsSize.height * readingsCollapsedScale
        let collapsedTitle = HeaderLayout.collapsedTitle(
            width: naturalTitleWidth * collapsedScale,
            rowWidth: width,
            leadingReserve: leadingReserve,
            trailingReserve: trailingReserve
        )
        let gap = max(0, width - leadingReserve - trailingReserve)
        let expandedLimit = width - Mortar.Spacing.l * 2
        let titleLimit = expandedLimit + (gap - expandedLimit) * progress
        let titleExpanded = CGPoint(x: Mortar.Spacing.l, y: row)
        let titleCollapsed = CGPoint(x: collapsedTitle.x, y: (row - collapsedBlock) / 2)
        let readingsExpanded = CGPoint(x: Mortar.Spacing.l, y: row + titleHeight)
        let readingsCollapsed = CGPoint(
            x: (width - collapsedReadingsSize.width * readingsCollapsedScale) / 2,
            y: titleCollapsed.y + titleHeight * collapsedScale
        )

        ZStack(alignment: .topLeading) {
            Text(title)
                .font(.largeTitle.bold())
                .lineLimit(1)
                // Divided by the scale so the truncation width holds after scaling.
                .frame(maxWidth: width > 0 ? max(0, titleLimit / scale) : nil, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .background {
                    Text(title).font(.largeTitle.bold()).lineLimit(1).fixedSize().hidden()
                        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { naturalTitleWidth = $0 }
                }
                .accessibilityAddTraits(.isHeader)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { titleHeight = $0 }
                .scaleEffect(scale, anchor: .topLeading)
                .offset(lerp(titleExpanded, titleCollapsed, progress))
            if let area {
                // Static copies measure both ends, so the visible one resizes without moving the layout.
                ZStack { AreaClimateReadings(area: area, morph: 0) }.fixedSize().hidden()
                    .onGeometryChange(for: CGSize.self) { $0.size } action: { expandedReadingsSize = $0 }
                ZStack { AreaClimateReadings(area: area, morph: 1) }.fixedSize().hidden()
                    .onGeometryChange(for: CGSize.self) { $0.size } action: { collapsedReadingsSize = $0 }
                // Tappable only while they still read as pills.
                AreaClimateReadings(area: area, morph: progress, isInteractive: progress < 0.5)
                    .fixedSize()
                    .scaleEffect(1 - (1 - readingsCollapsedScale) * progress, anchor: .topLeading)
                    .offset(lerp(readingsExpanded, readingsCollapsed, progress))
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: row + (titleHeight + expandedReadingsSize.height) * (1 - progress), alignment: .topLeading)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .onChange(of: titleHeight + expandedReadingsSize.height, initial: true) { onHeightChange($1) }
    }

    private func lerp(_ from: CGPoint, _ to: CGPoint, _ progress: CGFloat) -> CGSize {
        CGSize(width: from.x + (to.x - from.x) * progress, height: from.y + (to.y - from.y) * progress)
    }
}

// MARK: - Localization

private extension AreaHeaderBar {
    enum Localization {
        static let back = String(localized: "Back", comment: "Accessibility label for the button that returns from an area to the Areas list")
    }
}
