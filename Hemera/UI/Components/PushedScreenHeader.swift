import SwiftUI
import Mortar

extension View {
    /**
     Replaces the system bar with a back button or avatar, the screen's actions and a large title. In
     compact width the title morphs into the button row on scroll, and the accessory into a subtitle.
    */
    func pushedScreenHeader<Accessory: View>(
        _ title: String,
        leading: HeaderLeading = .back,
        isEditing: Bool = false,
        staysCollapsed: Bool = false,
        actions: [FeedAction] = [],
        trailing: AnyView? = nil,
        perform: @escaping (_ actionID: String, _ item: String?) -> Void = { _, _ in },
        @ViewBuilder accessory: @escaping (_ collapse: CGFloat) -> Accessory = { _ in EmptyView() }
    ) -> some View {
        modifier(PushedScreenHeader(
            title: title,
            leading: leading,
            isEditing: isEditing,
            staysCollapsed: staysCollapsed,
            actions: actions,
            trailing: trailing,
            perform: perform,
            accessory: accessory
        ))
    }
}

/// What sits at the header's leading end.
enum HeaderLeading {
    case back
    /// The root of a sheet's stack, where the same dismissal closes the sheet.
    case close(label: String)
    /// A feed's root has nothing to go back to; the bare avatar takes the back button's place.
    case account(Account?, action: () -> Void)
}

private struct PushedScreenHeader<Accessory: View>: ViewModifier {
    let title: String
    let leading: HeaderLeading
    /// An editing toolbar brings up the system bar, so the header steps aside.
    let isEditing: Bool
    /// The title sits in the button row from the start, at any width.
    let staysCollapsed: Bool
    let actions: [FeedAction]
    /// Sits after the actions, for what a `FeedAction` can't express: a text button, a busy state.
    let trailing: AnyView?
    let perform: (_ actionID: String, _ item: String?) -> Void
    let accessory: (_ collapse: CGFloat) -> Accessory

