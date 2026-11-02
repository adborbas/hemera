import Foundation
import HemeraLog

struct AvailableUpdate: Equatable, Identifiable {
    let version: String
    let appStoreId: Int

    var id: String { version }
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
    private var skippedVersion: String? {
        didSet { store.settings.skippedVersion = skippedVersion }
    }

    private let lookup: any AppStoreLookup
    private let store: any SettingsStoring
    private let screenManager: ScreenManager
    private let now: () -> Date
    private let installedVersion: String
    private let osVersion: String
    private let mayCheck: () async -> Bool

    private static let gracePeriod: TimeInterval = 7 * 24 * 60 * 60

    // MARK: - Init

    init(
        lookup: any AppStoreLookup,
        store: any SettingsStoring,
        screenManager: ScreenManager,
        now: @escaping () -> Date = { .now },
        installedVersion: String,
        osVersion: String,
        mayCheck: @escaping () async -> Bool
    ) {
        self.lookup = lookup
        self.store = store
        self.screenManager = screenManager
        self.now = now
        self.installedVersion = installedVersion
        self.osVersion = osVersion
        self.mayCheck = mayCheck
        self.skippedVersion = store.settings.skippedVersion
    }

    // MARK: - Public Methods

    func check() async {
        var lookup = lookup
        var mayCheck = mayCheck
        #if DEBUG
        if fakesAppStoreUpdate {
            lookup = FakeAppStoreLookup()
            mayCheck = { true }
        }
        #endif
        guard screenManager.stayAwake, await mayCheck() else {
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

        dueUpdate = release.version != skippedVersion && osSupported && (releaseIsSettled || deviceIsStale)
            ? AvailableUpdate(version: release.version, appStoreId: release.trackId)
            : nil
    }

    /// Restarts the behind-since clock, so a newer version waits a week from now, not from first seen.
    func skip() {
        guard let dueUpdate else { return }
        skippedVersion = dueUpdate.version
        self.dueUpdate = nil
        behindSince = now()
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
