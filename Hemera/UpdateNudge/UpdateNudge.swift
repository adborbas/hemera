import Foundation
import HemeraLog

struct AvailableUpdate: Equatable {
    let version: String
    let appStoreId: Int
}

/// Nudges a Kiosk Mode device to update, because iOS never updates an app that stays in the foreground.
@Observable
@MainActor
final class UpdateNudge {

    // MARK: - Properties

    /// Non-nil exactly when an update is due.
    var availableUpdate: AvailableUpdate? {
        screenManager.stayAwake ? dueUpdate : nil
    }

    #if DEBUG
    var fakesAppStoreUpdate = false {
        didSet { Task { await check() } }
    }
    #endif

    private var dueUpdate: AvailableUpdate?
    private var behindSince: Date?

    private let lookup: any AppStoreLookup
    private let screenManager: ScreenManager
    private let now: () -> Date
    private let installedVersion: String
    private let osVersion: String
    private let buildMayCheck: Bool

    private static let gracePeriod: TimeInterval = 7 * 24 * 60 * 60

    // MARK: - Init

    init(
        lookup: any AppStoreLookup,
        screenManager: ScreenManager,
        now: @escaping () -> Date = { .now },
        installedVersion: String,
        osVersion: String,
        buildMayCheck: Bool
    ) {
        self.lookup = lookup
        self.screenManager = screenManager
        self.now = now
        self.installedVersion = installedVersion
        self.osVersion = osVersion
        self.buildMayCheck = buildMayCheck
    }

    // MARK: - Public Methods

    func check() async {
        var lookup = lookup
        var mayCheck = buildMayCheck
        #if DEBUG
        if fakesAppStoreUpdate {
            lookup = FakeAppStoreLookup()
            mayCheck = true
        }
        #endif
        guard screenManager.stayAwake, mayCheck else {
            dueUpdate = nil
            return
        }

        let release: AppStoreRelease?
        do {
            release = try await lookup.latestRelease()
        } catch {
            Log.warning("App Store update check failed", cause: error)
            return
        }

        guard let release, Self.compare(release.version, installedVersion) == .orderedDescending else {
            behindSince = nil
            dueUpdate = nil
            return
        }
        let now = now()
        let behindSince = behindSince ?? now
        self.behindSince = behindSince

        let releaseIsSettled = now.timeIntervalSince(release.releaseDate) >= Self.gracePeriod
        // Releases ship every few days, so a fresh release alone would never let the nudge fire.
        let deviceIsStale = now.timeIntervalSince(behindSince) >= Self.gracePeriod
        let osSupported = Self.compare(osVersion, release.minimumOsVersion) != .orderedAscending

        dueUpdate = osSupported && (releaseIsSettled || deviceIsStale)
            ? AvailableUpdate(version: release.version, appStoreId: release.trackId)
            : nil
    }

    func checkDaily() async {
        while !Task.isCancelled {
            await check()
            try? await Task.sleep(for: .seconds(24 * 60 * 60))
        }
    }
}

// MARK: - Private Methods

private extension UpdateNudge {
    /// Compares dotted versions numerically, so "2.10" > "2.9" and "18" == "18.0".
    static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let right = rhs.split(separator: ".").map { Int($0) ?? 0 }
        for index in 0..<max(left.count, right.count) {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0
            if l != r { return l < r ? .orderedAscending : .orderedDescending }
        }
        return .orderedSame
    }
}
