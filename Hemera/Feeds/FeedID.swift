import Foundation

/// Stable, namespaced identifier of a feed, such as `home`, `areas` or `area:kitchen`.
nonisolated struct FeedID: Hashable, Sendable {
    let rawValue: String

    /// The part before the first `:`, which selects the provider that resolves this ID.
    var namespace: String {
        String(rawValue.prefix { $0 != ":" })
    }

    static let home = FeedID(rawValue: "home")
    static let areas = FeedID(rawValue: "areas")
}
