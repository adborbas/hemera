import Foundation
import SwiftData
import Testing
@testable import Hemera

private struct GenericHistoryError: Error {}

@MainActor
struct AreaClimateHistoryViewModelTests {

    // MARK: - Setup

    let container: ModelContainer
    let context: ModelContext

    init() {
        let schema = Schema([
            LightEntity.self, CoverEntity.self, SceneEntity.self, ScriptEntity.self, SensorEntity.self,
            SwitchEntity.self, ButtonEntity.self, AutomationEntity.self,
            BinarySensorEntity.self, ClimateEntity.self, AreaEntity.self, FloorEntity.self, HomeTile.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: config)
        context = container.mainContext
    }

    // MARK: - load

    @Test
    func load_withBothSensors_andProviderReturnsSamples_bothSeriesLoaded() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")
        let humidity = sensor("sensor.lobby.humidity", name: "Humidity", deviceClass: "humidity", unit: "%")
        let tempSamples = samples(20.0, 21.0)
        let humiditySamples = samples(45.0, 46.5)

        let provider = MockSensorHistoryProvider()
        provider.stubs = [
            "sensor.lobby.temperature": .samples(tempSamples),
            "sensor.lobby.humidity": .samples(humiditySamples),
        ]
        let viewModel = AreaClimateHistoryViewModel(area: area(with: [temperature, humidity], in: context), provider: provider)

        await viewModel.load()

        if case let .loaded(series) = viewModel.temperature {
            #expect(series.sensorName == "Temperature")
            #expect(series.unit == "°C")
            #expect(series.samples == tempSamples)
        } else {
            Issue.record("temperature expected to be loaded, got \(viewModel.temperature)")
        }
        if case let .loaded(series) = viewModel.humidity {
            #expect(series.sensorName == "Humidity")
            #expect(series.unit == "%")
            #expect(series.samples == humiditySamples)
        } else {
            Issue.record("humidity expected to be loaded, got \(viewModel.humidity)")
        }
    }

    @Test
    func load_withBothSensors_asksForBothEntityIdsInDayRange() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")
        let humidity = sensor("sensor.lobby.humidity", name: "Humidity", deviceClass: "humidity", unit: "%")

        let provider = MockSensorHistoryProvider()
        provider.result = []
        let viewModel = AreaClimateHistoryViewModel(area: area(with: [temperature, humidity], in: context), provider: provider)

        await viewModel.load()

