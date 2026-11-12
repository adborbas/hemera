import Mortar
import SwiftUI

/// On iPhone, holding the colour field or slider shrinks the panel around it so the app shows through.
struct ThemeEditorView: View {
    /// The iPhone drawer runs under the home indicator; the iPad card is rounded all round.
    let isDrawer: Bool
    let cancel: () -> Void
    let done: () -> Void

    @Environment(ThemeManager.self) private var themeManager

    @State private var family: ThemeFamily
    /// Where the field's handle sits; kept across pages so the greyscale page doesn't lose the hue.
    @State private var position: (hue: Double, radius: Double)
    @State private var active: Control?
    @State private var activation: Task<Void, Never>?
    @State private var frames: [Control: CGRect] = [:]

    /// Settings' list colour as its sheet shows it; the panel isn't a sheet, so it asks for elevated.
    private static let panelBackground = Color(UIColor { traits in
        UIColor.systemGroupedBackground.resolvedColor(with: traits.modifyingTraits { $0.userInterfaceLevel = .elevated })
    })

    private static let space = "themePanel"

    private enum Control { case dotField, slider }

    /// `theme` is what the editor opens on: its family's page, or the nearest one when it has none.
    init(theme: Theme, isDrawer: Bool, cancel: @escaping () -> Void, done: @escaping () -> Void) {
        self.isDrawer = isDrawer
        self.cancel = cancel
        self.done = done
        if case .gradient(let gradient) = theme {
            let family = gradient.family ?? .nearest(to: gradient.color)
            _family = State(initialValue: family)
            _position = State(initialValue: family.position(of: gradient.color))
        } else {
            _family = State(initialValue: .bright)
            _position = State(initialValue: (hue: 0.07, radius: 0.75))
        }
    }

    private var gradient: Theme.Gradient? {
        if case .gradient(let gradient) = themeManager.theme { gradient } else { nil }
    }

    var body: some View {
        VStack(spacing: Mortar.Spacing.m) {
            header
            controls
        }
        .padding(.top, Mortar.Spacing.l)
        .padding(.bottom, Mortar.Spacing.xl)
        .frame(maxWidth: .infinity)
        .coordinateSpace(.named(Self.space))
        .background { panel.ignoresSafeArea(edges: isDrawer ? .bottom : []) }
        .animation(.smooth(duration: 0.4), value: active)
        .sensoryFeedback(.impact(weight: .light), trigger: active) { _, new in new != nil }
        // A swipe to another page keeps the field position, so the theme follows it there.
        .onChange(of: family) { pick(position) }
    }

    /// One shape that contracts from the whole panel to a plate around the held control, and back.
    private var panel: some View {
        GeometryReader { proxy in
            let plate = active.flatMap { frames[$0] }.map { $0.insetBy(dx: -Self.inset($0), dy: -Self.inset($0)) }
            let rect = plate ?? CGRect(origin: .zero, size: proxy.size)
            let round = plate.map { min($0.width, $0.height) / 2 } ?? Mortar.Radii.xl
            UnevenRoundedRectangle(
                topLeadingRadius: round,
                bottomLeadingRadius: isDrawer && plate == nil ? 0 : round,
                bottomTrailingRadius: isDrawer && plate == nil ? 0 : round,
                topTrailingRadius: round,
                style: .continuous
            )
            .fill(Self.panelBackground)
            .shadow(color: .black.opacity(plate == nil ? 0 : 0.18), radius: 16, y: 4)
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
        }
    }

    /// The slider's plate hugs it more tightly than the round field's.
    private static func inset(_ frame: CGRect) -> CGFloat {
        frame.height < 100 ? Mortar.Spacing.s : Mortar.Spacing.m
    }

    private var controls: some View {
        VStack(spacing: Mortar.Spacing.l) {
            swatches
                .opacity(opacity(for: nil))
                .animation(contentFade, value: active)

            WavySlider(
                label: Localization.intensity,
                value: Binding(get: { themeManager.intensity }, set: { themeManager.setIntensity($0) })
            ) {
                setActive(.slider, $0)
            }
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { frames[.slider] = $0 }
            .padding(.horizontal, Mortar.Spacing.xl)
            .opacity(opacity(for: .slider))
            .animation(contentFade, value: active)

            ThemeDotField(
                family: family,
                hue: position.hue,
                radius: position.radius,
                showsHandle: gradient != nil,
                pick: { pick((hue: $0, radius: $1), select: true) },
                onActive: { setActive(.dotField, $0) }
            )
            .frame(width: 220, height: 220)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { frames[.dotField] = $0 }
            .opacity(opacity(for: .dotField))
            .animation(contentFade, value: active)
        }
    }

