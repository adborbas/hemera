import Foundation
import Testing
@testable import Hemera

@MainActor
struct UpdateNudgeTests {

    private static let day: TimeInterval = 24 * 60 * 60
    private static let start = Date(timeIntervalSince1970: 1_800_000_000)

    private let lookup = StubAppStoreLookup()
    private let clock = TestClock(now: UpdateNudgeTests.start)
    private let store = InMemorySettingsStore()
    private let defaults = UserDefaults(suiteName: "com.hemera.tests.\(UUID().uuidString)")!
    private let screenManager: ScreenManager

    init() {
        screenManager = ScreenManager(store: store)
        screenManager.stayAwake = true
    }

    private func makeNudge(installed: String = "1.0", os: String = "18.0") -> UpdateNudge {
        UpdateNudge(
            lookup: lookup,
            defaults: defaults,
            screenManager: screenManager,
            now: { [clock] in clock.now },
            installedVersion: installed,
            osVersion: os,
            mayCheck: { true }
        )
    }

    private func release(_ version: String, daysOld: Double, minimumOs: String = "18.0") -> AppStoreRelease {
        AppStoreRelease(
            version: version,
            releaseDate: clock.now.addingTimeInterval(-daysOld * Self.day),
            minimumOsVersion: minimumOs,
            trackId: 42
        )
    }

    // MARK: - Due rule

    /// A release that has been out a week is stable enough to push a kiosk tablet onto.
    @Test func check_releaseAWeekOld_isDue() async {
        lookup.result = .success(release("1.1", daysOld: 7))
        let nudge = makeNudge()

        await nudge.check()

        #expect(nudge.availableUpdate == AvailableUpdate(version: "1.1", appStoreId: 42))
    }

    /// Releases ship every few days, so a device can fall a week behind while each release is fresh.
    @Test func check_deviceBehindAWeekWhileReleasesStayFresh_isDue() async {
        let nudge = makeNudge()
        lookup.result = .success(release("1.1", daysOld: 0))
        await nudge.check()
        #expect(nudge.availableUpdate == nil)

        clock.now += 4 * Self.day
        lookup.result = .success(release("1.2", daysOld: 0))
        await nudge.check()
        #expect(nudge.availableUpdate == nil)

        clock.now += 3 * Self.day
        lookup.result = .success(release("1.3", daysOld: 1))
        await nudge.check()
        #expect(nudge.availableUpdate?.version == "1.3")
    }

    @Test func check_freshReleaseAndDeviceJustFellBehind_isNotDue() async {
        lookup.result = .success(release("1.1", daysOld: 6))
        let nudge = makeNudge()

        await nudge.check()

        #expect(nudge.availableUpdate == nil)
    }

    /// Nudging toward a version the device cannot install would be a dead end.
    @Test func check_deviceOSBelowMinimum_staysQuiet() async {
        lookup.result = .success(release("1.1", daysOld: 30, minimumOs: "26.0"))
        let nudge = makeNudge(os: "18.5")

        await nudge.check()

        #expect(nudge.availableUpdate == nil)
    }

    @Test func check_installedIsLatest_staysQuiet() async {
        lookup.result = .success(release("1.1", daysOld: 30))
        let nudge = makeNudge(installed: "1.1")

        await nudge.check()

        #expect(nudge.availableUpdate == nil)
    }

    /// A string compare would call 2.10 older than 2.9 and miss every double-digit release.
    @Test func check_comparesVersionsNumerically() async {
        lookup.result = .success(release("2.10", daysOld: 30))
        let nudge = makeNudge(installed: "2.9")

        await nudge.check()

        #expect(nudge.availableUpdate?.version == "2.10")
    }

    // MARK: - Kiosk Mode

    /// Outside Kiosk Mode iOS updates the app on its own, so the nudge is noise.
    @Test func availableUpdate_kioskModeTurnedOff_clears() async {
        lookup.result = .success(release("1.1", daysOld: 30))
        let nudge = makeNudge()
        await nudge.check()
        #expect(nudge.availableUpdate != nil)

        screenManager.stayAwake = false

        #expect(nudge.availableUpdate == nil)
    }

    @Test func check_kioskModeOff_doesNotLookUp() async {
        screenManager.stayAwake = false
        lookup.result = .success(release("1.1", daysOld: 30))
        let nudge = makeNudge()

        await nudge.check()

        #expect(lookup.callCount == 0)
        #expect(nudge.availableUpdate == nil)
    }

    // MARK: - Skip

    /// An owner who chose to stay on a version must not be nagged about it again, even after relaunch.
    @Test func skip_sameVersion_staysQuietAcrossRelaunch() async {
        lookup.result = .success(release("1.1", daysOld: 30))
        let nudge = makeNudge()
        await nudge.check()
        nudge.skip()
        #expect(nudge.availableUpdate == nil)

        await nudge.check()
        #expect(nudge.availableUpdate == nil)

        let relaunched = makeNudge()
        await relaunched.check()
        #expect(relaunched.availableUpdate == nil)
    }

    /// Without restarting the clock, a stale device would nag again with the next fresh release.
    @Test func skip_newerFreshVersion_waitsAWeekFromSkip() async {
        let nudge = makeNudge()
        lookup.result = .success(release("1.1", daysOld: 0))
        await nudge.check()
        clock.now += 7 * Self.day
        await nudge.check()
        nudge.skip()

        clock.now += 1 * Self.day
        lookup.result = .success(release("1.2", daysOld: 0))
        await nudge.check()
        #expect(nudge.availableUpdate == nil)

        clock.now += 6 * Self.day
        await nudge.check()
        #expect(nudge.availableUpdate?.version == "1.2")
    }

    /// Skipping one version is not opting out: a settled newer release nudges straight away.
    @Test func skip_newerVersionAWeekOld_isDue() async {
        lookup.result = .success(release("1.1", daysOld: 30))
        let nudge = makeNudge()
        await nudge.check()
        nudge.skip()

        lookup.result = .success(release("1.2", daysOld: 7))
        await nudge.check()

        #expect(nudge.availableUpdate?.version == "1.2")
    }

    // MARK: - Failures

    @Test func check_lookupFails_staysQuiet() async {
        lookup.result = .failure(URLError(.notConnectedToInternet))
        let nudge = makeNudge()

        await nudge.check()

        #expect(nudge.availableUpdate == nil)
    }
}

@MainActor
private final class StubAppStoreLookup: AppStoreLookup {
    var result: Result<AppStoreRelease?, Error> = .success(nil)
    var callCount = 0

    func latestRelease() async throws -> AppStoreRelease? {
        callCount += 1
        return try result.get()
    }
}

private final class TestClock {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}