        #expect(provider.requests.contains { $0.entityId == "sensor.lobby.temperature" && $0.range == .day })
        #expect(provider.requests.contains { $0.entityId == "sensor.lobby.humidity" && $0.range == .day })
    }

    @Test
    func load_temperatureThrowsNoRecordedHistory_humidityStillLoaded() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")
        let humidity = sensor("sensor.lobby.humidity", name: "Humidity", deviceClass: "humidity", unit: "%")
        let humiditySamples = samples(45.0)

        let provider = MockSensorHistoryProvider()
        provider.stubs = [
            "sensor.lobby.temperature": .failure(SensorHistoryError.noRecordedHistory),
            "sensor.lobby.humidity": .samples(humiditySamples),
        ]
        let viewModel = AreaClimateHistoryViewModel(area: area(with: [temperature, humidity], in: context), provider: provider)

        await viewModel.load()

        guard case .noRecordedHistory = viewModel.temperature else {
            Issue.record("temperature expected noRecordedHistory, got \(viewModel.temperature)")
            return
        }
        if case let .loaded(series) = viewModel.humidity {
            #expect(series.samples == humiditySamples)
        } else {
            Issue.record("humidity expected to be loaded, got \(viewModel.humidity)")
        }
    }

    @Test
    func load_withGenericError_mapsToFailedNotNoRecordedHistory() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")
        let humidity = sensor("sensor.lobby.humidity", name: "Humidity", deviceClass: "humidity", unit: "%")

        let provider = MockSensorHistoryProvider()
        provider.stubs = ["sensor.lobby.temperature": .failure(GenericHistoryError())]
        let viewModel = AreaClimateHistoryViewModel(area: area(with: [temperature, humidity], in: context), provider: provider)

        await viewModel.load()

        guard case .failed = viewModel.temperature else {
            // A generic error must surface as `.failed`, never `.noRecordedHistory`.
            Issue.record("temperature expected failed, got \(viewModel.temperature)")
            return
        }
    }

    @Test
    func load_areaWithNoHumiditySensor_humidityUnavailableAndNeverFetched() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")

        let provider = MockSensorHistoryProvider()
        provider.result = []
        let viewModel = AreaClimateHistoryViewModel(area: area(with: [temperature], in: context), provider: provider)

        await viewModel.load()

        guard case .unavailable = viewModel.humidity else {
            Issue.record("humidity expected unavailable, got \(viewModel.humidity)")
            return
        }
        // A measurement with no sensor is never fetched.
        #expect(provider.requests.contains { $0.entityId == "sensor.lobby.humidity" } == false)
        #expect(provider.requests.contains { $0.entityId == "sensor.lobby.temperature" })
    }

    @Test
    func load_withNilUnits_fallsBackToDefaults() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: nil)
        let humidity = sensor("sensor.lobby.humidity", name: "Humidity", deviceClass: "humidity", unit: nil)

        let provider = MockSensorHistoryProvider()
        provider.result = []
        let viewModel = AreaClimateHistoryViewModel(area: area(with: [temperature, humidity], in: context), provider: provider)

        await viewModel.load()

        guard case let .loaded(series) = viewModel.temperature else {
            Issue.record("temperature expected loaded, got \(viewModel.temperature)")
            return
        }
        #expect(series.unit == "°")
        guard case let .loaded(series) = viewModel.humidity else {
            Issue.record("humidity expected loaded, got \(viewModel.humidity)")
            return
        }
        #expect(series.unit == "%")
    }

    // MARK: - Range selection and caching

    @Test
    func init_selectedRangeDefaultsToDay() {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")

        let viewModel = AreaClimateHistoryViewModel(area: area(with: [temperature], in: context), provider: MockSensorHistoryProvider())

        #expect(viewModel.selectedRange == .day)
    }

    @Test
    func load_selectingWeek_requestsWeekRangeForBothSensors() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")
        let humidity = sensor("sensor.lobby.humidity", name: "Humidity", deviceClass: "humidity", unit: "%")

        let provider = MockSensorHistoryProvider()
        provider.result = []
        let viewModel = AreaClimateHistoryViewModel(area: area(with: [temperature, humidity], in: context), provider: provider)

        viewModel.selectedRange = .week
        await viewModel.load()

        #expect(provider.requests.contains { $0.entityId == "sensor.lobby.temperature" && $0.range == .week })
        #expect(provider.requests.contains { $0.entityId == "sensor.lobby.humidity" && $0.range == .week })
    }

    @Test
    func load_selectingMonth_requestsMonthRangeForBothSensors() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")
        let humidity = sensor("sensor.lobby.humidity", name: "Humidity", deviceClass: "humidity", unit: "%")

        let provider = MockSensorHistoryProvider()
        provider.result = []
        let viewModel = AreaClimateHistoryViewModel(area: area(with: [temperature, humidity], in: context), provider: provider)

        viewModel.selectedRange = .month
        await viewModel.load()

        #expect(provider.requests.contains { $0.entityId == "sensor.lobby.temperature" && $0.range == .month })
        #expect(provider.requests.contains { $0.entityId == "sensor.lobby.humidity" && $0.range == .month })
    }

    @Test
    func load_reselectingAFetchedRange_issuesNoFurtherRequest() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")
        let humidity = sensor("sensor.lobby.humidity", name: "Humidity", deviceClass: "humidity", unit: "%")

        let provider = MockSensorHistoryProvider()
        provider.result = []
        let viewModel = AreaClimateHistoryViewModel(area: area(with: [temperature, humidity], in: context), provider: provider)

        viewModel.selectedRange = .week
        await viewModel.load()
        let requestCount = provider.requests.count

        // Selecting an already-fetched range again must render from cache without a request.
        await viewModel.load()

        #expect(provider.requests.count == requestCount)
    }

    @Test
    func load_rangeWhoseFetchFailed_isReRequestedOnReselect() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")
        let humidity = sensor("sensor.lobby.humidity", name: "Humidity", deviceClass: "humidity", unit: "%")

        let provider = MockSensorHistoryProvider()
        provider.stubs = [
            "sensor.lobby.temperature": .failure(GenericHistoryError()),
            "sensor.lobby.humidity": .failure(GenericHistoryError()),
        ]
        let viewModel = AreaClimateHistoryViewModel(area: area(with: [temperature, humidity], in: context), provider: provider)

        viewModel.selectedRange = .week
        await viewModel.load()
        guard case .failed = viewModel.temperature, case .failed = viewModel.humidity else {
            Issue.record("both series expected failed, got \(viewModel.temperature) / \(viewModel.humidity)")
            return
        }
        let requestCount = provider.requests.count

        // A failure is never cached, so selecting the same range re-requests both sensors.
        await viewModel.load()

        #expect(provider.requests.count == requestCount + 2)
    }

    @Test
    func load_noRecordedHistoryOutcome_isCachedAndNotReRequested() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")
        let humidity = sensor("sensor.lobby.humidity", name: "Humidity", deviceClass: "humidity", unit: "%")

        let provider = MockSensorHistoryProvider()
        provider.stubs = [
            "sensor.lobby.temperature": .failure(SensorHistoryError.noRecordedHistory),
            "sensor.lobby.humidity": .failure(SensorHistoryError.noRecordedHistory),
        ]
        let viewModel = AreaClimateHistoryViewModel(area: area(with: [temperature, humidity], in: context), provider: provider)

        viewModel.selectedRange = .week
        await viewModel.load()
        guard case .noRecordedHistory = viewModel.temperature, case .noRecordedHistory = viewModel.humidity else {
            Issue.record("both series expected noRecordedHistory, got \(viewModel.temperature) / \(viewModel.humidity)")
            return
        }
        let requestCount = provider.requests.count

        // A settled no-history outcome is cached, so re-selecting the range issues no request.
        await viewModel.load()

        #expect(provider.requests.count == requestCount)
    }

    // MARK: - Selection and readout

    /// Scrubbing inside a bucket reads out that bucket's mean for each measurement.
    @Test
    func selectionInsideSampleResolvesThatSampleForBothMeasurements() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")
        let humidity = sensor("sensor.lobby.humidity", name: "Humidity", deviceClass: "humidity", unit: "%")

        let provider = MockSensorHistoryProvider()
        provider.stubs = [
            "sensor.lobby.temperature": .samples(samples(20.5)),
            "sensor.lobby.humidity": .samples(samples(47.5)),
        ]
        let viewModel = AreaClimateHistoryViewModel(area: area(with: [temperature, humidity], in: context), provider: provider)

        await viewModel.load()

        // samples(_:) lays one 300s bucket at [1000, 1300); 1100 falls inside it.
        viewModel.selectedDate = Date(timeIntervalSince1970: 1100)

        #expect(viewModel.temperatureReadout?.mean == 20.5)
        #expect(viewModel.humidityReadout?.mean == 47.5)
    }

    /// The interval is half-open: a bucket's own `start` resolves that bucket.
    @Test
    func selectionOnSampleStartResolvesThatSampleNotTheNext() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")

        let provider = MockSensorHistoryProvider()
        provider.stubs = ["sensor.lobby.temperature": .samples(samples(10, 20, 30))]
        let viewModel = AreaClimateHistoryViewModel(area: area(with: [temperature], in: context), provider: provider)

        await viewModel.load()

        // buckets are [1000, 1300)=10, [1300, 1600)=20, [1600, 1900)=30; 1300 is the middle start.
        viewModel.selectedDate = Date(timeIntervalSince1970: 1300)

        #expect(viewModel.temperatureReadout?.mean == 20)
    }

    /// The interval is half-open: a bucket's `end` does not resolve that bucket, it resolves the next.
    @Test
    func selectionOnSampleEndResolvesTheNextSample() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")

        let provider = MockSensorHistoryProvider()
        provider.stubs = ["sensor.lobby.temperature": .samples(samples(10, 20, 30))]
        let viewModel = AreaClimateHistoryViewModel(area: area(with: [temperature], in: context), provider: provider)

        await viewModel.load()

        // 1600 is the end of the [1300, 1600)=20 bucket, so it resolves the [1600, 1900)=30 bucket.
        viewModel.selectedDate = Date(timeIntervalSince1970: 1600)

        #expect(viewModel.temperatureReadout?.mean == 30)
    }

    /// A date in one series' gap resolves nil for it while the other series still reads out.
    @Test
    func selectionInsideGapResolvesNilForThatMeasurementWhileOtherResolves() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")
        let humidity = sensor("sensor.lobby.humidity", name: "Humidity", deviceClass: "humidity", unit: "%")

        // Temperature skips [1300, 1600); humidity holds one wide bucket across the same span.
        let temperatureSamples = [
            ClimateSample(start: Date(timeIntervalSince1970: 1000), end: Date(timeIntervalSince1970: 1300), mean: 20.0),
            ClimateSample(start: Date(timeIntervalSince1970: 1600), end: Date(timeIntervalSince1970: 1900), mean: 22.0),
        ]
        let humiditySamples = [
            ClimateSample(start: Date(timeIntervalSince1970: 1000), end: Date(timeIntervalSince1970: 2000), mean: 45.0),
        ]
        let provider = MockSensorHistoryProvider()
        provider.stubs = [
            "sensor.lobby.temperature": .samples(temperatureSamples),
            "sensor.lobby.humidity": .samples(humiditySamples),
        ]
        let viewModel = AreaClimateHistoryViewModel(area: area(with: [temperature, humidity], in: context), provider: provider)

        await viewModel.load()

        // 1450 lands inside temperature's gap but inside humidity's single bucket.
        viewModel.selectedDate = Date(timeIntervalSince1970: 1450)

        let temperatureReadout = viewModel.temperatureReadout
        let humidityReadout = viewModel.humidityReadout

        // Temperature's gap yields a readout with no sample; humidity's wide bucket still reads.
        #expect(temperatureReadout != nil)
        #expect(temperatureReadout?.mean == nil)
        #expect(temperatureReadout?.interval == nil)
        #expect(humidityReadout?.mean == 45.0)
        #expect(humidityReadout?.interval != nil)
    }

    /// A date outside every bucket resolves nil.
    @Test
    func selectionOutsideLoadedSeriesResolvesNil() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")

        let provider = MockSensorHistoryProvider()
        provider.stubs = ["sensor.lobby.temperature": .samples(samples(20.0))]
        let viewModel = AreaClimateHistoryViewModel(area: area(with: [temperature], in: context), provider: provider)

        await viewModel.load()

        let outsideAfter = Date(timeIntervalSince1970: 5000)
        let outsideBefore = Date(timeIntervalSince1970: 500)
        viewModel.selectedDate = outsideAfter
        #expect(viewModel.temperatureReadout?.mean == nil)
        viewModel.selectedDate = outsideBefore
        #expect(viewModel.temperatureReadout?.mean == nil)
    }

    /// Clearing the scrub position leaves nothing to read for either measurement.
    @Test
    func clearingSelectedDateLeavesNoReadout() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")
        let humidity = sensor("sensor.lobby.humidity", name: "Humidity", deviceClass: "humidity", unit: "%")

        let provider = MockSensorHistoryProvider()
        provider.stubs = [
            "sensor.lobby.temperature": .samples(samples(20.0)),
            "sensor.lobby.humidity": .samples(samples(45.0)),
        ]
        let viewModel = AreaClimateHistoryViewModel(area: area(with: [temperature, humidity], in: context), provider: provider)

        await viewModel.load()

        viewModel.selectedDate = Date(timeIntervalSince1970: 1100)
        #expect(viewModel.temperatureReadout?.mean != nil)
        #expect(viewModel.humidityReadout?.mean != nil)

        viewModel.selectedDate = nil
        #expect(viewModel.temperatureReadout == nil)
        #expect(viewModel.humidityReadout == nil)
    }

    /// An `.unavailable` measurement resolves nil; the other still reads.
    @Test
    func selectionWithUnavailableMeasurementResolvesNilWithoutCrashing() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")

        let provider = MockSensorHistoryProvider()
        provider.stubs = ["sensor.lobby.temperature": .samples(samples(20.0))]
        let viewModel = AreaClimateHistoryViewModel(area: area(with: [temperature], in: context), provider: provider)

        await viewModel.load()

        guard case .unavailable = viewModel.humidity else {
            Issue.record("humidity expected unavailable, got \(viewModel.humidity)")
            return
        }

        viewModel.selectedDate = Date(timeIntervalSince1970: 1100)
        #expect(viewModel.humidityReadout == nil)
        #expect(viewModel.temperatureReadout?.mean == 20.0)
    }

    /// A measurement whose fetch failed resolves nil without crashing; the other still reads.
    @Test
    func selectionWithFailedMeasurementResolvesNilWithoutCrashing() async {
        let temperature = sensor("sensor.lobby.temperature", name: "Temperature", deviceClass: "temperature", unit: "°C")
        let humidity = sensor("sensor.lobby.humidity", name: "Humidity", deviceClass: "humidity", unit: "%")

        let provider = MockSensorHistoryProvider()
        provider.stubs = [
            "sensor.lobby.temperature": .samples(samples(20.0)),
            "sensor.lobby.humidity": .failure(GenericHistoryError()),
        ]
        let viewModel = AreaClimateHistoryViewModel(area: area(with: [temperature, humidity], in: context), provider: provider)

        await viewModel.load()

        guard case .failed = viewModel.humidity else {
            Issue.record("humidity expected failed, got \(viewModel.humidity)")
            return
        }

        viewModel.selectedDate = Date(timeIntervalSince1970: 1100)
        #expect(viewModel.humidityReadout == nil)
        #expect(viewModel.temperatureReadout?.mean == 20.0)
    }

    // MARK: - Helpers

    private func sensor(_ entityId: String, name: String, deviceClass: String, unit: String?) -> SensorEntity {
        SensorEntity(entityId: entityId, name: name, state: "0", deviceClass: deviceClass, unitOfMeasurement: unit)
    }

    private func area(with sensors: [SensorEntity], in context: ModelContext) -> AreaEntity {
        let created = AreaEntity(areaId: "area", name: "Area")
        sensors.forEach { $0.area = created }
        context.insert(created)
        sensors.forEach(context.insert)
        return created
    }

    private func samples(_ means: Double...) -> [ClimateSample] {
        means.enumerated().map { index, value in
            let start = Date(timeIntervalSince1970: 1000 + TimeInterval(index) * 300)
            return ClimateSample(start: start, end: start.addingTimeInterval(300), mean: value)
        }
    }
}