    @State private var scroll = FeedHeaderScroll()
    @State private var collapseRange: CGFloat = 0
    @State private var regularHeight: CGFloat = 0
    @State private var sheetTopPadding: CGFloat = 0

    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
        let isCompact = horizontalSizeClass == .compact || staysCollapsed
        content
            .environment(\.feedHeaderScroll, isEditing ? nil : scroll)
            .contentMargins(
                .top,
                isEditing || staysCollapsed ? 0 : (isCompact ? compactHeight : regularHeight),
                for: .scrollContent
            )
            // Its height never changes, and it must also clear content that doesn't scroll.
            .safeAreaPadding(.top, staysCollapsed ? compactHeight : 0)
            .toolbar(isEditing ? .visible : .hidden, for: .navigationBar)
            .background { SwipeBackRestorer() }
            .overlay(alignment: .top) {
                if !isEditing {
                    Group {
                        if isCompact {
                            CollapsingBar(
                                scroll: scroll,
                                title: title,
                                leading: leading,
                                staysCollapsed: staysCollapsed,
                                topPadding: sheetTopPadding,
                                actions: actions,
                                trailing: trailing,
                                perform: perform,
                                accessory: accessory,
                                onCollapseRangeChange: { collapseRange = staysCollapsed ? 0 : $0 }
                            )
                        } else {
                            RegularBar(
                                scroll: scroll,
                                title: title,
                                leading: leading,
                                actions: actions,
                                trailing: trailing,
                                perform: perform,
                                accessory: accessory
                            )
                                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { regularHeight = $0 }
                        }
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            // A sheet has no top safe area, which would leave the buttons on its rounded edge.
            .onGeometryChange(for: CGFloat.self) { staysCollapsed && $0.safeAreaInsets.top == 0 ? Mortar.Spacing.m : 0 } action: {
                sheetTopPadding = $0
            }
            .animation(reduceMotion ? nil : Mortar.Motion.springNormal, value: isEditing)
            .onChange(of: collapseRange, initial: true) { scroll.hideRange = $1 }
            .onChange(of: canCollapse, initial: true) { scroll.canHide = $1 }
    }

    /// The button row, the collapsing title block and the header's bottom paddings.
    private var compactHeight: CGFloat {
        sheetTopPadding + Mortar.TapTarget.minimum + collapseRange + Mortar.Spacing.xs + Mortar.Spacing.s
    }

    /// Same rules as the main header.
    private var canCollapse: Bool {
        horizontalSizeClass == .compact && !voiceOverEnabled && !reduceMotion && !isEditing && !staysCollapsed
    }
}

// MARK: - Bars

/// A title with nothing under it needs no plate until content scrolls beneath it.
private func isPlateVisible(accessoryHeight: CGFloat, scroll: FeedHeaderScroll) -> Bool {
    accessoryHeight > 0 || scroll.isScrolled
}

/// Wide layouts don't collapse, so everything shares one row: back, title, accessory, actions.
private struct RegularBar<Accessory: View>: View {
    let scroll: FeedHeaderScroll
    let title: String
    let leading: HeaderLeading
    let actions: [FeedAction]
    let trailing: AnyView?
    let perform: (_ actionID: String, _ item: String?) -> Void
    let accessory: (_ collapse: CGFloat) -> Accessory

    @State private var accessoryHeight: CGFloat = 0

    var body: some View {
        HStack(alignment: .top, spacing: Mortar.Spacing.m) {
            LeadingButton(leading: leading)
            // The accessory takes the title's row while both fit, else the row below the title.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Mortar.Spacing.m) {
                    titleText
                    Spacer(minLength: 0)
                    measuredAccessory
                }
                VStack(alignment: .leading, spacing: 0) {
                    titleText
                    measuredAccessory
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            ActionsCapsule(actions: actions, perform: perform)
            trailing
        }
        .modifier(WindowControlsOffset(sizeToFit: true))
        .padding(.horizontal, Mortar.Spacing.l)
        .padding(.bottom, Mortar.Spacing.xs)
        .modifier(HeaderBackground(isPlateVisible: isPlateVisible(accessoryHeight: accessoryHeight, scroll: scroll)))
    }

    private var titleText: some View {
        Text(title)
            .font(.largeTitle.bold())
            .lineLimit(1)
            .frame(minHeight: Mortar.TapTarget.minimum)
            .accessibilityAddTraits(.isHeader)
    }

    private var measuredAccessory: some View {
        accessory(0)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { accessoryHeight = $0 }
    }
}

private struct CollapsingBar<Accessory: View>: View {
    let scroll: FeedHeaderScroll
    let title: String
    let leading: HeaderLeading
    let staysCollapsed: Bool
    let topPadding: CGFloat
    let actions: [FeedAction]
    let trailing: AnyView?
    let perform: (_ actionID: String, _ item: String?) -> Void
    let accessory: (_ collapse: CGFloat) -> Accessory
    let onCollapseRangeChange: (CGFloat) -> Void

    @State private var leadingEnd = Mortar.Spacing.l + Mortar.TapTarget.minimum
    @State private var trailingWidth: CGFloat = 0
    @State private var expandedAccessorySize: CGSize = .zero
    @State private var collapsedAccessorySize: CGSize = .zero

    var body: some View {
        let row = Mortar.TapTarget.minimum
        ZStack(alignment: .topLeading) {
            MorphingTitle(
                scroll: scroll,
                title: title,
                staysCollapsed: staysCollapsed,
                accessory: accessory,
                expandedAccessorySize: expandedAccessorySize,
                collapsedAccessorySize: collapsedAccessorySize,
                leadingReserve: leadingEnd + Mortar.Spacing.s,
                trailingReserve: Mortar.Spacing.l + (trailingWidth > 0 ? trailingWidth + Mortar.Spacing.s : 0),
                onCollapseRangeChange: onCollapseRangeChange
            )
            .padding(.bottom, Mortar.Spacing.xs)
            HStack {
                LeadingButton(leading: leading)
                    // Read inside the offset, which it still sees, so the title clears the moved button.
                    .onGeometryChange(for: CGFloat.self) {
                        $0.frame(in: .named(Self.barSpace)).maxX
                    } action: { leadingEnd = $0 }
                    .modifier(WindowControlsOffset())
                Spacer()
                HStack(spacing: Mortar.Spacing.s) {
                    ActionsCapsule(actions: actions, perform: perform)
                    trailing
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { trailingWidth = $0 }
            }
            .padding(.horizontal, Mortar.Spacing.l)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(.top, topPadding)
        .coordinateSpace(.named(Self.barSpace))
        // Static copies measure both ends, so the visible accessory resizes without moving the layout.
        .background {
            ZStack { accessory(0) }.fixedSize().hidden()
                .onGeometryChange(for: CGSize.self) { $0.size } action: { expandedAccessorySize = $0 }
            ZStack { accessory(1) }.fixedSize().hidden()
                .onGeometryChange(for: CGSize.self) { $0.size } action: { collapsedAccessorySize = $0 }
        }
        .modifier(HeaderBackground(
            isPlateVisible: isPlateVisible(accessoryHeight: expandedAccessorySize.height, scroll: scroll)
        ))
    }

    private static var barSpace: String { "CollapsingBar" }
}

private struct LeadingButton: View {
    let leading: HeaderLeading

    var body: some View {
        switch leading {
        case .back: DismissButton(label: Localization.back, icon: "chevron.left")
        case .close(let label): DismissButton(label: label, icon: "xmark")
        case .account(let account, let action):
            AccountButton(account: account, action: action, opensMenu: true)
        }
    }
}

private struct DismissButton: View {
    let label: String
    let icon: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button { dismiss() } label: {
            Label(label, systemImage: icon)
                .labelStyle(.iconOnly)
                .frame(width: Mortar.TapTarget.minimum, height: Mortar.TapTarget.minimum)
                .contentShape(.circle)
        }
        .tint(.primary)
        .modifier(GlassCapsule())
    }
}

/// The screen's actions in one glass capsule; nothing at all without actions.
private struct ActionsCapsule: View {
    let actions: [FeedAction]
    let perform: (_ actionID: String, _ item: String?) -> Void

    var body: some View {
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
    }
}

// MARK: - Swipe Back

/// Hiding the system bar also turns off the edge swipe back; this turns it on while the screen is shown.
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

/// The per-frame reader: the title and accessory shrink and slide into the centre of the button row.
private struct MorphingTitle<Accessory: View>: View {
    let scroll: FeedHeaderScroll
    let title: String
    let staysCollapsed: Bool
    let accessory: (_ collapse: CGFloat) -> Accessory
    let expandedAccessorySize: CGSize
    let collapsedAccessorySize: CGSize
    /// Room the back button and the trailing capsule take in the button row.
    let leadingReserve: CGFloat
    let trailingReserve: CGFloat
    let onCollapseRangeChange: (CGFloat) -> Void

    @State private var titleHeight: CGFloat = 0
    @State private var naturalTitleWidth: CGFloat = 0
    @State private var width: CGFloat = 0

    private let accessoryCollapsedScale: CGFloat = 0.85
    private let row = Mortar.TapTarget.minimum

    var body: some View {
        let progress = staysCollapsed ? 1 : scroll.progress
        let collapsedScale = UIFont.preferredFont(forTextStyle: .headline).pointSize
            / UIFont.preferredFont(forTextStyle: .largeTitle).pointSize
        let scale = 1 - (1 - collapsedScale) * progress
        let block = HeaderLayout.titleSpacing + titleHeight + expandedAccessorySize.height
        let collapsedBlock = titleHeight * collapsedScale + collapsedAccessorySize.height * accessoryCollapsedScale
        let collapsedTitle = HeaderLayout.collapsedTitle(
            width: naturalTitleWidth * collapsedScale,
            rowWidth: width,
            leadingReserve: leadingReserve,
            trailingReserve: trailingReserve
        )
        let gap = max(0, width - leadingReserve - trailingReserve)
        let expandedLimit = width - Mortar.Spacing.l * 2
        let titleLimit = expandedLimit + (gap - expandedLimit) * progress
        let titleExpanded = CGPoint(x: Mortar.Spacing.l, y: row + HeaderLayout.titleSpacing)
        let titleCollapsed = CGPoint(x: collapsedTitle.x, y: (row - collapsedBlock) / 2)
        let accessoryExpanded = CGPoint(x: Mortar.Spacing.l, y: titleExpanded.y + titleHeight)
        let accessoryCollapsed = CGPoint(
            x: (width - collapsedAccessorySize.width * accessoryCollapsedScale) / 2,
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
            accessory(progress)
                .fixedSize()
                .scaleEffect(1 - (1 - accessoryCollapsedScale) * progress, anchor: .topLeading)
                .offset(lerp(accessoryExpanded, accessoryCollapsed, progress))
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: row + block * (1 - progress), alignment: .topLeading)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .onChange(of: block, initial: true) { onCollapseRangeChange($1) }
    }

    private func lerp(_ from: CGPoint, _ to: CGPoint, _ progress: CGFloat) -> CGSize {
        CGSize(width: from.x + (to.x - from.x) * progress, height: from.y + (to.y - from.y) * progress)
    }
}

// MARK: - Localization

private extension LeadingButton {
    enum Localization {
        static let back = String(localized: "Back", comment: "Accessibility label for the button that returns to the previous screen")
    }
}
