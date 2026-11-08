import Foundation

/// Stable, namespaced identifier of a feed, such as `home`, `areas` or `domain:light`.
nonisolated struct FeedID: RawRepresentable, Hashable, Sendable, Codable {
    let rawValue: String

    /// The part before the first `:`, which selects the provider that resolves this ID.
    var namespace: String {
        String(rawValue.prefix { $0 != ":" })
    }

    /// The part after the namespace, such as `light` in `domain:light`.
    var value: String {
        String(rawValue.drop { $0 != ":" }.dropFirst())
    }

    static let home = FeedID(rawValue: "home")
    static let areas = FeedID(rawValue: "areas")

    static func domain(_ domain: String) -> FeedID {
        FeedID(rawValue: "domain:\(domain)")
    }

    /// Every built-in feed, in default pill row order.
    static let builtIns: [FeedID] = [
        .home, .areas, .domain("light"), .domain("cover"), .domain("climate"), .domain("scene")
    ]
}
