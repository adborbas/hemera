import Accessibility
import Charts
import Mortar
import SwiftUI

/// One climate measurement's history for an area's representative sensor, led by the value.
struct AreaClimateHistoryView: View {

    @Bindable var viewModel: AreaClimateHistoryViewModel
    let areaName: String

    @Environment(\.dismiss) private var dismiss

    init(viewModel: AreaClimateHistoryViewModel, areaName: String) {
        self.viewModel = viewModel
        self.areaName = areaName
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Mortar.Spacing.l) {
                header

                content

                HStack {
                    Spacer()
                    rangeChips
                }
            }
            .padding(Mortar.Spacing.l)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Label(Localization.close, systemImage: "xmark")
                            .labelStyle(.iconOnly)
                    }
                }
            }
            .task(id: viewModel.selectedRange) { await viewModel.load() }
        }
    }

    // MARK: - Header

    /// The caption and the reading, which is this screen's headline rather than a footnote.
    private var header: some View {
        VStack(alignment: .leading, spacing: Mortar.Spacing.xs) {
            Text(caption)
                .font(.caption2.weight(.semibold))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)

            readoutValue

            Text(readoutDetail)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .accessibilityElement(children: .combine)
        .animation(.smooth(duration: 0.20), value: viewModel.readout?.mean)
    }

    @ViewBuilder
    private var readoutValue: some View {
        if let mean = viewModel.readout?.mean {
            HStack(alignment: .firstTextBaseline, spacing: Mortar.Spacing.xxs) {
                Text(mean.formatted(.number.precision(.fractionLength(1))))
                    .font(.system(size: Self.valueFontSize, weight: .semibold, design: .rounded))
                    .contentTransition(.numericText())
                Text(viewModel.readout?.unit ?? "")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        } else {
            Text(Localization.noReading)
                .font(.system(size: Self.valueFontSize, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    private var caption: String {
        guard case let .loaded(series) = viewModel.series else { return areaName }
        return "\(areaName) · \(series.sensorName)"
    }

    /// The scrubbed sample's span, or a single space so the header never changes height.
    private var readoutDetail: String {
        guard let interval = viewModel.readout?.interval else { return " " }
        return formatInterval(interval)
    }

    // MARK: - Content

    /**
     While a range loads, the last chart stays dimmed under a spinner. Dimming is a modifier
     rather than a branch: two branches are two identities, and the morph dies with the old one.
    */
    private var content: some View {
        chart
            .opacity(isStale ? Self.staleOpacity : 1)
            .overlay { if isStale { ProgressView().controlSize(.small) } }
    }

    /// A chart already on screen while a newer range is still in flight.
    private var isStale: Bool {
        guard case .loaded = viewModel.series else { return false }
        return viewModel.isLoading
    }

    @ViewBuilder
    private var chart: some View {
        switch viewModel.series {
        case .loading:
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .noRecordedHistory:
            Text(Localization.noRecordedHistory)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .failed:
            VStack(spacing: Mortar.Spacing.s) {
                Text(Localization.loadFailed)
                    .foregroundStyle(.secondary)
                Button(action: { Task { await viewModel.retry() } }) {
                    Text(Localization.retry)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel(Localization.retryAction)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case let .loaded(series):
            ClimateChartView(
                runs: viewModel.curveRuns,
                valueDomain: viewModel.valueDomain,
                color: .cool,
                selectedPosition: $viewModel.selectedPosition,
                selectedPoint: viewModel.selectedPoint,
                axisLabel: axisLabel
            )
            .accessibilityChartDescriptor(
                ClimateChartDescriptor(
                    title: String(format: Localization.chartTitle, series.sensorName, series.unit),
                    summary: String(format: Localization.chartRange, rangeLabel(viewModel.selectedRange)),
                    unit: series.unit,
                    range: viewModel.selectedRange,
                    window: window(for: series),
                    samples: series.samples,
                    xAxisTitle: Localization.timeAxis
                )
            )
        }
    }

    // MARK: - Range

    private var rangeChips: some View {
        HStack(spacing: Mortar.Spacing.xs) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                let isSelected = viewModel.selectedRange == range
                Text(chipLabel(range))
                    .font(.footnote.weight(isSelected ? .semibold : .regular))
                    .padding(.horizontal, Mortar.Spacing.m)
                    .padding(.vertical, Mortar.Spacing.xs)
                    .background(isSelected ? AnyShapeStyle(.thickMaterial) : AnyShapeStyle(.clear), in: Capsule())
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    .contentShape(Capsule())
                    .onTapGesture { viewModel.selectedRange = range }
                    .accessibilityLabel(rangeLabel(range))
                    .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
            }
        }
        .animation(.smooth(duration: 0.20), value: viewModel.selectedRange)
    }

    // MARK: - Formatting

    /// A scrub position's time, in the selected range's style.
    private func axisLabel(_ position: Double) -> String {
        guard let date = viewModel.date(atPosition: position) else { return "" }
        return Self.axisTime(viewModel.selectedRange, date)
    }

    /// Beyond a day an axis label is a date alone; three full timestamps collide at phone width.
    private static func axisTime(_ range: TimeRange, _ date: Date) -> String {
        switch range {
        case .day:
            return date.formatted(date: .omitted, time: .shortened)
        case .week, .month:
            return date.formatted(.dateTime.day().month(.abbreviated))
        }
    }

    /// Formats a bucket's span; the 24-hour range omits the date, the others include it.
    private func formatInterval(_ interval: Range<Date>) -> String {
        switch viewModel.selectedRange {
        case .day:
            return interval.formatted(date: .omitted, time: .shortened)
        case .week, .month:
            return interval.formatted(date: .abbreviated, time: .shortened)
        }
    }

    private func window(for series: AreaClimateHistoryViewModel.ClimateSeries) -> ClosedRange<Date> {
        guard let first = series.samples.first?.start, let last = series.samples.last?.end, first < last else {
            let now = Date()
            return now.addingTimeInterval(-viewModel.selectedRange.interval)...now
        }
        return first...last
    }
}

// MARK: - Localization

private extension AreaClimateHistoryView {
    enum Localization {
        static let close = String(localized: "Close", comment: "Toolbar button that dismisses the area's climate-history sheet")
        static let noRecordedHistory = String(localized: "Home Assistant isn't recording history for this sensor", comment: "Shown in place of a climate chart when Home Assistant keeps no long-term statistics for the sensor, which is normal")
        static let loadFailed = String(localized: "Couldn't load history", comment: "Shown in place of a climate chart when the history fetch failed, next to a retry button")
        static let retry = String(localized: "Retry", comment: "The button that re-fetches a climate range whose history failed to load")
        static let timeAxis = String(localized: "Time", comment: "Horizontal axis key for a climate-history chart, over the selected range")
        static let twentyFourHours = String(localized: "24 Hours", comment: "Range option showing the last 24 hours of climate history")
        static let sevenDays = String(localized: "7 Days", comment: "Range option showing the last 7 days of climate history")
        static let thirtyDays = String(localized: "30 Days", comment: "Range option showing the last 30 days of climate history")
        static let chipDay = String(localized: "24H", comment: "Compact label for the 24-hour climate-history range")
        static let chipWeek = String(localized: "7D", comment: "Compact label for the 7-day climate-history range")
        static let chipMonth = String(localized: "30D", comment: "Compact label for the 30-day climate-history range")
        static let noReading = String(localized: "No reading", comment: "Shown in place of the value when the scrubbed position has no sample, eg. inside a recording gap")
        /// VoiceOver heading for the chart; names the sensor and the measurement it shows.
        static let chartTitle = String(localized: "Climate history of %1$@ (%2$@)", comment: "Audio-graph heading naming the sensor and its measurement, eg. Temperature (°C)")
        /// The window a chart covers, spoken alongside its audio graph.
        static let chartRange = String(localized: "Over the last %1$@", comment: "The selected range the chart's audio graph covers, eg. Over the last 24 hours")
        /// Accessibility label for the retry button after a climate-history fetch fails.
        static let retryAction = String(localized: "Retry loading climate history", comment: "Accessibility label on a retry button after a climate-history fetch fails")
    }

    /// The spoken name of a range; the enum carries no display text.
    func rangeLabel(_ range: TimeRange) -> String {
        switch range {
        case .day: return Localization.twentyFourHours
        case .week: return Localization.sevenDays
        case .month: return Localization.thirtyDays
        }
    }

    /// The compact chip label, which trades spelling out the range for giving the chart the room.
    func chipLabel(_ range: TimeRange) -> String {
        switch range {
        case .day: return Localization.chipDay
        case .week: return Localization.chipWeek
        case .month: return Localization.chipMonth
        }
    }

    /// How dim a still-loaded chart reads while a newer range loads over it.
    static let staleOpacity: Double = 0.5

    /// The headline reading's point size.
    static let valueFontSize: CGFloat = 44
}

#if DEBUG
import SwiftData

/// Preview-only provider: a short synthetic 24-hour series for any sensor.
fileprivate final class StubHistoryProvider: SensorHistoryProviding {
    func history(forEntityId entityId: String, range: TimeRange) async throws -> [ClimateSample] {
        let now = Date()
        let start = now.addingTimeInterval(-24 * 60 * 60)
        let step = now.timeIntervalSince(start) / 4
        return [19.5, 20.2, 21.0, 20.6, 19.8].enumerated().map { index, mean in
            let from = start.addingTimeInterval(TimeInterval(index) * step)
            return ClimateSample(start: from, end: from.addingTimeInterval(300), mean: mean)
        }
    }
}

fileprivate struct PreviewClimateHistory: View {
    var body: some View {
        let schema = Schema([
            LightEntity.self, CoverEntity.self, SceneEntity.self, ScriptEntity.self, SensorEntity.self,
            SwitchEntity.self, ButtonEntity.self, AutomationEntity.self,
            BinarySensorEntity.self, ClimateEntity.self, AreaEntity.self, FloorEntity.self, HomeTile.self
        ])
        let context = try! ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        ).mainContext

        let sensor = SensorEntity(entityId: "sensor.lobby.temperature", name: "Temperature",
                                  state: "20", deviceClass: "temperature", unitOfMeasurement: "°C")
        context.insert(sensor)

        let viewModel = AreaClimateHistoryViewModel(sensor: sensor, fallbackUnit: "°", provider: StubHistoryProvider())
        return AreaClimateHistoryView(viewModel: viewModel, areaName: "Lobby")
    }
}

#Preview {
    PreviewClimateHistory()
}

#endif
