import SwiftUI

struct DimOverlay: View {

    let clockFormat: ClockFormat
    @State private var showHint = true

    var body: some View {
        TimelineView(.everyMinute) { context in
            ZStack {
                Color.black
                    .ignoresSafeArea()

                VStack(spacing: 8) {
                    Text(context.date, format: timeFormat)
                        .font(.system(size: 80, weight: .regular, design: .rounded))

                    Text(context.date, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                        .font(.system(size: 22, weight: .regular, design: .rounded))
                }
                .foregroundStyle(.white.opacity(0.6))

                VStack {
                    Spacer()
                    if showHint {
                        Text(Localization.tapToWake)
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
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

private extension DimOverlay {
    enum Localization {
        static let tapToWake = String(localized: "Tap to wake", comment: "Hint shown briefly on the dimmed screen to indicate the user can tap to wake the display")
    }
}

#if DEBUG
#Preview {
    DimOverlay(clockFormat: .system)
}
#endif
