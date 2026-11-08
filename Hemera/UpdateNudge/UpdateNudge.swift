import Foundation
import HemeraLog

struct AvailableUpdate: Equatable, Identifiable {
    let version: String
    let appStoreId: Int

    var id: String { version }

    var label: String { Localization.available(version) }
}

private extension AvailableUpdate {
    enum Localization {
        static func available(_ version: String) -> String {
            String(localized: "\(version) available", comment: "Points to a newer App Store version, under the app version and on the Settings entry")
        }
    }
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
    private static let fakeUpdateKey = "debug.fakesAppStoreUpdate"

    var fakesAppStoreUpdate = false {
        didSet {
            defaults.set(fakesAppStoreUpdate, forKey: Self.fakeUpdateKey)
            Task { await check() }
        }
    }
    #endif

    private var dueUpdate: AvailableUpdate?
    private var behindSince: Date? {
        didSet { defaults.set(behindSince, forKey: Self.behindSinceKey) }
    }
    private var skippedVersion: String? {
        didSet { defaults.set(skippedVersion, forKey: Self.skippedVersionKey) }
    }

    private let lookup: any AppStoreLookup
    private let defaults: UserDefaults
    private let screenManager: ScreenManager
    private let now: () -> Date
    private let installedVersion: String
    private let osVersion: String
    private let mayCheck: () async -> Bool

    private static let gracePeriod: TimeInterval = 7 * 24 * 60 * 60
    private static let skippedVersionKey = "updateNudge.skippedVersion"
    private static let behindSinceKey = "updateNudge.behindSince"

    // MARK: - Init

    init(
        lookup: any AppStoreLookup,
        defaults: UserDefaults = .standard,
        screenManager: ScreenManager,
        now: @escaping () -> Date = { .now },
        installedVersion: String,
        osVersion: String,
        mayCheck: @escaping () async -> Bool
    ) {
        self.lookup = lookup
        self.defaults = defaults
        self.screenManager = screenManager
        self.now = now
        self.installedVersion = installedVersion
        self.osVersion = osVersion
        self.mayCheck = mayCheck
        self.skippedVersion = defaults.string(forKey: Self.skippedVersionKey)
        self.behindSince = defaults.object(forKey: Self.behindSinceKey) as? Date
        #if DEBUG
        self.fakesAppStoreUpdate = defaults.bool(forKey: Self.fakeUpdateKey)
        #endif
    }

    // MARK: - Public Methods

    func check() async {
        var lookup = lookup
        var mayCheck = mayCheck
        #if DEBUG
        // Screenshot mode never nudges, so a fake left on can't reach App Store screenshots.
        if fakesAppStoreUpdate, !CommandLine.arguments.contains("-screenshotMode") {
            lookup = FakeAppStoreLookup()
            mayCheck = { true }
        }
        #endif
        guard screenManager.stayAwake else {
            Log.info("Update check skipped: Kiosk Mode is off")
            dueUpdate = nil
            return
        }
        guard await mayCheck() else {
            Log.info("Update check skipped: not an App Store build, or demo mode")
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
            Log.info("Update check: up to date (latest \(release?.version ?? "none"))")
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
        Log.info("Update check: latest \(release.version), installed \(installedVersion), due \(dueUpdate != nil)")
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