    /// The system's close and confirm buttons in our own row, so they fade like everything else.
    private var header: some View {
        HStack {
            if #available(iOS 26, *) {
                Button(role: .close, action: cancel) {
                    Label(Localization.cancel, systemImage: "xmark").labelStyle(.iconOnly)
                }
                .buttonStyle(.glass)
                Spacer()
                Button(role: .confirm, action: done) {
                    Label(Localization.done, systemImage: "checkmark").labelStyle(.iconOnly)
                }
                .buttonStyle(.glassProminent)
            } else {
                Button(Localization.cancel, action: cancel)
                Spacer()
                Button(Localization.done, action: done).fontWeight(.semibold)
            }
        }
        .buttonBorderShape(.circle)
        .controlSize(.large)
        .padding(.horizontal, Mortar.Spacing.l)
        .opacity(opacity(for: nil))
        .animation(contentFade, value: active)
    }

    private var swatches: some View {
        VStack(spacing: Mortar.Spacing.s) {
            HStack(spacing: Mortar.Spacing.s) {
                Button { themeManager.chooseNone() } label: { ThemeSwatch(color: nil, isSelected: gradient == nil) }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Localization.none)
                Divider().frame(height: 26)
                TabView(selection: $family) {
                    ForEach(ThemeFamily.allCases, id: \.self) { family in
                        presets(of: family).tag(family)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 34)
            }
            HStack(spacing: Mortar.Spacing.xs) {
                ForEach(ThemeFamily.allCases, id: \.self) { family in
                    Circle()
                        .fill(family == self.family ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                        .frame(width: 6, height: 6)
                }
            }
        }
        .padding(.horizontal, Mortar.Spacing.l)
    }

    private func presets(of family: ThemeFamily) -> some View {
        let selected = gradient.flatMap { family.presetIndex(matching: $0.color) }
        return HStack(spacing: 3) {
            ForEach(Array(family.presets.enumerated()), id: \.offset) { index, preset in
                Button {
                    pick(family.position(of: preset), select: true)
                } label: {
                    ThemeSwatch(color: preset.swiftUIColor, isSelected: index == selected)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Moves the field's handle; the theme follows when it is a Gradient or `select` makes it one.
    private func pick(_ position: (hue: Double, radius: Double), select: Bool = false) {
        self.position = position
        guard select || gradient != nil else { return }
        themeManager.setColor(family.color(hue: position.hue, radius: position.radius), family: family)
    }

    /// Content leaves before the panel shrinks past it and returns once the panel is back behind it.
    private var contentFade: Animation {
        active == nil ? .easeIn(duration: 0.2).delay(0.15) : .easeOut(duration: 0.15)
    }

    /// Focuses only on a held touch, so a quick tap doesn't flash the panel away and back.
    private func setActive(_ control: Control, _ isTouching: Bool) {
        activation?.cancel()
        // iPad has room to spare, so its card never hides.
        guard isTouching, isDrawer else { return active = nil }
        activation = Task {
            try? await Task.sleep(for: .milliseconds(200))
            if !Task.isCancelled { active = control }
        }
    }

    /// Fully visible unless another control is being touched; `nil` means "not a touchable control".
    private func opacity(for control: Control?) -> Double {
        active == nil || active == control ? 1 : 0
    }
}

private extension ThemeEditorView {
    enum Localization {
        static let cancel = String(localized: "Cancel", comment: "Discards theme changes and leaves the theme editor")
        static let done = String(localized: "Done", comment: "Keeps theme changes and leaves the theme editor")
        static let none = String(localized: "None", comment: "Swatch that turns the theme background off")
        static let intensity = String(localized: "Intensity", comment: "Slider for how strong the theme colours are")
    }
}
