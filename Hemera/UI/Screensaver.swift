import SwiftUI
import Mortar

struct Screensaver: View {

    let clockFormat: ClockFormat
    /// The dimmed theme to paint behind the clock; `nil` is plain black.
    let paint: ThemePaint?
    @State private var showHint = true
    @State private var shownAt = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.everyMinute) { context in
            ZStack {
                Color.black
                    .ignoresSafeArea()
                if let paint {
                    MeshGradient(
                        width: 3,
                        height: 3,
                        points: ThemeMaths.meshPoints,
                        colors: ThemeMaths.meshColors(paint.color.swiftUIColor)
                    )
                    .opacity(paint.alpha)
                    .ignoresSafeArea()
                }

                VStack(spacing: Mortar.Spacing.s) {
                    Text(context.date, format: timeFormat)
                        .font(.system(size: 80, weight: .regular, design: .rounded))

                    Text(context.date, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                        .font(.system(size: 22, weight: .regular, design: .rounded))
                }
                .foregroundStyle(.white.opacity(paint == nil ? 0.6 : ThemeMaths.screensaverClockOpacity))
                .offset(clockOffset(at: context.date))
                .animation(reduceMotion ? nil : .easeInOut(duration: 3), value: clockOffset(at: context.date))

                VStack {
                    Spacer()
                    if showHint {
                        Text(Localization.tapToWake)
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundStyle(.white.opacity(paint == nil ? 0.4 : 0.6))
                            .transition(.opacity)
                            .padding(.bottom, 40)
                    }
                }
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation(.easeOut(duration: 1)) {
                showHint = false
            }
        }
    }

    /// Starts centred, then moves the clock every minute so a static screen doesn't burn in.
    static func clockOffset(minutesShown minute: Int) -> CGSize {
        let minute = Double(minute)
        return CGSize(width: (sin(minute * 0.9) * 12).rounded(), height: (sin(minute * 0.53) * 12).rounded())
    }

    private func clockOffset(at date: Date) -> CGSize {
        Self.clockOffset(minutesShown: Int(date.timeIntervalSince(shownAt) / 60))
    }

    private var timeFormat: Date.FormatStyle {
        switch clockFormat {
        case .system:
            .dateTime.hour().minute()
        case .twelveHour:
            .dateTime.hour().minute().locale(locale(hourCycle: .oneToTwelve))
        case .twentyFourHour:
            .dateTime.hour().minute().locale(locale(hourCycle: .zeroToTwentyThree))
        }
    }

    private func locale(hourCycle: Locale.HourCycle) -> Locale {
        var components = Locale.Components(locale: .current)
        components.hourCycle = hourCycle
        return Locale(components: components)
    }
}

private extension Screensaver {
    enum Localization {
        static let tapToWake = String(localized: "Tap to wake", comment: "Hint shown briefly on the screensaver to indicate the user can tap to wake the display")
    }
}

#if DEBUG
#Preview {
    Screensaver(clockFormat: .system, paint: nil)
}
#endif
