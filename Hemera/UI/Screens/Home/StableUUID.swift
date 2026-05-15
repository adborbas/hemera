import CryptoKit
import Foundation

extension UUID {
    /// Deterministic UUID derived from a stable string identifier.
    ///
    /// Use this when a SwiftUI structure (e.g. `TileGridEngine.Tile`) requires
    /// a `UUID` for identity but we want it tied to a domain key like an
    /// entityId or areaId. Same input → same UUID for the lifetime of the app
    /// and across launches.
    init(stableForString string: String) {
        let digest = SHA256.hash(data: Data(string.utf8))
        let bytes = Array(digest.prefix(16))
        self.init(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
