import Accessibility
import Charts
import Mortar
import SwiftUI

/// One climate measurement's history for an area's representative sensor.
struct AreaClimateHistoryView: View {

    @Bindable var viewModel: AreaClimateHistoryViewModel
    let areaName: String
    let color: Color

    @Environment(\.dismiss) private var dismiss

    init(viewModel: AreaClimateHistoryViewModel, areaName: String, color: Color) {
        self.viewModel = viewModel
        self.areaName = areaName
        self.color = color
    }

    var body: some View {
        let now = Date()
        let range = viewModel.selectedRange
        // The plot's x-domain follows the selected range so it rescales with the picker.
        let window = now.addingTimeInterval(-range.interval)...now

        NavigationStack {
            VStack(spacing: Mortar.Spacing.l) {
                Picker(Localization.range, selection: rangeSelection) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(rangeLabel(range)).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Mortar.Spacing.l)

                // A fixed-height readout above the plot so scrubbing shifts nothing below it.
                selectionHeader

                ScrollView {
                    plot(state: viewModel.series, isLoading: viewModel.isLoading,
                         window: window, range: range)
                        .padding(Mortar.Spacing.l)
                }
            }
            .navigationTitle(areaName)
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

    // MARK: - Range picker

    private var rangeSelection: Binding<TimeRange> {
        Binding(
            get: { viewModel.selectedRange },
            set: { viewModel.selectedRange = $0 }
        )
    }

    // MARK: - Plot

    /**
     While a range loads, the last chart stays dimmed under a spinner; a first
     load has nothing behind its spinner.
     */
    @ViewBuilder
    private func plot(
        state: AreaClimateHistoryViewModel.SeriesState,
        isLoading: Bool,
        window: ClosedRange<Date>,
        range: TimeRange
    ) -> some View {
        if isLoading, case .loaded = state {
            chartFor(state: state, window: window, range: range)
                .opacity(Self.staleOpacity)
                .overlay {
                    ProgressView()
                        .controlSize(.small)
                }
        } else {
            chartFor(state: state, window: window, range: range)
        }
    }

    /// The measurement's chart for the selected range; gaps split into separate runs.
    @ViewBuilder
    private func chartFor(
        state: AreaClimateHistoryViewModel.SeriesState,
        window: ClosedRange<Date>,
        range: TimeRange
    ) -> some View {
        switch state {
        case .loading:
            ProgressView()
                .controlSize(.small)
                .frame(height: Self.plotHeight)
                .frame(maxWidth: .infinity)

        case .noRecordedHistory:
            Text(Localization.noRecordedHistory)
                .foregroundStyle(.secondary)
                .frame(height: Self.plotHeight)

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
            .frame(height: Self.plotHeight)

        case let .loaded(series):
            VStack(alignment: .leading, spacing: Mortar.Spacing.xs) {
                Text("\(series.sensorName) (\(series.unit))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // One line per run, so a gap reads as a break rather than a straight line.
                Chart {
                    ForEach(Array(ClimateSampleRuns.split(series.samples).enumerated()), id: \.offset) { run in
                        ForEach(run.element, id: \.start) { sample in
                            LineMark(
                                x: .value(Localization.timeAxis, sample.start),
                                y: .value(Localization.meanAxis, sample.mean),
                                series: .value(Localization.runKey, run.offset)
                            )
                            .foregroundStyle(color)
                        }
                    }
                    if let selectedDate = viewModel.selectedDate {
                        // A thin secondary rule marks the scrub position the user is reading.
                        RuleMark(x: .value(Localization.timeAxis, selectedDate))
                            .foregroundStyle(.secondary)
                            .lineStyle(StrokeStyle(lineWidth: 1))
                    }
                }
                .chartXScale(domain: window)
                .chartXSelection(value: $viewModel.selectedDate)
                .chartLegend(.hidden)
                .frame(height: Self.plotHeight)
                .accessibilityChartDescriptor(
                    ClimateChartDescriptor(
                        title: String(format: Localization.chartTitle, series.sensorName, series.unit),
                        summary: String(format: Localization.chartRange, rangeLabel(range)),
                        unit: series.unit,
                        range: range,
                        window: window,
                        samples: series.samples,
                        xAxisTitle: Localization.timeAxis
                    )
                )
            }
        }
    }

    // MARK: - Readout header

    /// The reading at the scrub position, reserved at a fixed height so nothing below moves.
    private var selectionHeader: some View {
        selectionContent
            .frame(height: Self.selectionHeaderHeight, alignment: .top)
            .padding(.horizontal, Mortar.Spacing.l)
    }

    @ViewBuilder
    private var selectionContent: some View {
        if viewModel.selectedDate != nil, let readout = viewModel.readout {
            measurementBlock(readout)
        } else {
            // Nothing selected: fill the space so the plot doesn't jump on first drag.
            Text(Localization.dragPrompt)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    /// A measurement's name, interval, and mean, or a gap notice when the position lands in one.
    @ViewBuilder
    private func measurementBlock(_ readout: AreaClimateHistoryViewModel.Readout) -> some View {
        VStack(alignment: .leading, spacing: Mortar.Spacing.xxs) {
            Text(readout.sensorName)
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let interval = readout.interval, let mean = readout.mean {
                HStack(spacing: Mortar.Spacing.s) {
                    Text(formatInterval(interval))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(mean.formatted(.number.precision(.fractionLength(1))) + readout.unit)")
                        .font(.callout)
                }
            } else {
                Text(Localization.noReading)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
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
}

// MARK: - Localization

private extension AreaClimateHistoryView {
    enum Localization {
        static let close = String(localized: "Close", comment: "Toolbar button that dismisses the area's climate-history sheet")
        static let noRecordedHistory = String(localized: "Home Assistant isn't recording history for this sensor", comment: "Shown under a climate chart when Home Assistant keeps no long-term statistics for the sensor, which is normal")
        static let loadFailed = String(localized: "Couldn't load history", comment: "Shown under a climate chart when the history fetch failed, next to a retry button")
        static let retry = String(localized: "Retry", comment: "The button that re-fetches a climate range whose history failed to load")
        static let timeAxis = String(localized: "Time", comment: "Horizontal axis key for a climate-history chart, over the selected range")
        static let meanAxis = String(localized: "Mean", comment: "Vertical axis key for a climate-history chart, holding each bucket's mean")
        /// Not user-facing: the legend is hidden, this only keeps each run a separate series.
        static let runKey = "Run"
        static let range = String(localized: "Time range", comment: "Title of the picker that chooses how far back the area's climate-history chart reaches")
        static let twentyFourHours = String(localized: "24 Hours", comment: "Picker option showing the last 24 hours of climate history")
        static let sevenDays = String(localized: "7 Days", comment: "Picker option showing the last 7 days of climate history")
        static let thirtyDays = String(localized: "30 Days", comment: "Picker option showing the last 30 days of climate history")
        static let noReading = String(localized: "No reading", comment: "Shown for a measurement that has no sample at the scrubbed position, eg. inside a recording gap")
        static let dragPrompt = String(localized: "Drag across the chart to read a value", comment: "Idle text in the climate-history readout, shown before any position is scrubbed")
        /// VoiceOver heading for the chart; names the sensor and the measurement it shows.
        static let chartTitle = String(localized: "Climate history of %1$@ (%2$@)", comment: "Audio-graph heading naming the sensor and its measurement, eg. Temperature (°C)")
        /// The window a chart covers, spoken alongside its audio graph.
        static let chartRange = String(localized: "Over the last %1$@", comment: "The selected range the chart's audio graph covers, eg. Over the last 24 hours")
        /// Accessibility label for the retry button after a climate-history fetch fails.
        static let retryAction = String(localized: "Retry loading climate history", comment: "Accessibility label on a retry button after a climate-history fetch fails")
    }

    /// Maps each range to its picker label; the enum carries no display text.
    func rangeLabel(_ range: TimeRange) -> String {
        switch range {
        case .day: return Localization.twentyFourHours
        case .week: return Localization.sevenDays
        case .month: return Localization.thirtyDays
        }
    }

    /// Fixed height for the plot so it doesn't size to the container.
    static let plotHeight: CGFloat = 200

    /// How dim a still-loaded chart reads while a newer range loads over it.
    static let staleOpacity: Double = 0.5

    /// Reserves height for the readout, so scrubbing shifts the plot neither up nor down.
    static let selectionHeaderHeight: CGFloat = 80
}

// MARK: - Accessibility descriptor

/**
 A sendable audio-graph descriptor built from a settled series, so VoiceOver hears
 the recorded values and never a point that the run split dropped.
 */
extension AreaClimateHistoryView {
    struct ClimateChartDescriptor: AXChartDescriptorRepresentable, Sendable {

        let title: String
        let summary: String
        let unit: String
        let range: TimeRange
        let window: ClosedRange<Date>
        let samples: [ClimateSample]
        let xAxisTitle: String

        func makeChartDescriptor() -> AXChartDescriptor {
            let start = window.lowerBound.timeIntervalSinceReferenceDate
            let end = window.upperBound.timeIntervalSinceReferenceDate
            let means = samples.map(\.mean)

            let y: ClosedRange<Double>
            if let lo = means.min(), let hi = means.max() {
                y = lo...hi
            } else {
                y = 0...1
            }

            let xAxis = AXNumericDataAxisDescriptor(
                title: xAxisTitle,
                range: start...end,
                gridlinePositions: [],
                valueDescriptionProvider: {
                    Self.time(range, Date(timeIntervalSinceReferenceDate: $0))
                }
            )
            let yAxis = AXNumericDataAxisDescriptor(
                title: unit,
                range: y,
                gridlinePositions: [],
                valueDescriptionProvider: {
                    $0.formatted(.number.precision(.fractionLength(1))) + unit
                }
            )

            // One series per run keeps each gap a break, and adds nothing where a sample is absent.
            var series: [AXDataSeriesDescriptor] = []
            for run in ClimateSampleRuns.split(samples) {
                let points = run.map { sample in
                    AXDataPoint(
                        x: sample.start.timeIntervalSinceReferenceDate,
                        y: sample.mean,
                        label: pointLabel(sample)
                    )
                }
                series.append(AXDataSeriesDescriptor(name: title, isContinuous: true, dataPoints: points))
            }

            return AXChartDescriptor(
                title: title,
                summary: summary,
                xAxis: xAxis,
                yAxis: yAxis,
                series: series
            )
        }

        /// A sample's interval then its mean and unit, mirroring the scrub readout.
        private func pointLabel(_ sample: ClimateSample) -> String {
            let span = "\(Self.time(range, sample.start)) – \(Self.time(range, sample.end)) "
            return span + "\(sample.mean.formatted(.number.precision(.fractionLength(1))))\(unit)"
        }

        /// A time in the selected range's style; the day drops the date, the others keep it.
        private static func time(_ range: TimeRange, _ date: Date) -> String {
            switch range {
            case .day:
                return date.formatted(date: .omitted, time: .shortened)
            case .week, .month:
                return date.formatted(date: .abbreviated, time: .shortened)
            }
        }
    }
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
        return AreaClimateHistoryView(viewModel: viewModel, areaName: "Lobby", color: .warm)
    }
}

#Preview {
    PreviewClimateHistory()
}

#endif
